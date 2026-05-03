
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
    // Get local state from the editor instantly (includes unsaved changes)
    final resume = ref.watch(resumeNotifierProvider(resumeId));

    if (resume == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Preview')),
        body: const Center(child: Text('Could not load resume. Please save first.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview'),
        actions: [
          IconButton(icon: const Icon(Icons.print),
            onPressed: () async {
              await PDFService().printResume(resume);
            }),
          IconButton(icon: const Icon(Icons.share),
            onPressed: () { /* generate share link */ }),
        ],
      ),
      body: PdfPreview(
        build: (format) async {
          return await PDFService().generatePDFBytes(resume);
        },
        allowPrinting: false,
        allowSharing: false,
        canChangePageFormat: false,
        pdfPreviewPageDecoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
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
