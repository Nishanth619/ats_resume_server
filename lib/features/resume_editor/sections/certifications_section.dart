import 'package:flutter/material.dart';

class CertificationsSection extends StatefulWidget {
  final List<Map<String, dynamic>> data;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;

  const CertificationsSection({super.key, required this.data, required this.onChanged});

  @override
  State<CertificationsSection> createState() => _CertificationsState();
}

class _CertificationsState extends State<CertificationsSection> with AutomaticKeepAliveClientMixin {
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
      _items.add({'name': '', 'issuer': '', 'year': ''});
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
        title: const Text('Certifications',
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
                      decoration: const InputDecoration(labelText: 'Certification Name',
                          border: OutlineInputBorder()),
                      onChanged: (v) => _update(i, 'name', v))),
                  const SizedBox(width: 8),
                  IconButton(icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _removeEntry(i)),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: TextFormField(initialValue: _items[i]['issuer'],
                      decoration: const InputDecoration(labelText: 'Issuing Organization',
                          border: OutlineInputBorder()),
                      onChanged: (v) => _update(i, 'issuer', v))),
                  const SizedBox(width: 8),
                  Expanded(child: TextFormField(initialValue: _items[i]['year'],
                      decoration: const InputDecoration(labelText: 'Year',
                          border: OutlineInputBorder()),
                      onChanged: (v) => _update(i, 'year', v))),
                ]),
                const Divider(height: 24),
              ]),
            );
          }),
          Padding(
              padding: const EdgeInsets.all(12),
              child: OutlinedButton.icon(onPressed: _addEntry,
                  icon: const Icon(Icons.add), label: const Text('Add Certification'))),
        ],
      ),
    );
  }
}
