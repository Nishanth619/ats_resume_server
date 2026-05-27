import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../models/resume_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/resume_provider.dart';
import '../../services/ai_service.dart';
import '../../services/firestore_service.dart';
import '../../services/usage_tracker.dart';

// ─── States ──────────────────────────────────────────────────────────────────
enum _UploadStep { pick, parsing, preview, done }

class UploadResumeScreen extends ConsumerStatefulWidget {
  const UploadResumeScreen({super.key});

  @override
  ConsumerState<UploadResumeScreen> createState() => _UploadResumeScreenState();
}

class _UploadResumeScreenState extends ConsumerState<UploadResumeScreen>
    with SingleTickerProviderStateMixin {
  _UploadStep _step = _UploadStep.pick;
  String? _error;
  String? _fileName;
  ParsedResumeResult? _parsed;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Step 1: File pick ────────────────────────────────────────────────────
  Future<void> _pickFile() async {
    setState(() => _error = null);

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      setState(() => _error = 'Could not read file. Please try again.');
      return;
    }

    if (bytes.length > 10 * 1024 * 1024) {
      setState(() => _error = 'File too large. Maximum size is 10 MB.');
      return;
    }

    _fileName = file.name;
    await _checkLimitAndParse(base64Encode(bytes), file.name);
  }

  // ── Usage check + parsing ────────────────────────────────────────────────
  Future<void> _checkLimitAndParse(String pdfBase64, String fileName) async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;

    // Check if user already has a resume with the same file name (duplicate guard)
    final existing = ref.read(resumeListProvider).value ?? [];
    final duplicate = existing.where(
      (r) => r.title.toLowerCase().trim() ==
          fileName.replaceAll('.pdf', '').toLowerCase().trim(),
    ).firstOrNull;

    if (duplicate != null && mounted) {
      final proceed = await _showDuplicateDialog(duplicate);
      if (!proceed) return;
    }

    setState(() {
      _step = _UploadStep.parsing;
      _error = null;
    });

    try {
      final result = await ref.read(aiServiceProvider).parseResume(
            pdfBase64: pdfBase64,
            fileName: fileName,
          );

      if (mounted) {
        setState(() {
          _parsed = result;
          _step = _UploadStep.preview;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _step = _UploadStep.pick;
        });
      }
    }
  }

  Future<bool> _showDuplicateDialog(ResumeModel existing) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: context.appColors.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    color: AppColors.scoreOrange, size: 22),
                const SizedBox(width: 10),
                Text(
                  'Similar Resume Found',
                  style: TextStyle(
                    color: context.appColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            content: Text(
              'You already have a resume called "${existing.title}". Do you want to upload a new copy anyway?',
              style: TextStyle(
                color: context.appColors.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: context.appColors.textSecondary),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Upload Anyway'),
              ),
            ],
          ),
        ) ??
        false;
  }

  // ── Step 3: Save to Firestore + navigate ─────────────────────────────────
  ResumeModel? _createdResume; // keep the full model, not just the id

  Future<ResumeModel> _createResumeInFirestore() async {
    if (_createdResume != null) return _createdResume!;

    final uid = ref.read(authStateProvider).value!.uid;
    final p = _parsed!;

    // Build the resume with a placeholder id — Firestore will assign the real one
    final resume = ResumeModel(
      id: '',
      title: p.title.isNotEmpty ? p.title : (_fileName?.replaceAll('.pdf', '') ?? 'Uploaded Resume'),
      lastEdited: DateTime.now(),
      targetRole: p.targetRole,
      sections: p.sections,
    );

    final firestoreId = await ref
        .read(firestoreServiceProvider)
        .createResume(uid, resume);

    // Rebuild with the real Firestore document ID
    _createdResume = ResumeModel(
      id: firestoreId,
      title: resume.title,
      lastEdited: resume.lastEdited,
      targetRole: resume.targetRole,
      sections: resume.sections,
    );
    _createdResumeId = firestoreId;
    return _createdResume!;
  }

  Future<void> _navigateTo(String route) async {
    setState(() => _step = _UploadStep.done);
    try {
      final resume = await _createResumeInFirestore();

      // Pre-seed the notifier so the destination screen finds the resume
      // instantly without waiting for a Firestore stream round-trip
      if (mounted) {
        ref
            .read(resumeNotifierProvider(resume.id).notifier)
            .seed(resume);
      }

      if (mounted) context.pushReplacement('$route/${resume.id}');
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to save resume: ${e.toString().replaceFirst('Exception: ', '')}';
          _step = _UploadStep.preview;
        });
      }
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.bg,
      appBar: GradientAppBar(
        title: 'Upload Resume',
        actions: [
          if (_step == _UploadStep.preview)
            TextButton.icon(
              onPressed: () => setState(() {
                _step = _UploadStep.pick;
                _parsed = null;
                _fileName = null;
                _createdResumeId = null;
                _createdResume = null;
              }),
              icon: Icon(Icons.upload_file_rounded,
                  size: 18, color: AppColors.primaryLight),
              label: Text(
                'Re-upload',
                style: TextStyle(
                  color: AppColors.primaryLight,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: switch (_step) {
          _UploadStep.pick => _buildPickStep(),
          _UploadStep.parsing => _buildParsingStep(),
          _UploadStep.preview => _buildPreviewStep(),
          _UploadStep.done => _buildSavingStep(),
        },
      ),
    );
  }

  // ── Step 1 UI ─────────────────────────────────────────────────────────────
  Widget _buildPickStep() {
    return SingleChildScrollView(
      key: const ValueKey('pick'),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Upload Your Resume',
            style: TextStyle(
              color: context.appColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Our AI will extract your information and let you check ATS score, edit, or tailor it to any job.',
            style: TextStyle(
              color: context.appColors.textSecondary,
              fontSize: 14,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 32),

          // Drop zone card
          GestureDetector(
            onTap: _pickFile,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  width: 2,
                  strokeAlign: BorderSide.strokeAlignInside,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.picture_as_pdf_rounded,
                      color: AppColors.primary,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Tap to select PDF',
                    style: TextStyle(
                      color: context.appColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'PDF only · Max 10 MB',
                    style: TextStyle(
                      color: context.appColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.scoreRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.scoreRed.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AppColors.scoreRed, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: AppColors.scoreRed,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 36),

          // Usage info
          _UsageInfoBanner(),

          const SizedBox(height: 32),

          // What happens section
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What happens next?',
                  style: TextStyle(
                    color: context.appColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                ...[
                  ('🤖', 'AI reads your PDF', 'Gemini extracts all your experience, skills & education'),
                  ('✅', 'Review & confirm', 'See a summary of what was extracted'),
                  ('🚀', 'Choose your action', 'Check ATS score, edit resume, or tailor to a job'),
                ].map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.$1, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.$2,
                                style: TextStyle(
                                  color: context.appColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                item.$3,
                                style: TextStyle(
                                  color: context.appColors.textSecondary,
                                  fontSize: 11,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 2 UI ─────────────────────────────────────────────────────────────
  Widget _buildParsingStep() {
    return Center(
      key: const ValueKey('parsing'),
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
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.4), width: 2),
              ),
              child: const Center(
                child: Text('🤖', style: TextStyle(fontSize: 46)),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Reading Your Resume…',
            style: TextStyle(
              color: context.appColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Gemini AI is extracting your experience,\nskills, and education',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.appColors.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: 200,
            child: LinearProgressIndicator(
              backgroundColor: context.appColors.border,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 3,
              borderRadius: const BorderRadius.all(Radius.circular(4)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 3 UI ─────────────────────────────────────────────────────────────
  Widget _buildPreviewStep() {
    final p = _parsed!;
    final personal = p.sections['personal'] as Map? ?? {};

    return SingleChildScrollView(
      key: const ValueKey('preview'),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Success header
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.scoreGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.check_circle_rounded,
                      color: AppColors.scoreGreen, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Resume Parsed!',
                        style: TextStyle(
                          color: context.appColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        _fileName ?? 'Resume',
                        style: TextStyle(
                          color: context.appColors.textSecondary,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          SectionHeader(
            title: 'Extracted Data',
            subtitle: 'Review what was found in your resume',
          ),
          const SizedBox(height: 14),

          // Stats row
          Row(
            children: [
              _StatChip(
                icon: '💼',
                label: 'Jobs',
                value: '${p.experienceCount}',
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              _StatChip(
                icon: '🛠️',
                label: 'Skills',
                value: '${p.skillsCount}',
                color: AppColors.scoreGreen,
              ),
              const SizedBox(width: 10),
              _StatChip(
                icon: '🎓',
                label: 'Education',
                value:
                    '${(p.sections['education'] as List?)?.length ?? 0}',
                color: AppColors.accent,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Personal info preview
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PreviewRow(
                  icon: Icons.person_rounded,
                  label: 'Name',
                  value: p.name.isNotEmpty ? p.name : '—',
                ),
                _PreviewRow(
                  icon: Icons.email_rounded,
                  label: 'Email',
                  value: p.email.isNotEmpty ? p.email : '—',
                ),
                _PreviewRow(
                  icon: Icons.work_rounded,
                  label: 'Target Role',
                  value: p.targetRole.isNotEmpty ? p.targetRole : '—',
                ),
                if ((personal['location'] as String?)?.isNotEmpty == true)
                  _PreviewRow(
                    icon: Icons.location_on_rounded,
                    label: 'Location',
                    value: personal['location'] as String,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Skills preview
          if (p.skillsCount > 0) ...[
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Top Skills',
                    style: TextStyle(
                      color: context.appColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: (p.sections['skills'] as List)
                        .take(12)
                        .map((s) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.2)),
                              ),
                              child: Text(
                                s.toString(),
                                style: const TextStyle(
                                  color: AppColors.primaryLight,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                  if (p.skillsCount > 12)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '+${p.skillsCount - 12} more skills',
                        style: TextStyle(
                          color: context.appColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          SectionHeader(
            title: 'What do you want to do?',
            subtitle: 'Choose an action to continue',
          ),
          const SizedBox(height: 14),

          // Action buttons
          _ActionButton(
            icon: Icons.analytics_outlined,
            title: 'Check ATS Score',
            subtitle: 'See how your resume ranks against ATS filters',
            color: AppColors.primaryDark,
            onTap: () => _navigateTo('/ats'),
          ),
          const SizedBox(height: 10),
          _ActionButton(
            icon: Icons.edit_note_rounded,
            title: 'Edit Resume',
            subtitle: 'Open the full editor to refine any section',
            color: AppColors.scoreGreen,
            onTap: () => _navigateTo('/editor'),
          ),
          const SizedBox(height: 10),
          _ActionButton(
            icon: Icons.auto_fix_high_rounded,
            title: 'Tailor to Job Description',
            subtitle: 'AI rewrites your resume for a specific JD',
            color: AppColors.accent,
            onTap: () => _navigateTo('/auto-tailor'),
          ),
        ],
      ),
    );
  }

  // ── Step 4 UI (saving) ────────────────────────────────────────────────────
  Widget _buildSavingStep() {
    return Center(
      key: const ValueKey('done'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 20),
          Text(
            'Saving your resume…',
            style: TextStyle(
              color: context.appColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Usage info banner ────────────────────────────────────────────────────────
class _UsageInfoBanner extends ConsumerWidget {
  const _UsageInfoBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateProvider).value?.uid;
    if (uid == null) return const SizedBox.shrink();

    return FutureBuilder<int>(
      future: UsageTracker.getUsageCount(AiFeature.atsCheck, uid),
      builder: (context, snap) {
        final used = snap.data ?? 0;
        final limit = UsageTracker.getLimit(AiFeature.atsCheck);
        final remaining = (limit - used).clamp(0, limit);
        final isNearLimit = remaining <= 1;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isNearLimit
                ? AppColors.scoreOrange.withValues(alpha: 0.1)
                : AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isNearLimit
                  ? AppColors.scoreOrange.withValues(alpha: 0.3)
                  : AppColors.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isNearLimit
                    ? Icons.warning_amber_rounded
                    : Icons.upload_file_rounded,
                size: 16,
                color: isNearLimit ? AppColors.scoreOrange : AppColors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  remaining == 0
                      ? 'Daily limit reached — upgrade to Pro for unlimited uploads'
                      : '$remaining of $limit free uploads remaining today',
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
    );
  }
}

// ─── Helper widgets ───────────────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: context.appColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _PreviewRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: context.appColors.textMuted),
          const SizedBox(width: 10),
          Text(
            '$label: ',
            style: TextStyle(
              color: context.appColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: context.appColors.textPrimary,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: context.appColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: context.appColors.textSecondary,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: color,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
