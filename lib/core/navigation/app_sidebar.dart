import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/navigation/nav_item.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Visual language for portal sidebars.
class SidebarVisualTheme {
  const SidebarVisualTheme({
    required this.surfaceTop,
    required this.surfaceBottom,
    required this.accent,
    required this.accentSoft,
    required this.border,
    required this.activeFillStart,
    required this.activeFillEnd,
    this.cinematic = false,
  });

  final Color surfaceTop;
  final Color surfaceBottom;
  final Color accent;
  final Color accentSoft;
  final Color border;
  final Color activeFillStart;
  final Color activeFillEnd;
  final bool cinematic;

  static const standard = SidebarVisualTheme(
    surfaceTop: Color(0xFF12151C),
    surfaceBottom: Color(0xFF0E1015),
    accent: AppColors.gold,
    accentSoft: AppColors.goldLight,
    border: Color(0x26D4A34E),
    activeFillStart: Color(0x33D4A34E),
    activeFillEnd: Color(0x14D4A34E),
  );

  /// Warm gold command-center rail for admin.
  static const adminCinematic = SidebarVisualTheme(
    surfaceTop: Color(0xFF1A140C),
    surfaceBottom: Color(0xFF0B0C10),
    accent: Color(0xFFE8B84A),
    accentSoft: Color(0xFFF6D889),
    border: Color(0x55E8B84A),
    activeFillStart: Color(0xFFE0A830),
    activeFillEnd: Color(0xFF8A5A12),
    cinematic: true,
  );
}

/// Reusable sidebar for client, investor, and admin portals.
///
/// Collapse / expand uses a cinematic width glide with fading labels so
/// the rail never pops between states. Collapsed mode is an icon rail.
class AppSidebar extends StatefulWidget {
  const AppSidebar({
    super.key,
    required this.items,
    this.collapsed = false,
    this.onToggle,
    this.onSelect,
    this.header,
    this.footer,
    this.collapsedFooter,
    this.theme = SidebarVisualTheme.standard,
  });

  final List<NavItem> items;
  final bool collapsed;
  final VoidCallback? onToggle;
  /// Return true to consume the tap (e.g. logout) instead of routing.
  final bool Function(NavItem item)? onSelect;
  final Widget? header;
  final Widget? footer;
  final Widget? collapsedFooter;
  final SidebarVisualTheme theme;

  static const double expandedWidth = 280;
  static const double collapsedWidth = 84;

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar>
    with TickerProviderStateMixin {
  final _expanded = <String>{};
  late final AnimationController _rail;
  late final AnimationController _ambient;
  late final Animation<double> _widthFactor;
  late final Animation<double> _labelOpacity;
  late final Animation<double> _labelSlide;

  @override
  void initState() {
    super.initState();
    _rail = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
      value: widget.collapsed ? 0 : 1,
    );
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    );
    if (widget.theme.cinematic) {
      _ambient.repeat(reverse: true);
    }
    _widthFactor = CurvedAnimation(
      parent: _rail,
      curve: Curves.easeInOutCubicEmphasized,
      reverseCurve: Curves.easeInOutCubicEmphasized,
    );
    _labelOpacity = CurvedAnimation(
      parent: _rail,
      curve: const Interval(0.32, 1, curve: Curves.easeOutCubic),
      reverseCurve: const Interval(0, 0.5, curve: Curves.easeInCubic),
    );
    _labelSlide = Tween<double>(begin: -10, end: 0).animate(
      CurvedAnimation(
        parent: _rail,
        curve: const Interval(0.38, 1, curve: Curves.easeOutCubic),
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
    if (oldWidget.theme.cinematic != widget.theme.cinematic) {
      if (widget.theme.cinematic) {
        _ambient.repeat(reverse: true);
      } else {
        _ambient.stop();
      }
    }
  }

  @override
  void dispose() {
    _rail.dispose();
    _ambient.dispose();
    super.dispose();
  }

  void _activate(NavItem item) {
    if (widget.onSelect?.call(item) == true) return;
    if (item.path.isEmpty || item.isAction) return;
    context.go(item.path);
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final theme = widget.theme;

    return AnimatedBuilder(
      animation: Listenable.merge([_rail, _ambient]),
      builder: (context, _) {
        final width = AppSidebar.collapsedWidth +
            ((AppSidebar.expandedWidth - AppSidebar.collapsedWidth) *
                _widthFactor.value);
        final showLabels = _labelOpacity.value > 0.12;
        final ambient = theme.cinematic ? _ambient.value : 0.0;
        final glow = 0.08 + (0.14 * _widthFactor.value) + (0.08 * ambient);

        return ClipRect(
          child: SizedBox(
            width: width,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.surfaceTop,
                    Color.lerp(
                          theme.surfaceTop,
                          theme.surfaceBottom,
                          0.55 + (0.2 * ambient),
                        ) ??
                        theme.surfaceBottom,
                    theme.surfaceBottom,
                  ],
                  stops: const [0, 0.45, 1],
                ),
                border: Border(
                  right: BorderSide(
                    color: theme.accent.withValues(alpha: 0.12 + glow * 0.55),
                    width: theme.cinematic ? 1.4 : 1,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.accent.withValues(
                      alpha: theme.cinematic ? 0.12 + (0.08 * ambient) : 0.04,
                    ),
                    blurRadius: 28 * _widthFactor.value,
                    offset: Offset(10 * _widthFactor.value, 0),
                  ),
                  BoxShadow(
                    color: AppColors.deepBlack.withValues(alpha: 0.45),
                    blurRadius: 18 * _widthFactor.value,
                    offset: Offset(6 * _widthFactor.value, 0),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  if (theme.cinematic) ...[
                    Positioned(
                      top: -40 + (18 * ambient),
                      left: -30,
                      child: _AmbientOrb(
                        size: 140,
                        color: theme.accent.withValues(alpha: 0.18),
                      ),
                    ),
                    Positioned(
                      bottom: 80 - (12 * ambient),
                      right: -50,
                      child: _AmbientOrb(
                        size: 160,
                        color: theme.accentSoft.withValues(alpha: 0.1),
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment(-1, -1 + ambient),
                              end: Alignment(1, 1 - ambient),
                              colors: [
                                theme.accent.withValues(alpha: 0.07),
                                Colors.transparent,
                                theme.accentSoft.withValues(alpha: 0.05),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  Column(
                    children: [
                      _SidebarChrome(
                        collapsed: widget.collapsed,
                        progress: _widthFactor.value,
                        labelOpacity: _labelOpacity.value,
                        onToggle: widget.onToggle,
                        header: widget.header,
                        theme: theme,
                      ),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.sm,
                          ),
                          children: [
                            for (final item in widget.items)
                              _buildItem(
                                context,
                                item,
                                location,
                                showLabels: showLabels,
                                theme: theme,
                              ),
                          ],
                        ),
                      ),
                      _SidebarFooterSlot(
                        showLabels: showLabels,
                        labelOpacity: _labelOpacity.value,
                        footer: widget.footer,
                        collapsedFooter: widget.collapsedFooter,
                      ),
                    ],
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
    required SidebarVisualTheme theme,
  }) {
    if (item.isSectionHeader) {
      if (!showLabels) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          child: Opacity(
            opacity: (1 - _labelOpacity.value).clamp(0.0, 0.35),
            child: Divider(
              height: 1,
              color: theme.accent.withValues(alpha: 0.16),
            ),
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
        child: Opacity(
          opacity: _labelOpacity.value.clamp(0.0, 1.0),
          child: Text(
            item.label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: theme.accentSoft.withValues(alpha: 0.72),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
          ),
        ),
      );
    }

    if (item.isDivider) {
      return Divider(
        height: 24,
        color: theme.accent.withValues(alpha: 0.14),
      );
    }

    if (item.hasChildren && showLabels) {
      final isExpanded = _expanded.contains(item.label);
      final isGroupActive =
          item.children.any((c) => location.startsWith(c.path));

      return Column(
        children: [
          _NavRow(
            item: item,
            isActive: isGroupActive,
            showLabels: showLabels,
            labelOpacity: _labelOpacity.value,
            labelSlide: _labelSlide.value,
            theme: theme,
            trailing: AnimatedRotation(
              turns: isExpanded ? 0.5 : 0,
              duration: AppDurations.fast,
              curve: Curves.easeOutCubic,
              child: Icon(
                LucideIcons.chevronDown,
                size: 16,
                color: isGroupActive ? theme.accentSoft : AppColors.slate400,
              ),
            ),
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
                        _tile(
                          context,
                          child,
                          location,
                          showLabels: showLabels,
                          indent: true,
                          theme: theme,
                        ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      );
    }

    if (item.hasChildren && !showLabels) {
      final target = item.children.isNotEmpty ? item.children.first : item;
      return _tile(
        context,
        target,
        location,
        showLabels: false,
        tooltip: item.label,
        theme: theme,
      );
    }

    return _tile(
      context,
      item,
      location,
      showLabels: showLabels,
      theme: theme,
    );
  }

  Widget _tile(
    BuildContext context,
    NavItem item,
    String location, {
    required bool showLabels,
    required SidebarVisualTheme theme,
    bool indent = false,
    String? tooltip,
  }) {
    final isRootPortal = item.path == '/client' ||
        item.path == '/investor' ||
        item.path == '/dashboard';
    final isActive = isRootPortal
        ? location == item.path
        : location == item.path || location.startsWith('${item.path}/');

    return _NavRow(
      item: item,
      isActive: isActive,
      showLabels: showLabels,
      labelOpacity: _labelOpacity.value,
      labelSlide: _labelSlide.value,
      indent: indent,
      tooltip: tooltip,
      theme: theme,
      onTap: () => _activate(item),
    );
  }
}

class _AmbientOrb extends StatelessWidget {
  const _AmbientOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color,
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

class _SidebarChrome extends StatelessWidget {
  const _SidebarChrome({
    required this.collapsed,
    required this.progress,
    required this.labelOpacity,
    required this.onToggle,
    required this.header,
    required this.theme,
  });

  final bool collapsed;
  final double progress;
  final double labelOpacity;
  final VoidCallback? onToggle;
  final Widget? header;
  final SidebarVisualTheme theme;

  @override
  Widget build(BuildContext context) {
    final toggle = onToggle == null
        ? const SizedBox.shrink()
        : Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.accent.withValues(alpha: 0.28),
              ),
              color: theme.accent.withValues(alpha: 0.08),
            ),
            child: IconButton(
              tooltip: collapsed ? 'Expand sidebar' : 'Collapse sidebar',
              onPressed: onToggle,
              icon: Icon(
                LucideIcons.menu,
                color: theme.accentSoft,
                size: 18,
              ),
            ),
          );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        collapsed ? 10 : 10,
        14,
        collapsed ? 10 : 14,
        10,
      ),
      child: progress < 0.45
          ? Column(children: [if (onToggle != null) toggle])
          : Row(
              children: [
                if (onToggle != null) toggle,
                if (header != null)
                  Expanded(
                    child: ClipRect(
                      child: Opacity(
                        opacity: labelOpacity.clamp(0.0, 1.0),
                        child: header,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _SidebarFooterSlot extends StatelessWidget {
  const _SidebarFooterSlot({
    required this.showLabels,
    required this.labelOpacity,
    required this.footer,
    required this.collapsedFooter,
  });

  final bool showLabels;
  final double labelOpacity;
  final Widget? footer;
  final Widget? collapsedFooter;

  @override
  Widget build(BuildContext context) {
    if (footer == null && collapsedFooter == null) {
      return const SizedBox.shrink();
    }
    if (!showLabels) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
        child: collapsedFooter ?? const SizedBox.shrink(),
      );
    }
    if (footer == null) return const SizedBox.shrink();
    return Opacity(
      opacity: labelOpacity.clamp(0.0, 1.0),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        child: footer!,
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.item,
    required this.isActive,
    required this.showLabels,
    required this.labelOpacity,
    required this.labelSlide,
    required this.onTap,
    required this.theme,
    this.trailing,
    this.indent = false,
    this.tooltip,
  });

  final NavItem item;
  final bool isActive;
  final bool showLabels;
  final double labelOpacity;
  final double labelSlide;
  final VoidCallback onTap;
  final SidebarVisualTheme theme;
  final Widget? trailing;
  final bool indent;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final color = item.isDestructive
        ? const Color(0xFFF87171)
        : isActive
            ? (theme.cinematic ? AppColors.deepBlack : theme.accentSoft)
            : AppColors.white;
    final iconColor = item.isDestructive
        ? const Color(0xFFF87171)
        : isActive
            ? (theme.cinematic ? AppColors.deepBlack : theme.accent)
            : AppColors.slate400;
    final badge = item.badge;

    final decoration = isActive
        ? BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.activeFillStart,
                theme.activeFillEnd,
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: theme.accent.withValues(alpha: theme.cinematic ? 0.55 : 0.4),
            ),
            boxShadow: [
              BoxShadow(
                color: theme.accent.withValues(alpha: theme.cinematic ? 0.35 : 0.18),
                blurRadius: theme.cinematic ? 22 : 14,
                offset: const Offset(0, 4),
              ),
            ],
          )
        : BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.transparent),
          );

    final row = Padding(
      padding: EdgeInsets.fromLTRB(indent ? 16 : 10, 3, 10, 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          hoverColor: theme.accent.withValues(alpha: 0.08),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            height: 50,
            padding: EdgeInsets.symmetric(horizontal: showLabels ? 12 : 0),
            decoration: decoration,
            child: Row(
              children: [
                if (!showLabels) const Spacer(),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Center(
                        child: Icon(item.icon, color: iconColor, size: 20),
                      ),
                      if (!showLabels && badge != null && badge > 0)
                        Positioned(
                          top: -4,
                          right: -6,
                          child: _Badge(count: badge, theme: theme),
                        ),
                    ],
                  ),
                ),
                if (showLabels) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Opacity(
                      opacity: labelOpacity.clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(labelSlide, 0),
                        child: Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: color,
                            fontWeight:
                                isActive ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 14,
                            letterSpacing: isActive ? 0.2 : 0,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (trailing != null)
                    Opacity(
                      opacity: labelOpacity.clamp(0.0, 1.0),
                      child: trailing,
                    )
                  else if (badge != null && badge > 0)
                    Opacity(
                      opacity: labelOpacity.clamp(0.0, 1.0),
                      child: _Badge(count: badge, theme: theme),
                    ),
                ] else
                  const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );

    if (!showLabels) {
      return Tooltip(message: tooltip ?? item.label, child: row);
    }
    return row;
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count, required this.theme});

  final int count;
  final SidebarVisualTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.accentSoft, theme.accent],
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: theme.accent.withValues(alpha: 0.35),
            blurRadius: 8,
          ),
        ],
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.charcoal,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
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

  /// Prefer the longest matching path so `/investor` does not steal
  /// `/investor/portfolio` (and similarly for other portals).
  static int indexForLocation(List<NavItem> items, String location) {
    var best = -1;
    var bestLen = -1;
    for (var i = 0; i < items.length; i++) {
      final path = items[i].path;
      if (path.isEmpty || path.startsWith('__')) continue;
      final match =
          location == path || location.startsWith('$path/');
      if (match && path.length > bestLen) {
        best = i;
        bestLen = path.length;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = indexForLocation(items, location);

    return NavigationBar(
      selectedIndex: currentIndex < 0 ? 0 : currentIndex,
      onDestinationSelected: (index) => context.go(items[index].path),
      destinations: [
        for (final item in items)
          NavigationDestination(
            icon: Icon(item.icon),
            label: item.label,
            tooltip: item.label,
          ),
      ],
    );
  }
}
