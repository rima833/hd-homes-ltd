import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/extensions/datetime_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/page_container.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/core/widgets/feedback/app_badge.dart';
import 'package:hdhomesproject/features/blog/data/models/blog_content.dart';
import 'package:hdhomesproject/features/blog/data/providers/blog_article_provider.dart';
import 'package:hdhomesproject/features/blog/presentation/widgets/article_card.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Article detail template — Volume 2 Part 9.
class BlogArticleSections extends HookConsumerWidget {
  const BlogArticleSections({super.key, required this.detail});

  final BlogArticleDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aiTab = useState(0);
    final related = ref.watch(relatedArticlesProvider(detail.summary.slug));

    return Column(
      children: [
        _ArticleHero(detail: detail),
          SectionWrapper(
            child: PageContainer(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth > 900;
                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 240, child: _TocPanel(sections: detail.tableOfContents)),
                        const SizedBox(width: AppSpacing.xl),
                        Expanded(child: _ArticleBody(detail: detail, aiTab: aiTab)),
                      ],
                    );
                  }
                  return _ArticleBody(detail: detail, aiTab: aiTab);
                },
              ),
            ),
          ),
          SectionWrapper(
            backgroundColor: Theme.of(context).colorScheme.surface,
            child: Column(
              children: [
                const AnimatedSectionTitle(overline: 'RELATED', title: 'Related articles'),
                const SizedBox(height: AppSpacing.xl),
                _RelatedGrid(articles: related),
              ],
            ),
          ),
          SectionWrapper(
            child: _AuthorBio(author: detail.author),
          ),
          SectionWrapper(
            backgroundColor: Theme.of(context).colorScheme.surface,
            child: _PrevNextNav(
              prevSlug: detail.prevSlug,
              nextSlug: detail.nextSlug,
            ),
          ),
          SectionWrapper(
            child: Column(
              children: [
                const AnimatedSectionTitle(overline: 'COMMENTS', title: 'Join the discussion'),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Comment system with moderation ships with Supabase CMS (Volume 1.5).',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.base),
                PrimaryButton(
                  label: 'Sign in to comment',
                  icon: LucideIcons.messageCircle,
                  onPressed: () => context.go(RoutePaths.contact),
                ),
              ],
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
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.charcoal, AppColors.gold.withValues(alpha: 0.15)],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, AppColors.deepBlack.withValues(alpha: 0.9)],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.pagePadding, vertical: AppSpacing.xxl),
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
                    _meta(LucideIcons.eye, '${s.views} views'),
                  ],
                ),
                const SizedBox(height: AppSpacing.base),
                Wrap(
                  spacing: AppSpacing.xs,
                  children: s.tags.map((t) => Chip(label: Text(t))).toList(),
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

class _ArticleBody extends HookWidget {
  const _ArticleBody({required this.detail, required this.aiTab});

  final BlogArticleDetail detail;
  final ValueNotifier<int> aiTab;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AnimatedSectionTitle(
          overline: 'AI ASSISTANT',
          title: 'Summarize this article',
          alignment: TextAlign.start,
        ),
        const SizedBox(height: AppSpacing.base),
        DefaultTabController(
          length: 3,
          child: Column(
            children: [
              TabBar(
                onTap: (i) => aiTab.value = i,
                tabs: const [
                  Tab(text: '30 sec'),
                  Tab(text: '2 min'),
                  Tab(text: 'Full'),
                ],
              ),
              SizedBox(
                height: 120,
                child: TabBarView(
                  children: [
                    Text(detail.aiSummaries.short30s),
                    Text(detail.aiSummaries.medium2min),
                    Text(detail.aiSummaries.fullDetail),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        ...detail.body.map((block) => _ContentBlock(block: block)),
        if (detail.downloads.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          Text('Downloads', style: Theme.of(context).textTheme.titleMedium),
          ...detail.downloads.map(
            (d) => ListTile(
              leading: const Icon(LucideIcons.download, color: AppColors.gold),
              title: Text(d.title),
              subtitle: Text('${d.type} · ${d.size}'),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            _SocialButton(icon: LucideIcons.heart, label: 'Like'),
            _SocialButton(icon: LucideIcons.share2, label: 'Share'),
            _SocialButton(icon: LucideIcons.bookmark, label: 'Save'),
            _SocialButton(icon: LucideIcons.printer, label: 'Print'),
            _SocialButton(icon: LucideIcons.link, label: 'Copy link'),
          ],
        ),
        if (detail.faqs.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          Text('FAQs', style: Theme.of(context).textTheme.titleMedium),
          ...detail.faqs.map(
            (f) => ExpansionTile(title: Text(f.question), children: [Text(f.answer)]),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        PrimaryButton(
          label: 'Subscribe to newsletter',
          icon: LucideIcons.mail,
          onPressed: () => context.go(RoutePaths.blog),
        ),
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
                Text(block.caption!, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.gold)),
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
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontStyle: FontStyle.italic),
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

class _SocialButton extends StatelessWidget {
  const _SocialButton({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(onPressed: () {}, icon: Icon(icon, size: 16), label: Text(label));
  }
}

class _RelatedGrid extends StatelessWidget {
  const _RelatedGrid({required this.articles});

  final List<BlogArticleSummary> articles;

  @override
  Widget build(BuildContext context) {
    if (articles.isEmpty) return const Text('No related articles yet.');

    return Wrap(
      spacing: AppSpacing.base,
      runSpacing: AppSpacing.base,
      children: articles.map((a) => SizedBox(width: 320, child: ArticleCard(article: a, compact: true))).toList(),
    );
  }
}

class _AuthorBio extends StatelessWidget {
  const _AuthorBio({required this.author});

  final BlogAuthor author;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: AppColors.gold.withValues(alpha: 0.2),
              child: Text(author.name.substring(0, 1), style: const TextStyle(fontSize: 24, color: AppColors.gold)),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(author.name, style: Theme.of(context).textTheme.titleLarge),
                      if (author.verified) ...[
                        const SizedBox(width: AppSpacing.sm),
                        const AppBadge(label: 'Verified', variant: BadgeVariant.gold),
                      ],
                    ],
                  ),
                  Text(author.role),
                  const SizedBox(height: AppSpacing.sm),
                  Text(author.bio),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.xs,
                    children: author.expertise.map((e) => Chip(label: Text(e))).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrevNextNav extends StatelessWidget {
  const _PrevNextNav({required this.prevSlug, required this.nextSlug});

  final String? prevSlug;
  final String? nextSlug;

  @override
  Widget build(BuildContext context) {
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
        if (prevSlug != null && nextSlug != null) const SizedBox(width: AppSpacing.base),
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
