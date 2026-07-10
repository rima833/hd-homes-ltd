import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Section 1 — Premium trust hero.
class TrustHeroSection extends StatelessWidget {
  const TrustHeroSection({
    super.key,
    required this.headline,
    required this.subheadline,
    this.onDownloadProfile,
    this.onViewCertifications,
    this.onInvestorInfo,
  });

  final String headline;
  final String subheadline;
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
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.deepBlack, AppColors.charcoal, AppColors.gold.withValues(alpha: 0.15)],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, AppColors.deepBlack.withValues(alpha: 0.9)],
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
                Text(subheadline, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondaryDark)),
                const SizedBox(height: AppSpacing.xl),
                Wrap(
                  spacing: AppSpacing.base,
                  runSpacing: AppSpacing.sm,
                  children: [
                    PrimaryButton(label: 'Download Company Profile', icon: LucideIcons.download, onPressed: onDownloadProfile),
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
                      onPressed: onInvestorInfo ?? () => context.go(RoutePaths.investment),
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
