import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/features/properties/data/models/marketplace_property.dart';
import 'package:hdhomesproject/features/properties/data/models/property_detail_content.dart';
import 'package:hdhomesproject/features/properties/data/providers/marketplace_listings_provider.dart';

final propertyDetailProvider =
    Provider.family<PropertyDetailContent?, String>((ref, id) {
  final listings = ref.watch(marketplaceListingsProvider);
  final listing = listings.cast<MarketplaceProperty?>().firstWhere(
        (p) => p?.id == id,
        orElse: () => null,
      );
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

  return PropertyDetailContent(
    listing: p,
    lastUpdated: p.createdAt,
    relatedIds: related,
    overview: PropertyOverview(
      summary:
          '${p.title} in ${p.estate} offers ${p.bedrooms > 0 ? '${p.bedrooms}-bedroom' : ''} ${p.type.toLowerCase()} living '
          'with premium finishes and HD Homes transparency from inquiry to handover.',
      architecturalConcept:
          'Contemporary Nigerian architecture with optimized natural light, cross-ventilation, and durable materials.',
      lifestyleBenefits: p.lifestyleTags,
      targetBuyers: p.purpose == PropertyPurpose.invest
          ? 'Investors seeking capital growth and rental income'
          : 'Families and professionals seeking quality homes',
      investmentPotential: p.roiEstimate,
      communityFeatures: [
        'Gated estate access',
        'Landscaped green areas',
        'Community security',
        'Proximity to major corridors',
      ],
      developerHighlights: [
        'HD Homes verified delivery',
        'Transparent documentation',
        'Dedicated after-sales support',
      ],
    ),
    specs: PropertySpecs(
      bedrooms: p.bedrooms,
      bathrooms: p.bathrooms,
      toilets: p.bathrooms,
      kitchens: p.bedrooms > 0 ? 1 : 0,
      parkingSpaces: p.bedrooms >= 3 ? 2 : 1,
      floorArea: p.buildingSize,
      landArea: p.landSize,
      plotSize: p.landSize,
      floors: p.bedrooms >= 4 ? 2 : 1,
      yearBuilt: p.completionStatus == CompletionStatus.readyToMove ? '2025' : '2027 (est.)',
      smartHomeFeatures: p.amenities.where((a) => a.contains('Smart')).toList(),
      powerSupply: 'Grid + backup generator provision',
      waterSupply: 'Borehole + treatment plant',
      internetConnectivity: 'Fiber-ready infrastructure',
    ),
    pricing: PropertyPricing(
      basePrice: p.priceValue,
      promotionalPrice: p.isNew ? (p.priceValue * 0.97).round() : null,
      reservationFee: (p.priceValue * 0.05).round(),
      taxesAndFees: 'Documentation & statutory fees apply',
      mortgageEligible: p.paymentOptions.contains('Mortgage'),
    ),
    paymentPlans: [
      PropertyPaymentPlan(
        name: '12-Month Plan',
        downPayment: (p.priceValue * 0.3).round(),
        monthlyInstallment: ((p.priceValue * 0.7) / 12).round(),
        durationMonths: 12,
        interestRate: 0,
      ),
      PropertyPaymentPlan(
        name: '24-Month Plan',
        downPayment: (p.priceValue * 0.2).round(),
        monthlyInstallment: ((p.priceValue * 0.8) / 24).round(),
        durationMonths: 24,
        interestRate: 10,
      ),
    ],
    investment: PropertyInvestmentDetail(
      expectedRoi: p.roiEstimate,
      rentalYield: p.rentalYield,
      capitalAppreciation: p.capitalAppreciation,
      paybackPeriod: '6–8 years',
      occupancyForecast: '85–92%',
      investmentScore: p.investmentScore,
      riskLevel: p.riskLevel,
      isInvestmentProperty:
          p.purpose == PropertyPurpose.invest || p.category == PropertyCategory.investment,
    ),
    media: PropertyMediaBundle(
      images: List.generate(5, (i) => 'gallery_${p.id}_$i'),
      videos: const ['property_tour'],
      hasVirtualTour: true,
      hasDroneFootage: true,
      brochureUrl: '#',
    ),
    floorPlans: [
      PropertyFloorPlan(
        label: 'Ground Floor',
        dimensions: 'Open plan · 180 sqm',
        downloadUrl: '#',
      ),
      PropertyFloorPlan(
        label: 'First Floor',
        dimensions: '4 bedrooms · 200 sqm',
        downloadUrl: '#',
      ),
    ],
    masterPlan: PropertyMasterPlan(
      description: 'Master-planned estate with roads, green belts, clubhouse, and phased development.',
      legend: const [
        'Available plots',
        'Reserved plots',
        'Sold plots',
        'Clubhouse',
        'Green areas',
      ],
    ),
    construction: PropertyConstructionDetail(
      progress: p.completionStatus == CompletionStatus.readyToMove
          ? 1.0
          : p.completionStatus == CompletionStatus.underConstruction
              ? 0.65
              : 0.35,
      timeline: 'Foundation → Structure → Roofing → Finishing',
      weeklyUpdate: 'Structural work progressing on schedule with quality inspections completed.',
      completionForecast: p.completionStatus == CompletionStatus.readyToMove
          ? 'Ready now'
          : 'Q4 2026',
      milestones: const [
        'Planning approved',
        'Foundation complete',
        'Structure in progress',
        'Roofing',
        'Finishing',
      ],
    ),
    documents: const [
      PropertyDocument(title: 'Property Brochure', type: 'PDF', url: '#'),
      PropertyDocument(title: 'Price List', type: 'PDF', url: '#'),
      PropertyDocument(title: 'Floor Plans', type: 'PDF', url: '#'),
      PropertyDocument(title: 'Payment Schedule', type: 'PDF', url: '#'),
      PropertyDocument(title: 'Site Plan', type: 'PDF', url: '#'),
    ],
    nearbyPlaces: const [
      NearbyPlace(
        name: 'Greenfield International School',
        category: 'School',
        distance: '1.2 km',
        travelTime: '4 min',
      ),
      NearbyPlace(
        name: 'Lekki Mall',
        category: 'Shopping',
        distance: '3.5 km',
        travelTime: '12 min',
      ),
      NearbyPlace(
        name: 'General Hospital',
        category: 'Hospital',
        distance: '2.8 km',
        travelTime: '10 min',
      ),
      NearbyPlace(
        name: 'First Bank Branch',
        category: 'Bank',
        distance: '0.8 km',
        travelTime: '3 min',
      ),
    ],
    reviews: const [
      PropertyReview(
        name: 'Chioma A.',
        role: 'Verified Buyer',
        rating: 5,
        comment: 'Exceptional build quality and transparent process from start to finish.',
        verified: true,
        type: 'buyer',
      ),
      PropertyReview(
        name: 'James O.',
        role: 'Investor',
        rating: 5,
        comment: 'Strong rental demand in this corridor. HD Homes delivered on timelines.',
        verified: true,
        type: 'investor',
      ),
    ],
    faqs: const [
      PropertyFaqItem(
        question: 'Is the title verified?',
        answer: 'Yes. All HD Homes estates include verified title documentation.',
      ),
      PropertyFaqItem(
        question: 'Are installment plans available?',
        answer: 'Multiple flexible plans are available. See pricing section or contact sales.',
      ),
      PropertyFaqItem(
        question: 'Can I inspect before purchase?',
        answer: 'Yes. Book an inspection slot online or contact our sales team.',
      ),
      PropertyFaqItem(
        question: 'What documents are required?',
        answer: 'Valid ID, proof of income, and reservation fee to secure your unit.',
      ),
    ],
    availability: PropertyAvailabilityDashboard(
      totalUnits: 48,
      availableUnits: switch (p.availability) {
        AvailabilityLevel.available => 32,
        AvailabilityLevel.limited => 12,
        AvailabilityLevel.almostSoldOut => 4,
        AvailabilityLevel.soldOut => 0,
      },
      reservedUnits: 8,
      soldUnits: switch (p.availability) {
        AvailabilityLevel.soldOut => 48,
        _ => 8,
      },
    ),
    neighborhood: NeighborhoodIntelligence(
      safetyScore: 82,
      trafficConditions: 'Moderate — peak hours 7–9 AM',
      plannedInfrastructure: 'Road expansion and BRT corridor planned',
      appreciationEstimate: p.capitalAppreciation,
      walkabilityScore: 68,
      lifestyleScore: 85,
    ),
    inspectionSlots: const [
      InspectionSlot(date: 'Sat 12 Jul', time: '10:00 AM', available: true),
      InspectionSlot(date: 'Sat 12 Jul', time: '2:00 PM', available: true),
      InspectionSlot(date: 'Sun 13 Jul', time: '11:00 AM', available: false),
      InspectionSlot(date: 'Mon 14 Jul', time: '3:00 PM', available: true),
    ],
    aiInsight: PropertyAiInsight(
      matchSummary:
          'This property aligns with your preferences for ${p.city}, ${p.type}, and ${p.purpose.name} intent.',
      investmentStrengths: [
        'Strong ${p.capitalAppreciation} appreciation corridor',
        '${p.rentalYield} rental yield potential',
        'Verified developer track record',
      ],
      lifestyleBenefits: p.lifestyleTags,
      affordabilityNote:
          'Estimated monthly from ₦${((p.priceValue * 0.7) / 24 / 1e6).toStringAsFixed(1)}M on 24-month plan',
      suggestedActions: const [
        'Book a site inspection',
        'Speak with a sales advisor',
        'Reserve this unit',
      ],
    ),
  );
}
