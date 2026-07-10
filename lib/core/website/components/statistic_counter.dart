import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';

/// Animated statistic for hero and trust sections.
class StatisticCounter extends StatelessWidget {
  const StatisticCounter({
    super.key,
    required this.value,
    required this.label,
    this.suffix,
  });

  final String value;
  final String label;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$value${suffix ?? ''}',
          style: theme.headlineMedium?.copyWith(
            color: AppColors.gold,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          textAlign: TextAlign.center,
          style: theme.bodySmall,
        ),
      ],
    )
        .animate()
        .fadeIn(delay: 200.ms)
        .scale(begin: const Offset(0.92, 0.92), duration: AppDurations.normal);
  }
}
