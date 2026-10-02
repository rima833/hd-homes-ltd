// Property listing model for the marketplace (CMS/Supabase in Part 5).

import 'package:hdhomesproject/features/properties/data/models/property_detail_extras.dart';

enum PropertyPurpose { buy, invest, rent }

enum PropertyCategory {
  residential,
  commercial,
  land,
  investment,
}

enum AvailabilityLevel {
  available,
  limited,
  almostSoldOut,
  soldOut,
}

enum CompletionStatus {
  readyToMove,
  offPlan,
  underConstruction,
}

class MarketplaceProperty {
  const MarketplaceProperty({
    required this.id,
    required this.title,
    required this.slug,
    required this.price,
    required this.priceValue,
    required this.location,
    required this.city,
    required this.state,
    required this.estate,
    required this.type,
    required this.category,
    required this.purpose,
    required this.bedrooms,
    required this.bathrooms,
    required this.landSize,
    required this.buildingSize,
    required this.status,
    required this.completionStatus,
    required this.amenities,
    required this.paymentOptions,
    required this.developer,
    required this.isFeatured,
    required this.isNew,
    required this.isVerified,
    required this.hasPaymentPlan,
    required this.matchScore,
    required this.investmentScore,
    required this.availability,
    required this.roiEstimate,
    required this.rentalYield,
    required this.capitalAppreciation,
    required this.riskLevel,
    required this.lifestyleTags,
    required this.imageUrl,
    required this.galleryUrls,
    required this.lat,
    required this.lng,
    required this.createdAt,
    required this.popularity,
    this.toilets,
    this.kitchens,
    this.parkingSpaces,
    this.floors,
    this.yearBuilt,
    this.powerSupply,
    this.waterSupply,
    this.internetConnectivity,
    this.overviewSummary,
    this.architecturalConcept,
    this.investmentPotentialText,
    this.propertyCodeOverride,
    this.detailExtras,
    this.promoPrice,
  });

  final String id;
  final String title;
  final String slug;
  final String price;
  final int priceValue;
  final String location;
  final String city;
  final String state;
  final String estate;
  final String type;
  final PropertyCategory category;
  final PropertyPurpose purpose;
  final int bedrooms;
  final int bathrooms;
  final String landSize;
  final String buildingSize;
  final String status;
  final CompletionStatus completionStatus;
  final List<String> amenities;
  final List<String> paymentOptions;
  final String developer;
  final bool isFeatured;
  final bool isNew;
  final bool isVerified;
  final bool hasPaymentPlan;
  final int matchScore;
  final int investmentScore;
  final AvailabilityLevel availability;
  final String roiEstimate;
  final String rentalYield;
  final String capitalAppreciation;
  final String riskLevel;
  final List<String> lifestyleTags;
  final String? imageUrl;
  final List<String> galleryUrls;
  final double lat;
  final double lng;
  final DateTime createdAt;
  final int popularity;

  /// When set, public detail uses these instead of synthesized values.
  final int? toilets;
  final int? kitchens;
  final int? parkingSpaces;
  final int? floors;
  final String? yearBuilt;
  final String? powerSupply;
  final String? waterSupply;
  final String? internetConnectivity;
  final String? overviewSummary;
  final String? architecturalConcept;
  final String? investmentPotentialText;
  final String? propertyCodeOverride;
  final PropertyDetailExtras? detailExtras;
  final double? promoPrice;

  String get propertyCode =>
      propertyCodeOverride ?? 'HD-${id.toUpperCase()}';
}

class MarketplaceCategoryCard {
  const MarketplaceCategoryCard({
    required this.label,
    required this.count,
    required this.filterKey,
    required this.iconName,
    this.description = '',
    this.imageUrl,
    this.isFeatured = false,
  });

  final String label;
  final int count;
  final String filterKey;
  final String iconName;
  final String description;
  final String? imageUrl;
  final bool isFeatured;

  MarketplaceCategoryCard copyWith({
    String? label,
    int? count,
    String? filterKey,
    String? iconName,
    String? description,
    String? imageUrl,
    bool? isFeatured,
  }) {
    return MarketplaceCategoryCard(
      label: label ?? this.label,
      count: count ?? this.count,
      filterKey: filterKey ?? this.filterKey,
      iconName: iconName ?? this.iconName,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      isFeatured: isFeatured ?? this.isFeatured,
    );
  }
}

class MarketplaceFaqItem {
  const MarketplaceFaqItem({required this.question, required this.answer});

  final String question;
  final String answer;
}

class MarketplaceHeroContent {
  const MarketplaceHeroContent({
    required this.headline,
    required this.subheadline,
    required this.primaryCtaLabel,
    required this.primaryCtaPath,
    required this.secondaryCtaLabel,
    required this.secondaryCtaPath,
    required this.tertiaryCtaLabel,
    required this.tertiaryCtaPath,
    this.backgroundImageUrl,
    this.backgroundVideoUrl,
  });

  final String headline;
  final String subheadline;
  final String primaryCtaLabel;
  final String primaryCtaPath;
  final String secondaryCtaLabel;
  final String secondaryCtaPath;
  final String tertiaryCtaLabel;
  final String tertiaryCtaPath;
  final String? backgroundImageUrl;
  final String? backgroundVideoUrl;
}

class MarketplaceInsight {
  const MarketplaceInsight({
    required this.title,
    required this.value,
    required this.trend,
    required this.summary,
  });

  final String title;
  final String value;
  final String trend;
  final String summary;
}

class MarketplaceCmsContent {
  const MarketplaceCmsContent({
    required this.hero,
    required this.categories,
    required this.searchSuggestions,
    required this.faqs,
    required this.insights,
  });

  final MarketplaceHeroContent hero;
  final List<MarketplaceCategoryCard> categories;
  final List<String> searchSuggestions;
  final List<MarketplaceFaqItem> faqs;
  final List<MarketplaceInsight> insights;
}
