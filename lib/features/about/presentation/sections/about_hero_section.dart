import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/app_theme.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/about/data/models/about_cms_content.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Section 1 — About hero banner.
class AboutHeroSection extends StatelessWidget {
  const AboutHeroSection({super.key, required this.content});

  final AboutHeroContent content;

  @override
  Widget build(BuildContext context) {
    final height = context.isMobile ? 560 : 680;

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
                colors: [
                  Color(0xFF1A1510),
                  AppColors.charcoal,
                  AppColors.deepBlack,
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
                  AppColors.deepBlack.withValues(alpha: 0.3),
                  AppColors.deepBlack.withValues(alpha: 0.9),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.pagePadding,
              context.isMobile ? 100 : 120,
              context.pagePadding,
              AppSpacing.xxl,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset(AppTheme.logoAsset, height: 56)
                    .animate()
                    .fadeIn(duration: 500.ms)
                    .scale(begin: const Offset(0.9, 0.9)),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  content.headline,
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        color: AppColors.white,
                        height: 1.08,
                        fontSize: context.isMobile ? 32 : 48,
                      ),
                ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.06, end: 0),
                const SizedBox(height: AppSpacing.lg),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Text(
                    content.subheadline,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondaryDark,
                        ),
                  ),
                ).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: AppSpacing.xxl),
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
                ).animate().fadeIn(delay: 300.ms),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
