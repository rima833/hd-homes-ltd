import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/client_ops/domain/entities/client_ops_models.dart';
import 'package:hdhomesproject/features/client_ops/presentation/providers/client_ops_controller.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Client Command Center — Sales-style scrollable workspace (no Column overflow).
class ClientCommandCenterPage extends ConsumerWidget {
  const ClientCommandCenterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configured = ref.watch(supabaseConfiguredProvider);
    ref.watch(clientOpsRealtimeProvider);
    final realtimeConnected = ref.watch(clientOpsRealtimeConnectedProvider);
    final ui = ref.watch(clientOpsControllerProvider);
    final controller = ref.read(clientOpsControllerProvider.notifier);
    final kpisAsync = ref.watch(clientOpsDeskKpisProvider);
    final queuesAsync = ref.watch(clientOpsWorkQueuesProvider);

    if (!configured) {
      return const Scaffold(
        body: Center(child: Text('Connect Supabase to load client operations.')),
      );
    }

    return Scaffold(
      body: kpisAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  userFacingError(
                    e,
                    fallback: 'Unable to load Client Command Center.',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: controller.refresh,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (deskKpis) {
          final queues = queuesAsync.asData?.value;
          final ticker = deskKpis.unassigned > 0
              ? 'Unassigned: ${deskKpis.unassigned} · Pipeline: ${deskKpis.openLeads} · Payments: ${deskKpis.pendingPayments}'
              : 'Clients: ${deskKpis.totalClients} · Buyers: ${deskKpis.activeBuyers} · Portal linked: ${deskKpis.portalLinked}';

          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: CustomScrollView(
              slivers: [
                _Contained(
                  child: _Header(
                    ticker: ticker,
                    live: realtimeConnected,
                    message: ui.message,
                    error: ui.error,
                    onDismissMessage: controller.dismissMessage,
                    onRefresh: controller.refresh,
                    onOpenCrm: () => context.go(RoutePaths.dashboardCrm),
                    onOpenApplications: () =>
                        context.go(RoutePaths.dashboardClientApplications),
                  ),
                ),
                _Contained(
                  child: _KpiGrid(
                    desk: deskKpis,
                    onTap: (label) => _onKpiTap(controller, context, label),
                  ),
                ),
                _Contained(
                  child: _TabBar(
                    selected: ui.selectedTab,
                    onSelect: controller.setTab,
                    queues: queues,
                    totalClients: deskKpis.totalClients,
                  ),
                ),
                if (ui.selectedTab == ClientOpsTab.directory)
                  _Contained(
                    child: _DirectoryFilters(ui: ui, controller: controller),
                  ),
                ..._tabSlivers(context, ref, ui, controller, queues),
                const _Contained(child: SizedBox(height: 40)),
              ],
            ),
          );
        },
      ),
    );
  }

  void _onKpiTap(
    ClientOpsController controller,
    BuildContext context,
    String label,
  ) {
    switch (label) {
      case 'Unassigned':
        controller.setPortalOnly(false);
        controller.setUnassignedOnly(true);
        controller.setTab(ClientOpsTab.directory);
      case 'Leads':
        controller.setPortalOnly(false);
        controller.setRelationshipStatus('lead');
        controller.setTab(ClientOpsTab.directory);
      case 'Active Buyers':
        controller.setPortalOnly(false);
        controller.setRelationshipStatus('active_buyer');
        controller.setTab(ClientOpsTab.directory);
      case 'Portal Linked':
        controller.setUnassignedOnly(false);
        controller.setRelationshipStatus(null);
        controller.setPortalOnly(true);
        controller.setTab(ClientOpsTab.directory);
      case 'Total Clients':
        controller.setPortalOnly(false);
        controller.setUnassignedOnly(false);
        controller.setRelationshipStatus(null);
        controller.setTab(ClientOpsTab.directory);
      case 'Applications':
        context.go(RoutePaths.dashboardClientApplications);
      case 'Pending Payments':
      case 'Overdue Tasks':
      case 'Open Pipeline':
        controller.setTab(ClientOpsTab.queues);
      default:
        controller.setTab(ClientOpsTab.directory);
    }
  }

  List<Widget> _tabSlivers(
    BuildContext context,
    WidgetRef ref,
    ClientOpsUiState ui,
    ClientOpsController controller,
    ClientOpsWorkQueues? queues,
  ) {
    switch (ui.selectedTab) {
      case ClientOpsTab.overview:
        return [
          _Contained(
            child: _SectionCard(
              title: 'Needs attention',
              icon: LucideIcons.bell,
              child: _AttentionBoard(
                queues: queues,
                onOpenClient: controller.openClient360,
                onSeeQueues: () => controller.setTab(ClientOpsTab.queues),
                onSeeUnassigned: () {
                  controller.setUnassignedOnly(true);
                  controller.setTab(ClientOpsTab.directory);
                },
                onSeeApplications: () =>
                    context.go(RoutePaths.dashboardClientApplications),
              ),
            ),
          ),
          _Contained(
            child: _SectionCard(
              title: 'Recent clients',
              icon: LucideIcons.users,
              action: TextButton(
                onPressed: () => controller.setTab(ClientOpsTab.directory),
                child: const Text('Directory'),
              ),
              child: _RecentClients(controller: controller),
            ),
          ),
        ];
      case ClientOpsTab.directory:
        return [
          _Contained(
            child: _SectionCard(
              title: 'Client directory',
              icon: LucideIcons.contact,
              child: _DirectoryList(ui: ui, controller: controller),
            ),
          ),
        ];
      case ClientOpsTab.queues:
        return [
          _Contained(
            child: _SectionCard(
              title: 'Work queues',
              icon: LucideIcons.listChecks,
              child: _QueuesBoard(
                queues: queues,
                onOpenClient: controller.openClient360,
                onCompleteTask: controller.completeTask,
              ),
            ),
          ),
        ];
      case ClientOpsTab.detail:
        if (ui.selectedClientId == null) {
          return [
            _Contained(
              child: _SectionCard(
                title: 'Client 360',
                icon: LucideIcons.scanFace,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select a client from Directory or Work Queues.',
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton(
                          onPressed: () =>
                              controller.setTab(ClientOpsTab.directory),
                          child: const Text('Open Directory'),
                        ),
                        OutlinedButton(
                          onPressed: () =>
                              controller.setTab(ClientOpsTab.queues),
                          child: const Text('Work Queues'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ];
        }
        return [
          _Contained(
            child: _Client360Body(
              clientId: ui.selectedClientId!,
              controller: controller,
            ),
          ),
        ];
    }
  }
}

class _DeskLivePill extends StatelessWidget {
  const _DeskLivePill({required this.live});

  final bool live;

  @override
  Widget build(BuildContext context) {
    return Text(
      live
          ? 'Your latest records are here.'
          : "We're gathering the latest records.",
      style: const TextStyle(
        color: Color(0xFF9AA3B2),
        fontSize: 12,
        height: 1.35,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _Contained extends StatelessWidget {
  const _Contained({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(child: child);
}

class _Header extends StatelessWidget {
  const _Header({
    required this.ticker,
    required this.live,
    required this.onRefresh,
    required this.onOpenCrm,
    required this.onOpenApplications,
    this.message,
    this.error,
    this.onDismissMessage,
  });

  final String ticker;
  final bool live;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpenCrm;
  final VoidCallback onOpenApplications;
  final String? message;
  final String? error;
  final VoidCallback? onDismissMessage;

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
              final narrow = constraints.maxWidth < 720;
              final title = Text(
                'Client Command Center',
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
                    onPressed: onOpenCrm,
                    icon: const Icon(LucideIcons.columns, size: 16),
                    label: const Text('Open CRM'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.deepBlack,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: onOpenApplications,
                    icon: const Icon(LucideIcons.fileCheck, size: 16),
                    label: const Text('Applications'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.goldLight,
                      side: BorderSide(
                        color: AppColors.gold.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: () => onRefresh(),
                    icon: Icon(
                      LucideIcons.rotateCcw,
                      color: live
                          ? const Color(0xFF35D89A)
                          : AppColors.white,
                    ),
                  ),
                  _DeskLivePill(live: live),
                ],
              );

              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    const SizedBox(height: 6),
                    Text(
                      'Ownership · pipeline · applications · payments',
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
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        title,
                        Text(
                          'Ownership · pipeline · applications · payments',
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
          if (message != null) ...[
            const SizedBox(height: 8),
            Material(
              color: AppColors.gold.withValues(alpha: 0.15),
              borderRadius: AppRadius.cardBorder,
              child: ListTile(
                dense: true,
                leading: const Icon(LucideIcons.info, color: AppColors.gold),
                title: Text(message!),
                trailing: onDismissMessage == null
                    ? null
                    : IconButton(
                        icon: const Icon(LucideIcons.x, size: 16),
                        onPressed: onDismissMessage,
                      ),
              ),
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 8),
            Material(
              color: Colors.red.withValues(alpha: 0.15),
              borderRadius: AppRadius.cardBorder,
              child: ListTile(
                dense: true,
                leading: const Icon(LucideIcons.alertCircle, color: Colors.red),
                title: Text(error!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.desk, required this.onTap});

  final ClientDeskKpis desk;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        'Total Clients',
        '${desk.totalClients}',
        'Everyone on the book',
        LucideIcons.users,
        const Color(0xFF35D89A),
      ),
      (
        'Active Buyers',
        '${desk.activeBuyers}',
        'Buying now',
        LucideIcons.userCheck,
        const Color(0xFF36A2FF),
      ),
      (
        'Leads',
        '${desk.leads}',
        'Still in relationship',
        LucideIcons.userPlus,
        const Color(0xFFA66BFF),
      ),
      (
        'Unassigned',
        '${desk.unassigned}',
        'No relationship owner',
        LucideIcons.userX,
        const Color(0xFFFF9E45),
      ),
      (
        'Portal Linked',
        '${desk.portalLinked}',
        'Can sign in',
        LucideIcons.link,
        const Color(0xFF35D5D0),
      ),
      (
        'Open Pipeline',
        '${desk.openLeads}',
        'Leads not closed',
        LucideIcons.gitBranch,
        const Color(0xFF45A7FF),
      ),
      (
        'Applications',
        '${desk.pendingApplications}',
        'Waiting on review',
        LucideIcons.fileCheck,
        const Color(0xFFE0AA36),
      ),
      (
        'Pending Payments',
        '${desk.pendingPayments}',
        'Not yet cleared',
        LucideIcons.wallet,
        const Color(0xFF9B55F5),
      ),
      (
        'Overdue Tasks',
        '${desk.overdueTasks}',
        'Past the due time',
        LucideIcons.alarmClock,
        const Color(0xFFFF6B6B),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final cross = width >= 1100
              ? 4
              : width >= 720
                  ? 3
                  : 2;
          final tileWidth = (width - (8 * (cross - 1))) / cross;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in items)
                SizedBox(
                  width: tileWidth,
                  height: 92,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onTap(item.$1),
                      borderRadius: BorderRadius.circular(12),
                      child: Ink(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: item.$5.withValues(alpha: 0.38),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF102039),
                              item.$5.withValues(alpha: 0.12),
                            ],
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(item.$4, size: 14, color: item.$5),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      item.$1,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFFC0CBDB),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    LucideIcons.arrowUpRight,
                                    size: 12,
                                    color: item.$5,
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Text(
                                item.$2,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  height: 1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.$3,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF74859C),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
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

class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.selected,
    required this.onSelect,
    required this.totalClients,
    this.queues,
  });

  final ClientOpsTab selected;
  final ValueChanged<ClientOpsTab> onSelect;
  final int totalClients;
  final ClientOpsWorkQueues? queues;

  @override
  Widget build(BuildContext context) {
    String label(ClientOpsTab tab) {
      switch (tab) {
        case ClientOpsTab.overview:
          return 'Overview';
        case ClientOpsTab.directory:
          return 'Directory ($totalClients)';
        case ClientOpsTab.queues:
          final n = (queues?.unassigned.length ?? 0) +
              (queues?.followUps.length ?? 0) +
              (queues?.tasks.length ?? 0) +
              (queues?.payments.length ?? 0);
          return n > 0 ? 'Work Queues ($n)' : 'Work Queues';
        case ClientOpsTab.detail:
          return 'Client 360';
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: ClientOpsTab.values.map((tab) {
            final isSelected = tab == selected;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(label(tab)),
                selected: isSelected,
                onSelected: (_) => onSelect(tab),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.action,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: AppRadius.cardBorder,
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
                  if (action != null) action!,
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

class _AttentionBoard extends StatelessWidget {
  const _AttentionBoard({
    required this.onOpenClient,
    required this.onSeeQueues,
    required this.onSeeUnassigned,
    required this.onSeeApplications,
    this.queues,
  });

  final ClientOpsWorkQueues? queues;
  final ValueChanged<String> onOpenClient;
  final VoidCallback onSeeQueues;
  final VoidCallback onSeeUnassigned;
  final VoidCallback onSeeApplications;

  @override
  Widget build(BuildContext context) {
    if (queues == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final rows = <(String, int, VoidCallback, List<ClientOpsQueueItem>)>[
      (
        'Unassigned',
        queues!.unassigned.length,
        onSeeUnassigned,
        queues!.unassigned,
      ),
      (
        'Follow-ups',
        queues!.followUps.length,
        onSeeQueues,
        queues!.followUps,
      ),
      (
        'Payments',
        queues!.payments.length,
        onSeeQueues,
        queues!.payments,
      ),
      (
        'Applications',
        queues!.applications.length,
        onSeeApplications,
        queues!.applications,
      ),
    ];

    return Column(
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final row in rows)
              ActionChip(
                avatar: CircleAvatar(
                  backgroundColor: AppColors.gold.withValues(alpha: 0.2),
                  child: Text(
                    '${row.$2}',
                    style: const TextStyle(fontSize: 11, color: AppColors.gold),
                  ),
                ),
                label: Text(row.$1),
                onPressed: row.$3,
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (queues!.unassigned.isEmpty &&
            queues!.followUps.isEmpty &&
            queues!.payments.isEmpty)
          const Text('All clear — no urgent items.')
        else
          ...[
            ...queues!.unassigned.take(3),
            ...queues!.followUps.take(2),
            ...queues!.payments.take(2),
          ].map(
            (item) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(item.title),
              subtitle: Text(
                [item.subtitle, item.status]
                    .whereType<String>()
                    .where((s) => s.isNotEmpty)
                    .join(' · '),
              ),
              trailing: item.clientId == null
                  ? null
                  : TextButton(
                      onPressed: () => onOpenClient(item.clientId!),
                      child: const Text('Open'),
                    ),
            ),
          ),
      ],
    );
  }
}

class _RecentClients extends ConsumerWidget {
  const _RecentClients({required this.controller});
  final ClientOpsController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(
      clientOpsDirectoryProvider((
        search: '',
        relationshipStatus: null,
        customerType: null,
        assignedStaffId: null,
        unassignedOnly: false,
        portalOnly: false,
        limit: 8,
        offset: 0,
      )),
    );

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text(
        userFacingError(e, fallback: 'Unable to load clients.'),
      ),
      data: (page) {
        if (page.items.isEmpty) {
          return const Text('No clients yet.');
        }
        return Column(
          children: [
            for (final c in page.items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: AppColors.gold.withValues(alpha: 0.15),
                  child: Text(
                    c.fullName.isNotEmpty ? c.fullName[0].toUpperCase() : '?',
                    style: const TextStyle(color: AppColors.gold),
                  ),
                ),
                title: Text(c.fullName),
                subtitle: Text(
                  [
                    c.clientCode,
                    c.email,
                    c.statusLabel,
                  ].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
                ),
                trailing: IconButton(
                  tooltip: 'Open 360',
                  icon: const Icon(LucideIcons.arrowUpRight, size: 18),
                  onPressed: () => controller.openClient360(c.id),
                ),
                onTap: () => controller.openClient360(c.id),
              ),
          ],
        );
      },
    );
  }
}

class _DirectoryFilters extends ConsumerWidget {
  const _DirectoryFilters({required this.ui, required this.controller});

  final ClientOpsUiState ui;
  final ClientOpsController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final managers =
        ref.watch(clientOpsManagersProvider).asData?.value ?? const [];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Search name, email, code…',
              prefixIcon: const Icon(LucideIcons.search, size: 18),
              isDense: true,
              border: OutlineInputBorder(borderRadius: AppRadius.cardBorder),
            ),
            onChanged: controller.setSearch,
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All statuses'),
                  selected: ui.relationshipStatus == null &&
                      !ui.unassignedOnly &&
                      !ui.portalOnly,
                  onSelected: (_) {
                    controller.setRelationshipStatus(null);
                    controller.setUnassignedOnly(false);
                    controller.setPortalOnly(false);
                  },
                ),
                const SizedBox(width: 6),
                FilterChip(
                  label: const Text('Leads'),
                  selected: ui.relationshipStatus == 'lead',
                  onSelected: (_) => controller.setRelationshipStatus('lead'),
                ),
                const SizedBox(width: 6),
                FilterChip(
                  label: const Text('Active buyers'),
                  selected: ui.relationshipStatus == 'active_buyer',
                  onSelected: (_) =>
                      controller.setRelationshipStatus('active_buyer'),
                ),
                const SizedBox(width: 6),
                FilterChip(
                  label: const Text('Unassigned'),
                  selected: ui.unassignedOnly,
                  onSelected: controller.setUnassignedOnly,
                ),
                const SizedBox(width: 6),
                FilterChip(
                  label: const Text('Portal linked'),
                  selected: ui.portalOnly,
                  onSelected: controller.setPortalOnly,
                ),
                if (managers.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  DropdownButton<String?>(
                    value: ui.assignedStaffId,
                    hint: const Text('Owner'),
                    underline: const SizedBox.shrink(),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All owners'),
                      ),
                      ...managers.map(
                        (m) => DropdownMenuItem(
                          value: m.id,
                          child: Text(m.name),
                        ),
                      ),
                    ],
                    onChanged: controller.setAssignedStaffId,
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

class _DirectoryList extends ConsumerWidget {
  const _DirectoryList({required this.ui, required this.controller});

  final ClientOpsUiState ui;
  final ClientOpsController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(clientOpsDirectoryProvider(ui.directoryQuery));

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text(
        userFacingError(e, fallback: 'Unable to load directory.'),
      ),
      data: (page) {
        if (page.items.isEmpty) {
          return const Text('No matching clients.');
        }
        return Column(
          children: [
            for (final c in page.items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: AppColors.gold.withValues(alpha: 0.15),
                  child: Text(
                    c.fullName.isNotEmpty ? c.fullName[0].toUpperCase() : '?',
                    style: const TextStyle(color: AppColors.gold),
                  ),
                ),
                title: Text(c.fullName),
                subtitle: Text(
                  [
                    c.clientCode,
                    c.email,
                    c.statusLabel,
                    c.assignedStaffName ?? 'Unassigned',
                    if (c.hasPortal) 'Portal',
                  ].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
                ),
                trailing: Wrap(
                  spacing: 0,
                  children: [
                    IconButton(
                      tooltip: 'Assign owner',
                      icon: const Icon(LucideIcons.userCog, size: 18),
                      onPressed: () =>
                          _assignOwner(context, ref, c, controller),
                    ),
                    IconButton(
                      tooltip: 'Open 360',
                      icon: const Icon(LucideIcons.arrowUpRight, size: 18),
                      onPressed: () => controller.openClient360(c.id),
                    ),
                  ],
                ),
                onTap: () => controller.openClient360(c.id),
              ),
            Row(
              children: [
                Text(
                  '${page.offset + 1}–${page.offset + page.items.length} of ${page.total}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                IconButton(
                  onPressed: page.offset > 0 ? controller.prevPage : null,
                  icon: const Icon(LucideIcons.chevronLeft),
                ),
                IconButton(
                  onPressed: page.hasMore
                      ? () => controller.nextPage(page.total)
                      : null,
                  icon: const Icon(LucideIcons.chevronRight),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _QueuesBoard extends StatelessWidget {
  const _QueuesBoard({
    required this.onOpenClient,
    this.onCompleteTask,
    this.queues,
  });

  final ClientOpsWorkQueues? queues;
  final ValueChanged<String> onOpenClient;
  final Future<void> Function(String taskId)? onCompleteTask;

  @override
  Widget build(BuildContext context) {
    if (queues == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final sections = <(String, List<ClientOpsQueueItem>, bool)>[
      ('Unassigned', queues!.unassigned, false),
      ('Follow-ups', queues!.followUps, false),
      ('Tasks', queues!.tasks, true),
      ('Applications', queues!.applications, false),
      ('Payments', queues!.payments, false),
      ('Stale', queues!.stale, false),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final section in sections) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              '${section.$1} (${section.$2.length})',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.gold,
                  ),
            ),
          ),
          if (section.$2.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Clear'),
            )
          else
            ...section.$2.map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(item.title),
                subtitle: Text(
                  [
                    item.subtitle,
                    item.status,
                    if (item.dueAt != null)
                      DateFormat.MMMd().add_jm().format(item.dueAt!.toLocal()),
                  ].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
                ),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    if (section.$3 &&
                        onCompleteTask != null &&
                        item.status != 'done')
                      TextButton(
                        onPressed: () => onCompleteTask!(item.id),
                        child: const Text('Done'),
                      ),
                    if (item.clientId != null)
                      TextButton(
                        onPressed: () => onOpenClient(item.clientId!),
                        child: const Text('Open'),
                      ),
                  ],
                ),
              ),
            ),
          const Divider(height: 16),
        ],
      ],
    );
  }
}

class _Client360Body extends ConsumerWidget {
  const _Client360Body({
    required this.clientId,
    required this.controller,
  });

  final String clientId;
  final ClientOpsController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(clientOpsDetailProvider(clientId));

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          userFacingError(e, fallback: 'Unable to load client 360.'),
        ),
      ),
      data: (detail) {
        final c = detail.client;
        return Column(
          children: [
            _SectionCard(
              title: c.fullName,
              icon: LucideIcons.user,
              action: Wrap(
                spacing: 4,
                children: [
                  TextButton.icon(
                    onPressed: () => context.go(RoutePaths.dashboardCrm),
                    icon: const Icon(LucideIcons.columns, size: 16),
                    label: const Text('CRM'),
                  ),
                  TextButton.icon(
                    onPressed: () => _assignOwner(context, ref, c, controller),
                    icon: const Icon(LucideIcons.userCog, size: 16),
                    label: const Text('Assign'),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    [
                      c.clientCode,
                      c.statusLabel,
                      c.assignedStaffName ?? 'Unassigned',
                      if (c.hasPortal) 'Portal linked',
                    ].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _meta(context, 'Email', c.email ?? '—'),
                      _meta(context, 'Phone', c.phone ?? '—'),
                      _meta(context, 'WhatsApp', c.whatsapp ?? '—'),
                      _meta(context, 'Company', c.company ?? '—'),
                    ],
                  ),
                  if (detail.aiSummary != null &&
                      detail.aiSummary!.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(detail.aiSummary!),
                  ],
                ],
              ),
            ),
            _SectionCard(
              title: 'Leads (${detail.leads.length})',
              icon: LucideIcons.sparkles,
              child: detail.leads.isEmpty
                  ? const Text('No leads')
                  : Column(
                      children: [
                        for (final l in detail.leads)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(l.title),
                            subtitle: Text(l.status),
                          ),
                      ],
                    ),
            ),
            _SectionCard(
              title: 'Tasks (${detail.tasks.length})',
              icon: LucideIcons.checkSquare,
              child: detail.tasks.isEmpty
                  ? const Text('No tasks')
                  : Column(
                      children: [
                        for (final t in detail.tasks)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(t.title),
                            subtitle: Text(
                              [
                                t.status,
                                if (t.dueAt != null)
                                  DateFormat.yMMMd()
                                      .format(t.dueAt!.toLocal()),
                              ].whereType<String>().join(' · '),
                            ),
                            trailing: t.status == 'done'
                                ? const Text('Done')
                                : TextButton(
                                    onPressed: () =>
                                        controller.completeTask(t.id),
                                    child: const Text('Mark done'),
                                  ),
                          ),
                      ],
                    ),
            ),
            _SectionCard(
              title: 'Applications (${detail.applications.length})',
              icon: LucideIcons.fileText,
              child: detail.applications.isEmpty
                  ? const Text('No applications')
                  : Column(
                      children: [
                        for (final a in detail.applications)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(a.status),
                            subtitle: Text(
                              [
                                a.paymentPlan,
                                if (a.amountOffered != null)
                                  NumberFormat.currency(
                                    symbol: '₦',
                                    decimalDigits: 0,
                                  ).format(a.amountOffered),
                              ]
                                  .whereType<String>()
                                  .where((s) => s.isNotEmpty)
                                  .join(' · '),
                            ),
                          ),
                      ],
                    ),
            ),
            _SectionCard(
              title: 'Payments (${detail.payments.length})',
              icon: LucideIcons.wallet,
              child: detail.payments.isEmpty
                  ? const Text('No payments')
                  : Column(
                      children: [
                        for (final p in detail.payments)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(p.status),
                            subtitle: Text(
                              [
                                p.reference,
                                if (p.amount != null)
                                  NumberFormat.currency(
                                    symbol: '${p.currency ?? 'NGN'} ',
                                    decimalDigits: 0,
                                  ).format(p.amount),
                              ]
                                  .whereType<String>()
                                  .where((s) => s.isNotEmpty)
                                  .join(' · '),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _meta(BuildContext context, String label, String value) {
    return SizedBox(
      width: 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(value),
        ],
      ),
    );
  }
}

Future<void> _assignOwner(
  BuildContext context,
  WidgetRef ref,
  ClientOpsRow client,
  ClientOpsController controller,
) async {
  final managers = await ref
      .read(clientOpsManagersProvider.future)
      .catchError((_) => const <ClientOpsStaffOption>[]);
  if (!context.mounted) return;
  if (managers.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No staff managers available')),
    );
    return;
  }

  String? selected = client.assignedStaffId ?? managers.first.id;
  final picked = await showDialog<String>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: const Text('Assign relationship owner'),
            content: DropdownButtonFormField<String>(
              initialValue: selected,
              items: managers
                  .map(
                    (m) => DropdownMenuItem(value: m.id, child: Text(m.name)),
                  )
                  .toList(),
              onChanged: (v) => setState(() => selected = v),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed:
                    selected == null ? null : () => Navigator.pop(ctx, selected),
                child: const Text('Assign'),
              ),
            ],
          );
        },
      );
    },
  );

  if (picked == null || picked.isEmpty) return;
  await controller.assignOwner(clientId: client.id, staffId: picked);
}
