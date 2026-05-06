import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/resume_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../services/pdf_service.dart';
import 'package:printing/printing.dart';

import 'sections/personal_info_section.dart';
import 'sections/experience_section.dart';
import 'sections/education_section.dart';
import 'sections/skills_section.dart';
import 'sections/projects_section.dart';
import 'sections/certifications_section.dart';
import 'sections/languages_section.dart';
import 'sections/awards_section.dart';

class ResumeEditorScreen extends ConsumerStatefulWidget {
  final String resumeId;
  final String? initialTemplate;
  const ResumeEditorScreen({super.key, required this.resumeId, this.initialTemplate});
  
  @override
  ConsumerState<ResumeEditorScreen> createState() => _State();
}

class _State extends ConsumerState<ResumeEditorScreen> {
  late Timer _autoSaveTimer;
  bool _dirty = false;
  String _saveStatus = 'Saved';

  @override
  void initState() {
    super.initState();
    _autoSaveTimer = Timer.periodic(Duration(seconds: 30), (_) {
      if (_dirty) _save();
    });
    
    if (widget.resumeId == 'new' && widget.initialTemplate != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Just delay slightly to ensure the stream provider has emitted the initial 'new' resume
        Future.delayed(Duration(milliseconds: 100), () {
          ref.read(resumeNotifierProvider(widget.resumeId).notifier)
             .setTemplate(widget.initialTemplate!);
        });
      });
    }
  }

  @override
  void dispose() {
    _autoSaveTimer.cancel();
    if (_dirty) _save();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saveStatus = 'Saving...');
    await ref.read(resumeNotifierProvider(widget.resumeId).notifier).save();
    setState(() { _dirty = false; _saveStatus = 'Saved'; });
  }

  void _onChanged() => setState(() { _dirty = true; _saveStatus = 'Unsaved'; });

  @override
  Widget build(BuildContext context) {
    final resumeAsync = ref.watch(resumeStreamProvider(widget.resumeId));

    return Scaffold(
      backgroundColor: context.appColors.bg,
      appBar: GradientAppBar(
        title: resumeAsync.whenData((r) => r.title).value ?? 'Edit Resume',
        actions: [
          Center(
            child: Container(
              margin: EdgeInsets.only(right: 8),
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _dirty 
                    ? AppColors.scoreOrange.withValues(alpha: 0.15) 
                    : AppColors.scoreGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _dirty 
                      ? AppColors.scoreOrange.withValues(alpha: 0.3) 
                      : AppColors.scoreGreen.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _dirty ? Icons.pending_outlined : Icons.check_circle_outline,
                    size: 14,
                    color: _dirty ? AppColors.scoreOrange : AppColors.scoreGreen,
                  ),
                  SizedBox(width: 4),
                  Text(_saveStatus, style: TextStyle(
                      color: _dirty ? AppColors.scoreOrange : AppColors.scoreGreen, 
                      fontSize: 11, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.visibility_outlined, color: context.appColors.textPrimary, size: 22),
            onPressed: () => context.push('/preview/${widget.resumeId}')
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: context.appColors.textPrimary),
            color: context.appColors.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            itemBuilder: (_) => [
              _buildPopupItem('ats', Icons.analytics_outlined, 'Check ATS Score'),
              _buildPopupItem('jd', Icons.work_outline_rounded, 'Match Job Description'),
              _buildPopupItem('cover', Icons.mail_outline_rounded, 'Generate Cover Letter'),
            ],
            onSelected: (val) {
              if (val == 'ats') context.push('/ats/${widget.resumeId}');
              if (val == 'jd') context.push('/jd/${widget.resumeId}');
              if (val == 'cover') context.push('/cover-letter/${widget.resumeId}');
            }
          ),
          SizedBox(width: 8),
        ],
      ),
      body: resumeAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: AppColors.primaryLight)),
        error: (e, _) => Center(
          child: Text('Error: $e', style: TextStyle(color: context.appColors.textSecondary))),
        data: (resume) => LayoutBuilder(
          builder: (context, constraints) {
            final editor = ListView(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 100),
              children: [
                PersonalInfoSection(
                  resumeId: widget.resumeId,
                  data: Map<String,dynamic>.from(resume.sections['personal'] ?? {}),
                  onChanged: (d) {
                    ref.read(resumeNotifierProvider(widget.resumeId).notifier)
                        .updateSection('personal', d);
                    _onChanged();
                  }),
                SizedBox(height: 16),
                ExperienceSection(
                  data: List<Map<String,dynamic>>.from(resume.sections['experience'] ?? []),
                  targetRole: resume.targetRole,
                  onChanged: (d) {
                    ref.read(resumeNotifierProvider(widget.resumeId).notifier)
                        .updateSection('experience', d);
                    _onChanged();
                  }),
                SizedBox(height: 16),
                EducationSection(
                  data: List<Map<String,dynamic>>.from(resume.sections['education'] ?? []),
                  onChanged: (d) {
                    ref.read(resumeNotifierProvider(widget.resumeId).notifier)
                        .updateSection('education', d);
                    _onChanged();
                  }),
                SizedBox(height: 16),
                SkillsSection(
                  data: List<String>.from(resume.sections['skills'] ?? []),
                  onChanged: (d) {
                    ref.read(resumeNotifierProvider(widget.resumeId).notifier)
                        .updateSection('skills', d);
                    _onChanged();
                  }),
                SizedBox(height: 16),
                ProjectsSection(
                  data: List<Map<String,dynamic>>.from(resume.sections['projects'] ?? []),
                  onChanged: (d) {
                    ref.read(resumeNotifierProvider(widget.resumeId).notifier)
                        .updateSection('projects', d);
                    _onChanged();
                  }),
                SizedBox(height: 16),
                CertificationsSection(
                  data: List<Map<String,dynamic>>.from(resume.sections['certifications'] ?? []),
                  onChanged: (d) {
                    ref.read(resumeNotifierProvider(widget.resumeId).notifier)
                        .updateSection('certifications', d);
                    _onChanged();
                  }),
                SizedBox(height: 16),
                AwardsSection(
                  data: List<Map<String,dynamic>>.from(resume.sections['awards'] ?? []),
                  onChanged: (d) {
                    ref.read(resumeNotifierProvider(widget.resumeId).notifier)
                        .updateSection('awards', d);
                    _onChanged();
                  }),
                SizedBox(height: 16),
                LanguagesSection(
                  data: List<Map<String,dynamic>>.from(resume.sections['languages'] ?? []),
                  onChanged: (d) {
                    ref.read(resumeNotifierProvider(widget.resumeId).notifier)
                        .updateSection('languages', d);
                    _onChanged();
                  }),
              ]);

            if (constraints.maxWidth > 800) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 1, child: editor),
                  VerticalDivider(width: 1, color: context.appColors.border),
                  Expanded(
                    flex: 1,
                    child: Container(
                      color: context.appColors.surface,
                      child: PdfPreview(
                        build: (format) async => await PDFService().generatePDFBytes(resume),
                        allowPrinting: false,
                        allowSharing: false,
                        canChangePageFormat: false,
                        canChangeOrientation: false,
                        pdfPreviewPageDecoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12, offset: Offset(0, 4)),
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
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: context.appColors.primaryGradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () => context.push('/ats/${widget.resumeId}'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: Icon(Icons.analytics_rounded, color: Colors.white),
          label: Text('ATS Score', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildPopupItem(String value, IconData icon, String text) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: context.appColors.textPrimary),
          SizedBox(width: 12),
          Text(text, style: TextStyle(color: context.appColors.textPrimary, fontSize: 14)),
        ],
      ),
    );
  }
}
