import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/navigation/deferred_navigation.dart';
import 'package:hdhomesproject/core/navigation/nav_item.dart';
import 'package:hdhomesproject/core/navigation/navigation_config.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:url_launcher/url_launcher.dart';

class CmsPublicLink {
  const CmsPublicLink({required this.label, required this.url});

  final String label;
  final String url;
}

List<CmsPublicLink> cmsLinksFromContent(Map<String, dynamic> content) {
  final raw = content['items'];
  if (raw is! List) return const [];
  final links = <CmsPublicLink>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final label = '${item['label'] ?? ''}'.trim();
    final url = '${item['url'] ?? item['path'] ?? ''}'.trim();
    if (label.isEmpty || url.isEmpty) continue;
    links.add(CmsPublicLink(label: label, url: url));
  }
  return links;
}

CmsSectionRecord? primaryPublishedMenu(List<CmsSectionRecord> menus) {
  if (menus.isEmpty) return null;
  bool named(CmsSectionRecord menu, String needle) {
    final key = menu.sectionKey.toLowerCase();
    final title = (menu.title ?? '').toLowerCase();
    return key == needle ||
        title == needle ||
        key.contains(needle) ||
        title.contains(needle);
  }

  for (final needle in ['primary', 'header']) {
    for (final menu in menus) {
      if (named(menu, needle) && cmsLinksFromContent(menu.content).isNotEmpty) {
        return menu;
      }
    }
  }
  for (final menu in menus) {
    if (cmsLinksFromContent(menu.content).isNotEmpty) return menu;
  }
  return menus.first;
}

String _navPath(String path) {
  var normalized = path.trim();
  if (normalized.isEmpty || normalized.startsWith('http')) return normalized;
  if (!normalized.startsWith('/')) normalized = '/$normalized';
  if (normalized.length > 1 && normalized.endsWith('/')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  return normalized;
}

/// Puts the built-in dropdowns back on Properties, Investment, and Discover.
/// Pages that live inside Discover are not also shown as their own header links.
List<NavItem> withPublicDropdowns(List<NavItem> items) {
  final defaults = {
    for (final item in NavigationConfig.publicNav) item.path: item,
  };
  final discover = defaults[RoutePaths.discover]!;
  final insideDiscover = {
    for (final child in discover.children) _navPath(child.path),
  };

  final seen = <String>{};
  final folded = <NavItem>[];
  var hasDiscover = false;
  for (final item in items) {
    final path = _navPath(item.path);
    if (path.isEmpty || !seen.add(path)) continue;
    if (path == RoutePaths.discover) hasDiscover = true;
    if (path != RoutePaths.discover && insideDiscover.contains(path)) continue;
    folded.add(item.path == path ? item : item.copyWith(path: path));
  }
  if (!hasDiscover) {
    final afterInvestment = folded.indexWhere(
      (item) => item.path == RoutePaths.investment,
    );
    folded.insert(
      afterInvestment >= 0 ? afterInvestment + 1 : folded.length,
      discover,
    );
  }

  final topLevel = {for (final item in folded) item.path};
  return [
    for (final item in folded) _dropdownFor(item, defaults[item.path], topLevel),
  ];
}

NavItem _dropdownFor(NavItem item, NavItem? fallback, Set<String> topLevel) {
  if (fallback == null || !fallback.hasChildren) return item;
  final seen = <String>{};
  final children = <NavItem>[];
  for (final child in [...fallback.children, ...item.children]) {
    final path = _navPath(child.path);
    if (path.isEmpty || !seen.add(path)) continue;
    if (path != item.path && topLevel.contains(path)) continue;
    children.add(child.path == path ? child : child.copyWith(path: path));
  }
  if (children.isEmpty) return item;
  return item.copyWith(
    children: children,
    icon: item.icon ?? fallback.icon,
  );
}

List<NavItem> navItemsFromMenus(List<CmsSectionRecord> menus) {
  final menu = primaryPublishedMenu(menus);
  if (menu == null) return const [];
  return [
    for (final link in cmsLinksFromContent(menu.content))
      NavItem(label: link.label, path: link.url, icon: Icons.link),
  ];
}

/// Published header links, or null while offline / still loading / empty.
final publishedHeaderNavProvider = Provider<List<NavItem>?>((ref) {
  ref.watch(menusRealtimeProvider);
  if (!ref.watch(supabaseConfiguredProvider)) return null;
  final menus = ref.watch(publishedMenuSectionsProvider).valueOrNull;
  if (menus == null) return null;
  final items = navItemsFromMenus(menus);
  if (items.isEmpty) return null;
  return items;
});

Future<void> openCmsLink(BuildContext context, String raw) async {
  final target = raw.trim();
  if (target.isEmpty) return;
  final uri = Uri.tryParse(target);
  final isHttp =
      uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty;
  if (isHttp) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    return;
  }
  if (!context.mounted) return;
  final path = target.startsWith('/') ? target : '/$target';
  final router = GoRouter.maybeOf(context);
  if (router == null) return;
  goDeferred(context, path);
}
