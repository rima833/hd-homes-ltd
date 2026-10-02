import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/features/properties/data/models/marketplace_filters.dart';
import 'package:hdhomesproject/features/properties/data/providers/marketplace_controller.dart';
import 'package:hdhomesproject/features/properties/presentation/sections/marketplace_categories_section.dart';
import 'package:hdhomesproject/features/properties/presentation/sections/marketplace_closing_section.dart';
import 'package:hdhomesproject/features/properties/presentation/sections/marketplace_comparison_section.dart';
import 'package:hdhomesproject/features/properties/presentation/sections/marketplace_grid_section.dart';
import 'package:hdhomesproject/features/properties/presentation/sections/marketplace_hero_section.dart';
import 'package:hdhomesproject/features/properties/presentation/sections/marketplace_search_section.dart';

/// Property Marketplace — Volume 2 Part 4.
class MarketplacePage extends ConsumerStatefulWidget {
  const MarketplacePage({super.key});

  @override
  ConsumerState<MarketplacePage> createState() => _MarketplacePageState();
}

class _MarketplacePageState extends ConsumerState<MarketplacePage> {
  String? _appliedCategoryQuery;
  final _gridKey = GlobalKey();

  MarketplaceSort _sortForCategory(String category) {
    if (category == 'new' || category == 'new_launches') {
      return MarketplaceSort.newest;
    }
    if (category == 'hot') return MarketplaceSort.popular;
    return MarketplaceSort.newest;
  }

  void _applyCategoryFromUrl(String? category) {
    if (category == _appliedCategoryQuery) return;
    _appliedCategoryQuery = category;
    final intended = category;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Abort if Clear / chip / navigation changed the URL before this ran.
      final latest =
          GoRouterState.of(context).uri.queryParameters['category'];
      if (latest != intended || _appliedCategoryQuery != intended) return;

      final current = ref.read(marketplaceFiltersProvider);
      if (intended == null || intended.isEmpty) {
        if (current.categoryKey != null) {
          ref.read(marketplaceFiltersProvider.notifier).state =
              current.copyWith(clearCategoryKey: true);
        }
        return;
      }
      if (current.categoryKey == intended) return;
      ref.read(marketplaceFiltersProvider.notifier).state = current.copyWith(
        categoryKey: intended,
        sort: _sortForCategory(intended),
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (GoRouter.maybeOf(context) == null) return;
    final category = GoRouterState.of(context).uri.queryParameters['category'];
    _applyCategoryFromUrl(category);
  }

  @override
  Widget build(BuildContext context) {
    final cms = ref.watch(marketplaceCmsProvider);

    // Keep ?category= in sync with in-page category chips (not search text).
    ref.listen(marketplaceFiltersProvider, (prev, next) {
      if (prev?.categoryKey == next.categoryKey) return;
      if (GoRouter.maybeOf(context) == null) return;
      final params = GoRouterState.of(context).uri.queryParameters;
      final urlCategory = params['category'];
      if (next.categoryKey == urlCategory ||
          (next.categoryKey == null &&
              (urlCategory == null || urlCategory.isEmpty))) {
        _appliedCategoryQuery = next.categoryKey;
        return;
      }
      _appliedCategoryQuery = next.categoryKey;
      if (next.categoryKey == null || next.categoryKey!.isEmpty) {
        context.go(RoutePaths.properties);
      } else {
        context.go(
          Uri(
            path: RoutePaths.properties,
            queryParameters: {'category': next.categoryKey},
          ).toString(),
        );
      }
    });

    return Column(
      children: [
        MarketplaceHeroSection(content: cms.hero),
        MarketplaceSearchSection(resultsScrollKey: _gridKey),
        const MarketplaceCategoriesSection(),
        MarketplaceGridSection(key: _gridKey),
        const MarketplaceComparisonSection(),
        const MarketplaceInvestmentSection(),
        const MarketplaceClosingSection(),
      ],
    );
  }
}
