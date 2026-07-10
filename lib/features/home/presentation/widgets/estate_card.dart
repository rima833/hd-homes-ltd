import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
            onTap: () => context.go(widget.estate.route),
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
                          child: Icon(LucideIcons.building2,
                              size: 48, color: AppColors.gold),
                        ),
                      ),
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
                    children: [
                      Text(
                        widget.estate.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          const Icon(LucideIcons.mapPin,
                              size: 14, color: AppColors.gold),
                          const SizedBox(width: AppSpacing.xs),
                          Text(widget.estate.location),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '${widget.estate.propertyCount} properties · From ${widget.estate.priceFrom}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (_hovered) ...[
                        const SizedBox(height: AppSpacing.base),
                        PrimaryButton(
                          label: 'Explore Estate',
                          expand: true,
                          onPressed: () => context.go(widget.estate.route),
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
