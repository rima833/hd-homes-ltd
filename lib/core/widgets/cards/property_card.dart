import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hdhomesproject/core/media/widgets/delivery_image.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/app_icon_button.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/core/widgets/feedback/app_badge.dart';

/// Premium property listing card for marketplace grids and carousels.
///
/// Bounded parents (carousels) get a flex + scale-down body so the card never
/// emits RenderFlex overflow. Hover CTA space is reserved when provided.
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bounded = constraints.hasBoundedHeight &&
              constraints.maxHeight.isFinite &&
              constraints.maxHeight < double.infinity;
          // Lift only when height is unconstrained — lift in a carousel slot
          // causes bottom overflow stripes.
          final lift = !bounded && _hovered;

          return AnimatedContainer(
            duration: AppDurations.fast,
            curve: AppAnimations.standard,
            transform: Matrix4.translationValues(0, lift ? -4.0 : 0, 0),
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
                child: bounded
                    ? _boundedLayout(constraints.maxWidth)
                    : _unboundedLayout(),
              ),
            ),
          );
        },
      ),
    ).animate().fadeIn(duration: AppDurations.normal);
  }

  Widget _unboundedLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _ImageSection(
          imageUrl: widget.imageUrl,
          status: widget.status,
          isFavorite: widget.isFavorite,
          onFavorite: widget.onFavorite,
          fill: false,
        ),
        _Body(
          hovered: _hovered,
          title: widget.title,
          price: widget.price,
          location: widget.location,
          bedrooms: widget.bedrooms,
          bathrooms: widget.bathrooms,
          landSize: widget.landSize,
          onBookInspection: widget.onBookInspection,
          compact: false,
        ),
      ],
    );
  }

  Widget _boundedLayout(double maxWidth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 11,
          child: _ImageSection(
            imageUrl: widget.imageUrl,
            status: widget.status,
            isFavorite: widget.isFavorite,
            onFavorite: widget.onFavorite,
            fill: true,
          ),
        ),
        Expanded(
          flex: 10,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: maxWidth,
              child: _Body(
                hovered: _hovered,
                title: widget.title,
                price: widget.price,
                location: widget.location,
                bedrooms: widget.bedrooms,
                bathrooms: widget.bathrooms,
                landSize: widget.landSize,
                onBookInspection: widget.onBookInspection,
                compact: true,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.hovered,
    required this.title,
    required this.price,
    required this.location,
    required this.compact,
    this.bedrooms,
    this.bathrooms,
    this.landSize,
    this.onBookInspection,
  });

  final bool hovered;
  final String title;
  final String price;
  final String location;
  final bool compact;
  final int? bedrooms;
  final int? bathrooms;
  final String? landSize;
  final VoidCallback? onBookInspection;

  @override
  Widget build(BuildContext context) {
    final pad = compact ? AppSpacing.md : AppSpacing.base;
    return Padding(
      padding: EdgeInsets.all(pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            price,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w700,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            title,
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
                  location,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (bedrooms != null || bathrooms != null || landSize != null) ...[
            const SizedBox(height: AppSpacing.md),
            _FeatureRow(
              bedrooms: bedrooms,
              bathrooms: bathrooms,
              landSize: landSize,
            ),
          ],
          if (onBookInspection != null) ...[
            const SizedBox(height: AppSpacing.base),
            AnimatedOpacity(
              duration: AppDurations.fast,
              opacity: hovered ? 1 : 0,
              child: IgnorePointer(
                ignoring: !hovered,
                child: PrimaryButton(
                  label: 'Book Inspection',
                  expand: true,
                  onPressed: onBookInspection,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ImageSection extends StatelessWidget {
  const _ImageSection({
    required this.imageUrl,
    required this.status,
    required this.isFavorite,
    required this.onFavorite,
    required this.fill,
  });

  final String? imageUrl;
  final String? status;
  final bool isFavorite;
  final VoidCallback? onFavorite;
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final media = imageUrl != null && imageUrl!.isNotEmpty
        ? MediaDeliveryImage(
            url: imageUrl!,
            fit: BoxFit.cover,
            placeholder: ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            errorWidget: Container(
              color: AppColors.darkElevated,
              child: const Icon(AppIcons.property, size: 48),
            ),
          )
        : Container(
            color: AppColors.darkElevated,
            child: const Center(
              child: Icon(AppIcons.property, size: 48, color: AppColors.gold),
            ),
          );

    final stack = Stack(
      fit: StackFit.expand,
      children: [
        media,
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

    if (fill) return stack;
    return AspectRatio(aspectRatio: 16 / 10, child: stack);
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
          Flexible(
            child: Text(
              landSize!,
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}
