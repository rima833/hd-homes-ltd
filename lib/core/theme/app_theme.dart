import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/theme/app_theme_extension.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';

/// Central theme configuration for HD Homes Ltd design system.
abstract final class AppTheme {
  static const String logoAsset = 'assets/images/logos/hd_homes_logo.png';

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final textTheme = AppTypography.textTheme(brightness);

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.gold,
      onPrimary: AppColors.white,
      primaryContainer: AppColors.goldLight,
      onPrimaryContainer: AppColors.deepBlack,
      secondary: AppColors.charcoal,
      onSecondary: AppColors.white,
      surface: isDark ? AppColors.deepBlack : AppColors.lightBackground,
      onSurface: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
      onSurfaceVariant:
          isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
      error: AppColors.error,
      onError: AppColors.white,
      outline: AppColors.gray,
      surfaceContainerHighest:
          isDark ? AppColors.darkElevated : AppColors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: AppTypography.fontFamily,
      textTheme: textTheme,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      dividerColor: AppColors.gray.withValues(alpha: 0.5),
      splashFactory: InkRipple.splashFactory,
      extensions: [
        HdHomesThemeExtension(
          spacing: const AppSpacingTokens(),
          radius: const AppRadiusTokens(),
          isDark: isDark,
        ),
      ],
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? AppColors.deepBlack : AppColors.white,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: isDark ? AppColors.darkSurface : AppColors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.darkElevated : AppColors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.base,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.inputBorder,
          borderSide: BorderSide(color: AppColors.gray.withValues(alpha: 0.6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputBorder,
          borderSide: BorderSide(color: AppColors.gray.withValues(alpha: 0.6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputBorder,
          borderSide: const BorderSide(color: AppColors.gold, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputBorder,
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputBorder,
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        labelStyle: textTheme.bodyMedium,
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.white,
          elevation: 2,
          shadowColor: AppColors.gold.withValues(alpha: 0.3),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.base,
          ),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.buttonBorder),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.gold,
          side: const BorderSide(color: AppColors.gold, width: 1.5),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.base,
          ),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.buttonBorder),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.gold,
          textStyle: textTheme.labelLarge,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.white,
        elevation: 4,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? AppColors.darkElevated : AppColors.white,
        selectedColor: AppColors.gold.withValues(alpha: 0.2),
        labelStyle: textTheme.labelMedium!,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.buttonBorder),
        side: BorderSide(color: AppColors.gray.withValues(alpha: 0.5)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.dialogBorder),
        elevation: 8,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.charcoal,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: AppColors.white),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.buttonBorder),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.gold,
      ),
      iconTheme: IconThemeData(
        color: colorScheme.onSurface,
        size: AppIcons.md,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
