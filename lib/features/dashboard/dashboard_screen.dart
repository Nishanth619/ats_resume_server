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
      backgroundColor: AppColors.bgDark,
      body: CustomScrollView(
        slivers: [
          // ─── Premium SliverAppBar ───
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.surfaceDark,
            elevation: 0,
            leading: Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu_rounded, color: AppColors.textPrimary),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
            actions: [
              GradientBadge(text: 'PRO'),
              const SizedBox(width: 12),
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary,
                child: Text(
                  (user?.displayName?.isNotEmpty == true
                          ? user!.displayName![0]
                          : user?.email?[0] ?? 'U')
                      .toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 16),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1A1035), AppColors.bgDark],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Stack(
                  children: [
                    // Decorative glow blobs
                    Positioned(
                      top: -30, right: -30,
                      child: Container(
                        width: 160, height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha: 0.12),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 60, left: -20,
                      child: Container(
                        width: 100, height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.accent.withValues(alpha: 0.08),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 90, 24, 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShaderMask(
                            shaderCallback: (b) =>
                                AppColors.primaryGradient.createShader(b),
                            child: Text(
                              'Hello, ${user?.displayName?.split(' ').first ?? 'there'} 👋',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Your AI-powered career toolkit is ready.',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ─── Feature Grid ───
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(
                      title: 'Features', subtitle: 'Everything you need to land the job'),
                  const SizedBox(height: 16),
                  _FeatureGrid(),
                  const SizedBox(height: 12),
                  // ─── LinkedIn Import Banner ───
                  _LinkedInImportCard(),
                  const SizedBox(height: 20),
                  SectionHeader(
                    title: 'My Resumes',
                    subtitle: 'Tap to edit · Long press for options',
                    trailing: resumes.whenOrNull(
                      data: (list) => list.isNotEmpty
                          ? GradientBadge(text: '${list.length}')
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // ─── Resume List ───
          resumes.when(
            loading: () => const SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppColors.primary),
                    SizedBox(height: 16),
                    Text('Loading your resumes...',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(
                child: Text('Error: $e',
                    style:
                        const TextStyle(color: AppColors.textSecondary)),
              ),
            ),
            data: (list) => list.isEmpty
                ? SliverFillRemaining(child: _buildEmptyState(context))
                : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _ResumeCard(resume: list[i]),
                        ),
                        childCount: list.length,
                      ),
                    ),
                  ),
          ),
        ],
      ),
      drawer: _buildDrawer(context, ref),
      floatingActionButton: _buildFAB(context),
      bottomNavigationBar: ref.watch(bannerAdProvider) != null
          ? Container(
              color: AppColors.surfaceDark,
              padding: const EdgeInsets.only(top: 4),
              child: ref.watch(bannerAdProvider)!,
            )
          : null,
    );
  }

  Widget _buildFAB(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: () => context.push('/templates'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('New Resume',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 30,
                  ),
                ],
              ),
              child: const Center(
                child: Text('📄', style: TextStyle(fontSize: 44)),
              ),
            ),
            const SizedBox(height: 28),
            const Text('No resumes yet',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            const Text(
              'Create your first ATS-optimised resume\nand land your dream job.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 32),
            GradientButton(
              label: 'Create My First Resume',
              onPressed: () => context.push('/templates'),
              width: 260,
              icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, WidgetRef ref) {
    return Drawer(
      backgroundColor: AppColors.surfaceDark,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 28),
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text('📄', style: TextStyle(fontSize: 26)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('ATS.ai',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800)),
                const Text('Career Intelligence Platform',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _DrawerItem(
              icon: Icons.add_circle_outline_rounded,
              label: 'New Resume',
              onTap: () {
                Navigator.pop(context);
                context.push('/templates');
              }),
          _DrawerItem(
              icon: Icons.work_outline_rounded,
              label: 'Job Tracker',
              onTap: () {
                Navigator.pop(context);
                context.push('/job-tracker');
              }),
          _DrawerItem(
              icon: Icons.settings_outlined,
              label: 'Settings',
              onTap: () {
                Navigator.pop(context);
                context.push('/settings');
              }),
          const Spacer(),
          const Divider(color: AppColors.borderDark),
          _DrawerItem(
              icon: Icons.logout_rounded,
              label: 'Sign Out',
              isDestructive: true,
              onTap: () {
                Navigator.pop(context);
                ref.read(authServiceProvider).signOut();
              }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ─── Feature Grid Widget ───
class _FeatureGrid extends ConsumerWidget {
  static const List<_FeatureItem> _features = [
    _FeatureItem(
      emoji: '📄',
      title: 'Build Resume',
      subtitle: 'ATS-optimised templates',
      gradient: AppColors.primaryGradient,
      directRoute: '/templates',
      isLarge: true,
    ),
    _FeatureItem(
      emoji: '🎯',
      title: 'ATS Score',
      subtitle: 'Beat the bots',
      gradient: LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)]),
      resumeRoute: '/ats',
    ),
    _FeatureItem(
      emoji: '🔍',
      title: 'JD Matcher',
      subtitle: 'Match & auto-tailor',
      gradient: AppColors.accentGradient,
      resumeRoute: '/jd',
    ),
    _FeatureItem(
      emoji: '🪄',
      title: 'Auto-Tailor',
      subtitle: 'AI rewrites for JD',
      gradient: LinearGradient(colors: [Color(0xFF059669), Color(0xFF0D9488)]),
      resumeRoute: '/jd',
    ),
    _FeatureItem(
      emoji: '✉️',
      title: 'Cover Letter',
      subtitle: 'AI generated in seconds',
      gradient: LinearGradient(colors: [Color(0xFFD97706), Color(0xFFDC2626)]),
      resumeRoute: '/cover-letter',
    ),
    _FeatureItem(
      emoji: '💼',
      title: 'Job Tracker',
      subtitle: 'Track all applications',
      gradient: LinearGradient(colors: [Color(0xFF0EA5E9), Color(0xFF2563EB)]),
      directRoute: '/job-tracker',
    ),
    _FeatureItem(
      emoji: '⬇️',
      title: 'Export PDF',
      subtitle: 'Download & share',
      gradient: LinearGradient(colors: [Color(0xFF374151), Color(0xFF1F2937)]),
      resumeRoute: '/preview',
    ),
  ];

  const _FeatureGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumes = ref.watch(resumeListProvider).value ?? [];
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemW = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _features.map((f) {
            final width = f.isLarge ? constraints.maxWidth : itemW;
            final height = f.isLarge ? 110.0 : 130.0;
            return _FeatureCard(
              feature: f,
              width: width,
              height: height,
              resumes: resumes,
            );
          }).toList(),
        );
      },
    );
  }
}

class _FeatureItem {
  final String emoji;
  final String title;
  final String subtitle;
  final LinearGradient gradient;
  /// Direct navigation (no resume needed)
  final String? directRoute;
  /// Route prefix that requires a resume ID: navigates to "$resumeRoute/{id}"
  final String? resumeRoute;
  final bool isLarge;

  const _FeatureItem({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.gradient,
    this.directRoute,
    this.resumeRoute,
    this.isLarge = false,
  });
}

class _FeatureCard extends ConsumerStatefulWidget {
  final _FeatureItem feature;
  final double width;
  final double height;
  final List<ResumeModel> resumes;
  const _FeatureCard({
    required this.feature,
    required this.width,
    required this.height,
    required this.resumes,
  });

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
        vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1.0, end: 0.95)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTap() async {
    final f = widget.feature;

    // Show Interstitial ad before navigating (1 in 3 chance so it's not annoying)
    if (DateTime.now().millisecondsSinceEpoch % 3 == 0) {
      await ref.read(adServiceProvider).showInterstitialAd();
    }

    // Direct route — no resume needed
    if (f.directRoute != null) {
      context.push(f.directRoute!);
      return;
    }

    // Resume-scoped route
    if (f.resumeRoute != null) {
      final resumes = widget.resumes;
      if (resumes.isEmpty) {
        // No resumes yet — prompt to create one
        showModalBottomSheet(
          context: context,
          backgroundColor: AppColors.cardDark,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          builder: (_) => Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.borderDark,
                      borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 24),
                Text(f.emoji, style: const TextStyle(fontSize: 40)),
                const SizedBox(height: 12),
                Text('No resumes yet',
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(
                  'Create a resume first, then use "${f.title}" from within the editor.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 24),
                GradientButton(
                  label: 'Create Resume',
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/templates');
                  },
                  icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                ),
              ],
            ),
          ),
        );
        return;
      }

      if (resumes.length == 1) {
        // Only one resume — go straight there
        context.push('${f.resumeRoute}/${resumes.first.id}');
        return;
      }

      // Multiple resumes — show a picker
      showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.cardDark,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.55,
          maxChildSize: 0.85,
          builder: (_, scrollCtrl) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: AppColors.borderDark,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text(f.emoji, style: const TextStyle(fontSize: 26)),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(f.title,
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w700)),
                        Text('Select a resume to continue',
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: AppColors.borderDark),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    controller: scrollCtrl,
                    itemCount: resumes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final r = resumes[i];
                      final scoreColor = AppColors.scoreColor(r.atsScore);
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        tileColor: AppColors.surfaceDark,
                        leading: Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            color: scoreColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text('${r.atsScore}',
                                style: TextStyle(
                                    color: scoreColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800)),
                          ),
                        ),
                        title: Text(r.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14)),
                        subtitle: Text(
                          r.targetRole?.isNotEmpty == true
                              ? r.targetRole!
                              : 'No target role set',
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded,
                            color: AppColors.textMuted),
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
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.feature;
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) { _ctrl.reverse(); _onTap(); },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: f.gradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: f.gradient.colors.first.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Background watermark emoji
              Positioned(
                right: -12, bottom: -12,
                child: Text(f.emoji,
                    style: TextStyle(
                        fontSize: f.isLarge ? 72 : 58,
                        color: Colors.white.withValues(alpha: 0.1))),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(18),
                child: f.isLarge
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 52, height: 52,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(
                              child: Text(f.emoji,
                                  style: const TextStyle(fontSize: 26)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(f.title,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800)),
                                const SizedBox(height: 4),
                                Text(f.subtitle,
                                    style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.75),
                                        fontSize: 13)),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text('Get Started →',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(f.emoji,
                                  style: const TextStyle(fontSize: 22)),
                            ),
                          ),
                          const Spacer(),
                          Text(f.title,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 3),
                          Text(f.subtitle,
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 11)),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Supporting Widgets ───

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
    final color = isDestructive ? AppColors.error : AppColors.textSecondary;
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(label,
          style: TextStyle(color: color, fontWeight: FontWeight.w600)),
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
        padding: const EdgeInsets.all(18),
        showGlow: score >= 80,
        glowColor: scoreColor,
        child: Row(
          children: [
            // Score ring
            SizedBox(
              width: 64,
              height: 64,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 5,
                    backgroundColor: AppColors.borderDark,
                    valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                    strokeCap: StrokeCap.round,
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$score',
                          style: TextStyle(
                              color: scoreColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w800)),
                      Text('ATS',
                          style: TextStyle(
                              color: scoreColor.withValues(alpha: 0.7),
                              fontSize: 9,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(resume.title,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded,
                          size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(_formatDate(resume.lastEdited),
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 12)),
                      const SizedBox(width: 12),
                      const Icon(Icons.download_outlined,
                          size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text('${resume.downloadCount}',
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _ScoreBar(score: score, color: scoreColor),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Quick actions column
            Column(
              children: [
                _MiniAction(
                  icon: Icons.visibility_outlined,
                  color: AppColors.primary,
                  onTap: () => context.push('/preview/${resume.id}'),
                ),
                const SizedBox(height: 8),
                _MiniAction(
                  icon: Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
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
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.borderDark,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            Text(resume.title,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            _OptionTile(
                icon: Icons.edit_outlined,
                label: 'Edit Resume',
                onTap: () {
                  Navigator.pop(ctx);
                  ctx.push('/editor/${resume.id}');
                }),
            _OptionTile(
                icon: Icons.visibility_outlined,
                label: 'Preview Resume',
                onTap: () {
                  Navigator.pop(ctx);
                  ctx.push('/preview/${resume.id}');
                }),
            _OptionTile(
                icon: Icons.analytics_outlined,
                label: 'Check ATS Score',
                onTap: () {
                  Navigator.pop(ctx);
                  ctx.push('/ats/${resume.id}');
                }),
            _OptionTile(
                icon: Icons.work_outline_rounded,
                label: 'Match Job Description',
                onTap: () {
                  Navigator.pop(ctx);
                  ctx.push('/jd/${resume.id}');
                }),
            _OptionTile(
                icon: Icons.delete_outline_rounded,
                label: 'Delete',
                isDestructive: true,
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(resumeActionsProvider).deleteResume(resume.id);
                }),
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
  const _MiniAction({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
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
        backgroundColor: AppColors.borderDark,
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
  const _OptionTile(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.isDestructive = false});

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppColors.error : AppColors.textPrimary;
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
      title: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w600, fontSize: 15)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

// ─── LinkedIn Import Card (homepage) ──────────────────────────────────────────
class _LinkedInImportCard extends StatelessWidget {
  const _LinkedInImportCard();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const _LinkedInImportSheet(),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0077B5), Color(0xFF004471)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0077B5).withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            // LinkedIn "in" logo box
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
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
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Import from LinkedIn',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 3),
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: const Text(
                'Import →',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── LinkedIn Import Bottom Sheet ─────────────────────────────────────────────
class _LinkedInImportSheet extends ConsumerStatefulWidget {
  const _LinkedInImportSheet();

  @override
  ConsumerState<_LinkedInImportSheet> createState() => _LinkedInImportSheetState();
}

class _LinkedInImportSheetState extends ConsumerState<_LinkedInImportSheet> {
  bool _loading = false;
  String _status = '';

  // ── ZIP import ──────────────────────────────────────────────────────────────
  Future<void> _importZip() async {
    Navigator.pop(context); // close sheet
    setState(() { _loading = true; _status = 'Reading ZIP…'; });

    try {
      final service = ref.read(linkedInImportServiceProvider);
      final data = await service.importFromZip();
      if (data == null) return; // user cancelled

      _setState('Creating resume…');

      // Create a new blank resume
      final newId = await ref.read(resumeActionsProvider).createNewResume('modern');

      if (newId.isEmpty) throw Exception('Failed to create resume');

      _setState('Filling in your data…');

      final notifier = ref.read(resumeNotifierProvider(newId).notifier);

      // Personal info
      notifier.updateSection('personal', {
        'name':     data['name'] ?? '',
        'email':    data['email'] ?? '',
        'phone':    data['phone'] ?? '',
        'summary':  data['summary'] ?? '',
        'headline': data['headline'] ?? '',
        'location': data['location'] ?? '',
      });

      // Experience
      if (data['experience'] is List && (data['experience'] as List).isNotEmpty) {
        notifier.updateSection(
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

      // Education
      if (data['education'] is List && (data['education'] as List).isNotEmpty) {
        notifier.updateSection(
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

      // Skills
      if (data['skills'] is List && (data['skills'] as List).isNotEmpty) {
        notifier.updateSection('skills', List<String>.from(data['skills'] as List));
      }

      await notifier.save();

      if (mounted) {
        _showSnack('✅ Resume built from LinkedIn! Review and edit it.', success: true);
        // Navigate straight to editor
        if (context.mounted) context.push('/editor/$newId');
      }
    } catch (e) {
      if (mounted) {
        _showSnack(e.toString().replaceFirst('Exception: ', ''), success: false);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setState(String msg) {
    if (mounted) setState(() => _status = msg);
  }

  void _showSnack(String msg, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? const Color(0xFF0077B5) : AppColors.scoreRed,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── OAuth (placeholder — requires LinkedIn app setup) ──────────────────────
  void _importOAuth() {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('LinkedIn OAuth',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        content: const Text(
          'To enable "Sign in with LinkedIn", you need to:\n\n'
          '1. Create a LinkedIn app at linkedin.com/developers\n'
          '2. Add LINKEDIN_CLIENT_ID & LINKEDIN_CLIENT_SECRET to your Render env vars\n'
          '3. Set redirect URI to:\nhttps://ats-resume-server.onrender.com/api/linkedin/callback\n\n'
          'Until then, use the ZIP import — it gives you the most complete data.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 44, height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderDark,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 22),

          // Header
          Row(
            children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFF0077B5).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Text('in',
                      style: TextStyle(
                          color: Color(0xFF0077B5),
                          fontWeight: FontWeight.w900,
                          fontSize: 20)),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Import from LinkedIn',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 17)),
                    SizedBox(height: 2),
                    Text('Choose how to import your profile',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Option 1: LinkedIn Login (OAuth) ──
          _SheetOption(
            icon: Icons.person_rounded,
            iconBg: const Color(0xFF0077B5),
            title: 'Sign in with LinkedIn',
            subtitle: 'Quick login — imports name & email',
            badge: 'Requires Setup',
            badgeColor: AppColors.scoreOrange,
            onTap: _importOAuth,
          ),
          const SizedBox(height: 12),

          // ── Option 2: ZIP Upload ──
          _SheetOption(
            icon: Icons.upload_file_rounded,
            iconBg: AppColors.primary,
            title: 'Upload LinkedIn Data ZIP',
            subtitle: 'Full import — work history, education, skills & more',
            badge: 'Recommended',
            badgeColor: AppColors.scoreGreen,
            onTap: _importZip,
          ),
          const SizedBox(height: 16),

          // Info box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderDark),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('💡', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'To get your ZIP: LinkedIn → Me → Settings & Privacy → Data Privacy → Get a copy of your data → Select "Want something in particular?" → Profile data → Request archive',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        height: 1.55),
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

// ─── Sheet Option Row ──────────────────────────────────────────────────────────
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
      color: AppColors.cardDark,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: iconBg.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: iconBg.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: iconBg, size: 22),
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
                                fontSize: 14)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                                color: badgeColor.withValues(alpha: 0.3), width: 1),
                          ),
                          child: Text(badge,
                              style: TextStyle(
                                  fontSize: 9,
                                  color: badgeColor,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            height: 1.4)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded,
                  color: AppColors.textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
