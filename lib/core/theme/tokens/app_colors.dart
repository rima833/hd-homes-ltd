import 'package:flutter/material.dart';

/// HD Homes Ltd official brand color palette (Part 4 design tokens).
abstract final class AppColors {
  // Brand
  static const Color gold = Color(0xFFD4A34E);
  static const Color goldLight = Color(0xFFF4C978);
  static const Color charcoal = Color(0xFF3F4148);
  static const Color deepBlack = Color(0xFF0F1115);
  static const Color white = Color(0xFFFFFFFF);
  static const Color lightBackground = Color(0xFFF8F9FA);
  static const Color gray = Color(0xFFD9D9D9);

  // Status
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Surfaces (dark theme)
  static const Color darkSurface = Color(0xFF1A1D24);
  static const Color darkElevated = Color(0xFF252830);

  // Text
  static const Color textPrimaryDark = white;
  static const Color textSecondaryDark = Color(0xFFB0B3BA);
  static const Color textPrimaryLight = deepBlack;
  static const Color textSecondaryLight = Color(0xFF6B7280);

  // Gradients
  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [gold, goldLight],
  );

  static const LinearGradient goldGradientVertical = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [gold, goldLight],
  );

  // Neutral scale (50–950)
  static const Color neutral50 = Color(0xFFF9FAFB);
  static const Color neutral100 = Color(0xFFF3F4F6);
  static const Color neutral200 = Color(0xFFE5E7EB);
  static const Color neutral300 = Color(0xFFD1D5DB);
  static const Color neutral400 = Color(0xFF9CA3AF);
  static const Color neutral500 = Color(0xFF6B7280);
  static const Color neutral600 = Color(0xFF4B5563);
  static const Color neutral700 = Color(0xFF374151);
  static const Color neutral800 = Color(0xFF1F2937);
  static const Color neutral900 = Color(0xFF111827);
  static const Color neutral950 = deepBlack;

  // Interactive states
  static Color primaryHover = goldLight;
  static Color primaryDisabled = gold.withValues(alpha: 0.4);
  static Color overlayDark = deepBlack.withValues(alpha: 0.6);
  static Color overlayLight = white.withValues(alpha: 0.85);

  // Glass
  static Color glassBackground(Brightness brightness) => brightness == Brightness.dark
      ? white.withValues(alpha: 0.08)
      : white.withValues(alpha: 0.72);

  static Color glassBorder(Brightness brightness) => brightness == Brightness.dark
      ? white.withValues(alpha: 0.12)
      : white.withValues(alpha: 0.5);
}
