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
import 'package:hdhomesproject/features/properties/data/models/marketplace_filters.dart';
import 'package:hdhomesproject/features/properties/data/models/marketplace_property.dart';
import 'package:hdhomesproject/features/properties/data/providers/marketplace_controller.dart';
import 'package:hdhomesproject/features/properties/presentation/widgets/marketplace_property_card.dart';

/// Sections 5–6, 10, 13 — Featured, grid, recommended, recently added.
class MarketplaceGridSection extends ConsumerStatefulWidget {
  const MarketplaceGridSection({super.key});

  @override
  ConsumerState<MarketplaceGridSection> createState() =>
      _MarketplaceGridSectionState();
}

class _MarketplaceGridSectionState extends ConsumerState<MarketplaceGridSection> {
  static const _pageSize = 6;
  int _visibleCount = _pageSize;

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(filteredPropertiesProvider);
    final featured = ref.watch(featuredPropertiesProvider);
    final recommended = ref.watch(recommendedPropertiesProvider);
    final recent = ref.watch(recentPropertiesProvider);
    final favorites = ref.watch(marketplaceFavoritesProvider);
    final compare = ref.watch(marketplaceCompareProvider);
    final columns = context.gridColumns.clamp(1, 4);
    final visible = results.take(_visibleCount).toList();

    return Column(
      children: [
        if (featured.isNotEmpty && ref.watch(marketplaceFiltersProvider).query.isEmpty)
          SectionWrapper(
            backgroundColor: AppColors.charcoal,
            child: Column(
              children: [
                const AnimatedSectionTitle(
                  overline: 'FEATURED',
                  title: 'Featured properties',
                ),
                const SizedBox(height: AppSpacing.xl),
                _grid(context, featured.take(3).toList(), columns, favorites, compare),
              ],
            ),
          ),
        SectionWrapper(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: AnimatedSectionTitle(
                      overline: 'RESULTS',
                      title: '${results.length} properties found',
                      alignment: TextAlign.start,
                    ),
                  ),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Grid'), icon: Icon(Icons.grid_view_rounded)),
                      ButtonSegment(value: true, label: Text('Map'), icon: Icon(Icons.map_outlined)),
                    ],
                    selected: {ref.watch(marketplaceFiltersProvider).showMap},
                    onSelectionChanged: (s) {
                      ref.read(marketplaceFiltersProvider.notifier).state =
                          ref.read(marketplaceFiltersProvider).copyWith(
                                showMap: s.first,
                              );
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              if (results.isEmpty)
                EmptyState(
                  title: 'No properties found',
                  message: 'Try adjusting your filters or browse featured listings.',
                  icon: Icons.search_off_rounded,
                  actionLabel: 'Clear filters',
                  onAction: () {
                    ref.read(marketplaceFiltersProvider.notifier).state =
                        const MarketplaceFilters();
                  },
                )
              else if (ref.watch(marketplaceFiltersProvider).showMap)
                const MarketplaceMapPreview()
              else ...[
                _grid(context, visible, columns, favorites, compare),
                if (_visibleCount < results.length) ...[
                  const SizedBox(height: AppSpacing.xl),
                  Center(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _visibleCount += _pageSize),
                      child: const Text('Load more'),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
        if (recommended.isNotEmpty)
          SectionWrapper(
            backgroundColor: Theme.of(context).colorScheme.surface,
            child: Column(
              children: [
                const AnimatedSectionTitle(
                  overline: 'AI RECOMMENDED',
                  title: 'Recommended for you',
                  subtitle: 'Based on match score, budget, and browsing patterns.',
                ),
                const SizedBox(height: AppSpacing.xl),
                _grid(context, recommended, columns, favorites, compare),
              ],
            ),
          ),
        SectionWrapper(
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'NEW LISTINGS',
                title: 'Recently added',
              ),
              const SizedBox(height: AppSpacing.xl),
              _grid(context, recent, columns, favorites, compare),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final width =
            (constraints.maxWidth - (columns - 1) * AppSpacing.base) / columns;
        return Wrap(
          spacing: AppSpacing.base,
          runSpacing: AppSpacing.base,
          children: items
              .map(
                (p) => SizedBox(
                  width: width,
                  child: MarketplacePropertyCard(
                    property: p,
                    isFavorite: favorites.contains(p.id),
                    isCompared: compare.contains(p.id),
                    onTap: () => _openProperty(p),
                    onFavorite: () => _toggleFavorite(p.id),
                    onCompare: () => _toggleCompare(p.id),
                    onBookInspection: () => context.go(RoutePaths.bookInspection),
                    onQuickView: () => _openProperty(p),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  void _openProperty(MarketplaceProperty p) {
    final recent = [...ref.read(marketplaceRecentProvider)];
    recent.remove(p.id);
    recent.insert(0, p.id);
    ref.read(marketplaceRecentProvider.notifier).state = recent.take(10).toList();
    trackGrowthPropertyView(ref, p.id);
    context.go('/properties/${p.id}');
  }

  void _toggleFavorite(String id) {
    final set = {...ref.read(marketplaceFavoritesProvider)};
    if (set.contains(id)) {
      set.remove(id);
    } else {
      set.add(id);
    }
    ref.read(marketplaceFavoritesProvider.notifier).state = set;
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

class MarketplaceMapPreview extends ConsumerWidget {
  const MarketplaceMapPreview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final properties = ref.watch(filteredPropertiesProvider);

    return Container(
      height: context.isMobile ? 360 : 480,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardBorder,
        gradient: LinearGradient(
          colors: [AppColors.charcoal, AppColors.gold.withValues(alpha: 0.15)],
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              'Interactive map — ${properties.length} markers',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.white,
                  ),
            ),
          ),
          for (final p in properties.take(8))
            Align(
              alignment: _align(p),
              child: const Icon(Icons.location_on_rounded, color: AppColors.gold, size: 24),
            ),
        ],
      ),
    );
  }

  Alignment _align(MarketplaceProperty p) {
    final x = ((p.lng - 3.4) / 4).clamp(-0.8, 0.8);
    final y = ((6.5 - p.lat) / 3).clamp(-0.8, 0.8);
    return Alignment(x, y);
  }
}
