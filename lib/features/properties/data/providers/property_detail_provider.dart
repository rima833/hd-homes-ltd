import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/properties/data/models/marketplace_property.dart';
import 'package:hdhomesproject/features/properties/data/models/property_detail_content.dart';
import 'package:hdhomesproject/features/properties/data/models/property_detail_extras.dart';
import 'package:hdhomesproject/features/properties/data/providers/marketplace_listings_provider.dart';

/// Public property detail — prefers a fresh CMS fetch by id or slug
/// (homepage cards use slug; marketplace cards use UUID).
final propertyDetailProvider =
    Provider.family<PropertyDetailContent?, String>((ref, idOrSlug) {
  final listings = ref.watch(marketplaceListingsProvider);
  MarketplaceProperty? findLocal() {
    return listings.cast<MarketplaceProperty?>().firstWhere(
          (p) => p?.id == idOrSlug || p?.slug == idOrSlug,
          orElse: () => null,
        );
  }

  if (ref.watch(supabaseConfiguredProvider)) {
    final remote = ref.watch(publishedPropertyByIdProvider(idOrSlug));
    final cms = remote.asData?.value;
    if (cms != null) {
      return _buildDetail(toMarketplaceProperty(cms), listings);
    }
    if (remote.isLoading) {
      final listing = findLocal();
      if (listing != null) return _buildDetail(listing, listings);
      return null;
    }
  }

  final listing = findLocal();
  if (listing == null) return null;
  return _buildDetail(listing, listings);
});

final relatedPropertiesProvider =
    Provider.family<List<MarketplaceProperty>, String>((ref, id) {
  final detail = ref.watch(propertyDetailProvider(id));
  if (detail == null) return [];
  final all = ref.watch(marketplaceListingsProvider);
  return all
      .where((p) => detail.relatedIds.contains(p.id))
      .toList();
});

PropertyDetailContent _buildDetail(
  MarketplaceProperty p,
  List<MarketplaceProperty> all,
) {
  final related = all
      .where((x) => x.id != p.id && (x.city == p.city || x.type == p.type))
      .take(3)
      .map((x) => x.id)
      .toList();

  final x = p.detailExtras ?? PropertyDetailExtras.emptyForWizard();
  final price = p.priceValue;
  final rawFee = x.reservationFeePercent;
  final feeAmount = rawFee > 100 ? rawFee : price * rawFee / 100;
  final overview = p.overviewSummary?.trim() ?? '';

  final gallery = p.galleryUrls.isNotEmpty
      ? p.galleryUrls
      : (p.imageUrl != null && p.imageUrl!.isNotEmpty
          ? [p.imageUrl!]
          : const <String>[]);

  final paymentPlans = x.paymentPlans
      .where((plan) => plan.name.trim().isNotEmpty && plan.months > 0)
      .map((plan) {
    final rawDown = plan.downPaymentPercent;
    final downPayment = rawDown > 100 ? rawDown : price * rawDown / 100;
    final balance = (price - downPayment).clamp(0, price);
    final months = plan.months <= 0 ? 1 : plan.months;
    final withInterest = balance * (1 + plan.interestRate / 100);
    return PropertyPaymentPlan(
      name: plan.name,
      downPayment: downPayment.round(),
      monthlyInstallment: (withInterest / months).round(),
      durationMonths: plan.months,
      interestRate: plan.interestRate,
    );
  }).toList();

  final floorPlans = x.floorPlans
      .where((f) => f.label.trim().isNotEmpty)
      .map(
        (f) => PropertyFloorPlan(
          label: f.label,
          dimensions: f.dimensions,
          downloadUrl: f.downloadUrl.isEmpty ? '#' : f.downloadUrl,
        ),
      )
      .toList();

  final documents = x.documents
      .where(
        (d) => d.title.trim().isNotEmpty && d.url.trim().isNotEmpty,
      )
      .map(
        (d) => PropertyDocument(
          title: d.title,
          type: d.type,
          url: d.url,
        ),
      )
      .toList();

  final nearby = x.nearbyPlaces
      .where((n) => n.name.trim().isNotEmpty)
      .map(
        (n) => NearbyPlace(
          name: n.name,
          category: n.category,
          distance: n.distance,
          travelTime: n.travelTime,
        ),
      )
      .toList();

  final reviews = x.reviews
      .where((r) => r.comment.trim().isNotEmpty || r.name.trim().isNotEmpty)
      .map(
        (r) => PropertyReview(
          name: r.name,
          role: r.role,
          rating: r.rating.toDouble(),
          comment: r.comment,
          verified: r.verified,
          type: r.type,
        ),
      )
      .toList();

  final faqs = x.faqs
      .where((f) => f.question.trim().isNotEmpty)
      .map((f) => PropertyFaqItem(question: f.question, answer: f.answer))
      .toList();

  final slots = x.inspectionSlots
      .where((s) => s.date.trim().isNotEmpty || s.time.trim().isNotEmpty)
      .map(
        (s) => InspectionSlot(
          date: s.date,
          time: s.time,
          available: s.available,
        ),
      )
      .toList();

  final brochure = documents
      .cast<PropertyDocument?>()
      .firstWhere(
        (d) => d!.title.toLowerCase().contains('brochure'),
        orElse: () => documents.isNotEmpty ? documents.first : null,
      );

  return PropertyDetailContent(
    listing: p,
    lastUpdated: p.createdAt,
    relatedIds: related,
    overview: PropertyOverview(
      summary: overview,
      architecturalConcept: p.architecturalConcept?.trim() ?? '',
      lifestyleBenefits: p.lifestyleTags,
      targetBuyers: x.targetBuyers.trim(),
      investmentPotential: p.investmentPotentialText?.trim() ?? '',
      communityFeatures: x.communityFeatures,
      developerHighlights: x.developerHighlights,
    ),
    specs: PropertySpecs(
      bedrooms: p.bedrooms,
      bathrooms: p.bathrooms,
      toilets: p.toilets ?? 0,
      kitchens: p.kitchens ?? 0,
      parkingSpaces: p.parkingSpaces ?? 0,
      floorArea: p.buildingSize,
      landArea: p.landSize,
      plotSize: p.landSize,
      floors: p.floors ?? 0,
      yearBuilt: p.yearBuilt ?? '',
      smartHomeFeatures: p.amenities.where((a) => a.contains('Smart')).toList(),
      powerSupply: p.powerSupply ?? '',
      waterSupply: p.waterSupply ?? '',
      internetConnectivity: p.internetConnectivity ?? '',
    ),
    pricing: PropertyPricing(
      basePrice: price,
      promotionalPrice: (p.promoPrice != null && p.promoPrice! > 0)
          ? p.promoPrice!.round()
          : null,
      reservationFee: feeAmount.round(),
      taxesAndFees: x.taxesAndFees,
      mortgageEligible: x.mortgageEligible,
      showMortgageCalculator: x.showMortgageCalculator,
      mortgageDepositPercent: x.mortgageDepositPercent,
      mortgageDepositMinPercent: x.mortgageDepositMinPercent,
      mortgageDepositMaxPercent: x.mortgageDepositMaxPercent,
      mortgageInterestRate: x.mortgageInterestRate,
      mortgageInterestMin: x.mortgageInterestMin,
      mortgageInterestMax: x.mortgageInterestMax,
      mortgageTermYears: x.mortgageTermYears,
      mortgageTermMinYears: x.mortgageTermMinYears,
      mortgageTermMaxYears: x.mortgageTermMaxYears,
    ),
    paymentPlans: paymentPlans,
    investment: PropertyInvestmentDetail(
      expectedRoi: _adminText(p.roiEstimate),
      rentalYield: _adminText(p.rentalYield),
      capitalAppreciation: x.appreciationEstimate.trim(),
      paybackPeriod: '',
      occupancyForecast: '',
      investmentScore: p.investmentScore,
      riskLevel: p.riskLevel,
      isInvestmentProperty:
          p.purpose == PropertyPurpose.invest ||
              p.category == PropertyCategory.investment,
    ),
    media: PropertyMediaBundle(
      images: gallery,
      videos: [
        if (x.videoTourUrl.trim().isNotEmpty) x.videoTourUrl.trim(),
      ],
      hasVirtualTour: x.tour360Url.trim().isNotEmpty,
      hasDroneFootage: x.droneTourUrl.trim().isNotEmpty,
      brochureUrl: brochure?.url,
      tour360Url: x.tour360Url.trim().isEmpty ? null : x.tour360Url.trim(),
      videoTourUrl:
          x.videoTourUrl.trim().isEmpty ? null : x.videoTourUrl.trim(),
      droneTourUrl:
          x.droneTourUrl.trim().isEmpty ? null : x.droneTourUrl.trim(),
    ),
    floorPlans: floorPlans,
    masterPlan: PropertyMasterPlan(
      description: x.masterPlanDescription.trim(),
      legend: x.masterPlanLegend,
    ),
    construction: const PropertyConstructionDetail(
      progress: 0,
      timeline: '',
      weeklyUpdate: '',
      completionForecast: '',
      milestones: [],
    ),
    documents: documents,
    nearbyPlaces: nearby,
    reviews: reviews,
    faqs: faqs,
    availability: PropertyAvailabilityDashboard(
      totalUnits: x.totalUnits,
      availableUnits: x.availableUnits,
      reservedUnits: x.reservedUnits,
      soldUnits: x.soldUnits,
    ),
    neighborhood: NeighborhoodIntelligence(
      safetyScore: x.safetyScore,
      trafficConditions: x.trafficConditions,
      plannedInfrastructure: x.plannedInfrastructure,
      appreciationEstimate: x.appreciationEstimate.trim(),
      walkabilityScore: x.walkabilityScore,
      lifestyleScore: x.lifestyleScore,
    ),
    inspectionSlots: slots,
    aiInsight: PropertyAiInsight(
      matchSummary: '',
      investmentStrengths: const [],
      lifestyleBenefits: p.lifestyleTags,
      affordabilityNote: '',
      suggestedActions: const [],
    ),
  );
}

String _adminText(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty || trimmed == '—' || trimmed == '-') return '';
  return trimmed;
}
