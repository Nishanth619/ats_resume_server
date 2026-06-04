import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/admob_service.dart';
import '../../services/ad_block_guard.dart';
import '../../services/pdf_service.dart';
import '../../services/storage_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/resume_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../core/utils/isolate_utils.dart';
import 'package:share_plus/share_plus.dart';

class DownloadScreen extends ConsumerStatefulWidget {
  final String resumeId;
  const DownloadScreen({super.key, required this.resumeId});
  @override
  ConsumerState<DownloadScreen> createState() => _DLState();
}

class _DLState extends ConsumerState<DownloadScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = false;
  bool _done = false;
  String _status = 'Watch a short ad to download your resume completely FREE';
  String? _filePath;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    ref.read(adServiceProvider).loadRewardedAd();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _executeDownload() async {
    try {
      final resume = await fetchResumeForExport(ref, widget.resumeId);
      // Generate PDF on a background isolate — keeps the UI at 60fps
      final bytes = await generatePDFInBackground(resume);
      final file = await PDFService().savePDFBytesToFile(resume, bytes);
      final user = ref.read(authStateProvider).value;
      if (user != null && widget.resumeId != 'new') {
        try {
          await ref
              .read(storageServiceProvider)
              .uploadResumePDF(user.uid, widget.resumeId, file);
        } catch (_) {
          // Keep the local download successful even if cloud PDF refresh fails.
        }
      }

      try {
        await ref
            .read(resumeNotifierProvider(widget.resumeId).notifier)
            .incrementDownload();
      } catch (_) {}

      if (mounted) {
        setState(() {
          _done = true;
          _loading = false;
          _filePath = file.path;
          _status = 'Resume downloaded successfully!';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _status = 'Error: $e';
        });
      }
    }
  }

  Future<void> _download() async {
    final adSvc = ref.read(adServiceProvider);

    // Block if ad blocker / private DNS detected (free users only)
    final guardOk = await AdBlockGuard.check(context, ref);
    if (!guardOk) return;

    // If ad is not ready yet, try loading it once
    if (!adSvc.isRewardedReady) {
      setState(() => _status = 'Preparing download...');
      await adSvc.loadRewardedAd();
      await Future.delayed(const Duration(seconds: 2));

      // If the ad network has no fill, bypass gracefully (not a blocker case)
      if (!adSvc.isRewardedReady) {
        setState(() {
          _loading = true;
          _status = 'Generating PDF...';
        });
        await _executeDownload();
        return;
      }
    }

    setState(() => _loading = true);
    await adSvc.showRewardedAd(
      onRewarded: _executeDownload,
      onFailed: () {
        if (mounted) {
          // If the ad fails mid-show, bypass and download anyway
          _executeDownload();
        }
      },
    );
  }

  Future<void> _shareFile() async {
    if (_filePath == null) return;
    await Share.shareXFiles([XFile(_filePath!)], subject: 'My Ats.Ai Resume');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.appColors.bg,
    appBar: GradientAppBar(title: 'Download Resume'),
    body: Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated icon
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, child) => Transform.scale(
                scale: _done ? 1.0 : 1.0 + (_pulseCtrl.value * 0.05),
                child: child,
              ),
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: context.appColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: (_done ? AppColors.scoreGreen : AppColors.primary)
                        .withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  _done ? Icons.check_circle_outlined : Icons.download_outlined,
                  size: 52,
                  color: _done ? AppColors.scoreGreen : context.appColors.textMuted,
                ),
              ),
            ),

            SizedBox(height: 32),

            // Status text
            Text(
              _done ? '🎉 Download Complete!' : 'Free Resume Download',
              style: TextStyle(
                color: context.appColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 12),
            Text(
              _status,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.appColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),

            if (_filePath != null) ...[
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: context.appColors.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.appColors.border),
                ),
                child: Text(
                  _filePath!.split('/').last,
                  style: TextStyle(
                    color: context.appColors.textMuted,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],

            SizedBox(height: 36),

            // Action buttons
            if (_done) ...[
              GradientButton(
                label: 'Share Resume',
                onPressed: _shareFile,
                icon: Icon(Icons.share_rounded, color: Colors.white, size: 18),
              ),
              SizedBox(height: 12),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: context.appColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: context.appColors.border,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Back to Editor',
                      style: TextStyle(
                        color: context.appColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
            ] else if (_loading) ...[
              CircularProgressIndicator(color: AppColors.primaryLight),
              SizedBox(height: 16),
              Text(
                _status.contains('Generating')
                    ? 'Creating your PDF...'
                    : 'Loading ad...',
                style: TextStyle(
                  color: context.appColors.textMuted,
                  fontSize: 13,
                ),
              ),
            ] else ...[
              GradientButton(
                label: 'Watch Ad & Download FREE',
                onPressed: _download,
                icon: Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],

            SizedBox(height: 24),
            if (!_done)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.scoreGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.scoreGreen.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_rounded,
                      color: AppColors.scoreGreen,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'FREE • No payment required',
                      style: TextStyle(
                        color: AppColors.scoreGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
