import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:go_router/go_router.dart';
import '../../providers/resume_provider.dart';
import '../../services/pdf_service.dart';
import '../../models/resume_model.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../core/utils/isolate_utils.dart';

class ResumePreviewScreen extends ConsumerWidget {
  final String resumeId;
  const ResumePreviewScreen({super.key, required this.resumeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get local state from the editor instantly (includes unsaved changes)
    ResumeModel? resume = ref.watch(resumeNotifierProvider(resumeId));
    if (resume == null) {
      final asyncVal = ref.watch(resumeStreamProvider(resumeId));
      if (asyncVal.isLoading) {
        return Scaffold(
          backgroundColor: context.appColors.bg,
          body: Center(
              child: CircularProgressIndicator(color: AppColors.primaryLight)),
        );
      }
      resume = asyncVal.value;
    }

    if (resume == null) {
      return Scaffold(
        backgroundColor: context.appColors.bg,
        appBar: GradientAppBar(title: 'Preview'),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('📄', style: TextStyle(fontSize: 48)),
              SizedBox(height: 16),
              Text('Could not load resume',
                  style: TextStyle(
                      color: context.appColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              SizedBox(height: 8),
              Text('Please save your resume first.',
                  style: TextStyle(color: context.appColors.textSecondary, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: context.appColors.bg,
      appBar: GradientAppBar(
        title: 'Preview',
        actions: [
          IconButton(
            icon: Icon(Icons.print_rounded,
                color: context.appColors.textPrimary, size: 22),
            onPressed: () async {
              await PDFService().printResume(resume!);
            },
          ),
          SizedBox(width: 8),
        ],
      ),
      body: Container(
        margin: EdgeInsets.fromLTRB(12, 12, 12, 0),
        decoration: BoxDecoration(
          color: context.appColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: context.appColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: PdfPreview(
          build: (format) async {
            return await generatePDFInBackground(resume!);
          },
          allowPrinting: false,
          allowSharing: false,
          canChangePageFormat: false,
          canChangeOrientation: false,
          pdfPreviewPageDecoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: GradientButton(
            label: 'Download for Free — Watch Ad',
            onPressed: () => context.push('/download/$resumeId'),
            icon: Icon(Icons.download_rounded,
                color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

