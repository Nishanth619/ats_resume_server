import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/auth_service.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/shared_widgets.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Scaffold(
      backgroundColor: context.appColors.bg,
      appBar: GradientAppBar(title: 'Settings'),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Profile card
            GlassCard(
              showGlow: true,
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: context.appColors.primaryGradient,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        (user?.displayName?.isNotEmpty == true
                                ? user!.displayName![0]
                                : user?.email?[0] ?? 'U')
                            .toUpperCase(),
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.displayName ?? 'User',
                          style: TextStyle(
                              color: context.appColors.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 4),
                        Text(
                          user?.email ?? '',
                          style: TextStyle(
                              color: context.appColors.textSecondary, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 8),
                        GradientBadge(text: 'Free Plan'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 28),
            _SectionLabel(label: 'Appearance'),
            _SettingsTile(
              icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              label: 'Theme',
              subtitle: isDark ? 'Dark mode' : 'Light mode',
              trailing: Switch.adaptive(
                value: isDark,
                activeThumbColor: AppColors.primaryLight,
                onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
              ),
              onTap: () => ref.read(themeModeProvider.notifier).toggle(),
            ),

            SizedBox(height: 20),
            _SectionLabel(label: 'Account'),
            _SettingsTile(
              icon: Icons.person_outline_rounded,
              label: 'Account Information',
              subtitle: user?.email ?? 'Manage your profile',
              onTap: () {
                // Show account info bottom sheet
                _showAccountInfo(context, user);
              },
            ),

            SizedBox(height: 20),
            _SectionLabel(label: 'Legal'),
            _SettingsTile(
              icon: Icons.privacy_tip_outlined,
              label: 'Privacy Policy',
              onTap: () => _launchUrl('https://ats-resume-builder.app/privacy'),
            ),
            _SettingsTile(
              icon: Icons.description_outlined,
              label: 'Terms of Service',
              onTap: () => _launchUrl('https://ats-resume-builder.app/terms'),
            ),

            SizedBox(height: 20),
            _SectionLabel(label: 'Support'),
            _SettingsTile(
              icon: Icons.help_outline_rounded,
              label: 'Help & FAQ',
              subtitle: 'Get help with the app',
              onTap: () => _launchUrl('mailto:support@ats-resume-builder.app?subject=Help%20Request'),
            ),
            _SettingsTile(
              icon: Icons.star_outline_rounded,
              label: 'Rate the App',
              subtitle: 'Love ATS.ai? Leave a review',
              onTap: () => _launchUrl('https://play.google.com/store/apps/details?id=com.atsai.resume'),
            ),
            _SettingsTile(
              icon: Icons.share_rounded,
              label: 'Share with Friends',
              subtitle: 'Help others land their dream job',
              onTap: () => _launchUrl('https://play.google.com/store/apps/details?id=com.atsai.resume'),
            ),

            SizedBox(height: 32),
            // Danger zone
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Danger Zone',
                      style: TextStyle(
                          color: AppColors.scoreRed,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                  SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => _confirmSignOut(context, ref),
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.scoreRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.scoreRed.withValues(alpha: 0.3),
                            width: 1),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout_rounded,
                              color: AppColors.scoreRed, size: 18),
                          SizedBox(width: 10),
                          Text('Sign Out',
                              style: TextStyle(
                                  color: AppColors.scoreRed,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 32),
            Text('ATS.ai v1.0.0\nBuilt with ❤️ for job seekers',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: context.appColors.textMuted,
                    fontSize: 12,
                    height: 1.6)),
          ],
        ),
      ),
    );
  }

  void _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showAccountInfo(BuildContext context, dynamic user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.appColors.card,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(24, 20, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: context.appColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
            SizedBox(height: 24),
            Text('Account Details',
                style: TextStyle(
                    color: context.appColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            SizedBox(height: 20),
            _InfoRow(label: 'Name', value: user?.displayName ?? 'Not set'),
            _InfoRow(label: 'Email', value: user?.email ?? 'Unknown'),
            _InfoRow(label: 'UID', value: user?.uid?.substring(0, 12) ?? '—'),
            _InfoRow(label: 'Plan', value: 'Free'),
          ],
        ),
      ),
    );
  }

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.appColors.card,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(24, 20, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: context.appColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
            SizedBox(height: 24),
            Text('👋', style: TextStyle(fontSize: 48)),
            SizedBox(height: 16),
            Text('Sign Out?',
                style: TextStyle(
                    color: context.appColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
            SizedBox(height: 8),
            Text('You can always come back and log in again.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: context.appColors.textSecondary, fontSize: 14)),
            SizedBox(height: 28),
            GradientButton(
              label: 'Yes, Sign Out',
              onPressed: () {
                Navigator.pop(context);
                ref.read(authServiceProvider).signOut();
              },
              gradient: LinearGradient(
                  colors: [AppColors.error, Color(0xFFC0392B)]),
            ),
            SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style: TextStyle(
                      color: context.appColors.textSecondary,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                  color: context.appColors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          Spacer(),
          Text(value,
              style: TextStyle(
                  color: context.appColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 4, bottom: 10),
      child: Text(label.toUpperCase(),
          style: TextStyle(
              color: context.appColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2)),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.appColors.border, width: 1),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primaryLight, size: 18),
        ),
        title: Text(label,
            style: TextStyle(
                color: context.appColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14)),
        subtitle: subtitle != null
            ? Text(subtitle!,
                style: TextStyle(
                    color: context.appColors.textMuted, fontSize: 12))
            : null,
        trailing: trailing ??
            Icon(Icons.chevron_right_rounded,
                color: context.appColors.textMuted, size: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

