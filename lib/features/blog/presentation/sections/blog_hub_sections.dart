import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/blog/data/models/blog_content.dart';
import 'package:hdhomesproject/features/blog/data/providers/blog_catalog_provider.dart';
import 'package:hdhomesproject/features/blog/presentation/widgets/article_card.dart';
import 'package:hdhomesproject/features/blog/presentation/widgets/blog_search_bar.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Section 1 — Premium Knowledge Center hero.
class BlogHeroSection extends ConsumerWidget {
  const BlogHeroSection({
    super.key,
    required this.headline,
    required this.subheadline,
    required this.searchController,
    required this.onSearchChanged,
    this.onBrowseArticles,
    this.popularSearches = const [],
  });

  final String headline;
  final String subheadline;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback? onBrowseArticles;
  final List<String> popularSearches;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: context.isMobile ? 560 : 640,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.charcoal,
                  AppColors.gold.withValues(alpha: 0.18),
                  AppColors.deepBlack,
                ],
              ),
            ),
            child: Center(
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
                colors: [Colors.transparent, AppColors.deepBlack.withValues(alpha: 0.92)],
                stops: const [0.3, 1.0],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.pagePadding, vertical: AppSpacing.xxl),
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
                    popularSearches: popularSearches,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Wrap(
                  spacing: AppSpacing.base,
                  runSpacing: AppSpacing.sm,
                  children: [
                    PrimaryButton(
                      label: 'Browse Articles',
                      icon: LucideIcons.newspaper,
                      onPressed: onBrowseArticles,
                    ),
                    PrimaryButton(
                      label: 'Market Reports',
                      variant: ButtonVariant.secondary,
                      icon: LucideIcons.trendingUp,
                      onPressed: () => onBrowseArticles?.call(),
                    ),
                    PrimaryButton(
                      label: 'Investment Guides',
                      variant: ButtonVariant.ghost,
                      icon: LucideIcons.landmark,
                      onPressed: () => context.go(RoutePaths.investment),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Hub sections 2–8 — featured, latest, categories, trending, market, academy, research, video.
class BlogHubSections extends HookConsumerWidget {
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
    final cms = ref.watch(blogHubCmsProvider);
    final allArticles = ref.watch(blogCatalogProvider);
    final featured = ref.watch(featuredArticlesProvider);
    final trending = ref.watch(trendingArticlesProvider);
    final carouselIndex = useState(0);

    final filtered = allArticles.where((a) {
      final matchesSearch = searchQuery.isEmpty ||
          a.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
          a.excerpt.toLowerCase().contains(searchQuery.toLowerCase()) ||
          a.tags.any((t) => t.toLowerCase().contains(searchQuery.toLowerCase()));
      final matchesCategory =
          selectedCategoryId == null || a.categoryId == selectedCategoryId;
      return matchesSearch && matchesCategory;
    }).toList();

    final latest = filtered.take(6).toList();
    final editorsPicks = allArticles.where((a) => a.isEditorsPick).take(4).toList();

    return Column(
      children: [
        if (featured.isNotEmpty)
          SectionWrapper(
            child: Column(
              children: [
                const AnimatedSectionTitle(
                  overline: 'FEATURED',
                  title: 'Featured stories',
                  subtitle: 'Editor-curated insights from HD Homes experts.',
                ),
                const SizedBox(height: AppSpacing.xl),
                CarouselSlider.builder(
                  itemCount: featured.length,
                  options: CarouselOptions(
                    height: context.isMobile ? 460 : 400,
                    viewportFraction: context.isMobile ? 0.92 : 0.55,
                    enlargeCenterPage: true,
                    onPageChanged: (i, _) => carouselIndex.value = i,
                  ),
                  itemBuilder: (_, index, __) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    child: ArticleCard(
                      article: featured[index],
                      compact: true,
                      showFeaturedBadge: true,
                    ),
                  ),
                ),
                Text('${carouselIndex.value + 1} / ${featured.length}'),
              ],
            ),
          ),
        SectionWrapper(
          key: articlesKey,
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'LATEST',
                title: 'Latest articles',
                subtitle: 'Fresh insights on property, investment, and development.',
              ),
              const SizedBox(height: AppSpacing.xl),
              _ArticleGrid(articles: latest),
            ],
          ),
        ),
        SectionWrapper(
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'CATEGORIES',
                title: 'Browse by topic',
              ),
              const SizedBox(height: AppSpacing.xl),
              Wrap(
                spacing: AppSpacing.base,
                runSpacing: AppSpacing.base,
                alignment: WrapAlignment.center,
                children: cms.categories.map((cat) {
                  final selected = selectedCategoryId == cat.id;
                  return FilterChip(
                    label: Text(cat.name),
                    selected: selected,
                    onSelected: (_) => onCategorySelected?.call(selected ? null : cat.id),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        SectionWrapper(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'TRENDING',
                title: 'Trending content',
                subtitle: 'Most read, editor picks, and popular this week.',
              ),
              const SizedBox(height: AppSpacing.xl),
              DefaultTabController(
                length: 3,
                child: Column(
                  children: [
                    const TabBar(
                      tabs: [
                        Tab(text: 'Most Read'),
                        Tab(text: "Editor's Picks"),
                        Tab(text: 'Popular This Week'),
                      ],
                    ),
                    SizedBox(
                      height: 420,
                      child: TabBarView(
                        children: [
                          _ArticleGrid(articles: trending.take(4).toList(), compact: true),
                          _ArticleGrid(articles: editorsPicks, compact: true),
                          _ArticleGrid(articles: trending.reversed.take(4).toList(), compact: true),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SectionWrapper(
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'MARKET INTELLIGENCE',
                title: 'Live market dashboard',
                subtitle: 'Key metrics updated from CMS — Supabase in Volume 1.5.',
              ),
              const SizedBox(height: AppSpacing.xl),
              Wrap(
                spacing: AppSpacing.base,
                runSpacing: AppSpacing.base,
                children: cms.marketInsights
                    .map((m) => _MarketCard(insight: m))
                    .toList(),
              ),
            ],
          ),
        ),
        SectionWrapper(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'LEARNING ACADEMY',
                title: 'HD Homes Learning Academy',
                subtitle: 'Structured education from beginner to advanced.',
              ),
              const SizedBox(height: AppSpacing.xl),
              Wrap(
                spacing: AppSpacing.base,
                runSpacing: AppSpacing.base,
                children: cms.academyTracks.map((t) => _AcademyCard(track: t)).toList(),
              ),
            ],
          ),
        ),
        SectionWrapper(
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'RESEARCH',
                title: 'Research library',
              ),
              const SizedBox(height: AppSpacing.xl),
              ...cms.researchReports.map((r) => _ResearchTile(report: r)),
            ],
          ),
        ),
        SectionWrapper(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'VIDEO CENTER',
                title: 'Videos & webinars',
              ),
              const SizedBox(height: AppSpacing.xl),
              Wrap(
                spacing: AppSpacing.base,
                runSpacing: AppSpacing.base,
                children: cms.videos.map((v) => _VideoCard(video: v)).toList(),
              ),
            ],
          ),
        ),
        SectionWrapper(
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'DOWNLOADS',
                title: 'Download center',
              ),
              const SizedBox(height: AppSpacing.xl),
              ...cms.downloads.map((d) => _DownloadTile(download: d)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ArticleGrid extends StatelessWidget {
  const _ArticleGrid({required this.articles, this.compact = false});

  final List<BlogArticleSummary> articles;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (articles.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Text('No articles match your search.'),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = context.isMobile ? 1 : (constraints.maxWidth > 1100 ? 3 : 2);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            mainAxisSpacing: AppSpacing.base,
            crossAxisSpacing: AppSpacing.base,
            childAspectRatio: compact ? 0.72 : 0.68,
          ),
          itemCount: articles.length,
          itemBuilder: (_, i) => ArticleCard(article: articles[i], compact: compact),
        );
      },
    );
  }
}

class _MarketCard extends StatelessWidget {
  const _MarketCard({required this.insight});

  final MarketInsight insight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(insight.title, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(
                insight.value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppColors.gold),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text('${insight.change} · ${insight.period}',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _AcademyCard extends StatelessWidget {
  const _AcademyCard({required this.track});

  final AcademyTrack track;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(track.level.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.gold)),
              const SizedBox(height: AppSpacing.sm),
              Text(track.title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(track.description, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: AppSpacing.base),
              Text('${track.lessonCount} lessons',
                  style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResearchTile extends StatelessWidget {
  const _ResearchTile({required this.report});

  final ResearchReport report;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(LucideIcons.fileText, color: AppColors.gold),
      title: Text(report.title),
      subtitle: Text('${report.description} · ${report.publishedAt}'),
      trailing: Text(report.downloadType),
    );
  }
}

class _VideoCard extends StatelessWidget {
  const _VideoCard({required this.video});

  final BlogVideo video;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 140,
              color: AppColors.charcoal,
              child: const Center(child: Icon(LucideIcons.play, color: AppColors.gold, size: 40)),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.base),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(video.category, style: Theme.of(context).textTheme.labelSmall),
                  Text(video.title, style: Theme.of(context).textTheme.titleSmall),
                  Text(video.duration, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadTile extends StatelessWidget {
  const _DownloadTile({required this.download});

  final BlogDownload download;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(LucideIcons.download, color: AppColors.gold),
      title: Text(download.title),
      subtitle: Text('${download.type} · ${download.size}'),
      trailing: IconButton(
        icon: const Icon(LucideIcons.externalLink),
        onPressed: () {},
      ),
    );
  }
}
