import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
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
  String? _errorMessage; // inline error shown inside the form card

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

  /// Converts a Firebase error code into a friendly, human-readable message.
  String _friendlyError(FirebaseAuthException e) {
    switch (e.code) {
      // ── Sign-in errors ──────────────────────────────────────────────────
      case 'user-not-found':
        return 'No account found with this email. Please sign up first.';
      case 'wrong-password':
        return 'Incorrect password. Please try again or reset your password.';
      case 'invalid-credential':
        return 'Incorrect email or password. Please check and try again.';
      case 'invalid-email':
        return 'The email address is not valid. Please enter a correct email.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network and retry.';
      // ── Sign-up errors ──────────────────────────────────────────────────
      case 'email-already-in-use':
        return 'An account already exists with this email. Please sign in instead.';
      case 'weak-password':
        return 'Password is too weak. Please use at least 8 characters with numbers.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled. Please contact support.';
      // ── Default ─────────────────────────────────────────────────────────
      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
  }

  Future<void> _submit() async {
    setState(() => _errorMessage = null); // clear previous error
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
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _errorMessage = _friendlyError(e));
    } on Exception catch (e) {
      if (mounted) {
        setState(() =>
            _errorMessage = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() =>
          _errorMessage = 'Enter your email address above, then tap Forgot Password.');
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(authServiceProvider).sendPasswordReset(email);
      if (mounted) {
        setState(() => _errorMessage = null);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Password reset email sent to $email'),
          backgroundColor: AppColors.scoreGreen,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _errorMessage = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.bg,
      body: Stack(
        children: [
          // Animated background — isolated in its own repaint layer
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _bgController,
              builder: (_, _) => CustomPaint(
                size: MediaQuery.of(context).size,
                painter: _LoginBgPainter(_bgController.value),
              ),
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
                          // Clean logo — no glow box
                          const Text('📄', style: TextStyle(fontSize: 64)),
                          const SizedBox(height: 20),
                          const Text('ATS.ai',
                              style: TextStyle(
                                  color: AppColors.primaryLight,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5)),
                          const SizedBox(height: 6),
                          Text(
                            _isSignUp
                                ? 'Create your account'
                                : 'Welcome back 👋',
                            style: TextStyle(
                                color: context.appColors.textSecondary,
                                fontSize: 15),
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
                                  color: context.appColors.textMuted,
                                  size: 20,
                                ),
                                onPressed: () =>
                                    setState(() => _obscurePass = !_obscurePass),
                              ),
                              validator: (v) => (v?.length ?? 0) >= 6
                                  ? null
                                  : 'Min 6 characters',
                            ),

                            // ── Inline error banner ─────────────────────
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 16),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.error
                                          .withValues(alpha: 0.35),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.error_outline_rounded,
                                          color: AppColors.error, size: 18),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          _errorMessage!,
                                          style: TextStyle(
                                            color: AppColors.error,
                                            fontSize: 13,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => setState(
                                            () => _errorMessage = null),
                                        child: Icon(
                                          Icons.close_rounded,
                                          color: AppColors.error
                                              .withValues(alpha: 0.6),
                                          size: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 20),
                            GradientButton(
                              label: _isSignUp ? 'Create Account' : 'Sign In',
                              onPressed: _loading ? null : _submit,
                              isLoading: _loading,
                            ),

                            // ── Forgot password (sign-in mode only) ──────
                            if (!_isSignUp) ...[
                              const SizedBox(height: 4),
                              TextButton(
                                onPressed: _loading ? null : _forgotPassword,
                                child: Text(
                                  'Forgot password?',
                                  style: TextStyle(
                                    color: context.appColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ] else
                              const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Toggle sign-in / sign-up
                    GestureDetector(
                      onTap: () {
                        _fadeController.reset();
                        setState(() {
                          _isSignUp = !_isSignUp;
                          _errorMessage = null; // clear error on mode switch
                        });
                        _fadeController.forward();
                      },
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: TextStyle(
                              color: context.appColors.textSecondary,
                              fontSize: 14),
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
      style: TextStyle(color: context.appColors.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: context.appColors.textMuted),
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
      ]).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_LoginBgPainter old) => old.t != t;
}
