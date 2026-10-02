import 'package:hdhomesproject/features/properties/data/models/marketplace_property.dart';

enum MarketplaceSort {
  newest,
  priceLowHigh,
  priceHighLow,
  popular,
  bestInvestment,
  bestMatch,
}

class MarketplaceFilters {
  const MarketplaceFilters({
    this.query = '',
    this.state,
    this.city,
    this.estate,
    this.category,
    this.purpose,
    this.type,
    this.minBedrooms,
    this.minBathrooms,
    this.minPrice,
    this.maxPrice,
    this.completionStatus,
    this.amenities = const [],
    this.paymentOptions = const [],
    this.developer,
    this.lifestyle,
    this.categoryKey,
    this.sort = MarketplaceSort.newest,
  });

  final String query;
  final String? state;
  final String? city;
  final String? estate;
  final PropertyCategory? category;
  final PropertyPurpose? purpose;
  final String? type;
  final int? minBedrooms;
  final int? minBathrooms;
  final int? minPrice;
  final int? maxPrice;
  final CompletionStatus? completionStatus;
  final List<String> amenities;
  final List<String> paymentOptions;
  final String? developer;
  final String? lifestyle;
  /// Browse-by-category key (luxury, affordable, land, …) — live counts + filter.
  final String? categoryKey;
  final MarketplaceSort sort;

  MarketplaceFilters copyWith({
    String? query,
    String? state,
    String? city,
    String? estate,
    PropertyCategory? category,
    PropertyPurpose? purpose,
    String? type,
    int? minBedrooms,
    int? minBathrooms,
    int? minPrice,
    int? maxPrice,
    CompletionStatus? completionStatus,
    List<String>? amenities,
    List<String>? paymentOptions,
    String? developer,
    String? lifestyle,
    String? categoryKey,
    MarketplaceSort? sort,
    bool clearState = false,
    bool clearCity = false,
    bool clearEstate = false,
    bool clearCategory = false,
    bool clearPurpose = false,
    bool clearType = false,
    bool clearCompletion = false,
    bool clearDeveloper = false,
    bool clearLifestyle = false,
    bool clearCategoryKey = false,
    bool clearMinBedrooms = false,
    bool clearMinBathrooms = false,
    bool clearMinPrice = false,
    bool clearMaxPrice = false,
  }) {
    return MarketplaceFilters(
      query: query ?? this.query,
      state: clearState ? null : (state ?? this.state),
      city: clearCity ? null : (city ?? this.city),
      estate: clearEstate ? null : (estate ?? this.estate),
      category: clearCategory ? null : (category ?? this.category),
      purpose: clearPurpose ? null : (purpose ?? this.purpose),
      type: clearType ? null : (type ?? this.type),
      minBedrooms: clearMinBedrooms ? null : (minBedrooms ?? this.minBedrooms),
      minBathrooms:
          clearMinBathrooms ? null : (minBathrooms ?? this.minBathrooms),
      minPrice: clearMinPrice ? null : (minPrice ?? this.minPrice),
      maxPrice: clearMaxPrice ? null : (maxPrice ?? this.maxPrice),
      completionStatus:
          clearCompletion ? null : (completionStatus ?? this.completionStatus),
      amenities: amenities ?? this.amenities,
      paymentOptions: paymentOptions ?? this.paymentOptions,
      developer: clearDeveloper ? null : (developer ?? this.developer),
      lifestyle: clearLifestyle ? null : (lifestyle ?? this.lifestyle),
      categoryKey: clearCategoryKey ? null : (categoryKey ?? this.categoryKey),
      sort: sort ?? this.sort,
    );
  }

  int get activeCount {
    var count = 0;
    if (query.trim().isNotEmpty) count++;
    if (state != null) count++;
    if (city != null) count++;
    if (estate != null) count++;
    if (category != null) count++;
    if (purpose != null) count++;
    if (type != null) count++;
    if (minBedrooms != null) count++;
    if (minBathrooms != null) count++;
    if (minPrice != null || maxPrice != null) count++;
    if (completionStatus != null) count++;
    if (amenities.isNotEmpty) count++;
    if (paymentOptions.isNotEmpty) count++;
    if (developer != null) count++;
    if (lifestyle != null) count++;
    if (categoryKey != null) count++;
    return count;
  }
}

/// Category browse matching — used for live listing counts and grid filters.
bool matchesCategoryKey(MarketplaceProperty p, String key) {
  final hay =
      '${p.title} ${p.type} ${p.status} ${p.category.name} ${p.purpose.name} '
              '${p.lifestyleTags.join(' ')} ${p.amenities.join(' ')} '
              '${p.propertyCode}'
          .toLowerCase();
  final slug = key.toLowerCase().trim();

  switch (slug) {
    case 'luxury':
      return p.lifestyleTags.contains('Luxury Living') ||
          hay.contains('luxury') ||
          hay.contains('premium') ||
          hay.contains('penthouse') ||
          hay.contains('mansion') ||
          (p.priceValue >= 80000000) ||
          (p.isFeatured &&
              (p.category == PropertyCategory.residential ||
                  hay.contains('apartment') ||
                  hay.contains('duplex') ||
                  hay.contains('villa')));
    case 'affordable':
      return (p.priceValue > 0 && p.priceValue <= 35000000) ||
          hay.contains('affordable') ||
          hay.contains('starter') ||
          hay.contains('budget');
    case 'family':
      return p.lifestyleTags.contains('Family Living') ||
          p.bedrooms >= 3 ||
          hay.contains('family') ||
          hay.contains('duplex') ||
          hay.contains('terrace') ||
          hay.contains('townhouse');
    case 'commercial':
      return p.category == PropertyCategory.commercial ||
          hay.contains('commercial') ||
          hay.contains('office') ||
          hay.contains('retail') ||
          hay.contains('plaza');
    case 'land':
      return p.category == PropertyCategory.land ||
          hay.contains('land') ||
          hay.contains('plot');
    case 'investment':
      return p.category == PropertyCategory.investment ||
          p.purpose == PropertyPurpose.invest ||
          hay.contains('invest') ||
          hay.contains('roi') ||
          hay.contains('off-plan') ||
          hay.contains('off plan');
    case 'new':
    case 'new_launches':
      return p.isNew ||
          hay.contains('new launch') ||
          hay.contains('new listing') ||
          hay.contains('launch') ||
          hay.contains('off-plan') ||
          hay.contains('off plan') ||
          p.completionStatus == CompletionStatus.underConstruction ||
          DateTime.now().difference(p.createdAt).inDays <= 90;
    case 'hot':
      return p.isFeatured ||
          hay.contains('deal') ||
          hay.contains('hot') ||
          hay.contains('promo');
    default:
      // Exact type / slug match for admin-defined keys (e.g. duplex, apartment).
      return hay.contains(slug) ||
          p.type.toLowerCase().replaceAll(' ', '_') == slug ||
          p.type.toLowerCase() == slug;
  }
}

int countCategoryKey(List<MarketplaceProperty> properties, String key) =>
    properties.where((p) => matchesCategoryKey(p, key)).length;

List<MarketplaceProperty> filterProperties(
  List<MarketplaceProperty> properties,
  MarketplaceFilters filters,
) {
  var results = properties.where((p) {
    if (filters.query.isNotEmpty) {
      final tokens = filters.query
          .toLowerCase()
          .split(RegExp(r'\s+'))
          .where((t) => t.isNotEmpty)
          .toList();
      final haystack =
          '${p.title} ${p.location} ${p.city} ${p.state} ${p.estate} '
                  '${p.propertyCode} ${p.type} ${p.bedrooms} bedroom '
                  '${p.purpose.name} ${p.status} ${p.lifestyleTags.join(' ')}'
              .toLowerCase();
      for (final token in tokens) {
        if (!haystack.contains(token)) return false;
      }
    }
    if (filters.state != null) {
      final want = filters.state!.toLowerCase().trim();
      final got = p.state.toLowerCase().trim();
      final city = p.city.toLowerCase().trim();
      final loc = p.location.toLowerCase();
      bool matchesState() {
        if (want == 'fct' || want == 'abuja') {
          return got == 'fct' ||
              got == 'abuja' ||
              city == 'abuja' ||
              loc.contains('abuja');
        }
        if (want == 'lagos') {
          return got == 'lagos' || city == 'lagos' || loc.contains('lagos');
        }
        return got == want || city == want || loc.contains(want);
      }

      if (!matchesState()) return false;
    }
    if (filters.city != null &&
        p.city.toLowerCase() != filters.city!.toLowerCase()) {
      return false;
    }
    if (filters.estate != null &&
        p.estate.toLowerCase() != filters.estate!.toLowerCase()) {
      return false;
    }
    if (filters.categoryKey != null &&
        !matchesCategoryKey(p, filters.categoryKey!)) {
      return false;
    }
    if (filters.category != null && p.category != filters.category) return false;
    if (filters.purpose != null && p.purpose != filters.purpose) return false;
    if (filters.type != null &&
        p.type.toLowerCase() != filters.type!.toLowerCase()) {
      return false;
    }
    if (filters.minBedrooms != null && p.bedrooms < filters.minBedrooms!) {
      return false;
    }
    if (filters.minBathrooms != null && p.bathrooms < filters.minBathrooms!) {
      return false;
    }
    if (filters.minPrice != null &&
        p.priceValue > 0 &&
        p.priceValue < filters.minPrice!) {
      return false;
    }
    if (filters.maxPrice != null &&
        p.priceValue > 0 &&
        p.priceValue > filters.maxPrice!) {
      return false;
    }
    if (filters.completionStatus != null) {
      if (filters.completionStatus == CompletionStatus.offPlan) {
        if (p.completionStatus != CompletionStatus.offPlan &&
            p.completionStatus != CompletionStatus.underConstruction) {
          return false;
        }
      } else if (p.completionStatus != filters.completionStatus) {
        return false;
      }
    }
    if (filters.developer != null && p.developer != filters.developer) {
      return false;
    }
    if (filters.lifestyle != null &&
        !p.lifestyleTags.contains(filters.lifestyle)) {
      return false;
    }
    for (final amenity in filters.amenities) {
      if (!p.amenities.contains(amenity)) return false;
    }
    for (final option in filters.paymentOptions) {
      if (!p.paymentOptions.contains(option)) return false;
    }
    return true;
  }).toList();

  results = switch (filters.sort) {
    MarketplaceSort.newest =>
      results..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
    MarketplaceSort.priceLowHigh =>
      results..sort((a, b) => a.priceValue.compareTo(b.priceValue)),
    MarketplaceSort.priceHighLow =>
      results..sort((a, b) => b.priceValue.compareTo(a.priceValue)),
    MarketplaceSort.popular =>
      results..sort((a, b) => b.popularity.compareTo(a.popularity)),
    MarketplaceSort.bestInvestment =>
      results..sort((a, b) => b.investmentScore.compareTo(a.investmentScore)),
    MarketplaceSort.bestMatch =>
      results..sort((a, b) => b.matchScore.compareTo(a.matchScore)),
  };

  return results;
}
