import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/ai_service.dart';
import '../../../providers/resume_provider.dart';

class PersonalInfoSection extends ConsumerStatefulWidget {
  final String resumeId;
  final Map<String, dynamic> data;
  final ValueChanged<Map<String, dynamic>> onChanged;

  const PersonalInfoSection({super.key, required this.resumeId, required this.data, required this.onChanged});

  @override
  ConsumerState<PersonalInfoSection> createState() => _PersonalInfoState();
}

class _PersonalInfoState extends ConsumerState<PersonalInfoSection> {
  late Map<String, dynamic> _data;

  @override
  void initState() {
    super.initState();
    _data = Map.from(widget.data);
  }

  void _update(String key, String value) {
    _data[key] = value;
    widget.onChanged(_data);
  }
  
  Future<void> _generateSummary() async {
    final resume = ref.read(resumeStreamProvider(widget.resumeId)).value;
    if (resume == null) return;
    
    final exps = (resume.sections['experience'] as List? ?? [])
        .map((e) => "\${e['title']} at \${e['company']}").toList();
    final skills = List<String>.from(resume.sections['skills'] ?? []);
    
    final summary = await ref.read(aiServiceProvider).generateSummary(
      name: _data['name'] ?? '',
      targetRole: resume.targetRole,
      experiences: exps.cast<String>(),
      skills: skills,
    );
    
    setState(() => _data['summary'] = summary);
    widget.onChanged(_data);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        title: const Text('Personal Information',
            style: TextStyle(fontWeight: FontWeight.bold)),
        initiallyExpanded: true,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              TextFormField(
                initialValue: _data['name'] ?? '',
                decoration: const InputDecoration(labelText: 'Full Name',
                    border: OutlineInputBorder()),
                onChanged: (v) => _update('name', v),
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
                initialValue: _data['summary'] ?? '',
                decoration: InputDecoration(
                  labelText: 'Professional Summary',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
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
