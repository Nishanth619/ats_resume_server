import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/ai_service.dart';
import '../../providers/resume_provider.dart';

class JDMatcherScreen extends ConsumerStatefulWidget {
  final String resumeId;
  const JDMatcherScreen({super.key, required this.resumeId});
  @override
  ConsumerState<JDMatcherScreen> createState() => _JDState();
}

class _JDState extends ConsumerState<JDMatcherScreen> {
  final _jdCtrl = TextEditingController();
  KeywordMatchResult? _result;
  bool _loading = false;

  Future<void> _analyse() async {
    if (_jdCtrl.text.isEmpty) return;
    setState(() => _loading = true);
    
    try {
      final resume = ref.read(resumeStreamProvider(widget.resumeId)).value;
      if (resume == null) return;
      
      // Save JD to resume for ATS check later
      await ref.read(resumeNotifierProvider(widget.resumeId).notifier)
          .updateTargetJD(_jdCtrl.text.trim());
          
      // Run keyword match
      final buf = StringBuffer();
      final p = resume.sections['personal'] ?? {};
      buf.writeln('${p['summary'] ?? ''}');
      for (final e in (resume.sections['experience'] as List? ?? [])) {
        buf.writeln('${e['description'] ?? ''}');
      }
      buf.writeln((resume.sections['skills'] as List? ?? []).join(', '));
      
      final result = await ref.read(aiServiceProvider).matchJD(buf.toString(), _jdCtrl.text);
      setState(() { _result = result; _loading = false; });
    } catch (_) { 
      setState(() => _loading = false); 
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Job Description Matcher')),
    body: Padding(
      padding: const EdgeInsets.all(16), 
      child: Column(
        children: [
          TextField(
            controller: _jdCtrl, 
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Paste Job Description here',
              border: OutlineInputBorder(), 
              alignLabelWithHint: true
            )
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _analyse,
              child: _loading 
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Analyse Match')
            )
          ),
          if (_result != null) ...[
            const SizedBox(height: 20),
            LinearProgressIndicator(
              value: _result!.matchPercentage / 100,
              backgroundColor: Colors.red.shade100, 
              color: Colors.green
            ),
            const SizedBox(height: 6),
            Text(
              '${_result!.matchPercentage}% keyword match',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, 
                      children: [
                        const Text('Matched', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView(
                            children: _result!.matched.map((k) =>
                              Chip(
                                label: Text(k, style: const TextStyle(fontSize: 11)),
                                backgroundColor: Colors.green.shade50
                              )
                            ).toList()
                          )
                        ),
                      ]
                    )
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, 
                      children: [
                        const Text('Missing', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView(
                            children: _result!.missing.map((k) =>
                              ActionChip(
                                label: Text(k, style: const TextStyle(fontSize: 11)),
                                backgroundColor: Colors.red.shade50,
                                onPressed: () { /* Add to skills */ }
                              )
                            ).toList()
                          )
                        ),
                      ]
                    )
                  ),
                ]
              )
            ),
          ],
        ]
      )
    ),
  );
}
