import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/investment/presentation/widgets/investment_market_insight_ui.dart';
import 'package:hdhomesproject/features/investment/presentation/widgets/investment_opportunity_ui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Premium, CMS-driven Market Insights section for the investment hub.
class InvestmentMarketInsightsSection extends HookConsumerWidget {
  const InvestmentMarketInsightsSection({
    super.key,
    this.pageSlug = 'investment',
  });

  /// CMS page slug used to fetch header/title/overline/subtitle content.
  ///
  /// `/investment` uses `investment`, while `/properties` can use `properties`.
  final String pageSlug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(websiteMarketInsightsRealtimeProvider);

    final asyncInsights = ref.watch(publishedWebsiteMarketInsightsProvider);
    final statsAsync = ref.watch(publishedCompanyStatsHomeProvider);
    final page = ref
        .watch(publishedPageBySlugProvider(pageSlug))
        .valueOrNull;
    final content = page?.content ?? const <String, dynamic>{};

    final overline =
        _pick(content, const [
          'marketInsightsOverline',
          'market_insights_overline',
        ]) ??
        'MARKET';
    final title =
        _pick(content, const [
          'marketInsightsTitle',
          'market_insights_title',
        ]) ??
        'Market insights';
    final subtitle =
        _pick(content, const [
          'marketInsightsSubtitle',
          'market_insights_subtitle',
        ]) ??
        'Data-driven outlook across key Nigerian corridors.';

    final mobile = context.isMobile;
    final centered = !mobile;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final trustStats = (statsAsync.valueOrNull ?? const <CmsCompanyStat>[])
        .where((s) => s.isSummary || s.placement == 'summary')
        .take(5)
        .map(
          (s) => (
            value: '${s.value}${s.suffix}',
            label: s.label,
            icon: companyStatIcon(s.iconName),
          ),
        )
        .toList();

    return SectionWrapper(
      backgroundColor: kInvestmentHubBg,
      child: Column(
        children: [
          MarketInsightsSectionHeader(
                overline: overline,
                title: title,
                subtitle: subtitle,
                centered: centered,
              )
              .animate(target: reduceMotion ? 0 : 1)
              .fadeIn(duration: 500.ms)
              .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
          const SizedBox(height: AppSpacing.xl),
          asyncInsights.when(
            loading: () => _InsightWrap(
              mobile: mobile,
              children: const [
                MarketInsightCardSkeleton(),
                MarketInsightCardSkeleton(),
                MarketInsightCardSkeleton(),
                MarketInsightCardSkeleton(),
              ],
            ),
            error: (err, _) => MarketInsightsErrorState(
              message: '$err',
              onRetry: () {
                ref.invalidate(publishedWebsiteMarketInsightsProvider);
              },
            ),
            data: (insights) {
              if (insights.isEmpty) {
                return const MarketInsightsEmptyState();
              }
              return _InsightWrap(
                mobile: mobile,
                children: [
                  for (var index = 0; index < insights.length; index++)
                    _animatedCard(
                      MarketInsightCard(
                        insight: insights[index],
                        animationDelay: Duration(milliseconds: 80 * index),
                      ),
                      index: index,
                      reduceMotion: reduceMotion,
                    ),
                ],
              );
            },
          ),
          if (trustStats.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            MarketInsightsTrustStrip(stats: trustStats, mobile: mobile)
                .animate(target: reduceMotion ? 0 : 1)
                .fadeIn(delay: 400.ms, duration: 500.ms),
          ],
        ],
      ),
    );
  }

  String? _pick(Map<String, dynamic> content, List<String> keys) {
    for (final key in keys) {
      final v = content[key];
      if (v != null && '$v'.trim().isNotEmpty) return '$v'.trim();
    }
    return null;
  }
}

Widget _animatedCard(
  Widget card, {
  required int index,
  required bool reduceMotion,
}) {
  if (reduceMotion) return card;
  return card
      .animate()
      .fadeIn(
        delay: Duration(milliseconds: 80 * index),
        duration: 450.ms,
      )
      .slideY(
        begin: 0.06,
        end: 0,
        delay: Duration(milliseconds: 80 * index),
        curve: Curves.easeOutCubic,
      );
}

class _InsightWrap extends StatelessWidget {
  const _InsightWrap({required this.mobile, required this.children});

  final bool mobile;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = mobile ? 1 : 2;
        final gap = AppSpacing.base;
        final width = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - gap) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}
