import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/properties/data/models/marketplace_filters.dart';
import 'package:hdhomesproject/features/properties/data/providers/marketplace_controller.dart';
import 'package:hdhomesproject/features/properties/data/providers/marketplace_listings_provider.dart';
import 'package:hdhomesproject/features/properties/data/providers/popular_searches_provider.dart';
import 'package:hdhomesproject/features/properties/presentation/widgets/marketplace_search_results_panel.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Live marketplace search — query + instant property matches.
class MarketplaceSearchSection extends HookConsumerWidget {
  const MarketplaceSearchSection({super.key, this.resultsScrollKey});

  /// Scroll target for "See all results" (marketplace grid).
  final GlobalKey? resultsScrollKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(publishedPropertiesRealtimeProvider);

    final filters = ref.watch(marketplaceFiltersProvider);
    final allResults = ref.watch(filteredPropertiesProvider);
    final loadingCatalog = ref.watch(marketplaceListingsLoadingProvider);
    final controller = useTextEditingController(text: filters.query);
    final focusNode = useFocusNode();

    useEffect(() {
      if (controller.text != filters.query) {
        controller.value = TextEditingValue(
          text: filters.query,
          selection: TextSelection.collapsed(offset: filters.query.length),
        );
      }
      return null;
    }, [filters.query]);

    void setFilters(MarketplaceFilters next) {
      ref.read(marketplaceFiltersProvider.notifier).state = next;
    }

    MarketplaceFilters current() => ref.read(marketplaceFiltersProvider);

    void clearAll() {
      controller.clear();
      setFilters(const MarketplaceFilters());
      if (GoRouter.maybeOf(context) != null) {
        context.go(RoutePaths.properties);
      }
    }

    void scrollToResults() {
      focusNode.unfocus();
      final target = resultsScrollKey?.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeInOutCubic,
          alignment: 0.05,
        );
      }
    }

    final query = filters.query.trim();
    final previewResults = allResults.take(5).toList();

    return SectionWrapper(
      compact: true,
      padding: EdgeInsets.symmetric(horizontal: context.pagePadding),
      animate: false,
      child: Material(
        elevation: 12,
        borderRadius: AppRadius.cardBorder,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                focusNode: focusNode,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search by name, estate, location, code…',
                  prefixIcon: const Icon(LucideIcons.search),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (filters.query.isNotEmpty)
                        IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(LucideIcons.x, size: 18),
                          onPressed: () {
                            controller.clear();
                            setFilters(current().copyWith(query: ''));
                          },
                        ),
                      IconButton(
                        tooltip: 'Best match',
                        icon: const Icon(
                          LucideIcons.sparkles,
                          color: AppColors.gold,
                        ),
                        onPressed: () {
                          setFilters(
                            current().copyWith(sort: MarketplaceSort.bestMatch),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                onChanged: (value) {
                  setFilters(current().copyWith(query: value));
                },
                onSubmitted: (value) {
                  final term = value.trim();
                  if (term.length >= 2) {
                    recordPopularPropertySearch(ref, term: term);
                  }
                  scrollToResults();
                },
              ),
              if (query.isNotEmpty)
                MarketplaceSearchResultsPanel(
                  query: query,
                  results: previewResults,
                  totalCount: allResults.length,
                  loading: loadingCatalog,
                  onSeeAll: scrollToResults,
                )
              else if (filters.activeCount > 0) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${allResults.length} ${allResults.length == 1 ? 'property' : 'properties'} match your filters',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: AppColors.slate500,
                            ),
                      ),
                    ),
                    TextButton(
                      onPressed: clearAll,
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
