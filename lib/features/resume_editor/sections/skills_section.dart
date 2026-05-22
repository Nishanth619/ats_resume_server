import 'dart:convert';
import 'package:flutter/material.dart';

class SkillsSection extends StatefulWidget {
  final List<String> data;
  final ValueChanged<List<String>> onChanged;

  const SkillsSection({super.key, required this.data, required this.onChanged});

  @override
  State<SkillsSection> createState() => _SkillsState();
}

class _SkillsState extends State<SkillsSection>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _ctrl = TextEditingController();
  late List<String> _skills;

  @override
  void initState() {
    super.initState();
    _syncFromWidget();
  }

  /// Normalize incoming data safely, coercing every element
  /// to a non-empty String. This guards against the tailoring merge returning
  /// non-String elements.
  void _syncFromWidget() {
    _skills = _normalize(widget.data);
  }

  static List<String> _normalize(List<dynamic> raw) {
    return raw
        .map((e) => e?.toString().trim() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
  }

  @override
  void didUpdateWidget(covariant SkillsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    try {
      if (jsonEncode(widget.data) != jsonEncode(_skills)) {
        setState(() => _syncFromWidget());
      }
    } catch (_) {
      setState(() => _syncFromWidget());
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
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
    super.build(context);
    return Card(
      child: ExpansionTile(
        title: const Text(
          'Skills',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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
                    labelText: 'Add a skill (press Enter or tap +)',
                    border: const UnderlineInputBorder(),
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
                  children: _skills
                      .map(
                        (s) => Chip(
                          label: Text(s),
                          onDeleted: () => _removeSkill(s),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
