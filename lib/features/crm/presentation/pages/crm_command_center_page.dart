import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/auth/policies/role_nav_policy.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/identity_provider.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/authentication/domain/services/organization_service.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/organization_controller.dart';
import 'package:hdhomesproject/features/crm/domain/entities/crm_models.dart';
import 'package:hdhomesproject/features/crm/presentation/providers/crm_controller.dart';
import 'package:hdhomesproject/features/crm/presentation/widgets/crm_calculator_leads_tab.dart';
import 'package:hdhomesproject/features/crm/presentation/widgets/crm_command_center_shell.dart';
import 'package:hdhomesproject/features/home/data/providers/payment_calculator_provider.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

String _csvEscape(String? raw) {
  final v = (raw ?? '').replaceAll('"', '""');
  if (v.contains(',') || v.contains('"') || v.contains('\n')) {
    return '"$v"';
  }
  return v;
}

String buildLeadsCsv(List<CrmLead> leads) {
  final buf = StringBuffer(
    'Lead ID,Title,Client,Source,Stage,Status,Priority,Value,Property,Location,Captured\n',
  );
  for (final l in leads) {
    buf.writeln(
      [
        _csvEscape(l.id),
        _csvEscape(l.title),
        _csvEscape(l.clientName),
        _csvEscape(l.sourceName),
        _csvEscape(l.stageName),
        _csvEscape(l.status.label),
        _csvEscape(l.priority.label),
        _csvEscape(l.estimatedValue?.toStringAsFixed(0)),
        _csvEscape(l.propertyTitle),
        _csvEscape(l.preferredLocation),
        _csvEscape(l.capturedAt?.toIso8601String()),
      ].join(','),
    );
  }
  return buf.toString();
}

Future<void> exportLeadsCsv(BuildContext context, List<CrmLead> leads) async {
  if (leads.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No leads to export for the current filter.'),
      ),
    );
    return;
  }
  final csv = buildLeadsCsv(leads);
  await Clipboard.setData(ClipboardData(text: csv));
  try {
    await Share.share(
      csv,
      subject: 'HD Homes Sales leads export (${leads.length})',
    );
  } catch (_) {
    // Clipboard already set.
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exported ${leads.length} leads (copied + share sheet).'),
      ),
    );
  }
}

abstract final class _Crm {
  static const bg = Color(0xFF0B0C0E);
  static const surface = Color(0xFF14161A);
  static const elevated = Color(0xFF1A1D24);
  static const border = Color(0x22FFFFFF);
  static const muted = Color(0x99FFFFFF);
  static const gold = AppColors.primaryGold;
  static const green = Color(0xFF22C55E);
  static const amber = Color(0xFFF59E0B);
  static const red = Color(0xFFF87171);

  static InputDecoration field(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: muted),
      hintStyle: TextStyle(color: muted.withValues(alpha: 0.7)),
      filled: true,
      fillColor: bg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: gold.withValues(alpha: 0.7)),
      ),
    );
  }

  static ButtonStyle get ghost => OutlinedButton.styleFrom(
    foregroundColor: gold,
    side: BorderSide(color: gold.withValues(alpha: 0.45)),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  );

  static ButtonStyle get solid => FilledButton.styleFrom(
    backgroundColor: gold,
    foregroundColor: AppColors.charcoal,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );
}

String _fmtDate(DateTime? value) {
  if (value == null) return '—';
  return DateFormat.MMMd().add_jm().format(value.toLocal());
}

String _fmtMoney(double? value) {
  if (value == null) return '—';
  if (value >= 1e9) return '₦${(value / 1e9).toStringAsFixed(1)}B';
  if (value >= 1e6) return '₦${(value / 1e6).toStringAsFixed(1)}M';
  if (value >= 1e3) return '₦${(value / 1e3).toStringAsFixed(0)}K';
  return '₦${value.toStringAsFixed(0)}';
}

CrmKpiFilter _filterForLabel(String label) {
  return switch (label.toLowerCase()) {
    'new leads' => CrmKpiFilter.newLeads,
    'active pipeline' => CrmKpiFilter.activePipeline,
    'qualified' => CrmKpiFilter.qualified,
    'inspections today' => CrmKpiFilter.inspectionsToday,
    'follow-ups due' || 'follow ups due' => CrmKpiFilter.followUpsDue,
    'active clients' => CrmKpiFilter.activeClients,
    'pipeline value' => CrmKpiFilter.pipelineValue,
    'conversion rate' || 'conversion' => CrmKpiFilter.conversion,
    _ => CrmKpiFilter.none,
  };
}

List<SalesBridgeRow> _searchRows(List<SalesBridgeRow> rows, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return rows;
  return rows.where((r) {
    return r.title.toLowerCase().contains(q) ||
        r.status.toLowerCase().contains(q) ||
        (r.subtitle?.toLowerCase().contains(q) ?? false) ||
        (r.clientName?.toLowerCase().contains(q) ?? false) ||
        (r.propertyTitle?.toLowerCase().contains(q) ?? false);
  }).toList();
}

bool _bridgeMatchesClient(CrmClient client, SalesBridgeRow row) {
  if (row.crmClientId != null && row.crmClientId == client.id) return true;
  final profileId = client.profileId?.trim();
  final rowProfileId = row.profileId?.trim();
  if (profileId != null &&
      profileId.isNotEmpty &&
      rowProfileId != null &&
      rowProfileId.isNotEmpty &&
      profileId == rowProfileId) {
    return true;
  }
  final email = (client.email ?? '').trim().toLowerCase();
  final rowEmail = (row.clientEmail ?? '').trim().toLowerCase();
  if (email.isNotEmpty && rowEmail.isNotEmpty && email == rowEmail) {
    return true;
  }
  final phone = (client.phone ?? '').replaceAll(RegExp(r'\D'), '');
  final rowPhone = (row.clientPhone ?? '').replaceAll(RegExp(r'\D'), '');
  if (phone.length >= 7 && rowPhone.length >= 7 && phone == rowPhone) {
    return true;
  }
  final nameKey = client.fullName.trim().toLowerCase();
  final rowName = (row.clientName ?? '').trim().toLowerCase();
  if (nameKey.isNotEmpty && rowName.isNotEmpty) {
    if (rowName.contains(nameKey) || nameKey.contains(rowName)) return true;
  }
  return false;
}

Color _statusColor(String status) {
  final s = status.toLowerCase();
  if (s.contains('cancel') || s.contains('reject') || s.contains('lost')) {
    return _Crm.red;
  }
  if (s.contains('complete') ||
      s.contains('approve') ||
      s.contains('confirm') ||
      s.contains('won')) {
    return _Crm.green;
  }
  if (s.contains('pending') || s.contains('review') || s.contains('schedul')) {
    return _Crm.amber;
  }
  return _Crm.muted;
}

/// Live Sales Command Center — leads, clients, enquiries, inspections.
class CrmCommandCenterPage extends ConsumerStatefulWidget {
  const CrmCommandCenterPage({super.key, this.initialTab});

  /// When opening `/dashboard/clients`, land on the Clients registry tab.
  final CrmCommandTab? initialTab;

  @override
  ConsumerState<CrmCommandCenterPage> createState() =>
      _CrmCommandCenterPageState();
}

class _CrmCommandCenterPageState extends ConsumerState<CrmCommandCenterPage> {
  final _kpiScroll = ScrollController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _appliedInitialTab = false;

  @override
  void dispose() {
    _kpiScroll.dispose();
    super.dispose();
  }

  void _applyInitialTab(CrmController controller) {
    if (_appliedInitialTab) return;
    final tab = widget.initialTab;
    if (tab == null) return;
    _appliedInitialTab = true;
    controller.setTab(tab);
  }

  @override
  Widget build(BuildContext context) {
    final asyncSnap = ref.watch(crmSnapshotProvider);
    final ui = ref.watch(crmControllerProvider);
    final realtimeLive = ref.watch(crmRealtimeStatusProvider);
    final live =
        realtimeLive || (asyncSnap.valueOrNull?.fromRemote ?? false);
    final controller = ref.read(crmControllerProvider.notifier);
    _applyInitialTab(controller);

    final calculatorLeadCount =
        ref
            .watch(cmsCalculatorApplicationsProvider)
            .valueOrNull
            ?.where(
              (app) =>
                  app.status != 'closed' &&
                  app.status != 'spam' &&
                  app.status != 'converted',
            )
            .length ??
        0;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _Crm.bg,
      drawer: MediaQuery.sizeOf(context).width < 1100
          ? Drawer(
              backgroundColor: CrmDeskColors.sidebar,
              child: CrmDeskSidebar(
                sections: asyncSnap.valueOrNull == null
                    ? const []
                    : buildCrmNavSections(
                        asyncSnap.requireValue,
                        calculatorLeadCount: calculatorLeadCount,
                      ),
                selected: ui.selectedTab,
                onSelect: (tab) {
                  controller.setTab(tab);
                  Navigator.pop(context);
                },
                live: live,
                onClose: () => Navigator.pop(context),
              ),
            )
          : null,
      body: asyncSnap.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _Crm.gold)),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.activity, color: _Crm.red, size: 28),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  '$e',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _Crm.red),
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: controller.refresh,
                icon: const Icon(LucideIcons.refreshCw, size: 16),
                label: const Text('Retry'),
                style: _Crm.solid,
              ),
            ],
          ),
        ),
        data: (snap) {
          final stages = [...snap.stages]
            ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
          final wide = MediaQuery.sizeOf(context).width >= 1100;
          final navSections = buildCrmNavSections(
            snap,
            calculatorLeadCount: calculatorLeadCount,
          );

          Widget mainPane() {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CrmDeskTopBar(
                  tab: ui.selectedTab,
                  live: live,
                  loadedAt: snap.loadedAt,
                  showMenu: !wide,
                  onMenu: wide
                      ? null
                      : () => _scaffoldKey.currentState?.openDrawer(),
                  onRefresh: controller.refresh,
                  onExport: () {
                    final leads = controller.filteredLeads(snap);
                    exportLeadsCsv(context, leads);
                  },
                  onAddLead: () => _showCreateLead(context, ref, snap),
                  onAddClient: () => _showCreateClient(context, ref),
                ),
                if (ui.lastMessage != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Material(
                      color: _Crm.gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      child: ListTile(
                        dense: true,
                        leading: const Icon(
                          LucideIcons.checkCircle2,
                          color: _Crm.gold,
                          size: 18,
                        ),
                        title: Text(
                          ui.lastMessage!,
                          style: const TextStyle(color: Colors.white),
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            LucideIcons.x,
                            size: 16,
                            color: _Crm.muted,
                          ),
                          onPressed: controller.clearMessage,
                        ),
                      ),
                    ),
                  ),
                if (crmTabShowsKpis(ui.selectedTab)) ...[
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _KpiStrip(
                      kpis: snap.kpis,
                      active: ui.kpiFilter,
                      onTap: controller.applyKpi,
                      scrollController: _kpiScroll,
                    ),
                  ),
                ],
                if (crmTabUsesSearch(ui.selectedTab)) ...[
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _SearchAndFilters(
                      ui: ui,
                      stages: stages,
                      showStageFilters: crmTabUsesStageFilter(ui.selectedTab),
                      onSearch: controller.setSearch,
                      onStage: controller.setStageFilter,
                      onClearKpi: () => controller.applyKpi(CrmKpiFilter.none),
                    ),
                  ),
                ],
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                    child: _TabBody(snap: snap, ui: ui),
                  ),
                ),
              ],
            );
          }

          if (!wide) {
            return mainPane();
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 268,
                child: CrmDeskSidebar(
                  sections: navSections,
                  selected: ui.selectedTab,
                  onSelect: controller.setTab,
                  live: live,
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

// ─── KPI strip ─────────────────────────────────────────────────────────────

class _KpiStrip extends StatelessWidget {
  const _KpiStrip({
    required this.kpis,
    required this.active,
    required this.onTap,
    this.scrollController,
  });

  final List<CrmKpi> kpis;
  final CrmKpiFilter active;
  final ValueChanged<CrmKpiFilter> onTap;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    if (kpis.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 78,
      child: Scrollbar(
        controller: scrollController,
        thumbVisibility: false,
        child: ListView.separated(
          controller: scrollController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 2),
          itemCount: kpis.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final k = kpis[i];
            return _KpiTile(
              kpi: k,
              selected:
                  _filterForLabel(k.label) != CrmKpiFilter.none &&
                  _filterForLabel(k.label) == active,
              onTap: () {
                final filter = _filterForLabel(k.label);
                if (filter != CrmKpiFilter.none) onTap(filter);
              },
            );
          },
        ),
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.kpi,
    required this.selected,
    required this.onTap,
  });

  final CrmKpi kpi;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _Crm.gold.withValues(alpha: 0.12) : _Crm.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 132, maxWidth: 168),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? _Crm.gold.withValues(alpha: 0.6) : _Crm.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                kpi.label,
                maxLines: 2,
                style: const TextStyle(color: _Crm.muted, fontSize: 11),
              ),
              const SizedBox(height: 4),
              Text(
                kpi.displayValue,
                maxLines: 1,
                style: TextStyle(
                  color: selected ? _Crm.gold : Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Search / filters / tabs ───────────────────────────────────────────────

class _SearchAndFilters extends StatelessWidget {
  const _SearchAndFilters({
    required this.ui,
    required this.stages,
    required this.onSearch,
    required this.onStage,
    required this.onClearKpi,
    this.showStageFilters = true,
  });

  final CrmUiState ui;
  final List<CrmPipelineStage> stages;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onStage;
  final VoidCallback onClearKpi;
  final bool showStageFilters;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          onChanged: onSearch,
          style: const TextStyle(color: Colors.white),
          decoration:
              _Crm.field(
                'Search',
                hint: 'Leads, clients, properties, references…',
              ).copyWith(
                prefixIcon: const Icon(
                  LucideIcons.search,
                  size: 18,
                  color: _Crm.muted,
                ),
                isDense: true,
              ),
        ),
        if (showStageFilters) ...[
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _Chip(
                  label: 'All stages',
                  selected: ui.stageFilter == null,
                  onTap: () => onStage(null),
                ),
                for (final s in stages)
                  _Chip(
                    label: s.name,
                    selected: ui.stageFilter == s.slug,
                    onTap: () => onStage(s.slug),
                  ),
                if (ui.kpiFilter != CrmKpiFilter.none)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: InputChip(
                      label: Text('KPI: ${ui.kpiFilter.name}'),
                      onDeleted: onClearKpi,
                      backgroundColor: _Crm.elevated,
                      deleteIconColor: _Crm.gold,
                      labelStyle: const TextStyle(color: _Crm.gold),
                      side: BorderSide(color: _Crm.gold.withValues(alpha: 0.4)),
                    ),
                  ),
              ],
            ),
          ),
        ] else if (ui.kpiFilter != CrmKpiFilter.none) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: InputChip(
              label: Text('KPI: ${ui.kpiFilter.name}'),
              onDeleted: onClearKpi,
              backgroundColor: _Crm.elevated,
              deleteIconColor: _Crm.gold,
              labelStyle: const TextStyle(color: _Crm.gold),
              side: BorderSide(color: _Crm.gold.withValues(alpha: 0.4)),
            ),
          ),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: _Crm.gold,
        backgroundColor: _Crm.elevated,
        labelStyle: TextStyle(
          color: selected ? AppColors.charcoal : Colors.white70,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        side: BorderSide(color: selected ? _Crm.gold : _Crm.border),
      ),
    );
  }
}

// ─── Tab body router ───────────────────────────────────────────────────────

class _TabBody extends ConsumerWidget {
  const _TabBody({required this.snap, required this.ui});

  final CrmCommandCenterSnapshot snap;
  final CrmUiState ui;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(crmControllerProvider.notifier);
    final leads = controller.filteredLeads(snap);
    final clients = controller.filteredClients(snap);
    final stages = [...snap.stages]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    Future<void> move(CrmLead lead, String stageId) async {
      try {
        await ref
            .read(crmServiceProvider)
            .moveLeadStage(leadId: lead.id, toStageId: stageId);
        await controller.afterMutation('Moved “${lead.title}”');
      } catch (e) {
        controller.setMessage('Move failed: $e');
      }
    }

    void openLead(CrmLead lead) {
      controller.selectLead(lead.id);
      _showLeadSheet(context, lead, snap);
    }

    return switch (ui.selectedTab) {
      CrmCommandTab.overview => _OverviewTab(
        snap: snap,
        onTab: controller.setTab,
        onOpenLead: openLead,
        onCompleteTask: (t) async {
          try {
            await ref.read(crmServiceProvider).updateTaskStatus(t.id, 'done');
            await controller.afterMutation('Task completed');
          } catch (e) {
            controller.setMessage('Failed: $e');
          }
        },
      ),
      CrmCommandTab.leads => _LeadTable(
        leads: leads,
        stages: stages,
        onOpen: openLead,
        onMove: move,
        onEdit: (l) => _showEditLead(context, ref, l),
      ),
      CrmCommandTab.pipeline => _PipelineBoard(
        stages: stages,
        leads: leads,
        onOpenLead: openLead,
        onMove: move,
      ),
      CrmCommandTab.clients => _ClientList(
        clients: clients,
        onOpen: controller.selectClient,
        onEdit: (c) => _showEditClient(context, ref, c),
      ),
      CrmCommandTab.properties => _BridgeList(
        rows: _searchRows(snap.properties, ui.searchQuery),
        icon: LucideIcons.building2,
        emptyText: 'No properties published yet.',
        moduleLabel: 'Open Properties',
        moduleRoute: RoutePaths.dashboardProperties,
      ),
      CrmCommandTab.inspections => _BridgeList(
        rows: _searchRows(snap.inspections, ui.searchQuery),
        icon: LucideIcons.calendarCheck,
        emptyText: 'No inspection requests yet.',
        moduleLabel: 'Open Inspections',
        moduleRoute: RoutePaths.dashboardInspections,
      ),
      CrmCommandTab.applications => _BridgeList(
        rows: _searchRows(snap.applications, ui.searchQuery),
        icon: LucideIcons.fileText,
        emptyText: 'No property applications yet.',
        moduleLabel: 'Open Applications',
        moduleRoute: RoutePaths.dashboardClientApplications,
      ),
      CrmCommandTab.calculator => CrmCalculatorLeadsTab(snap: snap),
      CrmCommandTab.payments => _BridgeList(
        rows: _searchRows(snap.payments, ui.searchQuery),
        icon: LucideIcons.wallet,
        emptyText: 'No client payment intents yet.',
        moduleLabel: 'Open Finance',
        moduleRoute: RoutePaths.dashboardFinance,
      ),
      CrmCommandTab.tasks => _TaskList(
        tasks: snap.tasks,
        onStatus: (t, status) async {
          try {
            await ref.read(crmServiceProvider).updateTask(
                  taskId: t.id,
                  status: status,
                );
            await controller.afterMutation('Task updated');
          } catch (e) {
            controller.setMessage('Failed: $e');
          }
        },
        onReschedule: (t, due) async {
          try {
            await ref.read(crmServiceProvider).updateTask(
                  taskId: t.id,
                  dueAt: due,
                );
            await controller.afterMutation('Task rescheduled');
          } catch (e) {
            controller.setMessage('Failed: $e');
          }
        },
        onAdd: () => _showCreateTask(context, ref, snap),
      ),
      CrmCommandTab.appointments => _AppointmentList(
        appointments: snap.appointments,
        onStatus: (a, status) async {
          try {
            await ref
                .read(crmServiceProvider)
                .updateAppointmentStatus(a.id, status);
            await controller.afterMutation('Appointment $status');
          } catch (e) {
            controller.setMessage('Failed: $e');
          }
        },
        onAdd: () => _showCreateAppointment(context, ref, snap),
      ),
      CrmCommandTab.activity => _TimelineList(events: snap.timeline),
      CrmCommandTab.analytics => _AnalyticsTab(snap: snap),
      CrmCommandTab.client360 => _Client360(
        snap: snap,
        client: controller.selectedClient(snap),
        onPick: controller.selectClient,
        onAddNote: (c) => _showAddNote(context, ref, c),
        onAddTask: (c) => _showCreateTask(context, ref, snap, clientId: c.id),
        onEdit: (c) => _showEditClient(context, ref, c),
      ),
    };
  }
}

// ─── Shared building blocks ────────────────────────────────────────────────

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.icon,
    required this.children,
    this.emptyText,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final String? emptyText;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _Crm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Crm.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: _Crm.gold),
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
                style: const TextStyle(color: _Crm.muted, fontSize: 12),
              ),
            )
          else
            ...children,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    this.subtitle,
    this.trailing,
    this.trailingColor,
    this.action,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final String? trailing;
  final Color? trailingColor;
  final Widget? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 3,
                      style: const TextStyle(color: _Crm.muted, fontSize: 11),
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              Text(
                trailing!,
                style: TextStyle(
                  color: trailingColor ?? _Crm.gold,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            ?action,
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, {this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? _Crm.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text, {this.icon = LucideIcons.circle, this.action});
  final String text;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 26, color: _Crm.muted),
          const SizedBox(height: 10),
          Text(text, style: const TextStyle(color: _Crm.muted)),
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    );
  }
}

// ─── Overview ──────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.snap,
    required this.onTab,
    required this.onOpenLead,
    required this.onCompleteTask,
  });

  final CrmCommandCenterSnapshot snap;
  final ValueChanged<CrmCommandTab> onTab;
  final ValueChanged<CrmLead> onOpenLead;
  final ValueChanged<CrmTask> onCompleteTask;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final endOfDay = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 1));

    final priorities = snap.tasks
        .where(
          (t) =>
              (t.status == CrmTaskStatus.open ||
                  t.status == CrmTaskStatus.inProgress) &&
              t.dueAt != null &&
              t.dueAt!.isBefore(endOfDay),
        )
        .take(6)
        .toList();
    final callbacks = snap.callbacks.take(5).toList();
    final upcomingInspections = snap.inspections
        .where((i) => i.when != null && i.when!.isAfter(now))
        .take(5)
        .toList();
    final applications = snap.applications.take(5).toList();
    final consultations = snap.consultations.take(5).toList();
    final payments = snap.payments.take(5).toList();
    final activity = snap.timeline.take(6).toList();
    final counts = snap.stageCounts();
    final stages = [...snap.stages]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final hotLeads = snap.leads
        .where(
          (l) =>
              l.priority == CrmPriority.high ||
              l.priority == CrmPriority.urgent,
        )
        .take(5)
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1400
            ? 3
            : constraints.maxWidth >= 900
            ? 2
            : 1;
        final gap = 14.0;
        final cardWidth =
            (constraints.maxWidth - (gap * (columns - 1))) / columns;

        final cards = <Widget>[
          _Panel(
            title: "Today's priorities",
            icon: LucideIcons.target,
            emptyText: 'No follow-ups due today.',
            trailing: TextButton(
              onPressed: () => onTab(CrmCommandTab.tasks),
              child: const Text(
                'All tasks',
                style: TextStyle(color: _Crm.gold, fontSize: 11),
              ),
            ),
            children: [
              for (final t in priorities)
                _Row(
                  title: t.title,
                  subtitle:
                      '${t.clientName ?? '—'} · ${t.taskType.label} · ${_fmtDate(t.dueAt)}',
                  trailing: 'Mark done',
                  onTap: () => onCompleteTask(t),
                ),
            ],
          ),
          _Panel(
            title: 'New callbacks',
            icon: LucideIcons.phoneCall,
            emptyText: 'No callback requests.',
            trailing: TextButton(
              onPressed: () => context.go(RoutePaths.dashboardCallbacks),
              child: const Text(
                'Open',
                style: TextStyle(color: _Crm.gold, fontSize: 11),
              ),
            ),
            children: [
              for (final r in callbacks)
                _Row(
                  title: r.title,
                  subtitle: '${r.subtitle ?? '—'} · ${_fmtDate(r.when)}',
                  trailing: r.status.isEmpty ? null : r.status,
                  trailingColor: _statusColor(r.status),
                ),
            ],
          ),
          _Panel(
            title: 'Upcoming inspections',
            icon: LucideIcons.calendarCheck,
            emptyText: 'No inspections scheduled.',
            trailing: TextButton(
              onPressed: () => context.go(RoutePaths.dashboardInspections),
              child: const Text(
                'Open',
                style: TextStyle(color: _Crm.gold, fontSize: 11),
              ),
            ),
            children: [
              for (final r in upcomingInspections)
                _Row(
                  title: r.title,
                  subtitle:
                      '${r.propertyTitle ?? 'Property TBD'} · ${_fmtDate(r.when)}',
                  trailing: r.status.isEmpty ? null : r.status,
                  trailingColor: _statusColor(r.status),
                ),
            ],
          ),
          _Panel(
            title: 'Recent applications',
            icon: LucideIcons.fileText,
            emptyText: 'No applications submitted.',
            trailing: TextButton(
              onPressed: () =>
                  context.go(RoutePaths.dashboardClientApplications),
              child: const Text(
                'Open',
                style: TextStyle(color: _Crm.gold, fontSize: 11),
              ),
            ),
            children: [
              for (final r in applications)
                _Row(
                  title: r.propertyTitle ?? r.title,
                  subtitle: '${_fmtMoney(r.amount)} · ${_fmtDate(r.when)}',
                  trailing: r.status.isEmpty ? null : r.status,
                  trailingColor: _statusColor(r.status),
                ),
            ],
          ),
          _Panel(
            title: 'Consultations',
            icon: LucideIcons.messageSquare,
            emptyText: 'No consultations booked.',
            trailing: TextButton(
              onPressed: () => context.go(RoutePaths.dashboardConsultations),
              child: const Text(
                'Open',
                style: TextStyle(color: _Crm.gold, fontSize: 11),
              ),
            ),
            children: [
              for (final r in consultations)
                _Row(
                  title: r.title,
                  subtitle: '${r.subtitle ?? '—'} · ${_fmtDate(r.when)}',
                  trailing: r.status.isEmpty ? null : r.status,
                  trailingColor: _statusColor(r.status),
                ),
            ],
          ),
          _Panel(
            title: 'Payment activity',
            icon: LucideIcons.wallet,
            emptyText: 'No payment intents yet.',
            trailing: TextButton(
              onPressed: () => onTab(CrmCommandTab.payments),
              child: const Text(
                'All',
                style: TextStyle(color: _Crm.gold, fontSize: 11),
              ),
            ),
            children: [
              for (final r in payments)
                _Row(
                  title: r.title,
                  subtitle:
                      '${_fmtMoney(r.amount)} · ${r.propertyTitle ?? '—'} · ${_fmtDate(r.when)}',
                  trailing: r.status.isEmpty ? null : r.status,
                  trailingColor: _statusColor(r.status),
                ),
            ],
          ),
          _Panel(
            title: 'Pipeline by stage',
            icon: LucideIcons.gitBranch,
            emptyText: 'No pipeline stages configured.',
            trailing: TextButton(
              onPressed: () => onTab(CrmCommandTab.pipeline),
              child: const Text(
                'Board',
                style: TextStyle(color: _Crm.gold, fontSize: 11),
              ),
            ),
            children: [
              for (final s in stages)
                _Row(
                  title: s.name,
                  subtitle:
                      '${s.probabilityPct.toStringAsFixed(0)}% probability',
                  trailing: '${counts[s.slug] ?? 0}',
                ),
            ],
          ),
          _Panel(
            title: 'Hot leads',
            icon: LucideIcons.trendingUp,
            emptyText: 'No high-priority leads.',
            trailing: TextButton(
              onPressed: () => onTab(CrmCommandTab.leads),
              child: const Text(
                'All leads',
                style: TextStyle(color: _Crm.gold, fontSize: 11),
              ),
            ),
            children: [
              for (final l in hotLeads)
                _Row(
                  title: l.title,
                  subtitle:
                      '${l.clientName ?? '—'} · ${l.stageName ?? 'No stage'} · ${l.priority.label}',
                  trailing: l.valueDisplay,
                  onTap: () => onOpenLead(l),
                ),
            ],
          ),
          _Panel(
            title: 'Recent activity',
            icon: LucideIcons.activity,
            emptyText: 'No activity logged.',
            trailing: TextButton(
              onPressed: () => onTab(CrmCommandTab.activity),
              child: const Text(
                'All',
                style: TextStyle(color: _Crm.gold, fontSize: 11),
              ),
            ),
            children: [
              for (final e in activity)
                _Row(
                  title: e.title,
                  subtitle:
                      '${e.clientName ?? '—'} · ${e.eventType} · ${_fmtDate(e.occurredAt)}',
                ),
            ],
          ),
        ];

        return SingleChildScrollView(
          child: Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final card in cards) SizedBox(width: cardWidth, child: card),
            ],
          ),
        );
      },
    );
  }
}

// ─── Pipeline board ────────────────────────────────────────────────────────

class _PipelineBoard extends StatelessWidget {
  const _PipelineBoard({
    required this.stages,
    required this.leads,
    required this.onOpenLead,
    required this.onMove,
  });

  final List<CrmPipelineStage> stages;
  final List<CrmLead> leads;
  final ValueChanged<CrmLead> onOpenLead;
  final Future<void> Function(CrmLead lead, String stageId) onMove;

  @override
  Widget build(BuildContext context) {
    if (stages.isEmpty) {
      return const _Empty(
        'No pipeline stages configured.',
        icon: LucideIcons.gitBranch,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 2),
          child: Text(
            'Pipeline Board',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            'Long-press a card to drag onto another column, or use Move.',
            style: TextStyle(color: _Crm.muted, fontSize: 12),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columnHeight = constraints.maxHeight;
              return Scrollbar(
                thumbVisibility: false,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(bottom: 2),
                  itemCount: stages.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (_, i) {
                    final stage = stages[i];
                    final columnLeads = leads
                        .where(
                          (l) =>
                              l.stageId == stage.id ||
                              (l.stageId == null && l.stageSlug == stage.slug),
                        )
                        .toList();
                    var stageValue = 0.0;
                    for (final l in columnLeads) {
                      stageValue += l.estimatedValue ?? 0;
                    }

                    return SizedBox(
                      width: 282,
                      height: columnHeight,
                      child: DragTarget<CrmLead>(
                        onWillAcceptWithDetails: (d) =>
                            d.data.stageId != stage.id,
                        onAcceptWithDetails: (d) => onMove(d.data, stage.id),
                        builder: (context, candidate, rejected) {
                          final hot = candidate.isNotEmpty;
                          return DecoratedBox(
                            decoration: BoxDecoration(
                              color: hot
                                  ? _Crm.gold.withValues(alpha: 0.08)
                                  : _Crm.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: hot
                                    ? _Crm.gold.withValues(alpha: 0.55)
                                    : _Crm.border,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    12,
                                    12,
                                    4,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          stage.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      _Pill(
                                        '${columnLeads.length}',
                                        color: _Crm.gold,
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    0,
                                    12,
                                    8,
                                  ),
                                  child: Text(
                                    '${stage.probabilityPct.toStringAsFixed(0)}% · ${_fmtMoney(stageValue == 0 ? null : stageValue)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: _Crm.muted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                const Divider(height: 1, color: _Crm.border),
                                Expanded(
                                  child: columnLeads.isEmpty
                                      ? const Center(
                                          child: Text(
                                            'Drop leads here',
                                            style: TextStyle(
                                              color: _Crm.muted,
                                              fontSize: 12,
                                            ),
                                          ),
                                        )
                                      : ListView.builder(
                                          padding: const EdgeInsets.all(10),
                                          itemCount: columnLeads.length,
                                          itemBuilder: (_, j) {
                                            final lead = columnLeads[j];
                                            return _LeadCard(
                                              lead: lead,
                                              stages: stages,
                                              onTap: () => onOpenLead(lead),
                                              onMove: (id) => onMove(lead, id),
                                            );
                                          },
                                        ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LeadCard extends StatelessWidget {
  const _LeadCard({
    required this.lead,
    required this.stages,
    required this.onTap,
    required this.onMove,
  });

  final CrmLead lead;
  final List<CrmPipelineStage> stages;
  final VoidCallback onTap;
  final ValueChanged<String> onMove;

  @override
  Widget build(BuildContext context) {
    final urgent =
        lead.priority == CrmPriority.urgent ||
        lead.priority == CrmPriority.high;

    final card = Material(
      color: _Crm.elevated,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                lead.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                lead.clientName ?? 'Unknown client',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _Crm.muted, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                '${lead.sourceName ?? 'Manual'} · ${lead.propertyTitle ?? lead.preferredLocation ?? 'No property'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _Crm.muted, fontSize: 11),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      lead.valueDisplay,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _Crm.gold,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _Pill(
                    lead.priority.label,
                    color: urgent ? _Crm.red : _Crm.muted,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              PopupMenuButton<String>(
                tooltip: 'Move stage',
                color: _Crm.elevated,
                padding: EdgeInsets.zero,
                onSelected: onMove,
                itemBuilder: (_) => [
                  for (final s in stages)
                    if (s.id != lead.stageId)
                      PopupMenuItem(
                        value: s.id,
                        child: Text(
                          'Move to ${s.name}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                ],
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.gitBranch, size: 14, color: _Crm.gold),
                    SizedBox(width: 4),
                    Text(
                      'Move',
                      style: TextStyle(color: _Crm.gold, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: LongPressDraggable<CrmLead>(
        data: lead,
        feedback: Material(
          color: Colors.transparent,
          child: SizedBox(
            width: 250,
            child: Opacity(opacity: 0.92, child: card),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.35, child: card),
        child: card,
      ),
    );
  }
}

// ─── Leads table ───────────────────────────────────────────────────────────

class _LeadTable extends StatelessWidget {
  const _LeadTable({
    required this.leads,
    required this.stages,
    required this.onOpen,
    required this.onMove,
    required this.onEdit,
  });

  final List<CrmLead> leads;
  final List<CrmPipelineStage> stages;
  final ValueChanged<CrmLead> onOpen;
  final Future<void> Function(CrmLead, String) onMove;
  final ValueChanged<CrmLead> onEdit;

  @override
  Widget build(BuildContext context) {
    if (leads.isEmpty) {
      return const _Empty(
        'No leads match this filter.',
        icon: LucideIcons.users,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Scrollbar(
            thumbVisibility: false,
            child: ListView.separated(
              itemCount: leads.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _LeadCardRow(
                lead: leads[i],
                stages: stages,
                onOpen: onOpen,
                onMove: onMove,
                onEdit: onEdit,
                compact: true,
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Container(
                width: 980,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _Crm.elevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _Crm.border),
                ),
                child: const Row(
                  children: [
                    SizedBox(width: 260, child: _HeadCell('Lead')),
                    SizedBox(width: 180, child: _HeadCell('Client')),
                    SizedBox(width: 130, child: _HeadCell('Stage')),
                    SizedBox(width: 130, child: _HeadCell('Source')),
                    SizedBox(width: 120, child: _HeadCell('Value')),
                    SizedBox(width: 120, child: _HeadCell('Actions')),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Scrollbar(
                thumbVisibility: false,
                child: ListView.separated(
                  itemCount: leads.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (_, i) => _LeadCardRow(
                    lead: leads[i],
                    stages: stages,
                    onOpen: onOpen,
                    onMove: onMove,
                    onEdit: onEdit,
                    compact: false,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LeadCardRow extends StatelessWidget {
  const _LeadCardRow({
    required this.lead,
    required this.stages,
    required this.onOpen,
    required this.onMove,
    required this.onEdit,
    required this.compact,
  });

  final CrmLead lead;
  final List<CrmPipelineStage> stages;
  final ValueChanged<CrmLead> onOpen;
  final Future<void> Function(CrmLead, String) onMove;
  final ValueChanged<CrmLead> onEdit;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l = lead;
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Edit',
          visualDensity: VisualDensity.compact,
          onPressed: () => onEdit(l),
          icon: const Icon(LucideIcons.pencil, size: 15, color: _Crm.muted),
        ),
        PopupMenuButton<String>(
          tooltip: 'Move stage',
          color: _Crm.elevated,
          onSelected: (id) => onMove(l, id),
          itemBuilder: (_) => [
            for (final s in stages)
              if (s.id != l.stageId)
                PopupMenuItem(
                  value: s.id,
                  child: Text(
                    '→ ${s.name}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
          ],
          icon: const Icon(LucideIcons.gitBranch, size: 15, color: _Crm.gold),
        ),
      ],
    );

    if (compact) {
      return Material(
        color: _Crm.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => onOpen(l),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l.clientName ?? '—',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Text(
                  '${l.status.label} · ${l.stageName ?? 'No stage'} · ${l.valueDisplay}',
                  style: const TextStyle(color: _Crm.muted, fontSize: 11),
                ),
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: actions),
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      color: _Crm.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onOpen(l),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: 980,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 260,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '${l.status.label} · ${l.priority.label} · captured ${_fmtDate(l.capturedAt)}',
                          style: const TextStyle(
                            color: _Crm.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: Text(
                      l.clientName ?? '—',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 130,
                    child: Text(
                      l.stageName ?? 'No stage',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 130,
                    child: Text(
                      l.sourceName ?? 'Manual',
                      style: const TextStyle(color: _Crm.muted, fontSize: 12),
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    child: Text(
                      l.valueDisplay,
                      style: const TextStyle(
                        color: _Crm.gold,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(width: 120, child: actions),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeadCell extends StatelessWidget {
  const _HeadCell(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: _Crm.muted,
        fontSize: 10,
        letterSpacing: 1,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

// ─── Lead detail sheet ─────────────────────────────────────────────────────

Future<void> _showLeadSheet(
  BuildContext context,
  CrmLead lead,
  CrmCommandCenterSnapshot snap,
) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: _Crm.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _LeadDetailSheet(lead: lead, snap: snap),
  );
}

class _LeadDetailSheet extends ConsumerWidget {
  const _LeadDetailSheet({required this.lead, required this.snap});

  final CrmLead lead;
  final CrmCommandCenterSnapshot snap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(crmControllerProvider.notifier);
    CrmClient? client;
    for (final c in snap.clients) {
      if (c.id == lead.clientId) client = c;
    }
    final phone = client?.phone ?? client?.whatsapp;
    final stages = [...snap.stages]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final events = snap.timeline
        .where((e) => e.clientId == lead.clientId)
        .take(8)
        .toList();

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lead.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${lead.stageName ?? 'No stage'} · ${lead.status.label} · ${lead.valueDisplay}',
                        style: const TextStyle(color: _Crm.muted),
                      ),
                    ],
                  ),
                ),
                _Pill(
                  lead.priority.label,
                  color:
                      lead.priority == CrmPriority.urgent ||
                          lead.priority == CrmPriority.high
                      ? _Crm.red
                      : _Crm.gold,
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(LucideIcons.x, color: _Crm.muted, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const _SectionTitle('Contact'),
            Wrap(
              spacing: 18,
              runSpacing: 10,
              children: [
                _Info('Client', lead.clientName ?? client?.fullName ?? '—'),
                _Info('Phone', phone ?? '—'),
                _Info('Email', client?.email ?? '—'),
                _Info('Client code', client?.clientCode ?? '—'),
                _Info('Assigned to', lead.assignedTo ?? 'Unassigned'),
                _Info('Budget', client?.budgetRange ?? '—'),
              ],
            ),
            const SizedBox(height: 16),
            const _SectionTitle('Interest'),
            Wrap(
              spacing: 18,
              runSpacing: 10,
              children: [
                _Info('Source', lead.sourceName ?? 'Manual'),
                _Info('Property', lead.propertyTitle ?? '—'),
                _Info('Preferred location', lead.preferredLocation ?? '—'),
                _Info('Captured', _fmtDate(lead.capturedAt)),
                _Info('Last contacted', _fmtDate(lead.lastContactedAt)),
                _Info('Next follow-up', _fmtDate(lead.nextFollowUpAt)),
              ],
            ),
            if ((lead.interestSummary ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                lead.interestSummary!,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
            if ((lead.notes ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _Crm.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _Crm.border),
                ),
                child: Text(
                  lead.notes!,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ],
            const SizedBox(height: 16),
            const _SectionTitle('Activity'),
            if (events.isEmpty)
              const Text(
                'No activity logged for this client.',
                style: TextStyle(color: _Crm.muted, fontSize: 12),
              )
            else
              for (final e in events)
                _Row(
                  title: e.title,
                  subtitle: '${e.eventType} · ${_fmtDate(e.occurredAt)}',
                ),
            const SizedBox(height: 16),
            const _SectionTitle('Actions'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    try {
                      await ref
                          .read(crmServiceProvider)
                          .convertLeadToClient(lead.id);
                      await controller.afterMutation('Lead converted');
                    } catch (e) {
                      controller.setMessage('Convert failed: $e');
                    }
                  },
                  icon: const Icon(LucideIcons.userPlus, size: 15),
                  label: const Text('Convert to Client'),
                  style: _Crm.solid,
                ),
                if (phone != null && phone.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => launchUrl(Uri.parse('tel:$phone')),
                    icon: const Icon(LucideIcons.phone, size: 15),
                    label: const Text('Call'),
                    style: _Crm.ghost,
                  ),
                if (client != null)
                  OutlinedButton.icon(
                    onPressed: () {
                      final c = client!;
                      Navigator.of(context).pop();
                      _showAddNote(context, ref, c);
                    },
                    icon: const Icon(LucideIcons.stickyNote, size: 15),
                    label: const Text('Add note'),
                    style: _Crm.ghost,
                  ),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showCreateTask(
                      context,
                      ref,
                      snap,
                      clientId: lead.clientId,
                      leadId: lead.id,
                    );
                  },
                  icon: const Icon(LucideIcons.listChecks, size: 15),
                  label: const Text('Schedule task'),
                  style: _Crm.ghost,
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showEditLead(context, ref, lead);
                  },
                  icon: const Icon(LucideIcons.pencil, size: 15),
                  label: const Text('Edit lead'),
                  style: _Crm.ghost,
                ),
                PopupMenuButton<String>(
                  color: _Crm.elevated,
                  onSelected: (stageId) async {
                    Navigator.of(context).pop();
                    try {
                      await ref
                          .read(crmServiceProvider)
                          .moveLeadStage(leadId: lead.id, toStageId: stageId);
                      await controller.afterMutation('Stage updated');
                    } catch (e) {
                      controller.setMessage('Move failed: $e');
                    }
                  },
                  itemBuilder: (_) => [
                    for (final s in stages)
                      if (s.id != lead.stageId)
                        PopupMenuItem(
                          value: s.id,
                          child: Text(
                            'Move to ${s.name}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _Crm.gold.withValues(alpha: 0.45),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.gitBranch, size: 15, color: _Crm.gold),
                        SizedBox(width: 6),
                        Text(
                          'Move stage',
                          style: TextStyle(color: _Crm.gold, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Clients ───────────────────────────────────────────────────────────────

class _ClientList extends StatelessWidget {
  const _ClientList({
    required this.clients,
    required this.onOpen,
    required this.onEdit,
  });

  final List<CrmClient> clients;
  final ValueChanged<String> onOpen;
  final ValueChanged<CrmClient> onEdit;

  @override
  Widget build(BuildContext context) {
    if (clients.isEmpty) {
      return const _Empty('No clients yet.', icon: LucideIcons.users);
    }
    return ListView.separated(
      itemCount: clients.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final c = clients[i];
        return Material(
          color: _Crm.surface,
          borderRadius: BorderRadius.circular(14),
          child: ListTile(
            onTap: () => onOpen(c.id),
            leading: CircleAvatar(
              backgroundColor: _Crm.elevated,
              child: Text(
                c.fullName.isEmpty ? '?' : c.fullName[0].toUpperCase(),
                style: const TextStyle(color: _Crm.gold),
              ),
            ),
            title: Text(
              c.fullName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              '${c.clientCode} · ${c.relationshipStatus.label} · ${c.phone ?? c.email ?? '—'} · ${c.budgetRange}',
              maxLines: 3,
              style: const TextStyle(color: _Crm.muted, fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Pill(
                  c.healthLabel.label,
                  color: c.healthScore >= 60 ? _Crm.green : _Crm.amber,
                ),
                IconButton(
                  tooltip: 'Edit',
                  onPressed: () => onEdit(c),
                  icon: const Icon(
                    LucideIcons.pencil,
                    size: 15,
                    color: _Crm.muted,
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

// ─── Bridge lists (properties / inspections / applications) ────────────────

class _BridgeList extends ConsumerWidget {
  const _BridgeList({
    required this.rows,
    required this.icon,
    required this.emptyText,
    required this.moduleLabel,
    required this.moduleRoute,
  });

  final List<SalesBridgeRow> rows;
  final IconData icon;
  final String emptyText;
  final String moduleLabel;
  final String moduleRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canOpen = RoleNavPolicy.canAccessPath(
      ref.watch(identitySessionProvider),
      moduleRoute,
    );
    final openButton = canOpen
        ? OutlinedButton.icon(
            onPressed: () => context.go(moduleRoute),
            icon: const Icon(LucideIcons.externalLink, size: 15),
            label: Text(moduleLabel),
            style: _Crm.ghost,
          )
        : null;

    if (rows.isEmpty) {
      return _Empty(emptyText, icon: icon, action: openButton);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              '${rows.length} record${rows.length == 1 ? '' : 's'}',
              style: const TextStyle(color: _Crm.muted, fontSize: 12),
            ),
            const Spacer(),
            ?openButton,
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Scrollbar(
            thumbVisibility: false,
            child: ListView.separated(
              itemCount: rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final r = rows[i];
                final bits = <String>[
                  if (r.clientName != null && r.clientName!.isNotEmpty)
                    r.clientName!,
                  if (r.propertyTitle != null && r.propertyTitle!.isNotEmpty)
                    r.propertyTitle!,
                  if (r.subtitle != null && r.subtitle!.isNotEmpty) r.subtitle!,
                  if (r.when != null) _fmtDate(r.when),
                ];
                return Material(
                  color: _Crm.surface,
                  borderRadius: BorderRadius.circular(14),
                  child: ListTile(
                    onTap: canOpen ? () => context.go(moduleRoute) : null,
                    leading: Icon(icon, size: 18, color: _Crm.gold),
                    title: Text(
                      r.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      bits.isEmpty ? '—' : bits.join(' · '),
                      maxLines: 3,
                      style: const TextStyle(color: _Crm.muted, fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (r.amount != null) ...[
                          Text(
                            _fmtMoney(r.amount),
                            style: const TextStyle(
                              color: _Crm.gold,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (r.status.isNotEmpty)
                          _Pill(r.status, color: _statusColor(r.status)),
                        if (canOpen) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            LucideIcons.chevronRight,
                            size: 16,
                            color: _Crm.muted,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Tasks / appointments / activity ───────────────────────────────────────

Widget _taskActionsMenu({
  required BuildContext context,
  required CrmTask task,
  required void Function(CrmTask task, String status) onStatus,
  required void Function(CrmTask task, DateTime due) onReschedule,
}) {
  return PopupMenuButton<String>(
    tooltip: 'Task actions',
    color: _Crm.elevated,
    onSelected: (action) async {
      if (action == 'reschedule') {
        final d = await showDatePicker(
          context: context,
          initialDate: task.dueAt ?? DateTime.now(),
          firstDate: DateTime.now().subtract(const Duration(days: 1)),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (d == null || !context.mounted) return;
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(task.dueAt ?? DateTime.now()),
        );
        onReschedule(
          task,
          DateTime(
            d.year,
            d.month,
            d.day,
            time?.hour ?? 9,
            time?.minute ?? 0,
          ),
        );
        return;
      }
      onStatus(task, action);
    },
    itemBuilder: (_) => const [
      PopupMenuItem(
        value: 'in_progress',
        child: Text('Start', style: TextStyle(color: Colors.white)),
      ),
      PopupMenuItem(
        value: 'done',
        child: Text('Mark done', style: TextStyle(color: Colors.white)),
      ),
      PopupMenuItem(
        value: 'reschedule',
        child: Text('Change due date', style: TextStyle(color: Colors.white)),
      ),
      PopupMenuItem(
        value: 'cancelled',
        child: Text('Cancel', style: TextStyle(color: Colors.white)),
      ),
      PopupMenuItem(
        value: 'open',
        child: Text('Reopen', style: TextStyle(color: Colors.white)),
      ),
    ],
  );
}

class _TaskList extends StatelessWidget {
  const _TaskList({
    required this.tasks,
    required this.onStatus,
    required this.onReschedule,
    required this.onAdd,
  });

  final List<CrmTask> tasks;
  final void Function(CrmTask task, String status) onStatus;
  final void Function(CrmTask task, DateTime due) onReschedule;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(LucideIcons.plus, size: 15),
            label: const Text('Add task'),
            style: _Crm.solid,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: tasks.isEmpty
              ? _Empty(
                  'No tasks yet.',
                  icon: LucideIcons.listChecks,
                  action: FilledButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(LucideIcons.plus, size: 15),
                    label: const Text('Add task'),
                    style: _Crm.solid,
                  ),
                )
              : ListView.separated(
                  itemCount: tasks.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final t = tasks[i];
                    return Material(
                      color: _Crm.surface,
                      borderRadius: BorderRadius.circular(14),
                      child: ListTile(
                        title: Text(
                          t.title,
                          style: TextStyle(
                            color: Colors.white,
                            decoration: t.status == CrmTaskStatus.done
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        subtitle: Text(
                          '${t.clientName ?? '—'} · ${t.taskType.label} · ${_fmtDate(t.dueAt)} · ${t.status.label}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _Crm.muted,
                            fontSize: 12,
                          ),
                        ),
                        trailing: _taskActionsMenu(
                          context: context,
                          task: t,
                          onStatus: onStatus,
                          onReschedule: onReschedule,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _AppointmentList extends StatelessWidget {
  const _AppointmentList({
    required this.appointments,
    required this.onStatus,
    required this.onAdd,
  });

  final List<CrmAppointment> appointments;
  final void Function(CrmAppointment, String) onStatus;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(LucideIcons.plus, size: 15),
            label: const Text('Schedule'),
            style: _Crm.solid,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: appointments.isEmpty
              ? _Empty(
                  'No appointments scheduled.',
                  icon: LucideIcons.calendar,
                  action: FilledButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(LucideIcons.plus, size: 15),
                    label: const Text('Schedule'),
                    style: _Crm.solid,
                  ),
                )
              : ListView.separated(
                  itemCount: appointments.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final a = appointments[i];
                    return Material(
                      color: _Crm.surface,
                      borderRadius: BorderRadius.circular(14),
                      child: ListTile(
                        title: Text(
                          a.title,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          '${a.clientName ?? '—'} · ${a.appointmentType} · ${_fmtDate(a.scheduledAt)} · ${a.location ?? 'No location'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _Crm.muted,
                            fontSize: 12,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _Pill(
                              a.status.label,
                              color: _statusColor(a.status.slug),
                            ),
                            PopupMenuButton<String>(
                              color: _Crm.elevated,
                              onSelected: (s) => onStatus(a, s),
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'confirmed',
                                  child: Text(
                                    'Confirm',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'completed',
                                  child: Text(
                                    'Complete',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'cancelled',
                                  child: Text(
                                    'Cancel',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'no_show',
                                  child: Text(
                                    'No show',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _TimelineList extends StatelessWidget {
  const _TimelineList({required this.events});
  final List<CrmTimelineEvent> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const _Empty('No activity yet.', icon: LucideIcons.activity);
    }
    return ListView.separated(
      itemCount: events.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final e = events[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _Crm.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _Crm.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                e.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${e.clientName ?? '—'} · ${e.eventType} · ${_fmtDate(e.occurredAt)}',
                style: const TextStyle(color: _Crm.muted, fontSize: 12),
              ),
              if ((e.description ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  e.description!,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ─── Analytics (real counts only) ──────────────────────────────────────────

class _AnalyticsTab extends StatelessWidget {
  const _AnalyticsTab({required this.snap});
  final CrmCommandCenterSnapshot snap;

  @override
  Widget build(BuildContext context) {
    final sources = <String, int>{};
    final statuses = <CrmLeadStatus, int>{};
    var pipelineValue = 0.0;
    var wonValue = 0.0;
    for (final l in snap.leads) {
      final src = (l.sourceName ?? 'Manual').trim();
      sources[src] = (sources[src] ?? 0) + 1;
      statuses[l.status] = (statuses[l.status] ?? 0) + 1;
      if (l.status == CrmLeadStatus.won) {
        wonValue += l.estimatedValue ?? 0;
      } else if (l.status != CrmLeadStatus.lost) {
        pipelineValue += l.estimatedValue ?? 0;
      }
    }
    final sourceEntries = sources.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxSource = sourceEntries.isEmpty ? 1 : sourceEntries.first.value;
    final won = statuses[CrmLeadStatus.won] ?? 0;
    final lost = statuses[CrmLeadStatus.lost] ?? 0;
    final closed = won + lost;
    final conversion = closed == 0 ? 0.0 : (won / closed) * 100;
    final counts = snap.stageCounts();
    final stages = [...snap.stages]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StatTile(
                'Total leads',
                '${snap.leads.length}',
                LucideIcons.users,
              ),
              _StatTile(
                'Open pipeline value',
                _fmtMoney(pipelineValue),
                LucideIcons.banknote,
              ),
              _StatTile(
                'Won value',
                _fmtMoney(wonValue),
                LucideIcons.checkCircle2,
              ),
              _StatTile('Won / Lost', '$won / $lost', LucideIcons.target),
              _StatTile(
                'Conversion',
                '${conversion.toStringAsFixed(0)}%',
                LucideIcons.percent,
              ),
              _StatTile(
                'Clients',
                '${snap.clients.length}',
                LucideIcons.briefcase,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Panel(
            title: 'Leads by source',
            icon: LucideIcons.barChart3,
            emptyText: 'No leads captured yet.',
            children: [
              for (final e in sourceEntries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              e.key,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Text(
                            '${e.value}',
                            style: const TextStyle(
                              color: _Crm.gold,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: e.value / maxSource,
                          minHeight: 6,
                          backgroundColor: _Crm.elevated,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            _Crm.gold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _Panel(
            title: 'Leads by stage',
            icon: LucideIcons.gitBranch,
            emptyText: 'No pipeline stages configured.',
            children: [
              for (final s in stages)
                _Row(
                  title: s.name,
                  subtitle:
                      '${s.probabilityPct.toStringAsFixed(0)}% probability',
                  trailing: '${counts[s.slug] ?? 0}',
                ),
            ],
          ),
          const SizedBox(height: 16),
          _Panel(
            title: 'Leads by status',
            icon: LucideIcons.activity,
            emptyText: 'No leads captured yet.',
            children: [
              for (final s in CrmLeadStatus.values)
                if ((statuses[s] ?? 0) > 0)
                  _Row(title: s.label, trailing: '${statuses[s]}'),
            ],
          ),
          const SizedBox(height: 16),
          _Panel(
            title: 'Cross-module volume',
            icon: LucideIcons.layoutGrid,
            children: [
              _Row(title: 'Callbacks', trailing: '${snap.callbacks.length}'),
              _Row(
                title: 'Consultations',
                trailing: '${snap.consultations.length}',
              ),
              _Row(
                title: 'Inspections',
                trailing: '${snap.inspections.length}',
              ),
              _Row(
                title: 'Applications',
                trailing: '${snap.applications.length}',
              ),
              _Row(title: 'Payments', trailing: '${snap.payments.length}'),
              _Row(title: 'Properties', trailing: '${snap.properties.length}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile(this.label, this.value, this.icon);
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _Crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _Crm.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _Crm.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _Crm.muted, fontSize: 11),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
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

// ─── Client 360 ────────────────────────────────────────────────────────────

class _Client360 extends StatelessWidget {
  const _Client360({
    required this.snap,
    required this.client,
    required this.onPick,
    required this.onAddNote,
    required this.onAddTask,
    required this.onEdit,
  });

  final CrmCommandCenterSnapshot snap;
  final CrmClient? client;
  final ValueChanged<String> onPick;
  final ValueChanged<CrmClient> onAddNote;
  final ValueChanged<CrmClient> onAddTask;
  final ValueChanged<CrmClient> onEdit;

  @override
  Widget build(BuildContext context) {
    if (snap.clients.isEmpty) {
      return const _Empty(
        'Create a client to open the 360° view.',
        icon: LucideIcons.user,
      );
    }
    final c = client ?? snap.clients.first;
    final clientLeads = snap.leads.where((l) => l.clientId == c.id).toList();
    final clientTasks = snap.tasks.where((t) => t.clientId == c.id).toList();
    final clientAppts = snap.appointments
        .where((a) => a.clientId == c.id)
        .toList();
    final events = snap.timeline
        .where((e) => e.clientId == c.id)
        .take(12)
        .toList();
    bool matchesRow(SalesBridgeRow r) => _bridgeMatchesClient(c, r);

    final relatedInspections = snap.inspections
        .where(matchesRow)
        .take(8)
        .toList();
    final relatedCallbacks = snap.callbacks.where(matchesRow).take(8).toList();
    final relatedConsultations = snap.consultations
        .where(matchesRow)
        .take(8)
        .toList();
    final relatedApps = snap.applications.where(matchesRow).take(8).toList();
    final relatedPayments = snap.payments.where(matchesRow).take(8).toList();

    final detailSections = _Client360Detail(
      c: c,
      clientLeads: clientLeads,
      clientTasks: clientTasks,
      clientAppts: clientAppts,
      events: events,
      relatedInspections: relatedInspections,
      relatedCallbacks: relatedCallbacks,
      relatedConsultations: relatedConsultations,
      relatedApps: relatedApps,
      relatedPayments: relatedPayments,
      onAddNote: onAddNote,
      onAddTask: onAddTask,
      onEdit: onEdit,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 960;

        if (stacked) {
          return Scrollbar(
            thumbVisibility: false,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 8),
              children: [
                SizedBox(
                  height: 52,
                  child: Scrollbar(
                    thumbVisibility: false,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: snap.clients.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final item = snap.clients[i];
                        final selected = item.id == c.id;
                        return FilterChip(
                          label: Text(item.fullName),
                          selected: selected,
                          onSelected: (_) => onPick(item.id),
                          selectedColor: _Crm.gold.withValues(alpha: 0.2),
                          checkmarkColor: _Crm.gold,
                          labelStyle: TextStyle(
                            color: selected ? _Crm.gold : Colors.white70,
                            fontSize: 12,
                          ),
                          side: BorderSide(
                            color: selected ? _Crm.gold : _Crm.border,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                detailSections,
              ],
            ),
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 240,
              child: Scrollbar(
                thumbVisibility: false,
                child: Container(
                  decoration: BoxDecoration(
                    color: _Crm.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _Crm.border),
                  ),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: snap.clients.length,
                    itemBuilder: (_, i) {
                      final item = snap.clients[i];
                      return ListTile(
                        dense: true,
                        selected: item.id == c.id,
                        selectedTileColor: _Crm.elevated,
                        title: Text(
                          item.fullName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          item.clientCode,
                          style: const TextStyle(
                            color: _Crm.muted,
                            fontSize: 11,
                          ),
                        ),
                        onTap: () => onPick(item.id),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Scrollbar(
                thumbVisibility: false,
                child: ListView(children: [detailSections]),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Client360Detail extends ConsumerWidget {
  const _Client360Detail({
    required this.c,
    required this.clientLeads,
    required this.clientTasks,
    required this.clientAppts,
    required this.events,
    required this.relatedInspections,
    required this.relatedCallbacks,
    required this.relatedConsultations,
    required this.relatedApps,
    required this.relatedPayments,
    required this.onAddNote,
    required this.onAddTask,
    required this.onEdit,
  });

  final CrmClient c;
  final List<CrmLead> clientLeads;
  final List<CrmTask> clientTasks;
  final List<CrmAppointment> clientAppts;
  final List<CrmTimelineEvent> events;
  final List<SalesBridgeRow> relatedInspections;
  final List<SalesBridgeRow> relatedCallbacks;
  final List<SalesBridgeRow> relatedConsultations;
  final List<SalesBridgeRow> relatedApps;
  final List<SalesBridgeRow> relatedPayments;
  final ValueChanged<CrmClient> onAddNote;
  final ValueChanged<CrmClient> onAddTask;
  final ValueChanged<CrmClient> onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(identitySessionProvider);
    bool canOpen(String path) => RoleNavPolicy.canAccessPath(session, path);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _Crm.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _Crm.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                c.fullName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${c.clientCode} · ${c.customerType.label} · ${c.relationshipStatus.label}',
                style: const TextStyle(color: _Crm.muted),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 18,
                runSpacing: 10,
                children: [
                  _Info('Phone', c.phone ?? '—'),
                  _Info('Email', c.email ?? '—'),
                  _Info('Budget', c.budgetRange),
                  _Info(
                    'Health',
                    '${c.healthLabel.label} (${c.healthScore.toStringAsFixed(0)})',
                  ),
                  _Info('Lead score', c.leadScore.toStringAsFixed(0)),
                  _Info(
                    'Locations',
                    c.preferredLocations.isEmpty
                        ? '—'
                        : c.preferredLocations.join(', '),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if ((c.phone ?? '').isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () => launchUrl(Uri.parse('tel:${c.phone}')),
                      icon: const Icon(LucideIcons.phone, size: 15),
                      label: const Text('Call'),
                      style: _Crm.ghost,
                    ),
                  OutlinedButton.icon(
                    onPressed: () => onEdit(c),
                    icon: const Icon(LucideIcons.pencil, size: 15),
                    label: const Text('Edit'),
                    style: _Crm.ghost,
                  ),
                  FilledButton.icon(
                    onPressed: () => onAddTask(c),
                    icon: const Icon(LucideIcons.checkSquare, size: 15),
                    label: const Text('Task'),
                    style: _Crm.solid,
                  ),
                  OutlinedButton.icon(
                    onPressed: () => onAddNote(c),
                    icon: const Icon(LucideIcons.stickyNote, size: 15),
                    label: const Text('Note'),
                    style: _Crm.ghost,
                  ),
                  if (canOpen(RoutePaths.dashboardFinance))
                    OutlinedButton.icon(
                      onPressed: () => context.go(RoutePaths.dashboardFinance),
                      icon: const Icon(LucideIcons.wallet, size: 15),
                      label: const Text('Finance'),
                      style: _Crm.ghost,
                    ),
                  if (canOpen(RoutePaths.dashboardDocuments))
                    OutlinedButton.icon(
                      onPressed: () => context.go(RoutePaths.dashboardDocuments),
                      icon: const Icon(LucideIcons.fileText, size: 15),
                      label: const Text('Documents'),
                      style: _Crm.ghost,
                    ),
                  if (canOpen(RoutePaths.dashboardConstruction))
                    OutlinedButton.icon(
                      onPressed: () =>
                          context.go(RoutePaths.dashboardConstruction),
                      icon: const Icon(LucideIcons.hardHat, size: 15),
                      label: const Text('Construction'),
                      style: _Crm.ghost,
                    ),
                  if (canOpen(RoutePaths.dashboardSupport))
                    OutlinedButton.icon(
                      onPressed: () => context.go(
                        '${RoutePaths.dashboardSupport}?tab=clientMessages',
                      ),
                      icon: const Icon(LucideIcons.messageSquare, size: 15),
                      label: const Text('Messages'),
                      style: _Crm.ghost,
                    ),
                  if (canOpen(RoutePaths.dashboardInvestors))
                    OutlinedButton.icon(
                      onPressed: () =>
                          context.go(RoutePaths.dashboardInvestors),
                      icon: const Icon(LucideIcons.landmark, size: 15),
                      label: const Text('Investors'),
                      style: _Crm.ghost,
                    ),
                  if ((c.profileId ?? '').isEmpty &&
                      (c.email ?? '').trim().contains('@'))
                    FilledButton.icon(
                      onPressed: () async {
                        final parts = c.fullName.trim().split(RegExp(r'\s+'));
                        final first = parts.isEmpty ? null : parts.first;
                        final last = parts.length > 1
                            ? parts.sublist(1).join(' ')
                            : null;
                        try {
                          var invite = await ref
                              .read(organizationServiceProvider)
                              .invitePortalUser(
                                email: c.email!.trim(),
                                roleSlug: 'client',
                                firstName: first,
                                lastName: last,
                                phone: c.phone,
                                crmClientId: c.id,
                              );
                          if (!context.mounted) return;
                          if (invite.status == 'accepted') {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Portal access linked for ${invite.email}',
                                ),
                              ),
                            );
                            ref.invalidate(crmSnapshotProvider);
                            return;
                          }
                          if (!invite.hasUsableToken) {
                            invite = await ref
                                .read(organizationServiceProvider)
                                .revealPortalInviteToken(invite.id);
                          }
                          final path =
                              OrganizationService.portalInviteRegisterPath(
                                invite,
                              );
                          final link = '${Uri.base.origin}/#$path';
                          await Clipboard.setData(ClipboardData(text: link));
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Portal invite link copied — share securely',
                              ),
                            ),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(userFacingError(e))),
                          );
                        }
                      },
                      icon: const Icon(LucideIcons.userPlus, size: 15),
                      label: const Text('Invite to portal'),
                      style: _Crm.solid,
                    ),
                  if ((c.profileId ?? '').isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _Crm.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _Crm.green.withValues(alpha: 0.45),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            LucideIcons.badgeCheck,
                            size: 15,
                            color: _Crm.green,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Portal linked',
                            style: TextStyle(
                              color: _Crm.green,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionTitle('Leads (${clientLeads.length})'),
        for (final l in clientLeads)
          _Row(
            title: l.title,
            subtitle: '${l.stageName ?? '—'} · ${l.status.label}',
            trailing: l.valueDisplay,
          ),
        const SizedBox(height: 8),
        _SectionTitle('Tasks (${clientTasks.length})'),
        for (final t in clientTasks)
          _Row(
            title: t.title,
            subtitle: '${t.taskType.label} · ${_fmtDate(t.dueAt)}',
            trailing: t.status.label,
            action: _taskActionsMenu(
              context: context,
              task: t,
              onStatus: (task, status) async {
                try {
                  await ref.read(crmServiceProvider).updateTask(
                    taskId: task.id,
                    status: status,
                  );
                  await ref
                      .read(crmControllerProvider.notifier)
                      .afterMutation('Task updated');
                } catch (e) {
                  ref
                      .read(crmControllerProvider.notifier)
                      .setMessage('Failed: $e');
                }
              },
              onReschedule: (task, due) async {
                try {
                  await ref.read(crmServiceProvider).updateTask(
                    taskId: task.id,
                    dueAt: due,
                  );
                  await ref
                      .read(crmControllerProvider.notifier)
                      .afterMutation('Task rescheduled');
                } catch (e) {
                  ref
                      .read(crmControllerProvider.notifier)
                      .setMessage('Failed: $e');
                }
              },
            ),
          ),
        const SizedBox(height: 8),
        _SectionTitle('Appointments (${clientAppts.length})'),
        for (final a in clientAppts)
          _Row(
            title: a.title,
            subtitle: _fmtDate(a.scheduledAt),
            trailing: a.status.label,
          ),
        const SizedBox(height: 8),
        _SectionTitle('Inspections (linked) (${relatedInspections.length})'),
        if (relatedInspections.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text(
              'No matching inspections by name.',
              style: TextStyle(color: _Crm.muted, fontSize: 12),
            ),
          ),
        for (final i in relatedInspections)
          _Row(
            title: i.title,
            subtitle: '${i.propertyTitle ?? '—'} · ${_fmtDate(i.when)}',
            trailing: i.status,
          ),
        const SizedBox(height: 8),
        _SectionTitle('Applications (linked) (${relatedApps.length})'),
        if (relatedApps.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text(
              'No matching applications yet.',
              style: TextStyle(color: _Crm.muted, fontSize: 12),
            ),
          ),
        for (final a in relatedApps)
          _Row(
            title: a.propertyTitle ?? a.title,
            subtitle: _fmtDate(a.when),
            trailing: a.status,
          ),
        const SizedBox(height: 8),
        _SectionTitle('Payments (linked) (${relatedPayments.length})'),
        if (relatedPayments.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text(
              'No matching payment intents.',
              style: TextStyle(color: _Crm.muted, fontSize: 12),
            ),
          ),
        for (final p in relatedPayments)
          _Row(
            title: p.title,
            subtitle:
                '${_fmtMoney(p.amount)} · ${p.propertyTitle ?? '—'} · ${_fmtDate(p.when)}',
            trailing: p.status,
          ),
        const SizedBox(height: 8),
        _SectionTitle('Callbacks (${relatedCallbacks.length})'),
        for (final b in relatedCallbacks)
          _Row(
            title: b.title,
            subtitle: b.subtitle ?? _fmtDate(b.when),
            trailing: b.status,
          ),
        const SizedBox(height: 8),
        _SectionTitle('Consultations (${relatedConsultations.length})'),
        for (final x in relatedConsultations)
          _Row(
            title: x.title,
            subtitle: x.subtitle ?? _fmtDate(x.when),
            trailing: x.status,
          ),
        const SizedBox(height: 8),
        const _SectionTitle('Recent activity'),
        if (events.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No activity logged.',
              style: TextStyle(color: _Crm.muted, fontSize: 12),
            ),
          ),
        for (final e in events)
          _Row(
            title: e.title,
            subtitle:
                '${e.description ?? e.eventType} · ${_fmtDate(e.occurredAt)}',
          ),
      ],
    );
  }
}

class _Info extends StatelessWidget {
  const _Info(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 168,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: _Crm.muted, fontSize: 11)),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: _Crm.gold,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ─── Dialogs ───────────────────────────────────────────────────────────────

Widget _dialogField(
  TextEditingController controller,
  String label, {
  int maxLines = 1,
  TextInputType? keyboardType,
}) {
  return TextField(
    controller: controller,
    maxLines: maxLines,
    keyboardType: keyboardType,
    style: const TextStyle(color: Colors.white),
    decoration: _Crm.field(label),
  );
}

AlertDialog _shell({
  required String title,
  required Widget content,
  required VoidCallback onCancel,
  required VoidCallback onConfirm,
  String confirmLabel = 'Save',
  double width = 440,
}) {
  return AlertDialog(
    backgroundColor: _Crm.surface,
    title: Text(title, style: const TextStyle(color: Colors.white)),
    content: SizedBox(
      width: width,
      child: SingleChildScrollView(child: content),
    ),
    actions: [
      TextButton(
        onPressed: onCancel,
        child: const Text('Cancel', style: TextStyle(color: _Crm.muted)),
      ),
      FilledButton(
        onPressed: onConfirm,
        style: _Crm.solid,
        child: Text(confirmLabel),
      ),
    ],
  );
}

class _ClientDraft {
  _ClientDraft([CrmClient? existing])
    : name = TextEditingController(text: existing?.fullName ?? ''),
      email = TextEditingController(text: existing?.email ?? ''),
      phone = TextEditingController(text: existing?.phone ?? ''),
      whatsapp = TextEditingController(text: existing?.whatsapp ?? ''),
      company = TextEditingController(text: existing?.company ?? ''),
      occupation = TextEditingController(text: existing?.occupation ?? ''),
      budgetMin = TextEditingController(
        text: existing?.budgetMin?.toStringAsFixed(0) ?? '',
      ),
      budgetMax = TextEditingController(
        text: existing?.budgetMax?.toStringAsFixed(0) ?? '',
      ),
      locations = TextEditingController(
        text: existing?.preferredLocations.join(', ') ?? '',
      ),
      customerType = existing?.customerType.slug ?? 'buyer',
      relationship = existing?.relationshipStatus.slug ?? 'lead';

  final TextEditingController name;
  final TextEditingController email;
  final TextEditingController phone;
  final TextEditingController whatsapp;
  final TextEditingController company;
  final TextEditingController occupation;
  final TextEditingController budgetMin;
  final TextEditingController budgetMax;
  final TextEditingController locations;
  String customerType;
  String relationship;

  List<String> get locationList => locations.text
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();

  double? money(TextEditingController controller) {
    final raw = controller.text.replaceAll(',', '').trim();
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }
}

Widget _clientDraftFields(
  _ClientDraft draft,
  void Function(void Function()) setLocal,
) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _dialogField(draft.name, 'Full name'),
      const SizedBox(height: 10),
      _dialogField(draft.phone, 'Phone', keyboardType: TextInputType.phone),
      const SizedBox(height: 10),
      _dialogField(
        draft.whatsapp,
        'WhatsApp',
        keyboardType: TextInputType.phone,
      ),
      const SizedBox(height: 10),
      _dialogField(
        draft.email,
        'Email',
        keyboardType: TextInputType.emailAddress,
      ),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        initialValue: draft.customerType,
        dropdownColor: _Crm.elevated,
        style: const TextStyle(color: Colors.white),
        decoration: _Crm.field('Client type'),
        items: [
          for (final type in CrmCustomerType.values)
            DropdownMenuItem(value: type.slug, child: Text(type.label)),
        ],
        onChanged: (value) => setLocal(
          () => draft.customerType = value ?? draft.customerType,
        ),
      ),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        initialValue: draft.relationship,
        dropdownColor: _Crm.elevated,
        style: const TextStyle(color: Colors.white),
        decoration: _Crm.field('Relationship'),
        items: [
          for (final status in CrmRelationshipStatus.values)
            DropdownMenuItem(value: status.slug, child: Text(status.label)),
        ],
        onChanged: (value) => setLocal(
          () => draft.relationship = value ?? draft.relationship,
        ),
      ),
      const SizedBox(height: 10),
      _dialogField(
        draft.budgetMin,
        'Budget from (₦)',
        keyboardType: TextInputType.number,
      ),
      const SizedBox(height: 10),
      _dialogField(
        draft.budgetMax,
        'Budget to (₦)',
        keyboardType: TextInputType.number,
      ),
      const SizedBox(height: 10),
      _dialogField(draft.locations, 'Preferred locations (comma separated)'),
      const SizedBox(height: 10),
      _dialogField(draft.company, 'Company'),
      const SizedBox(height: 10),
      _dialogField(draft.occupation, 'Occupation'),
    ],
  );
}

Future<void> _showCreateClient(BuildContext context, WidgetRef ref) async {
  final draft = _ClientDraft();
  var formError = '';

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => _shell(
        title: 'New client',
        confirmLabel: 'Create',
        width: 480,
        onCancel: () => Navigator.pop(ctx, false),
        onConfirm: () {
          if (draft.name.text.trim().isEmpty) {
            setLocal(() => formError = 'A client needs a name.');
            return;
          }
          Navigator.pop(ctx, true);
        },
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _clientDraftFields(draft, setLocal),
            if (formError.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                formError,
                style: const TextStyle(color: _Crm.red, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    ),
  );
  if (ok != true) return;
  try {
    await ref
        .read(crmServiceProvider)
        .upsertClient(
          fullName: draft.name.text,
          email: draft.email.text,
          phone: draft.phone.text,
          whatsapp: draft.whatsapp.text,
          customerType: draft.customerType,
          relationshipStatus: draft.relationship,
          budgetMin: draft.money(draft.budgetMin),
          budgetMax: draft.money(draft.budgetMax),
          preferredLocations: draft.locationList,
          company: draft.company.text,
          occupation: draft.occupation.text,
        );
    await ref
        .read(crmControllerProvider.notifier)
        .afterMutation('Client created');
  } catch (e) {
    ref.read(crmControllerProvider.notifier).setMessage('Failed: $e');
  }
}

Future<void> _showEditClient(
  BuildContext context,
  WidgetRef ref,
  CrmClient existing,
) async {
  final draft = _ClientDraft(existing);
  var formError = '';

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => _shell(
        title: 'Edit client',
        width: 480,
        onCancel: () => Navigator.pop(ctx, false),
        onConfirm: () {
          if (draft.name.text.trim().isEmpty) {
            setLocal(() => formError = 'A client needs a name.');
            return;
          }
          Navigator.pop(ctx, true);
        },
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _clientDraftFields(draft, setLocal),
            if (formError.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                formError,
                style: const TextStyle(color: _Crm.red, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    ),
  );
  if (ok != true) return;
  try {
    await ref
        .read(crmServiceProvider)
        .upsertClient(
          id: existing.id,
          fullName: draft.name.text,
          email: draft.email.text,
          phone: draft.phone.text,
          whatsapp: draft.whatsapp.text,
          customerType: draft.customerType,
          relationshipStatus: draft.relationship,
          budgetMin: draft.money(draft.budgetMin),
          budgetMax: draft.money(draft.budgetMax),
          preferredLocations: draft.locationList,
          company: draft.company.text,
          occupation: draft.occupation.text,
        );
    await ref
        .read(crmControllerProvider.notifier)
        .afterMutation('Client updated');
  } catch (e) {
    ref.read(crmControllerProvider.notifier).setMessage('Failed: $e');
  }
}

Future<void> _showCreateLead(
  BuildContext context,
  WidgetRef ref,
  CrmCommandCenterSnapshot snap,
) async {
  if (snap.clients.isEmpty) {
    ref
        .read(crmControllerProvider.notifier)
        .setMessage('Create a client first, then add a lead.');
    return;
  }
  final stages = [...snap.stages]
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  var clientId = snap.clients.first.id;
  String? stageId = stages.isEmpty ? null : stages.first.id;
  var priority = 'medium';
  final title = TextEditingController(text: 'New opportunity');
  final value = TextEditingController();
  final notes = TextEditingController();

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => _shell(
        title: 'Add lead',
        confirmLabel: 'Create',
        width: 470,
        onCancel: () => Navigator.pop(ctx, false),
        onConfirm: () => Navigator.pop(ctx, true),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: clientId,
              dropdownColor: _Crm.elevated,
              style: const TextStyle(color: Colors.white),
              decoration: _Crm.field('Client'),
              items: [
                for (final c in snap.clients)
                  DropdownMenuItem(value: c.id, child: Text(c.fullName)),
              ],
              onChanged: (v) => setLocal(() => clientId = v ?? clientId),
            ),
            const SizedBox(height: 10),
            _dialogField(title, 'Title'),
            const SizedBox(height: 10),
            if (stages.isNotEmpty) ...[
              DropdownButtonFormField<String>(
                initialValue: stageId,
                dropdownColor: _Crm.elevated,
                style: const TextStyle(color: Colors.white),
                decoration: _Crm.field('Stage'),
                items: [
                  for (final s in stages)
                    DropdownMenuItem(value: s.id, child: Text(s.name)),
                ],
                onChanged: (v) => setLocal(() => stageId = v),
              ),
              const SizedBox(height: 10),
            ],
            DropdownButtonFormField<String>(
              initialValue: priority,
              dropdownColor: _Crm.elevated,
              style: const TextStyle(color: Colors.white),
              decoration: _Crm.field('Priority'),
              items: const [
                DropdownMenuItem(value: 'low', child: Text('Low')),
                DropdownMenuItem(value: 'medium', child: Text('Medium')),
                DropdownMenuItem(value: 'high', child: Text('High')),
                DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
              ],
              onChanged: (v) => setLocal(() => priority = v ?? priority),
            ),
            const SizedBox(height: 10),
            _dialogField(
              value,
              'Estimated value (₦)',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            _dialogField(notes, 'Notes', maxLines: 3),
          ],
        ),
      ),
    ),
  );
  if (ok != true || title.text.trim().isEmpty) return;
  try {
    await ref
        .read(crmServiceProvider)
        .createLead(
          clientId: clientId,
          title: title.text,
          stageId: stageId,
          priority: priority,
          estimatedValue: double.tryParse(value.text.trim()),
          notes: notes.text,
        );
    await ref
        .read(crmControllerProvider.notifier)
        .afterMutation('Lead created');
  } catch (e) {
    ref.read(crmControllerProvider.notifier).setMessage('Failed: $e');
  }
}

Future<void> _showEditLead(
  BuildContext context,
  WidgetRef ref,
  CrmLead lead,
) async {
  final title = TextEditingController(text: lead.title);
  final value = TextEditingController(
    text: lead.estimatedValue?.toStringAsFixed(0) ?? '',
  );
  final notes = TextEditingController(text: lead.notes ?? '');
  var priority = lead.priority.slug;
  var status = lead.status.slug;

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => _shell(
        title: 'Edit lead',
        onCancel: () => Navigator.pop(ctx, false),
        onConfirm: () => Navigator.pop(ctx, true),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogField(title, 'Title'),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: priority,
              dropdownColor: _Crm.elevated,
              style: const TextStyle(color: Colors.white),
              decoration: _Crm.field('Priority'),
              items: const [
                DropdownMenuItem(value: 'low', child: Text('Low')),
                DropdownMenuItem(value: 'medium', child: Text('Medium')),
                DropdownMenuItem(value: 'high', child: Text('High')),
                DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
              ],
              onChanged: (v) => setLocal(() => priority = v ?? priority),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: status,
              dropdownColor: _Crm.elevated,
              style: const TextStyle(color: Colors.white),
              decoration: _Crm.field('Status'),
              items: const [
                DropdownMenuItem(value: 'open', child: Text('Open')),
                DropdownMenuItem(value: 'qualified', child: Text('Qualified')),
                DropdownMenuItem(value: 'nurture', child: Text('Nurture')),
                DropdownMenuItem(value: 'won', child: Text('Won')),
                DropdownMenuItem(value: 'lost', child: Text('Lost')),
              ],
              onChanged: (v) => setLocal(() => status = v ?? status),
            ),
            const SizedBox(height: 10),
            _dialogField(
              value,
              'Estimated value (₦)',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            _dialogField(notes, 'Notes', maxLines: 3),
          ],
        ),
      ),
    ),
  );
  if (ok != true) return;
  try {
    await ref
        .read(crmServiceProvider)
        .updateLead(
          leadId: lead.id,
          title: title.text,
          priority: priority,
          status: status,
          estimatedValue: double.tryParse(value.text.trim()),
          notes: notes.text,
        );
    await ref
        .read(crmControllerProvider.notifier)
        .afterMutation('Lead updated');
  } catch (e) {
    ref.read(crmControllerProvider.notifier).setMessage('Failed: $e');
  }
}

Future<void> _showCreateTask(
  BuildContext context,
  WidgetRef ref,
  CrmCommandCenterSnapshot snap, {
  String? clientId,
  String? leadId,
}) async {
  if (snap.clients.isEmpty) {
    ref
        .read(crmControllerProvider.notifier)
        .setMessage('Create a client first.');
    return;
  }
  var selectedClient = clientId ?? snap.clients.first.id;
  if (!snap.clients.any((c) => c.id == selectedClient)) {
    selectedClient = snap.clients.first.id;
  }
  final title = TextEditingController();
  final notes = TextEditingController();
  var type = 'follow_up';
  var priority = 'medium';
  var due = DateTime.now().add(const Duration(days: 1));
  var formError = '';

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => _shell(
        title: 'Add task',
        confirmLabel: 'Create',
        onCancel: () => Navigator.pop(ctx, false),
        onConfirm: () {
          if (title.text.trim().isEmpty) {
            setLocal(
              () => formError =
                  'Give the task a title so the team knows what to do.',
            );
            return;
          }
          Navigator.pop(ctx, true);
        },
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: selectedClient,
              dropdownColor: _Crm.elevated,
              style: const TextStyle(color: Colors.white),
              decoration: _Crm.field('Client'),
              items: [
                for (final c in snap.clients)
                  DropdownMenuItem(value: c.id, child: Text(c.fullName)),
              ],
              onChanged: (v) =>
                  setLocal(() => selectedClient = v ?? selectedClient),
            ),
            const SizedBox(height: 10),
            _dialogField(title, 'What needs to happen'),
            const SizedBox(height: 10),
            _dialogField(notes, 'Notes for the team', maxLines: 2),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: type,
              dropdownColor: _Crm.elevated,
              style: const TextStyle(color: Colors.white),
              decoration: _Crm.field('Type'),
              items: const [
                DropdownMenuItem(value: 'call', child: Text('Call')),
                DropdownMenuItem(value: 'meeting', child: Text('Meeting')),
                DropdownMenuItem(
                  value: 'site_visit',
                  child: Text('Site visit'),
                ),
                DropdownMenuItem(value: 'email', child: Text('Email')),
                DropdownMenuItem(value: 'follow_up', child: Text('Follow-up')),
                DropdownMenuItem(value: 'reminder', child: Text('Reminder')),
                DropdownMenuItem(
                  value: 'internal_note',
                  child: Text('Internal note'),
                ),
              ],
              onChanged: (v) => setLocal(() => type = v ?? type),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: priority,
              dropdownColor: _Crm.elevated,
              style: const TextStyle(color: Colors.white),
              decoration: _Crm.field('Priority'),
              items: const [
                DropdownMenuItem(value: 'low', child: Text('Low')),
                DropdownMenuItem(value: 'medium', child: Text('Medium')),
                DropdownMenuItem(value: 'high', child: Text('High')),
                DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
              ],
              onChanged: (v) => setLocal(() => priority = v ?? priority),
            ),
            const SizedBox(height: 6),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Due', style: TextStyle(color: _Crm.muted)),
              subtitle: Text(
                DateFormat.yMMMd().add_jm().format(due),
                style: const TextStyle(color: Colors.white),
              ),
              trailing: const Icon(LucideIcons.calendar, color: _Crm.gold),
              onTap: () async {
                final d = await showDatePicker(
                  context: ctx,
                  initialDate: due,
                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (d == null || !ctx.mounted) return;
                final t = await showTimePicker(
                  context: ctx,
                  initialTime: TimeOfDay.fromDateTime(due),
                );
                setLocal(() {
                  due = DateTime(
                    d.year,
                    d.month,
                    d.day,
                    t?.hour ?? due.hour,
                    t?.minute ?? due.minute,
                  );
                });
              },
            ),
            if (formError.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                formError,
                style: const TextStyle(color: _Crm.red, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    ),
  );
  if (ok != true) return;
  if (title.text.trim().isEmpty) {
    ref
        .read(crmControllerProvider.notifier)
        .setMessage('Give the task a title so the team knows what to do.');
    return;
  }
  try {
    await ref
        .read(crmServiceProvider)
        .createTask(
          clientId: selectedClient,
          leadId: leadId,
          title: title.text,
          notes: notes.text,
          taskType: type,
          priority: priority,
          dueAt: due,
        );
    await ref
        .read(crmControllerProvider.notifier)
        .afterMutation('Task created');
  } catch (e) {
    ref.read(crmControllerProvider.notifier).setMessage('Failed: $e');
  }
}

Future<void> _showCreateAppointment(
  BuildContext context,
  WidgetRef ref,
  CrmCommandCenterSnapshot snap,
) async {
  if (snap.clients.isEmpty) {
    ref
        .read(crmControllerProvider.notifier)
        .setMessage('Create a client first.');
    return;
  }
  var selectedClient = snap.clients.first.id;
  var appointmentType = 'meeting';
  final title = TextEditingController(text: 'Site meeting');
  final location = TextEditingController();
  var when = DateTime.now().add(const Duration(days: 1, hours: 2));

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => _shell(
        title: 'Schedule appointment',
        confirmLabel: 'Schedule',
        onCancel: () => Navigator.pop(ctx, false),
        onConfirm: () => Navigator.pop(ctx, true),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: selectedClient,
              dropdownColor: _Crm.elevated,
              style: const TextStyle(color: Colors.white),
              decoration: _Crm.field('Client'),
              items: [
                for (final c in snap.clients)
                  DropdownMenuItem(value: c.id, child: Text(c.fullName)),
              ],
              onChanged: (v) =>
                  setLocal(() => selectedClient = v ?? selectedClient),
            ),
            const SizedBox(height: 10),
            _dialogField(title, 'Title'),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: appointmentType,
              dropdownColor: _Crm.elevated,
              style: const TextStyle(color: Colors.white),
              decoration: _Crm.field('Type'),
              items: const [
                DropdownMenuItem(value: 'meeting', child: Text('Meeting')),
                DropdownMenuItem(
                  value: 'site_visit',
                  child: Text('Site visit'),
                ),
                DropdownMenuItem(value: 'call', child: Text('Call')),
                DropdownMenuItem(
                  value: 'consultation',
                  child: Text('Consultation'),
                ),
              ],
              onChanged: (v) =>
                  setLocal(() => appointmentType = v ?? appointmentType),
            ),
            const SizedBox(height: 10),
            _dialogField(location, 'Location'),
            const SizedBox(height: 6),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('When', style: TextStyle(color: _Crm.muted)),
              subtitle: Text(
                DateFormat.yMMMd().add_jm().format(when),
                style: const TextStyle(color: Colors.white),
              ),
              trailing: IconButton(
                icon: const Icon(LucideIcons.calendar, color: _Crm.gold),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: when,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (d == null || !ctx.mounted) return;
                  final t = await showTimePicker(
                    context: ctx,
                    initialTime: TimeOfDay.fromDateTime(when),
                  );
                  setLocal(() {
                    when = DateTime(
                      d.year,
                      d.month,
                      d.day,
                      t?.hour ?? when.hour,
                      t?.minute ?? when.minute,
                    );
                  });
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
  if (ok != true || title.text.trim().isEmpty) return;
  try {
    await ref
        .read(crmServiceProvider)
        .createAppointment(
          clientId: selectedClient,
          title: title.text,
          scheduledAt: when,
          appointmentType: appointmentType,
          location: location.text,
        );
    await ref
        .read(crmControllerProvider.notifier)
        .afterMutation('Appointment scheduled');
  } catch (e) {
    ref.read(crmControllerProvider.notifier).setMessage('Failed: $e');
  }
}

Future<void> _showAddNote(
  BuildContext context,
  WidgetRef ref,
  CrmClient client,
) async {
  final body = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => _shell(
      title: 'Note · ${client.fullName}',
      onCancel: () => Navigator.pop(ctx, false),
      onConfirm: () => Navigator.pop(ctx, true),
      content: _dialogField(body, 'Note', maxLines: 5),
    ),
  );
  if (ok != true || body.text.trim().isEmpty) return;
  try {
    await ref
        .read(crmServiceProvider)
        .addNote(clientId: client.id, body: body.text);
    await ref.read(crmControllerProvider.notifier).afterMutation('Note saved');
  } catch (e) {
    ref.read(crmControllerProvider.notifier).setMessage('Failed: $e');
  }
}
