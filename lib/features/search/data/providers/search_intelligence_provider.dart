import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/growth/analytics/journey_tracker.dart';
import 'package:hdhomesproject/features/properties/data/models/marketplace_filters.dart';
import 'package:hdhomesproject/features/properties/data/models/marketplace_property.dart';
import 'package:hdhomesproject/features/properties/data/providers/marketplace_controller.dart';
import 'package:hdhomesproject/features/properties/data/providers/marketplace_listings_provider.dart';
import 'package:hdhomesproject/features/search/data/models/search_intelligence.dart';

/// Parses natural-language queries into structured marketplace filters (AI placeholder).
AiSearchParseResult parseAiSearchQuery(String input) {
  var filters = MarketplaceFilters(query: input.trim(), sort: MarketplaceSort.bestMatch);
  final extracted = <String>[];
  final q = input.toLowerCase();

  if (q.contains('abuja') || q.contains('fct')) {
    filters = filters.copyWith(state: 'FCT');
    extracted.add('Location: Abuja');
  } else if (q.contains('lekki') || q.contains('lagos')) {
    filters = filters.copyWith(state: 'Lagos', city: q.contains('lekki') ? 'Lekki' : null);
    extracted.add('Location: ${q.contains('lekki') ? 'Lekki, Lagos' : 'Lagos'}');
  } else if (q.contains('port harcourt')) {
    filters = filters.copyWith(state: 'Rivers', city: 'Port Harcourt');
    extracted.add('Location: Port Harcourt');
  }

  if (q.contains('duplex')) {
    filters = filters.copyWith(type: 'Duplex');
    extracted.add('Type: Duplex');
  } else if (q.contains('terrace')) {
    filters = filters.copyWith(type: 'Terrace');
    extracted.add('Type: Terrace');
  } else if (q.contains('apartment') || q.contains('flat')) {
    filters = filters.copyWith(type: 'Apartment');
    extracted.add('Type: Apartment');
  } else if (q.contains('land')) {
    filters = filters.copyWith(category: PropertyCategory.land);
    extracted.add('Category: Land');
  } else if (q.contains('commercial')) {
    filters = filters.copyWith(category: PropertyCategory.commercial);
    extracted.add('Category: Commercial');
  }

  final bedMatch = RegExp(r'(\d)\s*[- ]?\s*bed').firstMatch(q);
  if (bedMatch != null) {
    final beds = int.parse(bedMatch.group(1)!);
    filters = filters.copyWith(minBedrooms: beds);
    extracted.add('Bedrooms: $beds+');
  }

  final underMatch = RegExp(r'under\s*₦?\s*(\d+)\s*m').firstMatch(q);
  if (underMatch != null) {
    final max = int.parse(underMatch.group(1)!) * 1000000;
    filters = filters.copyWith(maxPrice: max);
    extracted.add('Budget: under ₦${underMatch.group(1)}M');
  }

  if (q.contains('swimming pool') || q.contains('pool')) {
    filters = filters.copyWith(amenities: [...filters.amenities, 'Swimming Pool']);
    extracted.add('Amenity: Swimming Pool');
  }
  if (q.contains('smart home')) {
    filters = filters.copyWith(amenities: [...filters.amenities, 'Smart Home']);
    extracted.add('Amenity: Smart Home');
  }
  if (q.contains('installment')) {
    filters = filters.copyWith(paymentOptions: [...filters.paymentOptions, 'Installment']);
    extracted.add('Payment: Installment');
  }

  if (q.contains('invest') || q.contains('roi')) {
    filters = filters.copyWith(purpose: PropertyPurpose.invest, sort: MarketplaceSort.bestInvestment);
    extracted.add('Goal: Investment');
  }

  if (q.contains('off-plan') || q.contains('off plan')) {
    filters = filters.copyWith(completionStatus: CompletionStatus.offPlan);
    extracted.add('Status: Off-plan');
  }
  if (q.contains('ready')) {
    filters = filters.copyWith(completionStatus: CompletionStatus.readyToMove);
    extracted.add('Status: Ready to move');
  }

  if (q.contains('hd-h') || q.contains('hdh')) {
    extracted.add('Property code detected');
  }

  final confidence = (35 + extracted.length * 12).clamp(40, 98);

  return AiSearchParseResult(
    filters: filters,
    extractedCriteria: extracted.isEmpty ? ['General keyword search'] : extracted,
    confidence: confidence,
  );
}

AffordabilityResult calculateAffordability({
  required double monthlyIncome,
  required double savings,
  required double commitments,
}) {
  final disposable = (monthlyIncome - commitments).clamp(0, double.infinity);
  final budget = (disposable * 12 * 5 + savings).round();
  final mortgageOk = disposable >= 500000;
  final installmentOk = disposable >= 300000;

  return AffordabilityResult(
    comfortableBudget: '₦${_formatCompact(budget)}',
    mortgageEligible: mortgageOk,
    installmentAffordable: installmentOk ? 'Up to ₦${_formatCompact((disposable * 12 * 8).round())}' : 'Limited',
    recommendedPlan: mortgageOk ? 'Mortgage + 20% down payment' : 'Developer installment plan',
  );
}

String _formatCompact(int n) {
  if (n >= 1000000000) return '${(n / 1000000000).toStringAsFixed(1)}B';
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(0)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K';
  return '$n';
}

final savedSearchesProvider = StateProvider<List<SavedSearch>>((ref) => [
      SavedSearch(
        id: 'ss1',
        name: 'Lagos Duplex under ₦120M',
        filters: const MarketplaceFilters(
          state: 'Lagos',
          type: 'Duplex',
          maxPrice: 120000000,
        ),
        createdAt: DateTime(2026, 3, 1),
      ),
      SavedSearch(
        id: 'ss2',
        name: 'Abuja Investment Properties',
        filters: const MarketplaceFilters(
          state: 'FCT',
          purpose: PropertyPurpose.invest,
          sort: MarketplaceSort.bestInvestment,
        ),
        createdAt: DateTime(2026, 2, 15),
      ),
    ]);

final propertyAlertsProvider = StateProvider<List<PropertyAlert>>((ref) => const [
      PropertyAlert(
        id: 'pa1',
        label: 'New Lekki listings',
        trigger: 'New matching properties',
        channel: 'Email + Dashboard',
        active: true,
      ),
      PropertyAlert(
        id: 'pa2',
        label: 'Price drop alerts',
        trigger: 'Price reduction on saved properties',
        channel: 'Email',
        active: true,
      ),
      PropertyAlert(
        id: 'pa3',
        label: 'Horizon Gardens Phase 2',
        trigger: 'New phase launch',
        channel: 'WhatsApp (future)',
        active: false,
      ),
    ]);

final searchHistoryProvider = StateProvider<List<SearchHistoryEntry>>((ref) => [
      SearchHistoryEntry(
        id: 'h1',
        query: '4 bedroom duplex Lekki',
        filterSummary: 'Lagos · Duplex · 4+ beds',
        searchedAt: DateTime(2026, 4, 8),
        resultsCount: 6,
      ),
      SearchHistoryEntry(
        id: 'h2',
        query: 'Abuja investment',
        filterSummary: 'FCT · Invest · Best investment sort',
        searchedAt: DateTime(2026, 4, 5),
        resultsCount: 4,
      ),
    ]);

final searchAnalyticsProvider = Provider<SearchAnalyticsSummary>((ref) {
  final history = ref.watch(searchHistoryProvider);
  final saved = ref.watch(savedSearchesProvider);
  final recent = ref.watch(marketplaceRecentProvider);

  return SearchAnalyticsSummary(
    searchesPerformed: history.length,
    savedSearches: saved.length,
    favoriteLocations: const ['Lekki', 'Abuja', 'Chevron'],
    propertiesViewed: recent.length,
    suggestedImprovement: 'Try adding a max budget filter to narrow your Lekki duplex results.',
  );
});

final recentlyViewedPropertiesProvider = Provider<List<MarketplaceProperty>>((ref) {
  final ids = ref.watch(marketplaceRecentProvider);
  final all = ref.watch(marketplaceListingsProvider);
  if (ids.isEmpty) {
    return all.take(3).toList();
  }
  return all.where((p) => ids.contains(p.id)).toList();
});

final aiMatchedPropertiesProvider = Provider<List<MarketplaceProperty>>((ref) {
  final all = ref.watch(marketplaceListingsProvider);
  final sorted = [...all]..sort((a, b) => b.matchScore.compareTo(a.matchScore));
  return sorted.take(6).toList();
});

final searchEmptyAlternativesProvider = Provider<List<MarketplaceProperty>>((ref) {
  final all = ref.watch(marketplaceListingsProvider);
  final sorted = [...all]..sort((a, b) => b.popularity.compareTo(a.popularity));
  return sorted.take(4).toList();
});

void recordSearch(WidgetRef ref, {required String query, required int resultsCount}) {
  final filters = ref.read(marketplaceFiltersProvider);
  final summary = _filterSummary(filters);
  final entry = SearchHistoryEntry(
    id: 'h-${DateTime.now().millisecondsSinceEpoch}',
    query: query.isEmpty ? summary : query,
    filterSummary: summary,
    searchedAt: DateTime.now(),
    resultsCount: resultsCount,
  );
  ref.read(searchHistoryProvider.notifier).update((s) => [entry, ...s.take(19)]);
  trackGrowthSearch(ref, query.isEmpty ? summary : query, filters: {'summary': summary});
}

String _filterSummary(MarketplaceFilters f) {
  final parts = <String>[];
  if (f.state != null) parts.add(f.state!);
  if (f.city != null) parts.add(f.city!);
  if (f.type != null) parts.add(f.type!);
  if (f.purpose != null) parts.add(f.purpose!.name);
  if (f.minBedrooms != null) parts.add('${f.minBedrooms!}+ beds');
  if (f.maxPrice != null) parts.add('max ₦${(f.maxPrice! / 1000000).round()}M');
  return parts.isEmpty ? 'All properties' : parts.join(' · ');
}

void saveCurrentSearch(WidgetRef ref, String name) {
  final filters = ref.read(marketplaceFiltersProvider);
  final saved = SavedSearch(
    id: 'ss-${DateTime.now().millisecondsSinceEpoch}',
    name: name,
    filters: filters,
    createdAt: DateTime.now(),
  );
  ref.read(savedSearchesProvider.notifier).update((s) => [saved, ...s]);
}
