import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/ai_service.dart';
import '../../services/firestore_service.dart';
import '../../providers/resume_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/shared_widgets.dart';

class CoverLetterScreen extends ConsumerStatefulWidget {
  final String resumeId;
  const CoverLetterScreen({super.key, required this.resumeId});
  @override
  ConsumerState<CoverLetterScreen> createState() => _CLState();
}

class _CLState extends ConsumerState<CoverLetterScreen>
    with SingleTickerProviderStateMixin {
  final _companyCtrl = TextEditingController();
  final _jdCtrl = TextEditingController();
  final _letterCtrl = TextEditingController();
  late AnimationController _shimmerCtrl;
  bool _loading = false;
  bool _generated = false;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    _companyCtrl.dispose();
    _jdCtrl.dispose();
    _letterCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (_companyCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please enter the company name'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    setState(() => _loading = true);
    try {
      final resume = ref.read(resumeStreamProvider(widget.resumeId)).value;
      final uid = ref.read(authStateProvider).value?.uid;
      if (resume == null || uid == null) return;
      final p = resume.sections['personal'] ?? {};
      final buf = StringBuffer();
      buf.writeln('${p['summary'] ?? ''}');
      for (final e in (resume.sections['experience'] as List? ?? [])) {
        buf.writeln('${e['title']} at ${e['company']}: ${e['description']}');
      }
      final letter = await ref.read(aiServiceProvider).generateCoverLetter(
            resumeText: buf.toString(),
            jd: _jdCtrl.text,
            company: _companyCtrl.text,
            name: p['name'] ?? '',
          );
      _letterCtrl.text = letter;
      await ref
          .read(firestoreServiceProvider)
          .saveCoverLetter(uid, widget.resumeId, letter, _companyCtrl.text);
      setState(() => _generated = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: GradientAppBar(title: 'Cover Letter Builder'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header card
            GlassCard(
              showGlow: true,
              glowColor: AppColors.accent,
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: AppColors.accentGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                        child: Text('✉️', style: TextStyle(fontSize: 24))),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AI Cover Letter',
                            style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w700)),
                        SizedBox(height: 2),
                        Text('Generated in seconds, tailored to the role',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Input card
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionHeader(
                      title: 'Job Details',
                      subtitle: 'Tell the AI where you\'re applying'),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _companyCtrl,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 15),
                    decoration: const InputDecoration(
                      labelText: 'Company Name *',
                      prefixIcon: Icon(Icons.business_outlined,
                          size: 20, color: AppColors.textMuted),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _jdCtrl,
                    maxLines: 4,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 14),
                    decoration: const InputDecoration(
                      labelText: 'Job Description (optional but recommended)',
                      alignLabelWithHint: true,
                      prefixIcon: Padding(
                        padding: EdgeInsets.only(bottom: 60),
                        child: Icon(Icons.description_outlined,
                            size: 20, color: AppColors.textMuted),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  GradientButton(
                    label: _loading ? 'Generating...' : 'Generate with AI ✨',
                    onPressed: _loading ? null : _generate,
                    isLoading: _loading,
                    gradient: AppColors.accentGradient,
                  ),
                ],
              ),
            ),

            // Result card
            if (_generated && _letterCtrl.text.isNotEmpty) ...[
              const SizedBox(height: 20),
              GlassCard(
                showGlow: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SectionHeader(title: 'Your Cover Letter'),
                        IconButton(
                          icon: const Icon(Icons.copy_outlined,
                              color: AppColors.textSecondary, size: 20),
                          onPressed: () {
                            Clipboard.setData(
                                ClipboardData(text: _letterCtrl.text));
                            ScaffoldMessenger.of(context)
                                .showSnackBar(const SnackBar(
                              content: Text('Copied to clipboard!'),
                              behavior: SnackBarBehavior.floating,
                            ));
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.bgDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderDark),
                      ),
                      child: TextField(
                        controller: _letterCtrl,
                        maxLines: null,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            height: 1.7),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    GradientButton(
                      label: 'Download FREE — Watch Short Ad',
                      onPressed: () => context.push('/download/${widget.resumeId}'),
                      icon: const Icon(Icons.download_rounded,
                          color: Colors.white, size: 18),
                      gradient: AppColors.goldGradient,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
