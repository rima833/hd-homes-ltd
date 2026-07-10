import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hdhomesproject/features/properties/data/providers/marketplace_controller.dart';
import 'package:hdhomesproject/features/search/data/providers/search_cms_provider.dart';
import 'package:hdhomesproject/features/search/data/providers/search_intelligence_provider.dart';
import 'package:hdhomesproject/features/search/presentation/sections/search_closing_sections.dart';
import 'package:hdhomesproject/features/search/presentation/sections/search_hero_section.dart';
import 'package:hdhomesproject/features/search/presentation/sections/search_hub_sections.dart';
import 'package:hdhomesproject/features/search/presentation/widgets/global_search_bar.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Property Search Intelligence hub — Volume 2 Part 11.
class SearchIntelligencePage extends HookConsumerWidget {
  const SearchIntelligencePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cms = ref.watch(searchHubCmsProvider);
    final filters = ref.watch(marketplaceFiltersProvider);
    final controller = useTextEditingController(text: filters.query);
    final advancedKey = useMemoized(GlobalKey.new);
    final resultsKey = useMemoized(GlobalKey.new);

    void scrollTo(GlobalKey key) {
      final target = key.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOutCubic,
        );
      }
    }

    void runSearch(String query) {
      ref.read(marketplaceFiltersProvider.notifier).state =
          ref.read(marketplaceFiltersProvider).copyWith(query: query);
      final count = ref.read(filteredPropertiesProvider).length;
      recordSearch(ref, query: query, resultsCount: count);
      scrollTo(resultsKey);
    }

    return Column(
      children: [
        SearchHeroSection(
          headline: cms.heroHeadline,
          subheadline: cms.heroSubheadline,
          onAdvancedFilters: () => scrollTo(advancedKey),
          searchBar: GlobalSearchBar(
            controller: controller,
            onChanged: runSearch,
            onSubmitted: runSearch,
            popularSearches: cms.popularSearches,
            recentSearches: cms.recentSearches,
            onAiSearch: () {
              final parsed = parseAiSearchQuery(controller.text);
              ref.read(marketplaceFiltersProvider.notifier).state = parsed.filters;
              runSearch(parsed.filters.query);
            },
          ),
        ),
        SearchHubSections(advancedKey: advancedKey, resultsKey: resultsKey),
        const SearchClosingSections(),
      ],
    );
  }
}
