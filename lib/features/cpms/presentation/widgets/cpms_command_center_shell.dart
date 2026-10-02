import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/config/ai_features.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/cpms/domain/entities/cpms_models.dart';
import 'package:hdhomesproject/features/cpms/presentation/providers/cpms_controller.dart';
import 'package:lucide_icons/lucide_icons.dart';

abstract final class CpmsDeskColors {
  static const bg = Color(0xFF0B0E14);
  static const sidebar = Color(0xFF0F1218);
  static const surface = Color(0xFF141820);
  static const elevated = Color(0xFF1A1F28);
  static const border = Color(0x18FFFFFF);
  static const muted = Color(0xFF8B929E);
  static const gold = AppColors.primaryGold;
  static const green = Color(0xFF22C55E);
  static const amber = Color(0xFFF59E0B);
  static const red = Color(0xFFEF4444);
}

class CpmsNavSection {
  const CpmsNavSection({required this.title, required this.items});

  final String title;
  final List<CpmsNavItem> items;
}

class CpmsNavItem {
  const CpmsNavItem({
    required this.tab,
    required this.icon,
    this.badge,
    this.urgent = false,
  });

  final CpmsCommandTab tab;
  final IconData icon;
  final int? badge;
  final bool urgent;
}

List<CpmsNavSection> buildCpmsNavSections(CpmsCommandCenterSnapshot snap) {
  final delayed = snap.projects.where((p) => p.isDelayed).length;
  final openMilestones = snap.milestones
      .where((m) => m.status != MilestoneStatus.completed)
      .length;
  final blocked = snap.tasks
      .where((t) => t.status == TaskStatus.blocked)
      .length;
  final pendingCo = snap.changeOrders
      .where(
        (c) =>
            c.status == ChangeOrderStatus.pending ||
            c.status == ChangeOrderStatus.draft,
      )
      .length;
  final openDefects = snap.defects
      .where((d) => d.status.toLowerCase() != 'closed')
      .length;
  final safetyOpen = snap.safetyIncidents.length;

  final sections = <CpmsNavSection>[
    CpmsNavSection(
      title: 'Command',
      items: [
        const CpmsNavItem(
          tab: CpmsCommandTab.overview,
          icon: LucideIcons.radio,
        ),
        CpmsNavItem(
          tab: CpmsCommandTab.projects,
          icon: LucideIcons.hardHat,
          badge: delayed > 0
              ? delayed
              : (snap.projects.isNotEmpty ? snap.projects.length : null),
          urgent: delayed > 0,
        ),
        const CpmsNavItem(tab: CpmsCommandTab.liveFeed, icon: LucideIcons.rss),
      ],
    ),
    CpmsNavSection(
      title: 'Delivery',
      items: [
        CpmsNavItem(
          tab: CpmsCommandTab.milestones,
          icon: LucideIcons.flag,
          badge: openMilestones > 0 ? openMilestones : null,
        ),
        CpmsNavItem(
          tab: CpmsCommandTab.tasks,
          icon: LucideIcons.checkSquare,
          badge: blocked > 0 ? blocked : null,
          urgent: blocked > 0,
        ),
        CpmsNavItem(
          tab: CpmsCommandTab.diary,
          icon: LucideIcons.bookOpen,
          badge: snap.siteDiaries.isNotEmpty ? snap.siteDiaries.length : null,
        ),
      ],
    ),
    CpmsNavSection(
      title: 'Ops',
      items: [
        CpmsNavItem(
          tab: CpmsCommandTab.procurement,
          icon: LucideIcons.package,
          badge: pendingCo > 0 ? pendingCo : null,
          urgent: pendingCo > 0,
        ),
        const CpmsNavItem(tab: CpmsCommandTab.budget, icon: LucideIcons.wallet),
        CpmsNavItem(
          tab: CpmsCommandTab.quality,
          icon: LucideIcons.badgeCheck,
          badge: openDefects > 0 ? openDefects : null,
          urgent: openDefects > 0,
        ),
        CpmsNavItem(
          tab: CpmsCommandTab.safety,
          icon: LucideIcons.shieldAlert,
          badge: safetyOpen > 0 ? safetyOpen : null,
          urgent: safetyOpen > 0,
        ),
      ],
    ),
    const CpmsNavSection(
      title: 'Tools',
      items: [CpmsNavItem(tab: CpmsCommandTab.wizard, icon: LucideIcons.wand2)],
    ),
  ];

  if (kAiFeaturesEnabled) {
    sections.add(
      const CpmsNavSection(
        title: 'Intelligence',
        items: [
          CpmsNavItem(tab: CpmsCommandTab.ai, icon: LucideIcons.sparkles),
        ],
      ),
    );
  }

  return sections;
}

class CpmsDeskSidebar extends StatelessWidget {
  const CpmsDeskSidebar({
    super.key,
    required this.sections,
    required this.selected,
    required this.onSelect,
    required this.live,
    required this.fromRemote,
    this.onClose,
  });

  final List<CpmsNavSection> sections;
  final CpmsCommandTab selected;
  final ValueChanged<CpmsCommandTab> onSelect;
  final bool live;
  final bool fromRemote;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: CpmsDeskColors.sidebar,
        border: Border(right: BorderSide(color: CpmsDeskColors.border)),
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
                        'CONSTRUCTION DESK',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: CpmsDeskColors.gold,
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
                    icon: const Icon(
                      LucideIcons.x,
                      color: CpmsDeskColors.muted,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
            child: _SyncPill(
              live: live || fromRemote,
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
                        color: CpmsDeskColors.muted,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CpmsDeskColors.gold.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: CpmsDeskColors.gold.withValues(alpha: 0.25),
                ),
              ),
              child: const Text(
                'Publish progress from a project to update the public site, client portal, and investor feed in realtime.',
                style: TextStyle(
                  color: CpmsDeskColors.muted,
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncPill extends StatelessWidget {
  const _SyncPill({required this.live});

  final bool live;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        live
            ? 'Your latest records are here.'
            : "We're gathering the latest records.",
        style: const TextStyle(
          color: CpmsDeskColors.muted,
          fontSize: 12,
          height: 1.35,
          fontWeight: FontWeight.w500,
        ),
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

  final CpmsNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected
            ? CpmsDeskColors.gold.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 16,
                  color: selected ? CpmsDeskColors.gold : CpmsDeskColors.muted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.tab.label,
                    style: TextStyle(
                      color: selected ? Colors.white : CpmsDeskColors.muted,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (item.badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (item.urgent
                                  ? CpmsDeskColors.red
                                  : CpmsDeskColors.gold)
                              .withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${item.badge}',
                      style: TextStyle(
                        color: item.urgent
                            ? CpmsDeskColors.red
                            : CpmsDeskColors.gold,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
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

class CpmsDeskTopBar extends StatelessWidget {
  const CpmsDeskTopBar({
    super.key,
    required this.tab,
    required this.live,
    required this.fromRemote,
    required this.onRefresh,
    this.showMenu = false,
    this.onMenu,
    this.onPublish,
    this.onNewProject,
  });

  final CpmsCommandTab tab;
  final bool live;
  final bool fromRemote;
  final VoidCallback onRefresh;
  final bool showMenu;
  final VoidCallback? onMenu;
  final VoidCallback? onPublish;
  final VoidCallback? onNewProject;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: const BoxDecoration(
        color: CpmsDeskColors.surface,
        border: Border(bottom: BorderSide(color: CpmsDeskColors.border)),
      ),
      child: Row(
        children: [
          if (showMenu)
            IconButton(
              onPressed: onMenu,
              icon: const Icon(LucideIcons.menu, color: Colors.white),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tab.label,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Milestones · procurement · quality · live publish',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: CpmsDeskColors.muted),
                ),
              ],
            ),
          ),
          if (onPublish != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.icon(
                onPressed: onPublish,
                icon: const Icon(LucideIcons.radio, size: 16),
                label: const Text('Publish live'),
                style: FilledButton.styleFrom(
                  backgroundColor: CpmsDeskColors.gold,
                  foregroundColor: const Color(0xFF1A1205),
                ),
              ),
            ),
          if (onNewProject != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: OutlinedButton.icon(
                onPressed: onNewProject,
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('New project'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: CpmsDeskColors.border),
                ),
              ),
            ),
          IconButton(
            tooltip: live || fromRemote ? 'Synced' : 'Refresh',
            onPressed: onRefresh,
            icon: Icon(
              LucideIcons.refreshCw,
              color: live || fromRemote
                  ? CpmsDeskColors.green
                  : CpmsDeskColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Project filter shown on operational tabs (milestones, budget, etc.).
class CpmsDeskProjectScope extends StatelessWidget {
  const CpmsDeskProjectScope({
    super.key,
    required this.projects,
    required this.selectedProjectId,
    required this.onChanged,
  });

  final List<CpmsProject> projects;
  final String? selectedProjectId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (projects.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          const Icon(LucideIcons.filter, size: 16, color: CpmsDeskColors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<String?>(
              value: selectedProjectId,
              isExpanded: true,
              dropdownColor: CpmsDeskColors.elevated,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Project scope',
                labelStyle: const TextStyle(color: CpmsDeskColors.muted),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: CpmsDeskColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: CpmsDeskColors.border),
                ),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All projects'),
                ),
                for (final p in projects)
                  DropdownMenuItem<String?>(value: p.id, child: Text(p.name)),
              ],
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class CpmsKpiStrip extends StatelessWidget {
  const CpmsKpiStrip({super.key, required this.kpis, this.onSelected});

  final List<CpmsKpi> kpis;
  final ValueChanged<CpmsKpi>? onSelected;

  @override
  Widget build(BuildContext context) {
    if (kpis.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1100
              ? 5
              : constraints.maxWidth >= 720
              ? 3
              : 2;
          final gap = 10.0;
          final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final kpi in kpis)
                SizedBox(
                  width: width,
                  child: Material(
                    color: CpmsDeskColors.elevated,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: onSelected == null ? null : () => onSelected!(kpi),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: CpmsDeskColors.gold.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              kpi.label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: CpmsDeskColors.muted,
                                fontSize: 11,
                                height: 1.2,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              kpi.displayValue,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
