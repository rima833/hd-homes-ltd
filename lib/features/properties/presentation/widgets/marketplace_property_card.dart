import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/app_icon_button.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/core/widgets/feedback/app_badge.dart';
import 'package:hdhomesproject/core/widgets/feedback/loading_skeleton.dart';
import 'package:hdhomesproject/features/properties/data/models/marketplace_property.dart';
import 'package:hdhomesproject/features/properties/presentation/widgets/marketplace_badges.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

/// Enhanced marketplace property card with enterprise badges.
class MarketplacePropertyCard extends StatefulWidget {
  const MarketplacePropertyCard({
    super.key,
    required this.property,
    this.isFavorite = false,
    this.isCompared = false,
    this.onTap,
    this.onFavorite,
    this.onCompare,
    this.onBookInspection,
    this.onQuickView,
    this.showMatchScore = true,
  });

  final MarketplaceProperty property;
  final bool isFavorite;
  final bool isCompared;
  final VoidCallback? onTap;
  final VoidCallback? onFavorite;
  final VoidCallback? onCompare;
  final VoidCallback? onBookInspection;
  final VoidCallback? onQuickView;
  final bool showMatchScore;

  @override
  State<MarketplacePropertyCard> createState() => _MarketplacePropertyCardState();
}

class _MarketplacePropertyCardState extends State<MarketplacePropertyCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.property;

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
            onTap: widget.onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 10,
                      child: p.imageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: p.imageUrl!,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => const PropertyCardSkeleton(),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.charcoal,
                                    AppColors.gold.withValues(alpha: 0.2),
                                  ],
                                ),
                              ),
                              child: const Center(
                                child: Icon(AppIcons.property, size: 48, color: AppColors.gold),
                              ),
                            ),
                    ),
                    Positioned(
                      top: AppSpacing.sm,
                      left: AppSpacing.sm,
                      child: Wrap(
                        spacing: AppSpacing.xs,
                        children: [
                          if (p.isFeatured)
                            const AppBadge(label: 'Featured', variant: BadgeVariant.gold),
                          if (p.isNew) const AppBadge(label: 'New', variant: BadgeVariant.success),
                          if (p.isVerified)
                            const AppBadge(label: 'Verified', variant: BadgeVariant.info),
                        ],
                      ),
                    ),
                    Positioned(
                      top: AppSpacing.sm,
                      right: AppSpacing.sm,
                      child: Row(
                        children: [
                          if (widget.onCompare != null)
                            AppIconButton(
                              icon: widget.isCompared
                                  ? Icons.compare_arrows_rounded
                                  : Icons.compare_outlined,
                              onPressed: widget.onCompare,
                              color: widget.isCompared ? AppColors.gold : AppColors.white,
                            ),
                          if (widget.onFavorite != null)
                            AppIconButton(
                              icon: widget.isFavorite
                                  ? AppIcons.favorite
                                  : AppIcons.favoriteOutline,
                              onPressed: widget.onFavorite,
                              color: widget.isFavorite ? AppColors.gold : AppColors.white,
                            ),
                        ],
                      ),
                    ),
                    if (_hovered && widget.onQuickView != null)
                      Positioned.fill(
                        child: Container(
                          color: AppColors.deepBlack.withValues(alpha: 0.35),
                          child: Center(
                            child: PrimaryButton(
                              label: 'Quick View',
                              onPressed: widget.onQuickView,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.base),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              p.price,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: AppColors.gold,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(LucideIcons.share2, size: 18),
                            onPressed: () => Share.share(
                              '${p.title} — ${p.price} at ${p.location}',
                            ),
                          ),
                        ],
                      ),
                      Text(
                        p.title,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          const Icon(AppIcons.location, size: 14, color: AppColors.gold),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              p.location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                      if (p.bedrooms > 0 || p.bathrooms > 0) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            if (p.bedrooms > 0) ...[
                              const Icon(AppIcons.bed, size: 14),
                              Text(' ${p.bedrooms}  '),
                            ],
                            if (p.bathrooms > 0) ...[
                              const Icon(AppIcons.bath, size: 14),
                              Text(' ${p.bathrooms}  '),
                            ],
                            if (p.landSize != '—') ...[
                              const Icon(AppIcons.area, size: 14),
                              Text(' ${p.landSize}'),
                            ],
                          ],
                        ),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        children: [
                          if (widget.showMatchScore) MatchScoreBadge(score: p.matchScore),
                          if (p.purpose == PropertyPurpose.invest)
                            InvestmentScoreBadge(score: p.investmentScore),
                          if (p.hasPaymentPlan)
                            const AppBadge(label: 'Payment Plan', variant: BadgeVariant.gold),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AvailabilityMeter(level: p.availability),
                      if (_hovered) ...[
                        const SizedBox(height: AppSpacing.base),
                        Row(
                          children: [
                            Expanded(
                              child: PrimaryButton(
                                label: 'View Details',
                                expand: true,
                                onPressed: widget.onTap,
                              ),
                            ),
                            if (widget.onBookInspection != null) ...[
                              const SizedBox(width: AppSpacing.sm),
                              PrimaryButton(
                                label: 'Inspect',
                                variant: ButtonVariant.secondary,
                                onPressed: widget.onBookInspection,
                              ),
                            ],
                          ],
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
    ).animate().fadeIn(duration: AppDurations.normal);
  }
}
