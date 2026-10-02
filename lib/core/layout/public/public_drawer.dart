import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/navigation/deferred_navigation.dart';
import 'package:hdhomesproject/core/navigation/nav_item.dart';
import 'package:hdhomesproject/core/navigation/navigation_config.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/l10n/app_strings.dart';
import 'package:hdhomesproject/core/widgets/buttons/book_inspection_hub_cta.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/identity_provider.dart';
import 'package:hdhomesproject/core/layout/public/published_chrome.dart';
import 'package:hdhomesproject/features/settings/domain/entities/public_website_gates.dart';
import 'package:hdhomesproject/features/settings/presentation/providers/platform_settings_providers.dart';

class PublicDrawer extends ConsumerWidget {
  const PublicDrawer({super.key});

  List<NavItem> _withoutEstates(List<NavItem> items) {
    return items.where((item) {
      final path = item.path.toLowerCase();
      final label = item.label.toLowerCase();
      if (path == RoutePaths.estates ||
          path.startsWith('${RoutePaths.estates}/')) {
        return false;
      }
      return label != 'estates';
    }).toList();
  }

  void _openInvest(BuildContext context, WidgetRef ref) {
    Navigator.of(context).pop();
    final session = ref.read(identitySessionProvider);
    if (session.isAuthenticated && session.canAccessInvestorPortal) {
      goDeferred(context, RoutePaths.investor);
      return;
    }
    goDeferred(context, RoutePaths.investment);
  }

  bool _isDropdownSectionOpen(NavItem item, String location) {
    if (item.children.any(
      (c) =>
          location == c.path ||
          (c.path != RoutePaths.home && location.startsWith('${c.path}/')),
    )) {
      return true;
    }
    if (item.path == RoutePaths.properties) {
      return location == RoutePaths.paymentCalculator ||
          location == RoutePaths.construction ||
          location.startsWith('${RoutePaths.properties}/') ||
          location.startsWith('${RoutePaths.construction}/');
    }
    if (item.path == RoutePaths.investment) {
      return location == RoutePaths.roiCalculator ||
          location.startsWith('${RoutePaths.investment}/');
    }
    if (item.path == RoutePaths.discover) {
      return item.children.any(
        (c) =>
            location == c.path ||
            (c.path != RoutePaths.home && location.startsWith('${c.path}/')),
      );
    }
    return location == item.path;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final settings = ref.watch(publishedPlatformSettingsProvider).valueOrNull;
    final published = ref.watch(publishedHeaderNavProvider);
    final source = withPublicDropdowns(
      published ?? _withoutEstates(NavigationConfig.publicNav),
    );
    final navItems = [
      for (final item in source)
        if (settings == null || settings.allowsPublicPath(item.path))
          if (settings == null || !item.hasChildren)
            item
          else
            item.copyWith(
              children: [
                for (final child in item.children)
                  if (settings.allowsPublicPath(child.path)) child,
              ],
            ),
    ];

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'HD Homes Ltd',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final item in navItems)
                    if (item.hasChildren)
                      ExpansionTile(
                        leading: Icon(item.icon),
                        title: Text(item.label),
                        initiallyExpanded: _isDropdownSectionOpen(
                          item,
                          location,
                        ),
                        children: [
                          for (final child in item.children)
                            ListTile(
                              contentPadding: const EdgeInsets.only(left: 56),
                              leading: child.icon != null
                                  ? Icon(child.icon, size: 18)
                                  : null,
                              title: Text(child.label),
                              selected:
                                  location == child.path ||
                                  (child.path != RoutePaths.home &&
                                      location.startsWith('${child.path}/')),
                              selectedColor: AppColors.gold,
                              onTap: () {
                                Navigator.of(context).pop();
                                goDeferred(context, child.path);
                              },
                            ),
                        ],
                      )
                    else
                      ListTile(
                        leading: Icon(item.icon),
                        title: Text(item.label),
                        selected: location == item.path,
                        selectedColor: AppColors.gold,
                        onTap: () {
                          Navigator.of(context).pop();
                          openCmsLink(context, item.path);
                        },
                      ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.base),
              child: Column(
                children: [
                  PrimaryButton(
                    label: AppStrings.navInvest,
                    expand: true,
                    onPressed: () => _openInvest(context, ref),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  BookInspectionHubCta(
                    expand: true,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      goDeferred(context, RoutePaths.login);
                    },
                    child: const Text('Login'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
