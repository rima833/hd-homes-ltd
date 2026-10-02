import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/cms_hero_media_background.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Section 1 — Cinematic media hero.
class MediaHeroSection extends StatelessWidget {
  const MediaHeroSection({
    super.key,
    required this.headline,
    required this.subheadline,
    this.propertyName,
    this.estateName,
    this.mediaCount,
    this.imageUrl,
    this.videoUrl,
    this.onWatchVideo,
    this.onVirtualTour,
    this.onDownload,
    this.onBookInspection,
    this.onViewListing,
  });

  final String headline;
  final String subheadline;
  final String? propertyName;
  final String? estateName;
  final int? mediaCount;
  final String? imageUrl;
  final String? videoUrl;
  final VoidCallback? onWatchVideo;
  final VoidCallback? onVirtualTour;
  final VoidCallback? onDownload;
  final VoidCallback? onBookInspection;
  final VoidCallback? onViewListing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: context.isMobile ? 520 : 600,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CmsHeroMediaBackground(
            imageUrl: imageUrl,
            videoUrl: videoUrl,
            fallbackColors: [
              AppColors.charcoal,
              AppColors.gold.withValues(alpha: 0.2),
              AppColors.deepBlack,
            ],
            fallbackChild: Center(
              child: Icon(
                LucideIcons.image,
                size: 80,
                color: AppColors.gold.withValues(alpha: 0.35),
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
                if (propertyName != null) ...[
                  Text(
                    propertyName!,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.gold,
                        ),
                  ),
                  if (estateName != null)
                    Text(
                      estateName!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondaryDark,
                          ),
                    ),
                  if (mediaCount != null)
                    Text(
                      '$mediaCount media assets',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                Text(
                  headline,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: AppSpacing.base),
                Text(
                  subheadline,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondaryDark,
                      ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Wrap(
                  spacing: AppSpacing.base,
                  runSpacing: AppSpacing.sm,
                  children: [
                    if (onWatchVideo != null)
                      PrimaryButton(
                        label: 'Watch Video',
                        icon: LucideIcons.play,
                        onPressed: onWatchVideo,
                      ),
                    if (onVirtualTour != null)
                      PrimaryButton(
                        label: 'Start Virtual Tour',
                        variant: ButtonVariant.secondary,
                        icon: LucideIcons.rotate3d,
                        onPressed: onVirtualTour,
                      ),
                    if (onViewListing != null)
                      PrimaryButton(
                        label: 'View listing',
                        variant: ButtonVariant.secondary,
                        icon: LucideIcons.arrowRight,
                        onPressed: onViewListing,
                      ),
                    if (onDownload != null)
                      PrimaryButton(
                        label: 'Download Brochure',
                        variant: ButtonVariant.ghost,
                        icon: LucideIcons.download,
                        onPressed: onDownload,
                      ),
                    PrimaryButton(
                      label: 'Book Inspection',
                      variant: ButtonVariant.ghost,
                      icon: LucideIcons.calendarCheck,
                      onPressed: onBookInspection ??
                          () => context.go(RoutePaths.bookInspection),
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

/// Hub hero without property context.
class MediaHubHeroSection extends StatelessWidget {
  const MediaHubHeroSection({
    super.key,
    required this.headline,
    required this.subheadline,
    this.imageUrl,
    this.videoUrl,
  });

  final String headline;
  final String subheadline;
  final String? imageUrl;
  final String? videoUrl;

  @override
  Widget build(BuildContext context) {
    return MediaHeroSection(
      headline: headline,
      subheadline: subheadline,
      imageUrl: imageUrl,
      videoUrl: videoUrl,
      onBookInspection: () => context.go(RoutePaths.bookInspection),
      onViewListing: () => context.go(RoutePaths.properties),
    );
  }
}
