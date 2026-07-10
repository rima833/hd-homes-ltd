import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
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
  return const MarketplaceCmsContent(
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
      ),
      MarketplaceCategoryCard(
        label: 'Affordable Homes',
        count: 86,
        filterKey: 'affordable',
        iconName: 'home',
      ),
      MarketplaceCategoryCard(
        label: 'Family Homes',
        count: 52,
        filterKey: 'family',
        iconName: 'users',
      ),
      MarketplaceCategoryCard(
        label: 'Commercial',
        count: 18,
        filterKey: 'commercial',
        iconName: 'building',
      ),
      MarketplaceCategoryCard(
        label: 'Land',
        count: 31,
        filterKey: 'land',
        iconName: 'map',
      ),
      MarketplaceCategoryCard(
        label: 'Investment',
        count: 42,
        filterKey: 'investment',
        iconName: 'trending',
      ),
      MarketplaceCategoryCard(
        label: 'New Listings',
        count: 15,
        filterKey: 'new',
        iconName: 'sparkles',
      ),
      MarketplaceCategoryCard(
        label: 'Hot Deals',
        count: 9,
        filterKey: 'hot',
        iconName: 'flame',
      ),
    ],
    searchSuggestions: [
      'Horizon Gardens Lekki',
      '4 bedroom duplex Abuja',
      'Off-plan investment Lagos',
      'Commercial plot Port Harcourt',
      'HD-H001',
    ],
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
});
