// Trust Center display models — live CMS data is mapped into these shapes.

class TrustPillar {
  const TrustPillar({
    required this.title,
    required this.description,
    required this.iconName,
  });

  final String title;
  final String description;
  final String iconName;
}

class TrustInvestorProtectionItem {
  const TrustInvestorProtectionItem({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;
}

class TrustLegalDocument {
  const TrustLegalDocument({
    required this.title,
    required this.category,
    this.version = '',
    this.updatedAt = '',
    this.size = '',
    this.slug,
  });

  final String title;
  final String category;
  final String version;
  final String updatedAt;
  final String size;
  final String? slug;
}

class TrustHubCms {
  const TrustHubCms({
    required this.heroHeadline,
    required this.heroSubheadline,
    this.backgroundImageUrl,
    this.backgroundVideoUrl,
    required this.pillars,
    required this.companyOverview,
    required this.investorProtection,
    required this.legalDocuments,
    this.profilePdfUrl,
    this.profileBrochureUrl,
    this.profileViewUrl,
  });

  final String heroHeadline;
  final String heroSubheadline;
  final String? backgroundImageUrl;
  final String? backgroundVideoUrl;
  final List<TrustPillar> pillars;
  final String companyOverview;
  final List<TrustInvestorProtectionItem> investorProtection;
  final List<TrustLegalDocument> legalDocuments;
  final String? profilePdfUrl;
  final String? profileBrochureUrl;
  final String? profileViewUrl;
}
