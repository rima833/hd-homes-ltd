import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/features/estates/data/models/estate_detail_content.dart';
import 'package:hdhomesproject/features/estates/data/providers/estate_listings_provider.dart';
import 'package:hdhomesproject/features/properties/data/models/marketplace_property.dart';
import 'package:hdhomesproject/features/properties/data/providers/marketplace_listings_provider.dart';

final estateDetailProvider =
    Provider.family<EstateDetailContent?, String>((ref, slug) {
  final estates = ref.watch(estateListingsProvider);
  final summary = estates.cast<EstateSummary?>().firstWhere(
        (e) => e?.slug == slug,
        orElse: () => null,
      );
  if (summary == null) return null;

  final allProperties = ref.watch(marketplaceListingsProvider);
  final estateProperties =
      allProperties.where((p) => p.estate == summary.name).toList();
  final related = estates.where((e) => e.slug != slug).take(3).map((e) => e.slug).toList();

  return _buildDetail(summary, estateProperties, related);
});

final estatePropertiesProvider =
    Provider.family<List<MarketplaceProperty>, String>((ref, slug) {
  final detail = ref.watch(estateDetailProvider(slug));
  if (detail == null) return [];
  final all = ref.watch(marketplaceListingsProvider);
  return all
      .where((p) => detail.availablePropertyIds.contains(p.id))
      .toList();
});

final relatedEstatesProvider =
    Provider.family<List<EstateSummary>, String>((ref, slug) {
  final detail = ref.watch(estateDetailProvider(slug));
  if (detail == null) return [];
  final all = ref.watch(estateListingsProvider);
  return all.where((e) => detail.relatedSlugs.contains(e.slug)).toList();
});

EstateDetailContent _buildDetail(
  EstateSummary s,
  List<MarketplaceProperty> properties,
  List<String> relatedSlugs,
) {
  final propertyIds = properties.map((p) => p.id).toList();
  final available = properties.where((p) => p.status == 'Available').length;
  final reserved = properties.where((p) => p.status == 'Reserved').length;
  final sold = properties.length - available - reserved;

  return EstateDetailContent(
    summary: s,
    availablePropertyIds: propertyIds,
    relatedSlugs: relatedSlugs,
    overview: EstateOverview(
      description:
          '${s.name} is a flagship HD Homes development spanning ${s.estateSize} in ${s.location}. '
          'Designed as a self-sufficient community, it combines residential excellence with commercial convenience, '
          'world-class amenities, and transparent investment opportunities.',
      vision:
          'To create a sustainable, smart, and family-centric community that sets a new benchmark for Nigerian estate living.',
      designPhilosophy:
          'Human-centred urban planning with wide boulevards, green corridors, mixed-use zones, and climate-responsive architecture.',
      developerInfo:
          'Developed by HD Homes Ltd — a trusted Nigerian property developer with verified titles, phased delivery, and dedicated after-sales support.',
      totalLandArea: s.estateSize,
      phaseCount: s.phaseCount,
      expectedCompletion: s.completionStatus,
      targetMarket: 'Families, professionals, diaspora buyers, and long-term investors',
    ),
    statistics: [
      EstateStatistic(label: 'Land Area', value: int.tryParse(s.estateSize.split(' ').first) ?? 42, suffix: ' ha'),
      EstateStatistic(label: 'Total Plots', value: s.propertyCount),
      EstateStatistic(label: 'Residential Units', value: (s.propertyCount * 0.85).round()),
      EstateStatistic(label: 'Commercial Units', value: (s.propertyCount * 0.15).round()),
      EstateStatistic(label: 'Green Space', value: 35, suffix: '%', isPercentage: true),
      EstateStatistic(label: 'Infrastructure', value: 82, suffix: '%', isPercentage: true),
      EstateStatistic(label: 'Available Units', value: available > 0 ? available : 48),
      EstateStatistic(label: 'Sold Units', value: sold > 0 ? sold : 120),
      if (s.status == EstateStatus.completed)
        EstateStatistic(label: 'Occupancy Rate', value: 78, suffix: '%', isPercentage: true),
    ],
    masterPlan: EstateMasterPlan(
      description:
          'Interactive master plan showing roads, amenities, zones, and plot availability. Click a plot to view property details or reserve.',
      legend: const [
        MasterPlanLegendItem(label: 'Available', colorHex: '#4CAF50'),
        MasterPlanLegendItem(label: 'Reserved', colorHex: '#FF9800'),
        MasterPlanLegendItem(label: 'Sold', colorHex: '#9E9E9E'),
        MasterPlanLegendItem(label: 'Parks', colorHex: '#2E7D32'),
        MasterPlanLegendItem(label: 'Clubhouse', colorHex: '#D4A34E'),
        MasterPlanLegendItem(label: 'Commercial', colorHex: '#1565C0'),
      ],
      plots: _generatePlots(properties),
    ),
    propertyTypeCategories: [
      EstatePropertyTypeCategory(
        name: 'Luxury Villas',
        priceRange: '${s.startingPrice} – ₦120M',
        availability: '${(available * 0.2).round()} available',
        description: 'Spacious 5–6 bedroom villas with private gardens and premium finishes.',
        iconName: 'home',
      ),
      EstatePropertyTypeCategory(
        name: 'Family Duplexes',
        priceRange: '${s.startingPrice} – ₦85M',
        availability: '${(available * 0.35).round()} available',
        description: '4-bedroom duplexes ideal for growing families.',
        iconName: 'building',
      ),
      EstatePropertyTypeCategory(
        name: 'Terrace Homes',
        priceRange: '₦35M – ₦55M',
        availability: '${(available * 0.25).round()} available',
        description: 'Efficient terrace layouts with modern open-plan living.',
        iconName: 'rows',
      ),
      EstatePropertyTypeCategory(
        name: 'Apartments',
        priceRange: '₦28M – ₦48M',
        availability: '${(available * 0.15).round()} available',
        description: 'Studio to 3-bedroom apartments with estate amenities access.',
        iconName: 'layers',
      ),
      EstatePropertyTypeCategory(
        name: 'Commercial',
        priceRange: '₦50M – ₦200M',
        availability: '12 units',
        description: 'Retail and office spaces along the estate boulevard.',
        iconName: 'store',
      ),
      EstatePropertyTypeCategory(
        name: 'Land Plots',
        priceRange: '₦15M – ₦40M',
        availability: '${(available * 0.05).round()} plots',
        description: 'Serviced plots for custom builds with HD Homes standards.',
        iconName: 'map',
      ),
    ],
    amenities: const [
      EstateAmenity(name: 'Clubhouse', description: 'Members lounge, events hall, and concierge.', available: true, iconName: 'crown'),
      EstateAmenity(name: 'Swimming Pool', description: 'Olympic-size pool with kids area.', available: true, iconName: 'waves'),
      EstateAmenity(name: 'Gym & Fitness', description: '24/7 fitness centre with personal training.', available: true, iconName: 'dumbbell'),
      EstateAmenity(name: 'Children\'s Playground', description: 'Safe, shaded play zones.', available: true, iconName: 'baby'),
      EstateAmenity(name: 'Green Parks', description: 'Landscaped parks and jogging tracks.', available: true, iconName: 'trees'),
      EstateAmenity(name: 'Sports Complex', description: 'Tennis, basketball, and football pitches.', available: true, iconName: 'trophy'),
      EstateAmenity(name: 'Shopping Center', description: 'On-estate retail and dining.', available: true, iconName: 'shopping'),
      EstateAmenity(name: 'Medical Center', description: 'Primary care clinic with pharmacy.', available: true, iconName: 'heart'),
      EstateAmenity(name: 'Schools', description: 'Partnership with leading private schools.', available: true, iconName: 'graduation'),
      EstateAmenity(name: 'Mosque / Church', description: 'Dedicated worship facilities.', available: true, iconName: 'church'),
      EstateAmenity(name: 'Smart Security', description: 'Biometric access and patrol teams.', available: true, iconName: 'shield'),
      EstateAmenity(name: 'Backup Power', description: 'Estate-wide generator and solar backup.', available: true, iconName: 'zap'),
    ],
    infrastructure: const [
      EstateInfrastructureItem(name: 'Road Network', description: 'Dual-carriageway internal roads', progress: 0.95),
      EstateInfrastructureItem(name: 'Drainage', description: 'Storm water management system', progress: 0.90),
      EstateInfrastructureItem(name: 'Electricity', description: 'Underground cabling + transformers', progress: 0.88),
      EstateInfrastructureItem(name: 'Water Supply', description: 'Borehole and treatment plant', progress: 0.92),
      EstateInfrastructureItem(name: 'Internet', description: 'Fiber-to-estate backbone', progress: 0.85),
      EstateInfrastructureItem(name: 'Street Lighting', description: 'LED solar-hybrid lighting', progress: 0.80),
      EstateInfrastructureItem(name: 'Sewage System', description: 'Centralized treatment facility', progress: 0.75),
      EstateInfrastructureItem(name: 'Security Gates', description: '3 controlled access points', progress: 1.0),
      EstateInfrastructureItem(name: 'Landscaping', description: 'Boulevards and green belts', progress: 0.70),
    ],
    location: EstateLocationDetail(
      address: s.location,
      connectivity: [
        '5 min to Lekki-Epe Expressway',
        'Direct access to major arterial roads',
        'Planned BRT corridor nearby',
      ],
      travelTimes: const [
        EstateTravelTime(destination: 'International Airport', distance: '35 km', time: '45 min'),
        EstateTravelTime(destination: 'Business District', distance: '12 km', time: '20 min'),
        EstateTravelTime(destination: 'Shopping Mall', distance: '4 km', time: '8 min'),
        EstateTravelTime(destination: 'Hospital', distance: '6 km', time: '12 min'),
        EstateTravelTime(destination: 'School', distance: '2 km', time: '5 min'),
      ],
    ),
    construction: EstateConstructionDetail(
      overallProgress: s.status == EstateStatus.completed ? 1.0 : 0.78,
      timeline: '2023 — Site acquisition · 2024 — Phase 1 infrastructure · 2025 — Phase 1 handover · 2026 — Phase 2 launch',
      weeklyUpdate: 'Foundation works completed on Blocks C–F. Road asphalt laying in progress on Boulevard 2.',
      monthlyUpdate: 'Drone survey confirms 78% Phase 1 completion. Clubhouse interior fit-out commenced.',
      milestones: const [
        'Site clearing — Complete',
        'Infrastructure Phase 1 — 95%',
        'Show units — Complete',
        'Phase 1 handover — Q3 2026',
        'Phase 2 launch — Q1 2027',
      ],
      phaseCompletion: [
        const EstatePhaseProgress(phase: 'Phase 1', progress: 0.78),
        const EstatePhaseProgress(phase: 'Phase 2', progress: 0.15),
        if (s.phaseCount >= 3) const EstatePhaseProgress(phase: 'Phase 3', progress: 0.0),
      ],
      completionForecast: s.status == EstateStatus.completed ? 'Completed 2025' : 'Q4 2027 (estimated)',
    ),
    paymentPlans: [
      EstatePaymentPlan(
        name: 'Outright Purchase',
        deposit: s.startingPriceValue,
        installment: 0,
        durationMonths: 0,
        interestRate: 0,
        eligibility: 'Full payment within 30 days — 3% discount',
      ),
      EstatePaymentPlan(
        name: '12-Month Plan',
        deposit: (s.startingPriceValue * 0.3).round(),
        installment: ((s.startingPriceValue * 0.7) / 12).round(),
        durationMonths: 12,
        interestRate: 0,
        eligibility: 'Salaried professionals with verifiable income',
      ),
      EstatePaymentPlan(
        name: '24-Month Plan',
        deposit: (s.startingPriceValue * 0.2).round(),
        installment: ((s.startingPriceValue * 0.8) / 24).round(),
        durationMonths: 24,
        interestRate: 10,
        eligibility: 'First-time buyers and investors',
      ),
      EstatePaymentPlan(
        name: '36-Month Plan',
        deposit: (s.startingPriceValue * 0.15).round(),
        installment: ((s.startingPriceValue * 0.85) / 36).round(),
        durationMonths: 36,
        interestRate: 12,
        eligibility: 'Extended payment for premium units',
      ),
      EstatePaymentPlan(
        name: 'Mortgage',
        deposit: (s.startingPriceValue * 0.2).round(),
        installment: ((s.startingPriceValue * 0.8) / 240).round(),
        durationMonths: 240,
        interestRate: 14,
        eligibility: 'Partner bank pre-qualification required',
      ),
    ],
    investment: EstateInvestmentDetail(
      projectedRoi: '18–24% over 5 years',
      rentalYield: '7.5–9.2% annually',
      appreciationForecast: '12–15% YoY in ${s.city}',
      demandIndex: 87,
      occupancyForecast: s.status == EstateStatus.completed ? '92% within 12 months' : '85% at handover',
      infrastructureGrowth: 'Lekki corridor expansion driving premium demand',
      governmentProjects: 'Lekki Deep Sea Port, Dangote Refinery corridor, planned metro link',
    ),
    gallery: EstateGallery(
      images: List.generate(8, (i) => 'gallery_${s.slug}_$i'),
      videos: List.generate(2, (i) => 'video_${s.slug}_$i'),
      hasDroneFootage: true,
      hasConstructionGallery: s.status != EstateStatus.completed,
      hasLifestylePhotos: true,
    ),
    virtualTour: const EstateVirtualTour(
      hasWalkthrough: true,
      hasDroneTour: true,
      hasInteractiveMap: true,
      hasVideoNarration: true,
    ),
    nearbyAttractions: const [
      EstateNearbyAttraction(name: 'Lekki British School', category: 'School', distance: '2.1 km', travelTime: '5 min'),
      EstateNearbyAttraction(name: 'Rivers State University', category: 'University', distance: '8 km', travelTime: '15 min'),
      EstateNearbyAttraction(name: 'Eko Hospital', category: 'Hospital', distance: '6 km', travelTime: '12 min'),
      EstateNearbyAttraction(name: 'Palms Shopping Mall', category: 'Shopping', distance: '4 km', travelTime: '8 min'),
      EstateNearbyAttraction(name: 'Eko Atlantic', category: 'Business District', distance: '15 km', travelTime: '25 min'),
      EstateNearbyAttraction(name: 'Murtala Muhammed Airport', category: 'Airport', distance: '35 km', travelTime: '45 min'),
    ],
    lifestyle: EstateLifestyle(
      headline: 'Life at ${s.name}',
      story:
          'Wake up to landscaped boulevards, walk your children to school within the estate, '
          'and unwind at the clubhouse — all within a secure, smart community designed for modern Nigerian families.',
      features: const [
        'Family-friendly neighbourhoods with low traffic zones',
        'Weekend farmers markets and community events',
        '24/7 security with CCTV and patrol teams',
        'Smart home-ready infrastructure',
        'Fitness trails and outdoor recreation',
      ],
      sustainability: const [
        'Solar-ready rooftops',
        'Rainwater harvesting systems',
        'Waste recycling programme',
        'Native landscaping for water efficiency',
      ],
    ),
    faqs: const [
      EstateFaqItem(
        question: 'Is infrastructure completed?',
        answer: 'Phase 1 infrastructure is 95% complete including roads, power, water, and drainage. Phase 2 infrastructure is in planning.',
      ),
      EstateFaqItem(
        question: 'Are titles verified?',
        answer: 'Yes. All HD Homes estates include verified titles, survey plans, and transparent documentation.',
      ),
      EstateFaqItem(
        question: 'When will Phase 2 launch?',
        answer: 'Phase 2 is scheduled for Q1 2027, subject to Phase 1 sell-through milestones.',
      ),
      EstateFaqItem(
        question: 'What are maintenance fees?',
        answer: 'Estate service charge is approximately ₦150,000–₦350,000 annually depending on unit type, covering security, landscaping, and amenity upkeep.',
      ),
      EstateFaqItem(
        question: 'Is financing available?',
        answer: 'Yes. We offer installment plans from 12–36 months plus partner bank mortgage options.',
      ),
      EstateFaqItem(
        question: 'Can I resell my property?',
        answer: 'Yes. HD Homes supports resale through our brokerage network with right of first refusal during the construction phase.',
      ),
    ],
    liveDashboard: EstateLiveDashboard(
      availableUnits: available > 0 ? available : 48,
      reservedUnits: reserved > 0 ? reserved : 12,
      soldUnits: sold > 0 ? sold : 180,
      constructionProgress: s.status == EstateStatus.completed ? 1.0 : 0.78,
      nextMilestone: 'Phase 1 road completion — June 2026',
      nextInspectionDate: 'Every Saturday, 10:00 AM',
      weatherConditions: 'Clear · 29°C · Ideal for site visits',
      estimatedCompletion: s.status == EstateStatus.completed ? 'Completed' : 'Q4 2027',
    ),
    constructionTimeline: const [
      ConstructionTimeMachineFrame(month: 'Jan 2025', progress: 0.35, caption: 'Foundation works across Phase 1', milestone: 'Site infrastructure 60%'),
      ConstructionTimeMachineFrame(month: 'Apr 2025', progress: 0.52, caption: 'Structural works and road network', milestone: 'First show units complete'),
      ConstructionTimeMachineFrame(month: 'Jul 2025', progress: 0.65, caption: 'Roofing and external finishes', milestone: 'Clubhouse structure complete'),
      ConstructionTimeMachineFrame(month: 'Oct 2025', progress: 0.72, caption: 'Landscaping and amenity fit-out', milestone: 'Boulevard 1 asphalt laid'),
      ConstructionTimeMachineFrame(month: 'Jan 2026', progress: 0.78, caption: 'Interior finishing and MEP', milestone: 'Phase 1 at 78%'),
    ],
    communitySimulator: const EstateCommunitySimulator(
      walkingRoutes: ['Boulevard Loop — 2.4 km', 'Park Trail — 1.1 km', 'Lake Walk — 3.2 km'],
      parks: ['Central Green', 'Children\'s Garden', 'Meditation Grove'],
      schools: ['HD Homes Academy (on-estate)', 'Lekki British School (2 km)'],
      fitnessAreas: ['Olympic Pool', 'Outdoor Gym', 'Tennis Courts'],
      retailZones: ['Estate Boulevard Shops', 'Farmers Market (weekends)'],
      events: ['Family Fun Day — monthly', 'Investor Briefing — quarterly'],
      securityCoverage: '24/7 patrol · 180+ CCTV cameras · 3 access gates',
      greenSpaces: '35% green coverage · 12 parks and gardens',
    ),
    investmentIntelligence: EstateInvestmentIntelligence(
      appreciationForecast: '12–15% annual appreciation in ${s.city}',
      rentalDemand: 'High — corporate tenants and diaspora lettings',
      infrastructureImpact: 'Port, refinery, and highway expansion driving Lekki corridor growth',
      comparableEstates: const ['Eko Atlantic', 'Lekki Paradise', 'Banana Island Extension'],
      marketTrends: 'Premium residential demand up 14% YoY in Lagos satellite corridors',
      riskScore: 22,
      growthIndex: 91,
      summary:
          '${s.name} scores highly on infrastructure completion, developer track record, and location premium. '
          'Recommended for long-term capital growth with moderate risk.',
    ),
  );
}

List<MasterPlanPlot> _generatePlots(List<MarketplaceProperty> properties) {
  final plots = <MasterPlanPlot>[];
  var x = 0.05;
  var y = 0.1;

  for (var i = 0; i < properties.length.clamp(0, 8); i++) {
    final p = properties[i];
    plots.add(
      MasterPlanPlot(
        plotNumber: 'P${100 + i}',
        label: p.title,
        status: p.status,
        x: x,
        y: y,
        width: 0.18,
        height: 0.12,
        propertyId: p.id,
        price: p.price,
      ),
    );
    x += 0.22;
    if (x > 0.75) {
      x = 0.05;
      y += 0.15;
    }
  }

  plots.addAll(const [
    MasterPlanPlot(plotNumber: 'CLB', label: 'Clubhouse', status: 'Amenity', x: 0.4, y: 0.45, width: 0.12, height: 0.08),
    MasterPlanPlot(plotNumber: 'PRK', label: 'Central Park', status: 'Park', x: 0.55, y: 0.5, width: 0.2, height: 0.15),
    MasterPlanPlot(plotNumber: 'COM', label: 'Commercial Zone', status: 'Commercial', x: 0.05, y: 0.55, width: 0.25, height: 0.1),
  ]);

  return plots;
}
