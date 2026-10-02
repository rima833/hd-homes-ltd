import 'package:flutter/material.dart';

/// A single navigation entry for sidebars, drawers, and nav bars.
class NavItem {
  const NavItem({
    required this.label,
    required this.path,
    this.icon,
    this.children = const [],
    this.isDivider = false,
    this.isSectionHeader = false,
    this.badge,
    this.isDestructive = false,
    this.anyOfPermissions,
  });

  /// Section label only (e.g. MAIN / ACCOUNT). Not tappable.
  const NavItem.section(this.label)
      : path = '',
        icon = null,
        children = const [],
        isDivider = false,
        isSectionHeader = true,
        badge = null,
        isDestructive = false,
        anyOfPermissions = null;

  /// When set, the nav entry is shown only if the session has at least one slug.
  /// When null, any staff role with dashboard access may see the item.
  final List<String>? anyOfPermissions;

  final String label;
  final String path;
  final IconData? icon;
  final List<NavItem> children;
  final bool isDivider;
  final bool isSectionHeader;
  final int? badge;
  final bool isDestructive;

  bool get hasChildren => children.isNotEmpty;

  /// Sentinel path for actions handled by the portal shell (e.g. logout).
  static const actionLogout = '__logout__';

  bool get isAction => path.startsWith('__');

  NavItem copyWith({
    String? label,
    String? path,
    IconData? icon,
    List<NavItem>? children,
    int? badge,
    bool clearBadge = false,
    bool? isDestructive,
  }) {
    if (isSectionHeader) {
      return NavItem.section(label ?? this.label);
    }
    return NavItem(
      label: label ?? this.label,
      path: path ?? this.path,
      icon: icon ?? this.icon,
      children: children ?? this.children,
      isDivider: isDivider,
      isSectionHeader: isSectionHeader,
      badge: clearBadge ? null : (badge ?? this.badge),
      isDestructive: isDestructive ?? this.isDestructive,
      anyOfPermissions: anyOfPermissions,
    );
  }
}
