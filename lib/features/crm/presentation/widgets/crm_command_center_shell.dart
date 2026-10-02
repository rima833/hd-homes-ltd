import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/constants/permissions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hdhomesproject/features/authentication/presentation/widgets/permission_gate.dart';
import 'package:hdhomesproject/features/crm/domain/entities/crm_models.dart';
import 'package:hdhomesproject/features/crm/presentation/providers/crm_controller.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

abstract final class CrmDeskColors {
  static const bg = Color(0xFF0B0E14);
  static const sidebar = Color(0xFF0F1218);
  static const surface = Color(0xFF141820);
  static const elevated = Color(0xFF1A1F28);
  static const border = Color(0x18FFFFFF);
  static const muted = Color(0xFF8B929E);
  static const gold = AppColors.primaryGold;
  static const green = Color(0xFF22C55E);
  static const amber = Color(0xFFF59E0B);
}

class CrmNavSection {
  const CrmNavSection({required this.title, required this.items});

  final String title;
  final List<CrmNavItem> items;
}

class CrmNavItem {
  const CrmNavItem({
    required this.tab,
    required this.icon,
    this.badge,
    this.urgent = false,
  });

  final CrmCommandTab tab;
  final IconData icon;
  final int? badge;
  final bool urgent;
}

List<CrmNavSection> buildCrmNavSections(
  CrmCommandCenterSnapshot snap, {
  int calculatorLeadCount = 0,
}) {
  final openLeads = snap.leads
      .where(
        (l) => l.status != CrmLeadStatus.won && l.status != CrmLeadStatus.lost,
      )
      .length;
  final openTasks = snap.tasks
      .where(
        (t) =>
            t.status == CrmTaskStatus.open ||
            t.status == CrmTaskStatus.inProgress,
      )
      .length;
  final pendingPayments = snap.payments
      .where(
        (p) =>
            p.status.toLowerCase().contains('pending') ||
            p.status.toLowerCase().contains('review'),
      )
      .length;
  final now = DateTime.now();
  final todayEnd = DateTime(
    now.year,
    now.month,
    now.day,
  ).add(const Duration(days: 1));
  final dueTasks = snap.tasks
      .where(
        (t) =>
            (t.status == CrmTaskStatus.open ||
                t.status == CrmTaskStatus.inProgress) &&
            t.dueAt != null &&
            t.dueAt!.isBefore(todayEnd),
      )
      .length;

  return [
    CrmNavSection(
      title: 'Command',
      items: [
        const CrmNavItem(
          tab: CrmCommandTab.overview,
          icon: LucideIcons.layoutDashboard,
        ),
      ],
    ),
    CrmNavSection(
      title: 'Pipeline',
      items: [
        CrmNavItem(
          tab: CrmCommandTab.leads,
          icon: LucideIcons.users,
          badge: openLeads > 0 ? openLeads : null,
        ),
        CrmNavItem(
          tab: CrmCommandTab.pipeline,
          icon: LucideIcons.gitBranch,
          badge: openLeads > 0 ? openLeads : null,
        ),
        CrmNavItem(
          tab: CrmCommandTab.clients,
          icon: LucideIcons.briefcase,
          badge: snap.clients.isNotEmpty ? snap.clients.length : null,
        ),
        CrmNavItem(tab: CrmCommandTab.client360, icon: LucideIcons.userCircle2),
      ],
    ),
    CrmNavSection(
      title: 'Inbound',
      items: [
        CrmNavItem(
          tab: CrmCommandTab.inspections,
          icon: LucideIcons.calendarCheck,
          badge: snap.inspections.isNotEmpty ? snap.inspections.length : null,
        ),
        CrmNavItem(
          tab: CrmCommandTab.applications,
          icon: LucideIcons.fileText,
          badge: snap.applications.isNotEmpty ? snap.applications.length : null,
        ),
        CrmNavItem(
          tab: CrmCommandTab.calculator,
          icon: LucideIcons.calculator,
          badge: calculatorLeadCount > 0 ? calculatorLeadCount : null,
          urgent: calculatorLeadCount > 0,
        ),
        CrmNavItem(
          tab: CrmCommandTab.payments,
          icon: LucideIcons.wallet,
          badge: pendingPayments > 0 ? pendingPayments : null,
          urgent: pendingPayments > 0,
        ),
        CrmNavItem(
          tab: CrmCommandTab.properties,
          icon: LucideIcons.building2,
          badge: snap.properties.isNotEmpty ? snap.properties.length : null,
        ),
      ],
    ),
    CrmNavSection(
      title: 'Work',
      items: [
        CrmNavItem(
          tab: CrmCommandTab.tasks,
          icon: LucideIcons.checkSquare,
          badge: dueTasks > 0 ? dueTasks : (openTasks > 0 ? openTasks : null),
          urgent: dueTasks > 0,
        ),
        CrmNavItem(
          tab: CrmCommandTab.appointments,
          icon: LucideIcons.calendar,
          badge: snap.appointments.isNotEmpty ? snap.appointments.length : null,
        ),
        CrmNavItem(
          tab: CrmCommandTab.activity,
          icon: LucideIcons.activity,
          badge: snap.timeline.isNotEmpty ? snap.timeline.length : null,
        ),
      ],
    ),
    CrmNavSection(
      title: 'Insights',
      items: [
        const CrmNavItem(
          tab: CrmCommandTab.analytics,
          icon: LucideIcons.barChart3,
        ),
      ],
    ),
  ];
}

bool crmTabUsesSearch(CrmCommandTab tab) => switch (tab) {
  CrmCommandTab.leads ||
  CrmCommandTab.pipeline ||
  CrmCommandTab.clients ||
  CrmCommandTab.properties ||
  CrmCommandTab.inspections ||
  CrmCommandTab.applications ||
  CrmCommandTab.calculator ||
  CrmCommandTab.payments => true,
  _ => false,
};

bool crmTabUsesStageFilter(CrmCommandTab tab) =>
    tab == CrmCommandTab.leads || tab == CrmCommandTab.pipeline;

bool crmTabShowsKpis(CrmCommandTab tab) =>
    tab == CrmCommandTab.overview ||
    tab == CrmCommandTab.leads ||
    tab == CrmCommandTab.pipeline;

class CrmDeskSidebar extends StatelessWidget {
  const CrmDeskSidebar({
    super.key,
    required this.sections,
    required this.selected,
    required this.onSelect,
    required this.live,
    this.onClose,
  });

  final List<CrmNavSection> sections;
  final CrmCommandTab selected;
  final ValueChanged<CrmCommandTab> onSelect;
  final bool live;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: CrmDeskColors.sidebar,
        border: Border(right: BorderSide(color: CrmDeskColors.border)),
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
                        'SALES DESK',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: CrmDeskColors.gold,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Command Center',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
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
                    icon: const Icon(LucideIcons.x, color: CrmDeskColors.muted),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
            child: Text(
              live
                  ? 'Your latest records are here.'
                  : "We're gathering the latest records.",
              style: const TextStyle(
                color: CrmDeskColors.muted,
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
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
                      section.title.toUpperCase(),
                      style: const TextStyle(
                        color: CrmDeskColors.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                  for (final item in section.items)
                    _NavTile(
                      item: item,
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

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final CrmNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final badge = item.badge;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected
            ? CrmDeskColors.gold.withValues(alpha: 0.12)
            : Colors.transparent,
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
                    ? CrmDeskColors.gold.withValues(alpha: 0.55)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 18,
                  color: selected ? CrmDeskColors.gold : CrmDeskColors.muted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.tab.label,
                    style: TextStyle(
                      color: selected ? Colors.white : CrmDeskColors.muted,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13.5,
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: item.urgent
                          ? CrmDeskColors.amber.withValues(alpha: 0.18)
                          : CrmDeskColors.elevated,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: item.urgent
                            ? CrmDeskColors.amber.withValues(alpha: 0.55)
                            : CrmDeskColors.border,
                      ),
                    ),
                    child: Text(
                      badge > 99 ? '99+' : '$badge',
                      style: TextStyle(
                        color: item.urgent
                            ? CrmDeskColors.amber
                            : CrmDeskColors.muted,
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

class CrmDeskTopBar extends StatelessWidget {
  const CrmDeskTopBar({
    super.key,
    required this.tab,
    required this.live,
    required this.loadedAt,
    required this.onMenu,
    required this.onRefresh,
    required this.onExport,
    required this.onAddLead,
    required this.onAddClient,
    this.showMenu = false,
  });

  final CrmCommandTab tab;
  final bool live;
  final DateTime? loadedAt;
  final VoidCallback? onMenu;
  final bool showMenu;
  final Future<void> Function() onRefresh;
  final VoidCallback onExport;
  final VoidCallback onAddLead;
  final VoidCallback onAddClient;

  @override
  Widget build(BuildContext context) {
    final synced = loadedAt == null
        ? null
        : 'Synced ${DateFormat.jm().format(loadedAt!.toLocal())}';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: const BoxDecoration(
        color: CrmDeskColors.surface,
        border: Border(bottom: BorderSide(color: CrmDeskColors.border)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 900;
          return Row(
            children: [
              if (showMenu && onMenu != null)
                IconButton(
                  onPressed: onMenu,
                  icon: const Icon(
                    LucideIcons.panelLeft,
                    color: CrmDeskColors.muted,
                  ),
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
                    if (synced != null)
                      Text(
                        synced,
                        style: const TextStyle(
                          color: CrmDeskColors.muted,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              if (!narrow) ...[
                PermissionGateAny(
                  permissions: const [
                    PermissionSlugs.crmAnalytics,
                    PermissionSlugs.crmWrite,
                  ],
                  child: OutlinedButton.icon(
                    onPressed: onExport,
                    icon: const Icon(LucideIcons.download, size: 15),
                    label: const Text('Export'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: CrmDeskColors.gold,
                      side: BorderSide(
                        color: CrmDeskColors.gold.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              IconButton(
                tooltip: 'Refresh',
                onPressed: onRefresh,
                icon: Icon(
                  LucideIcons.refreshCw,
                  size: 18,
                  color: live ? CrmDeskColors.green : CrmDeskColors.muted,
                ),
              ),
              if (narrow)
                _CrmOverflowMenu(
                  onExport: onExport,
                  onAddLead: onAddLead,
                  onAddClient: onAddClient,
                )
              else ...[
                PermissionGateAny(
                  permissions: const [PermissionSlugs.crmWrite],
                  child: OutlinedButton.icon(
                    onPressed: onAddClient,
                    icon: const Icon(LucideIcons.userPlus, size: 15),
                    label: const Text('Client'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: CrmDeskColors.gold,
                      side: BorderSide(
                        color: CrmDeskColors.gold.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PermissionGateAny(
                  permissions: const [
                    PermissionSlugs.crmLeads,
                    PermissionSlugs.crmWrite,
                  ],
                  child: FilledButton.icon(
                    onPressed: onAddLead,
                    icon: const Icon(LucideIcons.plus, size: 15),
                    label: const Text('Lead'),
                    style: FilledButton.styleFrom(
                      backgroundColor: CrmDeskColors.gold,
                      foregroundColor: CrmDeskColors.bg,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class CrmDeskEmptyState extends StatelessWidget {
  const CrmDeskEmptyState({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 40,
              color: CrmDeskColors.muted.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: CrmDeskColors.muted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _CrmOverflowMenu extends ConsumerWidget {
  const _CrmOverflowMenu({
    required this.onExport,
    required this.onAddLead,
    required this.onAddClient,
  });

  final VoidCallback onExport;
  final VoidCallback onAddLead;
  final VoidCallback onAddClient;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = <PopupMenuEntry<String>>[];
    if (evaluatePermissionAny(ref, const [
      PermissionSlugs.crmAnalytics,
      PermissionSlugs.crmWrite,
    ])) {
      items.add(
        const PopupMenuItem(value: 'export', child: Text('Export leads')),
      );
    }
    if (evaluatePermissionAny(ref, const [
      PermissionSlugs.crmLeads,
      PermissionSlugs.crmWrite,
    ])) {
      items.add(const PopupMenuItem(value: 'lead', child: Text('New lead')));
    }
    if (evaluatePermissionAny(ref, const [PermissionSlugs.crmWrite])) {
      items.add(
        const PopupMenuItem(value: 'client', child: Text('New client')),
      );
    }
    if (items.isEmpty) return const SizedBox.shrink();

    return PopupMenuButton<String>(
      icon: const Icon(LucideIcons.moreVertical, color: CrmDeskColors.muted),
      color: CrmDeskColors.elevated,
      onSelected: (v) {
        switch (v) {
          case 'export':
            onExport();
          case 'lead':
            onAddLead();
          case 'client':
            onAddClient();
        }
      },
      itemBuilder: (_) => items,
    );
  }
}
