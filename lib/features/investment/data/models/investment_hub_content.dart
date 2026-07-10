// Investment Hub CMS models (Supabase wired in Volume 1.5).

enum InvestmentProductType {
  offPlan,
  rentalIncome,
  capitalGrowth,
  commercial,
  landBanking,
  fractional,
}

class InvestmentPillar {
  const InvestmentPillar({
    required this.title,
    required this.description,
    required this.iconName,
  });

  final String title;
  final String description;
  final String iconName;
}

class InvestmentStatistic {
  const InvestmentStatistic({
    required this.value,
    required this.label,
    this.suffix,
  });

  final String value;
  final String label;
  final String? suffix;
}

class InvestmentOpportunity {
  const InvestmentOpportunity({
    required this.id,
    required this.title,
    required this.location,
    required this.type,
    required this.roi,
    required this.duration,
    required this.risk,
    required this.minInvestment,
    required this.status,
    required this.summary,
    this.estateSlug,
    this.propertyId,
  });

  final String id;
  final String title;
  final String location;
  final InvestmentProductType type;
  final String roi;
  final String duration;
  final String risk;
  final String minInvestment;
  final String status;
  final String summary;
  final String? estateSlug;
  final String? propertyId;
}

class InvestmentProcessStep {
  const InvestmentProcessStep({
    required this.step,
    required this.title,
    required this.description,
  });

  final int step;
  final String title;
  final String description;
}

class InvestmentMarketInsight {
  const InvestmentMarketInsight({
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

class InvestmentTestimonial {
  const InvestmentTestimonial({
    required this.name,
    required this.role,
    required this.quote,
    required this.portfolio,
  });

  final String name;
  final String role;
  final String quote;
  final String portfolio;
}

class InvestmentDownload {
  const InvestmentDownload({
    required this.title,
    required this.type,
    required this.size,
  });

  final String title;
  final String type;
  final String size;
}

class InvestmentFaq {
  const InvestmentFaq({
    required this.question,
    required this.answer,
  });

  final String question;
  final String answer;
}

class InvestmentHubCms {
  const InvestmentHubCms({
    required this.heroHeadline,
    required this.heroSubheadline,
    required this.pillars,
    required this.statistics,
    required this.opportunities,
    required this.processSteps,
    required this.marketInsights,
    required this.testimonials,
    required this.protectionSummary,
    required this.downloads,
    required this.faqs,
  });

  final String heroHeadline;
  final String heroSubheadline;
  final List<InvestmentPillar> pillars;
  final List<InvestmentStatistic> statistics;
  final List<InvestmentOpportunity> opportunities;
  final List<InvestmentProcessStep> processSteps;
  final List<InvestmentMarketInsight> marketInsights;
  final List<InvestmentTestimonial> testimonials;
  final String protectionSummary;
  final List<InvestmentDownload> downloads;
  final List<InvestmentFaq> faqs;
}

extension InvestmentProductTypeLabel on InvestmentProductType {
  String get label => switch (this) {
        InvestmentProductType.offPlan => 'Off-Plan',
        InvestmentProductType.rentalIncome => 'Rental Income',
        InvestmentProductType.capitalGrowth => 'Capital Growth',
        InvestmentProductType.commercial => 'Commercial',
        InvestmentProductType.landBanking => 'Land Banking',
        InvestmentProductType.fractional => 'Fractional',
      };
}
