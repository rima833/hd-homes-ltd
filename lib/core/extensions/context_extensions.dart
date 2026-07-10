import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/layout/responsive_utils.dart';
import 'package:hdhomesproject/core/theme/app_theme_extension.dart';
import 'package:hdhomesproject/core/theme/tokens/app_breakpoints.dart';

extension BuildContextExtensions on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => theme.textTheme;
  ColorScheme get colorScheme => theme.colorScheme;
  MediaQueryData get mediaQuery => MediaQuery.of(this);
  Size get screenSize => mediaQuery.size;
  double get screenWidth => screenSize.width;

  DeviceType get deviceType => ResponsiveUtils.deviceType(screenWidth);

  bool get isMobile => screenWidth < AppBreakpoints.mobile;
  bool get isTablet =>
      screenWidth >= AppBreakpoints.mobile &&
      screenWidth < AppBreakpoints.tablet;
  bool get isLaptop =>
      screenWidth >= AppBreakpoints.tablet &&
      screenWidth < AppBreakpoints.laptop;
  bool get isDesktop => screenWidth >= AppBreakpoints.laptop;

  int get gridColumns => ResponsiveUtils.gridColumns(screenWidth);
  double get pagePadding => ResponsiveUtils.pagePadding(screenWidth);

  HdHomesThemeExtension get hdTheme => Theme.of(this).extension<HdHomesThemeExtension>()!;
  AppSpacingTokens get spacing => hdTheme.spacing;
  AppRadiusTokens get radius => hdTheme.radius;
}
