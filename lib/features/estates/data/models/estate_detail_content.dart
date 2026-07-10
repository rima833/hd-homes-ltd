// Extended estate detail content (CMS/Supabase wired in Volume 1.5).

enum EstateStatus {
  comingSoon,
  preLaunch,
  sellingFast,
  underConstruction,
  phase1Open,
  phase2Open,
  completed,
  soldOut,
}

extension EstateStatusLabel on EstateStatus {
  String get label => switch (this) {
        EstateStatus.comingSoon => 'Coming Soon',
        EstateStatus.preLaunch => 'Pre-launch',
        EstateStatus.sellingFast => 'Selling Fast',
        EstateStatus.underConstruction => 'Under Construction',
        EstateStatus.phase1Open => 'Phase 1 Open',
        EstateStatus.phase2Open => 'Phase 2 Open',
        EstateStatus.completed => 'Completed',
        EstateStatus.soldOut => 'Sold Out',
      };
}

class EstateSummary {
  const EstateSummary({
    required this.id,
    required this.slug,
    required this.name,
    required this.location,
    required this.city,
    required this.state,
    required this.status,
    required this.startingPrice,
    required this.startingPriceValue,
    required this.propertyTypes,
    required this.estateSize,
    required this.completionStatus,
    required this.phaseCount,
    required this.propertyCount,
    required this.heroImageUrl,
    required this.heroVideoUrl,
    required this.tagline,
  });

  final String id;
  final String slug;
  final String name;
  final String location;
  final String city;
  final String state;
  final EstateStatus status;
  final String startingPrice;
  final int startingPriceValue;
  final List<String> propertyTypes;
  final String estateSize;
  final String completionStatus;
  final int phaseCount;
  final int propertyCount;
  final String? heroImageUrl;
  final String? heroVideoUrl;
  final String tagline;
}

class EstateDetailContent {
  const EstateDetailContent({
    required this.summary,
    required this.overview,
    required this.statistics,
    required this.masterPlan,
    required this.propertyTypeCategories,
    required this.amenities,
    required this.infrastructure,
    required this.location,
    required this.construction,
    required this.paymentPlans,
    required this.investment,
    required this.gallery,
    required this.virtualTour,
    required this.nearbyAttractions,
    required this.lifestyle,
    required this.faqs,
    required this.liveDashboard,
    required this.constructionTimeline,
    required this.communitySimulator,
    required this.investmentIntelligence,
    required this.relatedSlugs,
    required this.availablePropertyIds,
  });

  final EstateSummary summary;
  final EstateOverview overview;
  final List<EstateStatistic> statistics;
  final EstateMasterPlan masterPlan;
  final List<EstatePropertyTypeCategory> propertyTypeCategories;
  final List<EstateAmenity> amenities;
  final List<EstateInfrastructureItem> infrastructure;
  final EstateLocationDetail location;
  final EstateConstructionDetail construction;
  final List<EstatePaymentPlan> paymentPlans;
  final EstateInvestmentDetail investment;
  final EstateGallery gallery;
  final EstateVirtualTour virtualTour;
  final List<EstateNearbyAttraction> nearbyAttractions;
  final EstateLifestyle lifestyle;
  final List<EstateFaqItem> faqs;
  final EstateLiveDashboard liveDashboard;
  final List<ConstructionTimeMachineFrame> constructionTimeline;
  final EstateCommunitySimulator communitySimulator;
  final EstateInvestmentIntelligence investmentIntelligence;
  final List<String> relatedSlugs;
  final List<String> availablePropertyIds;
}

class EstateOverview {
  const EstateOverview({
    required this.description,
    required this.vision,
    required this.designPhilosophy,
    required this.developerInfo,
    required this.totalLandArea,
    required this.phaseCount,
    required this.expectedCompletion,
    required this.targetMarket,
  });

  final String description;
  final String vision;
  final String designPhilosophy;
  final String developerInfo;
  final String totalLandArea;
  final int phaseCount;
  final String expectedCompletion;
  final String targetMarket;
}

class EstateStatistic {
  const EstateStatistic({
    required this.label,
    required this.value,
    this.suffix,
    this.isPercentage = false,
  });

  final String label;
  final int value;
  final String? suffix;
  final bool isPercentage;
}

class EstateMasterPlan {
  const EstateMasterPlan({
    required this.description,
    required this.legend,
    required this.plots,
  });

  final String description;
  final List<MasterPlanLegendItem> legend;
  final List<MasterPlanPlot> plots;
}

class MasterPlanLegendItem {
  const MasterPlanLegendItem({required this.label, required this.colorHex});

  final String label;
  final String colorHex;
}

class MasterPlanPlot {
  const MasterPlanPlot({
    required this.plotNumber,
    required this.label,
    required this.status,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.propertyId,
    this.price,
  });

  final String plotNumber;
  final String label;
  final String status;
  final double x;
  final double y;
  final double width;
  final double height;
  final String? propertyId;
  final String? price;
}

class EstatePropertyTypeCategory {
  const EstatePropertyTypeCategory({
    required this.name,
    required this.priceRange,
    required this.availability,
    required this.description,
    required this.iconName,
  });

  final String name;
  final String priceRange;
  final String availability;
  final String description;
  final String iconName;
}

class EstateAmenity {
  const EstateAmenity({
    required this.name,
    required this.description,
    required this.available,
    required this.iconName,
  });

  final String name;
  final String description;
  final bool available;
  final String iconName;
}

class EstateInfrastructureItem {
  const EstateInfrastructureItem({
    required this.name,
    required this.description,
    required this.progress,
  });

  final String name;
  final String description;
  final double progress;
}

class EstateLocationDetail {
  const EstateLocationDetail({
    required this.address,
    required this.connectivity,
    required this.travelTimes,
  });

  final String address;
  final List<String> connectivity;
  final List<EstateTravelTime> travelTimes;
}

class EstateTravelTime {
  const EstateTravelTime({required this.destination, required this.distance, required this.time});

  final String destination;
  final String distance;
  final String time;
}

class EstateConstructionDetail {
  const EstateConstructionDetail({
    required this.overallProgress,
    required this.timeline,
    required this.weeklyUpdate,
    required this.monthlyUpdate,
    required this.milestones,
    required this.phaseCompletion,
    required this.completionForecast,
  });

  final double overallProgress;
  final String timeline;
  final String weeklyUpdate;
  final String monthlyUpdate;
  final List<String> milestones;
  final List<EstatePhaseProgress> phaseCompletion;
  final String completionForecast;
}

class EstatePhaseProgress {
  const EstatePhaseProgress({required this.phase, required this.progress});

  final String phase;
  final double progress;
}

class EstatePaymentPlan {
  const EstatePaymentPlan({
    required this.name,
    required this.deposit,
    required this.installment,
    required this.durationMonths,
    required this.interestRate,
    required this.eligibility,
  });

  final String name;
  final int deposit;
  final int installment;
  final int durationMonths;
  final double interestRate;
  final String eligibility;
}

class EstateInvestmentDetail {
  const EstateInvestmentDetail({
    required this.projectedRoi,
    required this.rentalYield,
    required this.appreciationForecast,
    required this.demandIndex,
    required this.occupancyForecast,
    required this.infrastructureGrowth,
    required this.governmentProjects,
  });

  final String projectedRoi;
  final String rentalYield;
  final String appreciationForecast;
  final int demandIndex;
  final String occupancyForecast;
  final String infrastructureGrowth;
  final String governmentProjects;
}

class EstateGallery {
  const EstateGallery({
    required this.images,
    required this.videos,
    required this.hasDroneFootage,
    required this.hasConstructionGallery,
    required this.hasLifestylePhotos,
  });

  final List<String> images;
  final List<String> videos;
  final bool hasDroneFootage;
  final bool hasConstructionGallery;
  final bool hasLifestylePhotos;
}

class EstateVirtualTour {
  const EstateVirtualTour({
    required this.hasWalkthrough,
    required this.hasDroneTour,
    required this.hasInteractiveMap,
    required this.hasVideoNarration,
  });

  final bool hasWalkthrough;
  final bool hasDroneTour;
  final bool hasInteractiveMap;
  final bool hasVideoNarration;
}

class EstateNearbyAttraction {
  const EstateNearbyAttraction({
    required this.name,
    required this.category,
    required this.distance,
    required this.travelTime,
  });

  final String name;
  final String category;
  final String distance;
  final String travelTime;
}

class EstateLifestyle {
  const EstateLifestyle({
    required this.headline,
    required this.story,
    required this.features,
    required this.sustainability,
  });

  final String headline;
  final String story;
  final List<String> features;
  final List<String> sustainability;
}

class EstateFaqItem {
  const EstateFaqItem({required this.question, required this.answer});

  final String question;
  final String answer;
}

class EstateLiveDashboard {
  const EstateLiveDashboard({
    required this.availableUnits,
    required this.reservedUnits,
    required this.soldUnits,
    required this.constructionProgress,
    required this.nextMilestone,
    required this.nextInspectionDate,
    required this.weatherConditions,
    required this.estimatedCompletion,
  });

  final int availableUnits;
  final int reservedUnits;
  final int soldUnits;
  final double constructionProgress;
  final String nextMilestone;
  final String nextInspectionDate;
  final String weatherConditions;
  final String estimatedCompletion;
}

class ConstructionTimeMachineFrame {
  const ConstructionTimeMachineFrame({
    required this.month,
    required this.progress,
    required this.caption,
    required this.milestone,
  });

  final String month;
  final double progress;
  final String caption;
  final String milestone;
}

class EstateCommunitySimulator {
  const EstateCommunitySimulator({
    required this.walkingRoutes,
    required this.parks,
    required this.schools,
    required this.fitnessAreas,
    required this.retailZones,
    required this.events,
    required this.securityCoverage,
    required this.greenSpaces,
  });

  final List<String> walkingRoutes;
  final List<String> parks;
  final List<String> schools;
  final List<String> fitnessAreas;
  final List<String> retailZones;
  final List<String> events;
  final String securityCoverage;
  final String greenSpaces;
}

class EstateInvestmentIntelligence {
  const EstateInvestmentIntelligence({
    required this.appreciationForecast,
    required this.rentalDemand,
    required this.infrastructureImpact,
    required this.comparableEstates,
    required this.marketTrends,
    required this.riskScore,
    required this.growthIndex,
    required this.summary,
  });

  final String appreciationForecast;
  final String rentalDemand;
  final String infrastructureImpact;
  final List<String> comparableEstates;
  final String marketTrends;
  final int riskScore;
  final int growthIndex;
  final String summary;
}
