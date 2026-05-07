import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../providers/resume_provider.dart';
import '../../../services/pdf_service.dart';
import 'sections/awards_section.dart';
import 'sections/certifications_section.dart';
import 'sections/education_section.dart';
import 'sections/experience_section.dart';
import 'sections/languages_section.dart';
import 'sections/personal_info_section.dart';
import 'sections/projects_section.dart';
import 'sections/skills_section.dart';

class ResumeEditorScreen extends ConsumerStatefulWidget {
  final String resumeId;
  final String? initialTemplate;

  const ResumeEditorScreen({
    super.key,
    required this.resumeId,
    this.initialTemplate,
  });

  @override
  ConsumerState<ResumeEditorScreen> createState() => _ResumeEditorScreenState();
}

class _ResumeEditorScreenState extends ConsumerState<ResumeEditorScreen> {
  late final Timer _autoSaveTimer;
  bool _dirty = false;
  String _saveStatus = 'Saved';
  bool _templateInitialised = false;
  Object? _previewError;

  @override
  void initState() {
    super.initState();
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_dirty && mounted) _save();
    });
  }

  @override
  void dispose() {
    _autoSaveTimer.cancel();
    if (_dirty) {
      _dirty = false;
      ref.read(resumeNotifierProvider(widget.resumeId).notifier).save();
    }
    super.dispose();
  }

  void _maybeInitTemplate(dynamic resumeExists) {
    if (_templateInitialised) return;
    if (widget.resumeId != 'new') return;
    final template = widget.initialTemplate;
    if (template == null || template.isEmpty) return;
    _templateInitialised = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(resumeNotifierProvider(widget.resumeId).notifier)
          .setTemplate(template);
    });
  }

  Future<void> _save() async {
    if (!mounted) return;
    setState(() => _saveStatus = 'Saving...');
    try {
      await ref.read(resumeNotifierProvider(widget.resumeId).notifier).save();
      if (!mounted) return;
      setState(() {
        _dirty = false;
        _saveStatus = 'Saved';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _saveStatus = 'Save failed');
    }
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {
      _dirty = true;
      _saveStatus = 'Unsaved';
    });
  }

  Future<bool> _onWillPop() async {
    if (!_dirty) return true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.appColors.card,
        title: Text(
          'Unsaved changes',
          style: TextStyle(color: context.appColors.textPrimary),
        ),
        content: Text(
          'You have unsaved changes. Save before leaving?',
          style: TextStyle(color: context.appColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _dirty = false;
              Navigator.pop(ctx, true);
            },
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () async {
              await _save();
              if (ctx.mounted) Navigator.pop(ctx, true);
            },
            child: const Text('Save & leave'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  T _cloneSection<T>(T value) {
    if (value is Map) {
      return Map<String, dynamic>.from(
            value.map((k, v) => MapEntry(k, _cloneSection(v))),
          )
          as T;
    }
    if (value is List) {
      return value.map(_cloneSection).toList() as T;
    }
    return value;
  }

  Map<String, dynamic> _sectionMap(dynamic raw) =>
      _cloneSection(raw as Map? ?? {}) as Map<String, dynamic>;

  List<Map<String, dynamic>> _sectionList(dynamic raw) => (raw as List? ?? [])
      .map((e) => _cloneSection(e) as Map<String, dynamic>)
      .toList();

  List<String> _sectionStrList(dynamic raw) =>
      List<String>.from(raw as List? ?? []);

  @override
  Widget build(BuildContext context) {
    final resumeAsync = ref.watch(resumeStreamProvider(widget.resumeId));

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: context.appColors.bg,
        appBar: GradientAppBar(
          title: resumeAsync.whenData((r) => r.title).value ?? 'Edit Resume',
          actions: [
            _SaveStatusChip(dirty: _dirty, label: _saveStatus),
            IconButton(
              icon: Icon(
                Icons.visibility_outlined,
                color: context.appColors.textPrimary,
                size: 22,
              ),
              onPressed: () => context.push('/preview/${widget.resumeId}'),
            ),
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert_rounded,
                color: context.appColors.textPrimary,
              ),
              color: context.appColors.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              itemBuilder: (_) => [
                _menuItem('ats', Icons.analytics_outlined, 'Check ATS Score'),
                _menuItem(
                  'tailor',
                  Icons.auto_fix_high_rounded,
                  'Auto-Tailor Resume',
                ),
                _menuItem(
                  'cover',
                  Icons.mail_outline_rounded,
                  'Generate Cover Letter',
                ),
              ],
              onSelected: (val) {
                if (val == 'ats') context.push('/ats/${widget.resumeId}');
                if (val == 'tailor') {
                  context.push('/auto-tailor/${widget.resumeId}');
                }
                if (val == 'cover') {
                  context.push('/cover-letter/${widget.resumeId}');
                }
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: resumeAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primaryLight),
          ),
          error: (e, _) => Center(
            child: Text(
              'Error: $e',
              style: TextStyle(color: context.appColors.textSecondary),
            ),
          ),
          data: (resume) {
            _maybeInitTemplate(resume);
            final editor = _buildEditor(resume);

            return LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 800) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 1, child: editor),
                      VerticalDivider(
                        width: 1,
                        color: context.appColors.border,
                      ),
                      Expanded(
                        flex: 1,
                        child: Container(
                          color: context.appColors.surface,
                          child: _previewError != null
                              ? _PreviewErrorPlaceholder(
                                  error: _previewError!,
                                  onRetry: () =>
                                      setState(() => _previewError = null),
                                )
                              : PdfPreview(
                                  build: (format) async {
                                    try {
                                      return await PDFService()
                                          .generatePDFBytes(resume);
                                    } catch (e) {
                                      if (mounted) {
                                        setState(() => _previewError = e);
                                      }
                                      rethrow;
                                    }
                                  },
                                  allowPrinting: false,
                                  allowSharing: false,
                                  canChangePageFormat: false,
                                  canChangeOrientation: false,
                                  pdfPreviewPageDecoration: BoxDecoration(
                                    color: Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.3,
                                        ),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ),
                    ],
                  );
                }
                return editor;
              },
            );
          },
        ),
        floatingActionButton: Container(
          decoration: BoxDecoration(
            gradient: context.appColors.primaryGradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: FloatingActionButton.extended(
            onPressed: () => context.push('/ats/${widget.resumeId}'),
            backgroundColor: Colors.transparent,
            elevation: 0,
            icon: const Icon(Icons.analytics_rounded, color: Colors.white),
            label: const Text(
              'ATS Score',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditor(dynamic resume) {
    final sections = resume.sections as Map;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
      children: [
        PersonalInfoSection(
          resumeId: widget.resumeId,
          data: _sectionMap(sections['personal']),
          onChanged: (d) {
            ref
                .read(resumeNotifierProvider(widget.resumeId).notifier)
                .updateSection('personal', d);
            _onChanged();
          },
        ),
        const SizedBox(height: 16),
        ExperienceSection(
          data: _sectionList(sections['experience']),
          targetRole: resume.targetRole as String,
          onChanged: (d) {
            ref
                .read(resumeNotifierProvider(widget.resumeId).notifier)
                .updateSection('experience', d);
            _onChanged();
          },
        ),
        const SizedBox(height: 16),
        EducationSection(
          data: _sectionList(sections['education']),
          onChanged: (d) {
            ref
                .read(resumeNotifierProvider(widget.resumeId).notifier)
                .updateSection('education', d);
            _onChanged();
          },
        ),
        const SizedBox(height: 16),
        SkillsSection(
          data: _sectionStrList(sections['skills']),
          onChanged: (d) {
            ref
                .read(resumeNotifierProvider(widget.resumeId).notifier)
                .updateSection('skills', d);
            _onChanged();
          },
        ),
        const SizedBox(height: 16),
        ProjectsSection(
          data: _sectionList(sections['projects']),
          onChanged: (d) {
            ref
                .read(resumeNotifierProvider(widget.resumeId).notifier)
                .updateSection('projects', d);
            _onChanged();
          },
        ),
        const SizedBox(height: 16),
        CertificationsSection(
          data: _sectionList(sections['certifications']),
          onChanged: (d) {
            ref
                .read(resumeNotifierProvider(widget.resumeId).notifier)
                .updateSection('certifications', d);
            _onChanged();
          },
        ),
        const SizedBox(height: 16),
        AwardsSection(
          data: _sectionList(sections['awards']),
          onChanged: (d) {
            ref
                .read(resumeNotifierProvider(widget.resumeId).notifier)
                .updateSection('awards', d);
            _onChanged();
          },
        ),
        const SizedBox(height: 16),
        LanguagesSection(
          data: _sectionList(sections['languages']),
          onChanged: (d) {
            ref
                .read(resumeNotifierProvider(widget.resumeId).notifier)
                .updateSection('languages', d);
            _onChanged();
          },
        ),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String text) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: context.appColors.textPrimary),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              color: context.appColors.textPrimary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _SaveStatusChip extends StatelessWidget {
  final bool dirty;
  final String label;

  const _SaveStatusChip({required this.dirty, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = dirty ? AppColors.scoreOrange : AppColors.scoreGreen;
    return Center(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              dirty ? Icons.pending_outlined : Icons.check_circle_outline,
              size: 14,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewErrorPlaceholder extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _PreviewErrorPlaceholder({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.picture_as_pdf_outlined,
              size: 48,
              color: context.appColors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              'Preview unavailable',
              style: TextStyle(
                color: context.appColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Could not render PDF preview.',
              style: TextStyle(
                color: context.appColors.textSecondary,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
