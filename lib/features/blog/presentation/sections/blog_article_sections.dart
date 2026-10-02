import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/extensions/datetime_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/cms_hero_media_background.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/core/widgets/feedback/app_badge.dart';
import 'package:hdhomesproject/features/blog/data/models/blog_content.dart';
import 'package:hdhomesproject/features/blog/data/providers/blog_article_provider.dart';
import 'package:hdhomesproject/features/blog/presentation/widgets/article_card.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Article detail — body, related posts, prev/next.
class BlogArticleSections extends ConsumerWidget {
  const BlogArticleSections({super.key, required this.detail});

  final BlogArticleDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final related = ref.watch(relatedArticlesProvider(detail.summary.slug));

    return Column(
      children: [
        _ArticleHero(detail: detail),
        if (detail.tableOfContents.isNotEmpty)
          SectionWrapper(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth > 900;
                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 240,
                        child: _TocPanel(sections: detail.tableOfContents),
                      ),
                      const SizedBox(width: AppSpacing.xl),
                      Expanded(child: _ArticleBody(detail: detail)),
                    ],
                  );
                }
                return _ArticleBody(detail: detail);
              },
            ),
          )
        else
          SectionWrapper(child: _ArticleBody(detail: detail)),
        if (related.isNotEmpty)
          SectionWrapper(
            backgroundColor: Theme.of(context).colorScheme.surface,
            child: Column(
              children: [
                const AnimatedSectionTitle(
                  overline: 'RELATED',
                  title: 'Related articles',
                ),
                const SizedBox(height: AppSpacing.xl),
                _RelatedGrid(articles: related),
              ],
            ),
          ),
        SectionWrapper(
          child: _PrevNextNav(
            prevSlug: detail.prevSlug,
            nextSlug: detail.nextSlug,
          ),
        ),
        SectionWrapper(
          backgroundColor: AppColors.charcoal,
          child: PrimaryButton(
            label: 'Browse all articles',
            icon: LucideIcons.newspaper,
            onPressed: () => context.go(RoutePaths.blog),
          ),
        ),
      ],
    );
  }
}

class _ArticleHero extends StatelessWidget {
  const _ArticleHero({required this.detail});

  final BlogArticleDetail detail;

  @override
  Widget build(BuildContext context) {
    final s = detail.summary;

    return SizedBox(
      height: context.isMobile ? 360 : 420,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CmsHeroMediaBackground(
            imageUrl: s.coverImageUrl,
            fallbackColors: [
              AppColors.charcoal,
              AppColors.gold.withValues(alpha: 0.15),
            ],
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  AppColors.deepBlack.withValues(alpha: 0.9),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.pagePadding,
              vertical: AppSpacing.xxl,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppBadge(label: detail.category.name, variant: BadgeVariant.gold),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  s.title,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: AppSpacing.base),
                Wrap(
                  spacing: AppSpacing.base,
                  runSpacing: AppSpacing.xs,
                  children: [
                    _meta(LucideIcons.user, detail.author.name),
                    _meta(LucideIcons.calendar, s.publishedAt.toDisplayDate()),
                    _meta(LucideIcons.clock, '${s.readMinutes} min read'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _meta(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.gold),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: AppColors.textSecondaryDark)),
      ],
    );
  }
}

class _TocPanel extends StatelessWidget {
  const _TocPanel({required this.sections});

  final List<String> sections;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Contents', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.base),
            ...sections.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text('• $s', style: Theme.of(context).textTheme.bodySmall),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArticleBody extends StatelessWidget {
  const _ArticleBody({required this.detail});

  final BlogArticleDetail detail;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (detail.summary.excerpt.isNotEmpty) ...[
          Text(
            detail.summary.excerpt,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
        ...detail.body.map((block) => _ContentBlock(block: block)),
      ],
    );
  }
}

class _ContentBlock extends StatelessWidget {
  const _ContentBlock({required this.block});

  final BlogContentBlock block;

  @override
  Widget build(BuildContext context) {
    return switch (block.type) {
      'heading' => Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.lg,
            bottom: AppSpacing.base,
          ),
          child: Text(
            block.content,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
      'callout' => Container(
          margin: const EdgeInsets.symmetric(vertical: AppSpacing.base),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.1),
            borderRadius: AppRadius.cardBorder,
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (block.caption != null)
                Text(
                  block.caption!,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.gold,
                      ),
                ),
              Text(block.content),
            ],
          ),
        ),
      'quote' => Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '"${block.content}"',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
              ),
              if (block.caption != null) Text('— ${block.caption}'),
            ],
          ),
        ),
      _ => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.base),
          child: Text(block.content, style: Theme.of(context).textTheme.bodyLarge),
        ),
    };
  }
}

class _RelatedGrid extends StatelessWidget {
  const _RelatedGrid({required this.articles});

  final List<BlogArticleSummary> articles;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.base,
      runSpacing: AppSpacing.base,
      children: articles
          .map(
            (a) => SizedBox(
              width: 320,
              child: ArticleCard(article: a, compact: true),
            ),
          )
          .toList(),
    );
  }
}

class _PrevNextNav extends StatelessWidget {
  const _PrevNextNav({required this.prevSlug, required this.nextSlug});

  final String? prevSlug;
  final String? nextSlug;

  @override
  Widget build(BuildContext context) {
    if (prevSlug == null && nextSlug == null) {
      return const SizedBox.shrink();
    }
    return Row(
      children: [
        if (prevSlug != null)
          Expanded(
            child: PrimaryButton(
              label: 'Previous article',
              variant: ButtonVariant.secondary,
              icon: LucideIcons.arrowLeft,
              onPressed: () => context.go('/blog/$prevSlug'),
            ),
          ),
        if (prevSlug != null && nextSlug != null)
          const SizedBox(width: AppSpacing.base),
        if (nextSlug != null)
          Expanded(
            child: PrimaryButton(
              label: 'Next article',
              icon: LucideIcons.arrowRight,
              onPressed: () => context.go('/blog/$nextSlug'),
            ),
          ),
      ],
    );
  }
}
