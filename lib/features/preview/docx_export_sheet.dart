import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/docx_export_service.dart';
import '../../providers/resume_provider.dart';

// Mock since Pro is skipped
final isProProvider = Provider<bool>((ref) => false);

/// Call this from ResumePreviewScreen or DownloadScreen
void showExportSheet(BuildContext context, WidgetRef ref, String resumeId) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _ExportSheet(resumeId: resumeId),
  );
}

class _ExportSheet extends ConsumerStatefulWidget {
  final String resumeId;
  const _ExportSheet({required this.resumeId});

  @override
  ConsumerState<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends ConsumerState<_ExportSheet> {
  bool _loading = false;
  double _progress = 0.0;
  String _status = '';

  Future<void> _exportDocx() async {
    final isPro = ref.read(isProProvider);
    if (!isPro) {
      // Redirect non-Pro users to upgrade screen
      Navigator.pop(context);
      context.push('/pro');
      return;
    }
    setState(() {
      _loading = true;
      _status = 'Generating Word document...';
      _progress = 0;
    });

    try {
      final resume = ref.read(resumeStreamProvider(widget.resumeId)).value;
      if (resume == null) throw Exception('Resume not loaded');
      final file = await ref.read(docxServiceProvider).exportToDocx(
        resume,
        onProgress: (p) => setState(() {
          _progress = p;
          _status = p < 1.0
              ? 'Downloading... ${(p * 100).toInt()}%'
              : 'Opening document...';
        }),
      );
      await ref.read(docxServiceProvider).openDocx(file);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() { _loading = false; _status = 'Error: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPro = ref.watch(isProProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle bar
        Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2))),
        const Text('Export Resume',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        // PDF option (always free)
        _ExportOption(
          icon: Icons.picture_as_pdf,
          iconColor: Colors.red,
          title: 'PDF — Free',
          subtitle: 'ATS-safe, watch a 30s ad to download',
          badgeText: 'FREE',
          badgeColor: Colors.green,
          onTap: () {
            Navigator.pop(context);
            context.push('/download/${widget.resumeId}');
          },
        ),
        const SizedBox(height: 12),
        // DOCX option (Pro only)
        _ExportOption(
          icon: Icons.article_outlined,
          iconColor: Colors.blue,
          title: 'Word Document (.docx)',
          subtitle: isPro
              ? 'Edit in Microsoft Word or Google Docs'
              : 'Upgrade to Pro to unlock Word export',
          badgeText: 'PRO',
          badgeColor: Colors.amber.shade700,
          onTap: _loading ? null : _exportDocx,
          trailing: !isPro
              ? const Icon(Icons.lock_outline, color: Colors.grey)
              : null,
        ),
        // Progress indicator
        if (_loading) ...[
          const SizedBox(height: 20),
          LinearProgressIndicator(
              value: _progress > 0 ? _progress : null,
              backgroundColor: Colors.grey.shade200,
              color: const Color(0xFF6366F1)),
          const SizedBox(height: 8),
          Text(_status,
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ]),
    );
  }
}

class _ExportOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title, subtitle, badgeText;
  final Color badgeColor;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _ExportOption({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.badgeColor,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: iconColor)),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                            color: badgeColor,
                            borderRadius: BorderRadius.circular(4)),
                        child: Text(badgeText,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold))),
                  ]),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ])),
            ?trailing,
          ]),
        ),
      );
}
