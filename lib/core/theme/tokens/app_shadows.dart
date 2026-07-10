import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/theme/tokens/app_colors.dart';

/// Soft elevation shadows — layered, never harsh.
abstract final class AppShadows {
  static List<BoxShadow> get sm => [
        BoxShadow(
          color: AppColors.deepBlack.withValues(alpha: 0.06),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get md => [
        BoxShadow(
          color: AppColors.deepBlack.withValues(alpha: 0.08),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: AppColors.deepBlack.withValues(alpha: 0.04),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get lg => [
        BoxShadow(
          color: AppColors.deepBlack.withValues(alpha: 0.12),
          blurRadius: 32,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: AppColors.deepBlack.withValues(alpha: 0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get goldGlow => [
    BoxShadow(
      color: AppColors.gold.withValues(alpha: 0.25),
      blurRadius: 24,
      offset: const Offset(0, 4),
    ),
  ];
}
