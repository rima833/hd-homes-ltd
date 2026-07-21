import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/cpms/domain/entities/cpms_models.dart';
import 'package:hdhomesproject/features/cpms/domain/services/cpms_service.dart';
import 'package:hdhomesproject/features/cpms/presentation/providers/cpms_controller.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Volume 4 Part 6 — Construction Command Center™ admin workspace.
class ConstructionCommandCenterPage extends ConsumerWidget {
  const ConstructionCommandCenterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSnap = ref.watch(cpmsSnapshotProvider);
    final ui = ref.watch(cpmsControllerProvider);
    final controller = ref.read(cpmsControllerProvider.notifier);

    return Scaffold(
      body: asyncSnap.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Failed to load Construction Command Center: $e'),
        ),
        data: (snap) {
          final tickerKpis = snap.kpis;
          final ticker = tickerKpis.isEmpty
              ? 'Construction live'
              : '${tickerKpis[ui.tickerIndex % tickerKpis.length].label}: '
                  '${tickerKpis[ui.tickerIndex % tickerKpis.length].displayValue}';

          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: CustomScrollView(
              slivers: [
                ContainedPadding(
                  child: _CpmsHeader(
                    ticker: ticker,
                    fromRemote: snap.fromRemote,
                    onRefresh: controller.refresh,
                    onOpenWarRoom: () =>
                        controller.setTab(CpmsCommandTab.overview),
                    onOpenWizard: () =>
                        controller.setTab(CpmsCommandTab.wizard),
                  ),
                ),
                if (ui.lastMessage != null)
                  ContainedPadding(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Material(
                        color: AppColors.gold.withValues(alpha: 0.15),
                        borderRadius: AppRadius.cardBorder,
                        child: ListTile(
                          leading: const Icon(
                            LucideIcons.info,
                            color: AppColors.gold,
                          ),
                          title: Text(ui.lastMessage!),
                          dense: true,
                          trailing: IconButton(
                            icon: const Icon(LucideIcons.x, size: 16),
                            onPressed: controller.clearMessage,
                          ),
                        ),
                      ),
                    ),
                  ),
                ContainedPadding(child: _KpiStrip(kpis: snap.kpis)),
                ContainedPadding(
                  child: _SearchAndFilters(
                    ui: ui,
                    onSearch: controller.setSearch,
                    onStatus: controller.setStatusFilter,
                  ),
                ),
                ContainedPadding(
                  child: _TabBar(
                    selected: ui.selectedTab,
                    onSelect: controller.setTab,
                  ),
                ),
                ..._tabSlivers(context, ref, snap, ui, controller),
                const ContainedPadding(child: SizedBox(height: 32)),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _tabSlivers(
    BuildContext context,
    WidgetRef ref,
    CpmsCommandCenterSnapshot snap,
    CpmsUiState ui,
    CpmsController controller,
  ) {
    switch (ui.selectedTab) {
      case CpmsCommandTab.overview:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'War Room',
              icon: LucideIcons.radio,
              child: _WarRoomPanel(snap: snap),
            ),
          ),
          ContainedPadding(
            child: _SectionCard(
              title: 'Activity Timeline',
              icon: LucideIcons.gitBranch,
              child: _ActivityList(activities: snap.activities),
            ),
          ),
          ContainedPadding(
            child: _SectionCard(
              title: 'Construction Alerts',
              icon: LucideIcons.bell,
              child: _AlertList(alerts: snap.alerts),
            ),
          ),
        ];
      case CpmsCommandTab.projects:
        final project = controller.selectedProject(snap);
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Projects',
              icon: LucideIcons.hardHat,
              child: _ProjectList(
                projects: controller.filteredProjects(snap),
                selectedId: project?.id,
                onOpen: controller.selectProject,
              ),
            ),
          ),
          if (project != null)
            ContainedPadding(
              child: _SectionCard(
                title: 'Digital Construction Twin™',
                icon: LucideIcons.box,
                child: _ProjectTwinPanel(
                  project: project,
                  onAiSummary: () {
                    final summary = ref
                        .read(cpmsServiceProvider)
                        .generateProgressSummary(project);
                    controller.setMessage(summary);
                  },
                ),
              ),
            ),
        ];
      case CpmsCommandTab.milestones:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Milestones',
              icon: LucideIcons.flag,
              child: _MilestoneList(milestones: snap.milestones),
            ),
          ),
        ];
      case CpmsCommandTab.tasks:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Tasks',
              icon: LucideIcons.checkSquare,
              child: _TaskList(tasks: snap.tasks),
            ),
          ),
        ];
      case CpmsCommandTab.procurement:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Procurement & Change Orders',
              icon: LucideIcons.package,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProcurementList(requests: snap.procurementRequests),
                  const Divider(height: 24),
                  Text(
                    'Contractors',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  _ContractorList(contractors: snap.contractors),
                  const Divider(height: 24),
                  Text(
                    'Change Orders',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  _ChangeOrderList(orders: snap.changeOrders),
                ],
              ),
            ),
          ),
        ];
      case CpmsCommandTab.budget:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Budget Control',
              icon: LucideIcons.wallet,
              child: _BudgetPanel(summaries: snap.budgetSummaries()),
            ),
          ),
        ];
      case CpmsCommandTab.quality:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Quality & Defect Intelligence',
              icon: LucideIcons.shieldCheck,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _QualityList(checks: snap.qualityChecks),
                  const Divider(height: 24),
                  Text(
                    'Defects',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  _DefectList(defects: snap.defects),
                  const Divider(height: 24),
                  Text(
                    'Inspections',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  _InspectionList(inspections: snap.inspections),
                ],
              ),
            ),
          ),
        ];
      case CpmsCommandTab.safety:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Safety',
              icon: LucideIcons.alertTriangle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SafetyList(incidents: snap.safetyIncidents),
                  const Divider(height: 24),
                  Text(
                    'Risk Register',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  _RiskList(risks: snap.risks),
                ],
              ),
            ),
          ),
        ];
      case CpmsCommandTab.diary:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Site Diaries',
              icon: LucideIcons.bookOpen,
              child: _DiaryList(entries: snap.siteDiaries),
            ),
          ),
        ];
      case CpmsCommandTab.ai:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Smart Progress Intelligence™',
              icon: LucideIcons.sparkles,
              child: _AiPanel(
                insights: snap.aiInsights,
                intelligence: snap.progressIntelligence,
                disclaimer: snap.forecastDisclaimer,
              ),
            ),
          ),
        ];
      case CpmsCommandTab.wizard:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Project Creation Wizard',
              icon: LucideIcons.wand2,
              child: _WizardPanel(
                draft: ui.wizard,
                onUpdate: controller.updateWizard,
                onNext: controller.wizardNext,
                onPrevious: controller.wizardPrevious,
                onReset: controller.wizardReset,
                onSubmit: () {
                  controller.setMessage(
                    'Wizard draft saved locally (Phase 1 stub): '
                    '${ui.wizard.name.isEmpty ? 'Untitled' : ui.wizard.name} · '
                    'step ${ui.wizard.step + 1}/${ui.wizard.totalSteps}.',
                  );
                },
              ),
            ),
          ),
        ];
    }
  }
}

class ContainedPadding extends StatelessWidget {
  const ContainedPadding({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(child: child);
  }
}

class _CpmsHeader extends StatelessWidget {
  const _CpmsHeader({
    required this.ticker,
    required this.fromRemote,
    required this.onRefresh,
    required this.onOpenWarRoom,
    required this.onOpenWizard,
  });

  final String ticker;
  final bool fromRemote;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpenWarRoom;
  final VoidCallback onOpenWizard;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.charcoal,
            AppColors.deepBlack.withValues(alpha: 0.9),
          ],
        ),
        border: Border(
          bottom: BorderSide(color: AppColors.gold.withValues(alpha: 0.25)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 640;
              final title = Text(
                'Construction Command Center™',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
              );
              final actions = Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: onOpenWarRoom,
                    icon: const Icon(LucideIcons.radio, size: 16),
                    label: const Text('War Room'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.deepBlack,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: onOpenWizard,
                    icon: const Icon(LucideIcons.wand2, size: 16),
                    label: const Text('New Project'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.white,
                      side: BorderSide(
                        color: AppColors.gold.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: () => onRefresh(),
                    icon: const Icon(
                      LucideIcons.rotateCcw,
                      color: AppColors.white,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.15),
                      borderRadius: AppRadius.cardBorder,
                    ),
                    child: Text(
                      fromRemote ? 'LIVE' : 'DEMO',
                      style: TextStyle(
                        color:
                            fromRemote ? Colors.greenAccent : AppColors.gold,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              );
              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    const SizedBox(height: 8),
                    Text(
                      'Milestones · procurement · quality · site diaries',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondaryDark,
                          ),
                    ),
                    const SizedBox(height: 12),
                    actions,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        title,
                        Text(
                          'Milestones · procurement · quality · site diaries',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondaryDark,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  actions,
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.12),
              borderRadius: AppRadius.cardBorder,
            ),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.activity,
                  size: 16,
                  color: AppColors.gold,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ticker,
                    style: const TextStyle(color: AppColors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiStrip extends StatelessWidget {
  const _KpiStrip({required this.kpis});

  final List<CpmsKpi> kpis;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        scrollDirection: Axis.horizontal,
        itemCount: kpis.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final kpi = kpis[i];
          return Container(
            width: 148,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: AppRadius.cardBorder,
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kpi.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const Spacer(),
                Text(
                  kpi.displayValue,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SearchAndFilters extends StatelessWidget {
  const _SearchAndFilters({
    required this.ui,
    required this.onSearch,
    required this.onStatus,
  });

  final CpmsUiState ui;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onStatus;

  @override
  Widget build(BuildContext context) {
    final statuses = ConstructionProjectStatus.values;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        children: [
          TextField(
            onChanged: onSearch,
            decoration: InputDecoration(
              hintText: 'Search projects, codes, managers…',
              prefixIcon: const Icon(LucideIcons.search, size: 18),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: AppRadius.cardBorder,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('All'),
                    selected: ui.statusFilter == null,
                    onSelected: (_) => onStatus(null),
                    selectedColor: AppColors.gold.withValues(alpha: 0.35),
                  ),
                ),
                ...statuses.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(s.label),
                      selected: ui.statusFilter == s.slug,
                      onSelected: (_) => onStatus(s.slug),
                      selectedColor: AppColors.gold.withValues(alpha: 0.35),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.selected, required this.onSelect});

  final CpmsCommandTab selected;
  final ValueChanged<CpmsCommandTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: CpmsCommandTab.values
            .map(
              (t) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(t.label),
                  selected: selected == t,
                  onSelected: (_) => onSelect(t),
                  selectedColor: AppColors.gold.withValues(alpha: 0.35),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: AppRadius.cardBorder,
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.15)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: AppColors.gold),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _WarRoomPanel extends StatelessWidget {
  const _WarRoomPanel({required this.snap});

  final CpmsCommandCenterSnapshot snap;

  @override
  Widget build(BuildContext context) {
    final delayed = CpmsService.detectDelayedProjects(snap.projects);
    final pendingCos = snap.changeOrders
        .where((c) => c.status == ChangeOrderStatus.pending)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Live escalation surface — delayed sites, change orders, and open safety.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        if (delayed.isEmpty)
          const Text('No delayed projects in view.')
        else
          ...delayed.map(
            (p) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.clock, color: Colors.orange),
              title: Text(p.name),
              subtitle: Text(
                '${p.delayDays}d slip · ${p.riskLevel.label} risk · '
                '${p.progressPct.toStringAsFixed(0)}%',
              ),
              dense: true,
            ),
          ),
        if (pendingCos.isNotEmpty) ...[
          const Divider(),
          ...pendingCos.map(
            (c) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.fileWarning, color: AppColors.gold),
              title: Text('${c.changeCode} · ${c.title}'),
              subtitle: Text(
                '${c.costDisplay} · +${c.scheduleImpactDays}d · pending approval',
              ),
              dense: true,
            ),
          ),
        ],
        if (snap.safetyIncidents.isNotEmpty) ...[
          const Divider(),
          ...snap.safetyIncidents.take(2).map(
                (s) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    LucideIcons.shieldAlert,
                    color: Colors.redAccent,
                  ),
                  title: Text(s.title),
                  subtitle: Text('${s.severity.label} · ${s.status}'),
                  dense: true,
                ),
              ),
        ],
      ],
    );
  }
}

class _ProjectList extends StatelessWidget {
  const _ProjectList({
    required this.projects,
    required this.selectedId,
    required this.onOpen,
  });

  final List<CpmsProject> projects;
  final String? selectedId;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    if (projects.isEmpty) return const Text('No projects match filters.');
    return Column(
      children: projects
          .map(
            (p) => ListTile(
              selected: p.id == selectedId,
              onTap: () => onOpen(p.id),
              contentPadding: EdgeInsets.zero,
              title: Text(p.name),
              subtitle: Text(
                '${p.projectCode} · ${p.status.label} · '
                '${p.progressPct.toStringAsFixed(0)}% · ${p.spentDisplay} / ${p.budgetDisplay}',
              ),
              trailing: p.isDelayed
                  ? const Icon(LucideIcons.alertCircle, color: Colors.orange)
                  : null,
              dense: true,
            ),
          )
          .toList(),
    );
  }
}

class _ProjectTwinPanel extends StatelessWidget {
  const _ProjectTwinPanel({
    required this.project,
    required this.onAiSummary,
  });

  final CpmsProject project;
  final VoidCallback onAiSummary;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMd();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(project.name, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          '${project.locationLabel ?? '—'} · PM ${project.managerLabel ?? '—'}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: (project.progressPct / 100).clamp(0, 1),
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
          color: AppColors.gold,
        ),
        const SizedBox(height: 8),
        Text(
          'Progress ${project.progressPct.toStringAsFixed(1)}% · '
          'Risk ${project.riskLevel.label} · Delay ${project.delayDays}d',
        ),
        if (project.forecastCompletionAt != null) ...[
          const SizedBox(height: 6),
          Text(
            'Forecast completion ${df.format(project.forecastCompletionAt!)} · '
            '${project.forecastConfidencePct?.toStringAsFixed(0) ?? '—'}% confidence',
          ),
          Text(
            project.forecastDisclaimer,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
          ),
        ],
        if (project.aiSummary != null) ...[
          const SizedBox(height: 8),
          Text(project.aiSummary!),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: onAiSummary,
          icon: const Icon(LucideIcons.sparkles, size: 16),
          label: const Text('AI Progress Summary'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.gold,
            foregroundColor: AppColors.deepBlack,
          ),
        ),
      ],
    );
  }
}

class _MilestoneList extends StatelessWidget {
  const _MilestoneList({required this.milestones});

  final List<CpmsMilestone> milestones;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.MMMd();
    return Column(
      children: milestones
          .map(
            (m) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(m.name),
              subtitle: Text(
                '${m.projectName ?? m.projectId} · ${m.status.label}'
                '${m.dueDate != null ? ' · due ${df.format(m.dueDate!)}' : ''}'
                '${m.isCritical ? ' · critical' : ''}'
                '${m.isOverdue ? ' · OVERDUE' : ''}',
              ),
              trailing: Text('${m.progressPct.toStringAsFixed(0)}%'),
              dense: true,
            ),
          )
          .toList(),
    );
  }
}

class _TaskList extends StatelessWidget {
  const _TaskList({required this.tasks});

  final List<CpmsTask> tasks;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: tasks
          .map(
            (t) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(t.title),
              subtitle: Text(
                '${t.projectName ?? t.projectId} · ${t.status.label} · '
                '${t.priority}${t.assigneeLabel != null ? ' · ${t.assigneeLabel}' : ''}',
              ),
              trailing: t.status == TaskStatus.blocked
                  ? const Icon(LucideIcons.ban, color: Colors.redAccent, size: 18)
                  : null,
              dense: true,
            ),
          )
          .toList(),
    );
  }
}

class _ProcurementList extends StatelessWidget {
  const _ProcurementList({required this.requests});

  final List<CpmsProcurementRequest> requests;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: requests
          .map(
            (r) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${r.requestCode} · ${r.title}'),
              subtitle: Text('${r.status} · ${r.costDisplay}'),
              dense: true,
            ),
          )
          .toList(),
    );
  }
}

class _ContractorList extends StatelessWidget {
  const _ContractorList({required this.contractors});

  final List<CpmsContractor> contractors;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: contractors
          .map(
            (c) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(c.companyName),
              subtitle: Text(
                '${c.specialty ?? 'general'} · ${c.status} · ${c.valueDisplay}'
                '${c.performanceScore != null ? ' · score ${c.performanceScore!.toStringAsFixed(0)}' : ''}',
              ),
              dense: true,
            ),
          )
          .toList(),
    );
  }
}

class _ChangeOrderList extends StatelessWidget {
  const _ChangeOrderList({required this.orders});

  final List<CpmsChangeOrder> orders;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: orders
          .map(
            (c) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${c.changeCode} · ${c.title}'),
              subtitle: Text(
                '${c.status.label} · ${c.costDisplay} · +${c.scheduleImpactDays}d',
              ),
              dense: true,
            ),
          )
          .toList(),
    );
  }
}

class _BudgetPanel extends StatelessWidget {
  const _BudgetPanel({required this.summaries});

  final List<CpmsBudgetSummary> summaries;

  @override
  Widget build(BuildContext context) {
    if (summaries.isEmpty) return const Text('No budget lines loaded.');
    return Column(
      children: summaries
          .map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.projectName,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    'Budgeted ${formatCpmsMoney(s.budgeted)} · '
                    'Committed ${formatCpmsMoney(s.committed)} · '
                    'Spent ${formatCpmsMoney(s.spent)}',
                  ),
                  if (s.pendingChangeOrderImpact > 0)
                    Text(
                      'Pending CO impact ${formatCpmsMoney(s.pendingChangeOrderImpact)}',
                      style: const TextStyle(color: Colors.orange),
                    ),
                  ...s.lines.map(
                    (l) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(l.category),
                      subtitle: Text(l.description ?? ''),
                      trailing: Text(formatCpmsMoney(l.spentAmount)),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _QualityList extends StatelessWidget {
  const _QualityList({required this.checks});

  final List<CpmsQualityCheck> checks;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: checks
          .map(
            (q) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(q.title),
              subtitle: Text(
                '${q.status}${q.scorePct != null ? ' · ${q.scorePct!.toStringAsFixed(0)}%' : ''}'
                '${q.inspectorLabel != null ? ' · ${q.inspectorLabel}' : ''}',
              ),
              dense: true,
            ),
          )
          .toList(),
    );
  }
}

class _DefectList extends StatelessWidget {
  const _DefectList({required this.defects});

  final List<CpmsDefect> defects;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: defects
          .map(
            (d) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(d.title),
              subtitle: Text(
                '${d.severity.label} · ${d.status}'
                '${d.locationLabel != null ? ' · ${d.locationLabel}' : ''}',
              ),
              dense: true,
            ),
          )
          .toList(),
    );
  }
}

class _InspectionList extends StatelessWidget {
  const _InspectionList({required this.inspections});

  final List<CpmsInspection> inspections;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.MMMd().add_jm();
    return Column(
      children: inspections
          .map(
            (i) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(i.title),
              subtitle: Text(
                '${i.inspectionType} · ${i.status}'
                '${i.scheduledAt != null ? ' · ${df.format(i.scheduledAt!.toLocal())}' : ''}',
              ),
              dense: true,
            ),
          )
          .toList(),
    );
  }
}

class _SafetyList extends StatelessWidget {
  const _SafetyList({required this.incidents});

  final List<CpmsSafetyIncident> incidents;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: incidents
          .map(
            (s) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s.title),
              subtitle: Text(
                '${s.severity.label} · ${s.status}'
                '${s.locationLabel != null ? ' · ${s.locationLabel}' : ''}',
              ),
              dense: true,
            ),
          )
          .toList(),
    );
  }
}

class _RiskList extends StatelessWidget {
  const _RiskList({required this.risks});

  final List<CpmsRisk> risks;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: risks
          .map(
            (r) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(r.title),
              subtitle: Text(
                '${r.severity.label} · ${r.likelihood} · ${r.status}'
                '${r.mitigation != null ? ' · ${r.mitigation}' : ''}',
              ),
              dense: true,
            ),
          )
          .toList(),
    );
  }
}

class _DiaryList extends StatelessWidget {
  const _DiaryList({required this.entries});

  final List<CpmsSiteDiary> entries;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMd();
    return Column(
      children: entries
          .map(
            (e) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                '${e.projectName ?? e.projectId}'
                '${e.entryDate != null ? ' · ${df.format(e.entryDate!)}' : ''}',
              ),
              subtitle: Text(
                '${e.summary}'
                '${e.workforceCount != null ? '\nWorkforce ${e.workforceCount}' : ''}'
                '${e.blockers != null ? '\nBlockers: ${e.blockers}' : ''}',
              ),
              isThreeLine: e.blockers != null,
              dense: true,
            ),
          )
          .toList(),
    );
  }
}

class _ActivityList extends StatelessWidget {
  const _ActivityList({required this.activities});

  final List<CpmsActivity> activities;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: activities
          .map(
            (a) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.activity, size: 16),
              title: Text(a.title),
              subtitle: Text(
                '${a.eventType}${a.actorLabel != null ? ' · ${a.actorLabel}' : ''}'
                '${a.description != null ? '\n${a.description}' : ''}',
              ),
              dense: true,
            ),
          )
          .toList(),
    );
  }
}

class _AlertList extends StatelessWidget {
  const _AlertList({required this.alerts});

  final List<CpmsAlert> alerts;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: alerts
          .map(
            (a) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                LucideIcons.bell,
                size: 16,
                color: a.severity == 'critical'
                    ? Colors.redAccent
                    : a.severity == 'warning'
                        ? Colors.orange
                        : AppColors.gold,
              ),
              title: Text(a.title),
              subtitle: Text(a.body ?? a.severity),
              dense: true,
            ),
          )
          .toList(),
    );
  }
}

class _AiPanel extends StatelessWidget {
  const _AiPanel({
    required this.insights,
    required this.intelligence,
    required this.disclaimer,
  });

  final List<CpmsAiInsight> insights;
  final List<String> intelligence;
  final String disclaimer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AI-generated insights · not factual site telemetry',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
              ),
        ),
        const SizedBox(height: 8),
        ...insights.map(
          (i) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(LucideIcons.sparkles, color: AppColors.gold),
            title: Text(i.title),
            subtitle: Text(
              '${i.body}'
              '${i.confidencePct != null ? '\nConfidence ${i.confidencePct!.toStringAsFixed(0)}%' : ''}'
              '\n${i.disclaimer}',
            ),
            isThreeLine: true,
            dense: true,
          ),
        ),
        const Divider(height: 24),
        ...intelligence.map(
          (line) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(LucideIcons.circle, size: 8, color: AppColors.gold),
                const SizedBox(width: 8),
                Expanded(child: Text(line)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          disclaimer,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
              ),
        ),
      ],
    );
  }
}

class _WizardPanel extends StatelessWidget {
  const _WizardPanel({
    required this.draft,
    required this.onUpdate,
    required this.onNext,
    required this.onPrevious,
    required this.onReset,
    required this.onSubmit,
  });

  final CpmsWizardDraft draft;
  final ValueChanged<CpmsWizardDraft> onUpdate;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onReset;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final step = draft.step;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step ${step + 1} of ${draft.totalSteps}: ${draft.currentStepTitle}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: (step + 1) / draft.totalSteps,
          minHeight: 6,
          borderRadius: BorderRadius.circular(4),
          color: AppColors.gold,
        ),
        const SizedBox(height: 16),
        ..._stepFields(context),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: step == 0 ? null : onPrevious,
              child: const Text('Back'),
            ),
            if (step < draft.totalSteps - 1)
              FilledButton(
                onPressed: onNext,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.deepBlack,
                ),
                child: const Text('Next'),
              )
            else
              FilledButton(
                onPressed: onSubmit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.deepBlack,
                ),
                child: const Text('Save Draft'),
              ),
            TextButton(onPressed: onReset, child: const Text('Reset')),
          ],
        ),
      ],
    );
  }

  List<Widget> _stepFields(BuildContext context) {
    switch (draft.step) {
      case 0:
        return [
          TextFormField(
            initialValue: draft.name,
            decoration: const InputDecoration(labelText: 'Project name'),
            onChanged: (v) => onUpdate(draft.copyWith(name: v)),
          ),
          TextFormField(
            initialValue: draft.projectCode,
            decoration: const InputDecoration(labelText: 'Project code'),
            onChanged: (v) => onUpdate(draft.copyWith(projectCode: v)),
          ),
          TextFormField(
            initialValue: draft.locationLabel,
            decoration: const InputDecoration(labelText: 'Location'),
            onChanged: (v) => onUpdate(draft.copyWith(locationLabel: v)),
          ),
          TextFormField(
            initialValue: draft.managerLabel,
            decoration: const InputDecoration(labelText: 'Project manager'),
            onChanged: (v) => onUpdate(draft.copyWith(managerLabel: v)),
          ),
        ];
      case 1:
        return [
          Text(
            'Schedule planning (dates stored in draft — Phase 1 stub).',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Start: ${draft.startDate != null ? DateFormat.yMMMd().format(draft.startDate!) : 'Today'}',
          ),
          Text(
            'Target end: ${draft.targetEndDate != null ? DateFormat.yMMMd().format(draft.targetEndDate!) : 'TBD'}',
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => onUpdate(
              draft.copyWith(
                startDate: DateTime.now(),
                targetEndDate: DateTime.now().add(const Duration(days: 180)),
              ),
            ),
            child: const Text('Apply 6-month default schedule'),
          ),
        ];
      case 2:
        return [
          TextFormField(
            initialValue: draft.budgetTotal == 0
                ? ''
                : draft.budgetTotal.toStringAsFixed(0),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Budget total (NGN)',
              prefixText: '₦ ',
            ),
            onChanged: (v) => onUpdate(
              draft.copyWith(budgetTotal: double.tryParse(v) ?? 0),
            ),
          ),
        ];
      case 3:
        return [
          TextFormField(
            initialValue: draft.phaseNames.join(', '),
            decoration: const InputDecoration(
              labelText: 'Phases (comma-separated)',
              hintText: 'Enabling, Superstructure, MEP',
            ),
            onChanged: (v) => onUpdate(
              draft.copyWith(
                phaseNames: v
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList(),
              ),
            ),
          ),
        ];
      case 4:
        return [
          TextFormField(
            initialValue: draft.milestoneNames.join(', '),
            decoration: const InputDecoration(
              labelText: 'Milestones (comma-separated)',
            ),
            onChanged: (v) => onUpdate(
              draft.copyWith(
                milestoneNames: v
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList(),
              ),
            ),
          ),
        ];
      case 5:
        return [
          TextFormField(
            initialValue: draft.contractorNames.join(', '),
            decoration: const InputDecoration(
              labelText: 'Contractors (comma-separated)',
            ),
            onChanged: (v) => onUpdate(
              draft.copyWith(
                contractorNames: v
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList(),
              ),
            ),
          ),
        ];
      default:
        return [
          Text('Name: ${draft.name.isEmpty ? '—' : draft.name}'),
          Text('Code: ${draft.projectCode.isEmpty ? '—' : draft.projectCode}'),
          Text('Location: ${draft.locationLabel.isEmpty ? '—' : draft.locationLabel}'),
          Text('Manager: ${draft.managerLabel.isEmpty ? '—' : draft.managerLabel}'),
          Text('Budget: ${formatCpmsMoney(draft.budgetTotal)}'),
          Text(
            'Phases: ${draft.phaseNames.isEmpty ? '—' : draft.phaseNames.join(", ")}',
          ),
          Text(
            'Milestones: ${draft.milestoneNames.isEmpty ? '—' : draft.milestoneNames.join(", ")}',
          ),
          Text(
            'Contractors: ${draft.contractorNames.isEmpty ? '—' : draft.contractorNames.join(", ")}',
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: draft.notes,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Review notes'),
            onChanged: (v) => onUpdate(draft.copyWith(notes: v)),
          ),
        ];
    }
  }
}
