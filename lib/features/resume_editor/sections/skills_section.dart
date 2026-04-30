import 'package:flutter/material.dart';

class SkillsSection extends StatefulWidget {
  final List<String> data;
  final ValueChanged<List<String>> onChanged;

  const SkillsSection({super.key, required this.data, required this.onChanged});

  @override
  State<SkillsSection> createState() => _SkillsState();
}

class _SkillsState extends State<SkillsSection> {
  final _ctrl = TextEditingController();
  late List<String> _skills;

  @override
  void initState() {
    super.initState();
    _skills = List.from(widget.data);
  }

  void _addSkill(String s) {
    final skill = s.trim();
    if (skill.isNotEmpty && !_skills.contains(skill)) {
      setState(() => _skills.add(skill));
      widget.onChanged(_skills);
      _ctrl.clear();
    }
  }

  void _removeSkill(String skill) {
    setState(() => _skills.remove(skill));
    widget.onChanged(_skills);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        title: const Text('Skills',
            style: TextStyle(fontWeight: FontWeight.bold)),
        initiallyExpanded: false,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _ctrl,
                  decoration: InputDecoration(
                    labelText: 'Add a skill (press Enter to add)',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () => _addSkill(_ctrl.text),
                    ),
                  ),
                  onSubmitted: _addSkill,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _skills.map((s) => Chip(
                    label: Text(s),
                    onDeleted: () => _removeSkill(s),
                  )).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
