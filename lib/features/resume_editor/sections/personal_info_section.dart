import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../../services/ai_service.dart';
import '../../../services/storage_service.dart';
import '../../../providers/resume_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/widgets/ai_report_dialog.dart';

class PersonalInfoSection extends ConsumerStatefulWidget {
  final String resumeId;
  final Map<String, dynamic> data;
  final ValueChanged<Map<String, dynamic>> onChanged;

  const PersonalInfoSection({
    super.key,
    required this.resumeId,
    required this.data,
    required this.onChanged,
  });

  @override
  ConsumerState<PersonalInfoSection> createState() => _PersonalInfoState();
}

class _PersonalInfoState extends ConsumerState<PersonalInfoSection>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late Map<String, dynamic> _data;
  late TextEditingController _summaryController;
  bool _isGeneratingSummary = false;
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _data = Map.from(widget.data);
    _summaryController = TextEditingController(text: _data['summary'] ?? '');
  }

  @override
  void didUpdateWidget(covariant PersonalInfoSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    try {
      final newJson = jsonEncode(widget.data);
      final currentJson = jsonEncode(_data);
      if (newJson != currentJson) {
        _data = Map.from(widget.data);
        if (_summaryController.text != (_data['summary'] ?? '')) {
          _summaryController.text = _data['summary'] ?? '';
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _summaryController.dispose();
    super.dispose();
  }

  void _update(String key, String value) {
    _data[key] = value;
    widget.onChanged(_data);
  }

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;

    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    setState(() => _isUploadingPhoto = true);
    try {
      // Read as bytes to avoid FileSystemException on content:// URIs (Android 13+)
      final bytes = await picked.readAsBytes();

      // Determine extension from original filename
      final ext = picked.name.contains('.')
          ? picked.name.split('.').last.toLowerCase()
          : 'jpg';

      // Write to app cache dir so File() path always works
      final tmpDir = await getTemporaryDirectory();
      final tmpFile = File('${tmpDir.path}/profile_upload.$ext');
      await tmpFile.writeAsBytes(bytes, flush: true);

      final url = await ref
          .read(storageServiceProvider)
          .uploadProfilePhoto(user.uid, tmpFile, ext: ext);

      _update('photoUrl', url);

      // Clean up temp file
      await tmpFile.delete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to upload photo: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _generateSummary() async {
    final resume = ref.read(resumeStreamProvider(widget.resumeId)).value;
    if (resume == null) return;

    final exps = (resume.sections['experience'] as List? ?? [])
        .whereType<Map>()
        .map((e) {
          final title = (e['title'] ?? '').toString().trim();
          final company = (e['company'] ?? '').toString().trim();
          final description = (e['description'] ?? '').toString().trim();
          return [
            if (title.isNotEmpty || company.isNotEmpty)
              '${title.isEmpty ? 'Role' : title} at ${company.isEmpty ? 'Company' : company}',
            if (description.isNotEmpty) description,
          ].join(': ');
        })
        .where((e) => e.trim().isNotEmpty)
        .toList();
    final skills = (resume.sections['skills'] as List? ?? [])
        .map((s) => s.toString())
        .where((s) => s.trim().isNotEmpty)
        .toList();

    setState(() => _isGeneratingSummary = true);

    try {
      final summary = await ref
          .read(aiServiceProvider)
          .generateSummary(
            name: _data['name'] ?? '',
            targetRole: resume.targetRole,
            experiences: exps.cast<String>(),
            skills: skills,
          );

      _data['summary'] = summary;
      _summaryController.text = summary;
      widget.onChanged(_data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate summary: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingSummary = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Card(
      child: ExpansionTile(
        title: Text(
          'Personal Information',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        initiallyExpanded: true,
        children: [
          Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: _pickAndUploadPhoto,
                      child: CircleAvatar(
                        radius: 36,
                        backgroundColor: context.appColors.surface,
                        backgroundImage:
                            _data['photoUrl'] != null &&
                                _data['photoUrl'].toString().isNotEmpty
                            ? NetworkImage(_data['photoUrl'])
                            : null,
                        child: _isUploadingPhoto
                            ? CircularProgressIndicator()
                            : _data['photoUrl'] == null ||
                                  _data['photoUrl'].toString().isEmpty
                            ? Icon(
                                Icons.add_a_photo_rounded,
                                color: context.appColors.textSecondary,
                              )
                            : null,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        initialValue: _data['name'] ?? '',
                        decoration: InputDecoration(
                          labelText: 'Full Name',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => _update('name', v),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: _data['email'] ?? '',
                        decoration: InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => _update('email', v),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        initialValue: _data['phone'] ?? '',
                        decoration: InputDecoration(
                          labelText: 'Phone',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => _update('phone', v),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: _data['location'] ?? '',
                        decoration: InputDecoration(
                          labelText: 'Location',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => _update('location', v),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        initialValue: _data['linkedin'] ?? '',
                        decoration: InputDecoration(
                          labelText: 'LinkedIn URL',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => _update('linkedin', v),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                TextFormField(
                  controller: _summaryController,
                  decoration: InputDecoration(
                    labelText: 'Professional Summary',
                    border: OutlineInputBorder(),
                    suffixIcon: _isGeneratingSummary
                        ? Padding(
                            padding: EdgeInsets.all(12.0),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_summaryController.text.trim().isNotEmpty)
                                IconButton(
                                  icon: Icon(
                                    Icons.flag_outlined,
                                    color: context.appColors.textSecondary,
                                  ),
                                  tooltip: 'Report AI output',
                                  onPressed: () => showAiReportDialog(
                                    context: context,
                                    ref: ref,
                                    feature: 'summary_generation',
                                    output: _summaryController.text,
                                  ),
                                ),
                              IconButton(
                                icon: Icon(
                                  Icons.auto_awesome,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                tooltip: 'Improve with AI',
                                onPressed: _generateSummary,
                              ),
                            ],
                            ),
                  ),
                  maxLines: 4,
                  onChanged: (v) => _update('summary', v),
                ),
                SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
