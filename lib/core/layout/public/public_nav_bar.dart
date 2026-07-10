import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/navigation/nav_item.dart';
import 'package:hdhomesproject/core/navigation/navigation_config.dart';
import 'package:hdhomesproject/core/theme/app_theme.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/l10n/app_strings.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Sticky public website navigation with glass effect on scroll.
class PublicNavBar extends StatelessWidget {
  const PublicNavBar({
    super.key,
    required this.scrolled,
    required this.onMenuTap,
    this.onSearchTap,
  });

  final bool scrolled;
  final VoidCallback onMenuTap;
  final VoidCallback? onSearchTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: scrolled ? 16 : 0,
          sigmaY: scrolled ? 16 : 0,
        ),
        child: AnimatedContainer(
          duration: AppDurations.fast,
          decoration: BoxDecoration(
            color: scrolled
                ? (isDark
                    ? AppColors.deepBlack.withValues(alpha: 0.85)
                    : AppColors.white.withValues(alpha: 0.9))
                : Colors.transparent,
            border: scrolled
                ? Border(
                    bottom: BorderSide(
                      color: AppColors.gray.withValues(alpha: 0.2),
                    ),
                  )
                : null,
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.pagePadding,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.go(RoutePaths.home),
                    child: Image.asset(AppTheme.logoAsset, height: 40),
                  ),
                  const Spacer(),
                  if (context.isLaptop || context.isDesktop) ...[
                    Flexible(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final item in NavigationConfig.publicNav.take(6))
                              _NavLink(item: item),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  IconButton(
                    tooltip: AppStrings.navSearch,
                    onPressed: onSearchTap,
                    icon: const Icon(LucideIcons.search),
                  ),
                  TextButton(
                    onPressed: () => context.go(RoutePaths.login),
                    child: const Text(AppStrings.navLogin),
                  ),
                  if (!context.isMobile) ...[
                    TextButton(
                      onPressed: () => context.go(RoutePaths.investment),
                      child: const Text(AppStrings.navInvest),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    PrimaryButton(
                      label: AppStrings.navBookInspection,
                      onPressed: () => context.go(RoutePaths.bookInspection),
                    ),
                  ] else
                    IconButton(
                      icon: const Icon(Icons.menu_rounded),
                      onPressed: onMenuTap,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink({required this.item});

  final NavItem item;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final isActive = location == item.path;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: TextButton(
        onPressed: () => context.go(item.path),
        style: TextButton.styleFrom(
          foregroundColor: isActive ? AppColors.gold : null,
        ),
        child: Text(item.label),
      ),
    );
  }
}
