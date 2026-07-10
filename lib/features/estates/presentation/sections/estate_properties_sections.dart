import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/page_container.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/features/estates/data/models/estate_detail_content.dart';
import 'package:hdhomesproject/features/estates/data/providers/estate_detail_provider.dart';
import 'package:hdhomesproject/features/properties/data/providers/marketplace_controller.dart';
import 'package:hdhomesproject/features/properties/presentation/widgets/marketplace_property_card.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Sections 5–8 — Available properties, types, amenities, infrastructure.
class EstatePropertiesSections extends ConsumerWidget {
  const EstatePropertiesSections({super.key, required this.detail});

  final EstateDetailContent detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final properties = ref.watch(estatePropertiesProvider(detail.summary.slug));
    final favorites = ref.watch(marketplaceFavoritesProvider);
    final compare = ref.watch(marketplaceCompareProvider);

    return Column(
      children: [
        SectionWrapper(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: PageContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AnimatedSectionTitle(
                  overline: 'INVENTORY',
                  title: 'Available properties',
                  alignment: TextAlign.start,
                ),
                const SizedBox(height: AppSpacing.xl),
                if (properties.isEmpty)
                  const Text('No units listed yet — contact sales for early allocation.')
                else
                  SizedBox(
                    height: 480,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: properties.length,
                      separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.base),
                      itemBuilder: (context, index) {
                        final p = properties[index];
                        return SizedBox(
                          width: context.isMobile ? 300 : 340,
                          child: MarketplacePropertyCard(
                            property: p,
                            isFavorite: favorites.contains(p.id),
                            isCompared: compare.contains(p.id),
                            onTap: () => context.go('/properties/${p.id}'),
                            onFavorite: () {},
                            showMatchScore: false,
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
        SectionWrapper(
          child: PageContainer(child: _PropertyTypes(categories: detail.propertyTypeCategories)),
        ),
        SectionWrapper(
          backgroundColor: AppColors.charcoal,
          child: PageContainer(child: _Amenities(amenities: detail.amenities)),
        ),
        SectionWrapper(
          child: PageContainer(child: _Infrastructure(items: detail.infrastructure)),
        ),
      ],
    );
  }
}

class _PropertyTypes extends StatelessWidget {
  const _PropertyTypes({required this.categories});

  final List<EstatePropertyTypeCategory> categories;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AnimatedSectionTitle(
          overline: 'PROPERTY TYPES',
          title: 'Homes for every lifestyle',
          alignment: TextAlign.start,
        ),
        const SizedBox(height: AppSpacing.xl),
        Wrap(
          spacing: AppSpacing.base,
          runSpacing: AppSpacing.base,
          children: categories
              .map(
                (c) => SizedBox(
                  width: context.isMobile ? double.infinity : 280,
                  child: _TypeCard(category: c),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({required this.category});

  final EstatePropertyTypeCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.home, color: AppColors.gold),
          const SizedBox(height: AppSpacing.sm),
          Text(category.name, style: Theme.of(context).textTheme.titleMedium),
          Text(category.priceRange, style: const TextStyle(color: AppColors.gold)),
          Text(category.availability, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          Text(category.description),
        ],
      ),
    );
  }
}

class _Amenities extends StatelessWidget {
  const _Amenities({required this.amenities});

  final List<EstateAmenity> amenities;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AnimatedSectionTitle(
          overline: 'AMENITIES',
          title: 'World-class amenities',
          alignment: TextAlign.start,
        ),
        const SizedBox(height: AppSpacing.xl),
        Wrap(
          spacing: AppSpacing.base,
          runSpacing: AppSpacing.base,
          children: amenities
              .map(
                (a) => SizedBox(
                  width: context.isMobile ? double.infinity : 260,
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.base),
                    decoration: BoxDecoration(
                      color: AppColors.darkSurface,
                      borderRadius: AppRadius.cardBorder,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          a.available ? Icons.check_circle_rounded : Icons.schedule_rounded,
                          color: AppColors.gold,
                          size: 18,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.name, style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w600)),
                              Text(a.description, style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _Infrastructure extends StatelessWidget {
  const _Infrastructure({required this.items});

  final List<EstateInfrastructureItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AnimatedSectionTitle(
          overline: 'INFRASTRUCTURE',
          title: 'Built to last',
          alignment: TextAlign.start,
        ),
        const SizedBox(height: AppSpacing.xl),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.base),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(item.name, style: Theme.of(context).textTheme.titleSmall)),
                    Text('${(item.progress * 100).round()}%'),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                LinearProgressIndicator(value: item.progress, color: AppColors.gold),
                Text(item.description, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
      ],
    );
  }
}
