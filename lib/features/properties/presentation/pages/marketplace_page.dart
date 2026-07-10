import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/features/properties/data/providers/marketplace_controller.dart';
import 'package:hdhomesproject/features/properties/presentation/sections/marketplace_categories_section.dart';
import 'package:hdhomesproject/features/properties/presentation/sections/marketplace_closing_section.dart';
import 'package:hdhomesproject/features/properties/presentation/sections/marketplace_comparison_section.dart';
import 'package:hdhomesproject/features/properties/presentation/sections/marketplace_grid_section.dart';
import 'package:hdhomesproject/features/properties/presentation/sections/marketplace_hero_section.dart';
import 'package:hdhomesproject/features/properties/presentation/sections/marketplace_search_section.dart';

/// AI-powered Property Marketplace — Volume 2 Part 4.
class MarketplacePage extends ConsumerWidget {
  const MarketplacePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cms = ref.watch(marketplaceCmsProvider);

    return Column(
      children: [
        MarketplaceHeroSection(content: cms.hero),
        const MarketplaceSearchSection(),
        const MarketplaceCategoriesSection(),
        const MarketplaceGridSection(),
        const MarketplaceComparisonSection(),
        const MarketplaceInvestmentSection(),
        const MarketplaceClosingSection(),
      ],
    );
  }
}
