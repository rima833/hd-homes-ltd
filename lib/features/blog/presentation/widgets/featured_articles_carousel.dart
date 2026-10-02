import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/scale_safe_carousel.dart';
import 'package:hdhomesproject/features/blog/data/models/blog_content.dart';
import 'package:hdhomesproject/features/blog/presentation/widgets/article_card.dart';

/// Featured stories: large center card, smaller neighbors, auto-play.
class FeaturedArticlesCarousel extends StatelessWidget {
  const FeaturedArticlesCarousel({super.key, required this.articles});

  final List<BlogArticleSummary> articles;

  @override
  Widget build(BuildContext context) {
    if (articles.isEmpty) return const SizedBox.shrink();

    final mobile = context.isMobile;
    final height = mobile ? 420.0 : 400.0;

    if (articles.length == 1) {
      return SizedBox(
        height: height,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ArticleCard(
              article: articles.first,
              compact: true,
              showFeaturedBadge: true,
            ),
          ),
        ),
      );
    }

    return ScaleSafeCarousel(
      itemCount: articles.length,
      height: height,
      viewportFraction: mobile ? 0.88 : 0.42,
      enlargeFactor: mobile ? 0.18 : 0.28,
      itemBuilder: (context, index, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: ArticleCard(
            article: articles[index],
            compact: true,
            showFeaturedBadge: true,
          ),
        );
      },
    );
  }
}
