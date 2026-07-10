import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/core/widgets/feedback/app_badge.dart';
import 'package:hdhomesproject/features/estates/data/models/estate_detail_content.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Section 1 — Premium estate hero with cinematic background.
class EstateDetailHero extends StatelessWidget {
  const EstateDetailHero({
    super.key,
    required this.detail,
    this.onExploreProperties,
  });

  final EstateDetailContent detail;
  final VoidCallback? onExploreProperties;

  @override
  Widget build(BuildContext context) {
    final s = detail.summary;

    return SizedBox(
      height: context.isMobile ? 520 : 640,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.charcoal,
                  AppColors.gold.withValues(alpha: 0.25),
                  AppColors.deepBlack,
                ],
              ),
            ),
            child: Center(
              child: Icon(
                s.heroVideoUrl != null ? LucideIcons.video : LucideIcons.plane,
                size: 64,
                color: AppColors.gold.withValues(alpha: 0.4),
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
                  AppColors.deepBlack.withValues(alpha: 0.85),
                ],
                stops: const [0.4, 1.0],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.pagePadding,
              vertical: AppSpacing.xxl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppBadge(label: s.status.label, variant: BadgeVariant.gold),
                const SizedBox(height: AppSpacing.base),
                Text(
                  s.name,
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    const Icon(LucideIcons.mapPin, color: AppColors.gold, size: 16),
                    const SizedBox(width: AppSpacing.xs),
                    Text(s.location, style: const TextStyle(color: AppColors.white)),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.xl,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _stat('From', s.startingPrice),
                    _stat('Types', s.propertyTypes.take(3).join(', ')),
                    _stat('Size', s.estateSize),
                    _stat('Status', s.completionStatus),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                Wrap(
                  spacing: AppSpacing.base,
                  runSpacing: AppSpacing.sm,
                  children: [
                    PrimaryButton(
                      label: 'Explore Properties',
                      icon: LucideIcons.building2,
                      onPressed: onExploreProperties,
                    ),
                    PrimaryButton(
                      label: 'Book Estate Tour',
                      variant: ButtonVariant.secondary,
                      icon: LucideIcons.calendar,
                      onPressed: () => context.go(RoutePaths.bookInspection),
                    ),
                    PrimaryButton(
                      label: 'Download Brochure',
                      variant: ButtonVariant.ghost,
                      icon: LucideIcons.download,
                      onPressed: () {},
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

  Widget _stat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryDark)),
        Text(value, style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
