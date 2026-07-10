import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hdhomesproject/core/theme/app_theme.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/l10n/app_strings.dart';

/// Section 1 — Cinematic loading experience (1–2 seconds).
class HomeSplashOverlay extends StatefulWidget {
  const HomeSplashOverlay({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<HomeSplashOverlay> createState() => _HomeSplashOverlayState();
}

class _HomeSplashOverlayState extends State<HomeSplashOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress;
  bool _exiting = false;

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..forward();

    _progress.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _exiting = true);
        Future<void>.delayed(const Duration(milliseconds: 400), () {
          if (mounted) widget.onComplete();
        });
      }
    });
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _exiting ? 0 : 1,
      duration: const Duration(milliseconds: 400),
      child: Container(
        color: AppColors.deepBlack,
        child: DecoratedBox(
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
          child: SafeArea(
            child: Column(
              children: [
                const Spacer(),
                Image.asset(AppTheme.logoAsset, height: 96)
                    .animate()
                    .fadeIn(duration: 500.ms)
                    .scale(
                      begin: const Offset(0.85, 0.85),
                      end: const Offset(1, 1),
                      curve: Curves.easeOutCubic,
                    ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  AppStrings.companyName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.white,
                        letterSpacing: 1.2,
                      ),
                ).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  AppStrings.tagline,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondaryDark,
                      ),
                ).animate().fadeIn(delay: 400.ms),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.colossal,
                    vertical: AppSpacing.xxl,
                  ),
                  child: AnimatedBuilder(
                    animation: _progress,
                    builder: (context, _) => LinearProgressIndicator(
                      value: _progress.value,
                      minHeight: 2,
                      backgroundColor: AppColors.neutral800,
                      color: AppColors.gold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
