import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/config/ai_features.dart';
import 'package:hdhomesproject/core/constants/permissions.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/authentication/presentation/widgets/permission_gate.dart';
import 'package:hdhomesproject/features/construction/presentation/providers/construction_platform_providers.dart';
import 'package:hdhomesproject/features/cpms/domain/entities/cpms_models.dart';
import 'package:hdhomesproject/features/cpms/domain/services/cpms_service.dart';
import 'package:hdhomesproject/features/cpms/presentation/providers/cpms_controller.dart';
import 'package:hdhomesproject/features/cpms/presentation/widgets/cpms_command_center_shell.dart';
import 'package:hdhomesproject/features/cpms/presentation/widgets/cpms_construction_update_dialog.dart';
import 'package:hdhomesproject/features/cpms/presentation/widgets/cpms_crud_actions.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

CpmsCommandTab _tabForKpi(String label) {
  final key = label.toLowerCase();
  if (key.contains('milestone')) return CpmsCommandTab.milestones;
  if (key.contains('task')) return CpmsCommandTab.tasks;
  if (key.contains('change')) return CpmsCommandTab.procurement;
  if (key.contains('defect')) return CpmsCommandTab.quality;
  if (key.contains('safety')) return CpmsCommandTab.safety;
  if (key.contains('budget')) return CpmsCommandTab.budget;
  return CpmsCommandTab.projects;
}

CpmsCommandTab _tabForAlert(CpmsAlert alert) {
  final text =
      '${alert.title} ${alert.body ?? ''} ${alert.severity}'.toLowerCase();
  if (text.contains('safety')) return CpmsCommandTab.safety;
  if (text.contains('defect') || text.contains('quality')) {
    return CpmsCommandTab.quality;
  }
  if (text.contains('change') || text.contains('procurement')) {
    return CpmsCommandTab.procurement;
  }
  if (text.contains('milestone')) return CpmsCommandTab.milestones;
  if (text.contains('budget')) return CpmsCommandTab.budget;
  return CpmsCommandTab.projects;
}

/// Volume 4 Part 6 — Construction Command Center™ admin workspace.
class ConstructionCommandCenterPage extends ConsumerStatefulWidget {
  const ConstructionCommandCenterPage({super.key});

  @override
  ConsumerState<ConstructionCommandCenterPage> createState() =>
      _ConstructionCommandCenterPageState();
}

class _ConstructionCommandCenterPageState
    extends ConsumerState<ConstructionCommandCenterPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  CpmsCrudActions get _crud => CpmsCrudActions(ref, context);

  Future<void> _publishLive(
    CpmsCommandCenterSnapshot snap,
    CpmsController controller,
  ) async {
    final project = controller.selectedProject(snap);
    if (project == null) {
      controller.setMessage('Select a project before publishing live.');
      return;
    }
    await showCpmsConstructionUpdateDialog(
      context: context,
      ref: ref,
      project: project,
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncSnap = ref.watch(cpmsSnapshotProvider);
    final ui = ref.watch(cpmsControllerProvider);
    final live = ref.watch(cpmsRealtimeStatusProvider);
    final controller = ref.read(cpmsControllerProvider.notifier);
    final wide = MediaQuery.sizeOf(context).width >= 1100;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: CpmsDeskColors.bg,
      drawer: wide
          ? null
          : Drawer(
              backgroundColor: CpmsDeskColors.sidebar,
              child: CpmsDeskSidebar(
                sections: asyncSnap.valueOrNull == null
                    ? const []
                    : buildCpmsNavSections(asyncSnap.requireValue),
                selected: ui.selectedTab,
                live: live,
                fromRemote: asyncSnap.valueOrNull?.fromRemote ?? false,
                onSelect: (tab) {
                  controller.setTab(tab);
                  Navigator.pop(context);
                },
                onClose: () => Navigator.pop(context),
              ),
            ),
      body: asyncSnap.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: CpmsDeskColors.gold),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.hardHat, color: CpmsDeskColors.red, size: 28),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Failed to load Construction Command Center: $e',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: CpmsDeskColors.red),
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: controller.refresh,
                icon: const Icon(LucideIcons.refreshCw, size: 16),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (snap) {
          final navSections = buildCpmsNavSections(snap);
          final main = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CpmsDeskTopBar(
                tab: ui.selectedTab,
                live: live,
                fromRemote: snap.fromRemote,
                showMenu: !wide,
                onMenu: wide
                    ? null
                    : () => _scaffoldKey.currentState?.openDrawer(),
                onRefresh: controller.refresh,
                onPublish: () => _publishLive(snap, controller),
                onNewProject: () =>
                    _crud.editProject(fromRemote: snap.fromRemote),
              ),
              if (ui.lastMessage != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Material(
                    color: CpmsDeskColors.gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    child: ListTile(
                      dense: true,
                      leading: const Icon(
                        LucideIcons.info,
                        color: CpmsDeskColors.gold,
                        size: 18,
                      ),
                      title: Text(
                        ui.lastMessage!,
                        style: const TextStyle(color: Colors.white),
                      ),
                      trailing: IconButton(
                        icon: const Icon(LucideIcons.x, size: 16),
                        onPressed: controller.clearMessage,
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: controller.refresh,
                  color: CpmsDeskColors.gold,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      if (ui.selectedTab == CpmsCommandTab.overview ||
                          ui.selectedTab == CpmsCommandTab.projects)
                        ContainedPadding(
                          child: CpmsKpiStrip(
                            kpis: snap.kpis,
                            onSelected: (kpi) =>
                                controller.setTab(_tabForKpi(kpi.label)),
                          ),
                        ),
                      if (controller.tabUsesProjectScope(ui.selectedTab))
                        ContainedPadding(
                          child: CpmsDeskProjectScope(
                            projects: snap.projects,
                            selectedProjectId: ui.selectedProjectId,
                            onChanged: controller.setProjectScope,
                          ),
                        ),
                      if (ui.selectedTab == CpmsCommandTab.projects ||
                          ui.selectedTab == CpmsCommandTab.milestones ||
                          ui.selectedTab == CpmsCommandTab.tasks)
                        ContainedPadding(
                          child: _SearchAndFilters(
                            ui: ui,
                            onSearch: controller.setSearch,
                            onStatus: controller.setStatusFilter,
                          ),
                        ),
                      ..._tabSlivers(context, ref, snap, ui, controller),
                      const ContainedPadding(child: SizedBox(height: 48)),
                    ],
                  ),
                ),
              ),
            ],
          );

          if (!wide) return main;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 260,
                child: CpmsDeskSidebar(
                  sections: navSections,
                  selected: ui.selectedTab,
                  live: live,
                  fromRemote: snap.fromRemote,
                  onSelect: controller.setTab,
                ),
              ),
              Expanded(child: main),
            ],
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
              child: _WarRoomPanel(
                snap: snap,
                onOpenProject: (project) {
                  controller.selectProject(project.id);
                },
                onOpenTab: controller.setTab,
                onUpdateProject: (project) => _crud.editProject(
                  project: project,
                  fromRemote: snap.fromRemote,
                ),
                onApproveChangeOrder: snap.fromRemote
                    ? (c) => _crud.approveChangeOrder(c)
                    : null,
              ),
            ),
          ),
          ContainedPadding(
            child: _SectionCard(
              title: 'Activity Timeline',
              icon: LucideIcons.gitBranch,
              child: _ActivityList(
                activities: snap.activities,
                warnings: snap.loadWarnings,
                onLogDiary: () {
                  controller.setTab(CpmsCommandTab.diary);
                  _crud.editDiary(
                    projects: snap.projects,
                    preferredProjectId: ui.selectedProjectId,
                  );
                },
                onPublish: () => _publishLive(snap, controller),
              ),
            ),
          ),
          ContainedPadding(
            child: _SectionCard(
              title: 'Construction Alerts',
              icon: LucideIcons.bell,
              child: _AlertList(
                alerts: snap.alerts,
                onOpen: (alert) => controller.setTab(_tabForAlert(alert)),
                onDismiss: snap.fromRemote ? _crud.dismissAlert : null,
              ),
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
              trailing: IconButton(
                tooltip: 'Add project',
                onPressed: () => _crud.editProject(fromRemote: snap.fromRemote),
                icon: const Icon(LucideIcons.plus, size: 18),
              ),
              child: _ProjectList(
                projects: controller.filteredProjects(snap),
                selectedId: project?.id,
                onOpen: controller.selectProject,
                onEdit: snap.fromRemote
                    ? (p) => _crud.editProject(
                          project: p,
                          fromRemote: snap.fromRemote,
                        )
                    : null,
                onDelete: snap.fromRemote ? _crud.deleteProject : null,
              ),
            ),
          ),
          if (project != null)
            ContainedPadding(
              child: _SectionCard(
                title: 'Digital Construction Twin™',
                icon: LucideIcons.box,
                trailing: snap.fromRemote
                    ? IconButton(
                        tooltip: 'Edit project',
                        onPressed: () => _crud.editProject(
                          project: project,
                          fromRemote: snap.fromRemote,
                        ),
                        icon: const Icon(LucideIcons.pencil, size: 18),
                      )
                    : null,
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
      case CpmsCommandTab.liveFeed:
        final project = controller.selectedProject(snap);
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Site updates',
              icon: LucideIcons.rss,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Refresh feed',
                    onPressed: () =>
                        ref.invalidate(adminConstructionUpdatesProvider),
                    icon: const Icon(LucideIcons.refreshCw, size: 18),
                  ),
                  if (project != null)
                    FilledButton.icon(
                      onPressed: () => _publishLive(snap, controller),
                      icon: const Icon(LucideIcons.plus, size: 16),
                      label: const Text('Publish update'),
                    ),
                ],
              ),
              child: _UnifiedLiveFeedPanel(
                projectId: ui.selectedProjectId,
                fromRemote: snap.fromRemote,
                onPublish: project == null
                    ? null
                    : () => _publishLive(snap, controller),
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
              trailing: IconButton(
                tooltip: 'Add milestone',
                onPressed: () => _crud.editMilestone(
                  projects: snap.projects,
                  preferredProjectId: ui.selectedProjectId,
                ),
                icon: const Icon(LucideIcons.plus, size: 18),
              ),
              child: _MilestoneList(
                milestones: controller.scopedByProject(
                  snap.milestones,
                  (m) => m.projectId,
                ),
                emptyHint: 'No milestones yet — tap + to add.',
                onEdit: (m) => _crud.editMilestone(
                  projects: snap.projects,
                  preferredProjectId: ui.selectedProjectId,
                  milestone: m,
                ),
                onDelete: _crud.deleteMilestone,
              ),
            ),
          ),
        ];
      case CpmsCommandTab.tasks:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Tasks',
              icon: LucideIcons.checkSquare,
              trailing: IconButton(
                tooltip: 'Add task',
                onPressed: () => _crud.editTask(
                  projects: snap.projects,
                  preferredProjectId: ui.selectedProjectId,
                ),
                icon: const Icon(LucideIcons.plus, size: 18),
              ),
              child: _TaskList(
                tasks: controller.scopedByProject(
                  snap.tasks,
                  (t) => t.projectId,
                ),
                emptyHint: 'No tasks yet — tap + to add.',
                onEdit: (t) => _crud.editTask(
                  projects: snap.projects,
                  preferredProjectId: ui.selectedProjectId,
                  task: t,
                ),
                onDelete: _crud.deleteTask,
                onStatus: _crud.setTaskStatus,
              ),
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
                  Row(
                    children: [
                      Text(
                        'Procurement',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _crud.editProcurement(
                          projects: snap.projects,
                          preferredProjectId: ui.selectedProjectId,
                        ),
                        icon: const Icon(LucideIcons.plus, size: 16),
                        label: const Text('Add request'),
                      ),
                    ],
                  ),
                  _ProcurementList(
                    requests: controller.scopedByProject(
                      snap.procurementRequests,
                      (r) => r.projectId,
                    ),
                    emptyHint: 'No procurement requests yet — tap Add request.',
                    onEdit: (r) => _crud.editProcurement(
                      projects: snap.projects,
                      preferredProjectId: ui.selectedProjectId,
                      request: r,
                    ),
                    onDelete: _crud.deleteProcurement,
                  ),
                  const Divider(height: 24),
                  Text(
                    'Contractors',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _crud.editContractor(
                        projects: snap.projects,
                        preferredProjectId: ui.selectedProjectId,
                      ),
                      icon: const Icon(LucideIcons.plus, size: 16),
                      label: const Text('Add contractor'),
                    ),
                  ),
                  _ContractorList(
                    contractors: controller.scopedByProject(
                      snap.contractors,
                      (c) => c.projectId,
                    ),
                    onEdit: (c) => _crud.editContractor(
                      projects: snap.projects,
                      preferredProjectId: ui.selectedProjectId,
                      contractor: c,
                    ),
                    onDelete: _crud.deleteContractor,
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Text(
                        'Change Orders',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _crud.editChangeOrder(
                          projects: snap.projects,
                          preferredProjectId: ui.selectedProjectId,
                        ),
                        icon: const Icon(LucideIcons.plus, size: 16),
                        label: const Text('Add change order'),
                      ),
                    ],
                  ),
                  _ChangeOrderList(
                    orders: controller.scopedByProject(
                      snap.changeOrders,
                      (c) => c.projectId,
                    ),
                    emptyHint: 'No change orders yet — tap Add change order.',
                    onEdit: (c) => _crud.editChangeOrder(
                      projects: snap.projects,
                      preferredProjectId: ui.selectedProjectId,
                      order: c,
                    ),
                    onDelete: _crud.deleteChangeOrder,
                  ),
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
              trailing: IconButton(
                tooltip: 'Add budget line',
                onPressed: () => _crud.editBudgetLine(
                  projects: snap.projects,
                  preferredProjectId: ui.selectedProjectId,
                ),
                icon: const Icon(LucideIcons.plus, size: 18),
              ),
              child: _BudgetPanel(
                summaries: controller.scopedBudgetSummaries(snap),
                emptyHint: 'No budget lines yet — tap + to add.',
                onEdit: (l) => _crud.editBudgetLine(
                  projects: snap.projects,
                  preferredProjectId: ui.selectedProjectId,
                  line: l,
                ),
                onDelete: _crud.deleteBudgetLine,
              ),
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
                  Row(
                    children: [
                      Text(
                        'Quality checks',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _crud.editQualityCheck(
                          projects: snap.projects,
                          preferredProjectId: ui.selectedProjectId,
                        ),
                        icon: const Icon(LucideIcons.plus, size: 16),
                        label: const Text('Add check'),
                      ),
                    ],
                  ),
                  _QualityList(
                    checks: controller.scopedByProject(
                      snap.qualityChecks,
                      (q) => q.projectId,
                    ),
                    emptyHint: 'No quality checks yet — tap Add check.',
                    onEdit: (q) => _crud.editQualityCheck(
                      projects: snap.projects,
                      preferredProjectId: ui.selectedProjectId,
                      check: q,
                    ),
                    onDelete: _crud.deleteQualityCheck,
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Text(
                        'Defects',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _crud.editDefect(
                          projects: snap.projects,
                          preferredProjectId: ui.selectedProjectId,
                        ),
                        icon: const Icon(LucideIcons.plus, size: 16),
                        label: const Text('Add defect'),
                      ),
                    ],
                  ),
                  _DefectList(
                    defects: controller.scopedByProject(
                      snap.defects,
                      (d) => d.projectId,
                    ),
                    emptyHint: 'No defects logged — tap Add defect.',
                    onEdit: (d) => _crud.editDefect(
                      projects: snap.projects,
                      preferredProjectId: ui.selectedProjectId,
                      defect: d,
                    ),
                    onDelete: _crud.deleteDefect,
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Text(
                        'Inspections',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _crud.editInspection(
                          projects: snap.projects,
                          preferredProjectId: ui.selectedProjectId,
                        ),
                        icon: const Icon(LucideIcons.plus, size: 16),
                        label: const Text('Schedule'),
                      ),
                    ],
                  ),
                  _InspectionList(
                    inspections: controller.scopedByProject(
                      snap.inspections,
                      (i) => i.projectId,
                    ),
                    emptyHint: 'No inspections scheduled — tap Schedule.',
                    onEdit: (i) => _crud.editInspection(
                      projects: snap.projects,
                      preferredProjectId: ui.selectedProjectId,
                      inspection: i,
                    ),
                    onDelete: _crud.deleteInspection,
                  ),
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
              trailing: IconButton(
                tooltip: 'Log incident',
                onPressed: () => _crud.editSafety(
                  projects: snap.projects,
                  preferredProjectId: ui.selectedProjectId,
                ),
                icon: const Icon(LucideIcons.plus, size: 18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SafetyList(
                    incidents: controller.scopedByProject(
                      snap.safetyIncidents,
                      (s) => s.projectId,
                    ),
                    emptyHint: 'No safety incidents — tap + to log one.',
                    onEdit: (s) => _crud.editSafety(
                      projects: snap.projects,
                      preferredProjectId: ui.selectedProjectId,
                      incident: s,
                    ),
                    onDelete: _crud.deleteSafety,
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Text(
                        'Risk Register',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _crud.editRisk(
                          projects: snap.projects,
                          preferredProjectId: ui.selectedProjectId,
                        ),
                        icon: const Icon(LucideIcons.plus, size: 16),
                        label: const Text('Add risk'),
                      ),
                    ],
                  ),
                  _RiskList(
                    risks: controller.scopedByProject(
                      snap.risks,
                      (r) => r.projectId,
                    ),
                    emptyHint: 'No risks on the register — tap Add risk.',
                    onEdit: (r) => _crud.editRisk(
                      projects: snap.projects,
                      preferredProjectId: ui.selectedProjectId,
                      risk: r,
                    ),
                    onDelete: _crud.deleteRisk,
                  ),
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
              trailing: IconButton(
                tooltip: 'Add diary entry',
                onPressed: () => _crud.editDiary(
                  projects: snap.projects,
                  preferredProjectId: ui.selectedProjectId,
                ),
                icon: const Icon(LucideIcons.plus, size: 18),
              ),
              child: _DiaryList(
                entries: controller.scopedByProject(
                  snap.siteDiaries,
                  (e) => e.projectId,
                ),
                emptyHint: 'No diary entries yet — tap + to add.',
                onEdit: (e) => _crud.editDiary(
                  projects: snap.projects,
                  preferredProjectId: ui.selectedProjectId,
                  entry: e,
                ),
                onDelete: _crud.deleteDiary,
              ),
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
                fromRemote: snap.fromRemote,
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
                onSubmit: () => _crud.submitWizard(ui.wizard),
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

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
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  if (trailing != null) trailing!,
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
  const _WarRoomPanel({
    required this.snap,
    this.onOpenProject,
    this.onOpenTab,
    this.onUpdateProject,
    this.onApproveChangeOrder,
  });

  final CpmsCommandCenterSnapshot snap;
  final ValueChanged<CpmsProject>? onOpenProject;
  final ValueChanged<CpmsCommandTab>? onOpenTab;
  final ValueChanged<CpmsProject>? onUpdateProject;
  final ValueChanged<CpmsChangeOrder>? onApproveChangeOrder;

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
          'Delayed sites, change orders, and open safety items.',
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
              trailing: TextButton(
                onPressed: onUpdateProject == null
                    ? null
                    : () => onUpdateProject!(p),
                child: const Text('Update'),
              ),
              onTap: onOpenProject == null ? null : () => onOpenProject!(p),
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
              trailing: onApproveChangeOrder != null
                  ? TextButton(
                      onPressed: () => onApproveChangeOrder!(c),
                      child: const Text('Approve'),
                    )
                  : null,
              dense: true,
            ),
          ),
        ],
        if (snap.safetyIncidents.isNotEmpty) ...[
          const Divider(),
          ...snap.safetyIncidents.take(4).map(
                (s) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    LucideIcons.shieldAlert,
                    color: Colors.redAccent,
                  ),
                  title: Text(s.title),
                  subtitle: Text('${s.severity.label} · ${s.status}'),
                  onTap: onOpenTab == null
                      ? null
                      : () => onOpenTab!(CpmsCommandTab.safety),
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
    this.onEdit,
    this.onDelete,
  });

  final List<CpmsProject> projects;
  final String? selectedId;
  final ValueChanged<String> onOpen;
  final ValueChanged<CpmsProject>? onEdit;
  final ValueChanged<CpmsProject>? onDelete;

  @override
  Widget build(BuildContext context) {
    if (projects.isEmpty) {
      return const Text('No projects yet — use Wizard or + to create one.');
    }
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
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (p.isDelayed)
                    const Icon(LucideIcons.alertCircle, color: Colors.orange),
                  if (onEdit != null)
                    IconButton(
                      tooltip: 'Edit',
                      onPressed: () => onEdit!(p),
                      icon: const Icon(LucideIcons.pencil, size: 16),
                    ),
                  if (onDelete != null)
                    IconButton(
                      tooltip: 'Delete',
                      onPressed: () => onDelete!(p),
                      icon: const Icon(LucideIcons.trash2, size: 16),
                    ),
                ],
              ),
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
        if (kAiFeaturesEnabled && project.aiSummary != null) ...[
          const SizedBox(height: 8),
          Text(project.aiSummary!),
        ],
        if (kAiFeaturesEnabled) ...[
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
      ],
    );
  }
}

class _MilestoneList extends StatelessWidget {
  const _MilestoneList({
    required this.milestones,
    this.emptyHint = 'No milestones yet.',
    this.onEdit,
    this.onDelete,
  });

  final List<CpmsMilestone> milestones;
  final String emptyHint;
  final ValueChanged<CpmsMilestone>? onEdit;
  final ValueChanged<CpmsMilestone>? onDelete;

  @override
  Widget build(BuildContext context) {
    if (milestones.isEmpty) return Text(emptyHint);
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
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${m.progressPct.toStringAsFixed(0)}%'),
                  if (onEdit != null)
                    IconButton(
                      onPressed: () => onEdit!(m),
                      icon: const Icon(LucideIcons.pencil, size: 16),
                    ),
                  if (onDelete != null)
                    IconButton(
                      onPressed: () => onDelete!(m),
                      icon: const Icon(LucideIcons.trash2, size: 16),
                    ),
                ],
              ),
              dense: true,
            ),
          )
          .toList(),
    );
  }
}

class _TaskList extends StatelessWidget {
  const _TaskList({
    required this.tasks,
    this.emptyHint = 'No tasks yet.',
    this.onEdit,
    this.onDelete,
    this.onStatus,
  });

  final List<CpmsTask> tasks;
  final String emptyHint;
  final ValueChanged<CpmsTask>? onEdit;
  final ValueChanged<CpmsTask>? onDelete;
  final void Function(CpmsTask task, String status)? onStatus;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) return Text(emptyHint);
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
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (t.status == TaskStatus.blocked)
                    const Icon(LucideIcons.ban, color: Colors.redAccent, size: 18),
                  if (onStatus != null)
                    PopupMenuButton<String>(
                      tooltip: 'Task status',
                      onSelected: (status) => onStatus!(t, status),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'in_progress', child: Text('Start')),
                        PopupMenuItem(value: 'blocked', child: Text('Block')),
                        PopupMenuItem(value: 'done', child: Text('Mark done')),
                        PopupMenuItem(value: 'todo', child: Text('Reopen')),
                      ],
                    ),
                  if (onEdit != null)
                    IconButton(
                      onPressed: () => onEdit!(t),
                      icon: const Icon(LucideIcons.pencil, size: 16),
                    ),
                  if (onDelete != null)
                    IconButton(
                      onPressed: () => onDelete!(t),
                      icon: const Icon(LucideIcons.trash2, size: 16),
                    ),
                ],
              ),
              dense: true,
            ),
          )
          .toList(),
    );
  }
}

class _ProcurementList extends StatelessWidget {
  const _ProcurementList({
    required this.requests,
    this.emptyHint = 'No procurement requests yet.',
    this.onEdit,
    this.onDelete,
  });

  final List<CpmsProcurementRequest> requests;
  final String emptyHint;
  final ValueChanged<CpmsProcurementRequest>? onEdit;
  final ValueChanged<CpmsProcurementRequest>? onDelete;

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) return Text(emptyHint);
    return Column(
      children: requests
          .map(
            (r) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${r.requestCode} · ${r.title}'),
              subtitle: Text('${r.status} · ${r.costDisplay}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onEdit != null)
                    IconButton(
                      onPressed: () => onEdit!(r),
                      icon: const Icon(LucideIcons.pencil, size: 16),
                    ),
                  if (onDelete != null)
                    IconButton(
                      onPressed: () => onDelete!(r),
                      icon: const Icon(LucideIcons.trash2, size: 16),
                    ),
                ],
              ),
              dense: true,
            ),
          )
          .toList(),
    );
  }
}

class _ContractorList extends StatelessWidget {
  const _ContractorList({
    required this.contractors,
    this.onEdit,
    this.onDelete,
  });

  final List<CpmsContractor> contractors;
  final ValueChanged<CpmsContractor>? onEdit;
  final ValueChanged<CpmsContractor>? onDelete;

  @override
  Widget build(BuildContext context) {
    if (contractors.isEmpty) {
      return const Text('No contractors yet — add them here or via the wizard.');
    }
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
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onEdit != null)
                    IconButton(
                      onPressed: () => onEdit!(c),
                      icon: const Icon(LucideIcons.pencil, size: 16),
                    ),
                  if (onDelete != null)
                    IconButton(
                      onPressed: () => onDelete!(c),
                      icon: const Icon(LucideIcons.trash2, size: 16),
                    ),
                ],
              ),
              dense: true,
            ),
          )
          .toList(),
    );
  }
}

class _ChangeOrderList extends StatelessWidget {
  const _ChangeOrderList({
    required this.orders,
    this.emptyHint = 'No change orders yet.',
    this.onEdit,
    this.onDelete,
  });

  final List<CpmsChangeOrder> orders;
  final String emptyHint;
  final ValueChanged<CpmsChangeOrder>? onEdit;
  final ValueChanged<CpmsChangeOrder>? onDelete;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) return Text(emptyHint);
    return Column(
      children: orders
          .map(
            (c) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${c.changeCode} · ${c.title}'),
              subtitle: Text(
                '${c.status.label} · ${c.costDisplay} · +${c.scheduleImpactDays}d',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onEdit != null)
                    IconButton(
                      onPressed: () => onEdit!(c),
                      icon: const Icon(LucideIcons.pencil, size: 16),
                    ),
                  if (onDelete != null)
                    IconButton(
                      onPressed: () => onDelete!(c),
                      icon: const Icon(LucideIcons.trash2, size: 16),
                    ),
                ],
              ),
              dense: true,
            ),
          )
          .toList(),
    );
  }
}

class _BudgetPanel extends StatelessWidget {
  const _BudgetPanel({
    required this.summaries,
    this.emptyHint = 'No budget lines loaded.',
    this.onEdit,
    this.onDelete,
  });

  final List<CpmsBudgetSummary> summaries;
  final String emptyHint;
  final ValueChanged<CpmsBudgetLine>? onEdit;
  final ValueChanged<CpmsBudgetLine>? onDelete;

  @override
  Widget build(BuildContext context) {
    if (summaries.isEmpty) return Text(emptyHint);
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
                      subtitle: Text(
                        '${l.description ?? ''}'
                        '${(l.description ?? '').isNotEmpty ? '\n' : ''}'
                        'Budgeted ${formatCpmsMoney(l.budgetedAmount)} · '
                        'Spent ${formatCpmsMoney(l.spentAmount)}',
                      ),
                      isThreeLine: (l.description ?? '').isNotEmpty,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (onEdit != null)
                            IconButton(
                              onPressed: () => onEdit!(l),
                              icon: const Icon(LucideIcons.pencil, size: 16),
                            ),
                          if (onDelete != null)
                            IconButton(
                              onPressed: () => onDelete!(l),
                              icon: const Icon(LucideIcons.trash2, size: 16),
                            ),
                        ],
                      ),
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
  const _QualityList({
    required this.checks,
    this.emptyHint = 'No quality checks yet.',
    this.onEdit,
    this.onDelete,
  });

  final List<CpmsQualityCheck> checks;
  final String emptyHint;
  final ValueChanged<CpmsQualityCheck>? onEdit;
  final ValueChanged<CpmsQualityCheck>? onDelete;

  @override
  Widget build(BuildContext context) {
    if (checks.isEmpty) return Text(emptyHint);
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
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onEdit != null)
                    IconButton(
                      onPressed: () => onEdit!(q),
                      icon: const Icon(LucideIcons.pencil, size: 16),
                    ),
                  if (onDelete != null)
                    IconButton(
                      onPressed: () => onDelete!(q),
                      icon: const Icon(LucideIcons.trash2, size: 16),
                    ),
                ],
              ),
              dense: true,
            ),
          )
          .toList(),
    );
  }
}

class _DefectList extends StatelessWidget {
  const _DefectList({
    required this.defects,
    this.emptyHint = 'No defects yet.',
    this.onEdit,
    this.onDelete,
  });

  final List<CpmsDefect> defects;
  final String emptyHint;
  final ValueChanged<CpmsDefect>? onEdit;
  final ValueChanged<CpmsDefect>? onDelete;

  @override
  Widget build(BuildContext context) {
    if (defects.isEmpty) return Text(emptyHint);
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
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onEdit != null)
                    IconButton(
                      onPressed: () => onEdit!(d),
                      icon: const Icon(LucideIcons.pencil, size: 16),
                    ),
                  if (onDelete != null)
                    IconButton(
                      onPressed: () => onDelete!(d),
                      icon: const Icon(LucideIcons.trash2, size: 16),
                    ),
                ],
              ),
              dense: true,
            ),
          )
          .toList(),
    );
  }
}

class _InspectionList extends StatelessWidget {
  const _InspectionList({
    required this.inspections,
    this.emptyHint = 'No inspections scheduled.',
    this.onEdit,
    this.onDelete,
  });

  final List<CpmsInspection> inspections;
  final String emptyHint;
  final ValueChanged<CpmsInspection>? onEdit;
  final ValueChanged<CpmsInspection>? onDelete;

  @override
  Widget build(BuildContext context) {
    if (inspections.isEmpty) return Text(emptyHint);
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
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onEdit != null)
                    IconButton(
                      onPressed: () => onEdit!(i),
                      icon: const Icon(LucideIcons.pencil, size: 16),
                    ),
                  if (onDelete != null)
                    IconButton(
                      onPressed: () => onDelete!(i),
                      icon: const Icon(LucideIcons.trash2, size: 16),
                    ),
                ],
              ),
              dense: true,
            ),
          )
          .toList(),
    );
  }
}

class _SafetyList extends StatelessWidget {
  const _SafetyList({
    required this.incidents,
    this.emptyHint = 'No safety incidents.',
    this.onEdit,
    this.onDelete,
  });

  final List<CpmsSafetyIncident> incidents;
  final String emptyHint;
  final ValueChanged<CpmsSafetyIncident>? onEdit;
  final ValueChanged<CpmsSafetyIncident>? onDelete;

  @override
  Widget build(BuildContext context) {
    if (incidents.isEmpty) return Text(emptyHint);
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
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onEdit != null)
                    IconButton(
                      onPressed: () => onEdit!(s),
                      icon: const Icon(LucideIcons.pencil, size: 16),
                    ),
                  if (onDelete != null)
                    IconButton(
                      onPressed: () => onDelete!(s),
                      icon: const Icon(LucideIcons.trash2, size: 16),
                    ),
                ],
              ),
              dense: true,
            ),
          )
          .toList(),
    );
  }
}

class _RiskList extends StatelessWidget {
  const _RiskList({
    required this.risks,
    this.emptyHint = 'No risks on the register.',
    this.onEdit,
    this.onDelete,
  });

  final List<CpmsRisk> risks;
  final String emptyHint;
  final ValueChanged<CpmsRisk>? onEdit;
  final ValueChanged<CpmsRisk>? onDelete;

  @override
  Widget build(BuildContext context) {
    if (risks.isEmpty) return Text(emptyHint);
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
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onEdit != null)
                    IconButton(
                      onPressed: () => onEdit!(r),
                      icon: const Icon(LucideIcons.pencil, size: 16),
                    ),
                  if (onDelete != null)
                    IconButton(
                      onPressed: () => onDelete!(r),
                      icon: const Icon(LucideIcons.trash2, size: 16),
                    ),
                ],
              ),
              dense: true,
            ),
          )
          .toList(),
    );
  }
}

class _DiaryList extends StatelessWidget {
  const _DiaryList({
    required this.entries,
    this.emptyHint = 'No diary entries yet.',
    this.onEdit,
    this.onDelete,
  });

  final List<CpmsSiteDiary> entries;
  final String emptyHint;
  final ValueChanged<CpmsSiteDiary>? onEdit;
  final ValueChanged<CpmsSiteDiary>? onDelete;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return Text(emptyHint);
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
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onEdit != null)
                    IconButton(
                      onPressed: () => onEdit!(e),
                      icon: const Icon(LucideIcons.pencil, size: 16),
                    ),
                  if (onDelete != null)
                    IconButton(
                      onPressed: () => onDelete!(e),
                      icon: const Icon(LucideIcons.trash2, size: 16),
                    ),
                ],
              ),
              dense: true,
            ),
          )
          .toList(),
    );
  }
}

class _UnifiedLiveFeedPanel extends ConsumerWidget {
  const _UnifiedLiveFeedPanel({
    required this.projectId,
    required this.fromRemote,
    this.onPublish,
  });

  final String? projectId;
  final bool fromRemote;
  final VoidCallback? onPublish;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(constructionPlatformRealtimeProvider);
    final async = ref.watch(adminConstructionUpdatesProvider(projectId));

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: CircularProgressIndicator(color: CpmsDeskColors.gold),
        ),
      ),
      error: (e, _) => Text(
        userFacingError(e, fallback: 'Unable to load live feed.'),
        style: const TextStyle(color: CpmsDeskColors.red),
      ),
      data: (updates) {
        if (!fromRemote) {
          return const Text(
            'Connect Supabase to load the unified construction progress feed.',
            style: TextStyle(color: CpmsDeskColors.muted),
          );
        }
        if (updates.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                const Icon(LucideIcons.rss, color: CpmsDeskColors.gold, size: 28),
                const SizedBox(height: 12),
                const Text(
                  'No progress updates yet',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Publish a site update to push live progress to the website, clients, and investors.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: CpmsDeskColors.muted),
                ),
                if (onPublish != null) ...[
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: onPublish,
                    icon: const Icon(LucideIcons.plus, size: 16),
                    label: const Text('Publish first update'),
                  ),
                ],
              ],
            ),
          );
        }

        final dateFmt = DateFormat.yMMMd().add_jm();
        return Column(
          children: [
            for (final u in updates)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CpmsDeskColors.elevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: u.isPublished
                        ? CpmsDeskColors.gold.withValues(alpha: 0.35)
                        : CpmsDeskColors.border,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      u.isPublished ? LucideIcons.radio : LucideIcons.fileEdit,
                      size: 16,
                      color: u.isPublished
                          ? CpmsDeskColors.green
                          : CpmsDeskColors.muted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            u.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (u.shortDescription != null &&
                              u.shortDescription!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                u.shortDescription!,
                                style: const TextStyle(
                                  color: CpmsDeskColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _FeedChip(
                                label: u.isPublished ? 'Published' : 'Draft',
                                color: u.isPublished
                                    ? CpmsDeskColors.green
                                    : CpmsDeskColors.amber,
                              ),
                              if (u.progressPct != null)
                                _FeedChip(
                                  label: '${u.progressPct!.round()}%',
                                  color: CpmsDeskColors.gold,
                                ),
                              for (final v in u.visibility)
                                _FeedChip(
                                  label: v,
                                  color: CpmsDeskColors.muted,
                                ),
                              if (u.media.isNotEmpty)
                                _FeedChip(
                                  label: '${u.media.length} media',
                                  color: CpmsDeskColors.muted,
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            u.publishedAt != null
                                ? 'Published ${dateFmt.format(u.publishedAt!.toLocal())}'
                                : (u.updateDate != null
                                    ? 'Update date ${DateFormat.yMMMd().format(u.updateDate!)}'
                                    : 'Pending publish'),
                            style: const TextStyle(
                              color: CpmsDeskColors.muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!u.isPublished)
                      TextButton(
                        onPressed: () async {
                          await ref
                              .read(constructionPlatformServiceProvider)
                              .publishUpdate(u.id);
                          ref.invalidate(adminConstructionUpdatesProvider);
                          ref.invalidate(publicConstructionProjectsProvider);
                        },
                        child: const Text('Publish'),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _FeedChip extends StatelessWidget {
  const _FeedChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ActivityList extends StatelessWidget {
  const _ActivityList({
    required this.activities,
    this.warnings = const [],
    this.onLogDiary,
    this.onPublish,
  });

  final List<CpmsActivity> activities;
  final List<String> warnings;
  final VoidCallback? onLogDiary;
  final VoidCallback? onPublish;

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('No activity yet. Log a site diary entry or publish progress.'),
          if (warnings.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              warnings.first,
              style: const TextStyle(color: Colors.orange, fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              if (onLogDiary != null)
                FilledButton.icon(
                  onPressed: onLogDiary,
                  icon: const Icon(LucideIcons.bookOpen, size: 16),
                  label: const Text('Log diary'),
                ),
              if (onPublish != null)
                OutlinedButton.icon(
                  onPressed: onPublish,
                  icon: const Icon(LucideIcons.radio, size: 16),
                  label: const Text('Publish live'),
                ),
            ],
          ),
        ],
      );
    }
    final when = DateFormat.MMMd().add_jm();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (warnings.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              warnings.first,
              style: const TextStyle(color: Colors.orange, fontSize: 12),
            ),
          ),
        Wrap(
          spacing: 8,
          children: [
            if (onLogDiary != null)
              TextButton.icon(
                onPressed: onLogDiary,
                icon: const Icon(LucideIcons.bookOpen, size: 16),
                label: const Text('Log diary'),
              ),
            if (onPublish != null)
              TextButton.icon(
                onPressed: onPublish,
                icon: const Icon(LucideIcons.radio, size: 16),
                label: const Text('Publish live'),
              ),
          ],
        ),
        for (final a in activities)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(LucideIcons.activity, size: 16),
            title: Text(a.title),
            subtitle: Text(
              '${a.eventType}${a.actorLabel != null ? ' · ${a.actorLabel}' : ''}'
              '${a.occurredAt != null ? ' · ${when.format(a.occurredAt!.toLocal())}' : ''}'
              '${a.description != null ? '\n${a.description}' : ''}',
            ),
            dense: true,
          ),
      ],
    );
  }
}

class _AlertList extends StatelessWidget {
  const _AlertList({
    required this.alerts,
    this.onDismiss,
    this.onOpen,
  });

  final List<CpmsAlert> alerts;
  final ValueChanged<CpmsAlert>? onDismiss;
  final ValueChanged<CpmsAlert>? onOpen;

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) return const Text('No construction alerts.');
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
              onTap: onOpen == null ? null : () => onOpen!(a),
              trailing: onDismiss != null
                  ? IconButton(
                      tooltip: 'Dismiss',
                      onPressed: () => onDismiss!(a),
                      icon: const Icon(LucideIcons.x, size: 16),
                    )
                  : null,
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
    required this.fromRemote,
  });

  final List<CpmsAiInsight> insights;
  final List<String> intelligence;
  final String disclaimer;
  final bool fromRemote;

  @override
  Widget build(BuildContext context) {
    if (!fromRemote) {
      return Text(
        'Connect Supabase to load live progress intelligence from your projects.\n\n$disclaimer',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }
    if (insights.isEmpty && intelligence.isEmpty) {
      return Text(
        'No AI insights yet. Open a project and use AI Progress Summary, '
        'or publish live progress to refresh intelligence.\n\n$disclaimer',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Insights derived from live project data',
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
        if (intelligence.isNotEmpty) const Divider(height: 24),
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
            if (step > 0)
              OutlinedButton(
                onPressed: onPrevious,
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
              PermissionGateAny(
                permissions: const [
                  PermissionSlugs.constructionProjects,
                  PermissionSlugs.constructionWrite,
                  PermissionSlugs.manageConstruction,
                ],
                child: FilledButton(
                  onPressed: onSubmit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.deepBlack,
                  ),
                  child: const Text('Create project'),
                ),
              ),
            PermissionGate(
              permission: PermissionSlugs.constructionWrite,
              child: TextButton(onPressed: onReset, child: const Text('Reset')),
            ),
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
            'Set project start and target completion dates.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Start: ${draft.startDate != null ? DateFormat.yMMMd().format(draft.startDate!) : 'Not set'}',
            ),
            trailing: TextButton(
              onPressed: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: draft.startDate ?? now,
                  firstDate: DateTime(now.year - 2),
                  lastDate: DateTime(now.year + 8),
                );
                if (picked != null) {
                  onUpdate(draft.copyWith(startDate: picked));
                }
              },
              child: const Text('Pick start'),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Target end: ${draft.targetEndDate != null ? DateFormat.yMMMd().format(draft.targetEndDate!) : 'Not set'}',
            ),
            trailing: TextButton(
              onPressed: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: draft.targetEndDate ??
                      (draft.startDate ?? now).add(const Duration(days: 180)),
                  firstDate: draft.startDate ?? DateTime(now.year - 2),
                  lastDate: DateTime(now.year + 8),
                );
                if (picked != null) {
                  onUpdate(draft.copyWith(targetEndDate: picked));
                }
              },
              child: const Text('Pick end'),
            ),
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
