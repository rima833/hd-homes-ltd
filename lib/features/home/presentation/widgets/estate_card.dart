import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/media/widgets/delivery_image.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/core/widgets/feedback/app_badge.dart';
import 'package:hdhomesproject/features/home/data/models/home_cms_content.dart';
import 'package:lucide_icons/lucide_icons.dart';

class EstateCard extends StatefulWidget {
  const EstateCard({super.key, required this.estate});

  final HomeEstateItem estate;

  @override
  State<EstateCard> createState() => _EstateCardState();
}

class _EstateCardState extends State<EstateCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
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
                onTap: () => context.go(widget.estate.route),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize:
                      bounded ? MainAxisSize.max : MainAxisSize.min,
                  children: [
                Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: widget.estate.imageUrl != null &&
                              widget.estate.imageUrl!.isNotEmpty
                          ? MediaDeliveryImage(
                              url: widget.estate.imageUrl!,
                              fit: BoxFit.cover,
                              errorWidget: _imageFallback(),
                            )
                          : _imageFallback(),
                    ),
                    Positioned(
                      top: AppSpacing.md,
                      left: AppSpacing.md,
                      child: AppBadge(
                        label: widget.estate.status,
                        variant: BadgeVariant.gold,
                      ),
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
                            widget.estate.name,
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
                                  widget.estate.location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            '${widget.estate.propertyCount} properties · From ${widget.estate.priceFrom}',
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 1,
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
                                    context.go(widget.estate.route),
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

  Widget _imageFallback() => Container(
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
