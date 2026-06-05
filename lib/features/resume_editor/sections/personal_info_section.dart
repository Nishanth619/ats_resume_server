import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/ai_service.dart';
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

  @override
  void initState() {
    super.initState();
    _data = Map.from(widget.data);
    _summaryController = TextEditingController(text: _data['summary'] ?? '');
  }

  @override
  void didUpdateWidget(covariant PersonalInfoSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync local state if parent data changed (e.g., from AI tailoring or cloud sync)
    final newSummary = widget.data['summary']?.toString() ?? '';
    if (newSummary != _data['summary']?.toString()) {
      _data = Map<String, dynamic>.from(widget.data);
      if (_summaryController.text != newSummary) {
        _summaryController.text = newSummary;
      }
    } else {
      // Just update the reference if other fields changed
      _data = Map<String, dynamic>.from(widget.data);
    }
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



  Future<void> _generateSummary() async {
    // Use the notifier state to get the most up-to-date content (including unsaved keystrokes)
    final resume = ref.read(resumeNotifierProvider(widget.resumeId));
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
                    Expanded(
                      child: TextFormField(
                        initialValue: _data['name'] ?? '',
                        decoration: InputDecoration(
                          labelText: 'Full Name',
                          border: UnderlineInputBorder(),
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
                          border: UnderlineInputBorder(),
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
                          border: UnderlineInputBorder(),
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
                          border: UnderlineInputBorder(),
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
                          border: UnderlineInputBorder(),
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
                    border: UnderlineInputBorder(),
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
