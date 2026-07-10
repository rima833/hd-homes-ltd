// Property listing model for the marketplace (CMS/Supabase in Part 5).

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

  String get propertyCode => 'HD-${id.toUpperCase()}';
}

class MarketplaceCategoryCard {
  const MarketplaceCategoryCard({
    required this.label,
    required this.count,
    required this.filterKey,
    required this.iconName,
  });

  final String label;
  final int count;
  final String filterKey;
  final String iconName;
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
  });

  final String headline;
  final String subheadline;
  final String primaryCtaLabel;
  final String primaryCtaPath;
  final String secondaryCtaLabel;
  final String secondaryCtaPath;
  final String tertiaryCtaLabel;
  final String tertiaryCtaPath;
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
