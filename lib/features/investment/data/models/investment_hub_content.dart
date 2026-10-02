class InvestmentPillar {
  const InvestmentPillar({
    required this.title,
    required this.description,
    required this.iconName,
    this.imageUrl,
  });

  final String title;
  final String description;
  final String iconName;
  final String? imageUrl;
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

class InvestmentProcessStep {
  const InvestmentProcessStep({
    required this.step,
    required this.title,
    required this.description,
    this.iconName,
  });

  final int step;
  final String title;
  final String description;
  final String? iconName;
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
    this.backgroundImageUrl,
    this.backgroundVideoUrl,
    required this.pillars,
    required this.statistics,
    required this.processSteps,
    required this.testimonials,
    required this.protectionSummary,
    required this.faqs,
  });

  final String heroHeadline;
  final String heroSubheadline;
  final String? backgroundImageUrl;
  final String? backgroundVideoUrl;
  final List<InvestmentPillar> pillars;
  final List<InvestmentStatistic> statistics;
  final List<InvestmentProcessStep> processSteps;
  final List<InvestmentTestimonial> testimonials;
  final String protectionSummary;
  final List<InvestmentFaq> faqs;
}
