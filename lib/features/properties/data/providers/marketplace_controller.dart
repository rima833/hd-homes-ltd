import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/cms/domain/data/hub_page_cms.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/properties/data/models/marketplace_filters.dart';
import 'package:hdhomesproject/features/properties/data/models/marketplace_property.dart';
import 'package:hdhomesproject/features/properties/data/providers/marketplace_listings_provider.dart';

final marketplaceFiltersProvider =
    StateProvider<MarketplaceFilters>((ref) => const MarketplaceFilters());

final marketplaceFavoritesProvider = StateProvider<Set<String>>((ref) => {});

final marketplaceCompareProvider = StateProvider<List<String>>((ref) => []);

final marketplaceRecentProvider = StateProvider<List<String>>((ref) => []);

final filteredPropertiesProvider = Provider<List<MarketplaceProperty>>((ref) {
  final all = ref.watch(marketplaceListingsProvider);
  final filters = ref.watch(marketplaceFiltersProvider);
  return filterProperties(all, filters);
});

final featuredPropertiesProvider = Provider<List<MarketplaceProperty>>((ref) {
  return ref
      .watch(marketplaceListingsProvider)
      .where((p) => p.isFeatured)
      .toList();
});

final recentPropertiesProvider = Provider<List<MarketplaceProperty>>((ref) {
  final all = ref.watch(marketplaceListingsProvider);
  final sorted = [...all]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return sorted.take(4).toList();
});

final recommendedPropertiesProvider = Provider<List<MarketplaceProperty>>((ref) {
  final all = ref.watch(marketplaceListingsProvider);
  final sorted = [...all]..sort((a, b) => b.matchScore.compareTo(a.matchScore));
  return sorted.take(4).toList();
});

final comparePropertiesProvider = Provider<List<MarketplaceProperty>>((ref) {
  final ids = ref.watch(marketplaceCompareProvider);
  final all = ref.watch(marketplaceListingsProvider);
  return all.where((p) => ids.contains(p.id)).toList();
});

final marketplaceCmsProvider = Provider<MarketplaceCmsContent>((ref) {
  final base = _marketplaceCmsBase;
  final listings = ref.watch(marketplaceListingsProvider);
  ref.watch(browseCategoriesRealtimeProvider);
  ref.watch(publishedPropertiesRealtimeProvider);

  List<MarketplaceCategoryCard> withLiveCounts(
    List<MarketplaceCategoryCard> cats,
  ) {
    return [
      for (final c in cats)
        c.copyWith(
          count: countCategoryKey(listings, c.filterKey),
          imageUrl: _coverForCategory(listings, c.filterKey) ?? c.imageUrl,
        ),
    ];
  }

  final cmsCats = ref.watch(publishedBrowseCategoriesProvider).valueOrNull;
  final sourceCats = (cmsCats != null && cmsCats.isNotEmpty)
      ? [
          for (final c in cmsCats)
            MarketplaceCategoryCard(
              label: c.label,
              count: 0,
              filterKey: c.filterKey,
              iconName: c.iconName,
              description: c.description,
              imageUrl: c.imageUrl,
              isFeatured: c.isFeatured,
            ),
        ]
      : base.categories;

  if (!ref.watch(supabaseConfiguredProvider)) {
    return MarketplaceCmsContent(
      hero: base.hero,
      categories: withLiveCounts(sourceCats),
      searchSuggestions: const [],
      faqs: base.faqs,
      insights: base.insights,
    );
  }
  final overlay =
      hubHeroFromPage(ref.watch(publishedPageBySlugProvider('properties')).valueOrNull);
  return MarketplaceCmsContent(
    hero: MarketplaceHeroContent(
      headline: overlay.headline ?? base.hero.headline,
      subheadline: overlay.subheadline ?? base.hero.subheadline,
      primaryCtaLabel: overlay.primaryCtaLabel ?? base.hero.primaryCtaLabel,
      primaryCtaPath: base.hero.primaryCtaPath,
      secondaryCtaLabel: overlay.secondaryCtaLabel ?? base.hero.secondaryCtaLabel,
      secondaryCtaPath: base.hero.secondaryCtaPath,
      tertiaryCtaLabel: base.hero.tertiaryCtaLabel,
      tertiaryCtaPath: base.hero.tertiaryCtaPath,
      backgroundImageUrl:
          overlay.backgroundImageUrl ?? base.hero.backgroundImageUrl,
      backgroundVideoUrl:
          overlay.backgroundVideoUrl ?? base.hero.backgroundVideoUrl,
    ),
    categories: withLiveCounts(sourceCats),
    searchSuggestions: const [],
    faqs: base.faqs,
    insights: base.insights,
  );
});

String? _coverForCategory(List<MarketplaceProperty> listings, String key) {
  for (final p in listings) {
    if (!matchesCategoryKey(p, key)) continue;
    final url = p.imageUrl?.trim();
    if (url != null && url.isNotEmpty) return url;
  }
  return null;
}

const _marketplaceCmsBase = MarketplaceCmsContent(
    hero: MarketplaceHeroContent(
      headline: 'Find Your Perfect Property',
      subheadline:
          'Discover premium homes, commercial spaces, land, and investment opportunities across Nigeria.',
      primaryCtaLabel: 'Browse All',
      primaryCtaPath: RoutePaths.properties,
      secondaryCtaLabel: 'Investment Properties',
      secondaryCtaPath: RoutePaths.investment,
      tertiaryCtaLabel: 'Book Consultation',
      tertiaryCtaPath: RoutePaths.bookInspection,
    ),
    categories: [
      MarketplaceCategoryCard(
        label: 'Luxury Homes',
        count: 24,
        filterKey: 'luxury',
        iconName: 'crown',
        isFeatured: true,
        description:
            'Premium residences crafted for elegance, comfort, and a lifestyle like no other.',
        imageUrl:
            '',
      ),
      MarketplaceCategoryCard(
        label: 'Affordable Homes',
        count: 86,
        filterKey: 'affordable',
        iconName: 'home',
        description: 'Quality homes designed for every budget.',
        imageUrl:
            '',
      ),
      MarketplaceCategoryCard(
        label: 'Family Homes',
        count: 52,
        filterKey: 'family',
        iconName: 'users',
        description: 'Spacious living for growing households.',
        imageUrl:
            '',
      ),
      MarketplaceCategoryCard(
        label: 'Commercial',
        count: 18,
        filterKey: 'commercial',
        iconName: 'building',
        description: 'Offices, retail, and mixed-use spaces.',
        imageUrl:
            '',
      ),
      MarketplaceCategoryCard(
        label: 'Land',
        count: 31,
        filterKey: 'land',
        iconName: 'map',
        description: 'Verified plots in high-growth corridors.',
        imageUrl:
            '',
      ),
      MarketplaceCategoryCard(
        label: 'Investment',
        count: 42,
        filterKey: 'investment',
        iconName: 'trending',
        description: 'Structured opportunities with strong ROI.',
        imageUrl:
            '',
      ),
      MarketplaceCategoryCard(
        label: 'New Launches',
        count: 15,
        filterKey: 'new',
        iconName: 'sparkles',
        description: 'Fresh releases and off-plan estates.',
        imageUrl:
            '',
      ),
    ],
    searchSuggestions: [],
    faqs: [
      MarketplaceFaqItem(
        question: 'How do I buy a property?',
        answer:
            'Browse listings, book an inspection, and our sales team will guide you through documentation and payment.',
      ),
      MarketplaceFaqItem(
        question: 'How do installments work?',
        answer:
            'We offer flexible payment plans with competitive terms. Use our calculator or speak with finance.',
      ),
      MarketplaceFaqItem(
        question: 'Can foreigners buy?',
        answer:
            'Yes, subject to Nigerian property laws. Contact our team for guidance on documentation.',
      ),
      MarketplaceFaqItem(
        question: 'How do inspections work?',
        answer: 'Book online and our team will confirm your slot within 24 hours.',
      ),
      MarketplaceFaqItem(
        question: 'How do I reserve a property?',
        answer:
            'After inspection, pay the reservation fee to secure your unit while documentation is processed.',
      ),
    ],
    insights: [
      MarketplaceInsight(
        title: 'Lagos Average Price',
        value: '₦58M',
        trend: '+8.2%',
        summary: 'Steady demand in Lekki corridor',
      ),
      MarketplaceInsight(
        title: 'Abuja Demand Index',
        value: 'High',
        trend: '+5.1%',
        summary: 'Strong buyer interest in satellite towns',
      ),
      MarketplaceInsight(
        title: 'Construction Activity',
        value: '18 sites',
        trend: 'Active',
        summary: 'Multiple estates in finishing phase',
      ),
    ],
  );
