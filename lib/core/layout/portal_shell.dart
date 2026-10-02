import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/layout/responsive_utils.dart';
import 'package:hdhomesproject/core/navigation/app_sidebar.dart';
import 'package:hdhomesproject/core/navigation/breadcrumbs.dart';
import 'package:hdhomesproject/core/navigation/nav_item.dart';
// AppBottomNav lives in app_sidebar.dart
import 'package:hdhomesproject/core/theme/app_theme.dart';
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
    this.contentPadding,
    this.showBrandLogo = false,
    this.showSearch = true,
    this.forceDrawerChrome = false,
    this.sidebarHeader,
    this.sidebarFooter,
    this.collapsedSidebarFooter,
    this.sidebarCollapsed,
    this.onSidebarCollapsedChanged,
    this.onNavSelect,
    this.permanentSidebarMinWidth,
    this.backgroundColor,
    this.headerBackgroundColor,
    this.headerBorderColor,
    this.sidebarTheme = SidebarVisualTheme.standard,
    this.reserveHeaderTitleSpace = true,
    this.showHeader = true,
  });

  final Widget child;
  final String title;
  final List<NavItem> navItems;
  final List<NavItem>? bottomNavItems;
  final List<BreadcrumbItem> breadcrumbs;
  final List<Widget>? actions;
  final EdgeInsets? contentPadding;
  final bool showBrandLogo;
  final bool showSearch;
  final bool forceDrawerChrome;
  final Widget? sidebarHeader;
  final Widget? sidebarFooter;
  final Widget? collapsedSidebarFooter;
  final bool? sidebarCollapsed;
  final ValueChanged<bool>? onSidebarCollapsedChanged;
  final bool Function(NavItem item)? onNavSelect;

  /// When set, the icon/label rail stays on screen from this width up.
  final double? permanentSidebarMinWidth;
  final Color? backgroundColor;
  final Color? headerBackgroundColor;
  final Color? headerBorderColor;
  final SidebarVisualTheme sidebarTheme;
  final bool reserveHeaderTitleSpace;

  /// When false, the portal title, search, and header actions are not shown.
  /// The page owns the full content height. Use [PortalShellMenu] to open the
  /// drawer on narrow screens.
  final bool showHeader;

  @override
  State<PortalShell> createState() => _PortalShellState();
}

class _PortalShellState extends State<PortalShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _sidebarCollapsed = false;

  bool get _collapsed => widget.sidebarCollapsed ?? _sidebarCollapsed;

  void _toggleSidebar() {
    final next = !_collapsed;
    widget.onSidebarCollapsedChanged?.call(next);
    if (widget.sidebarCollapsed == null) {
      setState(() => _sidebarCollapsed = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final minRail = widget.permanentSidebarMinWidth ?? AppBreakpoints.laptop;
    final showSidebar =
        !widget.forceDrawerChrome && context.screenWidth >= minRail;
    final useBottomNav =
        !showSidebar &&
        !widget.forceDrawerChrome &&
        ResponsiveUtils.useBottomNavigation(context.screenWidth);

    final sidebarHeader =
        widget.sidebarHeader ??
        Padding(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Text(
            widget.title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.gold,
              fontWeight: FontWeight.w700,
            ),
          ),
        );

    final sidebar = AppSidebar(
      items: widget.navItems,
      collapsed: showSidebar ? _collapsed : false,
      onToggle: showSidebar ? _toggleSidebar : null,
      onSelect: widget.onNavSelect,
      header: sidebarHeader,
      footer: widget.sidebarFooter,
      collapsedFooter: widget.collapsedSidebarFooter,
      theme: widget.sidebarTheme,
    );

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: widget.backgroundColor ?? AppColors.deepBlack,
      drawer: showSidebar
          ? null
          : Drawer(
              backgroundColor: widget.sidebarTheme.surfaceBottom,
              child: AppSidebar(
                items: widget.navItems,
                header: sidebarHeader,
                footer: widget.sidebarFooter,
                onSelect: widget.onNavSelect,
                theme: widget.sidebarTheme,
              ),
            ),
      body: Row(
        children: [
          if (showSidebar) sidebar,
          Expanded(
            child: PortalShellMenu(
              openDrawer: () => _scaffoldKey.currentState?.openDrawer(),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.showHeader)
                _PortalHeader(
                  title: widget.title,
                  showMenu: !showSidebar,
                  onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
                  actions: widget.actions,
                  showBrandLogo: widget.showBrandLogo,
                  showSearch: widget.showSearch,
                  reserveTitleSpace: widget.reserveHeaderTitleSpace,
                  backgroundColor:
                      widget.headerBackgroundColor ?? AppColors.charcoal,
                  borderColor:
                      widget.headerBorderColor ??
                      AppColors.gray.withValues(alpha: 0.15),
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
                    padding:
                        widget.contentPadding ??
                        EdgeInsets.all(context.pagePadding),
                    child: widget.child,
                  ),
                ),
              ],
            ),
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

/// Opens the portal drawer when the shell header is hidden.
class PortalShellMenu extends InheritedWidget {
  const PortalShellMenu({
    super.key,
    required this.openDrawer,
    required super.child,
  });

  final VoidCallback openDrawer;

  static PortalShellMenu? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<PortalShellMenu>();
  }

  @override
  bool updateShouldNotify(PortalShellMenu oldWidget) => false;
}

class _PortalHeader extends StatelessWidget {
  const _PortalHeader({
    required this.title,
    required this.showMenu,
    required this.onMenuTap,
    this.actions,
    this.showBrandLogo = false,
    this.showSearch = true,
    this.reserveTitleSpace = true,
    this.backgroundColor = AppColors.charcoal,
    this.borderColor,
  });

  final String title;
  final bool showMenu;
  final VoidCallback onMenuTap;
  final List<Widget>? actions;
  final bool showBrandLogo;
  final bool showSearch;
  final bool reserveTitleSpace;
  final Color backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          bottom: BorderSide(
            color: borderColor ?? AppColors.gray.withValues(alpha: 0.15),
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (showMenu)
                IconButton(
                  icon: const Icon(Icons.menu_rounded, color: AppColors.white),
                  tooltip: 'Menu',
                  onPressed: onMenuTap,
                ),
              if (reserveTitleSpace)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: showBrandLogo
                      ? Align(
                          alignment: Alignment.centerLeft,
                          child: Image.asset(
                            AppTheme.logoAsset,
                            height: 28,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => Text(
                              'HD HOMES',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: AppColors.gold,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6,
                                  ),
                            ),
                          ),
                        )
                      : title.trim().isEmpty
                      ? const SizedBox.shrink()
                      : Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: AppColors.white,
                                fontWeight: FontWeight.w600,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                )
              else if (showBrandLogo)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: Image.asset(
                    AppTheme.logoAsset,
                    height: 28,
                    fit: BoxFit.contain,
                  ),
                )
              else if (title.trim().isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.base),
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ),
              const Spacer(),
              if (actions != null)
                Flexible(
                  flex: 3,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      reverse: true,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: actions!,
                      ),
                    ),
                  ),
                ),
              if (showSearch)
                IconButton(
                  icon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.white,
                  ),
                  tooltip: 'Search (Ctrl+K)',
                  onPressed: () => CommandPaletteScope.maybeOf(context)?.open(),
                ),
            ],
          ),
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
    return context.dependOnInheritedWidgetOfExactType<CommandPaletteScope>();
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
