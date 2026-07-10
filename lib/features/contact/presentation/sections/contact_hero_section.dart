import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Section 1 — Premium contact hero.
class ContactHeroSection extends StatelessWidget {
  const ContactHeroSection({
    super.key,
    required this.headline,
    required this.subheadline,
    this.onContactSales,
    this.onBookInspection,
    this.onTalkAdvisor,
    this.onInvestor,
  });

  final String headline;
  final String subheadline;
  final VoidCallback? onContactSales;
  final VoidCallback? onBookInspection;
  final VoidCallback? onTalkAdvisor;
  final VoidCallback? onInvestor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: context.isMobile ? 520 : 600,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.charcoal,
                  AppColors.gold.withValues(alpha: 0.2),
                  AppColors.deepBlack,
                ],
              ),
            ),
            child: Center(
              child: Icon(
                LucideIcons.headphones,
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
                colors: [Colors.transparent, AppColors.deepBlack.withValues(alpha: 0.92)],
                stops: const [0.35, 1.0],
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
                      label: 'Contact Sales',
                      icon: LucideIcons.phone,
                      onPressed: onContactSales,
                    ),
                    PrimaryButton(
                      label: 'Book Inspection',
                      variant: ButtonVariant.secondary,
                      icon: LucideIcons.calendarCheck,
                      onPressed: onBookInspection,
                    ),
                    PrimaryButton(
                      label: 'Talk to an Advisor',
                      variant: ButtonVariant.ghost,
                      icon: LucideIcons.userCheck,
                      onPressed: onTalkAdvisor,
                    ),
                    PrimaryButton(
                      label: 'Become an Investor',
                      variant: ButtonVariant.ghost,
                      icon: LucideIcons.landmark,
                      onPressed: onInvestor ?? () => context.go(RoutePaths.investment),
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
