import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/ai_service.dart';
import '../../services/usage_tracker.dart';
import '../../services/admob_service.dart';
import '../../services/ad_block_guard.dart';
import '../../services/subscription_service.dart';
import '../../providers/resume_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../core/widgets/ai_report_dialog.dart';
import '../../services/firestore_service.dart';
import '../../models/resume_model.dart';

class AutoTailorScreen extends ConsumerStatefulWidget {
  final String resumeId;
  const AutoTailorScreen({super.key, required this.resumeId});
  @override
  ConsumerState<AutoTailorScreen> createState() => _AutoTailorState();
}

class _AutoTailorState extends ConsumerState<AutoTailorScreen>
    with SingleTickerProviderStateMixin {
  final _jdCtrl = TextEditingController();
  KeywordMatchResult? _result;
  bool _loading = false;
  bool _tailoring = false;
  bool _hasPendingChanges = false;
  Map<String, dynamic>? _originalSections;
  TailoredResumeResult? _tailorResult;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

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
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _jdCtrl.dispose();
    super.dispose();
  }

  Future<bool> _checkUsage() async {
    final isPro = ref.read(subscriptionProvider);
    if (isPro) return true;

    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return false;

    final count = await UsageTracker.getUsageCount(AiFeature.autoTailor, uid);
    if (count >= UsageTracker.getLimit(AiFeature.autoTailor)) {
      if (mounted) {
        final uid = ref.read(userDataProvider).value?.uid ?? '';
        ref.read(subscriptionProvider.notifier).presentPaywall(uid: uid);
      }
      return false;
    }
    return true;
  }

  Future<bool> _showAdForTailor() async {
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

  Future<void> _incrementTailorUsage() async {
    final isPro = ref.read(subscriptionProvider);
    if (isPro) return;
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid != null) {
      await UsageTracker.incrementUsage(AiFeature.autoTailor, uid);
    }
  }

  Future<void> _analyse() async {
    if (_jdCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please paste a job description first'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final canUse = await _checkUsage();
    if (!canUse) return;

    setState(() => _loading = true);
    try {
      final resume = await fetchResumeRobustly(ref, widget.resumeId);
      await ref
          .read(resumeNotifierProvider(widget.resumeId).notifier)
          .updateTargetJD(_jdCtrl.text.trim());

      // Gate strictly on reward — blocks if ad skipped/blocked/no-fill
      final adOk = await _showAdForTailor();
      if (!adOk) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final result = await ref
          .read(aiServiceProvider)
          .matchJD(_resumeTextForMatching(resume.sections), _jdCtrl.text);

      await _incrementTailorUsage();

      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _tailorResume() async {
    final jd = _jdCtrl.text.trim();
    if (jd.isEmpty) return;

    final canUse = await _checkUsage();
    if (!canUse) return;

    setState(() => _tailoring = true);
    try {
      final aiService = ref.read(aiServiceProvider);

      // Show ad — gate strictly on reward
      final adOk = await _showAdForTailor();
      if (!adOk) {
        if (mounted) setState(() => _tailoring = false);
        return;
      }
      await _incrementTailorUsage();

      // Snapshot original sections before tailoring
      final resume = ref.read(resumeNotifierProvider(widget.resumeId));
      if (resume != null) {
        _originalSections = Map<String, dynamic>.from(resume.sections);
      }

      // ── Pass 1: Tailor resume content (dryRun)
      final result = await ref
          .read(resumeNotifierProvider(widget.resumeId).notifier)
          .tailorToJD(jd, aiService, dryRun: true);

      // ── Score after Pass 1 (uses ALL sections now)
      final tailoredResume = ref.read(resumeNotifierProvider(widget.resumeId));
      KeywordMatchResult? pass1Match;
      if (tailoredResume != null) {
        pass1Match = await aiService.matchJD(
          _resumeTextForMatching(tailoredResume.sections),
          jd,
        );
      }

      // ── Pass 2: Keyword picker (only if missing keywords)
      if (mounted && pass1Match != null && pass1Match.missing.isNotEmpty) {
        final selectedKeywords = await _showKeywordPicker(pass1Match.missing);
        if (selectedKeywords.isNotEmpty && mounted) {
          await ref
              .read(resumeNotifierProvider(widget.resumeId).notifier)
              .injectKeywords(selectedKeywords, dryRun: true);
        }
      }

      // ── Final score after Pass 2
      final finalResume = ref.read(resumeNotifierProvider(widget.resumeId));
      KeywordMatchResult? finalMatch;
      if (finalResume != null) {
        finalMatch = await aiService.matchJD(
          _resumeTextForMatching(finalResume.sections),
          jd,
        );
      }

      if (mounted) {
        setState(() {
          _tailoring = false;
          _hasPendingChanges = true;
          _tailorResult = result;
          _result = finalMatch ?? pass1Match;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎯 Tailoring complete! Review and save changes.'),
            backgroundColor: AppColors.scoreGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      // Dialog was already shown by AdBlockGuard — suppress the error snackbar.
      if (e.toString().contains('ad_blocked')) {
        if (mounted) setState(() => _tailoring = false);
        return;
      }
      if (mounted) {
        setState(() => _tailoring = false);
        _revertChanges(); // Clean up local state on error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error tailoring resume: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<List<String>> _showKeywordPicker(List<String> keywords) async {
    final selected = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _KeywordPickerSheet(keywords: keywords),
    );
    return selected ?? [];
  }

  Future<void> _keepChanges() async {
    if (!_hasPendingChanges) return;
    try {
      final uid = ref.read(authStateProvider).value?.uid;
      final resume = ref.read(resumeNotifierProvider(widget.resumeId));
      if (uid != null && resume != null && _originalSections != null) {
        await ref.read(firestoreServiceProvider).saveVersionSnapshot(
          uid,
          widget.resumeId,
          {...resume.toJson(), 'sections': _originalSections!}
            ..remove('versions'),
        );
      }
      await ref.read(resumeNotifierProvider(widget.resumeId).notifier).save();
      if (mounted) {
        setState(() {
          _hasPendingChanges = false;
          _originalSections = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Resume tailored and saved!'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.scoreGreen,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to save: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

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
      _tailorResult = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('↩ Changes discarded. Original resume restored.'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  String _resumeTextForMatching(Map<String, dynamic> sections) {
    final buf = StringBuffer();

    // Personal summary
    final p = sections['personal'] is Map ? sections['personal'] as Map : {};
    buf.writeln('${p['summary'] ?? ''}');

    // Experience (title + description)
    for (final e in (sections['experience'] as List? ?? [])) {
      if (e is! Map) continue;
      buf.writeln('${e['title'] ?? ''} ${e['company'] ?? ''}');
      buf.writeln('${e['description'] ?? ''}');
    }

    // Skills (comma-separated)
    final skills = (sections['skills'] as List? ?? [])
        .map((s) => s.toString())
        .where((s) => s.trim().isNotEmpty)
        .join(', ');
    buf.writeln(skills);

    // Projects — ADDED: AI rewrites these during tailoring
    for (final proj in (sections['projects'] as List? ?? [])) {
      if (proj is! Map) continue;
      buf.writeln('${proj['name'] ?? ''} ${proj['description'] ?? ''}');
    }

    // Education highlights — ADDED: AI adds highlights during tailoring
    for (final edu in (sections['education'] as List? ?? [])) {
      if (edu is! Map) continue;
      buf.writeln('${edu['degree'] ?? ''} ${edu['institution'] ?? ''} ${edu['highlights'] ?? ''}');
    }

    // Certifications — ADDED: AI reorders these during tailoring
    for (final cert in (sections['certifications'] as List? ?? [])) {
      if (cert is! Map) continue;
      buf.writeln('${cert['name'] ?? ''} ${cert['issuer'] ?? ''}');
    }

    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.bg,
      appBar: GradientAppBar(title: 'Auto-Tailor'),
      body: (_loading || _tailoring) ? _buildLoading() : _buildContent(),
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
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: context.appColors.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  _tailoring ? '✨' : '🔍',
                  style: TextStyle(fontSize: 40),
                ),
              ),
            ),
          ),
          SizedBox(height: 28),
          ShaderMask(
            shaderCallback: (b) => AppColors.accentGradient.createShader(b),
            child: Text(
              _tailoring ? 'Tailoring Your Resume...' : 'Matching Keywords...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(height: 10),
          Text(
            _tailoring
                ? 'AI is rewriting your summary, experience\n& skills to match the job description'
                : 'Comparing your resume to the job description',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.appColors.textSecondary,
              fontSize: 13,
            ),
          ),
          SizedBox(height: 32),
          SizedBox(
            width: 200,
            child: LinearProgressIndicator(
              backgroundColor: context.appColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
              minHeight: 3,
              borderRadius: BorderRadius.all(Radius.circular(4)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Input card
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: AppColors.accentGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text('🔍', style: TextStyle(fontSize: 20)),
                      ),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Job Description',
                            style: TextStyle(
                              color: context.appColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Paste the full JD for best results',
                            style: TextStyle(
                              color: context.appColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    color: context.appColors.bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.appColors.border),
                  ),
                  child: TextField(
                    controller: _jdCtrl,
                    maxLines: 7,
                    style: TextStyle(
                      color: context.appColors.textPrimary,
                      fontSize: 14,
                      height: 1.6,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          'Paste the job description here...\n\nThe more detail, the better the match.',
                      hintStyle: TextStyle(
                        color: context.appColors.textMuted,
                        fontSize: 13,
                        height: 1.6,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                GradientButton(
                  label: 'Analyse Match ✨',
                  onPressed: _analyse,
                  gradient: AppColors.accentGradient,
                  icon: Icon(
                    Icons.analytics_outlined,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),

          // Results
          if (_result != null) ...[
            SizedBox(height: 24),

            // Match score card
            GlassCard(
              showGlow: true,
              glowColor: AppColors.scoreColor(_result!.matchPercentage),
              child: Column(
                children: [
                  ScoreRing(score: _result!.matchPercentage, radius: 80),
                  SizedBox(height: 20),
                  Text(
                    _result!.matchPercentage >= 75
                        ? '🎉 Great match — Apply now!'
                        : _result!.matchPercentage >= 50
                        ? '👍 Decent match — Add missing keywords'
                        : '⚠️ Low match — Tailor your resume',
                    style: TextStyle(
                      color: AppColors.scoreColor(_result!.matchPercentage),
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  // Match bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _result!.matchPercentage / 100,
                      backgroundColor: context.appColors.border,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.scoreColor(_result!.matchPercentage),
                      ),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),

            // Two-column keyword results
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Matched keywords
                Expanded(
                  child: GlassCard(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('✅ ', style: TextStyle(fontSize: 14)),
                            Text(
                              'Matched',
                              style: TextStyle(
                                color: AppColors.scoreGreen,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            Spacer(),
                            Text(
                              '${_result!.matched.length}',
                              style: TextStyle(
                                color: AppColors.scoreGreen,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _result!.matched
                              .map(
                                (k) => Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.scoreGreen.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: AppColors.scoreGreen.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    k,
                                    style: TextStyle(
                                      color: AppColors.scoreGreen,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 12),
                // Missing keywords
                Expanded(
                  child: GlassCard(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('❌ ', style: TextStyle(fontSize: 14)),
                            Text(
                              'Missing',
                              style: TextStyle(
                                color: AppColors.scoreRed,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            Spacer(),
                            Text(
                              '${_result!.missing.length}',
                              style: TextStyle(
                                color: AppColors.scoreRed,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _result!.missing
                              .map(
                                (k) => Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.scoreRed.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: AppColors.scoreRed.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    '+ $k',
                                    style: TextStyle(
                                      color: AppColors.scoreRed,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Tip card
            if (_result!.missing.isNotEmpty) ...[
              SizedBox(height: 16),
              GlassCard(
                showGlow: true,
                glowColor: AppColors.accentGold,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('💡', style: TextStyle(fontSize: 22)),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pro Tip',
                            style: TextStyle(
                              color: AppColors.accentGold,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Add the ${_result!.missing.take(3).join(', ')} keywords to your Skills or Summary section to significantly boost your match score.',
                            style: TextStyle(
                              color: context.appColors.textSecondary,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Tailor My Resume CTA ──
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
                            'Tailoring Preview — Not Yet Saved',
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
            ] else ...[
              GlassCard(
                showGlow: true,
                glowColor: AppColors.primary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text('🪄', style: TextStyle(fontSize: 22)),
                          ),
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Auto-Tailor Resume',
                                style: TextStyle(
                                  color: context.appColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'AI rewrites your summary, experience & skills to match this JD',
                                style: TextStyle(
                                  color: context.appColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    GradientButton(
                      label: 'Tailor My Resume to this JD  🪄',
                      onPressed: _tailorResume,
                      gradient: AppColors.primaryGradient,
                      icon: Icon(
                        Icons.auto_fix_high_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_hasPendingChanges && _tailorResult != null) ...[
              SizedBox(height: 16),
              _buildTailorAudit(_tailorResult!),
            ],
            if (_result != null) ...[
              SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => showAiReportDialog(
                  context: context,
                  ref: ref,
                  feature: _hasPendingChanges ? 'auto_tailor' : 'keyword_match',
                  output: _autoTailorReportText(),
                  inputContext: _jdCtrl.text.trim(),
                ),
                icon: Icon(Icons.flag_outlined, size: 18),
                label: Text('Report AI Output'),
              ),
            ],
          ],
        ],
      ),
    );
  }

  String _autoTailorReportText() {
    final buf = StringBuffer();
    final result = _result;
    if (result != null) {
      buf
        ..writeln('Match: ${result.matchPercentage}')
        ..writeln('Required: ${result.requiredKeywords.join(', ')}')
        ..writeln('Matched: ${result.matched.join(', ')}')
        ..writeln('Missing: ${result.missing.join(', ')}');
    }
    final tailor = _tailorResult;
    if (tailor != null) {
      buf
        ..writeln('Target role: ${tailor.targetRole}')
        ..writeln('Summary: ${tailor.summary}')
        ..writeln('Skills: ${tailor.skills.join(', ')}')
        ..writeln('Warnings: ${tailor.warnings.join('; ')}')
        ..writeln('Changes: ${tailor.changes}');
    }
    return buf.toString();
  }

  Widget _buildTailorAudit(TailoredResumeResult result) {
    final changes = result.changes;
    final warnings = result.warnings;

    return GlassCard(
      showGlow: true,
      glowColor: AppColors.scoreGreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.fact_check_outlined,
                color: AppColors.scoreGreen,
                size: 22,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Review Applied Changes',
                  style: TextStyle(
                    color: context.appColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          if (changes.isEmpty)
            Text(
              'The resume was saved, but the AI did not return a detailed change list.',
              style: TextStyle(
                color: context.appColors.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            )
          else
            ...changes.map(_buildChangeItem),
          if (warnings.isNotEmpty) ...[
            SizedBox(height: 14),
            Text(
              'Not added because it was not supported by your resume:',
              style: TextStyle(
                color: AppColors.scoreOrange,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 8),
            ...warnings.map(
              (warning) => Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text(
                  '- $warning',
                  style: TextStyle(
                    color: context.appColors.textSecondary,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ),
            ),
          ],
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/preview/${widget.resumeId}'),
                  icon: Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: Text('Preview PDF'),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: Icon(Icons.edit_outlined, size: 18),
                  label: Text('Editor'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChangeItem(Map<String, dynamic> change) {
    final section = (change['section'] ?? 'resume').toString();
    final before = (change['before'] ?? '').toString();
    final after = (change['after'] ?? '').toString();
    final reason = (change['reason'] ?? '').toString();

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.toUpperCase(),
            style: TextStyle(
              color: AppColors.scoreGreen,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (reason.isNotEmpty) ...[
            SizedBox(height: 4),
            Text(
              reason,
              style: TextStyle(
                color: context.appColors.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
          if (before.isNotEmpty) ...[
            SizedBox(height: 8),
            Text(
              'Before: $before',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.appColors.textMuted,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
          if (after.isNotEmpty) ...[
            SizedBox(height: 6),
            Text(
              'After: $after',
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.appColors.textPrimary,
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
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
