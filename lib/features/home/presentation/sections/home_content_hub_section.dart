import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/features/blog/data/models/blog_content.dart';
import 'package:hdhomesproject/features/blog/data/providers/blog_catalog_provider.dart';
import 'package:hdhomesproject/features/blog/presentation/widgets/featured_articles_carousel.dart';
import 'package:hdhomesproject/features/home/data/models/home_cms_content.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Blog carousel + FAQ — homepage content band.
class HomeContentHubSection extends ConsumerWidget {
  const HomeContentHubSection({
    super.key,
    required this.blogPosts,
    required this.faqs,
  });

  final List<HomeBlogItem> blogPosts;
  final List<HomeFaqItem> faqs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featured = ref.watch(featuredArticlesProvider);
    final catalog = ref.watch(blogCatalogProvider);
    final articles = featured.isNotEmpty
        ? featured
        : catalog.isNotEmpty
            ? catalog.take(6).toList()
            : _articlesFromHomePosts(blogPosts);

    final cards = <Widget>[];

    if (articles.isNotEmpty) {
      cards.add(
        _HubCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final header = const _HubHeader(
                    overline: 'INSIGHTS',
                    title: 'Featured stories',
                  );
                  final viewAll = TextButton(
                    onPressed: () => context.go(RoutePaths.blog),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.white,
                      side: BorderSide(
                        color: AppColors.gold.withValues(alpha: 0.55),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: const StadiumBorder(),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('View all articles'),
                        SizedBox(width: 6),
                        Icon(
                          LucideIcons.arrowRight,
                          size: 16,
                          color: AppColors.gold,
                        ),
                      ],
                    ),
                  );
                  if (constraints.maxWidth < 520) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        header,
                        const SizedBox(height: 8),
                        viewAll,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(child: header),
                      viewAll,
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Editor-curated insights from HD Homes.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondaryDark,
                    ),
              ),
              const SizedBox(height: AppSpacing.xl),
              FeaturedArticlesCarousel(articles: articles),
            ],
          ),
        ),
      );
    }

    if (faqs.isNotEmpty) {
      cards.add(
        _HubCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _HubHeader(
                overline: 'FAQ',
                title: 'Frequently asked questions',
              ),
              const SizedBox(height: AppSpacing.xl),
              for (final faq in faqs)
                _FaqTile(question: faq.question, answer: faq.answer),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: () => context.go(RoutePaths.contact),
                style: TextButton.styleFrom(foregroundColor: AppColors.gold),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View All FAQs',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(width: 6),
                    Icon(LucideIcons.arrowRight, size: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (cards.isEmpty) return const SizedBox.shrink();

    return SectionWrapper(
      backgroundColor: AppColors.deepBlack,
      child: Column(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.lg),
            cards[i],
          ],
        ],
      ),
    );
  }
}

List<BlogArticleSummary> _articlesFromHomePosts(List<HomeBlogItem> posts) {
  return [
    for (var i = 0; i < posts.length; i++)
      BlogArticleSummary(
        id: 'home-blog-$i',
        slug: _slugFromRoute(posts[i].route),
        title: posts[i].title,
        excerpt: posts[i].excerpt,
        categoryId: posts[i].category,
        categoryName: posts[i].category,
        authorId: 'editorial',
        authorName: 'HD Homes Editorial',
        coverImageUrl: posts[i].coverImageUrl,
        publishedAt: DateTime.tryParse(posts[i].date) ?? DateTime.now(),
        readMinutes: 5,
        isFeatured: posts[i].featured,
      ),
  ];
}

String _slugFromRoute(String route) {
  const prefix = '/blog/';
  if (route.startsWith(prefix) && route.length > prefix.length) {
    return route.substring(prefix.length);
  }
  return route.replaceFirst(RegExp(r'^/'), '');
}

class _HubCard extends StatelessWidget {
  const _HubCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.isMobile ? AppSpacing.lg : AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.1)),
      ),
      child: child,
    );
  }
}

class _HubHeader extends StatelessWidget {
  const _HubHeader({
    required this.overline,
    required this.title,
  });

  final String overline;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          overline,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.gold,
                letterSpacing: 2.2,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          title,
          style: GoogleFonts.playfairDisplay(
            fontSize: context.isMobile ? 26 : 32,
            fontWeight: FontWeight.w700,
            color: AppColors.white,
          ),
        ),
      ],
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        collapsedIconColor: AppColors.gold,
        iconColor: AppColors.gold,
        title: Text(
          question,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w600,
              ),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Text(
                answer,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondaryDark,
                      height: 1.5,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
