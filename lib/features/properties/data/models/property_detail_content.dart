// Extended property detail content (CMS/Supabase wired in Volume 1.5).

import 'package:hdhomesproject/features/properties/data/models/marketplace_property.dart';

class PropertyDetailContent {
  const PropertyDetailContent({
    required this.listing,
    required this.overview,
    required this.specs,
    required this.pricing,
    required this.paymentPlans,
    required this.investment,
    required this.media,
    required this.floorPlans,
    required this.masterPlan,
    required this.construction,
    required this.documents,
    required this.nearbyPlaces,
    required this.reviews,
    required this.faqs,
    required this.availability,
    required this.neighborhood,
    required this.inspectionSlots,
    required this.aiInsight,
    required this.relatedIds,
    required this.lastUpdated,
  });

  final MarketplaceProperty listing;
  final PropertyOverview overview;
  final PropertySpecs specs;
  final PropertyPricing pricing;
  final List<PropertyPaymentPlan> paymentPlans;
  final PropertyInvestmentDetail investment;
  final PropertyMediaBundle media;
  final List<PropertyFloorPlan> floorPlans;
  final PropertyMasterPlan masterPlan;
  final PropertyConstructionDetail construction;
  final List<PropertyDocument> documents;
  final List<NearbyPlace> nearbyPlaces;
  final List<PropertyReview> reviews;
  final List<PropertyFaqItem> faqs;
  final PropertyAvailabilityDashboard availability;
  final NeighborhoodIntelligence neighborhood;
  final List<InspectionSlot> inspectionSlots;
  final PropertyAiInsight aiInsight;
  final List<String> relatedIds;
  final DateTime lastUpdated;
}

class PropertyOverview {
  const PropertyOverview({
    required this.summary,
    required this.architecturalConcept,
    required this.lifestyleBenefits,
    required this.targetBuyers,
    required this.investmentPotential,
    required this.communityFeatures,
    required this.developerHighlights,
  });

  final String summary;
  final String architecturalConcept;
  final List<String> lifestyleBenefits;
  final String targetBuyers;
  final String investmentPotential;
  final List<String> communityFeatures;
  final List<String> developerHighlights;
}

class PropertySpecs {
  const PropertySpecs({
    required this.bedrooms,
    required this.bathrooms,
    required this.toilets,
    required this.kitchens,
    required this.parkingSpaces,
    required this.floorArea,
    required this.landArea,
    required this.plotSize,
    required this.floors,
    required this.yearBuilt,
    required this.smartHomeFeatures,
    required this.powerSupply,
    required this.waterSupply,
    required this.internetConnectivity,
  });

  final int bedrooms;
  final int bathrooms;
  final int toilets;
  final int kitchens;
  final int parkingSpaces;
  final String floorArea;
  final String landArea;
  final String plotSize;
  final int floors;
  final String yearBuilt;
  final List<String> smartHomeFeatures;
  final String powerSupply;
  final String waterSupply;
  final String internetConnectivity;
}

class PropertyPricing {
  const PropertyPricing({
    required this.basePrice,
    required this.promotionalPrice,
    required this.reservationFee,
    required this.taxesAndFees,
    required this.mortgageEligible,
  });

  final int basePrice;
  final int? promotionalPrice;
  final int reservationFee;
  final String taxesAndFees;
  final bool mortgageEligible;
}

class PropertyPaymentPlan {
  const PropertyPaymentPlan({
    required this.name,
    required this.downPayment,
    required this.monthlyInstallment,
    required this.durationMonths,
    required this.interestRate,
  });

  final String name;
  final int downPayment;
  final int monthlyInstallment;
  final int durationMonths;
  final double interestRate;
}

class PropertyInvestmentDetail {
  const PropertyInvestmentDetail({
    required this.expectedRoi,
    required this.rentalYield,
    required this.capitalAppreciation,
    required this.paybackPeriod,
    required this.occupancyForecast,
    required this.investmentScore,
    required this.riskLevel,
    required this.isInvestmentProperty,
  });

  final String expectedRoi;
  final String rentalYield;
  final String capitalAppreciation;
  final String paybackPeriod;
  final String occupancyForecast;
  final int investmentScore;
  final String riskLevel;
  final bool isInvestmentProperty;
}

class PropertyMediaBundle {
  const PropertyMediaBundle({
    required this.images,
    required this.videos,
    required this.hasVirtualTour,
    required this.hasDroneFootage,
    required this.brochureUrl,
  });

  final List<String> images;
  final List<String> videos;
  final bool hasVirtualTour;
  final bool hasDroneFootage;
  final String? brochureUrl;
}

class PropertyFloorPlan {
  const PropertyFloorPlan({
    required this.label,
    required this.dimensions,
    required this.downloadUrl,
  });

  final String label;
  final String dimensions;
  final String downloadUrl;
}

class PropertyMasterPlan {
  const PropertyMasterPlan({
    required this.description,
    required this.legend,
  });

  final String description;
  final List<String> legend;
}

class PropertyConstructionDetail {
  const PropertyConstructionDetail({
    required this.progress,
    required this.timeline,
    required this.weeklyUpdate,
    required this.completionForecast,
    required this.milestones,
  });

  final double progress;
  final String timeline;
  final String weeklyUpdate;
  final String completionForecast;
  final List<String> milestones;
}

class PropertyDocument {
  const PropertyDocument({
    required this.title,
    required this.type,
    required this.url,
  });

  final String title;
  final String type;
  final String url;
}

class NearbyPlace {
  const NearbyPlace({
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

class PropertyReview {
  const PropertyReview({
    required this.name,
    required this.role,
    required this.rating,
    required this.comment,
    required this.verified,
    required this.type,
  });

  final String name;
  final String role;
  final double rating;
  final String comment;
  final bool verified;
  final String type;
}

class PropertyFaqItem {
  const PropertyFaqItem({required this.question, required this.answer});

  final String question;
  final String answer;
}

class PropertyAvailabilityDashboard {
  const PropertyAvailabilityDashboard({
    required this.totalUnits,
    required this.availableUnits,
    required this.reservedUnits,
    required this.soldUnits,
  });

  final int totalUnits;
  final int availableUnits;
  final int reservedUnits;
  final int soldUnits;
}

class NeighborhoodIntelligence {
  const NeighborhoodIntelligence({
    required this.safetyScore,
    required this.trafficConditions,
    required this.plannedInfrastructure,
    required this.appreciationEstimate,
    required this.walkabilityScore,
    required this.lifestyleScore,
  });

  final int safetyScore;
  final String trafficConditions;
  final String plannedInfrastructure;
  final String appreciationEstimate;
  final int walkabilityScore;
  final int lifestyleScore;
}

class InspectionSlot {
  const InspectionSlot({
    required this.date,
    required this.time,
    required this.available,
  });

  final String date;
  final String time;
  final bool available;
}

class PropertyAiInsight {
  const PropertyAiInsight({
    required this.matchSummary,
    required this.investmentStrengths,
    required this.lifestyleBenefits,
    required this.affordabilityNote,
    required this.suggestedActions,
  });

  final String matchSummary;
  final List<String> investmentStrengths;
  final List<String> lifestyleBenefits;
  final String affordabilityNote;
  final List<String> suggestedActions;
}
