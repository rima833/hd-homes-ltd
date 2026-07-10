import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/app_icon_button.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/core/widgets/feedback/app_badge.dart';
import 'package:hdhomesproject/core/widgets/feedback/loading_skeleton.dart';

/// Premium property listing card for marketplace grids.
class PropertyCard extends StatefulWidget {
  const PropertyCard({
    super.key,
    required this.title,
    required this.price,
    required this.location,
    this.imageUrl,
    this.bedrooms,
    this.bathrooms,
    this.landSize,
    this.status,
    this.isFavorite = false,
    this.onTap,
    this.onFavorite,
    this.onBookInspection,
  });

  final String title;
  final String price;
  final String location;
  final String? imageUrl;
  final int? bedrooms;
  final int? bathrooms;
  final String? landSize;
  final String? status;
  final bool isFavorite;
  final VoidCallback? onTap;
  final VoidCallback? onFavorite;
  final VoidCallback? onBookInspection;

  @override
  State<PropertyCard> createState() => _PropertyCardState();
}

class _PropertyCardState extends State<PropertyCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppDurations.fast,
        curve: AppAnimations.standard,
        transform: Matrix4.translationValues(0, _hovered ? -4.0 : 0, 0),
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
                _ImageSection(
                  imageUrl: widget.imageUrl,
                  status: widget.status,
                  isFavorite: widget.isFavorite,
                  onFavorite: widget.onFavorite,
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.base),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.price,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppColors.gold,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        widget.title,
                        style: Theme.of(context).textTheme.titleLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          const Icon(
                            AppIcons.location,
                            size: AppIcons.sm,
                            color: AppColors.gold,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              widget.location,
                              style: Theme.of(context).textTheme.bodyMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (widget.bedrooms != null ||
                          widget.bathrooms != null ||
                          widget.landSize != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        _FeatureRow(
                          bedrooms: widget.bedrooms,
                          bathrooms: widget.bathrooms,
                          landSize: widget.landSize,
                        ),
                      ],
                      if (_hovered && widget.onBookInspection != null) ...[
                        const SizedBox(height: AppSpacing.base),
                        PrimaryButton(
                          label: 'Book Inspection',
                          expand: true,
                          onPressed: widget.onBookInspection,
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

class _ImageSection extends StatelessWidget {
  const _ImageSection({
    required this.imageUrl,
    required this.status,
    required this.isFavorite,
    required this.onFavorite,
  });

  final String? imageUrl;
  final String? status;
  final bool isFavorite;
  final VoidCallback? onFavorite;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AspectRatio(
          aspectRatio: 16 / 10,
          child: imageUrl != null
              ? CachedNetworkImage(
                  imageUrl: imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const PropertyCardSkeleton(),
                  errorWidget: (context, url, error) => Container(
                    color: AppColors.darkElevated,
                    child: const Icon(AppIcons.property, size: 48),
                  ),
                )
              : Container(
                  color: AppColors.darkElevated,
                  child: const Center(
                    child: Icon(AppIcons.property, size: 48, color: AppColors.gold),
                  ),
                ),
        ),
        if (status != null)
          Positioned(
            top: AppSpacing.md,
            left: AppSpacing.md,
            child: AppBadge(label: status!, variant: BadgeVariant.gold),
          ),
        if (onFavorite != null)
          Positioned(
            top: AppSpacing.sm,
            right: AppSpacing.sm,
            child: AppIconButton(
              icon: isFavorite ? AppIcons.favorite : AppIcons.favoriteOutline,
              onPressed: onFavorite,
              color: isFavorite ? AppColors.gold : AppColors.white,
            ),
          ),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    this.bedrooms,
    this.bathrooms,
    this.landSize,
  });

  final int? bedrooms;
  final int? bathrooms;
  final String? landSize;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;

    return Row(
      children: [
        if (bedrooms != null) ...[
          const Icon(AppIcons.bed, size: AppIcons.sm),
          const SizedBox(width: AppSpacing.xs),
          Text('$bedrooms', style: style),
          const SizedBox(width: AppSpacing.md),
        ],
        if (bathrooms != null) ...[
          const Icon(AppIcons.bath, size: AppIcons.sm),
          const SizedBox(width: AppSpacing.xs),
          Text('$bathrooms', style: style),
          const SizedBox(width: AppSpacing.md),
        ],
        if (landSize != null) ...[
          const Icon(AppIcons.area, size: AppIcons.sm),
          const SizedBox(width: AppSpacing.xs),
          Text(landSize!, style: style),
        ],
      ],
    );
  }
}
