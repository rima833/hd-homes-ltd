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
    final listings = ref.watch(estateListingsAsyncProvider);
    final cms = ref.watch(estatesHubCmsProvider);
    final columns = context.gridColumns.clamp(1, 3);
    final estates = listings.valueOrNull ?? const [];

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
                    if (estates.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        estates.length == 1
                            ? '1 published estate'
                            : '${estates.length} published estates',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondaryDark,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        SectionWrapper(
          child: listings.when(
            loading: () => const _EstateNotice(
              title: 'Loading estates',
              message: 'Published estates will appear here in a moment.',
            ),
            error: (_, _) => const _EstateNotice(
              title: 'Estates are unavailable right now',
              message: 'Please refresh the page and try again.',
            ),
            data: (estates) => estates.isEmpty
                ? const _EstateNotice(
                    title: 'No estates published yet',
                    message:
                        'New communities will show here as soon as they are published.',
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final w = (constraints.maxWidth -
                              (columns - 1) * AppSpacing.base) /
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
        ),
      ],
    );
  }
}

class _EstateNotice extends StatelessWidget {
  const _EstateNotice({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Column(
        children: [
          Icon(
            LucideIcons.building2,
            size: 40,
            color: AppColors.gold.withValues(alpha: 0.7),
          ),
          const SizedBox(height: AppSpacing.base),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
