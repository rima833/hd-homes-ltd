import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/layout/responsive_utils.dart';
import 'package:hdhomesproject/core/navigation/app_sidebar.dart';
import 'package:hdhomesproject/core/navigation/breadcrumbs.dart';
import 'package:hdhomesproject/core/navigation/nav_item.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';

/// Shared portal shell for client, investor, and admin applications.
///
/// Child pages may include their own [Scaffold]. Do not wrap [child] in an
/// unbounded [SingleChildScrollView] — that causes infinite-height layout
/// failures and InheritedWidget dispose crashes (`_dependents.isEmpty`).
class PortalShell extends StatefulWidget {
  const PortalShell({
    super.key,
    required this.child,
    required this.title,
    required this.navItems,
    this.bottomNavItems,
    this.breadcrumbs = const [],
    this.actions,
  });

  final Widget child;
  final String title;
  final List<NavItem> navItems;
  final List<NavItem>? bottomNavItems;
  final List<BreadcrumbItem> breadcrumbs;
  final List<Widget>? actions;

  @override
  State<PortalShell> createState() => _PortalShellState();
}

class _PortalShellState extends State<PortalShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _sidebarCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final showSidebar =
        ResponsiveUtils.showPermanentSidebar(context.screenWidth);
    final useBottomNav =
        ResponsiveUtils.useBottomNavigation(context.screenWidth);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.deepBlack,
      drawer: showSidebar
          ? null
          : Drawer(
              child: AppSidebar(items: widget.navItems),
            ),
      body: Row(
        children: [
          if (showSidebar)
            AppSidebar(
              items: widget.navItems,
              collapsed: _sidebarCollapsed,
              onToggle: () =>
                  setState(() => _sidebarCollapsed = !_sidebarCollapsed),
              header: Padding(
                padding: const EdgeInsets.all(AppSpacing.base),
                child: Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.gold,
                      ),
                ),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PortalHeader(
                  title: widget.title,
                  showMenu: !showSidebar,
                  onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
                  actions: widget.actions,
                ),
                if (widget.breadcrumbs.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      context.pagePadding,
                      AppSpacing.sm,
                      context.pagePadding,
                      0,
                    ),
                    child: AppBreadcrumbs(items: widget.breadcrumbs),
                  ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(context.pagePadding),
                    child: widget.child,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: useBottomNav && widget.bottomNavItems != null
          ? AppBottomNav(items: widget.bottomNavItems!)
          : null,
    );
  }
}

class _PortalHeader extends StatelessWidget {
  const _PortalHeader({
    required this.title,
    required this.showMenu,
    required this.onMenuTap,
    this.actions,
  });

  final String title;
  final bool showMenu;
  final VoidCallback onMenuTap;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.charcoal,
        border: Border(
          bottom: BorderSide(color: AppColors.gray.withValues(alpha: 0.15)),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            if (showMenu)
              IconButton(
                icon: const Icon(Icons.menu_rounded, color: AppColors.white),
                onPressed: onMenuTap,
              ),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.white,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (actions != null) ...actions!,
            IconButton(
              icon: const Icon(Icons.search_rounded, color: AppColors.white),
              tooltip: 'Search (Ctrl+K)',
              onPressed: () => CommandPaletteScope.maybeOf(context)?.open(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Inherited widget to open the global command palette from anywhere.
class CommandPaletteScope extends InheritedWidget {
  const CommandPaletteScope({
    super.key,
    required this.open,
    required super.child,
  });

  final VoidCallback open;

  static CommandPaletteScope? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<CommandPaletteScope>();
  }

  static CommandPaletteScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(
      scope != null,
      'CommandPaletteScope.of() called with no CommandPalette ancestor.',
    );
    return scope!;
  }

  @override
  bool updateShouldNotify(CommandPaletteScope oldWidget) => false;
}
