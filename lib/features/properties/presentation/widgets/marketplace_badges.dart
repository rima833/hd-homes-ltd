import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/properties/data/models/marketplace_property.dart';

class AvailabilityMeter extends StatelessWidget {
  const AvailabilityMeter({super.key, required this.level});

  final AvailabilityLevel level;

  @override
  Widget build(BuildContext context) {
    final (label, color, fill) = switch (level) {
      AvailabilityLevel.available => ('Available', AppColors.success, 1.0),
      AvailabilityLevel.limited => ('Limited Units', AppColors.warning, 0.65),
      AvailabilityLevel.almostSoldOut => ('Almost Sold Out', AppColors.error, 0.25),
      AvailabilityLevel.soldOut => ('Sold Out', AppColors.neutral500, 0.0),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color)),
            if (level != AvailabilityLevel.soldOut)
              Text('${(fill * 100).round()}%', style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: AppRadius.buttonBorder,
          child: LinearProgressIndicator(
            value: fill,
            minHeight: 4,
            backgroundColor: AppColors.neutral200,
            color: color,
          ),
        ),
      ],
    );
  }
}

class MatchScoreBadge extends StatelessWidget {
  const MatchScoreBadge({super.key, required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.badge),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome_rounded, size: 12, color: AppColors.gold),
          const SizedBox(width: 4),
          Text(
            '$score% Match',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class InvestmentScoreBadge extends StatelessWidget {
  const InvestmentScoreBadge({super.key, required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.badge),
      ),
      child: Text(
        'Invest: $score/100',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.info,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
