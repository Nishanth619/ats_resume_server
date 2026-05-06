import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/ai_service.dart';

class ExperienceSection extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> data;
  final String targetRole;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;

  const ExperienceSection({
    super.key,
    required this.data,
    required this.targetRole,
    required this.onChanged,
  });

  @override
  ConsumerState<ExperienceSection> createState() => _ExpState();
}

class _ExpState extends ConsumerState<ExperienceSection>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late List<Map<String, dynamic>> _items;
  late List<TextEditingController> _descControllers;
  final Set<int> _generatingIndices = {};

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.data);
    _descControllers = _items
        .map((e) => TextEditingController(text: e['description'] ?? ''))
        .toList();
  }

  @override
  void dispose() {
    for (final c in _descControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addEntry() {
    setState(() {
      _items.add({
        'title': '',
        'company': '',
        'location': '',
        'dates': '',
        'description': '',
      });
      _descControllers.add(TextEditingController(text: ''));
    });
    widget.onChanged(_items);
  }

  void _removeEntry(int i) {
    setState(() {
      _items.removeAt(i);
      final c = _descControllers.removeAt(i);
      c.dispose();
    });
    widget.onChanged(_items);
  }

  void _update(int i, String key, String value) {
    _items[i][key] = value;
    widget.onChanged(_items);
  }

  Future<void> _improveWithAI(int i) async {
    final raw = _items[i]['description'] ?? '';
    if (raw.isEmpty) return;

    setState(() => _generatingIndices.add(i));

    try {
      final improved = await ref
          .read(aiServiceProvider)
          .improveBullet(raw, widget.targetRole);

      _items[i]['description'] = improved;
      _descControllers[i].text = improved;
      widget.onChanged(_items);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to improve text: $e')));
      }
    } finally {
      if (mounted) setState(() => _generatingIndices.remove(i));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Card(
      child: ExpansionTile(
        title: const Text(
          'Work Experience',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        initiallyExpanded: true,
        children: [
          ..._items.asMap().entries.map((e) {
            final i = e.key;
            return Padding(
              key: ObjectKey(_items[i]),
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: _items[i]['title'],
                          decoration: const InputDecoration(
                            labelText: 'Job Title',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (v) => _update(i, 'title', v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _removeEntry(i),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: _items[i]['company'],
                    decoration: const InputDecoration(
                      labelText: 'Company',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => _update(i, 'company', v),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: _items[i]['location'],
                    decoration: const InputDecoration(
                      labelText: 'Location',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => _update(i, 'location', v),
                  ),
                  const SizedBox(height: 8),
                  _DateInputRow(
                    initialDates: _items[i]['dates'] ?? '',
                    onChanged: (v) => _update(i, 'dates', v),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descControllers[i],
                    decoration: InputDecoration(
                      labelText: 'Description (bullet points)',
                      border: const OutlineInputBorder(),
                      suffixIcon: _generatingIndices.contains(i)
                          ? const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF6366F1),
                                ),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(
                                Icons.auto_awesome,
                                color: Color(0xFF6366F1),
                              ),
                              tooltip: 'Improve with AI',
                              onPressed: () => _improveWithAI(i),
                            ),
                    ),
                    maxLines: 4,
                    onChanged: (v) => _update(i, 'description', v),
                  ),
                  const Divider(height: 24),
                ],
              ),
            );
          }),
          Padding(
            padding: const EdgeInsets.all(12),
            child: OutlinedButton.icon(
              onPressed: _addEntry,
              icon: const Icon(Icons.add),
              label: const Text('Add Experience'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateInputRow extends StatefulWidget {
  final String initialDates;
  final ValueChanged<String> onChanged;

  const _DateInputRow({required this.initialDates, required this.onChanged});

  @override
  State<_DateInputRow> createState() => _DateInputRowState();
}

class _DateInputRowState extends State<_DateInputRow> {
  late TextEditingController _startCtrl;
  late TextEditingController _endCtrl;

  @override
  void initState() {
    super.initState();
    final parts = widget.initialDates.split(RegExp(r'\s+-\s+'));
    _startCtrl = TextEditingController(
      text: parts.isNotEmpty ? parts[0] : widget.initialDates,
    );
    _endCtrl = TextEditingController(text: parts.length > 1 ? parts[1] : '');
  }

  @override
  void dispose() {
    _startCtrl.dispose();
    _endCtrl.dispose();
    super.dispose();
  }

  void _notify() {
    final s = _startCtrl.text.trim();
    final e = _endCtrl.text.trim();
    if (s.isEmpty && e.isEmpty) {
      widget.onChanged('');
    } else if (e.isEmpty) {
      widget.onChanged(s);
    } else {
      widget.onChanged('$s - $e');
    }
  }

  String? _validateDate(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    if (v.trim().toLowerCase() == 'present') return null;
    if (!RegExp(r'^(0[1-9]|1[0-2])\/\d{4}$').hasMatch(v.trim())) {
      return 'MM/YYYY';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextFormField(
            controller: _startCtrl,
            decoration: const InputDecoration(
              labelText: 'Start Date',
              hintText: 'MM/YYYY',
              border: OutlineInputBorder(),
            ),
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: _validateDate,
            onChanged: (_) => _notify(),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            controller: _endCtrl,
            decoration: const InputDecoration(
              labelText: 'End Date',
              hintText: 'MM/YYYY or Present',
              border: OutlineInputBorder(),
            ),
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: _validateDate,
            onChanged: (_) => _notify(),
          ),
        ),
      ],
    );
  }
}
