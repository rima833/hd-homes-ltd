import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/observability_models.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/audit_controller.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Observability Command Center — Sales-desk layout, live Supabase data only.
class ObservabilityCommandCenterPage extends ConsumerStatefulWidget {
  const ObservabilityCommandCenterPage({super.key});

  @override
  ConsumerState<ObservabilityCommandCenterPage> createState() =>
      _ObservabilityCommandCenterPageState();
}

class _ObservabilityCommandCenterPageState
    extends ConsumerState<ObservabilityCommandCenterPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _kpiScroll = ScrollController();
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _kpiScroll.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final centerAsync = ref.watch(commandCenterProvider);
    final searchAsync = ref.watch(adminAuditSearchProvider);
    final ui = ref.watch(auditControllerProvider);
    final controller = ref.read(auditControllerProvider.notifier);
    final filter = ref.watch(observabilityFilterProvider);
    final filterCtrl = ref.read(observabilityFilterProvider.notifier);
    ref.watch(auditRealtimeStatusProvider);
    ref.watch(auditRealtimeProvider);

    void refresh() {
      ref.invalidate(commandCenterProvider);
      ref.invalidate(adminAuditSearchProvider);
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _Occ.bg,
      drawer: MediaQuery.sizeOf(context).width < 1100
          ? Drawer(
              backgroundColor: _Occ.sidebar,
              child: _OccSidebar(
                selected: ui.selectedTab,
                openAlerts: centerAsync.valueOrNull?.openIssues ??
                    centerAsync.valueOrNull?.openAlerts ??
                    0,
                critical: centerAsync.valueOrNull?.criticalAlerts ?? 0,
                healthCount: centerAsync.valueOrNull?.health.length ?? 0,
                activityCount:
                    centerAsync.valueOrNull?.recentActivity.length ?? 0,
                onSelect: (tab) {
                  controller.setTab(tab);
                  Navigator.pop(context);
                },
                onClose: () => Navigator.pop(context),
              ),
            )
          : null,
      body: centerAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _Occ.gold)),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.shieldOff, color: _Occ.red, size: 28),
                const SizedBox(height: 12),
                Text(
                  userFacingError(
                    e,
                    fallback:
                        'Command center unavailable. Staff need view_audit_logs.',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _Occ.red),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: refresh,
                  icon: const Icon(LucideIcons.refreshCw, size: 16),
                  label: const Text('Retry'),
                  style: _Occ.solid,
                ),
              ],
            ),
          ),
        ),
        data: (snap) {
          final wide = MediaQuery.sizeOf(context).width >= 1100;

          Widget mainPane() {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _OccTopBar(
                  tab: ui.selectedTab,
                  loadedAt: snap.generatedAt,
                  showMenu: !wide,
                  onMenu: wide
                      ? null
                      : () => _scaffoldKey.currentState?.openDrawer(),
                  onRefresh: refresh,
                  busy: ui.isBusy,
                  onHealthProbe: controller.runHealthProbe,
                  onHeartbeat: controller.publishHeartbeatProbe,
                ),
                if (ui.message != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Material(
                      color: _Occ.gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      child: ListTile(
                        dense: true,
                        leading: const Icon(
                          LucideIcons.checkCircle2,
                          color: _Occ.gold,
                          size: 18,
                        ),
                        title: Text(
                          ui.message!,
                          style: const TextStyle(color: Colors.white),
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            LucideIcons.x,
                            size: 16,
                            color: _Occ.muted,
                          ),
                          onPressed: controller.clearFeedback,
                        ),
                      ),
                    ),
                  ),
                if (ui.error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Material(
                      color: _Occ.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      child: ListTile(
                        dense: true,
                        leading: const Icon(
                          LucideIcons.alertTriangle,
                          color: _Occ.red,
                          size: 18,
                        ),
                        title: Text(
                          userFacingError(ui.error, fallback: ui.error),
                          style: const TextStyle(color: Colors.white),
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            LucideIcons.x,
                            size: 16,
                            color: _Occ.muted,
                          ),
                          onPressed: controller.clearFeedback,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _OccKpiStrip(
                    snap: snap,
                    scrollController: _kpiScroll,
                    onSelectTab: controller.setTab,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                    child: _OccBody(
                      tab: ui.selectedTab,
                      snap: snap,
                      searchAsync: searchAsync,
                      filter: filter,
                      filterCtrl: filterCtrl,
                      searchCtrl: _searchCtrl,
                      ui: ui,
                      controller: controller,
                      onRefreshSearch: () =>
                          ref.invalidate(adminAuditSearchProvider),
                    ),
                  ),
                ),
              ],
            );
          }

          if (!wide) return mainPane();

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 268,
                child: _OccSidebar(
                  selected: ui.selectedTab,
                  openAlerts: snap.openIssues,
                  critical: snap.criticalAlerts,
                  healthCount: snap.health.length,
                  activityCount: snap.recentActivity.length,
                  onSelect: controller.setTab,
                ),
              ),
              Expanded(child: mainPane()),
            ],
          );
        },
      ),
    );
  }
}

// ─── Tokens (match Sales / CRM desk) ───────────────────────────────────────

abstract final class _Occ {
  // Match Sales desk (CrmDeskColors / _Crm)
  static const bg = Color(0xFF0B0E14);
  static const sidebar = Color(0xFF0F1218);
  static const surface = Color(0xFF141820);
  static const elevated = Color(0xFF1A1F28);
  static const border = Color(0x18FFFFFF);
  static const muted = Color(0xFF8B929E);
  static const gold = AppColors.primaryGold;
  static const green = Color(0xFF22C55E);
  static const amber = Color(0xFFF59E0B);
  static const red = Color(0xFFF87171);

  static ButtonStyle get solid => FilledButton.styleFrom(
        backgroundColor: gold,
        foregroundColor: AppColors.charcoal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );

  static ButtonStyle get ghost => OutlinedButton.styleFrom(
        foregroundColor: gold,
        side: BorderSide(color: gold.withValues(alpha: 0.45)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      );
}

// ─── Sidebar ───────────────────────────────────────────────────────────────

class _OccSidebar extends StatelessWidget {
  const _OccSidebar({
    required this.selected,
    required this.openAlerts,
    required this.critical,
    required this.healthCount,
    required this.activityCount,
    required this.onSelect,
    this.onClose,
  });

  final OccDeskTab selected;
  final int openAlerts;
  final int critical;
  final int healthCount;
  final int activityCount;
  final ValueChanged<OccDeskTab> onSelect;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final sections = <(String, List<_NavSpec>)>[
      (
        'Command',
        [
          const _NavSpec(OccDeskTab.overview, LucideIcons.layoutDashboard),
        ],
      ),
      (
        'Monitoring',
        [
          _NavSpec(
            OccDeskTab.health,
            LucideIcons.server,
            badge: healthCount > 0 ? healthCount : null,
          ),
          _NavSpec(
            OccDeskTab.alerts,
            LucideIcons.bell,
            badge: openAlerts > 0 ? openAlerts : null,
            urgent: critical > 0,
          ),
          _NavSpec(
            OccDeskTab.activity,
            LucideIcons.activity,
            badge: activityCount > 0 ? activityCount : null,
          ),
        ],
      ),
      (
        'Investigation',
        [
          const _NavSpec(OccDeskTab.audit, LucideIcons.scrollText),
        ],
      ),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: _Occ.sidebar,
        border: Border(right: BorderSide(color: _Occ.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'OPS DESK',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: _Occ.gold,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Command Center',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
                if (onClose != null)
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(LucideIcons.x, color: _Occ.muted),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
              children: [
                for (final section in sections) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
                    child: Text(
                      section.$1.toUpperCase(),
                      style: const TextStyle(
                        color: _Occ.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                  for (final item in section.$2)
                    _OccNavTile(
                      spec: item,
                      selected: selected == item.tab,
                      onTap: () => onSelect(item.tab),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavSpec {
  const _NavSpec(this.tab, this.icon, {this.badge, this.urgent = false});
  final OccDeskTab tab;
  final IconData icon;
  final int? badge;
  final bool urgent;
}

class _OccNavTile extends StatelessWidget {
  const _OccNavTile({
    required this.spec,
    required this.selected,
    required this.onTap,
  });

  final _NavSpec spec;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final badge = spec.badge;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? _Occ.gold.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? _Occ.gold.withValues(alpha: 0.55)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  spec.icon,
                  size: 18,
                  color: selected ? _Occ.gold : _Occ.muted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    spec.tab.label,
                    style: TextStyle(
                      color: selected ? Colors.white : _Occ.muted,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13.5,
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: spec.urgent
                          ? _Occ.amber.withValues(alpha: 0.18)
                          : _Occ.elevated,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: spec.urgent
                            ? _Occ.amber.withValues(alpha: 0.55)
                            : _Occ.border,
                      ),
                    ),
                    child: Text(
                      badge > 99 ? '99+' : '$badge',
                      style: TextStyle(
                        color: spec.urgent ? _Occ.amber : _Occ.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Top bar ───────────────────────────────────────────────────────────────

class _OccTopBar extends StatelessWidget {
  const _OccTopBar({
    required this.tab,
    required this.loadedAt,
    required this.onRefresh,
    required this.busy,
    required this.onHealthProbe,
    required this.onHeartbeat,
    this.onMenu,
    this.showMenu = false,
  });

  final OccDeskTab tab;
  final DateTime? loadedAt;
  final VoidCallback onRefresh;
  final bool busy;
  final VoidCallback onHealthProbe;
  final VoidCallback onHeartbeat;
  final VoidCallback? onMenu;
  final bool showMenu;

  @override
  Widget build(BuildContext context) {
    final synced = loadedAt == null
        ? "We're gathering the latest activity."
        : 'Your latest activity is here.';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: const BoxDecoration(
        color: _Occ.surface,
        border: Border(bottom: BorderSide(color: _Occ.border)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 900;
          return Row(
            children: [
              if (showMenu && onMenu != null)
                IconButton(
                  onPressed: onMenu,
                  icon: const Icon(LucideIcons.panelLeft, color: _Occ.muted),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tab.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      synced,
                      style: const TextStyle(
                        color: _Occ.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (!narrow) ...[
                OutlinedButton.icon(
                  onPressed: busy ? null : onHealthProbe,
                  icon: const Icon(LucideIcons.heartPulse, size: 15),
                  label: const Text('Health probe'),
                  style: _Occ.ghost,
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: busy ? null : onHeartbeat,
                  icon: const Icon(LucideIcons.radio, size: 15),
                  label: const Text('Heartbeat'),
                  style: _Occ.ghost,
                ),
                const SizedBox(width: 8),
              ],
              IconButton(
                tooltip: 'Refresh',
                onPressed: onRefresh,
                icon: Icon(
                  LucideIcons.refreshCw,
                  size: 18,
                  color: _Occ.muted,
                ),
              ),
              if (narrow)
                PopupMenuButton<String>(
                  icon: const Icon(LucideIcons.moreVertical, color: _Occ.muted),
                  color: _Occ.elevated,
                  onSelected: (v) {
                    if (v == 'probe') onHealthProbe();
                    if (v == 'beat') onHeartbeat();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'probe',
                      child: Text('Health probe'),
                    ),
                    PopupMenuItem(
                      value: 'beat',
                      child: Text('Heartbeat'),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

// ─── KPI strip ─────────────────────────────────────────────────────────────

class _OccKpiStrip extends StatelessWidget {
  const _OccKpiStrip({
    required this.snap,
    required this.onSelectTab,
    this.scrollController,
  });

  final CommandCenterSnapshot snap;
  final ValueChanged<OccDeskTab> onSelectTab;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final items = <_KpiItem>[
      _KpiItem(
        label: "Today's activity",
        value: '${snap.todayActivity}',
        tab: OccDeskTab.activity,
      ),
      _KpiItem(
        label: 'Active users',
        value: '${snap.activeUsersEstimate}',
        tab: OccDeskTab.activity,
      ),
      _KpiItem(
        label: 'Failed logins',
        value: '${snap.failedLogins}',
        tab: OccDeskTab.audit,
        accent: snap.failedLogins > 0 ? _Occ.amber : null,
      ),
      _KpiItem(
        label: 'Open alerts',
        value: '${snap.openAlerts}',
        tab: OccDeskTab.alerts,
        accent: snap.openAlerts > 0 ? _Occ.amber : null,
      ),
      _KpiItem(
        label: 'Critical',
        value: '${snap.criticalAlerts}',
        tab: OccDeskTab.alerts,
        accent: snap.criticalAlerts > 0 ? _Occ.red : null,
      ),
      _KpiItem(
        label: 'Security score',
        value: '${snap.securityScore}',
        tab: OccDeskTab.overview,
        accent: snap.securityScore >= 80 ? _Occ.green : _Occ.amber,
      ),
    ];

    return SizedBox(
      height: 78,
      child: Scrollbar(
        controller: scrollController,
        thumbVisibility: false,
        child: ListView.separated(
          controller: scrollController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 2),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final k = items[i];
            return Material(
              color: _Occ.surface,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onSelectTab(k.tab),
                child: Container(
                  constraints:
                      const BoxConstraints(minWidth: 132, maxWidth: 168),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: k.accent?.withValues(alpha: 0.55) ?? _Occ.border,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        k.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _Occ.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        k.value,
                        style: TextStyle(
                          color: k.accent ?? Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _KpiItem {
  const _KpiItem({
    required this.label,
    required this.value,
    required this.tab,
    this.accent,
  });
  final String label;
  final String value;
  final OccDeskTab tab;
  final Color? accent;
}

// ─── Body ──────────────────────────────────────────────────────────────────

class _OccBody extends StatelessWidget {
  const _OccBody({
    required this.tab,
    required this.snap,
    required this.searchAsync,
    required this.filter,
    required this.filterCtrl,
    required this.searchCtrl,
    required this.ui,
    required this.controller,
    required this.onRefreshSearch,
  });

  final OccDeskTab tab;
  final CommandCenterSnapshot snap;
  final AsyncValue<List<AuditRecord>> searchAsync;
  final ObservabilityFilter filter;
  final ObservabilityFilterNotifier filterCtrl;
  final TextEditingController searchCtrl;
  final AuditUiState ui;
  final AuditController controller;
  final VoidCallback onRefreshSearch;

  @override
  Widget build(BuildContext context) {
    return switch (tab) {
      OccDeskTab.overview => _OverviewBody(
          snap: snap,
          onProbe: controller.runHealthProbe,
          onOpenAlerts: () => controller.setTab(OccDeskTab.alerts),
          onOpenActivity: () => controller.setTab(OccDeskTab.activity),
          onOpenHealth: () => controller.setTab(OccDeskTab.health),
        ),
      OccDeskTab.health => _HealthBody(
          health: snap.health,
          onProbe: controller.runHealthProbe,
        ),
      OccDeskTab.alerts => _AlertsBody(
          alerts: snap.alerts,
          controller: controller,
        ),
      OccDeskTab.activity => _ActivityBody(records: snap.recentActivity),
      OccDeskTab.audit => _AuditBody(
          searchAsync: searchAsync,
          filter: filter,
          filterCtrl: filterCtrl,
          searchCtrl: searchCtrl,
          ui: ui,
          controller: controller,
          onRefresh: onRefreshSearch,
        ),
    };
  }
}

/// Sales-desk panel card (matches CRM `_Panel`).
class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.icon,
    required this.children,
    this.emptyText,
    this.trailing,
    this.footer,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final String? emptyText;
  final Widget? trailing;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _Occ.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Occ.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: _Occ.gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 10),
          if (children.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                emptyText ?? 'Nothing here yet.',
                style: const TextStyle(color: _Occ.muted, fontSize: 12),
              ),
            )
          else
            ...children,
          ?footer,
        ],
      ),
    );
  }
}

Widget _linkBtn(String label, VoidCallback onPressed) {
  return TextButton(
    onPressed: onPressed,
    child: Text(
      label,
      style: const TextStyle(color: _Occ.gold, fontSize: 11),
    ),
  );
}

// Overview — Sales Wrap grid; every primary panel visible (nothing hidden)
class _OverviewBody extends StatelessWidget {
  const _OverviewBody({
    required this.snap,
    required this.onProbe,
    required this.onOpenAlerts,
    required this.onOpenActivity,
    required this.onOpenHealth,
  });

  final CommandCenterSnapshot snap;
  final VoidCallback onProbe;
  final VoidCallback onOpenAlerts;
  final VoidCallback onOpenActivity;
  final VoidCallback onOpenHealth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1400
            ? 3
            : constraints.maxWidth >= 900
                ? 2
                : 1;
        const gap = 14.0;
        final cardWidth =
            (constraints.maxWidth - (gap * (columns - 1))) / columns;

        final cards = <Widget>[
          _Panel(
            title: 'Security posture',
            icon: LucideIcons.shield,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${snap.securityScore}',
                    style: TextStyle(
                      color:
                          snap.securityScore >= 80 ? _Occ.green : _Occ.amber,
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Text(
                      '/ 100',
                      style: TextStyle(color: _Occ.muted, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: snap.securityScore.clamp(0, 100) / 100,
                  minHeight: 8,
                  backgroundColor: _Occ.border,
                  color: snap.securityScore >= 80 ? _Occ.green : _Occ.amber,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                snap.openIssues == snap.openAlerts
                    ? '${snap.openAlerts} open events'
                    : '${snap.openIssues} open issues · ${snap.openAlerts} events',
                style: const TextStyle(color: _Occ.muted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Fact(
                    'Open alerts',
                    '${snap.openAlerts}',
                    snap.openAlerts > 0 ? _Occ.amber : _Occ.green,
                  ),
                  _Fact(
                    'Critical',
                    '${snap.criticalAlerts}',
                    snap.criticalAlerts > 0 ? _Occ.red : _Occ.green,
                  ),
                  _Fact(
                    'Failed logins',
                    '${snap.failedLogins}',
                    snap.failedLogins > 0 ? _Occ.amber : _Occ.muted,
                  ),
                  _Fact(
                    'Active users',
                    '${snap.activeUsersEstimate}',
                    _Occ.gold,
                  ),
                ],
              ),
            ],
          ),
          _Panel(
            title: 'System health',
            icon: LucideIcons.server,
            emptyText: 'No health checks yet. Run a probe to measure live services.',
            trailing: _linkBtn('All health', onOpenHealth),
            footer: snap.health.isEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: FilledButton.icon(
                      onPressed: onProbe,
                      icon: const Icon(LucideIcons.heartPulse, size: 16),
                      label: const Text('Run health probe'),
                      style: _Occ.solid,
                    ),
                  )
                : null,
            children: [
              for (final h in snap.health)
                _DeskRow(
                  title: h.label,
                  subtitle: [
                    if (h.message != null && h.message!.isNotEmpty) h.message!,
                    if (h.latencyMs != null) '${h.latencyMs}ms',
                    if (h.checkedAt != null)
                      DateFormat('HH:mm:ss').format(h.checkedAt!.toLocal()),
                  ].join(' · '),
                  trailing: h.status.slug.toUpperCase(),
                  trailingColor: h.status.color,
                ),
            ],
          ),
          _Panel(
            title: 'Open alerts',
            icon: LucideIcons.bell,
            emptyText: 'No open alerts.',
            trailing: _linkBtn('All (${snap.openAlerts})', onOpenAlerts),
            children: [
              for (final a in snap.alerts)
                _DeskRow(
                  title: a.title,
                  subtitle: [
                    a.description ?? a.lifecycle.slug,
                    if (a.eventCount > 1) '${a.eventCount} events',
                    ?a.sourceModule,
                    DateFormat('MMM d · HH:mm').format(a.createdAt.toLocal()),
                  ].join(' · '),
                  trailing: a.eventCount > 1 ? '${a.eventCount}' : a.severity.slug,
                  trailingColor: a.severity.color,
                ),
            ],
          ),
          _Panel(
            title: 'Recent activity',
            icon: LucideIcons.activity,
            emptyText: 'No recent audit events.',
            trailing: _linkBtn(
              'All (${snap.recentActivity.length})',
              onOpenActivity,
            ),
            children: [
              for (final r in snap.recentActivity)
                _DeskRow(
                  title: r.timelineTitle,
                  subtitle: '${r.module} · ${r.category.label}',
                  trailing: DateFormat('HH:mm').format(r.createdAt.toLocal()),
                ),
            ],
          ),
          _Panel(
            title: 'Platform activity',
            icon: LucideIcons.barChart3,
            emptyText: 'No module activity recorded yet.',
            trailing: _linkBtn('Feed', onOpenActivity),
            children: [
              for (final module in snap.platformModules.take(8))
                _DeskRow(
                  title: module.label,
                  subtitle: 'Recorded events',
                  trailing: '${module.count}',
                ),
            ],
          ),
        ];

        return SingleChildScrollView(
          child: Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final card in cards)
                SizedBox(width: cardWidth, child: card),
            ],
          ),
        );
      },
    );
  }
}

class _DeskRow extends StatelessWidget {
  const _DeskRow({
    required this.title,
    this.subtitle,
    this.trailing,
    this.trailingColor,
  });

  final String title;
  final String? subtitle;
  final String? trailing;
  final Color? trailingColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _Occ.muted, fontSize: 11),
                  ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Text(
              trailing!,
              style: TextStyle(
                color: trailingColor ?? _Occ.gold,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: _Occ.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _HealthBody extends StatelessWidget {
  const _HealthBody({required this.health, required this.onProbe});
  final List<SystemHealthCheck> health;
  final VoidCallback onProbe;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _Panel(
          title: 'Service status',
          icon: LucideIcons.server,
          emptyText:
              'No health checks yet. Run a probe to measure live services.',
          trailing: OutlinedButton.icon(
            onPressed: onProbe,
            icon: const Icon(LucideIcons.heartPulse, size: 14),
            label: const Text('Probe now'),
            style: _Occ.ghost,
          ),
          children: [
            for (final h in health)
              _DeskRow(
                title: h.label,
                subtitle: [
                  if (h.message != null && h.message!.isNotEmpty) h.message!,
                  if (h.latencyMs != null) '${h.latencyMs}ms',
                  if (h.checkedAt != null)
                    DateFormat('HH:mm:ss').format(h.checkedAt!.toLocal()),
                ].join(' · '),
                trailing: h.status.slug.toUpperCase(),
                trailingColor: h.status.color,
              ),
          ],
        ),
      ],
    );
  }
}

class _AlertsBody extends StatelessWidget {
  const _AlertsBody({required this.alerts, required this.controller});
  final List<SystemAlert> alerts;
  final AuditController controller;

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) {
      return const Center(
        child: Text(
          'No open alerts.',
          style: TextStyle(color: _Occ.muted),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.separated(
      itemCount: alerts.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final a = alerts[i];
        return Container(
          decoration: BoxDecoration(
            color: _Occ.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: a.severity.color.withValues(alpha: 0.35)),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: a.severity.color.withValues(alpha: 0.15),
              child: Icon(a.severity.icon, color: a.severity.color, size: 18),
            ),
            title: Text(
              a.title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              [
                a.description ?? a.lifecycle.slug,
                if (a.eventCount > 1) '${a.eventCount} matching events',
                ?a.sourceModule,
                DateFormat('MMM d · HH:mm').format(a.createdAt.toLocal()),
              ].join(' · '),
              style: const TextStyle(color: _Occ.muted, fontSize: 12),
            ),
            trailing: Wrap(
              spacing: 4,
              children: [
                IconButton(
                  tooltip: a.eventCount > 1
                      ? 'Acknowledge all ${a.eventCount}'
                      : 'Acknowledge',
                  onPressed: () => controller.updateAlertGroup(
                    a,
                    AlertLifecycle.acknowledged,
                  ),
                  icon: const Icon(LucideIcons.check, size: 18, color: _Occ.muted),
                ),
                IconButton(
                  tooltip: a.eventCount > 1
                      ? 'Resolve all ${a.eventCount}'
                      : 'Resolve',
                  onPressed: () => controller.updateAlertGroup(
                    a,
                    AlertLifecycle.resolved,
                  ),
                  icon: const Icon(
                    LucideIcons.checkCheck,
                    size: 18,
                    color: _Occ.green,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ActivityBody extends StatefulWidget {
  const _ActivityBody({required this.records});
  final List<AuditRecord> records;

  @override
  State<_ActivityBody> createState() => _ActivityBodyState();
}

class _ActivityBodyState extends State<_ActivityBody> {
  String? _module;

  @override
  Widget build(BuildContext context) {
    final modules = widget.records.map((r) => r.module).toSet().toList()
      ..sort();
    final records = _module == null
        ? widget.records
        : widget.records.where((r) => r.module == _module).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (modules.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _moduleChip('All', null, widget.records.length),
                  for (final module in modules)
                    _moduleChip(
                      module,
                      module,
                      widget.records.where((r) => r.module == module).length,
                    ),
                ],
              ),
            ),
          ),
        Expanded(
          child: records.isEmpty
              ? const Center(
                  child: Text(
                    'No recent activity for this module.',
                    style: TextStyle(color: _Occ.muted),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.separated(
                  itemCount: records.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final r = records[i];
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: _Occ.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _Occ.border),
                      ),
                      child: Row(
                        children: [
                          Icon(r.severity.icon, color: r.severity.color, size: 18),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.timelineTitle,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  [
                                    r.module,
                                    r.category.label,
                                    if (r.reason != null && r.reason!.isNotEmpty)
                                      r.reason!,
                                  ].join(' · '),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _Occ.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('MMM d · HH:mm')
                                .format(r.createdAt.toLocal()),
                            style: const TextStyle(color: _Occ.muted, fontSize: 11),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _moduleChip(String label, String? module, int count) {
    final selected = _module == module;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text('$label ($count)'),
        selected: selected,
        onSelected: (_) => setState(() => _module = module),
        selectedColor: _Occ.gold.withValues(alpha: 0.2),
        checkmarkColor: _Occ.gold,
        labelStyle: TextStyle(
          color: selected ? _Occ.gold : _Occ.muted,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        side: BorderSide(
          color: selected ? _Occ.gold.withValues(alpha: 0.5) : _Occ.border,
        ),
        backgroundColor: _Occ.elevated,
      ),
    );
  }
}

class _AuditBody extends ConsumerWidget {
  const _AuditBody({
    required this.searchAsync,
    required this.filter,
    required this.filterCtrl,
    required this.searchCtrl,
    required this.ui,
    required this.controller,
    required this.onRefresh,
  });

  final AsyncValue<List<AuditRecord>> searchAsync;
  final ObservabilityFilter filter;
  final ObservabilityFilterNotifier filterCtrl;
  final TextEditingController searchCtrl;
  final AuditUiState ui;
  final AuditController controller;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _Occ.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _Occ.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final preset in [
                    ActivityDatePreset.today,
                    ActivityDatePreset.last7Days,
                    ActivityDatePreset.last30Days,
                  ])
                    FilterChip(
                      label: Text(preset.label),
                      selected: filter.preset == preset,
                      onSelected: (_) => filterCtrl.setPreset(preset),
                      selectedColor: _Occ.gold.withValues(alpha: 0.2),
                      checkmarkColor: _Occ.gold,
                      labelStyle: TextStyle(
                        color: filter.preset == preset ? _Occ.gold : _Occ.muted,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      side: BorderSide(
                        color: filter.preset == preset
                            ? _Occ.gold.withValues(alpha: 0.5)
                            : _Occ.border,
                      ),
                      backgroundColor: _Occ.elevated,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: searchCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search action, module, correlation…',
                  hintStyle: TextStyle(color: _Occ.muted.withValues(alpha: 0.8)),
                  prefixIcon: const Icon(
                    LucideIcons.search,
                    size: 16,
                    color: _Occ.muted,
                  ),
                  filled: true,
                  fillColor: _Occ.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _Occ.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _Occ.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: _Occ.gold.withValues(alpha: 0.7)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                onChanged: filterCtrl.setQuery,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: searchAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator(color: _Occ.gold)),
            error: (e, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    userFacingError(e, fallback: 'Could not load audit rows.'),
                    style: const TextStyle(color: _Occ.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: onRefresh,
                    icon: const Icon(LucideIcons.refreshCw, size: 16),
                    label: const Text('Retry'),
                    style: _Occ.solid,
                  ),
                ],
              ),
            ),
            data: (rows) {
              if (rows.isEmpty) {
                return const Center(
                  child: Text(
                    'No matching records for this filter.',
                    style: TextStyle(color: _Occ.muted),
                  ),
                );
              }
              return Column(
                children: [
                  Row(
                    children: [
                      Text(
                        '${rows.length} records',
                        style: const TextStyle(
                          color: _Occ.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: ui.isBusy
                            ? null
                            : () async {
                                await controller.exportVisible(rows);
                                final csv =
                                    ref.read(auditControllerProvider).exportedCsv;
                                if (csv != null && context.mounted) {
                                  await Clipboard.setData(
                                    ClipboardData(text: csv),
                                  );
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('CSV copied to clipboard'),
                                    ),
                                  );
                                }
                              },
                        icon: const Icon(LucideIcons.download, size: 16),
                        label: const Text('Export CSV'),
                        style: _Occ.solid,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (context, i) {
                        final r = rows[i];
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: _Occ.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _Occ.border),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                r.severity.icon,
                                color: r.severity.color,
                                size: 16,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      r.timelineTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      '${r.module} · ${r.category.label} · '
                                      '${DateFormat('MMM d HH:mm').format(r.createdAt.toLocal())}',
                                      style: const TextStyle(
                                        color: _Occ.muted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                r.status.slug,
                                style: const TextStyle(
                                  color: _Occ.muted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
