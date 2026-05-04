import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/shared_widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late AnimationController _bgController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  bool _loading = false;
  bool _isSignUp = false;
  bool _obscurePass = true;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
        vsync: this, duration: const Duration(seconds: 10))
      ..repeat();
    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _bgController.dispose();
    _fadeController.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final auth = ref.read(authServiceProvider);
      if (_isSignUp) {
        await auth.signUpWithEmail(_emailCtrl.text.trim(),
            _passCtrl.text.trim(), _nameCtrl.text.trim());
      } else {
        await auth.signInWithEmail(
            _emailCtrl.text.trim(), _passCtrl.text.trim());
      }
      if (mounted) context.go('/dashboard');
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _googleSignIn() async {
    setState(() => _loading = true);
    try {
      final cred = await ref.read(authServiceProvider).signInWithGoogle();
      if (cred != null && mounted) context.go('/dashboard');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Stack(
        children: [
          // Animated background
          AnimatedBuilder(
            animation: _bgController,
            builder: (_, __) => CustomPaint(
              size: MediaQuery.of(context).size,
              painter: _LoginBgPainter(_bgController.value),
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    // Logo & title
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.4),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text('📄',
                                  style: TextStyle(fontSize: 32)),
                            ),
                          ),
                          const SizedBox(height: 20),
                          ShaderMask(
                            shaderCallback: (b) =>
                                AppColors.primaryGradient.createShader(b),
                            child: const Text('ATS.ai',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5)),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _isSignUp
                                ? 'Create your account'
                                : 'Welcome back 👋',
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Form card
                    GlassCard(
                      showGlow: true,
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_isSignUp) ...[
                              _buildField(
                                controller: _nameCtrl,
                                label: 'Full Name',
                                icon: Icons.person_outline_rounded,
                                validator: (v) => (v?.isEmpty ?? true)
                                    ? 'Enter your name'
                                    : null,
                              ),
                              const SizedBox(height: 16),
                            ],
                            _buildField(
                              controller: _emailCtrl,
                              label: 'Email address',
                              icon: Icons.mail_outline_rounded,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) =>
                                  (v?.contains('@') ?? false)
                                      ? null
                                      : 'Enter a valid email',
                            ),
                            const SizedBox(height: 16),
                            _buildField(
                              controller: _passCtrl,
                              label: 'Password',
                              icon: Icons.lock_outline_rounded,
                              obscureText: _obscurePass,
                              suffix: IconButton(
                                icon: Icon(
                                  _obscurePass
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: AppColors.textMuted,
                                  size: 20,
                                ),
                                onPressed: () =>
                                    setState(() => _obscurePass = !_obscurePass),
                              ),
                              validator: (v) => (v?.length ?? 0) >= 6
                                  ? null
                                  : 'Min 6 characters',
                            ),
                            const SizedBox(height: 28),
                            GradientButton(
                              label:
                                  _isSignUp ? 'Create Account' : 'Sign In',
                              onPressed: _loading ? null : _submit,
                              isLoading: _loading,
                            ),
                            const SizedBox(height: 16),

                            // Divider
                            Row(children: [
                              const Expanded(
                                  child: Divider(color: AppColors.borderDark)),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Text('or',
                                    style: TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 13)),
                              ),
                              const Expanded(
                                  child: Divider(color: AppColors.borderDark)),
                            ]),
                            const SizedBox(height: 16),

                            // Google button
                            GestureDetector(
                              onTap: _loading ? null : _googleSignIn,
                              child: Container(
                                height: 52,
                                decoration: BoxDecoration(
                                  color: AppColors.cardDark2,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: AppColors.borderDark, width: 1.5),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text('G',
                                        style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white)),
                                    const SizedBox(width: 10),
                                    Text('Continue with Google',
                                        style: TextStyle(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Toggle
                    GestureDetector(
                      onTap: () {
                        _fadeController.reset();
                        setState(() => _isSignUp = !_isSignUp);
                        _fadeController.forward();
                      },
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 14),
                          children: [
                            TextSpan(
                              text: _isSignUp
                                  ? 'Already have an account? '
                                  : "Don't have an account? ",
                            ),
                            TextSpan(
                              text: _isSignUp ? 'Sign In' : 'Sign Up',
                              style: const TextStyle(
                                  color: AppColors.primaryLight,
                                  fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
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

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: AppColors.textMuted),
        suffixIcon: suffix,
      ),
      validator: validator,
    );
  }
}

class _LoginBgPainter extends CustomPainter {
  final double t;
  _LoginBgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawOrb(canvas, size, AppColors.primary,
        Offset(size.width * 0.85, size.height * 0.15), 180, t);
    _drawOrb(canvas, size, AppColors.accent,
        Offset(size.width * 0.1, size.height * 0.6), 140, t * 0.7);
    _drawOrb(canvas, size, AppColors.primaryDark,
        Offset(size.width * 0.5, size.height * 0.9), 120, t * 0.5);
  }

  void _drawOrb(Canvas canvas, Size size, Color color, Offset baseCenter,
      double radius, double t) {
    final dx = math.sin(t * 2 * math.pi) * 30;
    final dy = math.cos(t * 2 * math.pi) * 30;
    final center = baseCenter + Offset(dx, dy);
    final paint = Paint()
      ..shader = RadialGradient(colors: [
        color.withValues(alpha: 0.18),
        Colors.transparent
      ]).createShader(
          Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_LoginBgPainter old) => old.t != t;
}
