import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/media/widgets/delivery_image.dart';
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bounded = constraints.hasBoundedHeight &&
              constraints.maxHeight.isFinite &&
              constraints.maxHeight < double.infinity;
          final lift = !bounded && _hovered;

          return AnimatedContainer(
            duration: AppDurations.fast,
            transform: Matrix4.translationValues(0, lift ? -6 : 0, 0),
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
                  mainAxisSize:
                      bounded ? MainAxisSize.max : MainAxisSize.min,
                  children: [
                Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: e.heroImageUrl != null && e.heroImageUrl!.isNotEmpty
                          ? MediaDeliveryImage(
                              url: e.heroImageUrl!,
                              fit: BoxFit.cover,
                              errorWidget: _imageFallback(),
                            )
                          : _imageFallback(),
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
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            e.name,
                            style: Theme.of(context).textTheme.titleLarge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Row(
                            children: [
                              const Icon(LucideIcons.mapPin,
                                  size: 14, color: AppColors.gold),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: Text(
                                  e.location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            '${e.propertyCount} units · ${e.estateSize} · From ${e.startingPrice}',
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            e.tagline,
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppSpacing.base),
                          AnimatedOpacity(
                            duration: AppDurations.fast,
                            opacity: _hovered ? 1 : 0,
                            child: IgnorePointer(
                              ignoring: !_hovered,
                              child: PrimaryButton(
                                label: 'Explore Estate',
                                expand: true,
                                onPressed: () =>
                                    context.go('/estates/${e.slug}'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _imageFallback() {
    return Container(
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
    );
  }
}
