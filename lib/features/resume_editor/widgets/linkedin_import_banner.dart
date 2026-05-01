import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_links/app_links.dart';
import '../../../services/linkedin_service.dart';
import '../../../providers/resume_provider.dart';
import '../../../core/constants/app_colors.dart';

class LinkedInImportBanner extends ConsumerStatefulWidget {
  final String resumeId;
  final VoidCallback onImported;
  const LinkedInImportBanner({
    super.key,
    required this.resumeId,
    required this.onImported,
  });

  @override
  ConsumerState<LinkedInImportBanner> createState() => _LIBannerState();
}

class _LIBannerState extends ConsumerState<LinkedInImportBanner> {
  bool _loading = false;
  String? _loadingMsg;

  // ─── Apply data from either import method ──────────────────────────────────
  Future<void> _applyLinkedInData(Map<String, dynamic> data) async {
    final notifier = ref.read(resumeNotifierProvider(widget.resumeId).notifier);

    if (data['name'] != null || data['email'] != null ||
        data['phone'] != null || data['summary'] != null) {
      await notifier.updateSection('personal', {
        'name':     data['name'] ?? '',
        'email':    data['email'] ?? '',
        'phone':    data['phone'] ?? '',
        'summary':  data['summary'] ?? '',
        'headline': data['headline'] ?? '',
        'location': data['location'] ?? '',
      });
    }

    if (data['experience'] is List && (data['experience'] as List).isNotEmpty) {
      await notifier.updateSection(
        'experience',
        List<Map<String, dynamic>>.from(
          (data['experience'] as List).map((e) => {
            'title':       e['title'] ?? '',
            'company':     e['company'] ?? '',
            'dates':       e['dates'] ?? '',
            'location':    e['location'] ?? '',
            'description': e['description'] ?? '',
          }),
        ),
      );
    }

    if (data['education'] is List && (data['education'] as List).isNotEmpty) {
      await notifier.updateSection(
        'education',
        List<Map<String, dynamic>>.from(
          (data['education'] as List).map((e) => {
            'degree':      e['degree'] ?? '',
            'institution': e['institution'] ?? '',
            'year':        e['year'] ?? '',
          }),
        ),
      );
    }

    if (data['skills'] is List && (data['skills'] as List).isNotEmpty) {
      await notifier.updateSection(
        'skills',
        List<String>.from(data['skills'] as List),
      );
    }

    await notifier.save();
    widget.onImported();
  }

  // ─── ZIP Import ────────────────────────────────────────────────────────────
  Future<void> _importZip() async {
    setState(() { _loading = true; _loadingMsg = 'Reading ZIP…'; });
    try {
      final service = ref.read(linkedInImportServiceProvider);
      final data = await service.importFromZip();
      if (data == null) return; // user cancelled picker
      setState(() => _loadingMsg = 'Applying profile…');
      await _applyLinkedInData(data);
      if (mounted) _showSuccess('LinkedIn ZIP imported successfully!');
    } catch (e) {
      if (mounted) _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() { _loading = false; _loadingMsg = null; });
    }
  }

  // ─── OAuth Import ──────────────────────────────────────────────────────────
  Future<void> _importOAuth() async {
    setState(() { _loading = true; _loadingMsg = 'Opening LinkedIn…'; });
    try {
      final oauthService = ref.read(linkedInOAuthServiceProvider);
      final oauthUrl = await oauthService.getOAuthUrl();

      // Open in external browser
      final uri = Uri.parse(oauthUrl);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not open LinkedIn login page');
      }

      setState(() => _loadingMsg = 'Waiting for LinkedIn…');

      // Listen for deep link callback
      final appLinks = AppLinks();
      final callbackUri = await appLinks.uriLinkStream
          .firstWhere((u) =>
            u.scheme == 'atsresumebuilder' &&
            u.host == 'linkedin-callback')
          .timeout(
            const Duration(minutes: 5),
            onTimeout: () => throw Exception('LinkedIn login timed out. Please try again.'),
          );

      setState(() => _loadingMsg = 'Applying profile…');
      final data = oauthService.parseCallback(callbackUri);
      if (data != null) {
        await _applyLinkedInData(data);
        if (mounted) _showSuccess('LinkedIn profile connected!');
      }
    } catch (e) {
      if (mounted) _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() { _loading = false; _loadingMsg = null; });
    }
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: const Color(0xFF0077B5),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: AppColors.scoreRed,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ─── Bottom Sheet ──────────────────────────────────────────────────────────
  void _showOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderDark,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Import from LinkedIn',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Choose how to import your profile',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),

            // Option A — OAuth
            _OptionTile(
              icon: Icons.bolt_rounded,
              iconColor: const Color(0xFF0077B5),
              title: 'Connect LinkedIn',
              subtitle: 'Sign in with LinkedIn — imports name & email instantly',
              badge: 'Quick',
              onTap: () {
                Navigator.pop(context);
                _importOAuth();
              },
            ),
            const SizedBox(height: 12),

            // Option B — ZIP
            _OptionTile(
              icon: Icons.upload_file_rounded,
              iconColor: AppColors.primary,
              title: 'Upload LinkedIn Export ZIP',
              subtitle: 'Import full profile: work history, education & skills',
              badge: 'Full Data',
              badgeColor: AppColors.scoreGreen,
              onTap: () {
                Navigator.pop(context);
                _importZip();
              },
            ),
            const SizedBox(height: 16),

            // Help note
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 14, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'To get your ZIP: LinkedIn → Me → Settings & Privacy → Data Privacy → Get a copy of your data → Request archive',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0077B5), Color(0xFF005E92)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0077B5).withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _loading ? null : _showOptions,
          borderRadius: BorderRadius.circular(14),
          splashColor: Colors.white12,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Text('in',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        )),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Import from LinkedIn',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        _loading
                            ? (_loadingMsg ?? 'Importing…')
                            : 'Pre-fill your resume in seconds',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (_loading)
                  const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Import',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Option Tile ───────────────────────────────────────────────────────────────
class _OptionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? badge;
  final Color? badgeColor;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    final bc = badgeColor ?? const Color(0xFF0077B5);
    return Material(
      color: AppColors.cardDark,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(title,
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: bc.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                  color: bc.withOpacity(0.3), width: 1),
                            ),
                            child: Text(badge!,
                                style: TextStyle(
                                    fontSize: 10,
                                    color: bc,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            height: 1.4)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
