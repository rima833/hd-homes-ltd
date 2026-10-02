import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/growth/analytics/journey_tracker.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/core/widgets/feedback/empty_state.dart';
import 'package:hdhomesproject/features/client/presentation/providers/marketplace_favorites_bridge.dart';
import 'package:hdhomesproject/features/properties/data/models/marketplace_filters.dart';
import 'package:hdhomesproject/features/properties/data/models/marketplace_property.dart';
import 'package:hdhomesproject/features/properties/data/providers/marketplace_controller.dart';
import 'package:hdhomesproject/features/properties/presentation/widgets/marketplace_property_card.dart';

/// Marketplace listings flow:
/// - Browse (no search/filters): Featured → All properties → Recommended → New
/// - Search/filter active: Results only (hides curated browse strips)
class MarketplaceGridSection extends ConsumerStatefulWidget {
  const MarketplaceGridSection({super.key});

  @override
  ConsumerState<MarketplaceGridSection> createState() =>
      _MarketplaceGridSectionState();
}

class _MarketplaceGridSectionState
    extends ConsumerState<MarketplaceGridSection> {
  static const _pageSize = 6;
  int _visibleCount = _pageSize;

  @override
  Widget build(BuildContext context) {
    ref.listen(marketplaceFiltersProvider, (prev, next) {
      if (prev != next && _visibleCount != _pageSize) {
        setState(() => _visibleCount = _pageSize);
      }
    });

    final results = ref.watch(filteredPropertiesProvider);
    final featured = ref.watch(featuredPropertiesProvider);
    final recommended = ref.watch(recommendedPropertiesProvider);
    final recent = ref.watch(recentPropertiesProvider);
    final favorites = ref.watch(marketplaceFavoritesProvider);
    final compare = ref.watch(marketplaceCompareProvider);
    final filters = ref.watch(marketplaceFiltersProvider);
    final columns = context.gridColumns.clamp(1, 4);
    final browsing = filters.activeCount == 0;
    final visible = results.take(_visibleCount).toList();

    // Deduplicate curated strips so the same listing isn't repeated endlessly.
    final featuredIds = featured.take(3).map((p) => p.id).toSet();
    final recommendedBrowse = recommended
        .where((p) => !featuredIds.contains(p.id))
        .take(4)
        .toList();
    final recentBrowse = recent
        .where((p) => !featuredIds.contains(p.id))
        .take(4)
        .toList();

    return Column(
      children: [
        // —— Browse: Featured first ——
        if (browsing && featured.isNotEmpty)
          SectionWrapper(
            backgroundColor: AppColors.charcoal,
            child: Column(
              children: [
                const AnimatedSectionTitle(
                  overline: 'FEATURED',
                  title: 'Featured properties',
                  subtitle: 'Hand-picked homes and investments from HD Homes.',
                ),
                const SizedBox(height: AppSpacing.xl),
                _grid(
                  context,
                  featured.take(3).toList(),
                  columns,
                  favorites,
                  compare,
                ),
              ],
            ),
          ),

        // —— Main grid: “All properties” when browsing, “Results” when filtering ——
        SectionWrapper(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: AnimatedSectionTitle(
                      overline: browsing ? 'LISTINGS' : 'RESULTS',
                      title: browsing
                          ? 'All properties'
                          : '${results.length} ${results.length == 1 ? 'property' : 'properties'} found',
                      subtitle: browsing
                          ? 'Explore the full HD Homes marketplace.'
                          : 'Matching your search and filters.',
                      alignment: TextAlign.start,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              if (results.isEmpty)
                EmptyState(
                  title: browsing
                      ? 'No properties yet'
                      : 'No properties found',
                  message: browsing
                      ? 'Published listings will appear here.'
                      : 'Try adjusting your filters or browse featured listings.',
                  icon: Icons.search_off_rounded,
                  actionLabel: browsing ? null : 'Clear filters',
                  onAction: browsing
                      ? null
                      : () {
                          ref.read(marketplaceFiltersProvider.notifier).state =
                              const MarketplaceFilters();
                          if (GoRouter.maybeOf(context) != null) {
                            context.go(RoutePaths.properties);
                          }
                        },
                )
              else ...[
                _grid(context, visible, columns, favorites, compare),
                if (_visibleCount < results.length) ...[
                  const SizedBox(height: AppSpacing.xl),
                  Center(
                    child: OutlinedButton(
                      onPressed: () =>
                          setState(() => _visibleCount += _pageSize),
                      child: const Text('Load more'),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),

        // —— Browse-only curated strips (hidden while searching/filtering) ——
        if (browsing && recommendedBrowse.isNotEmpty)
          SectionWrapper(
            backgroundColor: Theme.of(context).colorScheme.surface,
            child: Column(
              children: [
                const AnimatedSectionTitle(
                  overline: 'FOR YOU',
                  title: 'Recommended for you',
                  subtitle:
                      'Strong match scores based on lifestyle and investment potential.',
                ),
                const SizedBox(height: AppSpacing.xl),
                _grid(context, recommendedBrowse, columns, favorites, compare),
              ],
            ),
          ),
        if (browsing && recentBrowse.isNotEmpty)
          SectionWrapper(
            child: Column(
              children: [
                const AnimatedSectionTitle(
                  overline: 'NEW LISTINGS',
                  title: 'Recently added',
                  subtitle: 'Fresh releases across estates and corridors.',
                ),
                const SizedBox(height: AppSpacing.xl),
                _grid(context, recentBrowse, columns, favorites, compare),
              ],
            ),
          ),
      ],
    );
  }

  Widget _grid(
    BuildContext context,
    List<MarketplaceProperty> items,
    int columns,
    Set<String> favorites,
    List<String> compare,
  ) {
    if (items.isEmpty) return const SizedBox.shrink();
    final gap = AppSpacing.base;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        if (!maxW.isFinite || maxW <= 0) {
          return const SizedBox.shrink();
        }
        final cols = maxW < 360 ? 1 : columns.clamp(1, 4);
        final width = ((maxW - (cols - 1) * gap) / cols).clamp(120.0, maxW);
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final p in items)
              SizedBox(
                width: width,
                child: MarketplacePropertyCard(
                  property: p,
                  isFavorite: favorites.contains(p.id),
                  isCompared: compare.contains(p.id),
                  onTap: () => _openProperty(p),
                  onFavorite: () => _toggleFavorite(p),
                  onCompare: () => _toggleCompare(p.id),
                  onBookInspection: () =>
                      context.go(RoutePaths.bookInspection),
                  onQuickView: () => _openProperty(p),
                ),
              ),
          ],
        );
      },
    );
  }

  void _openProperty(MarketplaceProperty p) {
    final recent = [...ref.read(marketplaceRecentProvider)];
    recent.remove(p.id);
    recent.insert(0, p.id);
    ref.read(marketplaceRecentProvider.notifier).state =
        recent.take(10).toList();
    trackGrowthPropertyView(ref, p.id);
    context.go('/properties/${p.slug.isNotEmpty ? p.slug : p.id}');
  }

  void _toggleFavorite(MarketplaceProperty p) {
    toggleMarketplaceFavorite(
      ref,
      propertyId: p.id,
      title: p.title,
    );
  }

  void _toggleCompare(String id) {
    final list = [...ref.read(marketplaceCompareProvider)];
    if (list.contains(id)) {
      list.remove(id);
    } else if (list.length < 4) {
      list.add(id);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Compare up to 4 properties')),
      );
      return;
    }
    ref.read(marketplaceCompareProvider.notifier).state = list;
  }
}
