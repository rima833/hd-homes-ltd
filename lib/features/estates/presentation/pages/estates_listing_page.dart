import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/cms_hero_media_background.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/features/estates/data/providers/estate_listings_provider.dart';
import 'package:hdhomesproject/features/estates/data/providers/estates_cms_provider.dart';
import 'package:hdhomesproject/features/estates/presentation/widgets/estate_summary_card.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Estate listings index — links to individual estate showcases.
class EstatesListingPage extends ConsumerWidget {
  const EstatesListingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estates = ref.watch(estateListingsProvider);
    final cms = ref.watch(estatesHubCmsProvider);
    final columns = context.gridColumns.clamp(1, 3);

    return Column(
      children: [
        SizedBox(
          height: context.isMobile ? 420 : 480,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CmsHeroMediaBackground(
                imageUrl: cms.backgroundImageUrl,
                videoUrl: cms.backgroundVideoUrl,
                fallbackColors: [
                  AppColors.deepBlack,
                  AppColors.charcoal,
                  AppColors.gold.withValues(alpha: 0.18),
                ],
                fallbackChild: Center(
                  child: Icon(
                    LucideIcons.building2,
                    size: 72,
                    color: AppColors.gold.withValues(alpha: 0.22),
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
                    stops: const [0.35, 1],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  context.pagePadding,
                  context.isMobile ? 100 : 120,
                  context.pagePadding,
                  AppSpacing.xxl,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cms.overline,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppColors.gold,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      cms.heroHeadline,
                      style:
                          Theme.of(context).textTheme.displaySmall?.copyWith(
                                color: AppColors.white,
                                fontWeight: FontWeight.w800,
                              ),
                    ),
                    const SizedBox(height: AppSpacing.base),
                    Text(
                      cms.heroSubheadline,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.textSecondaryDark,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '${estates.length} estates across Nigeria',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondaryDark,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SectionWrapper(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w =
                  (constraints.maxWidth - (columns - 1) * AppSpacing.base) /
                      columns;
              return Wrap(
                spacing: AppSpacing.base,
                runSpacing: AppSpacing.base,
                children: estates
                    .map(
                      (e) => SizedBox(
                        width: w,
                        child: EstateSummaryCard(estate: e),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ),
      ],
    );
  }
}
