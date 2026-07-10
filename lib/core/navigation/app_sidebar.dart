import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/navigation/nav_item.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';

/// Reusable sidebar for client, investor, and admin portals.
class AppSidebar extends StatefulWidget {
  const AppSidebar({
    super.key,
    required this.items,
    this.collapsed = false,
    this.onToggle,
    this.header,
  });

  final List<NavItem> items;
  final bool collapsed;
  final VoidCallback? onToggle;
  final Widget? header;

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> {
  final _expanded = <String>{};

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final width = widget.collapsed ? 72.0 : 280.0;

    return AnimatedContainer(
      duration: AppDurations.fast,
      width: width,
      decoration: BoxDecoration(
        color: AppColors.charcoal,
        border: Border(
          right: BorderSide(color: AppColors.gray.withValues(alpha: 0.15)),
        ),
      ),
      child: Column(
        children: [
          if (widget.header != null)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.base),
              child: widget.header,
            ),
          if (widget.onToggle != null)
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: Icon(
                  widget.collapsed
                      ? Icons.chevron_right_rounded
                      : Icons.chevron_left_rounded,
                  color: AppColors.white,
                ),
                onPressed: widget.onToggle,
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              children: widget.items.map((item) => _buildItem(context, item, location)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, NavItem item, String location) {
    if (item.hasChildren && !widget.collapsed) {
      final isExpanded = _expanded.contains(item.label);
      final isGroupActive = item.children.any((c) => location.startsWith(c.path));

      return Column(
        children: [
          ListTile(
            leading: Icon(item.icon, color: AppColors.gray, size: AppIcons.md),
            title: Text(item.label, style: const TextStyle(color: AppColors.white)),
            trailing: Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              color: AppColors.gray,
            ),
            selected: isGroupActive,
            selectedTileColor: AppColors.gold.withValues(alpha: 0.1),
            onTap: () => setState(() {
              isExpanded ? _expanded.remove(item.label) : _expanded.add(item.label);
            }),
          ),
          if (isExpanded)
            for (final child in item.children)
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.base),
                child: _tile(context, child, location, dense: true),
              ),
        ],
      );
    }

    return _tile(context, item, location);
  }

  Widget _tile(BuildContext context, NavItem item, String location, {bool dense = false}) {
    final isActive = location == item.path || location.startsWith('${item.path}/');

    final tile = ListTile(
      dense: dense,
      leading: Icon(
        item.icon,
        color: isActive ? AppColors.gold : AppColors.gray,
        size: AppIcons.md,
      ),
      title: widget.collapsed
          ? null
          : Text(
              item.label,
              style: TextStyle(
                color: isActive ? AppColors.gold : AppColors.white,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
      selected: isActive,
      selectedTileColor: AppColors.gold.withValues(alpha: 0.12),
      onTap: () => context.go(item.path),
    );

    if (widget.collapsed) {
      return Tooltip(message: item.label, child: tile);
    }
    return tile;
  }
}

/// Bottom navigation for mobile portal views.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.items,
  });

  final List<NavItem> items;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = items.indexWhere(
      (item) => location == item.path || location.startsWith('${item.path}/'),
    );

    return NavigationBar(
      selectedIndex: currentIndex < 0 ? 0 : currentIndex,
      onDestinationSelected: (index) => context.go(items[index].path),
      destinations: [
        for (final item in items)
          NavigationDestination(
            icon: Icon(item.icon),
            label: item.label,
          ),
      ],
    );
  }
}
