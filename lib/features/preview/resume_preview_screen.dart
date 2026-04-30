import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:go_router/go_router.dart';
import '../../providers/resume_provider.dart';
import '../../services/pdf_service.dart';

class ResumePreviewScreen extends ConsumerWidget {
  final String resumeId;
  const ResumePreviewScreen({super.key, required this.resumeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumeAsync = ref.watch(resumeStreamProvider(resumeId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview'),
        actions: [
          IconButton(icon: const Icon(Icons.print),
            onPressed: () async {
              final resume = resumeAsync.value;
              if (resume != null) await PDFService().printResume(resume);
            }),
          IconButton(icon: const Icon(Icons.share),
            onPressed: () { /* generate share link */ }),
        ],
      ),
      body: resumeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (resume) => FutureBuilder<File>(
          future: Future.microtask(() => PDFService().generatePDF(resume)).timeout(const Duration(seconds: 10)),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Generating PDF preview...'),
                ],
              ));
            }
            if (snapshot.hasError) {
              return Center(child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Error generating preview:\n${snapshot.error}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
              ));
            }
            return PdfPreview(
              build: (format) async => snapshot.data!.readAsBytesSync(),
              allowPrinting: false,
              allowSharing: false,
              canChangePageFormat: false,
              pdfPreviewPageDecoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)]),
            );
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: () => context.push('/download/$resumeId'),
            icon: const Icon(Icons.download),
            label: const Text('Download for Free — Watch Ad'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52)),
          ),
        ),
      ),
    );
  }
}
