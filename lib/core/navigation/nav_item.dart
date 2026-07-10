import 'package:flutter/material.dart';

/// A single navigation entry for sidebars, drawers, and nav bars.
class NavItem {
  const NavItem({
    required this.label,
    required this.path,
    this.icon,
    this.children = const [],
    this.isDivider = false,
  });

  final String label;
  final String path;
  final IconData? icon;
  final List<NavItem> children;
  final bool isDivider;

  bool get hasChildren => children.isNotEmpty;
}
