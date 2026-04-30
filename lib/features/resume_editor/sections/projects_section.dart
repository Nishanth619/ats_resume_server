import 'package:flutter/material.dart';

class ProjectsSection extends StatefulWidget {
  final List<Map<String, dynamic>> data;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;

  const ProjectsSection({super.key, required this.data, required this.onChanged});

  @override
  State<ProjectsSection> createState() => _ProjectsState();
}

class _ProjectsState extends State<ProjectsSection> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late List<Map<String, dynamic>> _items;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.data);
  }

  void _addEntry() {
    setState(() {
      _items.add({'name': '', 'dates': '', 'description': ''});
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
    super.build(context);
    return Card(
      child: ExpansionTile(
        title: const Text('Projects',
            style: TextStyle(fontWeight: FontWeight.bold)),
        initiallyExpanded: false,
        children: [
          ..._items.asMap().entries.map((e) {
            final i = e.key;
            return Padding(
              key: ObjectKey(_items[i]),
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                Row(children: [
                  Expanded(child: TextFormField(
                      initialValue: _items[i]['name'],
                      decoration: const InputDecoration(labelText: 'Project Name',
                          border: OutlineInputBorder()),
                      onChanged: (v) => _update(i, 'name', v))),
                  const SizedBox(width: 8),
                  IconButton(icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _removeEntry(i)),
                ]),
                const SizedBox(height: 8),
                TextFormField(initialValue: _items[i]['dates'],
                    decoration: const InputDecoration(labelText: 'Dates',
                        border: OutlineInputBorder()),
                    onChanged: (v) => _update(i, 'dates', v)),
                const SizedBox(height: 8),
                TextFormField(
                    initialValue: _items[i]['description'],
                    decoration: const InputDecoration(
                        labelText: 'Description (bullet points)',
                        border: OutlineInputBorder()),
                    maxLines: 4,
                    onChanged: (v) => _update(i, 'description', v)),
                const Divider(height: 24),
              ]),
            );
          }),
          Padding(
              padding: const EdgeInsets.all(12),
              child: OutlinedButton.icon(onPressed: _addEntry,
                  icon: const Icon(Icons.add), label: const Text('Add Project'))),
        ],
      ),
    );
  }
}
