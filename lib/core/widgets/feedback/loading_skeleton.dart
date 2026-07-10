import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:shimmer/shimmer.dart';

class LoadingSkeleton extends StatelessWidget {
  const LoadingSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius,
  });

  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? AppColors.darkElevated : AppColors.gray.withValues(alpha: 0.3),
      highlightColor: isDark ? AppColors.darkSurface : AppColors.lightBackground,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: borderRadius ?? AppRadius.buttonBorder,
        ),
      ),
    );
  }
}

class PropertyCardSkeleton extends StatelessWidget {
  const PropertyCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardBorder,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LoadingSkeleton(height: 200, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          Padding(
            padding: EdgeInsets.all(AppSpacing.base),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LoadingSkeleton(width: 120, height: 24),
                SizedBox(height: AppSpacing.sm),
                LoadingSkeleton(width: 200),
                SizedBox(height: AppSpacing.sm),
                LoadingSkeleton(width: 160),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Branded loading indicator with gold accent.
class LoadingWidget extends StatelessWidget {
  const LoadingWidget({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              color: AppColors.gold,
              strokeWidth: 3,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.base),
            Text(message!, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}
