import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/resume_provider.dart';

import 'sections/personal_info_section.dart';
import 'sections/experience_section.dart';
import 'sections/education_section.dart';
import 'sections/skills_section.dart';
import 'sections/projects_section.dart';
import 'sections/certifications_section.dart';

class ResumeEditorScreen extends ConsumerStatefulWidget {
  final String resumeId;
  const ResumeEditorScreen({super.key, required this.resumeId});
  
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
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_dirty) _save();
    });
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
      appBar: AppBar(
        title: resumeAsync.whenData((r) => r.title).value != null
            ? Text(resumeAsync.value!.title) : const Text('Edit Resume'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(_saveStatus, style: TextStyle(
                  color: _dirty ? Colors.orange : Colors.green, fontSize: 12)),
            ),
          ),
          IconButton(icon: const Icon(Icons.save), onPressed: _save),
          IconButton(icon: const Icon(Icons.visibility),
              onPressed: () => context.push('/preview/${widget.resumeId}')),
          PopupMenuButton(itemBuilder: (_) => [
            const PopupMenuItem(value: 'ats', child: Text('Check ATS Score')),
            const PopupMenuItem(value: 'jd', child: Text('Match Job Description')),
            const PopupMenuItem(value: 'cover', child: Text('Generate Cover Letter')),
          ], onSelected: (val) {
            if (val == 'ats') context.push('/ats/${widget.resumeId}');
            if (val == 'jd') context.push('/jd/${widget.resumeId}');
            if (val == 'cover') context.push('/cover-letter/${widget.resumeId}');
          }),
        ],
      ),
      body: resumeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (resume) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            PersonalInfoSection(
              resumeId: widget.resumeId,
              data: Map<String,dynamic>.from(resume.sections['personal'] ?? {}),
              onChanged: (d) {
                ref.read(resumeNotifierProvider(widget.resumeId).notifier)
                    .updateSection('personal', d);
                _onChanged();
              }),
            const SizedBox(height: 12),
            ExperienceSection(
              data: List<Map<String,dynamic>>.from(resume.sections['experience'] ?? []),
              targetRole: resume.targetRole,
              onChanged: (d) {
                ref.read(resumeNotifierProvider(widget.resumeId).notifier)
                    .updateSection('experience', d);
                _onChanged();
              }),
            const SizedBox(height: 12),
            EducationSection(
              data: List<Map<String,dynamic>>.from(resume.sections['education'] ?? []),
              onChanged: (d) {
                ref.read(resumeNotifierProvider(widget.resumeId).notifier)
                    .updateSection('education', d);
                _onChanged();
              }),
            const SizedBox(height: 12),
            SkillsSection(
              data: List<String>.from(resume.sections['skills'] ?? []),
              onChanged: (d) {
                ref.read(resumeNotifierProvider(widget.resumeId).notifier)
                    .updateSection('skills', d);
                _onChanged();
              }),
            const SizedBox(height: 12),
            ProjectsSection(
              data: List<Map<String,dynamic>>.from(resume.sections['projects'] ?? []),
              onChanged: (d) {
                ref.read(resumeNotifierProvider(widget.resumeId).notifier)
                    .updateSection('projects', d);
                _onChanged();
              }),
            const SizedBox(height: 12),
            CertificationsSection(
              data: List<Map<String,dynamic>>.from(resume.sections['certifications'] ?? []),
              onChanged: (d) {
                ref.read(resumeNotifierProvider(widget.resumeId).notifier)
                    .updateSection('certifications', d);
                _onChanged();
              }),
            const SizedBox(height: 80),
          ]),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/ats/${widget.resumeId}'),
        icon: const Icon(Icons.analytics),
        label: const Text('ATS Score'),
      ),
    );
  }
}
