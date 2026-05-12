import 'dart:ui';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

// ═════════════════════════════════════════════════════════════════════════════
// GLASS CARD — true frosted-glass morphism panel
// ═════════════════════════════════════════════════════════════════════════════
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double borderRadius;
  final Color? glowColor;
  final bool showGlow;
  /// Optional solid tint overlay — e.g. AppColors.tintBlue for feature cards
  final Color? tintColor;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 20,
    this.glowColor,
    this.showGlow = false,
    this.tintColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isDark) {
      // ── Dark mode: true frosted-glass with backdrop blur ──────────────────
      final fill = tintColor != null
          ? Color.alphaBlend(tintColor!, AppColors.glassFill)
          : AppColors.glassFill;

      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              color: fill,
              border: Border.all(color: AppColors.glassBorder, width: 1),
              boxShadow: [
                if (showGlow)
                  BoxShadow(
                    color: (glowColor ?? AppColors.primary).withValues(alpha: 0.20),
                    blurRadius: 28,
                    spreadRadius: -4,
                    offset: const Offset(0, 6),
                  ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: padding ?? const EdgeInsets.all(20),
              child: child,
            ),
          ),
        ),
      );
    }

    // ── Light mode: clean solid white card — no blur needed ──────────────────
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: Colors.white,
        border: Border.all(color: AppColors.borderLight, width: 1),
        boxShadow: [
          if (showGlow)
            BoxShadow(
              color: (glowColor ?? AppColors.primary).withValues(alpha: 0.15),
              blurRadius: 20,
              spreadRadius: -4,
              offset: const Offset(0, 4),
            ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(20),
        child: child,
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// GLASS BUTTON — solid accent CTA (no gradient), with press animation
// Replaces GradientButton. The `gradient` param is accepted for compat but
// the accent color is extracted from it (or defaults to primary).
// ═════════════════════════════════════════════════════════════════════════════
class GradientButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final bool isLoading;
  /// Kept for backward compat — the first color is used as the solid fill.
  final LinearGradient? gradient;
  final double? width;
  /// Override color directly (takes priority over gradient)
  final Color? color;

  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.gradient,
    this.width,
    this.color,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.96)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _resolvedColor {
    if (widget.color != null) return widget.color!;
    // Extract tint from _FakeGradient or first real gradient color
    final g = widget.gradient;
    if (g != null && g.colors.isNotEmpty) {
      final c = g.colors.first;
      if (c != Colors.transparent) return c;
    }
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final accent = _resolvedColor;
    final isDisabled = widget.onPressed == null;

    return GestureDetector(
      onTapDown: isDisabled ? null : (_) => _ctrl.forward(),
      onTapUp: isDisabled
          ? null
          : (_) {
              _ctrl.reverse();
              widget.onPressed?.call();
            },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: Container(
          width: widget.width ?? double.infinity,
          height: 54,
          decoration: BoxDecoration(
            // Solid accent — no gradient
            color: isDisabled
                ? accent.withValues(alpha: 0.35)
                : accent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.14),
              width: 1,
            ),
            boxShadow: isDisabled
                ? null
                : [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.32),
                      blurRadius: 18,
                      offset: const Offset(0, 5),
                    ),
                  ],
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        widget.icon!,
                        const SizedBox(width: 10),
                      ],
                      Text(
                        widget.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
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

// ═════════════════════════════════════════════════════════════════════════════
// GLASS BADGE — pill badge with solid glass tint (no gradient)
// Replaces GradientBadge. gradient param kept for compat — accent extracted.
// ═════════════════════════════════════════════════════════════════════════════
class GradientBadge extends StatelessWidget {
  final String text;
  /// Kept for backward compat — first non-transparent color used as tint.
  final LinearGradient? gradient;
  final Color? color;

  const GradientBadge({super.key, required this.text, this.gradient, this.color});

  Color _resolvedTint() {
    if (color != null) return color!;
    final g = gradient;
    if (g != null && g.colors.isNotEmpty) {
      final c = g.colors.first;
      if (c != Colors.transparent) return c;
    }
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final tint = _resolvedTint();
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: tint.withValues(alpha: 0.30),
              width: 1,
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: tint.withValues(alpha: 1.0),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SECTION HEADER
// ═════════════════════════════════════════════════════════════════════════════
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: context.appColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: context.appColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SCORE RING — animated circular score indicator (no gradient, semantic color)
// ═════════════════════════════════════════════════════════════════════════════
class ScoreRing extends StatefulWidget {
  final int score;
  final double radius;

  const ScoreRing({super.key, required this.score, this.radius = 70});

  @override
  State<ScoreRing> createState() => _ScoreRingState();
}

class _ScoreRingState extends State<ScoreRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _anim = Tween<double>(begin: 0, end: widget.score / 100)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = AppColors.scoreColor(widget.score);
    final diameter    = widget.radius * 2;
    final strokeWidth = (widget.radius * 0.17).clamp(12.0, 16.0);
    final numberSize  = (widget.radius * 0.62).clamp(42.0, 58.0);
    final labelSize   = (widget.radius * 0.17).clamp(12.0, 15.0);

    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) => SizedBox(
        width: diameter + 28,
        height: diameter + 28,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer ring halo
            Container(
              width: diameter + 12,
              height: diameter + 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.06),
                border: Border.all(
                  color: color.withValues(alpha: 0.12),
                  width: 1,
                ),
              ),
            ),
            SizedBox(
              width: diameter,
              height: diameter,
              child: CircularProgressIndicator(
                value: _anim.value,
                strokeWidth: strokeWidth,
                backgroundColor: context.appColors.border.withValues(
                  alpha: Theme.of(context).brightness == Brightness.dark
                      ? 1.0
                      : 0.7,
                ),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                strokeCap: StrokeCap.round,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${((_anim.value) * 100).round()}',
                  style: TextStyle(
                    color: color,
                    fontSize: numberSize,
                    fontWeight: FontWeight.w900,
                    height: 0.95,
                  ),
                ),
                Text(
                  '/ 100',
                  style: TextStyle(
                    color: context.appColors.textSecondary,
                    fontSize: labelSize,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// GLASS APP BAR — frosted glass, no gradient title
// Drop-in replacement for GradientAppBar (same class name, same constructor).
// ═════════════════════════════════════════════════════════════════════════════
class GradientAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBack;

  const GradientAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showBack = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: preferredSize.height + MediaQuery.of(context).padding.top,
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0x1AFFFFFF).withValues(alpha: 0.05)
                : const Color(0x1AFFFFFF).withValues(alpha: 0.70),
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? AppColors.glassBorder
                    : const Color(0x1A000000),
                width: 1,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                if (showBack)
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: context.appColors.textPrimary,
                    ),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: context.appColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                if (actions != null) ...actions!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// AMBIENT BACKGROUND — deep navy + subtle orbs for glass depth
// Wrap any Scaffold body with this to make glass cards look great.
// ═════════════════════════════════════════════════════════════════════════════
class AmbientBackground extends StatelessWidget {
  final Widget child;
  const AmbientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!isDark) return child;
    return Stack(
      children: [
        // Base
        Container(color: AppColors.bgDark),
        // Top-left orb — blue
        Positioned(
          top: -80,
          left: -60,
          child: _Orb(size: 320, color: AppColors.orbBlue),
        ),
        // Bottom-right orb — orange
        Positioned(
          bottom: -60,
          right: -80,
          child: _Orb(size: 280, color: AppColors.orbOrange),
        ),
        // Mid-screen orb — purple
        Positioned(
          top: 380,
          left: 80,
          child: _Orb(size: 200, color: AppColors.orbPurple),
        ),
        // Content on top
        child,
      ],
    );
  }
}

class _Orb extends StatelessWidget {
  final double size;
  final Color color;
  const _Orb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }
}
