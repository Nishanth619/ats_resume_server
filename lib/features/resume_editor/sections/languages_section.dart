import 'package:flutter/material.dart';

class LanguagesSection extends StatefulWidget {
  final List<Map<String, dynamic>> data;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;

  const LanguagesSection({
    super.key,
    required this.data,
    required this.onChanged,
  });

  @override
  State<LanguagesSection> createState() => _LanguagesState();
}

class _LanguagesState extends State<LanguagesSection>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _ctrl = TextEditingController();
  late List<Map<String, dynamic>> _languages;
  String _selectedLevel = 'Native';

  final List<String> _levels = [
    'Native',
    'Fluent',
    'Professional',
    'Conversational',
    'Basic',
  ];

  @override
  void initState() {
    super.initState();
    _languages = List.from(
      widget.data.map((e) => Map<String, dynamic>.from(e)),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _addLanguage() {
    final lang = _ctrl.text.trim();
    if (lang.isNotEmpty) {
      if (!_languages.any(
        (e) => e['language'].toString().toLowerCase() == lang.toLowerCase(),
      )) {
        setState(() {
          _languages.add({'language': lang, 'level': _selectedLevel});
        });
        widget.onChanged(_languages);
      }
      _ctrl.clear();
    }
  }

  void _removeLanguage(int index) {
    setState(() => _languages.removeAt(index));
    widget.onChanged(_languages);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Card(
      child: ExpansionTile(
        title: const Text(
          'Languages',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        initiallyExpanded: false,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _ctrl,
                        decoration: const InputDecoration(
                          labelText: 'Language (e.g. Spanish)',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _addLanguage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedLevel,
                        decoration: const InputDecoration(
                          labelText: 'Level',
                          border: OutlineInputBorder(),
                        ),
                        items: _levels
                            .map(
                              (l) => DropdownMenuItem(
                                value: l,
                                child: Text(
                                  l,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedLevel = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: IconButton(
                        icon: Icon(
                          Icons.add_circle,
                          color: Theme.of(context).colorScheme.primary,
                          size: 40,
                        ),
                        onPressed: _addLanguage,
                      ),
                    ),
                  ],
                ),
                if (_languages.isNotEmpty) const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _languages.asMap().entries.map((e) {
                    final i = e.key;
                    final l = e.value;
                    return Chip(
                      label: Text('${l["language"]} (${l["level"]})'),
                      onDeleted: () => _removeLanguage(i),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
