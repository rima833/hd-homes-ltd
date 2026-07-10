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
    this.sort = MarketplaceSort.newest,
    this.showMap = false,
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
  final MarketplaceSort sort;
  final bool showMap;

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
    MarketplaceSort? sort,
    bool? showMap,
    bool clearState = false,
    bool clearCity = false,
    bool clearEstate = false,
    bool clearCategory = false,
    bool clearPurpose = false,
    bool clearType = false,
    bool clearCompletion = false,
    bool clearDeveloper = false,
    bool clearLifestyle = false,
  }) {
    return MarketplaceFilters(
      query: query ?? this.query,
      state: clearState ? null : (state ?? this.state),
      city: clearCity ? null : (city ?? this.city),
      estate: clearEstate ? null : (estate ?? this.estate),
      category: clearCategory ? null : (category ?? this.category),
      purpose: clearPurpose ? null : (purpose ?? this.purpose),
      type: clearType ? null : (type ?? this.type),
      minBedrooms: minBedrooms ?? this.minBedrooms,
      minBathrooms: minBathrooms ?? this.minBathrooms,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      completionStatus:
          clearCompletion ? null : (completionStatus ?? this.completionStatus),
      amenities: amenities ?? this.amenities,
      paymentOptions: paymentOptions ?? this.paymentOptions,
      developer: clearDeveloper ? null : (developer ?? this.developer),
      lifestyle: clearLifestyle ? null : (lifestyle ?? this.lifestyle),
      sort: sort ?? this.sort,
      showMap: showMap ?? this.showMap,
    );
  }

  int get activeCount {
    var count = 0;
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
    return count;
  }
}

List<MarketplaceProperty> filterProperties(
  List<MarketplaceProperty> properties,
  MarketplaceFilters filters,
) {
  var results = properties.where((p) {
    if (filters.query.isNotEmpty) {
      final q = filters.query.toLowerCase();
      final haystack =
          '${p.title} ${p.location} ${p.city} ${p.estate} ${p.propertyCode} ${p.type}'
              .toLowerCase();
      if (!haystack.contains(q)) return false;
    }
    if (filters.state != null && p.state != filters.state) return false;
    if (filters.city != null && p.city != filters.city) return false;
    if (filters.estate != null && p.estate != filters.estate) return false;
    if (filters.category != null && p.category != filters.category) return false;
    if (filters.purpose != null && p.purpose != filters.purpose) return false;
    if (filters.type != null && p.type != filters.type) return false;
    if (filters.minBedrooms != null && p.bedrooms < filters.minBedrooms!) {
      return false;
    }
    if (filters.minBathrooms != null && p.bathrooms < filters.minBathrooms!) {
      return false;
    }
    if (filters.minPrice != null && p.priceValue < filters.minPrice!) {
      return false;
    }
    if (filters.maxPrice != null && p.priceValue > filters.maxPrice!) {
      return false;
    }
    if (filters.completionStatus != null &&
        p.completionStatus != filters.completionStatus) {
      return false;
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
