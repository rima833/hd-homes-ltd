// Blog / Knowledge Center CMS models (Supabase wired in Volume 1.5).

enum BlogContentType {
  article,
  news,
  guide,
  report,
  video,
  pressRelease,
}

enum BlogCategoryGroup {
  realEstate,
  investment,
  construction,
  propertyDevelopment,
  legal,
  finance,
  lifestyle,
  companyNews,
}

extension BlogCategoryGroupLabel on BlogCategoryGroup {
  String get label => switch (this) {
        BlogCategoryGroup.realEstate => 'Real Estate',
        BlogCategoryGroup.investment => 'Investment',
        BlogCategoryGroup.construction => 'Construction',
        BlogCategoryGroup.propertyDevelopment => 'Property Development',
        BlogCategoryGroup.legal => 'Legal',
        BlogCategoryGroup.finance => 'Finance',
        BlogCategoryGroup.lifestyle => 'Lifestyle',
        BlogCategoryGroup.companyNews => 'Company News',
      };

  String get slug => switch (this) {
        BlogCategoryGroup.realEstate => 'real-estate',
        BlogCategoryGroup.investment => 'investment',
        BlogCategoryGroup.construction => 'construction',
        BlogCategoryGroup.propertyDevelopment => 'property-development',
        BlogCategoryGroup.legal => 'legal',
        BlogCategoryGroup.finance => 'finance',
        BlogCategoryGroup.lifestyle => 'lifestyle',
        BlogCategoryGroup.companyNews => 'company-news',
      };
}

class BlogCategory {
  const BlogCategory({
    required this.id,
    required this.group,
    required this.name,
    required this.description,
  });

  final String id;
  final BlogCategoryGroup group;
  final String name;
  final String description;
}

class BlogAuthor {
  const BlogAuthor({
    required this.id,
    required this.name,
    required this.role,
    required this.bio,
    required this.articleCount,
    required this.expertise,
    required this.verified,
    this.socialLinks = const [],
  });

  final String id;
  final String name;
  final String role;
  final String bio;
  final int articleCount;
  final List<String> expertise;
  final bool verified;
  final List<String> socialLinks;
}

class BlogArticleSummary {
  const BlogArticleSummary({
    required this.id,
    required this.slug,
    required this.title,
    required this.excerpt,
    required this.categoryId,
    required this.authorId,
    required this.publishedAt,
    required this.readMinutes,
    required this.views,
    required this.likes,
    required this.comments,
    required this.tags,
    required this.contentType,
    this.isFeatured = false,
    this.isTrending = false,
    this.isEditorsPick = false,
  });

  final String id;
  final String slug;
  final String title;
  final String excerpt;
  final String categoryId;
  final String authorId;
  final DateTime publishedAt;
  final int readMinutes;
  final int views;
  final int likes;
  final int comments;
  final List<String> tags;
  final BlogContentType contentType;
  final bool isFeatured;
  final bool isTrending;
  final bool isEditorsPick;
}

class BlogArticleDetail {
  const BlogArticleDetail({
    required this.summary,
    required this.body,
    required this.tableOfContents,
    required this.author,
    required this.category,
    required this.aiSummaries,
    required this.downloads,
    required this.relatedSlugs,
    required this.relatedPropertyIds,
    required this.relatedServiceSlugs,
    required this.faqs,
    required this.prevSlug,
    required this.nextSlug,
  });

  final BlogArticleSummary summary;
  final List<BlogContentBlock> body;
  final List<String> tableOfContents;
  final BlogAuthor author;
  final BlogCategory category;
  final BlogAiSummaries aiSummaries;
  final List<BlogDownload> downloads;
  final List<String> relatedSlugs;
  final List<String> relatedPropertyIds;
  final List<String> relatedServiceSlugs;
  final List<BlogFaqItem> faqs;
  final String? prevSlug;
  final String? nextSlug;
}

class BlogContentBlock {
  const BlogContentBlock({
    required this.type,
    required this.content,
    this.caption,
  });

  final String type;
  final String content;
  final String? caption;
}

class BlogAiSummaries {
  const BlogAiSummaries({
    required this.short30s,
    required this.medium2min,
    required this.fullDetail,
  });

  final String short30s;
  final String medium2min;
  final String fullDetail;
}

class BlogDownload {
  const BlogDownload({
    required this.title,
    required this.type,
    required this.size,
  });

  final String title;
  final String type;
  final String size;
}

class BlogFaqItem {
  const BlogFaqItem({required this.question, required this.answer});

  final String question;
  final String answer;
}

class BlogHubCms {
  const BlogHubCms({
    required this.heroHeadline,
    required this.heroSubheadline,
    required this.categories,
    required this.marketInsights,
    required this.academyTracks,
    required this.researchReports,
    required this.videos,
    required this.downloads,
    required this.authors,
    required this.events,
    required this.pressReleases,
    required this.glossary,
    required this.faqs,
    required this.popularSearches,
  });

  final String heroHeadline;
  final String heroSubheadline;
  final List<BlogCategory> categories;
  final List<MarketInsight> marketInsights;
  final List<AcademyTrack> academyTracks;
  final List<ResearchReport> researchReports;
  final List<BlogVideo> videos;
  final List<BlogDownload> downloads;
  final List<BlogAuthor> authors;
  final List<BlogEvent> events;
  final List<PressRelease> pressReleases;
  final List<GlossaryTerm> glossary;
  final List<BlogFaqItem> faqs;
  final List<String> popularSearches;
}

class MarketInsight {
  const MarketInsight({
    required this.title,
    required this.value,
    required this.change,
    required this.period,
  });

  final String title;
  final String value;
  final String change;
  final String period;
}

class AcademyTrack {
  const AcademyTrack({
    required this.level,
    required this.title,
    required this.description,
    required this.lessonCount,
    required this.articleSlugs,
  });

  final String level;
  final String title;
  final String description;
  final int lessonCount;
  final List<String> articleSlugs;
}

class ResearchReport {
  const ResearchReport({
    required this.title,
    required this.description,
    required this.publishedAt,
    required this.downloadType,
  });

  final String title;
  final String description;
  final String publishedAt;
  final String downloadType;
}

class BlogVideo {
  const BlogVideo({
    required this.title,
    required this.category,
    required this.duration,
  });

  final String title;
  final String category;
  final String duration;
}

class BlogEvent {
  const BlogEvent({
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

class PressRelease {
  const PressRelease({
    required this.title,
    required this.date,
    required this.excerpt,
    required this.slug,
  });

  final String title;
  final String date;
  final String excerpt;
  final String slug;
}

class GlossaryTerm {
  const GlossaryTerm({
    required this.term,
    required this.definition,
    required this.letter,
    required this.relatedArticleSlugs,
  });

  final String term;
  final String definition;
  final String letter;
  final List<String> relatedArticleSlugs;
}
