import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';

/// Section heading with overline, title, and optional subtitle.
class AnimatedSectionTitle extends StatelessWidget {
  const AnimatedSectionTitle({
    super.key,
    this.overline,
    required this.title,
    this.subtitle,
    this.alignment = TextAlign.center,
  });

  final String? overline;
  final String title;
  final String? subtitle;
  final TextAlign alignment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: alignment == TextAlign.center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        if (overline != null) ...[
          Text(
            overline!.toUpperCase(),
            textAlign: alignment,
            style: theme.labelSmall?.copyWith(
              color: AppColors.gold,
              letterSpacing: 2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Text(
          title,
          textAlign: alignment,
          style: theme.displaySmall,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.base),
          Text(
            subtitle!,
            textAlign: alignment,
            style: theme.bodyLarge?.copyWith(
              color: theme.bodyMedium?.color?.withValues(alpha: 0.75),
            ),
          ),
        ],
      ],
    )
        .animate()
        .fadeIn(duration: AppDurations.normal)
        .slideY(begin: 0.06, end: 0, duration: AppDurations.normal);
  }
}
