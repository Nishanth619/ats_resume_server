import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/ai_service.dart';

class ExperienceSection extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> data;
  final String targetRole;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;

  const ExperienceSection({super.key, required this.data, required this.targetRole, required this.onChanged});

  @override
  ConsumerState<ExperienceSection> createState() => _ExpState();
}

class _ExpState extends ConsumerState<ExperienceSection> {
  late List<Map<String, dynamic>> _items;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.data);
  }

  void _addEntry() {
    setState(() {
      _items.add({'title': '', 'company': '', 'location': '', 'dates': '', 'description': ''});
    });
    widget.onChanged(_items);
  }

  void _removeEntry(int i) {
    setState(() => _items.removeAt(i));
    widget.onChanged(_items);
  }

  void _update(int i, String key, String value) {
    _items[i][key] = value;
    widget.onChanged(_items);
  }

  Future<void> _improveWithAI(int i) async {
    final raw = _items[i]['description'] ?? '';
    if (raw.isEmpty) return;
    
    final improved = await ref.read(aiServiceProvider)
        .improveBullet(raw, widget.targetRole);
    setState(() => _items[i]['description'] = improved);
    widget.onChanged(_items);
  }
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        title: const Text('Work Experience',
            style: TextStyle(fontWeight: FontWeight.bold)),
        initiallyExpanded: true,
        children: [
          ..._items.asMap().entries.map((e) {
            final i = e.key;
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                Row(children: [
                  Expanded(child: TextFormField(
                      initialValue: _items[i]['title'],
                      decoration: const InputDecoration(labelText: 'Job Title',
                          border: OutlineInputBorder()),
                      onChanged: (v) => _update(i, 'title', v))),
                  const SizedBox(width: 8),
                  IconButton(icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _removeEntry(i)),
                ]),
                const SizedBox(height: 8),
                TextFormField(initialValue: _items[i]['company'],
                    decoration: const InputDecoration(labelText: 'Company',
                        border: OutlineInputBorder()),
                    onChanged: (v) => _update(i, 'company', v)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: TextFormField(initialValue: _items[i]['location'],
                      decoration: const InputDecoration(labelText: 'Location',
                          border: OutlineInputBorder()),
                      onChanged: (v) => _update(i, 'location', v))),
                  const SizedBox(width: 8),
                  Expanded(child: TextFormField(initialValue: _items[i]['dates'],
                      decoration: const InputDecoration(labelText: 'Dates (MM/YYYY)',
                          border: OutlineInputBorder()),
                      onChanged: (v) => _update(i, 'dates', v))),
                ]),
                const SizedBox(height: 8),
                TextFormField(
                    initialValue: _items[i]['description'],
                    decoration: InputDecoration(
                        labelText: 'Description (bullet points)',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                            icon: const Icon(Icons.auto_awesome, color: Color(0xFF6366F1)),
                            tooltip: 'Improve with AI',
                            onPressed: () => _improveWithAI(i))),
                    maxLines: 4,
                    onChanged: (v) => _update(i, 'description', v)),
                const Divider(height: 24),
              ]),
            );
          }),
          Padding(
              padding: const EdgeInsets.all(12),
              child: OutlinedButton.icon(onPressed: _addEntry,
                  icon: const Icon(Icons.add), label: const Text('Add Experience'))),
        ],
      ),
    );
  }
}
