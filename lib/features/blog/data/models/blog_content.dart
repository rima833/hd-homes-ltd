// Blog / Knowledge Center models.

class BlogCategory {
  const BlogCategory({
    required this.id,
    required this.name,
    this.slug = '',
    this.description = '',
  });

  final String id;
  final String name;
  final String slug;
  final String description;
}

class BlogAuthor {
  const BlogAuthor({
    required this.id,
    required this.name,
    this.role = 'Editorial',
    this.bio = '',
    this.avatarUrl,
  });

  final String id;
  final String name;
  final String role;
  final String bio;
  final String? avatarUrl;
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
    this.categoryName = 'Insights',
    this.authorName = 'HD Homes Editorial',
    this.coverImageUrl,
    this.tags = const [],
    this.isFeatured = false,
  });

  final String id;
  final String slug;
  final String title;
  final String excerpt;
  final String categoryId;
  final String categoryName;
  final String authorId;
  final String authorName;
  final String? coverImageUrl;
  final DateTime publishedAt;
  final int readMinutes;
  final List<String> tags;
  final bool isFeatured;
}

class BlogArticleDetail {
  const BlogArticleDetail({
    required this.summary,
    required this.body,
    required this.tableOfContents,
    required this.author,
    required this.category,
    required this.relatedSlugs,
    this.prevSlug,
    this.nextSlug,
  });

  final BlogArticleSummary summary;
  final List<BlogContentBlock> body;
  final List<String> tableOfContents;
  final BlogAuthor author;
  final BlogCategory category;
  final List<String> relatedSlugs;
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

class BlogHubCms {
  const BlogHubCms({
    required this.heroHeadline,
    required this.heroSubheadline,
    this.primaryCtaLabel = 'Browse Articles',
    this.secondaryCtaLabel = 'Talk to an Advisor',
    this.backgroundImageUrl,
    this.backgroundVideoUrl,
  });

  final String heroHeadline;
  final String heroSubheadline;
  final String primaryCtaLabel;
  final String secondaryCtaLabel;
  final String? backgroundImageUrl;
  final String? backgroundVideoUrl;
}
