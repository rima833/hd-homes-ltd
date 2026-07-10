// CMS-backed homepage content models (Supabase/CMS wired in Volume 1.5 Part 5).

class HomeCmsContent {
  const HomeCmsContent({
    required this.hero,
    required this.stats,
    required this.about,
    required this.whyChoose,
    required this.lifestyles,
    required this.estates,
    required this.properties,
    required this.investments,
    required this.constructionProjects,
    required this.testimonials,
    required this.partners,
    required this.awards,
    required this.blogPosts,
    required this.marketInsights,
    required this.events,
    required this.faqs,
    required this.downloads,
    required this.liveActivities,
    required this.executiveWelcome,
    required this.announcement,
  });

  final HomeHeroContent hero;
  final List<HomeStatItem> stats;
  final HomeAboutContent about;
  final List<HomeWhyChooseItem> whyChoose;
  final List<HomeLifestyleItem> lifestyles;
  final List<HomeEstateItem> estates;
  final List<HomePropertyItem> properties;
  final List<HomeInvestmentItem> investments;
  final List<HomeConstructionItem> constructionProjects;
  final List<HomeTestimonialItem> testimonials;
  final List<HomePartnerItem> partners;
  final List<HomeAwardItem> awards;
  final List<HomeBlogItem> blogPosts;
  final List<HomeMarketInsightItem> marketInsights;
  final List<HomeEventItem> events;
  final List<HomeFaqItem> faqs;
  final List<HomeDownloadItem> downloads;
  final List<HomeLiveActivityItem> liveActivities;
  final HomeExecutiveWelcome executiveWelcome;
  final String announcement;
}

class HomeHeroContent {
  const HomeHeroContent({
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

class HomeStatItem {
  const HomeStatItem({required this.value, required this.label, this.suffix});

  final int value;
  final String label;
  final String? suffix;
}

class HomeAboutContent {
  const HomeAboutContent({
    required this.title,
    required this.story,
    required this.mission,
    required this.vision,
    required this.values,
    required this.highlights,
    required this.ctaLabel,
    required this.ctaPath,
  });

  final String title;
  final String story;
  final String mission;
  final String vision;
  final List<String> values;
  final List<String> highlights;
  final String ctaLabel;
  final String ctaPath;
}

class HomeWhyChooseItem {
  const HomeWhyChooseItem({
    required this.title,
    required this.description,
    required this.iconName,
  });

  final String title;
  final String description;
  final String iconName;
}

class HomeLifestyleItem {
  const HomeLifestyleItem({
    required this.label,
    required this.description,
    required this.route,
  });

  final String label;
  final String description;
  final String route;
}

class HomeEstateItem {
  const HomeEstateItem({
    required this.id,
    required this.name,
    required this.location,
    required this.propertyCount,
    required this.priceFrom,
    required this.status,
    required this.imageUrl,
    required this.route,
  });

  final String id;
  final String name;
  final String location;
  final int propertyCount;
  final String priceFrom;
  final String status;
  final String? imageUrl;
  final String route;
}

class HomePropertyItem {
  const HomePropertyItem({
    required this.id,
    required this.title,
    required this.price,
    required this.location,
    required this.bedrooms,
    required this.bathrooms,
    required this.landSize,
    required this.type,
    required this.status,
    required this.imageUrl,
    required this.route,
  });

  final String id;
  final String title;
  final String price;
  final String location;
  final int bedrooms;
  final int bathrooms;
  final String landSize;
  final String type;
  final String status;
  final String? imageUrl;
  final String route;
}

class HomeInvestmentItem {
  const HomeInvestmentItem({
    required this.title,
    required this.roi,
    required this.type,
    required this.duration,
    required this.risk,
    required this.growth,
    required this.route,
  });

  final String title;
  final String roi;
  final String type;
  final String duration;
  final String risk;
  final String growth;
  final String route;
}

class HomeConstructionItem {
  const HomeConstructionItem({
    required this.name,
    required this.progress,
    required this.completionDate,
    required this.update,
    required this.route,
  });

  final String name;
  final double progress;
  final String completionDate;
  final String update;
  final String route;
}

class HomeTestimonialItem {
  const HomeTestimonialItem({
    required this.name,
    required this.role,
    required this.quote,
    required this.rating,
    required this.verified,
  });

  final String name;
  final String role;
  final String quote;
  final double rating;
  final bool verified;
}

class HomePartnerItem {
  const HomePartnerItem({required this.name, required this.category});

  final String name;
  final String category;
}

class HomeAwardItem {
  const HomeAwardItem({
    required this.title,
    required this.year,
    required this.issuer,
  });

  final String title;
  final String year;
  final String issuer;
}

class HomeBlogItem {
  const HomeBlogItem({
    required this.title,
    required this.category,
    required this.excerpt,
    required this.route,
    required this.date,
  });

  final String title;
  final String category;
  final String excerpt;
  final String route;
  final String date;
}

class HomeMarketInsightItem {
  const HomeMarketInsightItem({
    required this.title,
    required this.trend,
    required this.change,
    required this.summary,
  });

  final String title;
  final String trend;
  final String change;
  final String summary;
}

class HomeEventItem {
  const HomeEventItem({
    required this.title,
    required this.date,
    required this.location,
    required this.type,
  });

  final String title;
  final String date;
  final String location;
  final String type;
}

class HomeFaqItem {
  const HomeFaqItem({required this.question, required this.answer});

  final String question;
  final String answer;
}

class HomeDownloadItem {
  const HomeDownloadItem({
    required this.title,
    required this.fileType,
    required this.url,
  });

  final String title;
  final String fileType;
  final String url;
}

class HomeLiveActivityItem {
  const HomeLiveActivityItem({
    required this.message,
    required this.timeAgo,
    required this.type,
  });

  final String message;
  final String timeAgo;
  final String type;
}

class HomeExecutiveWelcome {
  const HomeExecutiveWelcome({
    required this.name,
    required this.title,
    required this.message,
    required this.videoUrl,
  });

  final String name;
  final String title;
  final String message;
  final String? videoUrl;
}
