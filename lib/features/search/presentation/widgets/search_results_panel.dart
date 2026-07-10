import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/core/widgets/feedback/empty_state.dart';
import 'package:hdhomesproject/features/properties/data/providers/marketplace_controller.dart';
import 'package:hdhomesproject/features/properties/presentation/widgets/marketplace_property_card.dart';
import 'package:hdhomesproject/features/search/data/providers/search_intelligence_provider.dart';

/// Search results grid, map toggle, and intelligent empty state.
class SearchResultsPanel extends ConsumerStatefulWidget {
  const SearchResultsPanel({super.key});

  @override
  ConsumerState<SearchResultsPanel> createState() => _SearchResultsPanelState();
}

class _SearchResultsPanelState extends ConsumerState<SearchResultsPanel> {
  static const _pageSize = 6;
  int _visible = _pageSize;

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(filteredPropertiesProvider);
    final favorites = ref.watch(marketplaceFavoritesProvider);
    final compare = ref.watch(marketplaceCompareProvider);
    final showMap = ref.watch(marketplaceFiltersProvider).showMap;
    final columns = context.gridColumns.clamp(1, 4);
    final visible = results.take(_visible).toList();
    final alternatives = ref.watch(searchEmptyAlternativesProvider);

    if (results.isEmpty) {
      return Column(
        children: [
          EmptyState(
            title: 'No exact matches',
            message: 'Try adjusting filters or explore similar properties below.',
            icon: Icons.search_off_rounded,
            actionLabel: 'Contact consultant',
            onAction: () => context.go(RoutePaths.contact),
          ),
          const SizedBox(height: AppSpacing.xl),
          const AnimatedSectionTitle(
            overline: 'SMART EMPTY STATE',
            title: 'Similar properties you may like',
          ),
          const SizedBox(height: AppSpacing.lg),
          _grid(context, alternatives, columns, favorites, compare),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: 'Request property notification',
            icon: Icons.notifications_active_outlined,
            onPressed: () {},
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${results.length} properties found',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Grid'), icon: Icon(Icons.grid_view_rounded)),
                ButtonSegment(value: true, label: Text('Map'), icon: Icon(Icons.map_outlined)),
              ],
              selected: {showMap},
              onSelectionChanged: (s) {
                ref.read(marketplaceFiltersProvider.notifier).state =
                    ref.read(marketplaceFiltersProvider).copyWith(showMap: s.first);
              },
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (showMap)
          Container(
            height: 320,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: AppRadius.cardBorder,
              gradient: LinearGradient(
                colors: [AppColors.charcoal, AppColors.gold.withValues(alpha: 0.1)],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.map_outlined, size: 48, color: AppColors.gold),
                const SizedBox(height: AppSpacing.sm),
                Text('${results.length} properties on map', style: Theme.of(context).textTheme.titleMedium),
                const Text('Clusters, heatmaps, draw area, radius search — Google Maps in production.'),
              ],
            ),
          )
        else
          _grid(context, visible, columns, favorites, compare),
        if (!showMap && _visible < results.length) ...[
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: PrimaryButton(
              label: 'Load more',
              variant: ButtonVariant.secondary,
              onPressed: () => setState(() => _visible += _pageSize),
            ),
          ),
        ],
      ],
    );
  }

  Widget _grid(
    BuildContext context,
    List properties,
    int columns,
    Set<String> favorites,
    List<String> compare,
  ) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: AppSpacing.base,
        crossAxisSpacing: AppSpacing.base,
        childAspectRatio: context.isMobile ? 0.65 : 0.7,
      ),
      itemCount: properties.length,
      itemBuilder: (_, i) {
        final p = properties[i];
        return MarketplacePropertyCard(
          property: p,
          isFavorite: favorites.contains(p.id),
          isCompared: compare.contains(p.id),
          onFavorite: () {
            final set = {...ref.read(marketplaceFavoritesProvider)};
            set.contains(p.id) ? set.remove(p.id) : set.add(p.id);
            ref.read(marketplaceFavoritesProvider.notifier).state = set;
          },
          onCompare: () {
            final list = [...ref.read(marketplaceCompareProvider)];
            if (list.contains(p.id)) {
              list.remove(p.id);
            } else if (list.length < 6) {
              list.add(p.id);
            }
            ref.read(marketplaceCompareProvider.notifier).state = list;
          },
        );
      },
    );
  }
}
