import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/ai_service.dart';
import '../../providers/resume_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/shared_widgets.dart';

class JDMatcherScreen extends ConsumerStatefulWidget {
  final String resumeId;
  const JDMatcherScreen({super.key, required this.resumeId});
  @override
  ConsumerState<JDMatcherScreen> createState() => _JDState();
}

class _JDState extends ConsumerState<JDMatcherScreen>
    with SingleTickerProviderStateMixin {
  final _jdCtrl = TextEditingController();
  KeywordMatchResult? _result;
  bool _loading = false;
  bool _tailoring = false;
  bool _tailored = false;
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
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _jdCtrl.dispose();
    super.dispose();
  }

  Future<void> _analyse() async {
    if (_jdCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please paste a job description first'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    setState(() => _loading = true);
    try {
      final resume = ref.read(resumeNotifierProvider(widget.resumeId));
      if (resume == null) {
        throw Exception('Could not load resume. Please go back to the editor and try again.');
      }
      await ref
          .read(resumeNotifierProvider(widget.resumeId).notifier)
          .updateTargetJD(_jdCtrl.text.trim());
      final buf = StringBuffer();
      final p = resume.sections['personal'] ?? {};
      buf.writeln('${p['summary'] ?? ''}');
      for (final e in (resume.sections['experience'] as List? ?? [])) {
        buf.writeln('${e['description'] ?? ''}');
      }
      buf.writeln((resume.sections['skills'] as List? ?? []).join(', '));
      final result =
          await ref.read(aiServiceProvider).matchJD(buf.toString(), _jdCtrl.text);
      setState(() {_result = result; _loading = false;});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _tailorResume() async {
    final jd = _jdCtrl.text.trim();
    if (jd.isEmpty) return;
    setState(() => _tailoring = true);
    try {
      final aiService = ref.read(aiServiceProvider);
      await ref
          .read(resumeNotifierProvider(widget.resumeId).notifier)
          .tailorToJD(jd, aiService);
      if (mounted) {
        setState(() { _tailoring = false; _tailored = true; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Resume tailored and saved! Go back to review changes.'),
          backgroundColor: AppColors.scoreGreen,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 4),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _tailoring = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error tailoring resume: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: GradientAppBar(title: 'JD Matcher'),
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
                gradient: AppColors.accentGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.accent.withOpacity(0.4),
                      blurRadius: 30)
                ],
              ),
              child: Center(child: Text(
                _tailoring ? '✨' : '🔍',
                style: const TextStyle(fontSize: 40))),
            ),
          ),
          const SizedBox(height: 28),
          ShaderMask(
            shaderCallback: (b) => AppColors.accentGradient.createShader(b),
            child: Text(
              _tailoring ? 'Tailoring Your Resume...' : 'Matching Keywords...',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 10),
          Text(
            _tailoring 
              ? 'AI is rewriting your summary, experience\n& skills to match the job description'
              : 'Comparing your resume to the job description',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 32),
          const SizedBox(
            width: 200,
            child: LinearProgressIndicator(
              backgroundColor: AppColors.borderDark,
              valueColor:
                  AlwaysStoppedAnimation<Color>(AppColors.accent),
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
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
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
                      child: const Center(
                          child: Text('🔍', style: TextStyle(fontSize: 20))),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Job Description',
                              style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700)),
                          Text('Paste the full JD for best results',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.bgDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderDark),
                  ),
                  child: TextField(
                    controller: _jdCtrl,
                    maxLines: 7,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        height: 1.6),
                    decoration: const InputDecoration(
                      hintText:
                          'Paste the job description here...\n\nThe more detail, the better the match.',
                      hintStyle: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                          height: 1.6),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                GradientButton(
                  label: 'Analyse Match ✨',
                  onPressed: _analyse,
                  gradient: AppColors.accentGradient,
                  icon:
                      const Icon(Icons.analytics_outlined, color: Colors.white, size: 18),
                ),
              ],
            ),
          ),

          // Results
          if (_result != null) ...[
            const SizedBox(height: 24),

            // Match score card
            GlassCard(
              showGlow: true,
              glowColor: AppColors.scoreColor(_result!.matchPercentage),
              child: Column(
                children: [
                  ScoreRing(score: _result!.matchPercentage, radius: 68),
                  const SizedBox(height: 16),
                  Text(
                    _result!.matchPercentage >= 75
                        ? '🎉 Great match — Apply now!'
                        : _result!.matchPercentage >= 50
                            ? '👍 Decent match — Add missing keywords'
                            : '⚠️ Low match — Tailor your resume',
                    style: TextStyle(
                        color:
                            AppColors.scoreColor(_result!.matchPercentage),
                        fontWeight: FontWeight.w700,
                        fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  // Match bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _result!.matchPercentage / 100,
                      backgroundColor: AppColors.borderDark,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.scoreColor(_result!.matchPercentage)),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Two-column keyword results
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Matched keywords
                Expanded(
                  child: GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('✅ ', style: TextStyle(fontSize: 14)),
                            const Text('Matched',
                                style: TextStyle(
                                    color: AppColors.scoreGreen,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13)),
                            const Spacer(),
                            Text('${_result!.matched.length}',
                                style: const TextStyle(
                                    color: AppColors.scoreGreen,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _result!.matched
                              .map((k) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.scoreGreen
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                          color: AppColors.scoreGreen
                                              .withOpacity(0.3)),
                                    ),
                                    child: Text(k,
                                        style: const TextStyle(
                                            color: AppColors.scoreGreen,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600)),
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Missing keywords
                Expanded(
                  child: GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('❌ ', style: TextStyle(fontSize: 14)),
                            const Text('Missing',
                                style: TextStyle(
                                    color: AppColors.scoreRed,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13)),
                            const Spacer(),
                            Text('${_result!.missing.length}',
                                style: const TextStyle(
                                    color: AppColors.scoreRed,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _result!.missing
                              .map((k) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color:
                                          AppColors.scoreRed.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                          color: AppColors.scoreRed
                                              .withOpacity(0.3)),
                                    ),
                                    child: Text('+ $k',
                                        style: const TextStyle(
                                            color: AppColors.scoreRed,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600)),
                                  ))
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
              const SizedBox(height: 16),
              GlassCard(
                showGlow: true,
                glowColor: AppColors.accentGold,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('💡', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Pro Tip',
                              style: TextStyle(
                                  color: AppColors.accentGold,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14)),
                          const SizedBox(height: 4),
                          Text(
                            'Add the ${_result!.missing.take(3).join(', ')} keywords to your Skills or Summary section to significantly boost your match score.',
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Tailor My Resume CTA ──
            const SizedBox(height: 24),
            if (_tailored)
              GlassCard(
                showGlow: true,
                glowColor: AppColors.scoreGreen,
                child: Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.scoreGreen.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(child: Text('✅', style: TextStyle(fontSize: 22))),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Resume Tailored!',
                              style: TextStyle(color: AppColors.scoreGreen,
                                  fontWeight: FontWeight.w700, fontSize: 14)),
                          SizedBox(height: 2),
                          Text('Go back to the editor to review your AI-improved resume.',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              GlassCard(
                showGlow: true,
                glowColor: AppColors.primary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(child: Text('🪄', style: TextStyle(fontSize: 22))),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Auto-Tailor Resume',
                                  style: TextStyle(color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w700, fontSize: 15)),
                              SizedBox(height: 2),
                              Text('AI rewrites your summary, experience & skills to match this JD',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    GradientButton(
                      label: 'Tailor My Resume to this JD  🪄',
                      onPressed: _tailorResume,
                      gradient: AppColors.primaryGradient,
                      icon: const Icon(Icons.auto_fix_high_rounded, color: Colors.white, size: 18),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
