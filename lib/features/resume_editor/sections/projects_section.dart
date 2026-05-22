import 'dart:convert';
import 'package:flutter/material.dart';

class ProjectsSection extends StatefulWidget {
  final List<Map<String, dynamic>> data;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;

  const ProjectsSection({
    super.key,
    required this.data,
    required this.onChanged,
  });

  @override
  State<ProjectsSection> createState() => _ProjectsState();
}

class _ProjectsState extends State<ProjectsSection>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late List<Map<String, dynamic>> _items;
  late List<TextEditingController> _descControllers;

  @override
  void initState() {
    super.initState();
    _syncFromWidget();
  }

  void _syncFromWidget() {
    _items = widget.data.map((e) => Map<String, dynamic>.from(e)).toList();
    _descControllers = _items
        .map((e) => TextEditingController(text: e['description'] ?? ''))
        .toList();
  }

  @override
  void didUpdateWidget(covariant ProjectsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    try {
      if (jsonEncode(widget.data) != jsonEncode(_items)) {
        _disposeControllers();
        setState(() => _syncFromWidget());
      }
    } catch (_) {
      _disposeControllers();
      setState(() => _syncFromWidget());
    }
  }

  void _disposeControllers() {
    for (final c in _descControllers) {
      c.dispose();
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _addEntry() {
    setState(() {
      _items.add({'name': '', 'dates': '', 'description': ''});
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Card(
      child: ExpansionTile(
        title: const Text(
          'Projects',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        initiallyExpanded: false,
        children: [
          ..._items.asMap().entries.map((e) {
            final i = e.key;
            return Padding(
              key: ValueKey('proj_$i'),
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: ValueKey('proj_name_${_items[i]['name']}_$i'),
                          initialValue: _items[i]['name'],
                          decoration: const InputDecoration(
                            labelText: 'Project Name',
                            border: UnderlineInputBorder(),
                          ),
                          onChanged: (v) => _update(i, 'name', v),
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
                    key: ValueKey('proj_dates_${_items[i]['dates']}_$i'),
                    initialValue: _items[i]['dates'],
                    decoration: const InputDecoration(
                      labelText: 'Dates',
                      border: UnderlineInputBorder(),
                    ),
                    onChanged: (v) => _update(i, 'dates', v),
                  ),
                  const SizedBox(height: 8),
                  // Use a controller so tailored description is always reflected
                  TextFormField(
                    controller: _descControllers[i],
                    decoration: const InputDecoration(
                      labelText: 'Description (bullet points)',
                      border: UnderlineInputBorder(),
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
              label: const Text('Add Project'),
            ),
          ),
        ],
      ),
    );
  }
}
