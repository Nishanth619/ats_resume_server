import 'package:flutter/material.dart';

class EducationSection extends StatefulWidget {
  final List<Map<String, dynamic>> data;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;

  const EducationSection({super.key, required this.data, required this.onChanged});

  @override
  State<EducationSection> createState() => _EducationState();
}

class _EducationState extends State<EducationSection> {
  late List<Map<String, dynamic>> _items;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.data);
  }

  void _addEntry() {
    setState(() {
      _items.add({'degree': '', 'institution': '', 'year': '', 'gpa': ''});
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

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        title: const Text('Education',
            style: TextStyle(fontWeight: FontWeight.bold)),
        initiallyExpanded: false,
        children: [
          ..._items.asMap().entries.map((e) {
            final i = e.key;
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                Row(children: [
                  Expanded(child: TextFormField(
                      initialValue: _items[i]['degree'],
                      decoration: const InputDecoration(labelText: 'Degree (e.g. BS Computer Science)',
                          border: OutlineInputBorder()),
                      onChanged: (v) => _update(i, 'degree', v))),
                  const SizedBox(width: 8),
                  IconButton(icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _removeEntry(i)),
                ]),
                const SizedBox(height: 8),
                TextFormField(initialValue: _items[i]['institution'],
                    decoration: const InputDecoration(labelText: 'Institution',
                        border: OutlineInputBorder()),
                    onChanged: (v) => _update(i, 'institution', v)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: TextFormField(initialValue: _items[i]['year'],
                      decoration: const InputDecoration(labelText: 'Graduation Year',
                          border: OutlineInputBorder()),
                      onChanged: (v) => _update(i, 'year', v))),
                  const SizedBox(width: 8),
                  Expanded(child: TextFormField(initialValue: _items[i]['gpa'],
                      decoration: const InputDecoration(labelText: 'GPA (Optional)',
                          border: OutlineInputBorder()),
                      onChanged: (v) => _update(i, 'gpa', v))),
                ]),
                const Divider(height: 24),
              ]),
            );
          }),
          Padding(
              padding: const EdgeInsets.all(12),
              child: OutlinedButton.icon(onPressed: _addEntry,
                  icon: const Icon(Icons.add), label: const Text('Add Education'))),
        ],
      ),
    );
  }
}
