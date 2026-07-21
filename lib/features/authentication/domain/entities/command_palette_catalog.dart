/// Unified Command Palette — foundation catalog (Part 13).
///
/// Full search UX lands in Part 14 (Enterprise Search & Global Command Center).
/// Palette entries respect permissions via [requiredPermission] when wired.
library;

class CommandPaletteAction {
  const CommandPaletteAction({
    required this.id,
    required this.label,
    required this.routeOrKey,
    this.keywords = const [],
    this.requiredPermission,
    this.category = 'navigate',
  });

  final String id;
  final String label;
  final String routeOrKey;
  final List<String> keywords;
  final String? requiredPermission;
  final String category;
}

abstract final class CommandPaletteCatalog {
  static const actions = <CommandPaletteAction>[
    CommandPaletteAction(
      id: 'go-preferences',
      label: 'Open Preference Center',
      routeOrKey: '/account/preferences',
      keywords: ['theme', 'accessibility', 'favorites'],
    ),
    CommandPaletteAction(
      id: 'go-profile',
      label: 'Open Profile Center',
      routeOrKey: '/account/profile',
      keywords: ['account', 'name'],
    ),
    CommandPaletteAction(
      id: 'go-notifications',
      label: 'Open Notifications',
      routeOrKey: '/account/notifications',
      keywords: ['alerts', 'inbox'],
    ),
    CommandPaletteAction(
      id: 'book-inspection',
      label: 'Book Inspection',
      routeOrKey: '/book-inspection',
      keywords: ['visit', 'schedule'],
      category: 'create',
    ),
    CommandPaletteAction(
      id: 'search-properties',
      label: 'Search Properties',
      routeOrKey: '/search',
      keywords: ['listings', 'homes'],
      category: 'search',
    ),
    CommandPaletteAction(
      id: 'rbac-console',
      label: 'Roles & Permissions',
      routeOrKey: '/dashboard/roles',
      requiredPermission: 'manage_roles',
      keywords: ['rbac', 'access'],
      category: 'admin',
    ),
  ];

  static List<CommandPaletteAction> filter(
    String query, {
    Set<String> permissions = const {},
    bool isStaff = false,
  }) {
    final q = query.trim().toLowerCase();
    return actions.where((a) {
      if (a.requiredPermission != null &&
          !permissions.contains(a.requiredPermission) &&
          !isStaff) {
        return false;
      }
      if (q.isEmpty) return true;
      final hay = [a.label, a.id, ...a.keywords].join(' ').toLowerCase();
      return hay.contains(q);
    }).toList();
  }
}
