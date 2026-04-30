import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/ai_service.dart';
import '../../services/firestore_service.dart';
import '../../providers/resume_provider.dart';
import '../../providers/auth_provider.dart';

class CoverLetterScreen extends ConsumerStatefulWidget {
  final String resumeId;
  const CoverLetterScreen({super.key, required this.resumeId});
  
  @override
  ConsumerState<CoverLetterScreen> createState() => _CLState();
}

class _CLState extends ConsumerState<CoverLetterScreen> {
  final _companyCtrl = TextEditingController();
  final _jdCtrl = TextEditingController();
  final _letterCtrl = TextEditingController();
  bool _loading = false;

  Future<void> _generate() async {
    setState(() => _loading = true);
    try {
      final resume = ref.read(resumeStreamProvider(widget.resumeId)).value;
      final uid = ref.read(authStateProvider).value?.uid;
      if (resume == null || uid == null) return;
      
      final p = resume.sections['personal'] ?? {};
      final buf = StringBuffer();
      buf.writeln('${p['summary'] ?? ''}');
      for (final e in (resume.sections['experience'] as List? ?? [])) {
        buf.writeln('${e['title']} at ${e['company']}: ${e['description']}');
      }
      
      final letter = await ref.read(aiServiceProvider).generateCoverLetter(
        resumeText: buf.toString(), 
        jd: _jdCtrl.text,
        company: _companyCtrl.text, 
        name: p['name'] ?? ''
      );
      
      _letterCtrl.text = letter;
      
      await ref.read(firestoreServiceProvider).saveCoverLetter(
        uid, widget.resumeId, letter, _companyCtrl.text
      );
    } finally { 
      setState(() => _loading = false); 
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Cover Letter Builder')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16), 
      child: Column(
        children: [
          TextField(
            controller: _companyCtrl,
            decoration: const InputDecoration(labelText: 'Company Name', border: OutlineInputBorder())
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _jdCtrl, 
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Job Description (optional)', border: OutlineInputBorder(), alignLabelWithHint: true)
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _generate,
              child: _loading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Generate Cover Letter with AI')
            )
          ),
          if (_letterCtrl.text.isNotEmpty) ...[
            const SizedBox(height: 20),
            TextField(
              controller: _letterCtrl, 
              maxLines: 20,
              decoration: const InputDecoration(labelText: 'Cover Letter (editable)', border: OutlineInputBorder(), alignLabelWithHint: true)
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => context.push('/download/${widget.resumeId}'),
              icon: const Icon(Icons.download),
              label: const Text('Download FREE — Watch Ad')
            ),
          ],
        ]
      )
    ),
  );
}
