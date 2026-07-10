import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/theme/tokens/app_breakpoints.dart';
import 'package:hdhomesproject/core/theme/tokens/app_spacing.dart';

enum DeviceType { mobile, tablet, laptop, desktop, ultraWide }

/// Responsive layout helpers — never hardcode widths.
abstract final class ResponsiveUtils {
  static DeviceType deviceType(double width) {
    if (width < AppBreakpoints.mobile) return DeviceType.mobile;
    if (width < AppBreakpoints.tablet) return DeviceType.tablet;
    if (width < AppBreakpoints.laptop) return DeviceType.laptop;
    if (width < AppBreakpoints.desktop) return DeviceType.desktop;
    return DeviceType.ultraWide;
  }

  static int gridColumns(double width) => switch (deviceType(width)) {
        DeviceType.mobile => 1,
        DeviceType.tablet => 2,
        DeviceType.laptop => 3,
        DeviceType.desktop => 4,
        DeviceType.ultraWide => 6,
      };

  static double pagePadding(double width) => switch (deviceType(width)) {
        DeviceType.mobile => AppSpacing.base,
        DeviceType.tablet => AppSpacing.xl,
        DeviceType.laptop => AppSpacing.xxl,
        DeviceType.desktop => AppSpacing.xxxl,
        DeviceType.ultraWide => AppSpacing.massive,
      };

  static double sidebarWidth(double width) =>
      width >= AppBreakpoints.tablet ? 280 : 0;

  static bool showPermanentSidebar(double width) =>
      width >= AppBreakpoints.laptop;

  static bool useBottomNavigation(double width) => width < AppBreakpoints.tablet;
}

/// Responsive grid that auto-sizes columns by breakpoint.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.spacing = AppSpacing.base,
    this.runSpacing = AppSpacing.base,
    this.maxColumns,
  });

  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final int? maxColumns;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = maxColumns ?? ResponsiveUtils.gridColumns(width);

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: children
              .map((child) => SizedBox(width: itemWidth, child: child))
              .toList(),
        );
      },
    );
  }
}
