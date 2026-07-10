import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/l10n/app_strings.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';

/// Reusable full-width hero for landing and marketing pages.
class WebsiteHeroSection extends StatelessWidget {
  const WebsiteHeroSection({
    super.key,
    required this.headline,
    this.subheadline,
    this.primaryCtaLabel,
    this.primaryCtaPath,
    this.secondaryCtaLabel,
    this.secondaryCtaPath,
    this.backgroundImage,
    this.minHeight,
  });

  final String headline;
  final String? subheadline;
  final String? primaryCtaLabel;
  final String? primaryCtaPath;
  final String? secondaryCtaLabel;
  final String? secondaryCtaPath;
  final String? backgroundImage;
  final double? minHeight;

  @override
  Widget build(BuildContext context) {
    final height = minHeight ?? (context.isMobile ? 520 : 640);

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (backgroundImage != null)
            Image.asset(backgroundImage!, fit: BoxFit.cover)
          else
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.deepBlack,
                    AppColors.charcoal,
                    AppColors.darkSurface,
                  ],
                ),
              ),
            ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.overlayDark.withValues(alpha: 0.35),
                  AppColors.deepBlack.withValues(alpha: 0.85),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.pagePadding),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.tagline.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.gold,
                        letterSpacing: 2.5,
                      ),
                ),
                const SizedBox(height: AppSpacing.base),
                Text(
                  headline,
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        color: AppColors.white,
                        height: 1.05,
                      ),
                ),
                if (subheadline != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Text(
                      subheadline!,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.textSecondaryDark,
                          ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xxl),
                Wrap(
                  spacing: AppSpacing.base,
                  runSpacing: AppSpacing.base,
                  children: [
                    if (primaryCtaLabel != null && primaryCtaPath != null)
                      PrimaryButton(
                        label: primaryCtaLabel!,
                        onPressed: () => context.go(primaryCtaPath!),
                      ),
                    if (secondaryCtaLabel != null && secondaryCtaPath != null)
                      PrimaryButton(
                        label: secondaryCtaLabel!,
                        variant: ButtonVariant.secondary,
                        onPressed: () => context.go(secondaryCtaPath!),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: AppDurations.slow);
  }
}
