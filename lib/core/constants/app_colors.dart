import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// APP COLORS — Glassmorphism edition, zero gradients
// ─────────────────────────────────────────────────────────────────────────────
class AppColors {
  // ── Primary brand ───────────────────────────────────────────────────────────
  static const Color primary      = Color(0xFF2563EB); // Blue-600
  static const Color primaryLight = Color(0xFF3B82F6); // Blue-500
  static const Color primaryDark  = Color(0xFF1D4ED8); // Blue-700

  // ── Accent ──────────────────────────────────────────────────────────────────
  static const Color accent     = Color(0xFFF97316); // Orange-500
  static const Color accentDark = Color(0xFFEA580C); // Orange-600
  static const Color accentGold = Color(0xFFF59E0B); // Amber-500 (Pro badge)

  // ── Dark surfaces ────────────────────────────────────────────────────────────
  // Deep slate-navy — works perfectly as glassmorphism base
  static const Color bgDark      = Color(0xFF080E1A); // Richer deep navy
  static const Color surfaceDark = Color(0xFF0D1526);
  static const Color cardDark    = Color(0xFF111E30);
  static const Color cardDark2   = Color(0xFF0F1B30); // alias kept for theme compat
  static const Color borderDark  = Color(0xFF1E2D45);

  // ── Light surfaces ────────────────────────────────────────────────────────────
  static const Color bgLight      = Color(0xFFF0F4F8);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight    = Color(0xFFFAFBFC);
  static const Color borderLight  = Color(0xFFE2E8F0);

  // ── Text ─────────────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFFF0F6FF);
  static const Color textSecondary = Color(0xFF8BA4C0);
  static const Color textMuted     = Color(0xFF4E6A8A);

  // ── Semantic ──────────────────────────────────────────────────────────────────
  static const Color scoreGreen  = Color(0xFF10B981);
  static const Color scoreOrange = Color(0xFFF59E0B);
  static const Color scoreRed    = Color(0xFFEF4444);
  static const Color success     = Color(0xFF10B981);
  static const Color error       = Color(0xFFEF4444);

  // ── Glass tints — solid semi-opaque fills for glass cards ────────────────────
  // These replace the old LinearGradient feature card palettes.
  // Use with BackdropFilter for real glassmorphism.
  static const Color tintBlue   = Color(0x1A2563EB); // blue   10% opacity
  static const Color tintGreen  = Color(0x1A10B981); // green  10% opacity
  static const Color tintOrange = Color(0x1AF97316); // orange 10% opacity
  static const Color tintSlate  = Color(0x1A475569); // slate  10% opacity
  static const Color tintNavy   = Color(0x1A1D4ED8); // navy   10% opacity
  static const Color tintGold   = Color(0x1AF59E0B); // gold   10% opacity

  // ── Ambient orb colors for bg depth (very subtle) ────────────────────────────
  static const Color orbBlue   = Color(0x142563EB); // blue  ~8%
  static const Color orbOrange = Color(0x0FF97316); // orange ~6%
  static const Color orbPurple = Color(0x0F7C3AED); // purple ~6%

  // ── Glass surface constants ────────────────────────────────────────────────────
  static const Color glassFill        = Color(0x0DFFFFFF); // white  5%
  static const Color glassFillHover   = Color(0x14FFFFFF); // white  8%
  static const Color glassBorder      = Color(0x1AFFFFFF); // white 10%
  static const Color glassBorderLight = Color(0x33FFFFFF); // white 20%

  // ── Backward-compat gradient stubs (callers kept; widgets ignore gradient) ────
  // These are kept so call-sites compile without changes. The widgets that
  // accepted `gradient:` parameters now extract the tint color from .accentColor
  // and render a flat glass tint instead of a ShaderMask gradient.
  static const FlatGradient primaryGradient  = FlatGradient(primary);
  static const FlatGradient heroGradient     = FlatGradient(primary);
  static const FlatGradient accentGradient   = FlatGradient(accent);
  static const FlatGradient darkBgGradient   = FlatGradient(bgDark);
  static const FlatGradient cardGradient     = FlatGradient(cardDark);
  static const FlatGradient goldGradient     = FlatGradient(accentGold);
  static const FlatGradient featureBlue      = FlatGradient(primary);
  static const FlatGradient featureGreen     = FlatGradient(scoreGreen);
  static const FlatGradient featureOrange    = FlatGradient(accent);
  static const FlatGradient featureSlate     = FlatGradient(Color(0xFF475569));
  static const FlatGradient featureNavy      = FlatGradient(primaryDark);

  static Color scoreColor(int score) =>
      score >= 80 ? scoreGreen : score >= 60 ? scoreOrange : scoreRed;
}

/// FlatGradient — satisfies the LinearGradient API but encodes a single solid
/// tint color so callers compile unchanged while widgets render glass instead.
class FlatGradient extends LinearGradient {
  final Color tint;
  const FlatGradient(this.tint)
      : super(colors: const [Colors.transparent, Colors.transparent]);

  /// Override createShader so legacy ShaderMask sites produce transparent
  /// output — no visual gradient is painted.
  @override
  Shader createShader(Rect rect, {TextDirection? textDirection}) =>
      const LinearGradient(colors: [Colors.transparent, Colors.transparent])
          .createShader(rect);

  /// The intended accent color for glass tint rendering.
  Color get accentColor => tint;
}

// ─────────────────────────────────────────────────────────────────────────────
// BuildContext extension — adaptive colors
// ─────────────────────────────────────────────────────────────────────────────
extension AppColorsExtension on BuildContext {
  BuildContext get appColors => this;

  bool get _isDark => Theme.of(this).brightness == Brightness.dark;

  Color get bg      => _isDark ? AppColors.bgDark      : AppColors.bgLight;
  Color get surface => _isDark ? AppColors.surfaceDark  : AppColors.surfaceLight;
  Color get card    => _isDark ? AppColors.cardDark     : AppColors.cardLight;
  Color get card2   => _isDark ? AppColors.cardDark     : const Color(0xFFEBF4FF);
  Color get border  => _isDark ? AppColors.borderDark   : AppColors.borderLight;

  Color get textPrimary   => _isDark ? AppColors.textPrimary   : const Color(0xFF0D1A2D);
  Color get textSecondary => _isDark ? AppColors.textSecondary : const Color(0xFF4E6A8A);
  Color get textMuted     => _isDark ? AppColors.textMuted     : const Color(0xFF8BA4C0);

  // Kept for compat — returns the stub gradient object
  FlatGradient get primaryGradient  => AppColors.primaryGradient;
  FlatGradient get bgGradient       => AppColors.darkBgGradient;
  FlatGradient get cardGradient     => AppColors.cardGradient;

  // Glass fill color — adapts to theme
  Color get glassFill   => _isDark ? AppColors.glassFill : const Color(0x0D000000);
  Color get glassBorder => _isDark ? AppColors.glassBorder : const Color(0x1A000000);
}
