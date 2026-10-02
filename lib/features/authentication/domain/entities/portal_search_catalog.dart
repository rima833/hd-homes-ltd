import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/navigation/nav_item.dart';
import 'package:hdhomesproject/core/navigation/navigation_config.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/app_role.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/command_palette_catalog.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/enterprise_search_models.dart';

/// Always-available portal destinations for Global Command Center search.
///
/// Merged with the remote `search_index` so client / investor / admin header
/// search works even when the DB index is empty.
abstract final class PortalSearchCatalog {
  static List<SearchIndexEntry> allEntries() => [
        // Use modules with no requiredPermission so clients / investors
        // always see their own portal destinations in header search.
        ..._fromNav(
          NavigationConfig.clientNav,
          audience: 'client',
          module: SearchResultModule.workspace,
          popularity: 88,
        ),
        ..._fromNav(
          NavigationConfig.investorNav,
          audience: 'investor',
          module: SearchResultModule.workspace,
          popularity: 88,
        ),
        ..._fromNav(
          NavigationConfig.adminNav,
          audience: 'staff',
          module: SearchResultModule.command,
          popularity: 90,
        ),
        ..._accountEntries,
        ..._sharedBrowseEntries,
      ];

  static List<SearchIndexEntry> forRole(AppRole? role) {
    return allEntries()
        .where((e) => isPathAllowedForRole(e.path, role))
        .toList();
  }

  static List<CommandPaletteAction> commandsForRole(AppRole? role) {
    return allEntries()
        .where((e) => isPathAllowedForRole(e.path, role))
        .map(
          (e) => CommandPaletteAction(
            id: e.id,
            label: e.title,
            routeOrKey: e.path,
            keywords: e.keywords,
            category: e.path.startsWith('/dashboard')
                ? 'admin'
                : e.path.startsWith('/investor')
                    ? 'investor'
                    : e.path.startsWith('/client')
                        ? 'client'
                        : 'navigate',
          ),
        )
        .toList();
  }

  /// Whether a result path is in-scope for the signed-in portal role.
  static bool isPathAllowedForRole(String path, AppRole? role) {
    if (path == NavItem.actionLogout || path.startsWith('__')) return false;
    if (role == null) return true;

    final isStaff = role == AppRole.superAdmin ||
        role == AppRole.admin ||
        role.isStaff;
    if (isStaff) return true;

    if (role == AppRole.client) {
      if (path.startsWith(RoutePaths.dashboard)) return false;
      if (path.startsWith(RoutePaths.investor)) return false;
      return true;
    }

    if (role == AppRole.investor) {
      if (path.startsWith(RoutePaths.dashboard)) return false;
      if (path.startsWith(RoutePaths.client)) return false;
      return true;
    }

    return true;
  }

  static const _accountEntries = <SearchIndexEntry>[
    SearchIndexEntry(
      id: 'portal-account-profile',
      module: SearchResultModule.workspace,
      title: 'Profile Center',
      subtitle: 'Name, contact, avatar',
      path: RoutePaths.profileCenter,
      keywords: ['profile', 'account', 'name', 'avatar', 'phone'],
      popularity: 92,
    ),
    SearchIndexEntry(
      id: 'portal-account-security',
      module: SearchResultModule.workspace,
      title: 'Security Center',
      subtitle: 'Password, MFA, trusted devices',
      path: RoutePaths.securityCenter,
      keywords: ['security', 'mfa', 'password', 'trust', 'sessions'],
      popularity: 91,
    ),
    SearchIndexEntry(
      id: 'portal-account-sessions',
      module: SearchResultModule.workspace,
      title: 'Active Sessions',
      subtitle: 'Devices signed in',
      path: RoutePaths.activeSessions,
      keywords: ['sessions', 'devices', 'sign out'],
      popularity: 70,
    ),
    SearchIndexEntry(
      id: 'portal-account-preferences',
      module: SearchResultModule.workspace,
      title: 'Preference Center',
      subtitle: 'Theme, accessibility, favorites',
      path: RoutePaths.preferenceCenter,
      keywords: ['preferences', 'theme', 'accessibility', 'favorites'],
      popularity: 85,
    ),
    SearchIndexEntry(
      id: 'portal-account-mfa',
      module: SearchResultModule.workspace,
      title: 'Enable MFA',
      subtitle: 'Authenticator setup',
      path: RoutePaths.mfaSetup,
      keywords: ['mfa', 'authenticator', '2fa', 'totp'],
      popularity: 80,
    ),
    SearchIndexEntry(
      id: 'portal-account-kyc',
      module: SearchResultModule.workspace,
      title: 'KYC Verification',
      subtitle: 'Identity documents',
      path: RoutePaths.kycVerification,
      keywords: ['kyc', 'verify', 'identity', 'documents'],
      popularity: 78,
    ),
    SearchIndexEntry(
      id: 'portal-account-verification',
      module: SearchResultModule.workspace,
      title: 'Verification Center',
      subtitle: 'Email and phone',
      path: RoutePaths.verificationCenter,
      keywords: ['email', 'phone', 'verify'],
      popularity: 76,
    ),
  ];

  static const _sharedBrowseEntries = <SearchIndexEntry>[
    SearchIndexEntry(
      id: 'portal-browse-properties',
      module: SearchResultModule.property,
      title: 'Browse Properties',
      subtitle: 'Marketplace listings',
      path: RoutePaths.properties,
      keywords: ['properties', 'homes', 'listings', 'marketplace', 'buy'],
      popularity: 95,
    ),
    SearchIndexEntry(
      id: 'portal-browse-search',
      module: SearchResultModule.property,
      title: 'Property Search',
      subtitle: 'Find homes',
      path: RoutePaths.search,
      keywords: ['search', 'find', 'filter'],
      popularity: 90,
    ),
    SearchIndexEntry(
      id: 'portal-browse-estates',
      module: SearchResultModule.estate,
      title: 'Estates',
      subtitle: 'Communities',
      path: RoutePaths.estates,
      keywords: ['estates', 'community'],
      popularity: 70,
    ),
    SearchIndexEntry(
      id: 'portal-browse-blog',
      module: SearchResultModule.blog,
      title: 'Blog',
      subtitle: 'News and guides',
      path: RoutePaths.blog,
      keywords: ['blog', 'articles', 'news'],
      popularity: 55,
    ),
    SearchIndexEntry(
      id: 'portal-book-inspection',
      module: SearchResultModule.service,
      title: 'Book Inspection',
      subtitle: 'Schedule a property visit',
      path: RoutePaths.bookInspection,
      keywords: ['inspection', 'book', 'visit', 'schedule'],
      popularity: 82,
    ),
  ];

  static List<SearchIndexEntry> _fromNav(
    List<NavItem> items, {
    required String audience,
    required SearchResultModule module,
    required int popularity,
  }) {
    final out = <SearchIndexEntry>[];
    void walk(NavItem item, [String? section]) {
      if (item.isSectionHeader) {
        for (final child in item.children) {
          walk(child, item.label);
        }
        return;
      }
      final path = item.path;
      if (path.isEmpty || path == NavItem.actionLogout || item.isAction) {
        for (final child in item.children) {
          walk(child, section);
        }
        return;
      }
      final id =
          'portal-$audience-${path.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '-')}';
      final keywords = <String>[
        item.label.toLowerCase(),
        audience,
        if (section != null) section.toLowerCase(),
        ...path.split('/').where((s) => s.isNotEmpty),
      ];
      out.add(
        SearchIndexEntry(
          id: id,
          module: module,
          title: item.label,
          subtitle: section == null
              ? '${audience[0].toUpperCase()}${audience.substring(1)} portal'
              : '$section · ${audience[0].toUpperCase()}${audience.substring(1)}',
          path: path,
          keywords: keywords,
          popularity: popularity,
        ),
      );
      for (final child in item.children) {
        walk(child, item.label);
      }
    }

    for (final item in items) {
      walk(item);
    }
    return out;
  }
}
