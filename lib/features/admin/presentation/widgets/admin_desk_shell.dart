import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/offline_updates_note.dart';
import 'package:lucide_icons/lucide_icons.dart';

abstract final class AdminDeskColors {
  static const bg = Color(0xFF0B0E14);
  static const surface = Color(0xFF141820);
  static const elevated = Color(0xFF1A1F28);
  static const border = Color(0x18FFFFFF);
  static const muted = Color(0xFF8B929E);
  static const gold = AppColors.primaryGold;
  static const green = Color(0xFF22C55E);
  static const amber = Color(0xFFF59E0B);
  static const red = Color(0xFFEF4444);
}

class AdminDeskTab {
  const AdminDeskTab({required this.label, required this.icon, this.badge});
  final String label;
  final IconData icon;
  final int? badge;
}

class AdminDeskKpi {
  const AdminDeskKpi({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
    this.accent,
    this.onTap,
  });
  final String label;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color? accent;
  final VoidCallback? onTap;
}

class AdminDeskPage extends StatelessWidget {
  const AdminDeskPage({
    super.key,
    required this.overline,
    required this.title,
    required this.subtitle,
    required this.tabs,
    required this.selectedTab,
    required this.onTabSelected,
    required this.body,
    this.kpis = const [],
    this.live = false,
    this.fromRemote = false,
    this.liveLabel,
    this.remoteLabel,
    this.onRefresh,
    this.message,
    this.onDismissMessage,
    this.error,
    this.actions = const [],
    this.isLoading = false,
    this.breadcrumb,
    this.showRemotePill = true,
  });

  final String overline;
  final String title;
  final String subtitle;
  final List<AdminDeskTab> tabs;
  final int selectedTab;
  final ValueChanged<int> onTabSelected;
  final Widget body;
  final List<AdminDeskKpi> kpis;
  final bool live;
  final bool fromRemote;
  // Kept for callers that still pass a status string. The pill uses synced.
  // ignore: unused_field
  final String? liveLabel;
  // ignore: unused_field
  final String? remoteLabel;
  final VoidCallback? onRefresh;
  final String? message;
  final VoidCallback? onDismissMessage;
  final String? error;
  final List<Widget> actions;
  final bool isLoading;
  final Widget? breadcrumb;
  final bool showRemotePill;

  /// Tab body is at least this tall so forms and lists stay usable.
  static const double minBodyHeight = 780;

  @override
  Widget build(BuildContext context) {
    final synced = live || fromRemote;
    final header = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TopBar(
          overline: overline,
          title: title,
          subtitle: subtitle,
          synced: synced,
          offline: showRemotePill && !synced,
          onRefresh: onRefresh,
          actions: actions,
          breadcrumb: breadcrumb,
        ),
        if (message != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: _Banner(text: message!, onDismiss: onDismissMessage),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: _Banner(text: error!, isError: true),
          ),
        if (kpis.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: _KpiStrip(kpis: kpis),
          ),
        if (tabs.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: _TabBar(
              tabs: tabs,
              selected: selectedTab,
              onSelected: onTabSelected,
            ),
          ),
        const SizedBox(height: 8),
      ],
    );

    final tabBody = isLoading
        ? const _DeskLoadingSkeleton()
        : AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: KeyedSubtree(
              key: ValueKey(selectedTab),
              child: body,
            ),
          );

    return ColoredBox(
      color: AdminDeskColors.bg,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewport = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : minBodyHeight;
          return CustomScrollView(
            primary: false,
            slivers: [
              SliverToBoxAdapter(child: header),
              SliverLayoutBuilder(
                builder: (context, sliver) {
                  final remaining =
                      viewport - sliver.precedingScrollExtent;
                  final height = math.max(minBodyHeight, remaining);
                  return SliverToBoxAdapter(
                    child: SizedBox(height: height, child: tabBody),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DeskSyncPill extends StatelessWidget {
  const _DeskSyncPill({required this.synced});

  final bool synced;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        synced
            ? 'Your latest records are here.'
            : "We're gathering the latest records.",
        style: const TextStyle(
          color: AdminDeskColors.muted,
          fontSize: 12,
          height: 1.35,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _DeskLoadingSkeleton extends StatelessWidget {
  const _DeskLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading workspace',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final widthFactor in const [1.0, .82, .94, .7, .88])
            FractionallySizedBox(
              widthFactor: widthFactor,
              alignment: Alignment.centerLeft,
              child: Container(
                height: 72,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AdminDeskColors.elevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AdminDeskColors.border),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AdminDeskEmptyState extends StatelessWidget {
  const AdminDeskEmptyState({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    this.action,
  });
  final String title;
  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AdminDeskColors.gold, size: 40),
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AdminDeskColors.muted)),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

class AdminDeskPanel extends StatelessWidget {
  const AdminDeskPanel({
    super.key,
    required this.child,
    this.fill = false,
    this.margin = const EdgeInsets.fromLTRB(12, 4, 12, 12),
  });

  final Widget child;
  final bool fill;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: fill ? double.infinity : null,
      height: fill ? double.infinity : null,
      margin: margin,
      decoration: BoxDecoration(
        color: AdminDeskColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminDeskColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.overline,
    required this.title,
    required this.subtitle,
    required this.synced,
    required this.offline,
    this.onRefresh,
    this.actions = const [],
    this.breadcrumb,
  });
  final String overline;
  final String title;
  final String subtitle;
  final bool synced;
  final bool offline;
  final VoidCallback? onRefresh;
  final List<Widget> actions;
  final Widget? breadcrumb;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      decoration: BoxDecoration(
        color: AdminDeskColors.surface,
        border: const Border(bottom: BorderSide(color: AdminDeskColors.border)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AdminDeskColors.surface,
            AdminDeskColors.bg.withValues(alpha: 0.96),
          ],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final heading = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (breadcrumb != null) ...[
                breadcrumb!,
                const SizedBox(height: 10),
              ] else ...[
                Text(overline.toUpperCase(),
                    style: const TextStyle(
                        color: AdminDeskColors.gold,
                        letterSpacing: 2,
                        fontSize: 11,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
              ],
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AdminDeskColors.gold.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AdminDeskColors.gold.withValues(alpha: 0.35),
                      ),
                    ),
                    child: const Icon(
                      LucideIcons.users,
                      size: 18,
                      color: AdminDeskColors.gold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 22 : 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _DeskSyncPill(synced: synced),
              const SizedBox(height: 6),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AdminDeskColors.muted,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              if (offline) ...[
                const SizedBox(height: 10),
                const OfflineUpdatesNote(color: AdminDeskColors.muted),
              ],
            ],
          );
          final controls = Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (onRefresh != null)
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: onRefresh,
                  style: IconButton.styleFrom(
                    backgroundColor: AdminDeskColors.elevated,
                    side: const BorderSide(color: AdminDeskColors.border),
                  ),
                  icon: Icon(
                    LucideIcons.refreshCw,
                    color: AdminDeskColors.muted,
                    size: 18,
                  ),
                ),
              ...actions,
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                heading,
                if (actions.isNotEmpty || onRefresh != null) ...[
                  const SizedBox(height: 14),
                  controls,
                ],
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: heading),
              const SizedBox(width: 16),
              Flexible(child: controls),
            ],
          );
        },
      ),
    );
  }
}

class _KpiStrip extends StatelessWidget {
  const _KpiStrip({required this.kpis});
  final List<AdminDeskKpi> kpis;

  static const double _cardMinWidth = 168;
  static const double _cardHeight = 128;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = 12.0;
        final canFitEqual = constraints.maxWidth >=
            (kpis.length * _cardMinWidth) + ((kpis.length - 1) * gap);

        Widget cardFor(AdminDeskKpi k) {
          final accent = k.accent ?? AdminDeskColors.gold;
          final card = Container(
            height: _cardHeight,
            decoration: BoxDecoration(
              color: AdminDeskColors.elevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AdminDeskColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(height: 2.5, color: accent),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(k.icon, size: 14, color: accent),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 26,
                        width: double.infinity,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            k.value,
                            maxLines: 1,
                            style: TextStyle(
                              color: accent,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        k.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        k.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AdminDeskColors.muted,
                          fontSize: 10,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
          if (k.onTap == null) return card;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: k.onTap,
              borderRadius: BorderRadius.circular(14),
              child: card,
            ),
          );
        }

        if (canFitEqual) {
          return SizedBox(
            height: _cardHeight,
            child: Row(
              children: [
                for (var i = 0; i < kpis.length; i++) ...[
                  if (i > 0) SizedBox(width: gap),
                  Expanded(child: cardFor(kpis[i])),
                ],
              ],
            ),
          );
        }

        return SizedBox(
          height: _cardHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: kpis.length,
            separatorBuilder: (_, _) => SizedBox(width: gap),
            itemBuilder: (context, index) => SizedBox(
              width: _cardMinWidth + 16,
              child: cardFor(kpis[index]),
            ),
          ),
        );
      },
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.tabs, required this.selected, required this.onSelected});
  final List<AdminDeskTab> tabs;
  final int selected;
  final ValueChanged<int> onSelected;
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useEqual = constraints.maxWidth >= 720 && tabs.length <= 5;
        final children = [
          for (var i = 0; i < tabs.length; i++)
            Padding(
              padding: EdgeInsets.only(right: useEqual ? 0 : 8),
              child: _DeskTabChip(
                tab: tabs[i],
                selected: selected == i,
                onTap: () => onSelected(i),
                expanded: useEqual,
              ),
            ),
        ];

        if (useEqual) {
          return Row(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: children[i]),
              ],
            ],
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: children),
        );
      },
    );
  }
}

class _DeskTabChip extends StatelessWidget {
  const _DeskTabChip({
    required this.tab,
    required this.selected,
    required this.onTap,
    this.expanded = false,
  });

  final AdminDeskTab tab;
  final bool selected;
  final VoidCallback onTap;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: expanded ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AdminDeskColors.gold.withValues(alpha: 0.16)
              : AdminDeskColors.elevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AdminDeskColors.gold.withValues(alpha: 0.55)
                : AdminDeskColors.border,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment:
              expanded ? MainAxisAlignment.center : MainAxisAlignment.start,
          mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Icon(
              tab.icon,
              size: 15,
              color: selected ? AdminDeskColors.gold : AdminDeskColors.muted,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                tab.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? Colors.white : AdminDeskColors.muted,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
            if (tab.badge != null && tab.badge! > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AdminDeskColors.gold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${tab.badge}',
                  style: const TextStyle(
                    color: AdminDeskColors.gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, this.onDismiss, this.isError = false});
  final String text;
  final VoidCallback? onDismiss;
  final bool isError;
  @override
  Widget build(BuildContext context) {
    final c = isError ? AdminDeskColors.red : AdminDeskColors.gold;
    return Material(
      color: c.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      child: ListTile(
        dense: true,
        leading: Icon(isError ? LucideIcons.alertCircle : LucideIcons.info, color: c, size: 18),
        title: Text(text, style: const TextStyle(color: Colors.white)),
        trailing: onDismiss != null
            ? IconButton(icon: const Icon(LucideIcons.x, size: 16), onPressed: onDismiss)
            : null,
      ),
    );
  }
}
