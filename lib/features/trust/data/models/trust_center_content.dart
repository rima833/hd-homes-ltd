// Trust Center CMS models (Supabase wired in Volume 1.5).

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

class TrustStatistic {
  const TrustStatistic({
    required this.value,
    required this.label,
    this.suffix,
  });

  final String value;
  final String label;
  final String? suffix;
}

class TrustDownload {
  const TrustDownload({
    required this.title,
    required this.type,
    required this.size,
  });

  final String title;
  final String type;
  final String size;
}

class TrustCertification {
  const TrustCertification({
    required this.title,
    required this.issuer,
    required this.certificateNumber,
    required this.issueDate,
    this.expiryDate,
    this.verificationUrl,
  });

  final String title;
  final String issuer;
  final String certificateNumber;
  final String issueDate;
  final String? expiryDate;
  final String? verificationUrl;
}

class TrustGovernanceMember {
  const TrustGovernanceMember({
    required this.name,
    required this.role,
    required this.bio,
  });

  final String name;
  final String role;
  final String bio;
}

class TrustPolicy {
  const TrustPolicy({
    required this.title,
    required this.summary,
  });

  final String title;
  final String summary;
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
    required this.version,
    required this.updatedAt,
    required this.size,
  });

  final String title;
  final String category;
  final String version;
  final String updatedAt;
  final String size;
}

class TrustComplianceItem {
  const TrustComplianceItem({
    required this.title,
    required this.status,
    required this.lastReviewed,
  });

  final String title;
  final String status;
  final String lastReviewed;
}

class TrustPartner {
  const TrustPartner({
    required this.name,
    required this.category,
    required this.description,
    required this.scope,
  });

  final String name;
  final String category;
  final String description;
  final String scope;
}

class TrustAward {
  const TrustAward({
    required this.title,
    required this.year,
    required this.issuer,
  });

  final String title;
  final String year;
  final String issuer;
}

class TrustCsrInitiative {
  const TrustCsrInitiative({
    required this.title,
    required this.category,
    required this.impact,
    required this.description,
  });

  final String title;
  final String category;
  final String impact;
  final String description;
}

class TrustEsgMetric {
  const TrustEsgMetric({
    required this.label,
    required this.value,
    required this.category,
  });

  final String label;
  final String value;
  final String category;
}

class TrustRiskItem {
  const TrustRiskItem({
    required this.title,
    required this.mitigation,
  });

  final String title;
  final String mitigation;
}

class TrustTransparencyReport {
  const TrustTransparencyReport({
    required this.title,
    required this.period,
    required this.type,
    required this.size,
  });

  final String title;
  final String period;
  final String type;
  final String size;
}

class TrustFaq {
  const TrustFaq({
    required this.category,
    required this.question,
    required this.answer,
  });

  final String category;
  final String question;
  final String answer;
}

class TrustTimelineEvent {
  const TrustTimelineEvent({
    required this.year,
    required this.title,
    required this.description,
  });

  final String year;
  final String title;
  final String description;
}

class TrustScoreBreakdown {
  const TrustScoreBreakdown({
    required this.label,
    required this.score,
    required this.maxScore,
  });

  final String label;
  final int score;
  final int maxScore;
}

class TrustDashboardMetric {
  const TrustDashboardMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}

class TrustComplianceDeadline {
  const TrustComplianceDeadline({
    required this.item,
    required this.dueDate,
    required this.status,
  });

  final String item;
  final String dueDate;
  final String status;
}

class TrustHubCms {
  const TrustHubCms({
    required this.heroHeadline,
    required this.heroSubheadline,
    required this.pillars,
    required this.statistics,
    required this.companyOverview,
    required this.vision,
    required this.mission,
    required this.coreValues,
    required this.profileDownloads,
    required this.certifications,
    required this.boardMembers,
    required this.policies,
    required this.investorProtection,
    required this.legalDocuments,
    required this.complianceItems,
    required this.partners,
    required this.awards,
    required this.csrInitiatives,
    required this.esgMetrics,
    required this.riskItems,
    required this.transparencyReports,
    required this.faqs,
    required this.timeline,
    required this.trustScore,
    required this.trustScoreBreakdown,
    required this.dashboardMetrics,
    required this.complianceDeadlines,
  });

  final String heroHeadline;
  final String heroSubheadline;
  final List<TrustPillar> pillars;
  final List<TrustStatistic> statistics;
  final String companyOverview;
  final String vision;
  final String mission;
  final List<String> coreValues;
  final List<TrustDownload> profileDownloads;
  final List<TrustCertification> certifications;
  final List<TrustGovernanceMember> boardMembers;
  final List<TrustPolicy> policies;
  final List<TrustInvestorProtectionItem> investorProtection;
  final List<TrustLegalDocument> legalDocuments;
  final List<TrustComplianceItem> complianceItems;
  final List<TrustPartner> partners;
  final List<TrustAward> awards;
  final List<TrustCsrInitiative> csrInitiatives;
  final List<TrustEsgMetric> esgMetrics;
  final List<TrustRiskItem> riskItems;
  final List<TrustTransparencyReport> transparencyReports;
  final List<TrustFaq> faqs;
  final List<TrustTimelineEvent> timeline;
  final int trustScore;
  final List<TrustScoreBreakdown> trustScoreBreakdown;
  final List<TrustDashboardMetric> dashboardMetrics;
  final List<TrustComplianceDeadline> complianceDeadlines;
}
