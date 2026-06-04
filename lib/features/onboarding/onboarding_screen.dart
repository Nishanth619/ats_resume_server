import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/shared_widgets.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  late AnimationController _bgController;
  late AnimationController _slideController;
  int _currentPage = 0;

  late final List<_OnboardingPage> _pages = [
    _OnboardingPage(
      title: 'Beat the\nATS Bots',
      subtitle:
          'Our templates are mathematically tested to parse perfectly in every major Applicant Tracking System.',
      icon: '🎯',
      tag: 'ATS-Optimised',
      gradient: LinearGradient(
        colors: [AppColors.primaryLight, AppColors.primary],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      glowColor: AppColors.primary,
    ),
    _OnboardingPage(
      title: 'AI-Powered\nWriting',
      subtitle:
          'Generate professional summaries and action-oriented bullet points tailored to your role in seconds.',
      icon: '✨',
      tag: 'AI-Powered',
      gradient: LinearGradient(
        colors: [Color(0xFF06B6D4), Color(0xFF8B5CF6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      glowColor: AppColors.accent,
    ),
    _OnboardingPage(
      title: 'Download\nInstantly Free',
      subtitle:
          'No paywalls. Watch a 30-second ad and download your professional ATS-safe PDF instantly.',
      icon: '🚀',
      tag: 'Always Free',
      gradient: AppColors.goldGradient,
      glowColor: AppColors.accentGold,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
        vsync: this, duration: const Duration(seconds: 8))
      ..repeat();
    _slideController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
  }

  @override
  void dispose() {
    _bgController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    if (mounted) context.go('/login');
  }

  void _nextPage() {
    if (_currentPage == _pages.length - 1) {
      _completeOnboarding();
    } else {
      _pageController.nextPage(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentPage];
    return Scaffold(
      backgroundColor: context.appColors.bg,
      body: Stack(
        children: [
          // Animated orb background — isolated repaint layer for 60fps
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _bgController,
              builder: (_, _) {
                return CustomPaint(
                  size: MediaQuery.of(context).size,
                  painter: _OrbPainter(_bgController.value, _currentPage),
                );
              },
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ShaderMask(
                        shaderCallback: (b) => page.gradient.createShader(b),
                        child: Text('ATS.ai',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800)),
                      ),
                      TextButton(
                        onPressed: _completeOnboarding,
                        child: Text('Skip',
                            style: TextStyle(
                                color: context.appColors.textSecondary, fontSize: 14)),
                      ),
                    ],
                  ),
                ),

                // Page content
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (v) => setState(() => _currentPage = v),
                    itemCount: _pages.length,
                    itemBuilder: (_, i) => _PageContent(
                      page: _pages[i],
                      isActive: i == _currentPage,
                    ),
                  ),
                ),

                // Bottom controls
                Padding(
                  padding: EdgeInsets.fromLTRB(28, 0, 28, 40),
                  child: Column(
                    children: [
                      // Page dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _pages.length,
                          (i) => AnimatedContainer(
                            duration: Duration(milliseconds: 300),
                            margin: EdgeInsets.symmetric(horizontal: 4),
                            width: i == _currentPage ? 28 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              gradient: i == _currentPage
                                  ? page.gradient
                                  : null,
                              color: i == _currentPage
                                  ? null
                                  : context.appColors.border,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 28),
                      GradientButton(
                        label: _currentPage == _pages.length - 1
                            ? 'Get Started'
                            : 'Continue',
                        onPressed: _nextPage,
                        gradient: page.gradient,
                        icon: Icon(
                          _currentPage == _pages.length - 1
                              ? Icons.rocket_launch_rounded
                              : Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ],
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

class _PageContent extends StatelessWidget {
  final _OnboardingPage page;
  final bool isActive;
  const _PageContent({required this.page, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon — clean custom design, no AI-style glow box
          Container(
            width: 136,
            height: 136,
            decoration: BoxDecoration(
              color: page.glowColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(
                color: page.glowColor.withValues(alpha: 0.22),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(page.icon, style: TextStyle(fontSize: 64)),
            ),
          ),
          SizedBox(height: 12),
          // Tag
          GradientBadge(text: page.tag, gradient: page.gradient),
          SizedBox(height: 32),
          ShaderMask(
            shaderCallback: (b) => page.gradient.createShader(b),
            child: Text(
              page.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  letterSpacing: -0.5),
            ),
          ),
          SizedBox(height: 20),
          Text(
            page.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: context.appColors.textSecondary,
                fontSize: 15,
                height: 1.65),
          ),
        ],
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  final double t;
  final int page;
  _OrbPainter(this.t, this.page);

  static const colors = [AppColors.primary, AppColors.accent, AppColors.accentGold];

  @override
  void paint(Canvas canvas, Size size) {
    final color = colors[page % colors.length];
    final x = size.width * 0.8 + math.sin(t * 2 * math.pi) * 40;
    final y = size.height * 0.2 + math.cos(t * 2 * math.pi) * 40;
    final paint = Paint()
      ..shader = RadialGradient(colors: [
        color.withValues(alpha: 0.15),
        Colors.transparent
      ]).createShader(Rect.fromCircle(
          center: Offset(x, y), radius: 200));
    canvas.drawCircle(Offset(x, y), 200, paint);

    final x2 = size.width * 0.1 + math.cos(t * 2 * math.pi) * 30;
    final y2 = size.height * 0.75 + math.sin(t * 2 * math.pi) * 30;
    final paint2 = Paint()
      ..shader = RadialGradient(colors: [
        color.withValues(alpha: 0.10),
        Colors.transparent
      ]).createShader(Rect.fromCircle(
          center: Offset(x2, y2), radius: 150));
    canvas.drawCircle(Offset(x2, y2), 150, paint2);
  }

  @override
  bool shouldRepaint(_OrbPainter old) => old.t != t || old.page != page;
}

class _OnboardingPage {
  final String title, subtitle, icon, tag;
  final LinearGradient gradient;
  final Color glowColor;
  _OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tag,
    required this.gradient,
    required this.glowColor,
  });
}
