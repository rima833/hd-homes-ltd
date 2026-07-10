// CMS-backed About page content models (Supabase wired in Volume 1.5 Part 5).

class AboutCmsContent {
  const AboutCmsContent({
    required this.hero,
    required this.intro,
    required this.story,
    required this.vision,
    required this.mission,
    required this.values,
    required this.timeline,
    required this.leadership,
    required this.whyChoose,
    required this.services,
    required this.awards,
    required this.partners,
    required this.csr,
    required this.sustainability,
    required this.process,
    required this.stats,
    required this.offices,
    required this.careers,
    required this.testimonials,
    required this.executiveVideo,
    required this.milestoneMap,
    required this.companyProfile,
    required this.trustCenter,
    required this.cta,
  });

  final AboutHeroContent hero;
  final AboutIntroContent intro;
  final List<AboutStoryChapter> story;
  final String vision;
  final String mission;
  final List<AboutValueItem> values;
  final List<AboutTimelineItem> timeline;
  final List<AboutLeaderProfile> leadership;
  final List<AboutWhyChooseItem> whyChoose;
  final List<AboutServiceItem> services;
  final List<AboutAwardItem> awards;
  final List<AboutPartnerItem> partners;
  final AboutCsrContent csr;
  final List<AboutSustainabilityItem> sustainability;
  final List<AboutProcessStep> process;
  final List<AboutStatItem> stats;
  final List<AboutOfficeLocation> offices;
  final AboutCareersPreview careers;
  final List<AboutTestimonialItem> testimonials;
  final AboutExecutiveVideo executiveVideo;
  final List<AboutMilestoneMarker> milestoneMap;
  final AboutCompanyProfile companyProfile;
  final List<AboutTrustItem> trustCenter;
  final AboutCtaContent cta;
}

class AboutHeroContent {
  const AboutHeroContent({
    required this.headline,
    required this.subheadline,
    required this.primaryCtaLabel,
    required this.primaryCtaPath,
    required this.secondaryCtaLabel,
    required this.secondaryCtaPath,
    required this.tertiaryCtaLabel,
    required this.tertiaryCtaPath,
    this.backgroundImageUrl,
    this.backgroundVideoUrl,
  });

  final String headline;
  final String subheadline;
  final String primaryCtaLabel;
  final String primaryCtaPath;
  final String secondaryCtaLabel;
  final String secondaryCtaPath;
  final String tertiaryCtaLabel;
  final String tertiaryCtaPath;
  final String? backgroundImageUrl;
  final String? backgroundVideoUrl;
}

class AboutIntroContent {
  const AboutIntroContent({
    required this.description,
    required this.yearsOperating,
    required this.specializations,
    required this.geographicPresence,
    required this.achievements,
    required this.philosophy,
  });

  final String description;
  final int yearsOperating;
  final List<String> specializations;
  final List<String> geographicPresence;
  final List<String> achievements;
  final String philosophy;
}

class AboutStoryChapter {
  const AboutStoryChapter({
    required this.year,
    required this.title,
    required this.body,
  });

  final String year;
  final String title;
  final String body;
}

class AboutValueItem {
  const AboutValueItem({
    required this.title,
    required this.description,
    required this.iconName,
  });

  final String title;
  final String description;
  final String iconName;
}

class AboutTimelineItem {
  const AboutTimelineItem({
    required this.date,
    required this.title,
    required this.description,
    this.imageUrl,
    this.videoUrl,
  });

  final String date;
  final String title;
  final String description;
  final String? imageUrl;
  final String? videoUrl;
}

class AboutLeaderProfile {
  const AboutLeaderProfile({
    required this.name,
    required this.position,
    required this.bio,
    required this.qualifications,
    required this.yearsExperience,
    this.photoUrl,
    this.linkedinUrl,
    this.email,
  });

  final String name;
  final String position;
  final String bio;
  final List<String> qualifications;
  final int yearsExperience;
  final String? photoUrl;
  final String? linkedinUrl;
  final String? email;
}

class AboutWhyChooseItem {
  const AboutWhyChooseItem({
    required this.title,
    required this.description,
    required this.iconName,
  });

  final String title;
  final String description;
  final String iconName;
}

class AboutServiceItem {
  const AboutServiceItem({
    required this.title,
    required this.description,
    required this.route,
    required this.iconName,
  });

  final String title;
  final String description;
  final String route;
  final String iconName;
}

class AboutAwardItem {
  const AboutAwardItem({
    required this.title,
    required this.year,
    required this.description,
    required this.issuer,
    this.verificationUrl,
  });

  final String title;
  final String year;
  final String description;
  final String issuer;
  final String? verificationUrl;
}

class AboutPartnerItem {
  const AboutPartnerItem({
    required this.name,
    required this.category,
  });

  final String name;
  final String category;
}

class AboutCsrContent {
  const AboutCsrContent({
    required this.intro,
    required this.initiatives,
    required this.impactStats,
  });

  final String intro;
  final List<AboutCsrInitiative> initiatives;
  final List<AboutStatItem> impactStats;
}

class AboutCsrInitiative {
  const AboutCsrInitiative({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;
}

class AboutSustainabilityItem {
  const AboutSustainabilityItem({
    required this.title,
    required this.description,
    required this.iconName,
  });

  final String title;
  final String description;
  final String iconName;
}

class AboutProcessStep {
  const AboutProcessStep({
    required this.title,
    required this.description,
    required this.timeline,
    required this.iconName,
  });

  final String title;
  final String description;
  final String timeline;
  final String iconName;
}

class AboutStatItem {
  const AboutStatItem({
    required this.value,
    required this.label,
    this.suffix,
  });

  final int value;
  final String label;
  final String? suffix;
}

class AboutOfficeLocation {
  const AboutOfficeLocation({
    required this.name,
    required this.type,
    required this.address,
    required this.phone,
    required this.email,
    required this.hours,
    required this.mapUrl,
  });

  final String name;
  final String type;
  final String address;
  final String phone;
  final String email;
  final String hours;
  final String mapUrl;
}

class AboutCareersPreview {
  const AboutCareersPreview({
    required this.whyWorkWithUs,
    required this.culture,
    required this.benefits,
    required this.openPositions,
    required this.ctaLabel,
    required this.ctaPath,
  });

  final List<String> whyWorkWithUs;
  final String culture;
  final List<String> benefits;
  final int openPositions;
  final String ctaLabel;
  final String ctaPath;
}

class AboutTestimonialItem {
  const AboutTestimonialItem({
    required this.name,
    required this.role,
    required this.quote,
    required this.rating,
    required this.verified,
    required this.type,
  });

  final String name;
  final String role;
  final String quote;
  final double rating;
  final bool verified;
  final String type;
}

class AboutExecutiveVideo {
  const AboutExecutiveVideo({
    required this.speakerName,
    required this.speakerTitle,
    required this.message,
    this.videoUrl,
    this.thumbnailUrl,
  });

  final String speakerName;
  final String speakerTitle;
  final String message;
  final String? videoUrl;
  final String? thumbnailUrl;
}

class AboutMilestoneMarker {
  const AboutMilestoneMarker({
    required this.city,
    required this.label,
    required this.type,
    required this.lat,
    required this.lng,
  });

  final String city;
  final String label;
  final String type;
  final double lat;
  final double lng;
}

class AboutCompanyProfile {
  const AboutCompanyProfile({
    required this.title,
    required this.description,
    required this.downloadUrl,
    required this.viewUrl,
  });

  final String title;
  final String description;
  final String downloadUrl;
  final String viewUrl;
}

class AboutTrustItem {
  const AboutTrustItem({
    required this.title,
    required this.detail,
    required this.reference,
  });

  final String title;
  final String detail;
  final String reference;
}

class AboutCtaContent {
  const AboutCtaContent({
    required this.title,
    required this.subtitle,
    required this.actions,
  });

  final String title;
  final String subtitle;
  final List<AboutCtaAction> actions;
}

class AboutCtaAction {
  const AboutCtaAction({
    required this.label,
    required this.path,
    required this.isPrimary,
  });

  final String label;
  final String path;
  final bool isPrimary;
}
