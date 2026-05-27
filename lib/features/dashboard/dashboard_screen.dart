import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/resume_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/resume_model.dart';
import '../../services/auth_service.dart';
import '../../services/admob_service.dart';
import '../../services/linkedin_service.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/shared_widgets.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumes = ref.watch(resumeListProvider);
    final user = ref.watch(authStateProvider).value;

    return Scaffold(
      backgroundColor: context.appColors.bg,
      body: AmbientBackground(
        child: CustomScrollView(
        slivers: [
          // ─── Premium SliverAppBar ───
          SliverAppBar(
            expandedHeight: 220,
            floating: false,
            pinned: true,
            backgroundColor: context.appColors.surface,
            elevation: 0,
            leading: Builder(
              builder: (ctx) => IconButton(
                icon: Icon(
                  Icons.menu_rounded,
                  color: context.appColors.textPrimary,
                ),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.notifications_none_rounded,
                    color: context.appColors.textSecondary),
                onPressed: () {},
              ),
              CircleAvatar(
                radius: 17,
                backgroundColor: AppColors.primary.withValues(alpha: 0.18),
                child: Text(
                  (user?.displayName?.isNotEmpty == true
                          ? user!.displayName![0]
                          : user?.email?[0] ?? 'U')
                      .toUpperCase(),
                  style: TextStyle(
                    color: AppColors.primaryLight,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              SizedBox(width: 16),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _AppBarBackground(user: user),
            ),
          ),

          // ─── Features Section ───
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(
                    title: 'Features',
                    subtitle: 'Everything you need to land the job',
                  ),
                  SizedBox(height: 16),
                  _FeatureGrid(),
                  SizedBox(height: 16),
                  _LinkedInImportCard(),
                  SizedBox(height: 24),
                  SectionHeader(
                    title: 'My Resumes',
                    subtitle: 'Tap to edit · long press for options',
                    trailing: resumes.whenOrNull(
                      data: (list) => list.isNotEmpty
                          ? GradientBadge(text: '${list.length}')
                          : null,
                    ),
                  ),
                  SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // ─── Resume List ───
          resumes.when(
            loading: () => SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppColors.primary),
                    SizedBox(height: 16),
                    Text(
                      'Loading your resumes...',
                      style: TextStyle(color: context.appColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(
                child: Text(
                  'Error: $e',
                  style: TextStyle(color: context.appColors.textSecondary),
                ),
              ),
            ),
            data: (list) => list.isEmpty
                ? SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(context),
                  )
                : SliverPadding(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => Padding(
                          padding: EdgeInsets.only(bottom: 14),
                          child: _ResumeCard(resume: list[i]),
                        ),
                        childCount: list.length,
                      ),
                    ),
                  ),
          ),
        ],
      ),
      ), // AmbientBackground
      drawer: _buildDrawer(context, ref),
      floatingActionButton: _buildFAB(context),
    );
  }

  Widget _buildFAB(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => context.push('/templates'),
      backgroundColor: AppColors.primary,
      elevation: 6,
      icon: const Icon(Icons.add_rounded, color: Colors.white),
      label: const Text(
        'New Resume',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: context.appColors.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.description_outlined,
                color: context.appColors.textMuted,
                size: 42,
              ),
            ),
            SizedBox(height: 28),
            Text(
              'No resumes yet',
              style: TextStyle(
                color: context.appColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Create your first ATS-optimised resume\nand land your dream job.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.appColors.textSecondary,
                fontSize: 14,
                height: 1.6,
              ),
            ),
            SizedBox(height: 32),
            GradientButton(
              label: 'Create My First Resume',
              onPressed: () => context.push('/templates'),
              width: 260,
              icon: Icon(Icons.add_rounded, color: Colors.white, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, WidgetRef ref) {
    return Drawer(
      backgroundColor: context.appColors.surface,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(24, 60, 24, 28),
            color: AppColors.surfaceDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Icon(
                    Icons.description_rounded,
                    color: AppColors.primaryLight,
                    size: 26,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Ats.Ai',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Career Intelligence Platform',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          SizedBox(height: 12),
          _DrawerItem(
            icon: Icons.upload_file_rounded,
            label: 'Upload Resume',
            onTap: () {
              Navigator.pop(context);
              context.push('/upload-resume');
            },
          ),
          _DrawerItem(
            icon: Icons.add_circle_outline_rounded,
            label: 'New Resume',
            onTap: () {
              Navigator.pop(context);
              context.push('/templates');
            },
          ),
          _DrawerItem(
            icon: Icons.work_outline_rounded,
            label: 'Job Tracker',
            onTap: () {
              Navigator.pop(context);
              context.push('/job-tracker');
            },
          ),
          _DrawerItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
            onTap: () {
              Navigator.pop(context);
              context.push('/settings');
            },
          ),
          Spacer(),
          Divider(color: context.appColors.border),
          _DrawerItem(
            icon: Icons.logout_rounded,
            label: 'Sign Out',
            isDestructive: true,
            onTap: () {
              Navigator.pop(context);
              ref.read(authServiceProvider).signOut();
            },
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ─── App Bar Background ────────────────────────────────────────────────────────
class _AppBarBackground extends ConsumerWidget {
  final dynamic user;
  const _AppBarBackground({required this.user});

  String _firstName(String? displayName) {
    final trimmed = displayName?.trim();
    if (trimmed == null || trimmed.isEmpty) return 'there';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? AppColors.bgDark : AppColors.bgLight,
      child: Stack(
        children: [
          // Structured right-side accent stripe — clean, geometric, intentional
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Row(
              children: [
                Container(
                  width: 3,
                  color: AppColors.primary.withValues(alpha: isDark ? 0.35 : 0.2),
                ),
                SizedBox(width: 4),
                Container(
                  width: 3,
                  color: AppColors.accent.withValues(alpha: isDark ? 0.25 : 0.15),
                ),
                SizedBox(width: 6),
                Container(
                  width: 1.5,
                  color: AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.1),
                ),
              ],
            ),
          ),
          // Subtle accent rule — solid, no gradient
          Positioned(
            left: 24,
            right: 80,
            bottom: 20,
            child: Container(
              height: 1.5,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Greeting content
          Align(
            alignment: Alignment.bottomLeft,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 0, 80, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 28,
                          height: 3,
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'CAREER DASHBOARD',
                          style: TextStyle(
                            color: AppColors.accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.8,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Hello, ${_firstName(user?.displayName)} 👋',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.appColors.textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Your AI-powered career toolkit is ready.',
                      style: TextStyle(
                        color: context.appColors.textSecondary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Feature Grid ──────────────────────────────────────────────────────────────
class _FeatureGrid extends ConsumerWidget {
  // Hero card (full width)
  static final _hero = _FeatureItem(
    icon: Icons.description_rounded,
    title: 'Build Resume',
    subtitle: 'ATS-optimised templates',
    tintColor: AppColors.primary,
    directRoute: '/templates',
    cardType: _CardType.hero,
  );

  static final _scoreCard = _FeatureItem(
    icon: Icons.center_focus_strong_rounded,
    title: 'ATS Score',
    subtitle: 'Beat the bots',
    tintColor: AppColors.primaryDark,
    resumeRoute: '/ats',
    cardType: _CardType.tall,
  );

  static final _autoTailorCard = _FeatureItem(
    icon: Icons.auto_fix_high_rounded,
    title: 'Auto-Tailor',
    subtitle: 'AI rewrites your resume to perfectly match a job description',
    tintColor: AppColors.scoreGreen,
    resumeRoute: '/auto-tailor',
    cardType: _CardType.wide,
  );

  static final _coverLetterCard = _FeatureItem(
    icon: Icons.mail_rounded,
    title: 'Cover Letter',
    subtitle: 'AI generated',
    tintColor: AppColors.accent,
    resumeRoute: '/cover-letter',
    cardType: _CardType.tall,
  );

  static final _bottomRow = [
    _FeatureItem(
      icon: Icons.upload_file_rounded,
      title: 'Upload Resume',
      subtitle: 'Scan & score existing PDF',
      tintColor: const Color(0xFF7C3AED), // violet
      directRoute: '/upload-resume',
      cardType: _CardType.compact,
    ),
    _FeatureItem(
      icon: Icons.work_rounded,
      title: 'Job Tracker',
      subtitle: 'Track applications',
      tintColor: const Color(0xFF64748B),
      directRoute: '/job-tracker',
      cardType: _CardType.compact,
    ),
    _FeatureItem(
      icon: Icons.file_download_rounded,
      title: 'Export PDF',
      subtitle: 'Download & share',
      tintColor: AppColors.primary,
      resumeRoute: '/preview',
      cardType: _CardType.compact,
    ),
  ];

  // All heights are explicit — no IntrinsicHeight, no Expanded height inference.
  static final double _heroH = 108.0;
  static final double _tallH = 130.0;
  static final double _gap = 12.0;
  static final double _wideH = _tallH * 2 + _gap;
  static final double _compactH = 116.0;

  const _FeatureGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumes = ref.watch(resumeListProvider).value ?? [];

    return Column(
      children: [
        // ── Row 1: Hero (full width) ──
        SizedBox(
          height: _heroH,
          child: _FeatureCard(feature: _hero, resumes: resumes),
        ),
        SizedBox(height: _gap),

        // ── Row 2: 2 equal tall left + 1 matching right ──
        SizedBox(
          height: _wideH,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Column(
                  children: [
                    SizedBox(
                      height: _tallH,
                      child: _FeatureCard(
                        feature: _scoreCard,
                        resumes: resumes,
                      ),
                    ),
                    SizedBox(height: _gap),
                    SizedBox(
                      height: _tallH,
                      child: _FeatureCard(
                        feature: _coverLetterCard,
                        resumes: resumes,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: _gap),
              Expanded(
                child: _FeatureCard(feature: _autoTailorCard, resumes: resumes),
              ),
            ],
          ),
        ),
        SizedBox(height: _gap),

        // ── Row 3: 3 equal compact cards ──
        SizedBox(
          height: _compactH,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _bottomRow.asMap().entries.map((entry) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: entry.key == 0 ? 0 : 6,
                    right: entry.key == _bottomRow.length - 1 ? 0 : 6,
                  ),
                  child: _FeatureCard(feature: entry.value, resumes: resumes),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

enum _CardType { hero, tall, wide, compact }

class _FeatureItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color tintColor;
  final String? directRoute;
  final String? resumeRoute;
  final _CardType cardType;

  _FeatureItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tintColor,
    this.directRoute,
    this.resumeRoute,
    this.cardType = _CardType.compact,
  });
}

// ─── Feature Card ──────────────────────────────────────────────────────────────
class _FeatureCard extends ConsumerStatefulWidget {
  final _FeatureItem feature;
  final List<ResumeModel> resumes;

  const _FeatureCard({required this.feature, required this.resumes});

  @override
  ConsumerState<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends ConsumerState<_FeatureCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 100),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // ── Card heights by type ──
  void _onTap() async {
    final f = widget.feature;

    if (DateTime.now().millisecondsSinceEpoch % 3 == 0) {
      await ref.read(adServiceProvider).showInterstitialAd();
    }
    if (!mounted) return;

    if (f.directRoute != null) {
      context.push(f.directRoute!);
      return;
    }

    if (f.resumeRoute != null) {
      final resumes = widget.resumes;
      if (resumes.isEmpty) {
        _showNoResumeSheet(f);
        return;
      }
      if (resumes.length == 1) {
        context.push('${f.resumeRoute}/${resumes.first.id}');
        return;
      }
      _showResumePicker(f, resumes);
    }
  }

  void _showNoResumeSheet(_FeatureItem f) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.appColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(24, 20, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.appColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 24),
            _FeatureIconBox(icon: f.icon, size: 56, iconSize: 28),
            SizedBox(height: 12),
            Text(
              'No resumes yet',
              style: TextStyle(
                color: context.appColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Create a resume first, then use "${f.title}" from within the editor.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.appColors.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            SizedBox(height: 24),
            GradientButton(
              label: 'Create Resume',
              onPressed: () {
                Navigator.pop(context);
                context.push('/templates');
              },
              icon: Icon(Icons.add_rounded, color: Colors.white, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  void _showResumePicker(_FeatureItem f, List<ResumeModel> resumes) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.appColors.card,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        maxChildSize: 0.85,
        builder: (_, scrollCtrl) => Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.appColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 20),
              Row(
                children: [
                  _FeatureIconBox(icon: f.icon, size: 42, iconSize: 22),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          f.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.appColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Select a resume to continue',
                          style: TextStyle(
                            color: context.appColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Divider(color: context.appColors.border),
              SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  controller: scrollCtrl,
                  itemCount: resumes.length,
                  separatorBuilder: (_, _) => SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final r = resumes[i];
                    final scoreColor = AppColors.scoreColor(r.atsScore);
                    return ListTile(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      tileColor: context.appColors.surface,
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: scoreColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            '${r.atsScore}',
                            style: TextStyle(
                              color: scoreColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        r.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.appColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        r.targetRole.isNotEmpty
                            ? r.targetRole
                            : 'No target role set',
                        style: TextStyle(
                          color: context.appColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: context.appColors.textMuted,
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        context.push('${f.resumeRoute}/${r.id}');
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final f = widget.feature;
    final isHero = f.cardType == _CardType.hero;
    final isWide = f.cardType == _CardType.wide;
    final isCompact = f.cardType == _CardType.compact;

    Widget cardContent;

    if (isHero) {
      // ── Hero: horizontal layout with arrow button ──
      cardContent = Padding(
        padding: EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(f.icon, color: Colors.white, size: 26),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    f.title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    f.subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ],
        ),
      );
    } else if (isWide) {
      // ── Wide: vertical with large watermark icon ──
      cardContent = Stack(
        children: [
          Positioned(
            right: -16,
            bottom: -16,
            child: Icon(
              f.icon,
              size: 110,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(f.icon, color: Colors.white, size: 24),
                ),
                Spacer(),
                Text(
                  f.title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  f.subtitle,
                  maxLines: 3,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 11.5,
                    height: 1.45,
                  ),
                ),
                SizedBox(height: 14),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Text(
                    'Try it →',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    } else if (isCompact) {
      // ── Compact: icon top, text bottom — uses full SizedBox height from parent ──
      cardContent = Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            right: -8,
            bottom: -8,
            child: Icon(
              f.icon,
              size: 52,
              color: Colors.white.withValues(alpha: 0.09),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(f.icon, color: Colors.white, size: 18),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.1,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      f.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 9.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      // ── Tall: icon top, text bottom — uses full SizedBox height from parent ──
      cardContent = Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            right: -10,
            bottom: -10,
            child: Icon(
              f.icon,
              size: 72,
              color: Colors.white.withValues(alpha: 0.09),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(f.icon, color: Colors.white, size: 21),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      f.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.68),
                        fontSize: 10.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        _onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: isDark
              ? BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Color.alphaBlend(
                        f.tintColor.withValues(alpha: 0.24),
                        const Color(0x0DFFFFFF),
                      ),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.13),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: f.tintColor.withValues(alpha: 0.20),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.28),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: cardContent,
                  ),
                )
              : Container(
                  decoration: BoxDecoration(
                    // Solid vivid tint in light mode — cards look vibrant
                    color: f.tintColor.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.30),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: f.tintColor.withValues(alpha: 0.28),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: cardContent,
                ),
        ),
      ),
    );
  }
}

// ── Small icon box helper ──────────────────────────────────────────────────────
class _FeatureIconBox extends StatelessWidget {
  final IconData icon;
  final double size;
  final double iconSize;
  const _FeatureIconBox({
    required this.icon,
    required this.size,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(icon, color: AppColors.primaryLight, size: iconSize),
    );
  }
}

// ─── Supporting Widgets ────────────────────────────────────────────────────────

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? AppColors.error
        : context.appColors.textSecondary;
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      horizontalTitleGap: 12,
    );
  }
}

class _ResumeCard extends ConsumerWidget {
  final ResumeModel resume;
  const _ResumeCard({required this.resume});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final score = resume.atsScore;
    final scoreColor = AppColors.scoreColor(score);

    return GestureDetector(
      onTap: () => context.push('/editor/${resume.id}'),
      onLongPress: () => _showOptions(context, ref),
      child: GlassCard(
        padding: EdgeInsets.all(18),
        showGlow: score >= 80,
        glowColor: scoreColor,
        child: Row(
          children: [
            _CompactScoreRing(score: score, color: scoreColor),
            SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    resume.title,
                    style: TextStyle(
                      color: context.appColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      _MetaChip(
                        icon: Icons.access_time_rounded,
                        label: _formatDate(resume.lastEdited),
                      ),
                      _MetaChip(
                        icon: Icons.download_outlined,
                        label: '${resume.downloadCount}',
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  _ScoreBar(score: score, color: scoreColor),
                ],
              ),
            ),
            SizedBox(width: 12),
            Column(
              children: [
                _MiniAction(
                  icon: Icons.visibility_outlined,
                  color: AppColors.primary,
                  onTap: () => context.push('/preview/${resume.id}'),
                ),
                SizedBox(height: 8),
                _MiniAction(
                  icon: Icons.chevron_right_rounded,
                  color: context.appColors.textMuted,
                  onTap: () => context.push('/editor/${resume.id}'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  void _showOptions(BuildContext ctx, WidgetRef ref) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: ctx.appColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: ctx.appColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 20),
            Text(
              resume.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ctx.appColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 20),
            _OptionTile(
              icon: Icons.edit_outlined,
              label: 'Edit Resume',
              onTap: () {
                Navigator.pop(ctx);
                ctx.push('/editor/${resume.id}');
              },
            ),
            _OptionTile(
              icon: Icons.visibility_outlined,
              label: 'Preview Resume',
              onTap: () {
                Navigator.pop(ctx);
                ctx.push('/preview/${resume.id}');
              },
            ),
            _OptionTile(
              icon: Icons.analytics_outlined,
              label: 'Check ATS Score',
              onTap: () {
                Navigator.pop(ctx);
                ctx.push('/ats/${resume.id}');
              },
            ),
            _OptionTile(
              icon: Icons.auto_fix_high_rounded,
              label: 'Auto-Tailor Resume',
              onTap: () {
                Navigator.pop(ctx);
                ctx.push('/auto-tailor/${resume.id}');
              },
            ),
            _OptionTile(
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              isDestructive: true,
              onTap: () {
                Navigator.pop(ctx);
                ref.read(resumeActionsProvider).deleteResume(resume.id);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _MiniAction({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

class _CompactScoreRing extends StatelessWidget {
  final int score;
  final Color color;

  const _CompactScoreRing({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      height: 74,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$score',
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'SCORE',
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: context.appColors.textMuted),
        SizedBox(width: 4),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 140),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: context.appColors.textMuted, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _ScoreBar extends StatelessWidget {
  final int score;
  final Color color;
  const _ScoreBar({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: score / 100,
        backgroundColor: context.appColors.border,
        valueColor: AlwaysStoppedAnimation<Color>(color),
        minHeight: 4,
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;
  const _OptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? AppColors.error
        : context.appColors.textPrimary;
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

// ─── LinkedIn Import Card ──────────────────────────────────────────────────────
class _LinkedInImportCard extends StatelessWidget {
  const _LinkedInImportCard();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _LinkedInImportSheet(),
      ),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0077B5), Color(0xFF004471)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF0077B5).withValues(alpha: 0.35),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  'in',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    letterSpacing: -1,
                  ),
                ),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Import from LinkedIn',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Auto-build your resume from LinkedIn data',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── LinkedIn Import Sheet ─────────────────────────────────────────────────────
class _LinkedInImportSheet extends ConsumerStatefulWidget {
  const _LinkedInImportSheet();

  @override
  ConsumerState<_LinkedInImportSheet> createState() =>
      _LinkedInImportSheetState();
}

class _LinkedInImportSheetState extends ConsumerState<_LinkedInImportSheet> {
  Future<void> _importZip() async {
    Navigator.pop(context);
    try {
      final service = ref.read(linkedInImportServiceProvider);
      final data = await service.importFromZip();
      if (data == null) return;

      final newId = await ref
          .read(resumeActionsProvider)
          .createNewResume('modern');
      if (newId.isEmpty) throw Exception('Failed to create resume');

      final notifier = ref.read(resumeNotifierProvider(newId).notifier);
      notifier.updateSection('personal', {
        'name': data['name'] ?? '',
        'email': data['email'] ?? '',
        'phone': data['phone'] ?? '',
        'summary': data['summary'] ?? '',
        'headline': data['headline'] ?? '',
        'location': data['location'] ?? '',
      });

      if (data['experience'] is List &&
          (data['experience'] as List).isNotEmpty) {
        notifier.updateSection(
          'experience',
          List<Map<String, dynamic>>.from(
            (data['experience'] as List).map(
              (e) => {
                'title': e['title'] ?? '',
                'company': e['company'] ?? '',
                'dates': e['dates'] ?? '',
                'location': e['location'] ?? '',
                'description': e['description'] ?? '',
              },
            ),
          ),
        );
      }
      if (data['education'] is List && (data['education'] as List).isNotEmpty) {
        notifier.updateSection(
          'education',
          List<Map<String, dynamic>>.from(
            (data['education'] as List).map(
              (e) => {
                'degree': e['degree'] ?? '',
                'institution': e['institution'] ?? '',
                'year': e['year'] ?? '',
              },
            ),
          ),
        );
      }
      if (data['skills'] is List && (data['skills'] as List).isNotEmpty) {
        notifier.updateSection(
          'skills',
          List<String>.from(data['skills'] as List),
        );
      }

      await notifier.save();
      if (mounted) {
        _showSnack(
          'Resume built from LinkedIn! Review and edit it.',
          success: true,
        );
        if (context.mounted) context.push('/editor/$newId');
      }
    } catch (e) {
      if (mounted) {
        _showSnack(
          e.toString().replaceFirst('Exception: ', ''),
          success: false,
        );
      }
    }
  }

  void _showSnack(String msg, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? Color(0xFF0077B5) : AppColors.scoreRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _importOAuth() {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.appColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'LinkedIn OAuth',
          style: TextStyle(
            color: context.appColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'To enable "Sign in with LinkedIn", you need to:\n\n'
          '1. Create a LinkedIn app at linkedin.com/developers\n'
          '2. Add LINKEDIN_CLIENT_ID & LINKEDIN_CLIENT_SECRET to your Render env vars\n'
          '3. Set redirect URI to:\nhttps://ats-resume-server.onrender.com/api/linkedin/callback\n\n'
          'Until then, use the ZIP import - it gives you the most complete data.',
          style: TextStyle(
            color: context.appColors.textSecondary,
            fontSize: 13,
            height: 1.6,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Got it', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: context.appColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: 22),
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Color(0xFF0077B5).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    'in',
                    style: TextStyle(
                      color: Color(0xFF0077B5),
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Import from LinkedIn',
                      style: TextStyle(
                        color: context.appColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Choose how to import your profile',
                      style: TextStyle(
                        color: context.appColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          _SheetOption(
            icon: Icons.person_rounded,
            iconBg: Color(0xFF0077B5),
            title: 'Sign in with LinkedIn',
            subtitle: 'Quick login - imports name and email',
            badge: 'Requires Setup',
            badgeColor: AppColors.scoreOrange,
            onTap: _importOAuth,
          ),
          SizedBox(height: 12),
          _SheetOption(
            icon: Icons.upload_file_rounded,
            iconBg: AppColors.primary,
            title: 'Upload LinkedIn Data ZIP',
            subtitle: 'Full import - work history, education, skills and more',
            badge: 'Recommended',
            badgeColor: AppColors.scoreGreen,
            onTap: _importZip,
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.appColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.appColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  color: AppColors.accentGold,
                  size: 18,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'To get your ZIP: LinkedIn > Me > Settings & Privacy > Data Privacy > Get a copy of your data > Select "Want something in particular?" > Profile data > Request archive',
                    style: TextStyle(
                      color: context.appColors.textSecondary,
                      fontSize: 11,
                      height: 1.55,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;
  final VoidCallback onTap;

  const _SheetOption({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.appColors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: iconBg.withValues(alpha: 0.08),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBg.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: iconBg, size: 22),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: 190),
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.appColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: badgeColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              fontSize: 9,
                              color: badgeColor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.appColors.textSecondary,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: context.appColors.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
