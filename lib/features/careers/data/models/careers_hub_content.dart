/// Careers Hub content models (CMS-backed with local fallbacks).

class CareerBenefitCard {
  const CareerBenefitCard({
    required this.title,
    required this.description,
    this.iconName = 'sparkles',
  });

  final String title;
  final String description;
  final String iconName;
}

class CareerStatItem {
  const CareerStatItem({
    required this.value,
    required this.label,
    this.iconName = 'briefcase',
  });

  final String value;
  final String label;
  final String iconName;
}

class CareerJob {
  const CareerJob({
    required this.id,
    required this.title,
    required this.department,
    required this.location,
    required this.employmentType,
    required this.summary,
    this.description = '',
    this.iconName = 'briefcase',
    this.applyUrl,
    this.featured = false,
  });

  final String id;
  final String title;
  final String department;
  final String location;
  final String employmentType;
  final String summary;
  final String description;
  final String iconName;
  final String? applyUrl;
  final bool featured;
}

class CareersHubCms {
  const CareersHubCms({
    required this.heroOverline,
    required this.heroTitleLine1,
    required this.heroTitleLine2,
    required this.heroBody,
    required this.cultureSummary,
    required this.aboutSubtitle,
    required this.stats,
    required this.benefits,
    required this.jobs,
    required this.whyWorkWithUs,
    required this.benefitPills,
    required this.openPositionsCount,
    required this.ctaPrimaryLabel,
    required this.ctaSecondaryLabel,
    required this.cvBannerText,
    required this.cvBannerCtaLabel,
    required this.cvEmail,
    this.heroImageUrl,
    this.seoTitle,
    this.seoDescription,
  });

  final String heroOverline;
  final String heroTitleLine1;
  final String heroTitleLine2;
  final String heroBody;
  final String? heroImageUrl;
  final String cultureSummary;
  final String aboutSubtitle;
  final List<CareerStatItem> stats;
  final List<CareerBenefitCard> benefits;
  final List<CareerJob> jobs;
  final List<String> whyWorkWithUs;
  final List<String> benefitPills;
  final int openPositionsCount;
  final String ctaPrimaryLabel;
  final String ctaSecondaryLabel;
  final String cvBannerText;
  final String cvBannerCtaLabel;
  final String cvEmail;
  final String? seoTitle;
  final String? seoDescription;

  /// Legacy alias used by older section widgets.
  String get heroHeadline => '$heroTitleLine1 $heroTitleLine2';
  String get heroSubheadline => heroBody;
}
