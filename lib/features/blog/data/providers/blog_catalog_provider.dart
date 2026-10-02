import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/blog/data/models/blog_content.dart';
import 'package:hdhomesproject/features/cms/domain/data/hub_page_cms.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';

/// Public blog catalog — published CMS posts when Supabase is configured.
/// Offline / unconfigured builds keep a small local fallback.
final blogCatalogProvider = Provider<List<BlogArticleSummary>>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) return _fallbackArticles;

  final posts = ref.watch(publishedBlogsProvider).value;
  if (posts == null || posts.isEmpty) return const [];
  final categories =
      ref.watch(publishedBlogCategoriesProvider).valueOrNull ?? const [];
  final authors =
      ref.watch(publishedBlogAuthorsProvider).valueOrNull ?? const [];
  return [
    for (final post in posts)
      _toArticleSummary(post, categories: categories, authors: authors),
  ];
});

BlogArticleSummary _toArticleSummary(
  CmsBlogPost post, {
  required List<CmsBlogCategory> categories,
  required List<CmsBlogAuthor> authors,
}) {
  CmsBlogCategory? category;
  for (final item in categories) {
    if (item.id == post.categoryId) {
      category = item;
      break;
    }
  }
  CmsBlogAuthor? author;
  for (final item in authors) {
    if (item.id == post.blogAuthorId) {
      author = item;
      break;
    }
  }
  return BlogArticleSummary(
    id: post.id,
    slug: post.slug,
    title: post.title,
    excerpt: post.excerpt ?? '',
    categoryId: post.categoryId ?? category?.id ?? '',
    categoryName: category?.name ?? 'Insights',
    authorId: post.blogAuthorId ?? author?.id ?? '',
    authorName: author?.displayName ?? 'HD Homes Editorial',
    coverImageUrl: post.coverImageUrl,
    publishedAt: post.publishedAt ?? DateTime.now(),
    readMinutes: post.readingTimeMinutes ?? 5,
    tags: const [],
    isFeatured: post.featured,
  );
}

final blogHubCmsProvider = Provider<BlogHubCms>((ref) {
  const base = _hubCms;
  if (!ref.watch(supabaseConfiguredProvider)) return base;
  final overlay = hubHeroFromPage(
    ref.watch(publishedPageBySlugProvider('blog')).valueOrNull,
  );
  return BlogHubCms(
    heroHeadline: overlay.headline ?? base.heroHeadline,
    heroSubheadline: overlay.subheadline ?? base.heroSubheadline,
    primaryCtaLabel: overlay.primaryCtaLabel ?? base.primaryCtaLabel,
    secondaryCtaLabel: overlay.secondaryCtaLabel ?? base.secondaryCtaLabel,
    backgroundImageUrl:
        overlay.backgroundImageUrl ?? base.backgroundImageUrl,
    backgroundVideoUrl:
        overlay.backgroundVideoUrl ?? base.backgroundVideoUrl,
  );
});

final blogCategoriesProvider = Provider<List<BlogCategory>>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) return _fallbackCategories;
  final rows = ref.watch(publishedBlogCategoriesProvider).value;
  if (rows == null || rows.isEmpty) return const [];
  return [
    for (final row in rows)
      BlogCategory(id: row.id, name: row.name, slug: row.slug),
  ];
});

final featuredArticlesProvider = Provider<List<BlogArticleSummary>>((ref) {
  return ref.watch(blogCatalogProvider).where((a) => a.isFeatured).toList();
});

final articlesByCategoryProvider =
    Provider.family<List<BlogArticleSummary>, String>((ref, categoryId) {
  return ref
      .watch(blogCatalogProvider)
      .where((a) => a.categoryId == categoryId)
      .toList();
});

const _fallbackCategories = [
  BlogCategory(id: 'buying-guides', name: 'Buying Guides', slug: 'buying-guides'),
  BlogCategory(id: 'investment', name: 'Investment Strategies', slug: 'investment'),
];

final _fallbackArticles = [
  BlogArticleSummary(
    id: 'b001',
    slug: 'first-time-buyers-guide-nigeria-2026',
    title: 'The Complete First-Time Buyer\'s Guide to Property in Nigeria (2026)',
    excerpt:
        'Everything you need to know before purchasing your first home — from budgeting to handover.',
    categoryId: 'buying-guides',
    categoryName: 'Buying Guides',
    authorId: 'editorial',
    authorName: 'HD Homes Editorial',
    publishedAt: DateTime(2026, 3, 15),
    readMinutes: 12,
    tags: const ['buying', 'guide'],
    isFeatured: true,
  ),
];

const _hubCms = BlogHubCms(
  heroHeadline: 'Insights That Build Better Decisions.',
  heroSubheadline:
      'Guides, market notes, and company news from the HD Homes team.',
  primaryCtaLabel: 'Browse Articles',
  secondaryCtaLabel: 'Talk to an Advisor',
  backgroundImageUrl:
      '',
);
