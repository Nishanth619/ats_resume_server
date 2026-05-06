import 'package:flutter/material.dart';

class AwardsSection extends StatefulWidget {
  final List<Map<String, dynamic>> data;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;

  const AwardsSection({super.key, required this.data, required this.onChanged});

  @override
  State<AwardsSection> createState() => _AwardsState();
}

class _AwardsState extends State<AwardsSection>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late List<Map<String, dynamic>> _items;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.data.map((e) => Map<String, dynamic>.from(e)));
  }

  void _addEntry() {
    setState(() {
      _items.add({'title': '', 'issuer': '', 'date': '', 'description': ''});
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
        title: const Text(
          'Awards & Achievements',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        initiallyExpanded: false,
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
                            labelText: 'Award Title',
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
                    initialValue: _items[i]['issuer'],
                    decoration: const InputDecoration(
                      labelText: 'Issuer / Organization',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => _update(i, 'issuer', v),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: _items[i]['date'],
                    decoration: const InputDecoration(
                      labelText: 'Date / Year',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => _update(i, 'date', v),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: _items[i]['description'],
                    decoration: const InputDecoration(
                      labelText: 'Description (Optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
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
              label: const Text('Add Award'),
            ),
          ),
        ],
      ),
    );
  }
}
