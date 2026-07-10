import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Section 1 — Search Intelligence hero.
class SearchHeroSection extends StatelessWidget {
  const SearchHeroSection({
    super.key,
    required this.headline,
    required this.subheadline,
    required this.searchBar,
    this.onAdvancedFilters,
  });

  final String headline;
  final String subheadline;
  final Widget searchBar;
  final VoidCallback? onAdvancedFilters;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: context.isMobile ? 560 : 600,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.charcoal, AppColors.gold.withValues(alpha: 0.18), AppColors.deepBlack],
              ),
            ),
            child: Center(
              child: Icon(LucideIcons.sparkles, size: 72, color: AppColors.gold.withValues(alpha: 0.25)),
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
                Text(subheadline, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondaryDark)),
                const SizedBox(height: AppSpacing.xl),
                ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: searchBar),
                const SizedBox(height: AppSpacing.base),
                PrimaryButton(
                  label: 'Advanced filters',
                  variant: ButtonVariant.secondary,
                  icon: LucideIcons.slidersHorizontal,
                  onPressed: onAdvancedFilters,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
