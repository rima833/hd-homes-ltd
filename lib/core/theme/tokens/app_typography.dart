import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hdhomesproject/core/theme/tokens/app_colors.dart';

/// Typography scale and text styles for HD Homes Ltd.
abstract final class AppTypography {
  static const String fontFamily = 'Manrope';
  static const String fallbackFamily = 'Inter';

  // Scale (px) — denser ~20% vs original marketing scale
  static const double hero = 52;
  static const double pageTitle = 40;
  static const double sectionTitle = 28;
  static const double cardTitle = 20;
  static const double subtitle = 18;
  static const double body = 15;
  static const double caption = 13;
  static const double smallLabel = 12;

  static TextStyle _manrope({
    required double fontSize,
    required FontWeight fontWeight,
    double? height,
    double? letterSpacing,
    Color? color,
  }) {
    return GoogleFonts.manrope(
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
    );
  }

  static TextTheme textTheme(Brightness brightness) {
    final primary = brightness == Brightness.dark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final secondary = brightness == Brightness.dark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return TextTheme(
      displayLarge: _manrope(
        fontSize: hero,
        fontWeight: FontWeight.w800,
        height: 1.1,
        letterSpacing: -1.5,
        color: primary,
      ),
      displayMedium: _manrope(
        fontSize: pageTitle,
        fontWeight: FontWeight.w700,
        height: 1.15,
        letterSpacing: -1,
        color: primary,
      ),
      displaySmall: _manrope(
        fontSize: sectionTitle,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: -0.5,
        color: primary,
      ),
      headlineMedium: _manrope(
        fontSize: cardTitle,
        fontWeight: FontWeight.w600,
        height: 1.25,
        color: primary,
      ),
      titleLarge: _manrope(
        fontSize: subtitle,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: primary,
      ),
      bodyLarge: _manrope(
        fontSize: body,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: primary,
      ),
      bodyMedium: _manrope(
        fontSize: caption,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: secondary,
      ),
      labelLarge: _manrope(
        fontSize: body,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: primary,
      ),
      labelMedium: _manrope(
        fontSize: caption,
        fontWeight: FontWeight.w500,
        height: 1.35,
        color: secondary,
      ),
      labelSmall: _manrope(
        fontSize: smallLabel,
        fontWeight: FontWeight.w500,
        height: 1.3,
        letterSpacing: 0.2,
        color: secondary,
      ),
    );
  }

  /// Responsive hero size based on screen width.
  static double responsiveHero(double width) {
    if (width < 600) return 30;
    if (width < 1024) return 40;
    return hero;
  }
}
