import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../../services/ai_service.dart';
import '../../providers/resume_provider.dart';

class ATSScoreScreen extends ConsumerStatefulWidget {
  final String resumeId;
  const ATSScoreScreen({super.key, required this.resumeId});
  @override
  ConsumerState<ATSScoreScreen> createState() => _ATSState();
}

class _ATSState extends ConsumerState<ATSScoreScreen> {
  ATSResult? _result;
  bool _loading = true;
  String? _error;

  @override
  void initState() { 
    super.initState(); 
    WidgetsBinding.instance.addPostFrameCallback((_) => _run()); 
  }

  Future<void> _run() async {
    setState(() { _loading = true; _error = null; });
    try {
      final resume = ref.read(resumeStreamProvider(widget.resumeId)).value;
      if (resume == null) throw Exception('Resume not loaded');
      final text = _serialize(resume);
      final result = await ref.read(aiServiceProvider).checkATS(text,
          targetJD: resume.targetJD.isNotEmpty ? resume.targetJD : null);
      await ref.read(resumeNotifierProvider(widget.resumeId).notifier).updateATSScore(result.score);
      setState(() { _result = result; _loading = false; });
    } catch (e) { 
      setState(() { _error = '$e'; _loading = false; }); 
    }
  }

  String _serialize(resume) {
    final buf = StringBuffer();
    final p = resume.sections['personal'] ?? {};
    buf.writeln('${p['name'] ?? ''}\n${p['email'] ?? ''}\n${p['phone'] ?? ''}');
    buf.writeln('PROFESSIONAL SUMMARY\n${p['summary'] ?? ''}');
    buf.writeln('WORK EXPERIENCE');
    for (final e in (resume.sections['experience'] as List? ?? [])) {
      buf.writeln('${e['title']} at ${e['company']} (${e['dates']})\n${e['description']}');
    }
    buf.writeln('EDUCATION');
    for (final e in (resume.sections['education'] as List? ?? [])) {
      buf.writeln('${e['degree']} - ${e['institution']} (${e['year']})');
    }
    buf.writeln('SKILLS\n${(resume.sections['skills'] as List? ?? []).join(', ')}');
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('ATS Score'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _run)]),
    body: _loading
        ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            CircularProgressIndicator(), SizedBox(height: 16), Text('Analysing your resume with AI...')]))
        : _error != null
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('Error: $_error'),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _run, child: const Text('Retry'))]))
            : _buildResults(),
  );

  Widget _buildResults() {
    if (_result == null) return const SizedBox();
    final score = _result!.score;
    final col = score >= 80 ? Colors.green : score >= 60 ? Colors.orange : Colors.red;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20), 
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: CircularPercentIndicator(
              radius: 80, 
              lineWidth: 12, 
              percent: score / 100,
              center: Column(
                mainAxisAlignment: MainAxisAlignment.center, 
                children: [
                  Text('$score', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: col)),
                  const Text('ATS Score')
                ]
              ),
              progressColor: col, 
              backgroundColor: Colors.grey.shade200,
              circularStrokeCap: CircularStrokeCap.round,
            )
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: col.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12), 
              border: Border.all(color: col.withOpacity(0.3))
            ),
            child: Text(
              score >= 80 ? 'Excellent — Ready to Apply!' : score >= 60 ? 'Good — Minor Fixes Needed' : 'Needs Work — Fix Issues First',
              style: TextStyle(color: col, fontWeight: FontWeight.bold, fontSize: 15),
              textAlign: TextAlign.center
            )
          ),
          if (_result!.issues.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('Issues Found', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ..._result!.issues.asMap().entries.map((e) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.warning_amber, color: Colors.orange),
                title: Text(e.value, style: const TextStyle(fontSize: 13)),
                subtitle: _result!.fixes.length > e.key
                    ? Text('Fix: ${_result!.fixes[e.key]}',
                        style: const TextStyle(color: Colors.green, fontSize: 12)) 
                    : null
              )
            )),
          ],
          if (_result!.missingKeywords.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('Missing Keywords', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8, 
              runSpacing: 8,
              children: _result!.missingKeywords.map((k) => Chip(
                label: Text(k),
                backgroundColor: Colors.red.shade50,
                labelStyle: TextStyle(color: Colors.red.shade700)
              )).toList()
            ),
          ],
        ]
      )
    );
  }
}
