import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hdhomesproject/core/theme/app_theme_extension.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';

/// Premium card with soft shadow, rounded corners, and hover elevation.
class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.showAccent = false,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final bool showAccent;
  final EdgeInsetsGeometry? margin;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      onEnter: widget.onTap != null ? (_) => setState(() => _hovered = true) : null,
      onExit: widget.onTap != null ? (_) => setState(() => _hovered = false) : null,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        curve: AppAnimations.standard,
        margin: widget.margin,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.white,
          borderRadius: AppRadius.cardBorder,
          border: Border.all(
            color: widget.showAccent
                ? AppColors.gold.withValues(alpha: _hovered ? 0.5 : 0.2)
                : AppColors.gray.withValues(alpha: 0.3),
          ),
          boxShadow: _hovered ? AppShadows.lg : AppShadows.md,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: AppRadius.cardBorder,
            child: Padding(
              padding: widget.padding ?? const EdgeInsets.all(AppSpacing.base),
              child: widget.child,
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: AppDurations.normal, curve: AppAnimations.enter);
  }
}

/// Glassmorphism card for dashboards and hero sections.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.blur = 12,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double blur;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hd = context.hdTheme;

    return ClipRRect(
      borderRadius: AppRadius.cardBorder,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Material(
          color: hd.glassBackground,
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: padding ?? const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                borderRadius: AppRadius.cardBorder,
                border: Border.all(color: hd.glassBorder),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Dashboard widget card with glass effect and optional icon.
class DashboardCard extends StatelessWidget {
  const DashboardCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.subtitle,
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: AppColors.gold, size: AppIcons.lg),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          child,
        ],
      ),
    );
  }
}

/// Animated statistics card for dashboards.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.trend,
    this.trendUp,
  });

  final String label;
  final String value;
  final IconData? icon;
  final String? trend;
  final bool? trendUp;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      showAccent: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.12),
                    borderRadius: AppRadius.buttonBorder,
                  ),
                  child: Icon(icon, color: AppColors.gold, size: AppIcons.md),
                ),
              const Spacer(),
              if (trend != null)
                Text(
                  trend!,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: trendUp == true
                            ? AppColors.success
                            : trendUp == false
                                ? AppColors.error
                                : null,
                      ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          Text(
            value,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontSize: 28,
                  color: AppColors.gold,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
