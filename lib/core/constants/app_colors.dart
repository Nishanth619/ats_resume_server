import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Primary brand gradient
  static const Color primary = Color(0xFF7C3AED); // Violet-700
  static const Color primaryLight = Color(0xFF8B5CF6); // Violet-500
  static const Color primaryDark = Color(0xFF5B21B6); // Violet-800
  static const Color accent = Color(0xFF06B6D4); // Cyan-500
  static const Color accentGold = Color(0xFFF59E0B); // Amber-500

  // Dark surfaces
  static const Color bgDark = Color(0xFF0A0A0F);
  static const Color surfaceDark = Color(0xFF111118);
  static const Color cardDark = Color(0xFF1A1A27);
  static const Color cardDark2 = Color(0xFF16162A);
  static const Color borderDark = Color(0xFF2D2D45);

  // Light surfaces
  static const Color bgLight = Color(0xFFF8F7FF);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFF3F0FF);
  static const Color borderLight = Color(0xFFE0D9FF);

  // Text
  static const Color textPrimary = Color(0xFFF0EEFF);
  static const Color textSecondary = Color(0xFF9B93C9);
  static const Color textMuted = Color(0xFF5A5480);

  // Semantic
  static const Color scoreGreen = Color(0xFF10B981);
  static const Color scoreOrange = Color(0xFFF59E0B);
  static const Color scoreRed = Color(0xFFEF4444);
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF7C3AED), Color(0xFF06B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkBgGradient = LinearGradient(
    colors: [Color(0xFF0A0A0F), Color(0xFF12101E)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF1E1B33), Color(0xFF16132A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static Color scoreColor(int score) =>
      score >= 80 ? scoreGreen : score >= 60 ? scoreOrange : scoreRed;
}
