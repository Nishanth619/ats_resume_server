import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/resume_model.dart';
import '../../services/ai_service.dart';
import '../../services/usage_tracker.dart';
import '../../services/admob_service.dart';
import '../../services/subscription_service.dart';
import '../../providers/resume_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../core/widgets/pro_upgrade_sheet.dart';
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
      if (mounted) showProUpgradeSheet(context, ref);
      throw Exception('limit_exceeded');
    }
  }

  Future<void> _showAdAndProceed() async {
    if (_bypassLimitsForTesting) return;

    final isPro = ref.read(subscriptionProvider);
    if (isPro) return;

    final adSvc = ref.read(adServiceProvider);
    await adSvc.loadRewardedAd();
    await adSvc.showRewardedAdAndWait(
      onAdWatched: () {},
      onAdFailed: () {},
    );
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
      // Show ad FIRST for free users
      await _showAdAndProceed();

      final resume = await fetchResumeRobustly(ref, widget.resumeId);

      final text = _serialize(resume);
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

  /// Safely converts any dynamic value to a plain String.
  /// Guards against Map/List stored where String is expected (e.g. after AI tailor).
  String _str(dynamic v) {
    if (v == null) return '';
    if (v is String) return v;
    if (v is Map) return v.values.map(_str).join(' ');
    if (v is List) return v.map(_str).join(', ');
    return v.toString();
  }

  String _serialize(ResumeModel resume) {
    final buf = StringBuffer();
    final p = (resume.sections['personal'] as Map?) ?? {};
    buf.writeln('${_str(p['name'])}\n${_str(p['email'])}\n${_str(p['phone'])}');
    buf.writeln('PROFESSIONAL SUMMARY\n${_str(p['summary'])}');
    buf.writeln('WORK EXPERIENCE');
    for (final e in (resume.sections['experience'] as List? ?? [])) {
      final em = e is Map ? e : <String, dynamic>{};
      buf.writeln(
        '${_str(em['title'])} at ${_str(em['company'])} (${_str(em['dates'])})\n'
        '${_str(em['description'])}',
      );
    }
    buf.writeln('EDUCATION');
    for (final e in (resume.sections['education'] as List? ?? [])) {
      final em = e is Map ? e : <String, dynamic>{};
      buf.writeln(
        '${_str(em['degree'])} - ${_str(em['institution'])} (${_str(em['year'])})',
      );
    }
    final skills = (resume.sections['skills'] as List? ?? [])
        .map((s) => _str(s))
        .where((s) => s.isNotEmpty)
        .join(', ');
    buf.writeln('SKILLS\n$skills');
    return buf.toString();
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
                      Text(
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
                gradient: context.appColors.primaryGradient,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.5),
                    blurRadius: 30,
                  ),
                ],
              ),
              child: Center(child: Text('🤖', style: TextStyle(fontSize: 44))),
            ),
          ),
          SizedBox(height: 28),
          ShaderMask(
            shaderCallback: (b) =>
                context.appColors.primaryGradient.createShader(b),
            child: Text(
              'Analysing Resume...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
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
                    ],
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
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '+ ',
                              style: TextStyle(
                                color: AppColors.scoreRed,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              k,
                              style: TextStyle(
                                color: AppColors.scoreRed,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
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
