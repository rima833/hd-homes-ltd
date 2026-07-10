import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Section 1 — Investment Hub hero.
class InvestmentHeroSection extends StatelessWidget {
  const InvestmentHeroSection({
    super.key,
    required this.headline,
    required this.subheadline,
    this.onExploreOpportunities,
    this.onCalculateRoi,
    this.onBookConsultation,
  });

  final String headline;
  final String subheadline;
  final VoidCallback? onExploreOpportunities;
  final VoidCallback? onCalculateRoi;
  final VoidCallback? onBookConsultation;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: context.isMobile ? 480 : 560,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.deepBlack,
                  AppColors.charcoal,
                  AppColors.gold.withValues(alpha: 0.2),
                ],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, AppColors.deepBlack.withValues(alpha: 0.92)],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.pagePadding, vertical: AppSpacing.xxl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondaryDark),
                ),
                const SizedBox(height: AppSpacing.xl),
                Wrap(
                  spacing: AppSpacing.base,
                  runSpacing: AppSpacing.sm,
                  children: [
                    PrimaryButton(
                      label: 'Explore Opportunities',
                      icon: LucideIcons.layers,
                      onPressed: onExploreOpportunities,
                    ),
                    PrimaryButton(
                      label: 'Calculate ROI',
                      variant: ButtonVariant.secondary,
                      icon: LucideIcons.calculator,
                      onPressed: onCalculateRoi,
                    ),
                    PrimaryButton(
                      label: 'Book Consultation',
                      variant: ButtonVariant.ghost,
                      icon: LucideIcons.calendar,
                      onPressed: onBookConsultation ?? () => context.go(RoutePaths.contact),
                    ),
                    PrimaryButton(
                      label: 'Investor Portal',
                      variant: ButtonVariant.ghost,
                      icon: LucideIcons.lock,
                      onPressed: () => context.go(RoutePaths.investor),
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
