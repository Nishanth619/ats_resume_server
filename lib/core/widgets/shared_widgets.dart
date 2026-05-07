import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

// ─────────────────────────────────────────────────────────
// GLASS CARD — glassmorphism container with border glow
// ─────────────────────────────────────────────────────────
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double borderRadius;
  final Color? glowColor;
  final bool showGlow;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 20,
    this.glowColor,
    this.showGlow = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: context.appColors.cardGradient,
        border: Border.all(color: context.appColors.border, width: 1),
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: (glowColor ?? AppColors.primary).withValues(
                    alpha: 0.25,
                  ),
                  blurRadius: 24,
                  spreadRadius: 0,
                  offset: Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.3)
                      : AppColors.primaryDark.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
      ),
      child: Padding(padding: padding ?? EdgeInsets.all(20), child: child),
    );
  }
}

// ─────────────────────────────────────────────────────────
// GRADIENT BUTTON — primary CTA with gradient fill
// ─────────────────────────────────────────────────────────
class GradientButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final bool isLoading;
  final LinearGradient? gradient;
  final double? width;

  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.gradient,
    this.width,
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
      duration: Duration(milliseconds: 120),
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
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
          height: 56,
          decoration: BoxDecoration(
            gradient: widget.gradient ?? context.appColors.primaryGradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: widget.isLoading
                ? SizedBox(
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
                        SizedBox(width: 10),
                      ],
                      Text(
                        widget.label,
                        style: TextStyle(
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

// ─────────────────────────────────────────────────────────
// GRADIENT BADGE — pill badge with gradient
// ─────────────────────────────────────────────────────────
class GradientBadge extends StatelessWidget {
  final String text;
  final LinearGradient? gradient;

  const GradientBadge({super.key, required this.text, this.gradient});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        gradient: gradient ?? AppColors.accentGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// SECTION HEADER
// ─────────────────────────────────────────────────────────
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
                ),
              ),
              if (subtitle != null) ...[
                SizedBox(height: 2),
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

// ─────────────────────────────────────────────────────────
// SCORE RING — animated circular score indicator
// ─────────────────────────────────────────────────────────
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
      duration: Duration(milliseconds: 1200),
    );
    _anim = Tween<double>(
      begin: 0,
      end: widget.score / 100,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
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
    final diameter = widget.radius * 2;
    final strokeWidth = (widget.radius * 0.17).clamp(12.0, 16.0);
    final numberSize = (widget.radius * 0.62).clamp(42.0, 58.0);
    final labelSize = (widget.radius * 0.17).clamp(12.0, 15.0);

    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) => SizedBox(
        width: diameter + 28,
        height: diameter + 28,
        child: Stack(
          alignment: Alignment.center,
          children: [
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
                      ? 1
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

// ─────────────────────────────────────────────────────────
// GRADIENT APP BAR
// ─────────────────────────────────────────────────────────
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
  Size get preferredSize => Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appColors.surface,
        border: Border(
          bottom: BorderSide(color: context.appColors.border, width: 1),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
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
                child: ShaderMask(
                  shaderCallback: (bounds) =>
                      context.appColors.primaryGradient.createShader(bounds),
                  child: Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              if (actions != null) ...actions!,
            ],
          ),
        ),
      ),
    );
  }
}
