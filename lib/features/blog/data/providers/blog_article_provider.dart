import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/features/blog/data/models/blog_content.dart';
import 'package:hdhomesproject/features/blog/data/providers/blog_catalog_provider.dart';

final blogArticleProvider =
    Provider.family<BlogArticleDetail?, String>((ref, slug) {
  final articles = ref.watch(blogCatalogProvider);
  BlogArticleSummary? summary;
  for (final article in articles) {
    if (article.slug == slug) {
      summary = article;
      break;
    }
  }
  if (summary == null) return null;

  final article = summary;
  final cms = ref.watch(blogHubCmsProvider);
  final authors = cms.authors;
  final categories = cms.categories;
  final allSlugs = articles.map((a) => a.slug).toList();
  final index = allSlugs.indexOf(slug);

  final author = authors.firstWhere((a) => a.id == article.authorId);
  final category = categories.firstWhere((c) => c.id == article.categoryId);

  final related = articles
      .where((a) => a.slug != slug && a.categoryId == article.categoryId)
      .take(3)
      .map((a) => a.slug)
      .toList();

  return BlogArticleDetail(
    summary: article,
    author: author,
    category: category,
    tableOfContents: _tocFor(article.slug),
    body: _bodyFor(article),
    aiSummaries: BlogAiSummaries(
      short30s: _shortSummary(article),
      medium2min: _mediumSummary(article),
      fullDetail: article.excerpt,
    ),
    downloads: cms.downloads.take(2).toList(),
    relatedSlugs: related,
    relatedPropertyIds: article.categoryId == 'cat-buying' ? ['h001'] : [],
    relatedServiceSlugs: article.categoryId == 'cat-invest'
        ? ['investment-advisory', 'property-valuation']
        : ['property-sales'],
    faqs: [
      BlogFaqItem(
        question: 'Who wrote this article?',
        answer: '${author.name} — ${author.role}. ${author.bio}',
      ),
      const BlogFaqItem(
        question: 'Can I share this article?',
        answer: 'Yes. Use the share buttons below or copy the link.',
      ),
    ],
    prevSlug: index > 0 ? allSlugs[index - 1] : null,
    nextSlug: index < allSlugs.length - 1 ? allSlugs[index + 1] : null,
  );
});

final relatedArticlesProvider =
    Provider.family<List<BlogArticleSummary>, String>((ref, slug) {
  final detail = ref.watch(blogArticleProvider(slug));
  if (detail == null) return [];
  final all = ref.watch(blogCatalogProvider);
  return all.where((a) => detail.relatedSlugs.contains(a.slug)).toList();
});

String _shortSummary(BlogArticleSummary s) =>
    '${s.title}: ${s.excerpt.split('.').first}.';

String _mediumSummary(BlogArticleSummary s) =>
    '${s.excerpt} This ${s.readMinutes}-minute read covers key points for '
    '${s.tags.join(', ')}. HD Homes publishes verified insights to help buyers and investors make confident decisions.';

List<String> _tocFor(String slug) => switch (slug) {
      'first-time-buyers-guide-nigeria-2026' => const [
          'Introduction',
          'Budget & Financing',
          'Location Selection',
          'Due Diligence',
          'Closing & Handover',
        ],
      _ => const ['Overview', 'Key Points', 'Practical Steps', 'Conclusion'],
    };

List<BlogContentBlock> _bodyFor(BlogArticleSummary s) => [
      BlogContentBlock(
        type: 'paragraph',
        content:
            '${s.excerpt} At HD Homes, we believe informed buyers make better decisions. '
            'This article draws on our team\'s experience across Lagos, Abuja, and Port Harcourt markets.',
      ),
      const BlogContentBlock(
        type: 'callout',
        content: 'Pro tip: Always verify title documents before making any payment.',
        caption: 'HD Homes Advisory',
      ),
      BlogContentBlock(
        type: 'paragraph',
        content:
            'Whether you are a first-time buyer, diaspora investor, or seasoned developer, '
            'understanding the Nigerian property landscape requires staying current with market trends, '
            'legal requirements, and financing options.',
      ),
      const BlogContentBlock(
        type: 'quote',
        content: 'Quality housing should be accessible — that starts with quality information.',
        caption: 'HD Homes Mission',
      ),
      BlogContentBlock(
        type: 'paragraph',
        content:
            'Contact our team for personalized advice, property viewings, or investment consultations. '
            'Browse related properties and services linked below.',
      ),
    ];
