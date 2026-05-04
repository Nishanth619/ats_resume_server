import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../services/ai_service.dart';
import '../../../services/storage_service.dart';
import '../../../providers/resume_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/constants/app_colors.dart';

class PersonalInfoSection extends ConsumerStatefulWidget {
  final String resumeId;
  final Map<String, dynamic> data;
  final ValueChanged<Map<String, dynamic>> onChanged;

  const PersonalInfoSection({super.key, required this.resumeId, required this.data, required this.onChanged});

  @override
  ConsumerState<PersonalInfoSection> createState() => _PersonalInfoState();
}

class _PersonalInfoState extends ConsumerState<PersonalInfoSection> with AutomaticKeepAliveClientMixin {
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
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked == null) return;

    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    setState(() => _isUploadingPhoto = true);
    try {
      final file = File(picked.path);
      final url = await ref.read(storageServiceProvider).uploadProfilePhoto(user.uid, file);
      _update('photoUrl', url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload photo: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _generateSummary() async {
    final resume = ref.read(resumeStreamProvider(widget.resumeId)).value;
    if (resume == null) return;
    
    final exps = (resume.sections['experience'] as List? ?? [])
        .map((e) => "\${e['title']} at \${e['company']}").toList();
    final skills = List<String>.from(resume.sections['skills'] ?? []);
    
    setState(() => _isGeneratingSummary = true);
    
    try {
      final summary = await ref.read(aiServiceProvider).generateSummary(
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
        title: const Text('Personal Information',
            style: TextStyle(fontWeight: FontWeight.bold)),
        initiallyExpanded: true,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: _pickAndUploadPhoto,
                    child: CircleAvatar(
                      radius: 36,
                      backgroundColor: AppColors.surfaceDark,
                      backgroundImage: _data['photoUrl'] != null && _data['photoUrl'].toString().isNotEmpty
                          ? NetworkImage(_data['photoUrl'])
                          : null,
                      child: _isUploadingPhoto
                          ? const CircularProgressIndicator()
                          : _data['photoUrl'] == null || _data['photoUrl'].toString().isEmpty
                              ? const Icon(Icons.add_a_photo_rounded, color: AppColors.textSecondary)
                              : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      initialValue: _data['name'] ?? '',
                      decoration: const InputDecoration(labelText: 'Full Name',
                          border: OutlineInputBorder()),
                      onChanged: (v) => _update('name', v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextFormField(
                  initialValue: _data['email'] ?? '',
                  decoration: const InputDecoration(labelText: 'Email',
                      border: OutlineInputBorder()),
                  onChanged: (v) => _update('email', v),
                )),
                const SizedBox(width: 8),
                Expanded(child: TextFormField(
                  initialValue: _data['phone'] ?? '',
                  decoration: const InputDecoration(labelText: 'Phone',
                      border: OutlineInputBorder()),
                  onChanged: (v) => _update('phone', v),
                )),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextFormField(
                  initialValue: _data['location'] ?? '',
                  decoration: const InputDecoration(labelText: 'Location',
                      border: OutlineInputBorder()),
                  onChanged: (v) => _update('location', v),
                )),
                const SizedBox(width: 8),
                Expanded(child: TextFormField(
                  initialValue: _data['linkedin'] ?? '',
                  decoration: const InputDecoration(labelText: 'LinkedIn URL',
                      border: OutlineInputBorder()),
                  onChanged: (v) => _update('linkedin', v),
                )),
              ]),
              const SizedBox(height: 8),
              TextFormField(
                controller: _summaryController,
                decoration: InputDecoration(
                  labelText: 'Professional Summary',
                  border: const OutlineInputBorder(),
                  suffixIcon: _isGeneratingSummary 
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 20, 
                          height: 20, 
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6366F1))
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.auto_awesome, color: Color(0xFF6366F1)),
                        tooltip: 'Improve with AI',
                        onPressed: _generateSummary,
                      ),
                ),
                maxLines: 4,
                onChanged: (v) => _update('summary', v),
              ),
              const SizedBox(height: 12),
            ]),
          ),
        ],
      ),
    );
  }
}
