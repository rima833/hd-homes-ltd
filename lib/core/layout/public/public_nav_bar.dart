import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/navigation/deferred_navigation.dart';
import 'package:hdhomesproject/core/navigation/nav_item.dart';
import 'package:hdhomesproject/core/navigation/navigation_config.dart';
import 'package:hdhomesproject/core/theme/app_theme.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/l10n/app_strings.dart';
import 'package:hdhomesproject/core/widgets/buttons/book_inspection_hub_cta.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/identity_provider.dart';
import 'package:hdhomesproject/core/layout/public/published_chrome.dart';
import 'package:hdhomesproject/features/settings/domain/entities/platform_settings.dart';
import 'package:hdhomesproject/features/settings/domain/entities/public_website_gates.dart';
import 'package:hdhomesproject/features/settings/presentation/providers/platform_settings_providers.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Sticky public website navigation with glass effect on scroll.
class PublicNavBar extends ConsumerWidget {
  const PublicNavBar({
    super.key,
    required this.scrolled,
    required this.onMenuTap,
    this.onSearchTap,
  });

  final bool scrolled;
  final VoidCallback onMenuTap;
  final VoidCallback? onSearchTap;

  List<NavItem> _headerNavLinks(WidgetRef ref) {
    final settings = ref.watch(publishedPlatformSettingsProvider).valueOrNull;
    final published = ref.watch(publishedHeaderNavProvider);
    final source = published ??
        [
          for (final path in NavigationConfig.publicHeaderPaths)
            NavigationConfig.publicNavByPath(path)!,
        ];

    return [
      for (final item in withPublicDropdowns(source))
        if (settings == null || settings.allowsPublicPath(item.path))
          if (!(item.path == RoutePaths.blog && !(settings?.enableBlog ?? true)))
            _gateChildren(item, settings),
    ];
  }

  NavItem _gateChildren(NavItem item, PlatformSettingsBundle? settings) {
    if (settings == null || !item.hasChildren) return item;
    return item.copyWith(
      children: [
        for (final child in item.children)
          if (settings.allowsPublicPath(child.path)) child,
      ],
    );
  }

  void _openInvest(BuildContext context, WidgetRef ref) {
    // Public investment hub — never block the tap on a login redirect.
    final session = ref.read(identitySessionProvider);
    final path = session.isAuthenticated && session.canAccessInvestorPortal
        ? RoutePaths.investor
        : RoutePaths.investment;
    goDeferred(context, path);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navItems = _headerNavLinks(ref);
    final desktop = context.isLaptop || context.isDesktop;

    final bar = AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: scrolled
            ? (isDark
                  ? AppColors.deepBlack.withValues(alpha: 0.78)
                  : AppColors.white.withValues(alpha: 0.88))
            : Colors.transparent,
        border: scrolled
            ? Border(
                bottom: BorderSide(
                  color: AppColors.gold.withValues(alpha: 0.12),
                ),
              )
            : null,
        boxShadow: scrolled
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.pagePadding,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => goDeferred(context, RoutePaths.home),
                child: Image.asset(AppTheme.logoAsset, height: 40),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (desktop)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 320),
                            curve: Curves.easeOutCubic,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: scrolled
                                  ? Colors.white.withValues(alpha: 0.04)
                                  : Colors.black.withValues(alpha: 0.18),
                              border: Border.all(
                                color: AppColors.gold.withValues(
                                  alpha: scrolled ? 0.18 : 0.12,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (final item in navItems)
                                  _NavLink(item: item),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              _NavIconButton(
                tooltip: AppStrings.navSearch,
                icon: LucideIcons.search,
                onPressed: onSearchTap,
              ),
              TextButton(
                onPressed: () => goDeferred(context, RoutePaths.login),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                ),
                child: const Text(AppStrings.navLogin),
              ),
              // Pinned right — Invest then Book Inspection/Contact Hub CTA.
              // Keep CTAs outside Expanded so they never get clipped away.
              if (!context.isMobile) ...[
                const SizedBox(width: AppSpacing.sm),
                if (context.screenWidth >= 1280)
                  _InvestWithUsButton(
                    onPressed: () => _openInvest(context, ref),
                  ),
                if (context.screenWidth >= 1280)
                  const SizedBox(width: AppSpacing.sm),
                const BookInspectionHubCta(),
              ] else
                IconButton(
                  icon: const Icon(Icons.menu_rounded),
                  onPressed: onMenuTap,
                ),
            ],
          ),
        ),
      ),
    );

    // BackdropFilter freezes Flutter web on some GPUs — skip it there.
    if (!scrolled || kIsWeb) return bar;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: bar,
      ),
    );
  }
}

class _NavIconButton extends StatefulWidget {
  const _NavIconButton({
    required this.tooltip,
    required this.icon,
    this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  State<_NavIconButton> createState() => _NavIconButtonState();
}

class _NavIconButtonState extends State<_NavIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _hovered ? AppColors.gold.withValues(alpha: 0.12) : null,
        ),
        child: IconButton(
          tooltip: widget.tooltip,
          onPressed: widget.onPressed,
          icon: Icon(widget.icon, color: _hovered ? AppColors.gold : null),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

/// Gold-outlined CTA — sits left of the rotating Book Inspection / Contact Hub.
class _InvestWithUsButton extends StatelessWidget {
  const _InvestWithUsButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.gold,
        backgroundColor: AppColors.gold.withValues(alpha: 0.08),
        side: BorderSide(
          color: AppColors.gold.withValues(alpha: 0.85),
          width: 1.2,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.sm,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: const Text(
        AppStrings.navInvest,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.2),
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink({required this.item});

  final NavItem item;

  bool _isActive(String location) {
    if (location == item.path) return true;
    if (item.path == RoutePaths.properties) {
      return location == RoutePaths.paymentCalculator ||
          location == RoutePaths.construction ||
          location.startsWith('${RoutePaths.properties}/') ||
          location.startsWith('${RoutePaths.construction}/');
    }
    if (item.path == RoutePaths.investment) {
      return location == RoutePaths.roiCalculator ||
          location.startsWith('${RoutePaths.investment}/');
    }
    if (item.path == RoutePaths.discover) {
      return item.children.any(
        (c) =>
            location == c.path ||
            (c.path != RoutePaths.home && location.startsWith('${c.path}/')),
      );
    }
    return item.children.any((c) => location == c.path);
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final isActive = _isActive(location);

    if (!item.hasChildren) {
      return _PlainNavLink(
        label: item.label,
        path: item.path,
        isActive: isActive,
      );
    }

    return _CinematicNavDropdown(
      item: item,
      isActive: isActive,
      currentLocation: location,
    );
  }
}

class _PlainNavLink extends StatefulWidget {
  const _PlainNavLink({
    required this.label,
    required this.path,
    required this.isActive,
  });

  final String label;
  final String path;
  final bool isActive;

  @override
  State<_PlainNavLink> createState() => _PlainNavLinkState();
}

class _PlainNavLinkState extends State<_PlainNavLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final lit = widget.isActive || _hovered;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => openCmsLink(context, widget.path),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  color: lit
                      ? AppColors.gold
                      : Theme.of(context).colorScheme.onSurface,
                  fontWeight: lit ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: lit ? 0.4 : 0.1,
                ),
                child: Text(
                  widget.label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                height: 2,
                width: lit ? 22 : 0,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  gradient: LinearGradient(
                    colors: [
                      AppColors.gold.withValues(alpha: 0.2),
                      AppColors.gold,
                      AppColors.gold.withValues(alpha: 0.2),
                    ],
                  ),
                  boxShadow: lit
                      ? [
                          BoxShadow(
                            color: AppColors.gold.withValues(alpha: 0.45),
                            blurRadius: 10,
                            spreadRadius: 0.5,
                          ),
                        ]
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hover-driven cinematic mega-style dropdown for Properties (and similar).
class _CinematicNavDropdown extends StatefulWidget {
  const _CinematicNavDropdown({
    required this.item,
    required this.isActive,
    required this.currentLocation,
  });

  final NavItem item;
  final bool isActive;
  final String currentLocation;

  @override
  State<_CinematicNavDropdown> createState() => _CinematicNavDropdownState();
}

class _CinematicNavDropdownState extends State<_CinematicNavDropdown> {
  final GlobalKey _triggerKey = GlobalKey();
  OverlayEntry? _overlay;
  bool _open = false;
  bool _triggerHovered = false;
  bool _panelHovered = false;
  Timer? _closeTimer;

  static const _closeDelay = Duration(milliseconds: 320);

  @override
  void dispose() {
    _closeTimer?.cancel();
    _removeOverlay();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _CinematicNavDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Shell survives route changes — an open overlay barrier would leave the
    // page unclickable until a full reload. Close as soon as the path changes.
    if (oldWidget.currentLocation != widget.currentLocation && _open) {
      _close();
    }
  }

  void _cancelClose() {
    _closeTimer?.cancel();
    _closeTimer = null;
  }

  void _scheduleClose() {
    _cancelClose();
    _closeTimer = Timer(_closeDelay, () {
      if (!mounted) return;
      if (_panelHovered || _triggerHovered) return;
      _close();
    });
  }

  void _handlePanelHover(bool inside) {
    _panelHovered = inside;
    if (inside) {
      _cancelClose();
      return;
    }
    if (!_triggerHovered) {
      _scheduleClose();
    }
  }

  void _openMenu() {
    _cancelClose();
    if (_open) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    _overlay = OverlayEntry(
      builder: (overlayContext) => _DropdownOverlay(
        triggerKey: _triggerKey,
        title: widget.item.label,
        children: widget.item.children,
        currentLocation: widget.currentLocation,
        onHoverChange: _handlePanelHover,
        onSelect: (path) {
          // Navigate from the State context — the OverlayEntry context is
          // deactivated by _close() and GoRouter.maybeOf would return null.
          final navContext = context;
          _close();
          if (navContext.mounted) {
            goDeferred(navContext, path);
          }
        },
        onDismiss: _close,
      ),
    );
    overlay.insert(_overlay!);
    setState(() => _open = true);
  }

  void _close() {
    _cancelClose();
    _panelHovered = false;
    _removeOverlay();
    if (mounted && _open) setState(() => _open = false);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  void _toggle() {
    if (_open) {
      _close();
    } else {
      _openMenu();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lit = widget.isActive || _open || _triggerHovered;

    return MouseRegion(
      key: _triggerKey,
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() => _triggerHovered = true);
        _cancelClose();
        _openMenu();
      },
      onExit: (_) {
        setState(() => _triggerHovered = false);
        if (!_panelHovered) {
          _scheduleClose();
        }
      },
      child: GestureDetector(
        onTap: _toggle,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: lit
                ? AppColors.gold.withValues(alpha: _open ? 0.14 : 0.08)
                : Colors.transparent,
            border: Border.all(
              color: lit
                  ? AppColors.gold.withValues(alpha: _open ? 0.5 : 0.28)
                  : Colors.transparent,
              width: lit ? 1 : 0,
            ),
            boxShadow: lit && _open
                ? [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.16),
                      blurRadius: 14,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  color: lit
                      ? AppColors.gold
                      : Theme.of(context).colorScheme.onSurface,
                  fontWeight: lit ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: lit ? 0.35 : 0.1,
                ),
                child: Text(widget.item.label),
              ),
              const SizedBox(width: 2),
              AnimatedRotation(
                turns: _open ? 0.5 : 0,
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutBack,
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: lit
                      ? AppColors.gold
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DropdownOverlay extends StatelessWidget {
  const _DropdownOverlay({
    required this.triggerKey,
    required this.title,
    required this.children,
    required this.currentLocation,
    required this.onHoverChange,
    required this.onSelect,
    required this.onDismiss,
  });

  final GlobalKey triggerKey;
  final String title;
  final List<NavItem> children;
  final String currentLocation;
  final ValueChanged<bool> onHoverChange;
  final ValueChanged<String> onSelect;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final mega = children.length >= 4;
    final preferredWidth = mega ? 520.0 : 280.0;
    final screen = MediaQuery.sizeOf(context);
    final edgePad = 16.0;
    final panelW = (screen.width - edgePad * 2)
        .clamp(240.0, preferredWidth)
        .toDouble();

    final triggerBox =
        triggerKey.currentContext?.findRenderObject() as RenderBox?;
    final triggerOrigin = (triggerBox != null && triggerBox.hasSize)
        ? triggerBox.localToGlobal(Offset.zero)
        : Offset(edgePad, MediaQuery.paddingOf(context).top + 56);
    final triggerSize = (triggerBox != null && triggerBox.hasSize)
        ? triggerBox.size
        : const Size(80, 40);

    // Prefer centering under the trigger, then clamp so nothing clips off-screen
    // (Discover sits far right — without this the 2nd column vanishes off-edge).
    var left = triggerOrigin.dx + (triggerSize.width / 2) - (panelW / 2);
    final maxLeft = (screen.width - edgePad - panelW).clamp(
      edgePad,
      screen.width,
    );
    left = left.clamp(edgePad, maxLeft);
    // Sit flush under the trigger; a transparent bridge inside the panel
    // covers the gap so hover doesn't dismiss while moving the cursor down.
    final top = triggerOrigin.dy + triggerSize.height;
    final backdropTop = top;

    return Stack(
      children: [
        Positioned(
          top: backdropTop,
          left: 0,
          right: 0,
          bottom: 0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
            child: ColoredBox(color: Colors.black.withValues(alpha: 0.28)),
          ),
        ),
        Positioned(
          left: left,
          top: top,
          width: panelW,
          child: MouseRegion(
            onEnter: (_) => onHoverChange(true),
            onExit: (_) => onHoverChange(false),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 10),
                  _CinematicMenuPanel(
                    title: title,
                    children: children,
                    currentLocation: currentLocation,
                    onSelect: onSelect,
                    mega: mega,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CinematicMenuPanel extends StatelessWidget {
  const _CinematicMenuPanel({
    required this.title,
    required this.children,
    required this.currentLocation,
    required this.onSelect,
    this.mega = false,
  });

  final String title;
  final List<NavItem> children;
  final String currentLocation;
  final ValueChanged<String> onSelect;
  final bool mega;

  String get _eyebrow {
    switch (title.toLowerCase()) {
      case 'properties':
        return 'HOMES & SITES';
      case 'investment':
        return 'INVESTOR TOOLS';
      case 'discover':
        return 'EXPLORE HD HOMES';
      default:
        return 'EXPLORE';
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      for (var i = 0; i < children.length; i++)
        _CinematicMenuItem(
          item: children[i],
          selected:
              currentLocation == children[i].path ||
              (children[i].path != RoutePaths.home &&
                  currentLocation.startsWith('${children[i].path}/')),
          index: i,
          onTap: () => onSelect(children[i].path),
          compact: mega,
        ),
    ];

    final panel =
        Container(
              padding: EdgeInsets.fromLTRB(
                mega ? 16 : 12,
                16,
                mega ? 16 : 12,
                14,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xF01E2430),
                    Color(0xF012161E),
                    Color(0xF00A0C10),
                  ],
                ),
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.42),
                  width: 1.1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.65),
                    blurRadius: 48,
                    offset: const Offset(0, 22),
                  ),
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.18),
                    blurRadius: 36,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -40,
                    right: -20,
                    child: IgnorePointer(
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppColors.gold.withValues(alpha: 0.14),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                            height: 2.5,
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(99),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  AppColors.gold.withValues(alpha: 0.95),
                                  const Color(0xFFF2C76B),
                                  AppColors.gold.withValues(alpha: 0.95),
                                  Colors.transparent,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.gold.withValues(alpha: 0.45),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                          )
                          .animate()
                          .scaleX(
                            begin: 0.12,
                            end: 1,
                            duration: 520.ms,
                            curve: Curves.easeOutCubic,
                          )
                          .fadeIn(duration: 260.ms),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(6, 0, 6, 14),
                        child: Row(
                          children: [
                            Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.gold,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.gold.withValues(
                                          alpha: 0.8,
                                        ),
                                        blurRadius: 12,
                                      ),
                                    ],
                                  ),
                                )
                                .animate(
                                  onPlay: kIsWeb
                                      ? null
                                      : (c) => c.repeat(reverse: true),
                                )
                                .scale(
                                  begin: const Offset(0.85, 0.85),
                                  end: const Offset(1.15, 1.15),
                                  duration: 1200.ms,
                                ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _eyebrow,
                                    style: TextStyle(
                                      color: AppColors.gold.withValues(
                                        alpha: 0.92,
                                      ),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (mega)
                        LayoutBuilder(
                          builder: (context, constraints) {
                            const gap = 10.0;
                            // Keep both columns inside the panel — never clip the
                            // right-hand Discover links off-screen.
                            final colW = ((constraints.maxWidth - gap) / 2)
                                .clamp(120.0, constraints.maxWidth);
                            return Wrap(
                              spacing: gap,
                              runSpacing: gap,
                              children: [
                                for (final item in items)
                                  SizedBox(width: colW, child: item),
                              ],
                            );
                          },
                        )
                      else
                        ...items,
                    ],
                  ),
                ],
              ),
            )
            .animate()
            .fadeIn(duration: 180.ms, curve: Curves.easeOut)
            .slideY(
              begin: -0.08,
              end: 0,
              duration: 260.ms,
              curve: Curves.easeOutCubic,
            );

    // BackdropFilter freezes Flutter web on some GPUs — skip it there.
    if (kIsWeb) {
      return ClipRRect(borderRadius: BorderRadius.circular(22), child: panel);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: panel,
      ),
    );
  }
}

class _CinematicMenuItem extends StatefulWidget {
  const _CinematicMenuItem({
    required this.item,
    required this.selected,
    required this.index,
    required this.onTap,
    this.compact = false,
  });

  final NavItem item;
  final bool selected;
  final int index;
  final VoidCallback onTap;
  final bool compact;

  @override
  State<_CinematicMenuItem> createState() => _CinematicMenuItemState();
}

class _CinematicMenuItemState extends State<_CinematicMenuItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final lit = widget.selected || _hovered;

    return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              margin: EdgeInsets.only(bottom: widget.compact ? 0 : 6),
              padding: EdgeInsets.symmetric(
                horizontal: widget.compact ? 10 : 12,
                vertical: widget.compact ? 10 : 12,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: lit
                    ? LinearGradient(
                        colors: [
                          AppColors.gold.withValues(alpha: 0.22),
                          AppColors.gold.withValues(alpha: 0.06),
                        ],
                      )
                    : LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.03),
                          Colors.white.withValues(alpha: 0.01),
                        ],
                      ),
                border: Border.all(
                  color: lit
                      ? AppColors.gold.withValues(alpha: 0.45)
                      : Colors.white.withValues(alpha: 0.06),
                ),
                boxShadow: _hovered
                    ? [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.2),
                          blurRadius: 16,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    width: widget.compact ? 30 : 34,
                    height: widget.compact ? 30 : 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: lit
                          ? AppColors.gold.withValues(alpha: 0.18)
                          : Colors.white.withValues(alpha: 0.04),
                      border: Border.all(
                        color: lit
                            ? AppColors.gold.withValues(alpha: 0.55)
                            : Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Icon(
                      widget.item.icon ?? LucideIcons.sparkles,
                      size: widget.compact ? 13 : 15,
                      color: lit ? AppColors.gold : Colors.white70,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.label,
                          style: TextStyle(
                            color: lit ? AppColors.gold : Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: widget.compact ? 12.5 : 13.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _menuSubtitle(widget.item.path),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: widget.compact ? 10.5 : 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedSlide(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutBack,
                    offset: _hovered ? Offset.zero : const Offset(-0.15, 0),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: lit ? 1 : 0.35,
                      child: Icon(
                        LucideIcons.arrowUpRight,
                        size: 14,
                        color: lit ? AppColors.gold : Colors.white54,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(delay: (55 * widget.index).ms, duration: 280.ms)
        .slideY(
          begin: -0.06,
          end: 0,
          delay: (55 * widget.index).ms,
          duration: 360.ms,
          curve: Curves.easeOutCubic,
        );
  }

  String _menuSubtitle(String path) {
    if (path == RoutePaths.paymentCalculator) {
      return 'Estimate your monthly plan';
    }
    if (path == RoutePaths.construction) {
      return 'Track on-site project progress';
    }
    if (path == RoutePaths.roiCalculator) {
      return 'Project investment returns';
    }
    if (path == RoutePaths.investment) {
      return 'Browse opportunities';
    }
    if (path == RoutePaths.properties) {
      return 'Browse homes & estates';
    }
    if (path == RoutePaths.services) {
      return 'Premium HD Homes services';
    }
    if (path == RoutePaths.estates) {
      return 'Explore estate communities';
    }
    if (path == RoutePaths.gallery) {
      return 'Project & lifestyle visuals';
    }
    if (path == RoutePaths.blog) {
      return 'Insights & market stories';
    }
    if (path == RoutePaths.careers) {
      return 'Join the HD Homes team';
    }
    if (path == RoutePaths.trust) {
      return 'Security & compliance';
    }
    if (path == RoutePaths.contact) {
      return 'Talk to our specialists';
    }
    return 'Explore HD Homes';
  }
}
