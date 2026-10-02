import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/cms_hero_media_background.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/core/widgets/feedback/loading_skeleton.dart';
import 'package:hdhomesproject/features/blog/data/models/blog_content.dart';
import 'package:hdhomesproject/features/blog/data/providers/blog_catalog_provider.dart';
import 'package:hdhomesproject/features/blog/presentation/widgets/article_card.dart';
import 'package:hdhomesproject/features/blog/presentation/widgets/blog_search_bar.dart';
import 'package:hdhomesproject/features/blog/presentation/widgets/featured_articles_carousel.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Premium blog hero with CMS media, search, and CTAs.
class BlogHeroSection extends ConsumerWidget {
  const BlogHeroSection({
    super.key,
    required this.headline,
    required this.subheadline,
    required this.searchController,
    required this.onSearchChanged,
    this.primaryCtaLabel = 'Browse Articles',
    this.secondaryCtaLabel = 'Talk to an Advisor',
    this.backgroundImageUrl,
    this.backgroundVideoUrl,
    this.onBrowseArticles,
  });

  final String headline;
  final String subheadline;
  final String primaryCtaLabel;
  final String secondaryCtaLabel;
  final String? backgroundImageUrl;
  final String? backgroundVideoUrl;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback? onBrowseArticles;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: context.isMobile ? 480 : 520,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CmsHeroMediaBackground(
            imageUrl: backgroundImageUrl,
            videoUrl: backgroundVideoUrl,
            fallbackColors: [
              AppColors.charcoal,
              AppColors.gold.withValues(alpha: 0.18),
              AppColors.deepBlack,
            ],
            fallbackChild: Center(
              child: Icon(
                LucideIcons.bookOpen,
                size: 72,
                color: AppColors.gold.withValues(alpha: 0.25),
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  AppColors.deepBlack.withValues(alpha: 0.92),
                ],
                stops: const [0.3, 1.0],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.pagePadding,
              vertical: AppSpacing.xxl,
            ),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headline,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.base),
                    Text(
                      subheadline,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.textSecondaryDark,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: BlogSearchBar(
                        controller: searchController,
                        onChanged: onSearchChanged,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Wrap(
                      spacing: AppSpacing.base,
                      runSpacing: AppSpacing.sm,
                      children: [
                        PrimaryButton(
                          label: primaryCtaLabel,
                          icon: LucideIcons.newspaper,
                          onPressed: onBrowseArticles,
                        ),
                        PrimaryButton(
                          label: secondaryCtaLabel,
                          variant: ButtonVariant.secondary,
                          icon: LucideIcons.messageCircle,
                          onPressed: () => context.go(RoutePaths.contact),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Featured strip and the live article catalog with topic filters.
class BlogHubSections extends ConsumerWidget {
  const BlogHubSections({
    super.key,
    this.articlesKey,
    this.searchQuery = '',
    this.selectedCategoryId,
    this.onCategorySelected,
  });

  final GlobalKey? articlesKey;
  final String searchQuery;
  final String? selectedCategoryId;
  final ValueChanged<String?>? onCategorySelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(blogCategoriesProvider);
    final catalogAsync = ref.watch(publishedBlogsProvider);
    final allArticles = ref.watch(blogCatalogProvider);
    final featured = ref.watch(featuredArticlesProvider);

    final filtered = allArticles.where((a) {
      final q = searchQuery.trim().toLowerCase();
      final matchesSearch = q.isEmpty ||
          a.title.toLowerCase().contains(q) ||
          a.excerpt.toLowerCase().contains(q) ||
          a.categoryName.toLowerCase().contains(q) ||
          a.authorName.toLowerCase().contains(q);
      final matchesCategory =
          selectedCategoryId == null || a.categoryId == selectedCategoryId;
      return matchesSearch && matchesCategory;
    }).toList();

    return Column(
      children: [
        if (featured.isNotEmpty)
          SectionWrapper(
            child: Column(
              children: [
                const AnimatedSectionTitle(
                  overline: 'FEATURED',
                  title: 'Featured stories',
                  subtitle: 'Editor-curated insights from HD Homes.',
                ),
                const SizedBox(height: AppSpacing.xl),
                FeaturedArticlesCarousel(articles: featured),
              ],
            ),
          ),
        KeyedSubtree(
          key: articlesKey,
          child: SectionWrapper(
            backgroundColor: Theme.of(context).colorScheme.surface,
            child: Column(
              children: [
                AnimatedSectionTitle(
                  overline: 'ARTICLES',
                  title: _catalogTitle(categories, selectedCategoryId),
                  subtitle: searchQuery.trim().isEmpty
                      ? 'Published insights on property, investment, and development.'
                      : 'Results for “${searchQuery.trim()}”.',
                ),
                if (categories.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.base),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    alignment: WrapAlignment.center,
                    children: [
                      FilterChip(
                        label: Text('All (${allArticles.length})'),
                        selected: selectedCategoryId == null,
                        onSelected: (_) => onCategorySelected?.call(null),
                      ),
                      for (final cat in categories)
                        FilterChip(
                          label: Text(
                            '${cat.name} (${allArticles.where((a) => a.categoryId == cat.id).length})',
                          ),
                          selected: selectedCategoryId == cat.id,
                          onSelected: (_) => onCategorySelected?.call(
                            selectedCategoryId == cat.id ? null : cat.id,
                          ),
                        ),
                    ],
                  ),
                ],
                if (selectedCategoryId != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  ActionChip(
                    label: const Text('Clear filter'),
                    avatar: const Icon(Icons.close, size: 16),
                    onPressed: () => onCategorySelected?.call(null),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                catalogAsync.when(
                  loading: () => const _ArticleGridSkeleton(),
                  error: (err, _) => Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Text('Could not load articles. $err'),
                  ),
                  data: (_) => _ArticleGrid(articles: filtered),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

String _catalogTitle(List<BlogCategory> categories, String? selectedId) {
  if (selectedId == null) return 'Latest articles';
  for (final cat in categories) {
    if (cat.id == selectedId) return cat.name;
  }
  return 'Latest articles';
}

class _ArticleGrid extends StatelessWidget {
  const _ArticleGrid({required this.articles});

  final List<BlogArticleSummary> articles;

  @override
  Widget build(BuildContext context) {
    if (articles.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Text('No published articles match this view yet.'),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = context.isMobile
            ? 1
            : (constraints.maxWidth > 1100 ? 3 : 2);
        final gap = AppSpacing.base;
        final w = cols == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final article in articles)
              SizedBox(width: w, child: ArticleCard(article: article)),
          ],
        );
      },
    );
  }
}

class _ArticleGridSkeleton extends StatelessWidget {
  const _ArticleGridSkeleton();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.base,
      runSpacing: AppSpacing.base,
      children: const [
        SizedBox(width: 320, child: PropertyCardSkeleton()),
        SizedBox(width: 320, child: PropertyCardSkeleton()),
        SizedBox(width: 320, child: PropertyCardSkeleton()),
      ],
    );
  }
}
