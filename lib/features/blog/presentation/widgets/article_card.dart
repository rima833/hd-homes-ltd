import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/extensions/datetime_extensions.dart';
import 'package:hdhomesproject/core/media/widgets/delivery_image.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/feedback/app_badge.dart';
import 'package:hdhomesproject/features/blog/data/models/blog_content.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Reusable article card for grids, carousels, and related content.
class ArticleCard extends StatefulWidget {
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
  State<ArticleCard> createState() => _ArticleCardState();
}

class _ArticleCardState extends State<ArticleCard> {
  bool _hovered = false;
  bool _opening = false;

  void _open() {
    if (_opening) return;
    _opening = true;
    if (widget.onTap != null) {
      widget.onTap!();
      return;
    }
    GoRouter.of(context).go('/blog/${widget.article.slug}');
  }

  @override
  Widget build(BuildContext context) {
    final article = widget.article;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bounded = constraints.hasBoundedHeight &&
              constraints.maxHeight.isFinite &&
              constraints.maxHeight < double.infinity;
          final lift = !bounded && !widget.compact && _hovered;

          return AnimatedContainer(
            duration: AppDurations.fast,
            transform: Matrix4.translationValues(0, lift ? -6 : 0, 0),
            decoration: BoxDecoration(
              borderRadius: AppRadius.cardBorder,
              boxShadow: (_hovered && !bounded) ? AppShadows.lg : AppShadows.md,
            ),
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: AppRadius.cardBorder,
              clipBehavior: Clip.antiAlias,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _open,
                child: bounded
                    ? _boundedLayout(article, constraints.maxWidth)
                    : _unboundedLayout(article),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _unboundedLayout(BlogArticleSummary article) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _Thumbnail(
          compact: widget.compact,
          coverImageUrl: article.coverImageUrl,
          showFeatured: widget.showFeaturedBadge && article.isFeatured,
          fill: false,
        ),
        _Body(article: article, compact: widget.compact),
      ],
    );
  }

  Widget _boundedLayout(BlogArticleSummary article, double maxWidth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 5,
          child: _Thumbnail(
            compact: widget.compact,
            coverImageUrl: article.coverImageUrl,
            showFeatured: widget.showFeaturedBadge && article.isFeatured,
            fill: true,
          ),
        ),
        Expanded(
          flex: 6,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: maxWidth,
              child: _Body(article: article, compact: widget.compact),
            ),
          ),
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.article, required this.compact});

  final BlogArticleSummary article;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(compact ? AppSpacing.base : AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AppBadge(
            label: article.categoryName,
            variant: BadgeVariant.gold,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            article.title,
            style: Theme.of(context).textTheme.titleMedium,
            maxLines: compact ? 2 : 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (!compact) ...[
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
            authorName: article.authorName,
            readMinutes: article.readMinutes,
            publishedAt: article.publishedAt,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Read article →',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    required this.compact,
    required this.showFeatured,
    required this.fill,
    this.coverImageUrl,
  });

  final bool compact;
  final bool showFeatured;
  final bool fill;
  final String? coverImageUrl;

  @override
  Widget build(BuildContext context) {
    final media = coverImageUrl != null && coverImageUrl!.isNotEmpty
        ? MediaDeliveryImage(
            url: coverImageUrl!,
            fit: BoxFit.cover,
            placeholder: const _ThumbFallback(),
            errorWidget: const _ThumbFallback(),
          )
        : const _ThumbFallback();

    final stack = Stack(
      fit: StackFit.expand,
      children: [
        media,
        if (showFeatured)
          const Positioned(
            top: AppSpacing.sm,
            left: AppSpacing.sm,
            child: AppBadge(label: 'Featured', variant: BadgeVariant.gold),
          ),
      ],
    );

    if (fill) return stack;
    return SizedBox(
      height: compact ? 140.0 : 180.0,
      width: double.infinity,
      child: stack,
    );
  }
}

class _ThumbFallback extends StatelessWidget {
  const _ThumbFallback();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.charcoal, AppColors.gold.withValues(alpha: 0.18)],
        ),
      ),
      child: Center(
        child: Icon(
          LucideIcons.newspaper,
          size: 40,
          color: AppColors.gold.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.authorName,
    required this.readMinutes,
    required this.publishedAt,
  });

  final String authorName;
  final int readMinutes;
  final DateTime publishedAt;

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
