import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';

class ConstructionProgressBar extends StatelessWidget {
  const ConstructionProgressBar({
    super.key,
    required this.percent,
    this.label = 'OVERALL PROGRESS',
    this.showPercent = true,
    this.height = 6,
    this.animate = true,
  });

  final double percent;
  final String label;
  final bool showPercent;
  final double height;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final clamped = percent.clamp(0, 100);
    final fraction = clamped / 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondaryDark,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const Spacer(),
            if (showPercent)
              Text(
                '${clamped.round()}%',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w800,
                    ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(height),
          child: TweenAnimationBuilder<double>(
            duration:
                animate ? const Duration(milliseconds: 800) : Duration.zero,
            curve: Curves.easeOutCubic,
            tween: Tween(begin: 0, end: fraction),
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: height,
              backgroundColor: AppColors.charcoal.withValues(alpha: 0.35),
              color: AppColors.gold,
            ),
          ),
        ),
      ],
    );
  }
}
