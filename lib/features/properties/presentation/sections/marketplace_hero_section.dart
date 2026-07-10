import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/app_theme.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/properties/data/models/marketplace_property.dart';

class MarketplaceHeroSection extends StatelessWidget {
  const MarketplaceHeroSection({super.key, required this.content});

  final MarketplaceHeroContent content;

  @override
  Widget build(BuildContext context) {
    final height = context.isMobile ? 480 : 520;

    return SizedBox(
      height: height.toDouble(),
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.deepBlack, AppColors.charcoal, Color(0xFF1A1510)],
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.deepBlack.withValues(alpha: 0.2),
                  AppColors.deepBlack.withValues(alpha: 0.92),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.pagePadding,
              context.isMobile ? 100 : 120,
              context.pagePadding,
              AppSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Image.asset(AppTheme.logoAsset, height: 40),
                const SizedBox(height: AppSpacing.base),
                Text(
                  content.headline,
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        color: AppColors.white,
                        fontSize: context.isMobile ? 32 : 44,
                      ),
                ).animate().fadeIn().slideY(begin: 0.05, end: 0),
                const SizedBox(height: AppSpacing.base),
                Text(
                  content.subheadline,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondaryDark,
                      ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.base,
                  runSpacing: AppSpacing.base,
                  children: [
                    PrimaryButton(
                      label: content.primaryCtaLabel,
                      onPressed: () => context.go(content.primaryCtaPath),
                    ),
                    PrimaryButton(
                      label: content.secondaryCtaLabel,
                      variant: ButtonVariant.secondary,
                      onPressed: () => context.go(content.secondaryCtaPath),
                    ),
                    PrimaryButton(
                      label: content.tertiaryCtaLabel,
                      variant: ButtonVariant.ghost,
                      onPressed: () => context.go(content.tertiaryCtaPath),
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
