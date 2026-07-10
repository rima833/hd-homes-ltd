import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';

/// Extended theme tokens accessible via [Theme.of(context).extension].
@immutable
class HdHomesThemeExtension extends ThemeExtension<HdHomesThemeExtension> {
  const HdHomesThemeExtension({
    required this.spacing,
    required this.radius,
    required this.isDark,
  });

  final AppSpacingTokens spacing;
  final AppRadiusTokens radius;
  final bool isDark;

  Color get glassBackground => AppColors.glassBackground(
        isDark ? Brightness.dark : Brightness.light,
      );

  Color get glassBorder => AppColors.glassBorder(
        isDark ? Brightness.dark : Brightness.light,
      );

  @override
  HdHomesThemeExtension copyWith({
    AppSpacingTokens? spacing,
    AppRadiusTokens? radius,
    bool? isDark,
  }) {
    return HdHomesThemeExtension(
      spacing: spacing ?? this.spacing,
      radius: radius ?? this.radius,
      isDark: isDark ?? this.isDark,
    );
  }

  @override
  HdHomesThemeExtension lerp(
    covariant ThemeExtension<HdHomesThemeExtension>? other,
    double t,
  ) {
    if (other is! HdHomesThemeExtension) return this;
    return HdHomesThemeExtension(
      spacing: spacing,
      radius: radius,
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

/// Spacing token accessor (wraps [AppSpacing] constants).
@immutable
class AppSpacingTokens {
  const AppSpacingTokens();

  double get xs => AppSpacing.xs;
  double get sm => AppSpacing.sm;
  double get md => AppSpacing.md;
  double get base => AppSpacing.base;
  double get lg => AppSpacing.lg;
  double get xl => AppSpacing.xl;
  double get xxl => AppSpacing.xxl;
  double get xxxl => AppSpacing.xxxl;
  double get huge => AppSpacing.huge;
  double get massive => AppSpacing.massive;
}

/// Radius token accessor.
@immutable
class AppRadiusTokens {
  const AppRadiusTokens();

  BorderRadius get button => AppRadius.buttonBorder;
  BorderRadius get card => AppRadius.cardBorder;
  BorderRadius get dialog => AppRadius.dialogBorder;
  BorderRadius get input => AppRadius.inputBorder;
  BorderRadius get image => AppRadius.imageBorder;
}

extension HdHomesThemeContext on BuildContext {
  HdHomesThemeExtension get hdTheme =>
      Theme.of(this).extension<HdHomesThemeExtension>()!;

  AppSpacingTokens get spacing => hdTheme.spacing;
  AppRadiusTokens get radius => hdTheme.radius;
}
