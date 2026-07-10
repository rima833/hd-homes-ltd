import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';

enum BadgeVariant { gold, success, warning, error, info, neutral }

class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.variant = BadgeVariant.gold,
  });

  final String label;
  final BadgeVariant variant;

  Color get _background => switch (variant) {
        BadgeVariant.gold => AppColors.gold.withValues(alpha: 0.15),
        BadgeVariant.success => AppColors.success.withValues(alpha: 0.15),
        BadgeVariant.warning => AppColors.warning.withValues(alpha: 0.15),
        BadgeVariant.error => AppColors.error.withValues(alpha: 0.15),
        BadgeVariant.info => AppColors.info.withValues(alpha: 0.15),
        BadgeVariant.neutral => AppColors.gray.withValues(alpha: 0.3),
      };

  Color get _foreground => switch (variant) {
        BadgeVariant.gold => AppColors.gold,
        BadgeVariant.success => AppColors.success,
        BadgeVariant.warning => AppColors.warning,
        BadgeVariant.error => AppColors.error,
        BadgeVariant.info => AppColors.info,
        BadgeVariant.neutral => AppColors.charcoal,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(AppRadius.badge),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: _foreground,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class NotificationBadge extends StatelessWidget {
  const NotificationBadge({
    super.key,
    required this.count,
    required this.child,
  });

  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: count > 0,
      label: Text('$count'),
      backgroundColor: AppColors.gold,
      textColor: AppColors.white,
      child: child,
    );
  }
}
