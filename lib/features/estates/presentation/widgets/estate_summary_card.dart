import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/core/widgets/feedback/app_badge.dart';
import 'package:hdhomesproject/features/estates/data/models/estate_detail_content.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Estate card for listings and related estates grids.
class EstateSummaryCard extends StatefulWidget {
  const EstateSummaryCard({super.key, required this.estate});

  final EstateSummary estate;

  @override
  State<EstateSummaryCard> createState() => _EstateSummaryCardState();
}

class _EstateSummaryCardState extends State<EstateSummaryCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.estate;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppDurations.fast,
        transform: Matrix4.translationValues(0, _hovered ? -6 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: AppRadius.cardBorder,
          boxShadow: _hovered ? AppShadows.lg : AppShadows.md,
        ),
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: AppRadius.cardBorder,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.go('/estates/${e.slug}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.charcoal,
                              AppColors.gold.withValues(alpha: 0.25),
                            ],
                          ),
                        ),
                        child: const Center(
                          child: Icon(LucideIcons.building2, size: 48, color: AppColors.gold),
                        ),
                      ),
                    ),
                    Positioned(
                      top: AppSpacing.md,
                      left: AppSpacing.md,
                      child: AppBadge(label: e.status.label, variant: BadgeVariant.gold),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.base),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.name, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          const Icon(LucideIcons.mapPin, size: 14, color: AppColors.gold),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(child: Text(e.location)),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '${e.propertyCount} units · ${e.estateSize} · From ${e.startingPrice}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(e.tagline, style: Theme.of(context).textTheme.bodySmall, maxLines: 2),
                      if (_hovered) ...[
                        const SizedBox(height: AppSpacing.base),
                        PrimaryButton(
                          label: 'Explore Estate',
                          expand: true,
                          onPressed: () => context.go('/estates/${e.slug}'),
                        ),
                      ],
                    ],
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
