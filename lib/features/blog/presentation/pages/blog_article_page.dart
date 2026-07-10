import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/website/components/breadcrumbs.dart';
import 'package:hdhomesproject/core/website/components/page_container.dart';
import 'package:hdhomesproject/core/website/seo/seo_binder.dart';
import 'package:hdhomesproject/core/website/seo/seo_config.dart';
import 'package:hdhomesproject/core/website/seo/seo_metadata.dart';
import 'package:hdhomesproject/core/website/seo/seo_resolver.dart';
import 'package:hdhomesproject/core/widgets/feedback/empty_state.dart';
import 'package:hdhomesproject/features/blog/data/providers/blog_article_provider.dart';
import 'package:hdhomesproject/features/blog/presentation/sections/blog_article_sections.dart';

/// Article detail page — Volume 2 Part 9.
class BlogArticlePage extends ConsumerWidget {
  const BlogArticlePage({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(blogArticleProvider(slug));

    if (detail == null) {
      return EmptyState(
        title: 'Article not found',
        message: 'This article may have been unpublished or moved.',
        icon: Icons.article_outlined,
        actionLabel: 'Browse Knowledge Center',
        onAction: () => context.go(RoutePaths.blog),
      );
    }

    final seo = SeoMetadata.articleDetail(
      detail.summary.title,
      detail.summary.excerpt,
      tags: detail.summary.tags,
      authorName: detail.author.name,
      publishedAt: detail.summary.publishedAt,
    ).withCanonical(SeoConfig.canonicalFor('/blog/${detail.summary.slug}'));

    return SeoBinder(
      metadata: seo,
      child: Column(
        children: [
          PageContainer(
            child: WebsiteBreadcrumbs(
              items: [
                const BreadcrumbItem(label: 'Home', path: RoutePaths.home),
                const BreadcrumbItem(label: 'Knowledge Center', path: RoutePaths.blog),
                BreadcrumbItem(label: detail.category.name),
                BreadcrumbItem(label: detail.summary.title),
              ],
            ),
          ),
          BlogArticleSections(detail: detail),
        ],
      ),
    );
  }
}
