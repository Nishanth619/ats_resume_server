import 'package:flutter/material.dart';

class AppColors {
  // ── Primary brand ──────────────────────────────────────────────────────────
  static const Color primary     = Color(0xFF2563EB); // Blue-600
  static const Color primaryLight = Color(0xFF3B82F6); // Blue-500
  static const Color primaryDark  = Color(0xFF1D4ED8); // Blue-700

  // ── Accent ─────────────────────────────────────────────────────────────────
  static const Color accent     = Color(0xFFF97316); // Orange-500 — distinctive warm pop
  static const Color accentDark = Color(0xFFEA580C); // Orange-600

  // ── Legacy / semantic aliases (kept for backward-compat) ───────────────────
  static const Color accentGold = Color(0xFFF59E0B); // Amber-500 (Pro badge only)

  // ── Dark surfaces (navy-based, not near-black purple) ─────────────────────
  static const Color bgDark      = Color(0xFF0B1120); // Deep navy
  static const Color surfaceDark = Color(0xFF111827); // Gray-900
  static const Color cardDark    = Color(0xFF1F2937); // Gray-800
  static const Color cardDark2   = Color(0xFF1A2744); // Slightly blue-navy variant
  static const Color borderDark  = Color(0xFF374151); // Gray-700

  // ── Light surfaces (slate-based, not washed purple) ───────────────────────
  static const Color bgLight      = Color(0xFFF1F5F9); // Slate-100
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight    = Color(0xFFF8FAFC); // Slate-50
  static const Color borderLight  = Color(0xFFE2E8F0); // Slate-200

  // ── Text ───────────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFFEFF6FF); // Blue-50 — clean, not pure white
  static const Color textSecondary = Color(0xFF94A3B8); // Slate-400
  static const Color textMuted     = Color(0xFF64748B); // Slate-500

  // ── Semantic ───────────────────────────────────────────────────────────────
  static const Color scoreGreen  = Color(0xFF10B981); // Emerald-500
  static const Color scoreOrange = Color(0xFFF59E0B); // Amber-500
  static const Color scoreRed    = Color(0xFFEF4444); // Red-500
  static const Color success     = Color(0xFF10B981);
  static const Color error       = Color(0xFFEF4444);

  // ── Feature card palettes (cohesive, intentional — not random rainbow) ─────
  // Each pair goes from a slightly deeper shade to the main color.
  static const LinearGradient featureBlue = LinearGradient(
    colors: [Color(0xFF1E3A5F), Color(0xFF2563EB)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const LinearGradient featureGreen = LinearGradient(
    colors: [Color(0xFF14532D), Color(0xFF16A34A)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const LinearGradient featureOrange = LinearGradient(
    colors: [Color(0xFF7C2D12), Color(0xFFF97316)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const LinearGradient featureSlate = LinearGradient(
    colors: [Color(0xFF1E293B), Color(0xFF475569)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const LinearGradient featureNavy = LinearGradient(
    colors: [Color(0xFF0F2356), Color(0xFF1D4ED8)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );

  // ── Gradients ──────────────────────────────────────────────────────────────
  // Primary gradient: blue → slightly deeper blue (monochromatic, not bi-hue)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Hero card: blue with warm orange hint — unique, branded
  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF1D4ED8), Color(0xFF2563EB), Color(0xFFF97316)],
    stops: [0.0, 0.55, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkBgGradient = LinearGradient(
    colors: [Color(0xFF0B1120), Color(0xFF0F1A2E)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF1F2937), Color(0xFF1A2744)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFFF97316)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Gold gradient: amber → darker amber (not amber-to-red, that was AI-generic)
  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static Color scoreColor(int score) =>
      score >= 80 ? scoreGreen : score >= 60 ? scoreOrange : scoreRed;
}

extension AppColorsExtension on BuildContext {
  BuildContext get appColors => this;

  bool get _isDark => Theme.of(this).brightness == Brightness.dark;

  Color get bg      => _isDark ? AppColors.bgDark      : AppColors.bgLight;
  Color get surface => _isDark ? AppColors.surfaceDark  : AppColors.surfaceLight;
  Color get card    => _isDark ? AppColors.cardDark     : AppColors.cardLight;
  Color get card2   => _isDark ? AppColors.cardDark2    : const Color(0xFFEBF4FF);
  Color get border  => _isDark ? AppColors.borderDark   : AppColors.borderLight;

  Color get textPrimary   => _isDark ? AppColors.textPrimary   : const Color(0xFF0F172A);
  Color get textSecondary => _isDark ? AppColors.textSecondary : const Color(0xFF475569);
  Color get textMuted     => _isDark ? AppColors.textMuted     : const Color(0xFF94A3B8);

  LinearGradient get bgGradient => _isDark
      ? AppColors.darkBgGradient
      : const LinearGradient(
          colors: [AppColors.bgLight, Color(0xFFE8F0FE)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );

  LinearGradient get cardGradient => _isDark
      ? AppColors.cardGradient
      : const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFF1F5F9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );

  LinearGradient get primaryGradient => AppColors.primaryGradient;
}
