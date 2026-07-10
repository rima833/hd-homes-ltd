import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/extensions/datetime_extensions.dart';
import 'package:hdhomesproject/core/extensions/number_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/feedback/app_badge.dart';
import 'package:hdhomesproject/features/blog/data/models/blog_content.dart';
import 'package:hdhomesproject/features/blog/data/providers/blog_catalog_provider.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Reusable article card for grids, carousels, and related content.
class ArticleCard extends ConsumerStatefulWidget {
  const ArticleCard({
    super.key,
    required this.article,
    this.compact = false,
    this.showFeaturedBadge = false,
    this.onTap,
  });

  final BlogArticleSummary article;
  final bool compact;
  final bool showFeaturedBadge;
  final VoidCallback? onTap;

  @override
  ConsumerState<ArticleCard> createState() => _ArticleCardState();
}

class _ArticleCardState extends ConsumerState<ArticleCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final article = widget.article;
    final cms = ref.watch(blogHubCmsProvider);
    final author = cms.authors.firstWhere((a) => a.id == article.authorId);
    final category = cms.categories.firstWhere((c) => c.id == article.categoryId);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppDurations.fast,
        transform: Matrix4.translationValues(0, _hovered ? -6 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: AppRadius.cardBorder,
          boxShadow: _hovered ? AppShadows.lg : AppShadows.md,
        ),
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: AppRadius.cardBorder,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap ?? () => context.go('/blog/${article.slug}'),
            child: SizedBox(
              height: widget.compact ? null : double.infinity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                _Thumbnail(
                  compact: widget.compact,
                  category: category.name,
                  showFeatured: widget.showFeaturedBadge && article.isFeatured,
                ),
                Padding(
                  padding: EdgeInsets.all(widget.compact ? AppSpacing.base : AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: [
                          AppBadge(label: category.name, variant: BadgeVariant.gold),
                          if (article.isEditorsPick && !widget.compact)
                            const AppBadge(label: "Editor's Pick", variant: BadgeVariant.info),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        article.title,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: widget.compact ? 2 : 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (!widget.compact) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          article.excerpt,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.base),
                      _MetaRow(
                        authorName: author.name,
                        readMinutes: article.readMinutes,
                        publishedAt: article.publishedAt,
                        views: article.views,
                        comments: article.comments,
                        likes: article.likes,
                        compact: widget.compact,
                      ),
                    ],
                  ),
                ),
              ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    required this.compact,
    required this.category,
    required this.showFeatured,
  });

  final bool compact;
  final String category;
  final bool showFeatured;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 140 : 180,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.charcoal, AppColors.gold.withValues(alpha: 0.18)],
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: Icon(
              LucideIcons.newspaper,
              size: compact ? 36 : 48,
              color: AppColors.gold.withValues(alpha: 0.5),
            ),
          ),
          if (showFeatured)
            const Positioned(
              top: AppSpacing.sm,
              left: AppSpacing.sm,
              child: AppBadge(label: 'Featured', variant: BadgeVariant.gold),
            ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.authorName,
    required this.readMinutes,
    required this.publishedAt,
    required this.views,
    required this.comments,
    required this.likes,
    required this.compact,
  });

  final String authorName;
  final int readMinutes;
  final DateTime publishedAt;
  final int views;
  final int comments;
  final int likes;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _iconMeta(LucideIcons.user, authorName, style),
        _iconMeta(LucideIcons.clock, '$readMinutes min', style),
        _iconMeta(LucideIcons.calendar, publishedAt.toDisplayDate(), style),
        if (!compact) ...[
          _iconMeta(LucideIcons.eye, views.toCompact(), style),
          _iconMeta(LucideIcons.messageCircle, '$comments', style),
          _iconMeta(LucideIcons.heart, '$likes', style),
        ],
      ],
    );
  }

  Widget _iconMeta(IconData icon, String label, TextStyle? style) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.gold),
        const SizedBox(width: 4),
        Text(label, style: style),
      ],
    );
  }
}
