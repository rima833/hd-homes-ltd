import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/navigation/nav_item.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';

/// Reusable sidebar for client, investor, and admin portals.
///
/// Collapse / expand uses a cinematic width glide with fading labels so
/// the rail never pops between states.
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

  static const double expandedWidth = 280;
  static const double collapsedWidth = 76;

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar>
    with SingleTickerProviderStateMixin {
  final _expanded = <String>{};
  late final AnimationController _rail;
  late final Animation<double> _widthFactor;
  late final Animation<double> _labelOpacity;
  late final Animation<double> _labelSlide;

  @override
  void initState() {
    super.initState();
    _rail = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      value: widget.collapsed ? 0 : 1,
    );
    _widthFactor = CurvedAnimation(
      parent: _rail,
      curve: Curves.easeInOutCubicEmphasized,
      reverseCurve: Curves.easeInOutCubicEmphasized,
    );
    _labelOpacity = CurvedAnimation(
      parent: _rail,
      curve: const Interval(0.28, 1, curve: Curves.easeOutCubic),
      reverseCurve: const Interval(0, 0.55, curve: Curves.easeInCubic),
    );
    _labelSlide = Tween<double>(begin: -8, end: 0).animate(
      CurvedAnimation(
        parent: _rail,
        curve: const Interval(0.35, 1, curve: Curves.easeOutCubic),
      ),
    );
  }

  @override
  void didUpdateWidget(covariant AppSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.collapsed != widget.collapsed) {
      if (widget.collapsed) {
        _rail.reverse();
      } else {
        _rail.forward();
      }
    }
  }

  @override
  void dispose() {
    _rail.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    return AnimatedBuilder(
      animation: _rail,
      builder: (context, _) {
        final width = AppSidebar.collapsedWidth +
            ((AppSidebar.expandedWidth - AppSidebar.collapsedWidth) *
                _widthFactor.value);
        final showLabels = _labelOpacity.value > 0.08;
        final glow = 0.04 + (0.08 * _widthFactor.value);

        return ClipRect(
          child: SizedBox(
            width: width,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.charcoal,
                    Color.lerp(
                          AppColors.charcoal,
                          AppColors.deepBlack,
                          0.35 + (0.25 * (1 - _widthFactor.value)),
                        ) ??
                        AppColors.charcoal,
                  ],
                ),
                border: Border(
                  right: BorderSide(
                    color: AppColors.gold.withValues(alpha: 0.08 + glow),
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.deepBlack.withValues(alpha: 0.35),
                    blurRadius: 18 * _widthFactor.value,
                    offset: Offset(6 * _widthFactor.value, 0),
                  ),
                ],
              ),
              child: Column(
                children: [
                  if (widget.header != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.base,
                        AppSpacing.md,
                        AppSpacing.sm,
                      ),
                      child: ClipRect(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          widthFactor: (0.42 + (0.58 * _widthFactor.value))
                              .clamp(0.42, 1.0),
                          child: Opacity(
                            opacity: (0.55 + (0.45 * _labelOpacity.value))
                                .clamp(0.0, 1.0),
                            child: widget.header,
                          ),
                        ),
                      ),
                    ),
                  if (widget.onToggle != null)
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _SidebarToggle(
                          collapsed: widget.collapsed,
                          progress: _widthFactor,
                          onPressed: widget.onToggle!,
                        ),
                      ),
                    ),
                  Expanded(
                    child: ListView(
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      children: [
                        for (final item in widget.items)
                          _buildItem(
                            context,
                            item,
                            location,
                            showLabels: showLabels,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildItem(
    BuildContext context,
    NavItem item,
    String location, {
    required bool showLabels,
  }) {
    if (item.hasChildren && showLabels) {
      final isExpanded = _expanded.contains(item.label);
      final isGroupActive =
          item.children.any((c) => location.startsWith(c.path));

      return Column(
        children: [
          ListTile(
            leading: Icon(item.icon, color: AppColors.gray, size: AppIcons.md),
            title: Opacity(
              opacity: _labelOpacity.value.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(_labelSlide.value, 0),
                child: Text(
                  item.label,
                  style: const TextStyle(color: AppColors.white),
                ),
              ),
            ),
            trailing: AnimatedRotation(
              turns: isExpanded ? 0.5 : 0,
              duration: AppDurations.fast,
              curve: Curves.easeOutCubic,
              child: const Icon(Icons.expand_more, color: AppColors.gray),
            ),
            selected: isGroupActive,
            selectedTileColor: AppColors.gold.withValues(alpha: 0.1),
            onTap: () => setState(() {
              isExpanded
                  ? _expanded.remove(item.label)
                  : _expanded.add(item.label);
            }),
          ),
          AnimatedSize(
            duration: AppDurations.normal,
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            child: isExpanded
                ? Column(
                    children: [
                      for (final child in item.children)
                        Padding(
                          padding: const EdgeInsets.only(left: AppSpacing.base),
                          child: _tile(
                            context,
                            child,
                            location,
                            dense: true,
                            showLabels: showLabels,
                          ),
                        ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      );
    }

    // Collapsed rail: parent with children becomes first-child shortcut + tooltip.
    if (item.hasChildren && !showLabels) {
      final target = item.children.isNotEmpty ? item.children.first : item;
      return _tile(context, target, location, showLabels: false, tooltip: item.label);
    }

    return _tile(context, item, location, showLabels: showLabels);
  }

  Widget _tile(
    BuildContext context,
    NavItem item,
    String location, {
    bool dense = false,
    required bool showLabels,
    String? tooltip,
  }) {
    final isActive =
        location == item.path || location.startsWith('${item.path}/');

    final tile = ListTile(
      dense: dense,
      contentPadding: EdgeInsets.symmetric(
        horizontal: showLabels ? AppSpacing.md : AppSpacing.sm,
      ),
      leading: AnimatedContainer(
        duration: AppDurations.fast,
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.gold.withValues(alpha: 0.16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          item.icon,
          color: isActive ? AppColors.gold : AppColors.gray,
          size: AppIcons.md,
        ),
      ),
      title: showLabels
          ? Opacity(
              opacity: _labelOpacity.value.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(_labelSlide.value, 0),
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isActive ? AppColors.gold : AppColors.white,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            )
          : null,
      selected: isActive,
      selectedTileColor: AppColors.gold.withValues(alpha: 0.08),
      onTap: () => context.go(item.path),
    );

    if (!showLabels) {
      return Tooltip(message: tooltip ?? item.label, child: tile);
    }
    return tile;
  }
}

class _SidebarToggle extends StatelessWidget {
  const _SidebarToggle({
    required this.collapsed,
    required this.progress,
    required this.onPressed,
  });

  final bool collapsed;
  final Animation<double> progress;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: collapsed ? 'Expand sidebar' : 'Collapse sidebar',
      onPressed: onPressed,
      icon: AnimatedBuilder(
        animation: progress,
        builder: (context, _) {
          return Transform.rotate(
            angle: (1 - progress.value) * 3.14159,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.22),
                ),
              ),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Icons.chevron_left_rounded,
                  color: AppColors.white,
                ),
              ),
            ),
          );
        },
      ),
    );
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
