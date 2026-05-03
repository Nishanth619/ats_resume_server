import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/admob_service.dart';
import '../../services/pdf_service.dart';
import '../../providers/resume_provider.dart';
import '../../models/resume_model.dart';

class DownloadScreen extends ConsumerStatefulWidget {
  final String resumeId;
  const DownloadScreen({super.key, required this.resumeId});
  @override
  ConsumerState<DownloadScreen> createState() => _DLState();
}

class _DLState extends ConsumerState<DownloadScreen> {
  bool _loading = false;
  bool _done = false;
  String _status = 'Watch a short ad to download your resume completely FREE';

  @override
  void initState() {
    super.initState();
    ref.read(adServiceProvider).loadRewardedAd();
  }

  Future<void> _download() async {
    final adSvc = ref.read(adServiceProvider);
    if (!adSvc.isRewardedReady) {
      setState(() => _status = 'Loading ad, please wait...');
      await adSvc.loadRewardedAd();
      await Future.delayed(const Duration(seconds: 2));
      if (!adSvc.isRewardedReady) {
        setState(() => _status = 'Ad not available right now. Please try again.'); 
        return;
      }
    }
    setState(() => _loading = true);
    await adSvc.showRewardedAd(
      onRewarded: () async {
        try {
          ResumeModel? resume = ref.read(resumeNotifierProvider(widget.resumeId));
          if (resume == null) resume = ref.read(resumeStreamProvider(widget.resumeId)).value;
          if (resume == null) {
            resume = await ref.read(resumeStreamProvider(widget.resumeId).future).timeout(
              const Duration(seconds: 10),
              onTimeout: () => throw Exception('Resume took too long to load from cloud.'),
            );
          }
          if (resume == null) throw Exception('Could not load resume. Please save and try again.');
          final file = await PDFService().generatePDF(resume);
          
          // Try to increment download count
          try {
             // In case incrementDownload isn't implemented yet, we don't want it to break the flow
             await ref.read(resumeNotifierProvider(widget.resumeId).notifier).incrementDownload();
          } catch (_) {}

          setState(() { 
            _done = true; 
            _loading = false;
            _status = 'Resume saved! Check your Downloads folder.\nPath: ${file.path}'; 
          });
        } catch (e) { 
          setState(() { _loading = false; _status = 'Error: $e'; }); 
        }
      },
      onFailed: () => setState(() { 
        _loading = false;
        _status = 'Please watch the complete ad to unlock download.'; 
      }),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Download Resume')),
    body: Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(
      mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(_done ? Icons.check_circle : Icons.play_circle_outline,
          size: 80, color: _done ? Colors.green : const Color(0xFF6366F1)),
        const SizedBox(height: 24),
        Text(_status, textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 32),
        if (!_done) _loading
          ? const Column(children: [
              CircularProgressIndicator(), SizedBox(height: 12),
              Text('Loading ad...')
            ])
          : ElevatedButton.icon(onPressed: _download,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Watch Ad & Download FREE'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(280, 52))),
        const SizedBox(height: 16),
        const Text('FREE • No payment required • 15-30 second ad',
          style: TextStyle(color: Colors.grey, fontSize: 12)),
    ]))),
  );
}
