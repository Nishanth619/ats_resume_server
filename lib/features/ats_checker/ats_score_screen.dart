import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/resume_model.dart';
import '../../services/ai_service.dart';
import '../../services/firestore_service.dart';
import '../../services/usage_tracker.dart';
import '../../services/admob_service.dart';
import '../../services/ad_block_guard.dart';
import '../../services/subscription_service.dart';
import '../../providers/resume_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../core/utils/isolate_utils.dart';
import '../../core/widgets/ai_report_dialog.dart';

class ATSScoreScreen extends ConsumerStatefulWidget {
  final String resumeId;
  const ATSScoreScreen({super.key, required this.resumeId});
  @override
  ConsumerState<ATSScoreScreen> createState() => _ATSState();
}

class _ATSState extends ConsumerState<ATSScoreScreen>
    with TickerProviderStateMixin {
  ATSResult? _result;
  bool _loading = true;
  String? _error;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  // ── Optimize Resume state ────────────────────────────────────────────────
  bool _optimising = false;
  bool _hasPendingChanges = false;
  Map<String, dynamic>? _originalSections; // snapshot for instant revert

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulse = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  bool get _bypassLimitsForTesting => kDebugMode || AppConfig.bypassAtsLimits;

  Future<void> _ensureCanUse() async {
    if (_bypassLimitsForTesting) return;

    final isPro = ref.read(subscriptionProvider);
    if (isPro) return;

    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;

    final count = await UsageTracker.getUsageCount(AiFeature.atsCheck, uid);
    if (count >= UsageTracker.getLimit(AiFeature.atsCheck)) {
      if (mounted) {
        final uid = ref.read(userDataProvider).value?.uid ?? '';
        ref.read(subscriptionProvider.notifier).presentPaywall(uid: uid);
      }
      throw Exception('limit_exceeded');
    }
  }

  Future<bool> _showAdAndProceed() async {
    if (_bypassLimitsForTesting) return true;

    final isPro = ref.read(subscriptionProvider);
    if (isPro) return true;

    // Capture before any await — satisfies use_build_context_synchronously
    final messenger = ScaffoldMessenger.of(context);

    final gate = await AdBlockGuard.check(context, ref);
    switch (gate) {
      case AdGateResult.allowed:
        return true;
      case AdGateResult.adBlocked:
        return false;
      case AdGateResult.noFill:
        messenger.showSnackBar(const SnackBar(
          content: Text('Ad not available right now — try again in a moment, or upgrade to Pro.'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 5),
        ));
        return false;
      case AdGateResult.showAd:
        final adSvc = ref.read(adServiceProvider);
        final watched = await adSvc.showRewardedAdAndWait();
        if (!watched) {
          messenger.showSnackBar(const SnackBar(
            content: Text('⚠️ Watch the full ad to unlock this feature.'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
          ));
        }
        return watched;
    }
  }

  Future<void> _run() async {
    try {
      await _ensureCanUse();
    } catch (_) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Show ad FIRST — blocks if ad skipped/blocked/no-fill
      final adOk = await _showAdAndProceed();
      if (!adOk) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final resume = await fetchResumeRobustly(ref, widget.resumeId);

      // Serialise resume to text on a background isolate (off the UI thread)
      final text = await serializeResumeInBackground(resume.sections);

      final result = await ref
          .read(aiServiceProvider)
          .checkATS(
            text,
            targetJD: resume.targetJD.isNotEmpty ? resume.targetJD : null,
            sections: resume.sections,
          );

      // Increment usage counter client-side
      final uid = ref.read(authStateProvider).value?.uid;
      if (uid != null && !_bypassLimitsForTesting) {
        await UsageTracker.incrementUsage(AiFeature.atsCheck, uid);
      }

      // Only save score if it is meaningful (> 0)
      if (result.score > 0) {
        await ref
            .read(resumeNotifierProvider(widget.resumeId).notifier)
            .updateATSScore(result.score);
      }
      if (mounted) {
        setState(() {
          _result = result;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  // ── Optimize Resume ────────────────────────────────────────────────────────

  /// Builds a JD-style optimisation profile from the ATS result.
  /// Structured as a real job description so the tailor-resume prompt
  /// reads it correctly — avoids LLM prompt-confusion from command-style text.
  String _buildOptimisationBrief(ATSResult result) {
    final buf = StringBuffer();

    // Header — looks like a job posting
    final role = ref
            .read(resumeNotifierProvider(widget.resumeId))
            ?.targetRole
            .trim() ??
        '';
    buf.writeln(
      'Senior ${role.isEmpty ? 'Software Engineer' : role} — ATS Optimisation Brief\n',
    );

    // Required qualifications — derived from critical issue fixes
    if (result.criticalIssues.isNotEmpty) {
      buf.writeln('Required Qualifications:');
      for (final issue in result.criticalIssues.take(5)) {
        final fix = issue.fix.trim();
        if (fix.isNotEmpty) buf.writeln('• $fix');
      }
      buf.writeln();
    }

    // Key competencies — from top 3 improvements (reframed as requirements)
    if (result.top3Improvements.isNotEmpty) {
      buf.writeln('Key Competencies & Responsibilities:');
      for (final imp in result.top3Improvements) {
        buf.writeln('• Experience with: $imp');
      }
      buf.writeln();
    }

    // Required technical skills — the exact missing keywords
    if (result.missingKeywords.isNotEmpty) {
      buf.writeln('Required Technical Skills:');
      buf.writeln(result.missingKeywords.take(20).join(', '));
      buf.writeln();
    }

    // Preferred qualifications — from wins (reinforce what's working)
    if (result.top3Wins.isNotEmpty) {
      buf.writeln('Preferred Qualifications:');
      for (final win in result.top3Wins) {
        buf.writeln('• Demonstrated strength in: $win');
      }
    }

    return buf.toString().trim();
  }

  Future<void> _optimiseResume() async {
    if (_result == null || _optimising) return;

    // Capture messenger before async gap
    final messenger = ScaffoldMessenger.of(context);

    // Ad gate (same as ATS check)
    final adOk = await _showAdAndProceed();
    if (!adOk || !mounted) return;

    // Snapshot the original sections before any changes
    final resume = ref.read(resumeNotifierProvider(widget.resumeId));
    if (resume == null) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Resume not loaded. Please go back and try again.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    _originalSections = Map<String, dynamic>.from(resume.sections);

    setState(() => _optimising = true);

    try {
      final aiService = ref.read(aiServiceProvider);
      final brief = _buildOptimisationBrief(_result!);

      // Pass 1 — dry-run tailor (local state only, no Firestore write)
      await ref
          .read(resumeNotifierProvider(widget.resumeId).notifier)
          .tailorToJD(brief, aiService, dryRun: true);

      // Show keyword picker if there are missing keywords
      List<String> selectedKeywords = [];
      if (mounted && _result!.missingKeywords.isNotEmpty) {
        selectedKeywords = await _showKeywordPicker(_result!.missingKeywords);
      }

      // Pass 2 — dry-run inject selected keywords (local state only)
      if (selectedKeywords.isNotEmpty && mounted) {
        await ref
            .read(resumeNotifierProvider(widget.resumeId).notifier)
            .injectKeywords(selectedKeywords, dryRun: true);
      }

      if (mounted) {
        setState(() {
          _optimising = false;
          _hasPendingChanges = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _optimising = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Optimisation failed: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.scoreRed,
        ));
        // Revert local state on error
        _revertChanges();
      }
    }
  }

  /// Shows a bottom sheet where the user picks which missing keywords to add.
  /// All chips start unselected — user must explicitly choose.
  Future<List<String>> _showKeywordPicker(List<String> keywords) async {
    final selected = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _KeywordPickerSheet(keywords: keywords),
    );
    return selected ?? [];
  }

  /// Saves the dry-run changes to Firestore and re-runs ATS analysis.
  Future<void> _keepChanges() async {
    if (!_hasPendingChanges) return;
    try {
      // Take version snapshot then save to Firestore
      final uid = ref.read(authStateProvider).value?.uid;
      final resume = ref.read(resumeNotifierProvider(widget.resumeId));
      if (uid != null && resume != null && _originalSections != null) {
        // Backup original before overwriting
        await ref.read(firestoreServiceProvider).saveVersionSnapshot(
          uid,
          widget.resumeId,
          {...resume.toJson(), 'sections': _originalSections!}
            ..remove('versions'),
        );
      }
      await ref
          .read(resumeNotifierProvider(widget.resumeId).notifier)
          .save();
      if (mounted) {
        setState(() {
          _hasPendingChanges = false;
          _originalSections = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Changes saved! Re-running analysis...'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ));
        // Re-run ATS check to show updated score
        _run();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to save: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.scoreRed,
        ));
      }
    }
  }

  /// Restores the original resume sections without touching Firestore.
  void _revertChanges() {
    if (_originalSections == null) return;
    final current = ref.read(resumeNotifierProvider(widget.resumeId));
    if (current == null) return;

    ref.read(resumeNotifierProvider(widget.resumeId).notifier).seed(
      ResumeModel(
        id: current.id,
        title: current.title,
        templateId: current.templateId,
        colorTheme: current.colorTheme,
        atsScore: current.atsScore,
        sections: _originalSections!,
        targetRole: current.targetRole,
        targetJD: current.targetJD,
        lastEdited: current.lastEdited,
        downloadCount: current.downloadCount,
      ),
    );
    setState(() {
      _hasPendingChanges = false;
      _originalSections = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('↩ Changes discarded. Original resume restored.'),
      behavior: SnackBarBehavior.floating,
    ));
  }


  @override
  Widget build(BuildContext context) {
    final isPro = ref.watch(subscriptionProvider);
    final uid = ref.watch(authStateProvider).value?.uid;

    return Scaffold(
      backgroundColor: context.appColors.bg,
      appBar: GradientAppBar(
        title: 'ATS Analysis',
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh_rounded,
              color: context.appColors.textPrimary,
            ),
            onPressed: _loading ? null : _run,
          ),
        ],
      ),
      body: Column(
        children: [
          // Usage counter banner for free users
          if (!isPro && uid != null && !_bypassLimitsForTesting)
            FutureBuilder<int>(
              future: UsageTracker.getUsageCount(AiFeature.atsCheck, uid),
              builder: (context, snap) {
                final used = snap.data ?? 0;
                final limit = UsageTracker.getLimit(AiFeature.atsCheck);
                final remaining = (limit - used).clamp(0, limit);
                final isNearLimit = remaining <= 1;
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: isNearLimit
                      ? AppColors.scoreOrange.withValues(alpha: 0.12)
                      : AppColors.primary.withValues(alpha: 0.08),
                  child: Row(
                    children: [
                      Icon(
                        isNearLimit ? Icons.warning_amber_rounded : Icons.analytics_outlined,
                        size: 15,
                        color: isNearLimit ? AppColors.scoreOrange : AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          remaining == 0
                              ? 'Daily limit reached — upgrade to Pro for unlimited checks'
                              : '$remaining of $limit free checks remaining today',
                          style: TextStyle(
                            fontSize: 12,
                            color: isNearLimit
                                ? AppColors.scoreOrange
                                : AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          Expanded(
            child: _loading
                ? _buildLoading()
                : _error != null
                    ? _buildError()
                    : _buildResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, child) =>
                Transform.scale(scale: _pulse.value, child: child),
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: context.appColors.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              child: Center(child: Text('🤖', style: TextStyle(fontSize: 44))),
            ),
          ),
          SizedBox(height: 28),
          Text(
            'Analysing Resume...',
            style: TextStyle(
              color: AppColors.primaryLight,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Running 24-point ATS compatibility check',
            style: TextStyle(
              color: context.appColors.textSecondary,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 32),
          SizedBox(
            width: 200,
            child: LinearProgressIndicator(
              backgroundColor: context.appColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 3,
              borderRadius: BorderRadius.all(Radius.circular(4)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: GlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('⚠️', style: TextStyle(fontSize: 48)),
              SizedBox(height: 16),
              Text(
                'Analysis Failed',
                style: TextStyle(
                  color: context.appColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.appColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              SizedBox(height: 24),
              GradientButton(label: 'Retry Analysis', onPressed: _run),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_result == null) return SizedBox();
    final score = _result!.score;
    final color = AppColors.scoreColor(score);
    final label = score >= 80
        ? 'Excellent — Ready to Apply!'
        : score >= 60
        ? 'Good — Minor Fixes Needed'
        : 'Needs Work — Fix Issues First';

    // Category labels for display
    final catLabels = {
      'keyword_match': 'Keyword Match',
      'impact_language': 'Impact Language',
      'structure': 'Structure',
      'relevance': 'Relevance',
      'ats_compatibility': 'ATS Compatibility',
    };
    final catIcons = {
      'keyword_match': '🔑',
      'impact_language': '⚡',
      'structure': '📊',
      'relevance': '🎯',
      'ats_compatibility': '🤖',
    };

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(
        children: [
          // ─── Score card ───
          GlassCard(
            showGlow: true,
            glowColor: color,
            child: Column(
              children: [
                ScoreRing(score: score, radius: 84),
                SizedBox(height: 20),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(
                      color: color.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                // Engine + cache badge
                if (_result!.engine.isNotEmpty) ...[
                  SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_result!.cached)
                        _badge('⚡ Cached', AppColors.scoreGreen),
                      if (_result!.cached) SizedBox(width: 8),
                      _badge(
                        _result!.engine == 'gemini'
                            ? '🤖 Gemini 2.5'
                            : '🧠 Llama 3',
                        AppColors.primary,
                      ),
                      // Show domain badge when available (Fix 9)
                      if (_result!.inferredDomain.isNotEmpty) ...[
                        SizedBox(width: 8),
                        _badge('🏭 ${_result!.inferredDomain}', AppColors.scoreOrange),
                      ],
                    ],
                  ),
                ],
                // Fallback model disclaimer banner (Fix 7)
                if (_result!.engine == 'llama3') ...[
                  SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.scoreOrange.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.scoreOrange.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Text('⚠️', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Scored by Llama 3 (fallback). Gemini was unavailable. '
                            'Scores may vary slightly — retry later for a Gemini score.',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.scoreOrange,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: 20),

          // ─── 5-Category Breakdown ───
          if (_result!.categories.isNotEmpty) ...[
            SectionHeader(
              title: 'Score Breakdown',
              subtitle: '5 categories • 20 pts each',
            ),
            SizedBox(height: 14),
            ..._result!.categories.entries.map((entry) {
              final label = catLabels[entry.key] ?? entry.key;
              final icon = catIcons[entry.key] ?? '📌';
              final cat = entry.value;
              final catColor = AppColors.scoreColor(
                cat.score * 5,
              ); // scale /20 -> /100
              return Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  padding: EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(icon, style: TextStyle(fontSize: 16)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              label,
                              style: TextStyle(
                                color: context.appColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Text(
                            '${cat.score}/20',
                            style: TextStyle(
                              color: catColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: cat.score / 20,
                          backgroundColor: context.appColors.border,
                          valueColor: AlwaysStoppedAnimation<Color>(catColor),
                          minHeight: 5,
                        ),
                      ),
                      if (cat.reasoning.isNotEmpty) ...[
                        SizedBox(height: 6),
                        Text(
                          cat.reasoning,
                          style: TextStyle(
                            color: context.appColors.textSecondary,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
            SizedBox(height: 14),
          ],

          // ─── Stats row ───
          Row(
            children: [
              _StatCard(
                label: 'Issues',
                value:
                    '${_result!.criticalIssues.isNotEmpty ? _result!.criticalIssues.length : _result!.issues.length}',
                icon: '⚠️',
                color: AppColors.scoreOrange,
              ),
              SizedBox(width: 12),
              _StatCard(
                label: 'Missing Keywords',
                value: '${_result!.missingKeywords.length}',
                icon: '🔑',
                color: AppColors.scoreRed,
              ),
              SizedBox(width: 12),
              _StatCard(
                label: 'Keywords Found',
                value:
                    '${_result!.matchedKeywords.isNotEmpty ? _result!.matchedKeywords.length : _result!.keywords.length}',
                icon: '✅',
                color: AppColors.scoreGreen,
              ),
            ],
          ),

          // ─── Top 3 Wins ───
          if (_result!.top3Wins.isNotEmpty) ...[
            SizedBox(height: 24),
            SectionHeader(
              title: '🏆 What You\'re Doing Right',
              subtitle: 'Keep these strong',
            ),
            SizedBox(height: 14),
            GlassCard(
              child: Column(
                children: _result!.top3Wins
                    .asMap()
                    .entries
                    .map(
                      (e) => Padding(
                        padding: EdgeInsets.only(
                          bottom: e.key < _result!.top3Wins.length - 1 ? 10 : 0,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: AppColors.scoreGreen.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  '✅',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                e.value,
                                style: TextStyle(
                                  color: context.appColors.textPrimary,
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],

          // ─── Top 3 Improvements ───
          if (_result!.top3Improvements.isNotEmpty) ...[
            SizedBox(height: 24),
            SectionHeader(
              title: '🔧 Quick Wins',
              subtitle: 'Fix these first for max score boost',
            ),
            SizedBox(height: 14),
            GlassCard(
              child: Column(
                children: _result!.top3Improvements
                    .asMap()
                    .entries
                    .map(
                      (e) => Padding(
                        padding: EdgeInsets.only(
                          bottom: e.key < _result!.top3Improvements.length - 1
                              ? 10
                              : 0,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: AppColors.scoreOrange.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  '🔧',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                e.value,
                                style: TextStyle(
                                  color: context.appColors.textPrimary,
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],

          // ─── Critical Issues ───
          if (_result!.criticalIssues.isNotEmpty) ...[
            SizedBox(height: 24),
            SectionHeader(
              title: 'Critical Issues',
              subtitle: 'Fix these to improve your score',
              trailing: GradientBadge(
                text: '${_result!.criticalIssues.length}',
                gradient: AppColors.goldGradient,
              ),
            ),
            SizedBox(height: 14),
            ..._result!.criticalIssues.map((issue) {
              final priorityColor = issue.priority == 'high'
                  ? AppColors.scoreRed
                  : issue.priority == 'medium'
                  ? AppColors.scoreOrange
                  : context.appColors.textSecondary;
              return Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              issue.issue,
                              style: TextStyle(
                                color: context.appColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          _badge(issue.priority.toUpperCase(), priorityColor),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '→ ',
                            style: TextStyle(
                              color: AppColors.scoreGreen,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              issue.fix,
                              style: TextStyle(
                                color: AppColors.scoreGreen,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ] else if (_result!.issues.isNotEmpty) ...[
            // Fallback for old schema
            SizedBox(height: 24),
            SectionHeader(
              title: 'Issues Found',
              subtitle: 'Fix these to improve your score',
              trailing: GradientBadge(
                text: '${_result!.issues.length}',
                gradient: AppColors.goldGradient,
              ),
            ),
            SizedBox(height: 14),
            ..._result!.issues.asMap().entries.map(
              (e) => Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.scoreOrange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text('⚠️', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.value,
                              style: TextStyle(
                                color: context.appColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            if (_result!.fixes.length > e.key) ...[
                              SizedBox(height: 6),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '→ ',
                                    style: TextStyle(
                                      color: AppColors.scoreGreen,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      _result!.fixes[e.key],
                                      style: TextStyle(
                                        color: AppColors.scoreGreen,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],

          // ─── Boolean Keyword Filter — Pass/Fail (Fix 5) ───────────────────────
          // A deterministic, non-AI substring check. Simulates the hard AND filter
          // recruiters run before they even look at a resume. No competitor shows this.
          if (_result!.missingKeywords.isNotEmpty || _result!.matchedKeywords.isNotEmpty) ...[
            SizedBox(height: 24),
            SectionHeader(
              title: '🔍 Boolean Filter Simulation',
              subtitle: 'Would you pass the recruiter\'s keyword AND filter?',
            ),
            SizedBox(height: 14),
            Builder(builder: (context) {
              final resumeText = ref
                  .read(resumeNotifierProvider(widget.resumeId))
                  ?.sections
                  .toString()
                  .toLowerCase() ?? '';
              // Run deterministic substring check on all required keywords
              final allRequired = [
                ..._result!.matchedKeywords,
                ..._result!.missingKeywords,
              ];
              final passed = allRequired
                  .where((k) => resumeText.contains(k.toLowerCase()))
                  .toList();
              final failed = allRequired
                  .where((k) => !resumeText.contains(k.toLowerCase()))
                  .toList();
              final passRate = allRequired.isEmpty
                  ? 100
                  : ((passed.length / allRequired.length) * 100).round();
              final filterPassed = failed.isEmpty;
              return GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: (filterPassed
                                    ? AppColors.scoreGreen
                                    : AppColors.scoreRed)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(
                              color: (filterPassed
                                      ? AppColors.scoreGreen
                                      : AppColors.scoreRed)
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            filterPassed
                                ? '✅ PASSES FILTER'
                                : '❌ BLOCKED BY FILTER',
                            style: TextStyle(
                              color: filterPassed
                                  ? AppColors.scoreGreen
                                  : AppColors.scoreRed,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '$passRate% match',
                          style: TextStyle(
                            color: context.appColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (failed.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Hard-blocked by missing:',
                        style: TextStyle(
                          color: AppColors.scoreRed,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: failed
                            .take(10)
                            .map((k) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.scoreRed
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                        color: AppColors.scoreRed
                                            .withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    k,
                                    style: TextStyle(
                                      color: AppColors.scoreRed,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],

          // ─── Stale Keywords (Fix 4) ───────────────────────────────────────────
          if (_result!.staleKeywords.isNotEmpty) ...[
            SizedBox(height: 24),
            SectionHeader(
              title: '⏳ Stale Keywords',
              subtitle: 'Skills last used >5 years ago — may hurt Relevance score',
              trailing: GradientBadge(
                text: '${_result!.staleKeywords.length}',
                gradient: AppColors.accentGradient,
              ),
            ),
            SizedBox(height: 14),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'These skills appear in your resume but were only used in older roles. '
                    'If they are required by the JD, a recruiter may question their currency.',
                    style: TextStyle(
                      color: context.appColors.textSecondary,
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _result!.staleKeywords
                        .map((k) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.scoreOrange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: AppColors.scoreOrange
                                        .withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                '⏳ $k',
                                style: TextStyle(
                                  color: AppColors.scoreOrange,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ],

          // ─── Missing keywords ───
          if (_result!.missingKeywords.isNotEmpty) ...[
            SizedBox(height: 24),
            SectionHeader(
              title: 'Missing Keywords',
              subtitle: 'Add these to boost your score',
              trailing: GradientBadge(
                text: '${_result!.missingKeywords.length}',
                gradient: AppColors.accentGradient,
              ),
            ),
            SizedBox(height: 14),
            GlassCard(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _result!.missingKeywords
                    .map(
                      (k) => Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.scoreRed.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.scoreRed.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '+ ',
                                style: TextStyle(
                                  color: AppColors.scoreRed,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              TextSpan(text: k),
                            ],
                          ),
                          style: TextStyle(
                            color: AppColors.scoreRed,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],

          // ─── Found keywords ───
          if (_result!.matchedKeywords.isNotEmpty ||
              _result!.keywords.isNotEmpty) ...[
            SizedBox(height: 24),
            SectionHeader(
              title: 'Keywords Detected',
              subtitle: 'Already in your resume',
              trailing: GradientBadge(
                text:
                    '${_result!.matchedKeywords.isNotEmpty ? _result!.matchedKeywords.length : _result!.keywords.length}',
              ),
            ),
            SizedBox(height: 14),
            GlassCard(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    (_result!.matchedKeywords.isNotEmpty
                            ? _result!.matchedKeywords
                            : _result!.keywords)
                        .map(
                          (k) => Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.scoreGreen.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.scoreGreen.withValues(
                                  alpha: 0.3,
                                ),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              k,
                              style: TextStyle(
                                color: AppColors.scoreGreen,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                        .toList(),
              ),
            ),
          ],
          SizedBox(height: 24),

          // ─── Pending-changes preview banner ───
          if (_hasPendingChanges) ...[
            Container(
              decoration: BoxDecoration(
                color: AppColors.scoreGreen.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.scoreGreen.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('🎯', style: TextStyle(fontSize: 16)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Optimisation Preview — Not Yet Saved',
                          style: TextStyle(
                            color: AppColors.scoreGreen,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Review your resume in the editor, then confirm below. Your original is safely preserved.',
                    style: TextStyle(
                      color: context.appColors.textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: GradientButton(
                          label: 'Keep Changes',
                          color: AppColors.scoreGreen,
                          icon: Icon(
                            Icons.check_circle_outline_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          onPressed: _keepChanges,
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: GradientButton(
                          label: 'Revert',
                          color: context.appColors.textSecondary,
                          icon: Icon(
                            Icons.undo_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          onPressed: _revertChanges,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
          ],

          // ─── Optimize Resume button (only when score < 80 and no pending changes) ───
          if (_result!.score < 80 && !_hasPendingChanges) ...[
            GlassCard(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('⚡', style: TextStyle(fontSize: 18)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Optimize Resume',
                          style: TextStyle(
                            color: context.appColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    'AI will fix the issues above and improve your score. You review changes before saving.',
                    style: TextStyle(
                      color: context.appColors.textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: 14),
                  GradientButton(
                    label: _optimising ? 'Optimising...' : 'Optimize My Resume',
                    isLoading: _optimising,
                    color: AppColors.accent,
                    icon: _optimising
                        ? null
                        : Icon(
                            Icons.auto_fix_high_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                    onPressed: _optimising ? null : _optimiseResume,
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
          ],

          OutlinedButton.icon(
            onPressed: () => showAiReportDialog(
              context: context,
              ref: ref,
              feature: 'ats_analysis',
              output: _atsReportText(_result!),
            ),
            icon: Icon(Icons.flag_outlined, size: 18),
            label: Text('Report AI Output'),
          ),
        ],
      ),
    );
  }

  String _atsReportText(ATSResult result) {
    final buf = StringBuffer()
      ..writeln('Score: ${result.score}')
      ..writeln('Issues: ${result.issues.join('; ')}')
      ..writeln('Fixes: ${result.fixes.join('; ')}')
      ..writeln('Missing keywords: ${result.missingKeywords.join(', ')}')
      ..writeln('Matched keywords: ${result.matchedKeywords.join(', ')}')
      ..writeln('Wins: ${result.top3Wins.join('; ')}')
      ..writeln('Improvements: ${result.top3Improvements.join('; ')}');
    for (final issue in result.criticalIssues) {
      buf.writeln('${issue.priority}: ${issue.issue} -> ${issue.fix}');
    }
    return buf.toString();
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value, icon;
  final Color color;
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassCard(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Text(icon, style: TextStyle(fontSize: 20)),
            SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.appColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Keyword Picker Sheet ─────────────────────────────────────────────────────
/// Bottom sheet showing all missing keywords as toggleable chips.
/// All chips start UNSELECTED — user must explicitly pick what they have.
class _KeywordPickerSheet extends StatefulWidget {
  final List<String> keywords;
  const _KeywordPickerSheet({required this.keywords});

  @override
  State<_KeywordPickerSheet> createState() => _KeywordPickerSheetState();
}

class _KeywordPickerSheetState extends State<_KeywordPickerSheet> {
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = {}; // none pre-selected — user chooses what they actually have
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selected.length;

    return Container(
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.appColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          SizedBox(height: 20),

          Text(
            'Add Missing Keywords to Skills',
            style: TextStyle(
              color: context.appColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Only select skills you genuinely have. Unselected = not added.',
            style: TextStyle(
              color: context.appColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          SizedBox(height: 16),

          // Chip grid
          Flexible(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.keywords.map((kw) {
                  final isSelected = _selected.contains(kw);
                  return FilterChip(
                    label: Text(
                      kw,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : context.appColors.textPrimary,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() {
                        if (isSelected) {
                          _selected.remove(kw);
                        } else {
                          _selected.add(kw);
                        }
                      });
                    },
                    selectedColor: AppColors.primary,
                    backgroundColor: context.appColors.card,
                    checkmarkColor: Colors.white,
                    side: BorderSide(
                      color: isSelected
                          ? AppColors.primary
                          : context.appColors.border,
                      width: 1,
                    ),
                    showCheckmark: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          SizedBox(height: 20),

          // Selection count
          Text(
            '$selectedCount of ${widget.keywords.length} selected',
            style: TextStyle(
              color: selectedCount > 0
                  ? AppColors.primary
                  : context.appColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 12),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: GradientButton(
                  label: selectedCount == 0
                      ? 'Add Keywords'
                      : 'Add $selectedCount Keyword${selectedCount == 1 ? '' : 's'}',
                  color: selectedCount == 0
                      ? context.appColors.textMuted
                      : AppColors.primary,
                  onPressed: selectedCount == 0
                      ? null
                      : () => Navigator.pop(context, _selected.toList()),
                ),
              ),
              SizedBox(width: 10),
              TextButton(
                onPressed: () => Navigator.pop(context, <String>[]),
                child: Text(
                  'Skip',
                  style: TextStyle(
                    color: context.appColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
