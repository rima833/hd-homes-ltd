import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/cms_hero_media_background.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Section 1 — Premium services hero with CMS media + CTAs.
class ServicesHeroSection extends StatelessWidget {
  const ServicesHeroSection({
    super.key,
    required this.headline,
    required this.subheadline,
    this.primaryCtaLabel = 'Explore Services',
    this.secondaryCtaLabel = 'Book Consultation',
    this.tertiaryCtaLabel = 'Request Proposal',
    this.backgroundImageUrl,
    this.backgroundVideoUrl,
    this.onExploreServices,
  });

  final String headline;
  final String subheadline;
  final String primaryCtaLabel;
  final String secondaryCtaLabel;
  final String tertiaryCtaLabel;
  final String? backgroundImageUrl;
  final String? backgroundVideoUrl;
  final VoidCallback? onExploreServices;

  @override
  Widget build(BuildContext context) {
    final mobile = context.isMobile;

    return SizedBox(
      height: mobile ? 520 : 600,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CmsHeroMediaBackground(
            imageUrl: backgroundImageUrl,
            videoUrl: backgroundVideoUrl,
            fallbackColors: [
              AppColors.charcoal,
              AppColors.gold.withValues(alpha: 0.22),
              AppColors.deepBlack,
            ],
            fallbackChild: Center(
              child: Icon(
                LucideIcons.hardHat,
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.45),
                    ),
                  ),
                  child: const Text(
                    'HD HOMES SERVICES',
                    style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.base),
                Text(
                  headline,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                ),
                const SizedBox(height: AppSpacing.base),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Text(
                    subheadline,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondaryDark,
                          height: 1.5,
                        ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Wrap(
                  spacing: AppSpacing.base,
                  runSpacing: AppSpacing.sm,
                  children: [
                    PrimaryButton(
                      label: primaryCtaLabel,
                      icon: LucideIcons.grid,
                      onPressed: onExploreServices,
                    ),
                    PrimaryButton(
                      label: secondaryCtaLabel,
                      variant: ButtonVariant.secondary,
                      icon: LucideIcons.calendar,
                      onPressed: () =>
                          context.go(RoutePaths.bookConsultation),
                    ),
                    PrimaryButton(
                      label: tertiaryCtaLabel,
                      variant: ButtonVariant.ghost,
                      icon: LucideIcons.fileText,
                      onPressed: () => context.go(RoutePaths.contact),
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
