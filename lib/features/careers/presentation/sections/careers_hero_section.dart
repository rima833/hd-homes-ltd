import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Section 1 — Careers Hub hero.
class CareersHeroSection extends StatelessWidget {
  const CareersHeroSection({
    super.key,
    required this.headline,
    required this.subheadline,
    required this.openPositions,
    this.onViewRoles,
    this.onGeneralApply,
  });

  final String headline;
  final String subheadline;
  final int openPositions;
  final VoidCallback? onViewRoles;
  final VoidCallback? onGeneralApply;

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
                  AppColors.gold.withValues(alpha: 0.18),
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
                  '$openPositions open positions',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.gold,
                        letterSpacing: 1.2,
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
                      label: 'View Open Roles',
                      icon: LucideIcons.briefcase,
                      onPressed: onViewRoles,
                    ),
                    PrimaryButton(
                      label: 'General Application',
                      variant: ButtonVariant.secondary,
                      icon: LucideIcons.fileText,
                      onPressed: onGeneralApply,
                    ),
                    PrimaryButton(
                      label: 'Contact HR',
                      variant: ButtonVariant.ghost,
                      icon: LucideIcons.mail,
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
