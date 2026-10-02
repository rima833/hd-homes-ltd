import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/features/blog/data/models/blog_content.dart';
import 'package:hdhomesproject/features/blog/data/providers/blog_catalog_provider.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';

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
  final categories = ref.watch(blogCategoriesProvider);
  final authors =
      ref.watch(publishedBlogAuthorsProvider).valueOrNull ?? const [];
  final allSlugs = articles.map((a) => a.slug).toList();
  final index = allSlugs.indexOf(slug);

  BlogCategory category = BlogCategory(
    id: article.categoryId,
    name: article.categoryName,
  );
  for (final item in categories) {
    if (item.id == article.categoryId) {
      category = item;
      break;
    }
  }

  var author = BlogAuthor(
    id: article.authorId,
    name: article.authorName,
    bio: 'Official editorial voice for HD Homes Ltd.',
  );
  for (final item in authors) {
    if (item.id == article.authorId) {
      author = BlogAuthor(
        id: item.id,
        name: item.displayName,
        bio: item.bio ?? author.bio,
        avatarUrl: item.avatarUrl,
      );
      break;
    }
  }

  final related = articles
      .where((a) => a.slug != slug && a.categoryId == article.categoryId)
      .take(3)
      .map((a) => a.slug)
      .toList();

  final cmsBody = ref.watch(publishedBlogsProvider).maybeWhen(
        data: (posts) {
          for (final post in posts) {
            if (post.slug == slug) return post.body;
          }
          return null;
        },
        orElse: () => null,
      );

  return BlogArticleDetail(
    summary: article,
    author: author,
    category: category,
    tableOfContents: _tocFor(cmsBody),
    body: _bodyFor(article, cmsBody),
    relatedSlugs: related,
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

List<String> _tocFor(String? cmsBody) {
  if (cmsBody != null && cmsBody.trim().isNotEmpty) {
    final headings = RegExp(r'^#{2,3}\s+(.+)$', multiLine: true)
        .allMatches(cmsBody)
        .map((m) => m.group(1)!.trim())
        .where((t) => t.isNotEmpty)
        .take(8)
        .toList();
    if (headings.isNotEmpty) return headings;
  }
  return const [];
}

List<BlogContentBlock> _bodyFor(BlogArticleSummary s, String? cmsBody) {
  final text = cmsBody?.trim();
  if (text != null && text.isNotEmpty) {
    return _blocksFromCmsBody(text);
  }
  return [
    BlogContentBlock(
      type: 'paragraph',
      content: s.excerpt.isEmpty
          ? 'This article is being prepared. Check back shortly.'
          : s.excerpt,
    ),
  ];
}

List<BlogContentBlock> _blocksFromCmsBody(String body) {
  final blocks = <BlogContentBlock>[];
  final paragraphs = body
      .split(RegExp(r'\n\s*\n'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty);

  for (final paragraph in paragraphs) {
    if (paragraph.startsWith('> ')) {
      blocks.add(
        BlogContentBlock(
          type: 'quote',
          content: paragraph.replaceFirst(RegExp(r'^>\s*'), '').trim(),
        ),
      );
      continue;
    }
    if (paragraph.startsWith('## ') || paragraph.startsWith('### ')) {
      blocks.add(
        BlogContentBlock(
          type: 'heading',
          content: paragraph.replaceFirst(RegExp(r'^#{2,3}\s*'), '').trim(),
        ),
      );
      continue;
    }
    blocks.add(BlogContentBlock(type: 'paragraph', content: paragraph));
  }

  if (blocks.isEmpty) {
    blocks.add(BlogContentBlock(type: 'paragraph', content: body));
  }
  return blocks;
}
