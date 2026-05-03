import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/ai_service.dart';
import '../../providers/resume_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/shared_widgets.dart';

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
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.95, end: 1.05)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Instantly get the in-memory resume (which includes unsaved edits)
      final resume = ref.read(resumeNotifierProvider(widget.resumeId));
      if (resume == null) {
        throw Exception('Could not load resume. Please go back to the editor and try again.');
      }

      final text = _serialize(resume);
      final result = await ref.read(aiServiceProvider).checkATS(
        text,
        targetJD: resume.targetJD.isNotEmpty ? resume.targetJD : null,
        sections: resume.sections,
      );
      // Only save score if it is meaningful (> 0)
      if (result.score > 0) {
        await ref
            .read(resumeNotifierProvider(widget.resumeId).notifier)
            .updateATSScore(result.score);
      }
      if (mounted) setState(() { _result = result; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _loading = false; });
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

  String _serialize(resume) {
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
      buf.writeln('${_str(em['degree'])} - ${_str(em['institution'])} (${_str(em['year'])})');
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
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: GradientAppBar(
        title: 'ATS Analysis',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
            onPressed: _loading ? null : _run,
          ),
        ],
      ),
      body: _loading
          ? _buildLoading()
          : _error != null
              ? _buildError()
              : _buildResults(),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, child) => Transform.scale(scale: _pulse.value, child: child),
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.5),
                    blurRadius: 30,
                  ),
                ],
              ),
              child: const Center(
                child: Text('🤖', style: TextStyle(fontSize: 44)),
              ),
            ),
          ),
          const SizedBox(height: 28),
          ShaderMask(
            shaderCallback: (b) => AppColors.primaryGradient.createShader(b),
            child: const Text('Analysing Resume...',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 10),
          const Text('Running 24-point ATS compatibility check',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 32),
          const SizedBox(
            width: 200,
            child: LinearProgressIndicator(
              backgroundColor: AppColors.borderDark,
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
        padding: const EdgeInsets.all(32),
        child: GlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⚠️', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              const Text('Analysis Failed',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 24),
              GradientButton(label: 'Retry Analysis', onPressed: _run),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_result == null) return const SizedBox();
    final score = _result!.score;
    final color = AppColors.scoreColor(score);
    final label = score >= 80
        ? 'Excellent — Ready to Apply!'
        : score >= 60
            ? 'Good — Minor Fixes Needed'
            : 'Needs Work — Fix Issues First';

    // Category labels for display
    const catLabels = {
      'keyword_match':     'Keyword Match',
      'impact_language':   'Impact Language',
      'structure':         'Structure',
      'relevance':         'Relevance',
      'ats_compatibility': 'ATS Compatibility',
    };
    const catIcons = {
      'keyword_match':     '🔑',
      'impact_language':   '⚡',
      'structure':         '📊',
      'relevance':         '🎯',
      'ats_compatibility': '🤖',
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(
        children: [
          // ─── Score card ───
          GlassCard(
            showGlow: true,
            glowColor: color,
            child: Column(
              children: [
                ScoreRing(score: score, radius: 72),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: color.withOpacity(0.3), width: 1),
                  ),
                  child: Text(label,
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                ),
                // Engine + cache badge
                if (_result!.engine.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_result!.cached)
                        _badge('⚡ Cached', AppColors.scoreGreen),
                      if (_result!.cached) const SizedBox(width: 8),
                      _badge(
                        _result!.engine == 'gemini' ? '🤖 Gemini 2.5' : '🧠 Llama 3',
                        AppColors.primary,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ─── 5-Category Breakdown ───
          if (_result!.categories.isNotEmpty) ...[
            const SectionHeader(
              title: 'Score Breakdown',
              subtitle: '5 categories • 20 pts each',
            ),
            const SizedBox(height: 14),
            ..._result!.categories.entries.map((entry) {
              final label = catLabels[entry.key] ?? entry.key;
              final icon = catIcons[entry.key] ?? '📌';
              final cat = entry.value;
              final catColor = AppColors.scoreColor(cat.score * 5); // scale /20 -> /100
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(icon, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(label,
                                style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13)),
                          ),
                          Text('${cat.score}/20',
                              style: TextStyle(
                                  color: catColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: cat.score / 20,
                          backgroundColor: AppColors.borderDark,
                          valueColor: AlwaysStoppedAnimation<Color>(catColor),
                          minHeight: 5,
                        ),
                      ),
                      if (cat.reasoning.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(cat.reasoning,
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                height: 1.4)),
                      ],
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 14),
          ],

          // ─── Stats row ───
          Row(
            children: [
              _StatCard(
                  label: 'Issues',
                  value: '${_result!.criticalIssues.isNotEmpty ? _result!.criticalIssues.length : _result!.issues.length}',
                  icon: '⚠️',
                  color: AppColors.scoreOrange),
              const SizedBox(width: 12),
              _StatCard(
                  label: 'Missing Keywords',
                  value: '${_result!.missingKeywords.length}',
                  icon: '🔑',
                  color: AppColors.scoreRed),
              const SizedBox(width: 12),
              _StatCard(
                  label: 'Keywords Found',
                  value: '${_result!.matchedKeywords.isNotEmpty ? _result!.matchedKeywords.length : _result!.keywords.length}',
                  icon: '✅',
                  color: AppColors.scoreGreen),
            ],
          ),

          // ─── Top 3 Wins ───
          if (_result!.top3Wins.isNotEmpty) ...[
            const SizedBox(height: 24),
            const SectionHeader(
              title: '🏆 What You\'re Doing Right',
              subtitle: 'Keep these strong',
            ),
            const SizedBox(height: 14),
            GlassCard(
              child: Column(
                children: _result!.top3Wins.asMap().entries.map((e) =>
                  Padding(
                    padding: EdgeInsets.only(bottom: e.key < _result!.top3Wins.length - 1 ? 10 : 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.scoreGreen.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(child: Text('✅', style: TextStyle(fontSize: 13))),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(e.value,
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 13, height: 1.5)),
                        ),
                      ],
                    ),
                  ),
                ).toList(),
              ),
            ),
          ],

          // ─── Top 3 Improvements ───
          if (_result!.top3Improvements.isNotEmpty) ...[
            const SizedBox(height: 24),
            const SectionHeader(
              title: '🔧 Quick Wins',
              subtitle: 'Fix these first for max score boost',
            ),
            const SizedBox(height: 14),
            GlassCard(
              child: Column(
                children: _result!.top3Improvements.asMap().entries.map((e) =>
                  Padding(
                    padding: EdgeInsets.only(bottom: e.key < _result!.top3Improvements.length - 1 ? 10 : 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.scoreOrange.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(child: Text('🔧', style: TextStyle(fontSize: 13))),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(e.value,
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 13, height: 1.5)),
                        ),
                      ],
                    ),
                  ),
                ).toList(),
              ),
            ),
          ],

          // ─── Critical Issues ───
          if (_result!.criticalIssues.isNotEmpty) ...[
            const SizedBox(height: 24),
            SectionHeader(
              title: 'Critical Issues',
              subtitle: 'Fix these to improve your score',
              trailing: GradientBadge(
                  text: '${_result!.criticalIssues.length}',
                  gradient: AppColors.goldGradient),
            ),
            const SizedBox(height: 14),
            ..._result!.criticalIssues.map((issue) {
              final priorityColor = issue.priority == 'high'
                  ? AppColors.scoreRed
                  : issue.priority == 'medium'
                      ? AppColors.scoreOrange
                      : AppColors.textSecondary;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(issue.issue,
                                style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                          ),
                          const SizedBox(width: 8),
                          _badge(issue.priority.toUpperCase(), priorityColor),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('→ ',
                              style: TextStyle(
                                  color: AppColors.scoreGreen,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                          Expanded(
                            child: Text(issue.fix,
                                style: const TextStyle(
                                    color: AppColors.scoreGreen,
                                    fontSize: 12, height: 1.4)),
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
            const SizedBox(height: 24),
            SectionHeader(
              title: 'Issues Found',
              subtitle: 'Fix these to improve your score',
              trailing: GradientBadge(
                  text: '${_result!.issues.length}',
                  gradient: AppColors.goldGradient),
            ),
            const SizedBox(height: 14),
            ..._result!.issues.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.scoreOrange.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(child: Text('⚠️', style: TextStyle(fontSize: 16))),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.value,
                                  style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13)),
                              if (_result!.fixes.length > e.key) ...[
                                const SizedBox(height: 6),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('→ ',
                                        style: TextStyle(
                                            color: AppColors.scoreGreen,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700)),
                                    Expanded(
                                      child: Text(_result!.fixes[e.key],
                                          style: const TextStyle(
                                              color: AppColors.scoreGreen,
                                              fontSize: 12)),
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
                )),
          ],

          // ─── Missing keywords ───
          if (_result!.missingKeywords.isNotEmpty) ...[
            const SizedBox(height: 24),
            SectionHeader(
              title: 'Missing Keywords',
              subtitle: 'Add these to boost your score',
              trailing: GradientBadge(
                  text: '${_result!.missingKeywords.length}',
                  gradient: AppColors.accentGradient),
            ),
            const SizedBox(height: 14),
            GlassCard(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _result!.missingKeywords
                    .map((k) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.scoreRed.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.scoreRed.withOpacity(0.3), width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('+ ', style: TextStyle(color: AppColors.scoreRed, fontSize: 11, fontWeight: FontWeight.w800)),
                              Text(k, style: const TextStyle(color: AppColors.scoreRed, fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],

          // ─── Found keywords ───
          if (_result!.matchedKeywords.isNotEmpty || _result!.keywords.isNotEmpty) ...[
            const SizedBox(height: 24),
            SectionHeader(
              title: 'Keywords Detected',
              subtitle: 'Already in your resume',
              trailing: GradientBadge(text: '${_result!.matchedKeywords.isNotEmpty ? _result!.matchedKeywords.length : _result!.keywords.length}'),
            ),
            const SizedBox(height: 14),
            GlassCard(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: (_result!.matchedKeywords.isNotEmpty ? _result!.matchedKeywords : _result!.keywords)
                    .map((k) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.scoreGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.scoreGreen.withOpacity(0.3), width: 1),
                          ),
                          child: Text(k, style: const TextStyle(color: AppColors.scoreGreen, fontSize: 12, fontWeight: FontWeight.w600)),
                        ))
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value, icon;
  final Color color;
  const _StatCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    height: 1.3)),
          ],
        ),
      ),
    );
  }
}
