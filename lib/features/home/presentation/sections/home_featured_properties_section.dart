import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/scale_safe_carousel.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/core/widgets/cards/property_card.dart';
import 'package:hdhomesproject/features/home/data/models/home_cms_content.dart';

/// Featured properties — same center-scale carousel motion as Insights.
class HomeFeaturedPropertiesSection extends StatelessWidget {
  const HomeFeaturedPropertiesSection({super.key, required this.properties});

  final List<HomePropertyItem> properties;

  @override
  Widget build(BuildContext context) {
    final items = properties;
    if (items.isEmpty) return const SizedBox.shrink();

    return SectionWrapper(
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: AnimatedSectionTitle(
                  overline: 'CURATED LISTINGS',
                  title: 'Featured properties',
                  subtitle:
                      'Handpicked homes ready for inspection and purchase.',
                  alignment: TextAlign.start,
                ),
              ),
              if (!context.isMobile)
                PrimaryButton(
                  label: 'Browse All',
                  variant: ButtonVariant.ghost,
                  onPressed: () => context.go(RoutePaths.properties),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          _FeaturedPropertiesCarousel(properties: items),
          if (context.isMobile) ...[
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: 'Browse All',
              variant: ButtonVariant.ghost,
              onPressed: () => context.go(RoutePaths.properties),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeaturedPropertiesCarousel extends StatelessWidget {
  const _FeaturedPropertiesCarousel({required this.properties});

  final List<HomePropertyItem> properties;

  @override
  Widget build(BuildContext context) {
    final mobile = context.isMobile;
    final height = mobile ? 460.0 : 480.0;

    Widget slide(HomePropertyItem property) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: _ListingCard(property: property),
      );
    }

    if (properties.length == 1) {
      return SizedBox(
        height: height,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: slide(properties.first),
          ),
        ),
      );
    }

    return ScaleSafeCarousel(
      itemCount: properties.length,
      height: height,
      viewportFraction: mobile ? 0.88 : 0.42,
      enlargeFactor: mobile ? 0.18 : 0.28,
      itemBuilder: (context, index, _) => slide(properties[index]),
    );
  }
}

class _ListingCard extends StatelessWidget {
  const _ListingCard({required this.property});

  final HomePropertyItem property;

  @override
  Widget build(BuildContext context) {
    return PropertyCard(
      title: property.title,
      price: property.price,
      location: property.location,
      bedrooms: property.bedrooms,
      bathrooms: property.bathrooms,
      landSize: property.landSize,
      status: property.status,
      imageUrl: property.imageUrl,
      onTap: () => context.go(property.route),
      onBookInspection: () => context.go(RoutePaths.bookInspection),
      onFavorite: () {},
    );
  }
}
