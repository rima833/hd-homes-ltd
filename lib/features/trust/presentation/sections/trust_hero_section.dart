import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/cms_hero_media_background.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Premium trust hero with live CMS copy and media.
class TrustHeroSection extends StatelessWidget {
  const TrustHeroSection({
    super.key,
    required this.headline,
    required this.subheadline,
    this.backgroundImageUrl,
    this.backgroundVideoUrl,
    this.onDownloadProfile,
    this.onViewCertifications,
    this.onInvestorInfo,
  });

  final String headline;
  final String subheadline;
  final String? backgroundImageUrl;
  final String? backgroundVideoUrl;
  final VoidCallback? onDownloadProfile;
  final VoidCallback? onViewCertifications;
  final VoidCallback? onInvestorInfo;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: context.isMobile ? 480 : 560,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CmsHeroMediaBackground(
            imageUrl: backgroundImageUrl,
            videoUrl: backgroundVideoUrl,
            fallbackColors: [
              AppColors.deepBlack,
              AppColors.charcoal,
              AppColors.gold.withValues(alpha: 0.18),
            ],
            fallbackChild: Center(
              child: Icon(
                LucideIcons.shieldCheck,
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
            padding: EdgeInsets.symmetric(
              horizontal: context.pagePadding,
              vertical: AppSpacing.xxl,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TRUST CENTER',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.gold,
                        letterSpacing: 2.4,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  headline,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: AppSpacing.base),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Text(
                    subheadline,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondaryDark,
                        ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Wrap(
                  spacing: AppSpacing.base,
                  runSpacing: AppSpacing.sm,
                  children: [
                    PrimaryButton(
                      label: 'Download Company Profile',
                      icon: LucideIcons.download,
                      onPressed: onDownloadProfile,
                    ),
                    PrimaryButton(
                      label: 'View Certifications',
                      variant: ButtonVariant.secondary,
                      icon: LucideIcons.award,
                      onPressed: onViewCertifications,
                    ),
                    PrimaryButton(
                      label: 'Investor Information',
                      variant: ButtonVariant.ghost,
                      icon: LucideIcons.trendingUp,
                      onPressed: onInvestorInfo ??
                          () => context.go(RoutePaths.investment),
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
