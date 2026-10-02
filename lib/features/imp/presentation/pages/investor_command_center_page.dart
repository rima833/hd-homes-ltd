import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/permissions.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/admin/presentation/widgets/admin_desk_shell.dart';
import 'package:hdhomesproject/features/authentication/domain/services/organization_service.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/organization_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/widgets/permission_gate.dart';
import 'package:hdhomesproject/features/imp/domain/entities/imp_models.dart';
import 'package:hdhomesproject/features/imp/domain/services/imp_service.dart';
import 'package:hdhomesproject/features/imp/presentation/pages/investor_admin_dialogs.dart';
import 'package:hdhomesproject/features/imp/presentation/providers/imp_controller.dart';
import 'package:hdhomesproject/features/imp/presentation/widgets/imp_compliance_docs_panels.dart';
import 'package:hdhomesproject/features/imp/presentation/widgets/imp_construction_support_panels.dart';
import 'package:hdhomesproject/features/imp/presentation/widgets/imp_investor_directory_panel.dart';
import 'package:hdhomesproject/features/imp/presentation/widgets/imp_notifications_desk_panel.dart';
import 'package:hdhomesproject/features/imp/presentation/widgets/imp_ops_overview.dart';
import 'package:hdhomesproject/features/imp/presentation/widgets/imp_reports_activity_panels.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Volume 4 Part 4 — Investor Command Center™ admin workspace.
class InvestorCommandCenterPage extends ConsumerWidget {
  const InvestorCommandCenterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSnap = ref.watch(impSnapshotProvider);
    ref.watch(impRealtimeProvider);
    final realtimeConfigured = ref.watch(supabaseConfiguredProvider);
    final realtimeConnected = ref.watch(impRealtimeConnectedProvider);
    final ui = ref.watch(impControllerProvider);
    final controller = ref.read(impControllerProvider.notifier);

    return Scaffold(
      body: asyncSnap.when(
        loading: () => AdminDeskPage(
          overline: 'Investor operations',
          title: 'Investor Command Center',
          subtitle: 'Loading the live investor workspace',
          tabs: const [],
          selectedTab: 0,
          onTabSelected: (_) {},
          body: const SizedBox.shrink(),
          isLoading: true,
        ),
        error: (e, _) => AdminDeskPage(
          overline: 'Investor operations',
          title: 'Investor Command Center',
          subtitle: 'Manage investor relationships and capital operations',
          tabs: const [],
          selectedTab: 0,
          onTabSelected: (_) {},
          body: const SizedBox.shrink(),
          error: userFacingError(
            e,
            fallback: 'Unable to load the investor workspace.',
          ),
          onRefresh: controller.refresh,
        ),
        data: (snap) {
          final deskKpisAsync = ref.watch(impDeskKpisProvider);
          final deskKpis = deskKpisAsync.asData?.value;
          final tickerKpis = deskKpis?.toKpiCards() ?? snap.kpis;
          final ticker = !snap.fromRemote
              ? "We're gathering investor records."
              : tickerKpis.isEmpty
              ? 'Manage investor relationships, investments, portfolio performance, distributions, compliance and communications in real time.'
              : '${tickerKpis[ui.tickerIndex % tickerKpis.length].label}: '
                    '${tickerKpis[ui.tickerIndex % tickerKpis.length].displayValue}';

          final tabs = ImpCommandTab.values
              .map((tab) => AdminDeskTab(label: tab.label, icon: _tabIcon(tab)))
              .toList();
          final kpiCards = deskKpisAsync.when(
            data: (kpis) => kpis
                .toKpiCards()
                .map(
                  (kpi) => AdminDeskKpi(
                    label: kpi.label,
                    value: kpi.displayValue,
                    subtitle: _kpiSubtitle(kpi.label),
                    icon: _kpiIcon(kpi.label),
                    accent: kpi.label == 'Overdue Actions' && kpi.value > 0
                        ? AdminDeskColors.red
                        : null,
                    onTap: () => _openKpi(controller, kpi.label),
                  ),
                )
                .toList(),
            loading: () => const <AdminDeskKpi>[],
            error: (_, _) => snap.kpis
                .map(
                  (kpi) => AdminDeskKpi(
                    label: kpi.label,
                    value: kpi.displayValue,
                    subtitle: _kpiSubtitle(kpi.label),
                    icon: _kpiIcon(kpi.label),
                    onTap: () => _openKpi(controller, kpi.label),
                  ),
                )
                .toList(),
          );
          return AdminDeskPage(
            overline: 'Investor operations',
            title: 'Investor Command Center',
            subtitle: ticker,
            tabs: tabs,
            selectedTab: ui.selectedTab.index,
            onTabSelected: (index) =>
                controller.setTab(ImpCommandTab.values[index]),
            live: realtimeConnected || snap.fromRemote,
            fromRemote: snap.fromRemote,
            liveLabel: !realtimeConfigured
                ? "We'll refresh this when the connection is back."
                : realtimeConnected
                ? 'Your latest records are here.'
                : "We're gathering the latest records.",
            remoteLabel: snap.fromRemote
                ? 'Your latest records are here.'
                : "We'll refresh this when the connection is back.",
            onRefresh: controller.refresh,
            message: ui.lastMessage,
            onDismissMessage: controller.clearMessage,
            kpis: kpiCards,
            body: RefreshIndicator(
              onRefresh: controller.refresh,
              child: ListView(
                primary: true,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 96),
                children: [
                  if (snap.fromRemote &&
                      ui.selectedTab == ImpCommandTab.investors)
                    ContainedPadding(
                      child: _SearchAndFilters(
                        ui: ui,
                        managers: ref
                            .watch(impInvestorManagersProvider)
                            .asData
                            ?.value,
                        onSearch: controller.setSearch,
                        onType: controller.setTypeFilter,
                        onLifecycle: controller.setLifecycleFilter,
                        onKyc: controller.setKycFilter,
                        onAssignedStaff: controller.setAssignedStaffFilter,
                      ),
                    ),
                  if (!snap.fromRemote)
                    const ContainedPadding(
                      child: _SectionCard(
                        title: 'Nothing to show yet',
                        icon: LucideIcons.cloudOff,
                        child: _EmptyState(
                          icon: LucideIcons.database,
                          message:
                              'Investor records will show here once they are available.',
                        ),
                      ),
                    )
                  else
                    ..._tabSlivers(context, ref, snap, ui, controller),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openKpi(ImpController controller, String label) {
    switch (label) {
      case 'Total Investors':
        controller.setLifecycleFilter(null);
        controller.setKycFilter(null);
        controller.setTab(ImpCommandTab.investors);
      case 'Active Investors':
        controller.setKycFilter(null);
        controller.setLifecycleFilter(null);
        controller.setTab(ImpCommandTab.investors);
      case 'Total AUM':
      case 'AUM':
      case 'Capital Raised':
        controller.openInvestments();
      case 'Upcoming Distributions':
      case 'Upcoming Payouts':
        controller.setCapitalSegment(ImpCapitalSegment.distributions);
      case 'Open Opportunities':
        controller.openOpportunities();
      case 'Pending Payments':
        controller.openPayments();
      case 'KYC Pending':
        controller.openKyc();
      case 'Overdue Actions':
        controller.openAlerts();
      default:
        controller.setTab(ImpCommandTab.overview);
    }
  }

  IconData _tabIcon(ImpCommandTab tab) => switch (tab) {
    ImpCommandTab.overview => LucideIcons.layoutDashboard,
    ImpCommandTab.investors => LucideIcons.users,
    ImpCommandTab.capital => LucideIcons.landmark,
    ImpCommandTab.payments => LucideIcons.wallet,
    ImpCommandTab.compliance => LucideIcons.shieldCheck,
    ImpCommandTab.support => LucideIcons.headphones,
    ImpCommandTab.insights => LucideIcons.activity,
    ImpCommandTab.investor360 => LucideIcons.userCircle,
  };

  IconData _kpiIcon(String label) {
    if (label == 'Total Investors') return LucideIcons.users;
    if (label == 'Active Investors') return LucideIcons.userCheck;
    if (label == 'Total AUM' || label == 'AUM') return LucideIcons.walletCards;
    if (label == 'Capital Raised') return LucideIcons.trendingUp;
    if (label == 'Upcoming Distributions' || label == 'Upcoming Payouts') {
      return LucideIcons.calendarClock;
    }
    if (label == 'Pending Payments') return LucideIcons.banknote;
    if (label == 'KYC Pending') return LucideIcons.shieldAlert;
    if (label == 'Overdue Actions') return LucideIcons.alarmClock;
    if (label == 'Avg Investment') return LucideIcons.badgeDollarSign;
    if (label == 'Open Opportunities') return LucideIcons.landmark;
    return LucideIcons.landmark;
  }

  String _kpiSubtitle(String label) => switch (label) {
    'Total Investors' => 'All non-archived investors',
    'Active Investors' => 'Lifecycle active/VIP/onboarding',
    'Total AUM' || 'AUM' => 'Total book value',
    'Capital Raised' => 'Sum raised across opportunities',
    'Upcoming Distributions' || 'Upcoming Payouts' =>
      'Scheduled + processing',
    'Pending Payments' => 'Awaiting finance verification',
    'KYC Pending' => 'Needs compliance review',
    'Overdue Actions' => 'Tasks + aged payment intents',
    'Avg Investment' => 'Mean commitment size',
    'Open Opportunities' => 'Capital raises open',
    _ => 'Operational metric',
  };

  List<Widget> _tabSlivers(
    BuildContext context,
    WidgetRef ref,
    ImpCommandCenterSnapshot snap,
    ImpUiState ui,
    ImpController controller,
  ) {
    final canWrite = hasPermissionAny(ref, const [
      PermissionSlugs.investorsWrite,
    ]);
    final canManageOpportunities = hasPermissionAny(ref, const [
      PermissionSlugs.investorsOpportunities,
      PermissionSlugs.investorsWrite,
    ]);
    final canManagePortfolio = hasPermissionAny(ref, const [
      PermissionSlugs.investorsPortfolio,
      PermissionSlugs.investorsWrite,
    ]);
    final canManageCommitments = hasPermissionAny(ref, const [
      PermissionSlugs.investorsPortfolio,
      PermissionSlugs.investorsOpportunities,
      PermissionSlugs.investorsWrite,
    ]);
    final canManageDistributions = hasPermissionAny(ref, const [
      PermissionSlugs.investorsDistributions,
      PermissionSlugs.investorsWrite,
    ]);
    final canManageAlerts = hasPermissionAny(ref, const [
      PermissionSlugs.investorsAnalytics,
      PermissionSlugs.investorsWrite,
    ]);
    final canManageKyc = hasPermissionAny(ref, const [
      PermissionSlugs.investorsKyc,
    ]);
    final canCommunicate = hasPermissionAny(ref, const [
      PermissionSlugs.investorsCommunicate,
    ]);
    final canAssignInvestments = hasPermissionAny(ref, const [
      PermissionSlugs.investorsAssign,
      PermissionSlugs.investorsPortfolio,
    ]);
    final canPublishDocuments = hasPermissionAny(ref, const [
      PermissionSlugs.investorsDocuments,
    ]);
    final canManageReports = hasPermissionAny(ref, const [
      PermissionSlugs.investorsReports,
    ]);
    final canManageReferrals = hasPermissionAny(ref, const [
      PermissionSlugs.investorsReferrals,
    ]);
    final canManageTasks = hasPermissionAny(ref, const [
      PermissionSlugs.investorsTasks,
      PermissionSlugs.investorsWrite,
    ]);
    final canManagePayments = hasPermissionAny(ref, const [
      PermissionSlugs.investorsPayments,
      PermissionSlugs.investorsWrite,
    ]);
    final canAssignOwner = hasPermissionAny(ref, const [
      PermissionSlugs.investorsAssign,
    ]);
    switch (ui.selectedTab) {
      case ImpCommandTab.overview:
        final queues = ref.watch(impWorkQueuesProvider);
        return [
          ContainedPadding(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: ImpOpsQueueShortcuts(
                queues: queues.asData?.value,
                onOpenPayments: controller.openPayments,
                onOpenKyc: controller.openKyc,
                onOpenInvestments: controller.openInvestments,
                onOpenAlerts: controller.openAlerts,
                onOpenSupport: controller.openSupport,
              ),
            ),
          ),
          ContainedPadding(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: queues.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => _EmptyState(
                  icon: LucideIcons.listChecks,
                  message: userFacingError(
                    error,
                    fallback: 'Unable to load investor work queues.',
                  ),
                ),
                data: (data) => _WorkQueuesPanel(
                  queues: data,
                  onOpenInvestor: controller.selectInvestor,
                  showTasks: canManageTasks,
                  canConfirmPayments: canManagePayments,
                  onConfirmPayment: canManagePayments
                      ? (intentId) =>
                            _confirmPaymentIntent(context, ref, intentId)
                      : null,
                  onRejectPayment: canManagePayments
                      ? (intentId) =>
                            _rejectPaymentIntent(context, ref, intentId)
                      : null,
                  onCompleteTask: canManageTasks
                      ? (taskId) => _setTaskStatus(
                            context,
                            ref,
                            taskId,
                            'done',
                          )
                      : null,
                ),
              ),
            ),
          ),
          ContainedPadding(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: ImpOpsOverviewExtras(
                holdings: snap.holdings,
                alerts: snap.alerts,
                activities: snap.activities,
                onAlertStatusChanged: canManageAlerts
                    ? (alert, status) =>
                          _setAlertStatus(context, ref, alert, status)
                    : null,
              ),
            ),
          ),
        ];
      case ImpCommandTab.investors:
        const pageSize = 25;
        final directory = ref.watch(
          impInvestorDirectoryProvider((
            search: ui.searchQuery,
            investorType: ui.typeFilter,
            lifecycleStatus: ui.lifecycleFilter,
            kycStatus: ui.kycFilter,
            assignedStaffId: ui.assignedStaffId,
            limit: pageSize,
            offset: ui.investorPageOffset,
          )),
        );
        return [
          ContainedPadding(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: directory.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => _EmptyState(
                  icon: LucideIcons.database,
                  message: userFacingError(
                    error,
                    fallback: 'Unable to load the investor directory.',
                  ),
                ),
                data: (page) => ImpInvestorDirectoryPanel(
                  investors: page.items,
                  selectedInvestorId: ui.selectedInvestorId,
                  onPreview: controller.previewInvestor,
                  onOpen360: controller.selectInvestor,
                  onCreate: canWrite
                      ? () => _saveInvestor(context, ref, null)
                      : null,
                  onEdit: canWrite
                      ? (investor) => _saveInvestor(context, ref, investor)
                      : null,
                  onArchive: canWrite
                      ? (investor) => _archiveInvestor(context, ref, investor)
                      : null,
                  total: page.total,
                  offset: page.offset,
                  limit: page.limit,
                  hasMore: page.hasMore,
                  onPrevPage: page.offset == 0
                      ? null
                      : () => controller.setInvestorPageOffset(
                            page.offset - page.limit,
                          ),
                  onNextPage: !page.hasMore
                      ? null
                      : () => controller.setInvestorPageOffset(
                            page.offset + page.limit,
                          ),
                ),
              ),
            ),
          ),
        ];
      case ImpCommandTab.capital:
        final websiteAsync = ref.watch(impWebsiteOpportunitiesProvider);
        return [
          ContainedPadding(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _ImpSegmentBar(
                labels: [
                  for (final s in ImpCapitalSegment.values) s.label,
                ],
                selectedIndex: ui.capitalSegment.index,
                onSelected: (i) => controller.setCapitalSegment(
                  ImpCapitalSegment.values[i],
                ),
              ),
            ),
          ),
          ...switch (ui.capitalSegment) {
            ImpCapitalSegment.investments => [
              ContainedPadding(
                child: _SectionCard(
                  title: 'Investments',
                  icon: LucideIcons.briefcase,
                  action: canManageCommitments
                      ? FilledButton.icon(
                          onPressed:
                              snap.investors.isEmpty ||
                                  snap.opportunities.isEmpty
                              ? null
                              : () =>
                                    _saveCommitment(context, ref, snap, null),
                          icon: const Icon(LucideIcons.plus, size: 16),
                          label: const Text('Add investment'),
                        )
                      : null,
                  child: _CommitmentList(
                    commitments: snap.commitments,
                    emptyMessage:
                        'No investments have been created yet. Record a commitment against an open capital raise.',
                    onEdit: canManageCommitments
                        ? (commitment) =>
                              _saveCommitment(context, ref, snap, commitment)
                        : null,
                    onStatusChanged: canManageCommitments
                        ? (commitment, status) => _setCommitmentStatus(
                              context,
                              ref,
                              commitment,
                              status,
                            )
                        : null,
                    onOpenInvestor: controller.selectInvestor,
                  ),
                ),
              ),
            ],
            ImpCapitalSegment.opportunities => [
              ContainedPadding(
                child: _SectionCard(
                  title: 'Capital Raise Manager',
                  icon: LucideIcons.landmark,
                  action: canManageOpportunities
                      ? FilledButton.icon(
                          onPressed: () =>
                              _saveOpportunity(context, ref, null),
                          icon: const Icon(LucideIcons.plus, size: 16),
                          label: const Text('New opportunity'),
                        )
                      : null,
                  child: _OpportunityList(
                    opportunities: controller.filteredOpportunities(snap),
                    onEdit: canManageOpportunities
                        ? (opportunity) =>
                              _saveOpportunity(context, ref, opportunity)
                        : null,
                  ),
                ),
              ),
              ContainedPadding(
                child: _SectionCard(
                  title: 'Website ↔ operations link',
                  icon: LucideIcons.link,
                  child: websiteAsync.when(
                    loading: () => ImpWebsiteLinkPanel(
                      opportunities: const [],
                      websiteOpportunities: const [],
                      canLink: false,
                      loading: true,
                      onLink: ({
                        required opportunityId,
                        required websiteOpportunityId,
                      }) async {},
                    ),
                    error: (error, _) => ImpWebsiteLinkPanel(
                      opportunities: snap.opportunities,
                      websiteOpportunities: const [],
                      canLink: false,
                      error: userFacingError(
                        error,
                        fallback: 'Unable to load website investment cards.',
                      ),
                      onLink: ({
                        required opportunityId,
                        required websiteOpportunityId,
                      }) async {},
                    ),
                    data: (sites) => ImpWebsiteLinkPanel(
                      opportunities: snap.opportunities,
                      websiteOpportunities: sites,
                      canLink: canManageOpportunities,
                      onLink: ({
                        required opportunityId,
                        required websiteOpportunityId,
                      }) =>
                          _linkWebsiteOpportunity(
                            context,
                            ref,
                            opportunityId: opportunityId,
                            websiteOpportunityId: websiteOpportunityId,
                          ),
                      onSetStatus: canManageOpportunities
                          ? ({
                              required websiteOpportunityId,
                              status,
                              opportunityStatus,
                              isFeatured,
                            }) =>
                              _setWebsiteOpportunityStatus(
                                context,
                                ref,
                                websiteOpportunityId: websiteOpportunityId,
                                status: status,
                                opportunityStatus: opportunityStatus,
                                isFeatured: isFeatured,
                              )
                          : null,
                    ),
                  ),
                ),
              ),
              ContainedPadding(
                child: _SectionCard(
                  title: 'Recent commitments',
                  icon: LucideIcons.badgeCheck,
                  action: canManageCommitments
                      ? TextButton(
                          onPressed: controller.openInvestments,
                          child: const Text('Open Investments'),
                        )
                      : null,
                  child: _CommitmentList(
                    commitments: snap.commitments.take(5).toList(),
                    emptyMessage: 'No recent commitments on capital raises.',
                    onOpenInvestor: controller.selectInvestor,
                  ),
                ),
              ),
            ],
            ImpCapitalSegment.portfolio => [
              ContainedPadding(
                child: _SectionCard(
                  title: 'Portfolio Intelligence',
                  icon: LucideIcons.pieChart,
                  child: _PortfolioPanel(
                    holdings: snap.holdings,
                    wallets: snap.wallets,
                    totalValue:
                        ImpService.computePortfolioValue(snap.holdings),
                    onAdjustHolding: canManagePortfolio
                        ? (holding) => _adjustHolding(context, ref, holding)
                        : null,
                  ),
                ),
              ),
            ],
            ImpCapitalSegment.distributions => [
              ContainedPadding(
                child: _SectionCard(
                  title: 'Distributions Queue',
                  icon: LucideIcons.banknote,
                  action: canManageDistributions
                      ? FilledButton.icon(
                          onPressed: snap.investors.isEmpty
                              ? null
                              : () => _saveDistribution(
                                    context,
                                    ref,
                                    snap,
                                    null,
                                  ),
                          icon: const Icon(LucideIcons.plus, size: 16),
                          label: const Text('Schedule'),
                        )
                      : null,
                  child: _DistributionList(
                    distributions: snap.distributions,
                    onEdit: canManageDistributions
                        ? (distribution) => _saveDistribution(
                              context,
                              ref,
                              snap,
                              distribution,
                            )
                        : null,
                    onStatusChanged: canManageDistributions
                        ? (distribution, status) => _setDistributionStatus(
                              context,
                              ref,
                              distribution,
                              status,
                            )
                        : null,
                  ),
                ),
              ),
            ],
          },
        ];
      case ImpCommandTab.payments:
        final queues = ref.watch(impWorkQueuesProvider);
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Payment verification queue',
              icon: LucideIcons.wallet,
              child: queues.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => _EmptyState(
                  icon: LucideIcons.wallet,
                  message: userFacingError(
                    error,
                    fallback: 'Unable to load payment intents.',
                  ),
                ),
                data: (data) {
                  if (!canManagePayments) {
                    return const _EmptyState(
                      icon: LucideIcons.lock,
                      message:
                          'You do not have permission to manage investor payments.',
                    );
                  }
                  final items = data.payments;
                  if (items.isEmpty) {
                    return const _EmptyState(
                      icon: LucideIcons.wallet,
                      message:
                          'No investor payments are awaiting verification.',
                    );
                  }
                  return Column(
                    children: items.map((item) {
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: const Icon(
                          LucideIcons.banknote,
                          size: 18,
                          color: AppColors.gold,
                        ),
                        title: Text(item.title),
                        subtitle: Text(
                          [
                            if (item.subtitle != null &&
                                item.subtitle!.isNotEmpty)
                              item.subtitle!,
                            item.status.replaceAll('_', ' '),
                          ].join(' · '),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (item.amount != null)
                              Text(formatImpMoney(item.amount!)),
                            IconButton(
                              tooltip: 'Confirm payment',
                              onPressed: () => _confirmPaymentIntent(
                                context,
                                ref,
                                item.id,
                              ),
                              icon: const Icon(
                                LucideIcons.checkCircle,
                                size: 18,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Reject payment',
                              onPressed: () => _rejectPaymentIntent(
                                context,
                                ref,
                                item.id,
                              ),
                              icon: const Icon(
                                LucideIcons.xCircle,
                                size: 18,
                                color: AdminDeskColors.red,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Open investor',
                              onPressed: () =>
                                  controller.selectInvestor(item.investorId),
                              icon: const Icon(
                                LucideIcons.chevronRight,
                                size: 16,
                              ),
                            ),
                          ],
                        ),
                        onTap: () =>
                            controller.selectInvestor(item.investorId),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ),
        ];
      case ImpCommandTab.compliance:
        final queues = ref.watch(impWorkQueuesProvider);
        final investorId = ui.selectedInvestorId ??
            (snap.investors.isEmpty ? null : snap.investors.first.id);
        final detailAsync = investorId == null
            ? null
            : ref.watch(impInvestorDetailProvider(investorId));
        final publishable = ref.watch(impPublishableDocumentsProvider);
        return [
          ContainedPadding(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _ImpSegmentBar(
                labels: [
                  for (final s in ImpComplianceSegment.values) s.label,
                ],
                selectedIndex: ui.complianceSegment.index,
                onSelected: (i) => controller.setComplianceSegment(
                  ImpComplianceSegment.values[i],
                ),
              ),
            ),
          ),
          ...switch (ui.complianceSegment) {
            ImpComplianceSegment.kyc => [
              ContainedPadding(
                child: _SectionCard(
                  title: 'KYC & Compliance',
                  icon: LucideIcons.shieldCheck,
                  child: queues.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (error, _) => _EmptyState(
                      icon: LucideIcons.shieldAlert,
                      message: userFacingError(
                        error,
                        fallback: 'Unable to load the KYC queue.',
                      ),
                    ),
                    data: (data) => ImpKycDeskPanel(
                      items: data.kyc,
                      canManage: canManageKyc,
                      onOpenInvestor: controller.selectInvestor,
                      onVerify: (investorId, status) =>
                          _verifyInvestorKyc(context, ref, investorId, status),
                    ),
                  ),
                ),
              ),
            ],
            ImpComplianceSegment.documents => [
              ContainedPadding(
                child: _SectionCard(
                  title: 'Investor documents',
                  icon: LucideIcons.folderOpen,
                  child: ImpDocumentsDeskPanel(
                    investors: snap.investors,
                    selectedInvestorId: investorId,
                    onSelectInvestor: controller.previewInvestor,
                    vaultDocuments:
                        detailAsync?.asData?.value.documents ?? const [],
                    loadingVault: detailAsync?.isLoading ?? false,
                    vaultError: detailAsync?.hasError == true
                        ? userFacingError(
                            detailAsync!.error!,
                            fallback: 'Unable to load vault documents.',
                          )
                        : null,
                    publishableDocuments:
                        publishable.asData?.value ?? const [],
                    canPublish: canPublishDocuments,
                    onPublish: (documentId, title) async {
                      final targetId = investorId;
                      if (targetId == null) return;
                      await ref
                          .read(impServiceProvider)
                          .publishDocumentToInvestor(
                            documentId: documentId,
                            investorId: targetId,
                            title: title,
                          );
                      ref.invalidate(impInvestorDetailProvider(targetId));
                      ref.invalidate(impSnapshotProvider);
                      controller.setMessage(
                        'Document published to investor vault',
                      );
                    },
                  ),
                ),
              ),
            ],
          },
        ];
      case ImpCommandTab.support:
        final inboxAsync = ref.watch(impSupportInboxProvider);
        final canSupport = hasPermissionAny(ref, const [
          PermissionSlugs.supportRead,
          PermissionSlugs.supportInbox,
          PermissionSlugs.supportTickets,
          PermissionSlugs.investorsCommunicate,
        ]);
        final canReply = hasPermissionAny(ref, const [
          PermissionSlugs.supportWrite,
          PermissionSlugs.supportTickets,
          PermissionSlugs.investorsCommunicate,
        ]);
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Investor support & messaging',
              icon: LucideIcons.headphones,
              child: !canSupport
                  ? const _EmptyState(
                      icon: LucideIcons.lock,
                      message:
                          'You do not have permission to view investor support inbox.',
                    )
                  : inboxAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (error, _) => _EmptyState(
                        icon: LucideIcons.headphones,
                        message: userFacingError(
                          error,
                          fallback: 'Unable to load investor support inbox.',
                        ),
                      ),
                      data: (inbox) => ImpSupportInboxPanel(
                        inbox: inbox,
                        canReply: canReply,
                        onOpenInvestor: controller.selectInvestor,
                        loadConversationMessages: (conversationId) => ref
                            .read(impServiceProvider)
                            .listConversationMessages(conversationId),
                        loadTicketMessages: (ticketId) => ref
                            .read(impServiceProvider)
                            .listTicketMessages(ticketId),
                        onReplyConversation: ({
                          required investorId,
                          required conversationId,
                          required body,
                          required subject,
                        }) async {
                          await ref.read(impServiceProvider).messageInvestor(
                                investorId: investorId,
                                conversationId: conversationId,
                                body: body,
                                subject: subject,
                              );
                          ref.invalidate(impSupportInboxProvider);
                          ref.invalidate(impInvestorDetailProvider(investorId));
                          controller.setMessage('Conversation reply sent');
                        },
                        onReplyTicket: ({
                          required ticketId,
                          required body,
                          required isInternal,
                        }) async {
                          await ref.read(impServiceProvider).replyToSupportTicket(
                                ticketId: ticketId,
                                message: body,
                                isInternal: isInternal,
                              );
                          ref.invalidate(impSupportInboxProvider);
                          controller.setMessage(
                            isInternal
                                ? 'Internal ticket note saved'
                                : 'Ticket reply sent',
                          );
                        },
                        onOpenConversationInDesk: (id) {
                          context.go(
                            '${RoutePaths.dashboardSupport}'
                            '?tab=clientMessages'
                            '&kind=investor'
                            '&conversation=$id',
                          );
                        },
                        onOpenTicketInDesk: (id) {
                          context.go(
                            '${RoutePaths.dashboardSupport}'
                            '?tab=tickets&ticket=$id',
                          );
                        },
                      ),
                    ),
            ),
          ),
        ];
      case ImpCommandTab.insights:
        final notificationsAsync = ref.watch(impRecentNotificationsProvider);
        final investorId = ui.selectedInvestorId ??
            (snap.investors.isEmpty ? null : snap.investors.first.id);
        final detailAsync = investorId == null
            ? null
            : ref.watch(impInvestorDetailProvider(investorId));
        return [
          ContainedPadding(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _ImpSegmentBar(
                labels: [
                  for (final s in ImpInsightsSegment.values) s.label,
                ],
                selectedIndex: ui.insightsSegment.index,
                onSelected: (i) => controller.setInsightsSegment(
                  ImpInsightsSegment.values[i],
                ),
              ),
            ),
          ),
          ...switch (ui.insightsSegment) {
            ImpInsightsSegment.reports => [
              ContainedPadding(
                child: _SectionCard(
                  title: 'Investor reports',
                  icon: LucideIcons.fileBarChart,
                  child: ImpReportsDeskPanel(
                    investors: snap.investors,
                    selectedInvestorId: investorId,
                    onSelectInvestor: controller.previewInvestor,
                    reports: detailAsync?.asData?.value.reports ?? const [],
                    loading: detailAsync?.isLoading ?? false,
                    error: detailAsync?.hasError == true
                        ? userFacingError(
                            detailAsync!.error!,
                            fallback: 'Unable to load investor reports.',
                          )
                        : null,
                    canPublish: canManageReports,
                    onPublish: ({
                      required title,
                      required reportType,
                      periodLabel,
                      fileUrl,
                    }) async {
                      final targetId = investorId;
                      if (targetId == null) {
                        throw StateError('Select an investor first');
                      }
                      await ref.read(impServiceProvider).publishInvestorReport(
                            investorId: targetId,
                            title: title,
                            reportType: reportType,
                            periodLabel: periodLabel,
                            fileUrl: fileUrl,
                          );
                      ref.invalidate(impInvestorDetailProvider(targetId));
                      ref.invalidate(impSnapshotProvider);
                      controller.setMessage('Report published');
                    },
                  ),
                ),
              ),
            ],
            ImpInsightsSegment.activity => [
              ContainedPadding(
                child: _SectionCard(
                  title: 'Activity / audit trail',
                  icon: LucideIcons.activity,
                  child: ImpActivityDeskPanel(
                    activities: snap.activities,
                    onOpenInvestor: controller.selectInvestor,
                  ),
                ),
              ),
            ],
            ImpInsightsSegment.alerts => [
              ContainedPadding(
                child: _SectionCard(
                  title: 'Alerts',
                  icon: LucideIcons.alertTriangle,
                  child: _AlertList(
                    alerts: snap.alerts,
                    onStatusChanged: canManageAlerts
                        ? (alert, status) =>
                              _setAlertStatus(context, ref, alert, status)
                        : null,
                  ),
                ),
              ),
              ContainedPadding(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: _SectionCard(
                    title: 'Investor notifications',
                    icon: LucideIcons.bell,
                    child: ImpNotificationsDeskPanel(
                      notifications:
                          notificationsAsync.asData?.value ?? const [],
                      investors: snap.investors,
                      selectedInvestorId: ui.selectedInvestorId,
                      onSelectInvestor: controller.previewInvestor,
                      canPublish: canCommunicate,
                      loading: notificationsAsync.isLoading,
                      error: notificationsAsync.hasError
                          ? userFacingError(
                              notificationsAsync.error!,
                              fallback: 'Unable to load notifications.',
                            )
                          : null,
                      onOpenInvestor: controller.selectInvestor,
                      onPublish:
                          ({
                            required String investorId,
                            required String title,
                            String? body,
                            String? route,
                          }) async {
                            await ref
                                .read(impServiceProvider)
                                .publishInvestorNotification(
                                  investorId: investorId,
                                  title: title,
                                  body: body,
                                  route: route,
                                );
                            ref.invalidate(impRecentNotificationsProvider);
                            ref.invalidate(impSnapshotProvider);
                            controller.setMessage('Notification sent');
                          },
                    ),
                  ),
                ),
              ),
            ],
          },
        ];
      case ImpCommandTab.investor360:
        final investorId =
            ui.selectedInvestorId ??
            (snap.investors.isEmpty ? null : snap.investors.first.id);
        return [
          ContainedPadding(
            child: _SectionCard(
              title: '360° Investor Workspace',
              icon: LucideIcons.userCircle,
              child: investorId == null
                  ? const Text('No investor selected')
                  : ref
                        .watch(impInvestorDetailProvider(investorId))
                        .when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (error, _) => _EmptyState(
                            icon: LucideIcons.database,
                            message: userFacingError(
                              error,
                              fallback: 'Unable to load investor details.',
                            ),
                          ),
                          data: (detail) => _Investor360Panel(
                            investor: detail.investor,
                            investors: [
                              detail.investor,
                              ...snap.investors.where(
                                (item) => item.id != detail.investor.id,
                              ),
                            ],
                            opportunities: snap.opportunities,
                            holdings: detail.holdings,
                            distributions: detail.distributions,
                            activities: detail.activities,
                            wallet: detail.wallet,
                            documents: detail.documents,
                            conversations: detail.conversations,
                            reports: detail.reports,
                            statements: detail.statements,
                            referrals: detail.referrals,
                            canInvite: canWrite,
                            canManageKyc: canManageKyc,
                            canNotify: canCommunicate,
                            canAssignInvestments: canAssignInvestments,
                            canPublishDocuments: canPublishDocuments,
                            canMessage: canCommunicate,
                            canManageReports: canManageReports,
                            canManageReferrals: canManageReferrals,
                            canAssignOwner: canAssignOwner,
                            canManageTasks: canManageTasks,
                            onSelectInvestor: controller.selectInvestor,
                            service: ref.read(impServiceProvider),
                            onChanged: (msg) {
                              ref.invalidate(impSnapshotProvider);
                              ref.invalidate(impWorkQueuesProvider);
                              ref.invalidate(
                                impInvestorDetailProvider(investorId),
                              );
                              controller.setMessage(msg);
                            },
                          ),
                        ),
            ),
          ),
        ];
    }
  }

  Future<void> _mutate(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() operation,
    String successMessage,
  ) async {
    try {
      await operation();
      ref.invalidate(impSnapshotProvider);
      ref.invalidate(impDeskKpisProvider);
      ref.invalidate(impWorkQueuesProvider);
      ref.invalidate(impInvestorDirectoryProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(error))));
    }
  }

  Future<void> _confirmPaymentIntent(
    BuildContext context,
    WidgetRef ref,
    String intentId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm payment intent'),
        content: const Text(
          'This posts a payment, receipt, and ledger deposit for the intent.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _mutate(context, ref, () async {
      await ref
          .read(impServiceProvider)
          .confirmInvestorIntent(intentId: intentId);
    }, 'Payment intent confirmed');
  }

  Future<void> _rejectPaymentIntent(
    BuildContext context,
    WidgetRef ref,
    String intentId,
  ) async {
    final notesCtrl = TextEditingController();
    final rejected = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject payment intent'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The investor submission stays recorded as rejected. '
              'This does not mark a bank transfer as paid.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Rejection notes (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AdminDeskColors.red,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    final notes = notesCtrl.text;
    notesCtrl.dispose();
    if (rejected != true || !context.mounted) return;
    await _mutate(context, ref, () async {
      await ref.read(impServiceProvider).confirmInvestorIntent(
            intentId: intentId,
            status: 'rejected',
            notes: notes.trim().isEmpty ? null : notes.trim(),
          );
    }, 'Payment intent rejected');
  }

  Future<void> _saveInvestor(
    BuildContext context,
    WidgetRef ref,
    ImpInvestor? investor,
  ) async {
    final value = await showInvestorFormDialog(
      context: context,
      investor: investor,
    );
    if (value == null || !context.mounted) return;
    await _mutate(context, ref, () async {
      await ref
          .read(impServiceProvider)
          .saveInvestor(
            investorId: investor?.id,
            fullName: value.fullName,
            email: value.email,
            phone: value.phone,
            company: value.company,
            nationality: value.nationality,
            investorType: value.investorType,
            lifecycleStatus: value.lifecycleStatus,
            riskLevel: value.riskLevel,
            preferredCurrency: value.preferredCurrency,
          );
    }, investor == null ? 'Investor created' : 'Investor updated');
  }

  Future<void> _archiveInvestor(
    BuildContext context,
    WidgetRef ref,
    ImpInvestor investor,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archive investor?'),
        content: Text(
          '${investor.fullName} will no longer appear in active management lists.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _mutate(
      context,
      ref,
      () => ref.read(impServiceProvider).archiveInvestor(investor.id),
      'Investor archived',
    );
  }

  Future<void> _saveOpportunity(
    BuildContext context,
    WidgetRef ref,
    ImpOpportunity? opportunity,
  ) async {
    final value = await showOpportunityFormDialog(
      context: context,
      opportunity: opportunity,
    );
    if (value == null || !context.mounted) return;
    await _mutate(
      context,
      ref,
      () async {
        await ref
            .read(impServiceProvider)
            .saveOpportunity(
              opportunityId: opportunity?.id,
              title: value.title,
              description: value.description,
              status: value.status,
              targetRaise: value.targetRaise,
              amountRaised: value.amountRaised,
              minTicket: value.minTicket,
              maxTicket: value.maxTicket,
              projectedReturnPct: value.projectedReturnPct,
              currency: value.currency,
              riskLevel: value.riskLevel,
            );
      },
      opportunity == null ? 'Opportunity created' : 'Opportunity updated',
    );
  }

  Future<void> _setCommitmentStatus(
    BuildContext context,
    WidgetRef ref,
    ImpCommitment commitment,
    String status,
  ) => _mutate(
    context,
    ref,
    () async {
      final service = ref.read(impServiceProvider);
      if (status == 'funded') {
        await service.fundInvestmentCommitment(commitment.id);
      } else {
        await service.setCommitmentStatus(commitment.id, status);
      }
    },
    status == 'funded'
        ? 'Investment funded and ledger updated'
        : 'Commitment status updated',
  );

  Future<void> _verifyInvestorKyc(
    BuildContext context,
    WidgetRef ref,
    String investorId,
    KycStatus status,
  ) => _mutate(
    context,
    ref,
    () => ref.read(impServiceProvider).verifyInvestorKyc(
          investorId: investorId,
          status: status,
        ),
    'KYC set to ${status.label}',
  );

  Future<void> _setTaskStatus(
    BuildContext context,
    WidgetRef ref,
    String taskId,
    String status,
  ) => _mutate(
    context,
    ref,
    () => ref.read(impServiceProvider).setInvestorTaskStatus(taskId, status),
    status == 'done' ? 'Task marked done' : 'Task status updated',
  );

  Future<void> _linkWebsiteOpportunity(
    BuildContext context,
    WidgetRef ref, {
    required String opportunityId,
    required String websiteOpportunityId,
  }) => _mutate(
    context,
    ref,
    () async {
      await ref.read(impServiceProvider).linkWebsiteOpportunity(
            opportunityId: opportunityId,
            websiteOpportunityId: websiteOpportunityId,
          );
      ref.invalidate(impWebsiteOpportunitiesProvider);
    },
    'Website investment card linked',
  );

  Future<void> _setWebsiteOpportunityStatus(
    BuildContext context,
    WidgetRef ref, {
    required String websiteOpportunityId,
    String? status,
    String? opportunityStatus,
    bool? isFeatured,
  }) => _mutate(
    context,
    ref,
    () async {
      await ref.read(impServiceProvider).setWebsiteOpportunityStatus(
            websiteOpportunityId: websiteOpportunityId,
            status: status,
            opportunityStatus: opportunityStatus,
            isFeatured: isFeatured,
          );
      ref.invalidate(impWebsiteOpportunitiesProvider);
    },
    status == 'active'
        ? 'Website card published'
        : status == 'draft'
        ? 'Website card unpublished'
        : status == 'archived'
        ? 'Website card archived'
        : 'Website card updated',
  );

  Future<void> _saveCommitment(
    BuildContext context,
    WidgetRef ref,
    ImpCommandCenterSnapshot snapshot,
    ImpCommitment? commitment,
  ) async {
    final value = await showCommitmentFormDialog(
      context: context,
      investors: snapshot.investors,
      opportunities: snapshot.opportunities,
      commitment: commitment,
    );
    if (value == null || !context.mounted) return;
    await _mutate(context, ref, () async {
      await ref
          .read(impServiceProvider)
          .saveCommitment(
            commitmentId: commitment?.id,
            investorId: value.investorId,
            opportunityId: value.opportunityId,
            amount: value.amount,
            currency: value.currency,
            status: value.status,
            notes: value.notes,
          );
    }, commitment == null ? 'Commitment recorded' : 'Commitment updated');
  }

  Future<void> _saveDistribution(
    BuildContext context,
    WidgetRef ref,
    ImpCommandCenterSnapshot snapshot,
    ImpDistribution? distribution,
  ) async {
    final value = await showDistributionFormDialog(
      context: context,
      investors: snapshot.investors,
      opportunities: snapshot.opportunities,
      distribution: distribution,
    );
    if (value == null || !context.mounted) return;
    await _mutate(
      context,
      ref,
      () async {
        await ref
            .read(impServiceProvider)
            .saveDistribution(
              distributionId: distribution?.id,
              investorId: value.investorId,
              opportunityId: value.opportunityId,
              amount: value.amount,
              status: value.status,
              distributionType: value.distributionType,
              currency: value.currency,
              scheduledAt: value.scheduledAt,
              reference: value.reference,
            );
      },
      distribution == null ? 'Distribution scheduled' : 'Distribution updated',
    );
  }

  Future<void> _setDistributionStatus(
    BuildContext context,
    WidgetRef ref,
    ImpDistribution distribution,
    DistributionStatus status,
  ) => _mutate(
    context,
    ref,
    () => ref
        .read(impServiceProvider)
        .setDistributionStatus(distribution.id, status),
    'Distribution status updated',
  );

  Future<void> _setAlertStatus(
    BuildContext context,
    WidgetRef ref,
    ImpAlert alert,
    String status,
  ) => _mutate(
    context,
    ref,
    () => ref.read(impServiceProvider).setAlertStatus(alert.id, status),
    'Alert status updated',
  );

  Future<void> _adjustHolding(
    BuildContext context,
    WidgetRef ref,
    ImpHolding holding,
  ) async {
    final controller = TextEditingController(
      text: holding.currentValue.toString(),
    );
    final formKey = GlobalKey<FormState>();
    final value = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Adjust ${holding.label}'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Current value'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (raw) {
              final parsed = double.tryParse((raw ?? '').trim());
              if (parsed == null) return 'Enter a number';
              return parsed < 0 ? 'Must be zero or greater' : null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(
                dialogContext,
                double.parse(controller.text.trim()),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || !context.mounted) return;
    await _mutate(
      context,
      ref,
      () => ref.read(impServiceProvider).adjustHoldingValue(holding.id, value),
      'Holding value updated',
    );
  }
}

class _ImpSegmentBar extends StatelessWidget {
  const _ImpSegmentBar({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Padding(
              padding: EdgeInsets.only(right: i == labels.length - 1 ? 0 : 6),
              child: ChoiceChip(
                label: Text(labels[i]),
                selected: selectedIndex == i,
                onSelected: (_) => onSelected(i),
              ),
            ),
        ],
      ),
    );
  }
}

class ContainedPadding extends StatelessWidget {
  const ContainedPadding({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

class _SearchAndFilters extends StatelessWidget {
  const _SearchAndFilters({
    required this.ui,
    required this.onSearch,
    required this.onType,
    required this.onLifecycle,
    required this.onKyc,
    required this.onAssignedStaff,
    this.managers,
  });

  final ImpUiState ui;
  final List<ImpStaffOption>? managers;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onType;
  final ValueChanged<InvestorLifecycleStatus?> onLifecycle;
  final ValueChanged<KycStatus?> onKyc;
  final ValueChanged<String?> onAssignedStaff;

  @override
  Widget build(BuildContext context) {
    final staff = managers ?? const <ImpStaffOption>[];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Search investors, codes, email…',
              prefixIcon: const Icon(LucideIcons.search, size: 18),
              isDense: true,
              border: OutlineInputBorder(borderRadius: AppRadius.cardBorder),
            ),
            onChanged: onSearch,
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All types'),
                  selected: ui.typeFilter == null,
                  onSelected: (_) => onType(null),
                ),
                ...InvestorType.values.map(
                  (t) => Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: FilterChip(
                      label: Text(t.label),
                      selected: ui.typeFilter == t.slug,
                      onSelected: (_) => onType(t.slug),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All lifecycle'),
                  selected: ui.lifecycleFilter == null,
                  onSelected: (_) => onLifecycle(null),
                ),
                ...InvestorLifecycleStatus.values.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: FilterChip(
                      label: Text(s.label),
                      selected: ui.lifecycleFilter == s,
                      onSelected: (_) => onLifecycle(s),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All KYC'),
                  selected: ui.kycFilter == null,
                  onSelected: (_) => onKyc(null),
                ),
                ...[
                  KycStatus.pending,
                  KycStatus.underReview,
                  KycStatus.awaitingDocuments,
                  KycStatus.approved,
                  KycStatus.rejected,
                  KycStatus.expired,
                ].map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: FilterChip(
                      label: Text(s.label),
                      selected: ui.kycFilter == s,
                      onSelected: (_) => onKyc(s),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (staff.isNotEmpty) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('All owners'),
                    selected: ui.assignedStaffId == null,
                    onSelected: (_) => onAssignedStaff(null),
                  ),
                  ...staff.map(
                    (m) => Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: FilterChip(
                        label: Text(m.name),
                        selected: ui.assignedStaffId == m.id,
                        onSelected: (_) => onAssignedStaff(
                          ui.assignedStaffId == m.id ? null : m.id,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WorkQueuesPanel extends StatelessWidget {
  const _WorkQueuesPanel({
    required this.queues,
    required this.onOpenInvestor,
    this.showTasks = true,
    this.canConfirmPayments = false,
    this.onConfirmPayment,
    this.onRejectPayment,
    this.onCompleteTask,
  });

  final ImpWorkQueues queues;
  final ValueChanged<String> onOpenInvestor;
  final bool showTasks;
  final bool canConfirmPayments;
  final Future<void> Function(String intentId)? onConfirmPayment;
  final Future<void> Function(String intentId)? onRejectPayment;
  final Future<void> Function(String taskId)? onCompleteTask;

  @override
  Widget build(BuildContext context) {
    final sections = <({
      String title,
      IconData icon,
      List<ImpWorkQueueItem> items,
      bool payments,
      bool tasks,
    })>[
      (
        title: 'Unassigned investors',
        icon: LucideIcons.userMinus,
        items: queues.unassigned,
        payments: false,
        tasks: false,
      ),
      (
        title: 'KYC queue',
        icon: LucideIcons.shieldCheck,
        items: queues.kyc,
        payments: false,
        tasks: false,
      ),
      (
        title: 'Payment queue',
        icon: LucideIcons.wallet,
        items: queues.payments,
        payments: true,
        tasks: false,
      ),
      if (showTasks)
        (
          title: 'Open tasks',
          icon: LucideIcons.listChecks,
          items: queues.tasks,
          payments: false,
          tasks: true,
        ),
      (
        title: 'Stale relationships',
        icon: LucideIcons.clock,
        items: queues.stale,
        payments: false,
        tasks: false,
      ),
    ];

    final hasAny = sections.any((section) => section.items.isNotEmpty);
    if (!hasAny) {
      return const _SectionCard(
        title: 'Work queues',
        icon: LucideIcons.listChecks,
        child: _EmptyState(
          icon: LucideIcons.listChecks,
          message: 'No investor work-queue items right now.',
        ),
      );
    }

    return Column(
      children: [
        for (final section in sections)
          if (section.items.isNotEmpty)
            _SectionCard(
              title: '${section.title} (${section.items.length})',
              icon: section.icon,
              child: Column(
                children: section.items.map((item) {
                  final amount = item.amount;
                  final showConfirm =
                      section.payments &&
                      canConfirmPayments &&
                      onConfirmPayment != null;
                  final showReject =
                      section.payments &&
                      canConfirmPayments &&
                      onRejectPayment != null;
                  final showComplete =
                      section.tasks && onCompleteTask != null;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Icon(section.icon, size: 18, color: AppColors.gold),
                    title: Text(item.title),
                    subtitle: Text(
                      [
                        if (item.subtitle != null && item.subtitle!.isNotEmpty)
                          item.subtitle!,
                        item.status.replaceAll('_', ' '),
                        if (item.priority != null) item.priority!,
                      ].join(' · '),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (amount != null) Text(formatImpMoney(amount)),
                        if (showConfirm)
                          IconButton(
                            tooltip: 'Confirm payment',
                            onPressed: () => onConfirmPayment!(item.id),
                            icon: const Icon(LucideIcons.checkCircle, size: 18),
                          ),
                        if (showReject)
                          IconButton(
                            tooltip: 'Reject payment',
                            onPressed: () => onRejectPayment!(item.id),
                            icon: const Icon(
                              LucideIcons.xCircle,
                              size: 18,
                              color: AdminDeskColors.red,
                            ),
                          ),
                        if (showComplete)
                          IconButton(
                            tooltip: 'Mark task done',
                            onPressed: () => onCompleteTask!(item.id),
                            icon: const Icon(LucideIcons.check, size: 18),
                          ),
                        if (!showConfirm && !showReject && !showComplete)
                          const Icon(LucideIcons.chevronRight, size: 16),
                      ],
                    ),
                    onTap: () => onOpenInvestor(item.investorId),
                  );
                }).toList(),
              ),
            ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.icon,
    this.action,
  });

  final String title;
  final Widget child;
  final IconData? icon;
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
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: AppColors.gold),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  ?action,
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

class _OpportunityList extends StatelessWidget {
  const _OpportunityList({required this.opportunities, this.onEdit});

  final List<ImpOpportunity> opportunities;
  final ValueChanged<ImpOpportunity>? onEdit;

  @override
  Widget build(BuildContext context) {
    if (opportunities.isEmpty) {
      return const _EmptyState(
        icon: LucideIcons.landmark,
        message: 'No investment opportunities are available.',
      );
    }
    return Column(
      children: opportunities.map((opp) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      opp.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Chip(
                    label: Text(opp.status.label),
                    visualDensity: VisualDensity.compact,
                  ),
                  if (onEdit != null)
                    IconButton(
                      tooltip: 'Edit opportunity',
                      onPressed: () => onEdit!(opp),
                      icon: const Icon(LucideIcons.edit3, size: 18),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${opp.code} · Raised ${formatImpMoney(opp.amountRaised)} / ${formatImpMoney(opp.targetRaise)} (${opp.fundedPct.toStringAsFixed(0)}%)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Projected return: ${opp.projectedReturnLabel}',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                opp.returnDisclaimer,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (opp.fundedPct / 100).clamp(0.0, 1.0),
                minHeight: 6,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _CommitmentList extends StatelessWidget {
  const _CommitmentList({
    required this.commitments,
    this.onEdit,
    this.onStatusChanged,
    this.onOpenInvestor,
    this.emptyMessage = 'No commitments have been recorded.',
  });

  final List<ImpCommitment> commitments;
  final ValueChanged<ImpCommitment>? onEdit;
  final void Function(ImpCommitment, String)? onStatusChanged;
  final ValueChanged<String>? onOpenInvestor;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (commitments.isEmpty) {
      return _EmptyState(
        icon: LucideIcons.badgeCheck,
        message: emptyMessage,
      );
    }
    return Column(
      children: commitments.map((c) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(c.opportunityTitle ?? 'Commitment'),
          subtitle: Text('${c.investorName ?? c.investorId} · ${c.status}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                c.amountDisplay,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (onEdit != null)
                IconButton(
                  tooltip: 'Edit commitment',
                  onPressed: () => onEdit!(c),
                  icon: const Icon(LucideIcons.edit3, size: 17),
                ),
              if (onStatusChanged != null)
                PopupMenuButton<String>(
                  tooltip: 'Change commitment status',
                  onSelected: (status) => onStatusChanged!(c, status),
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'pending', child: Text('Pending')),
                    PopupMenuItem(value: 'reserved', child: Text('Reserved')),
                    PopupMenuItem(value: 'confirmed', child: Text('Confirmed')),
                    PopupMenuItem(
                      value: 'funded',
                      child: Text('Fund (ledger)'),
                    ),
                    PopupMenuItem(value: 'cancelled', child: Text('Cancelled')),
                  ],
                ),
            ],
          ),
          onTap: onOpenInvestor == null
              ? null
              : () => onOpenInvestor!(c.investorId),
        );
      }).toList(),
    );
  }
}

class _PortfolioPanel extends StatelessWidget {
  const _PortfolioPanel({
    required this.holdings,
    required this.wallets,
    required this.totalValue,
    this.onAdjustHolding,
  });

  final List<ImpHolding> holdings;
  final List<ImpWallet> wallets;
  final double totalValue;
  final ValueChanged<ImpHolding>? onAdjustHolding;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Holdings value: ${formatImpMoney(totalValue)}',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (holdings.isEmpty)
          const _EmptyState(
            icon: LucideIcons.pieChart,
            message: 'No portfolio holdings have been assigned.',
          ),
        ...holdings.map(
          (h) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(h.label),
            subtitle: Text(
              '${h.investorName ?? 'Investor'} · cost ${formatImpMoney(h.costBasis)}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatImpMoney(h.currentValue),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (onAdjustHolding != null)
                  IconButton(
                    tooltip: 'Adjust current value',
                    onPressed: () => onAdjustHolding!(h),
                    icon: const Icon(LucideIcons.edit3, size: 17),
                  ),
              ],
            ),
          ),
        ),
        const Divider(),
        Text(
          'Wallets',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (wallets.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('No investor wallets are available.'),
          ),
        ...wallets.map(
          (w) => ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(w.investorName ?? w.investorId),
            subtitle: Text(
              'Available ${formatImpMoney(w.availableBalance)} · Pending ${formatImpMoney(w.pendingBalance)}',
            ),
            trailing: Text(formatImpMoney(w.totalBalance)),
          ),
        ),
      ],
    );
  }
}

class _DistributionList extends StatelessWidget {
  const _DistributionList({
    required this.distributions,
    this.onEdit,
    this.onStatusChanged,
  });

  final List<ImpDistribution> distributions;
  final ValueChanged<ImpDistribution>? onEdit;
  final void Function(ImpDistribution, DistributionStatus)? onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat.MMMd();
    if (distributions.isEmpty) {
      return const _EmptyState(
        icon: LucideIcons.banknote,
        message: 'No distributions have been scheduled.',
      );
    }
    return Column(
      children: distributions.map((d) {
        final when = d.paidAt ?? d.scheduledAt;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            d.status == DistributionStatus.paid
                ? LucideIcons.checkCircle
                : LucideIcons.clock,
            color: AppColors.gold,
            size: 18,
          ),
          title: Text(d.opportunityTitle ?? d.reference ?? 'Distribution'),
          subtitle: Text(
            '${d.investorName ?? d.investorId} · ${d.status.label}'
            '${when != null ? ' · ${fmt.format(when)}' : ''}',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                d.amountDisplay,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (onEdit != null)
                IconButton(
                  tooltip: 'Edit distribution',
                  onPressed: () => onEdit!(d),
                  icon: const Icon(LucideIcons.edit3, size: 17),
                ),
              if (onStatusChanged != null)
                PopupMenuButton<DistributionStatus>(
                  tooltip: 'Change distribution status',
                  onSelected: (status) => onStatusChanged!(d, status),
                  itemBuilder: (context) => DistributionStatus.values
                      .map(
                        (status) => PopupMenuItem(
                          value: status,
                          child: Text(status.label),
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _AlertList extends StatelessWidget {
  const _AlertList({required this.alerts, this.onStatusChanged});

  final List<ImpAlert> alerts;
  final void Function(ImpAlert, String)? onStatusChanged;

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) {
      return const _EmptyState(
        icon: LucideIcons.bell,
        message: 'There are no investor alerts.',
      );
    }
    return Column(
      children: alerts.map((a) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            LucideIcons.bell,
            size: 18,
            color:
                a.severity == AlertSeverity.critical ||
                    a.severity == AlertSeverity.high
                ? Colors.redAccent
                : AppColors.gold,
          ),
          title: Text(a.title),
          subtitle: Text(
            '${a.severity.label} · ${a.status}${a.body != null ? '\n${a.body}' : ''}',
          ),
          isThreeLine: a.body != null,
          trailing: onStatusChanged == null
              ? null
              : PopupMenuButton<String>(
                  tooltip: 'Update alert',
                  onSelected: (status) => onStatusChanged!(a, status),
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'acknowledged',
                      child: Text('Acknowledge'),
                    ),
                    PopupMenuItem(value: 'resolved', child: Text('Resolve')),
                    PopupMenuItem(value: 'dismissed', child: Text('Dismiss')),
                  ],
                ),
        );
      }).toList(),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _Imp360Section {
  static const profile = 0;
  static const compliance = 1;
  static const capital = 2;
  static const engage = 3;
  static const reports = 4;
  static const construction = 5;

  static const labels = <String>[
    'Profile',
    'Compliance',
    'Capital',
    'Engage',
    'Reports',
    'Construction',
  ];
}

class _Investor360Panel extends ConsumerStatefulWidget {
  const _Investor360Panel({
    required this.investor,
    required this.investors,
    required this.opportunities,
    required this.holdings,
    required this.distributions,
    required this.activities,
    required this.canInvite,
    required this.canManageKyc,
    required this.canNotify,
    required this.canAssignInvestments,
    required this.canPublishDocuments,
    required this.canMessage,
    required this.canManageReports,
    required this.canManageReferrals,
    required this.canAssignOwner,
    required this.canManageTasks,
    required this.onSelectInvestor,
    required this.service,
    this.wallet,
    this.documents = const [],
    this.conversations = const [],
    this.reports = const [],
    this.statements = const [],
    this.referrals = const [],
    this.onChanged,
  });

  final ImpInvestor investor;
  final List<ImpInvestor> investors;
  final List<ImpOpportunity> opportunities;
  final List<ImpHolding> holdings;
  final List<ImpDistribution> distributions;
  final List<ImpActivity> activities;
  final List<ImpVaultDocument> documents;
  final List<ImpConversation> conversations;
  final List<ImpReport> reports;
  final List<ImpStatement> statements;
  final List<ImpReferralCommission> referrals;
  final bool canInvite;
  final bool canManageKyc;
  final bool canNotify;
  final bool canAssignInvestments;
  final bool canPublishDocuments;
  final bool canMessage;
  final bool canManageReports;
  final bool canManageReferrals;
  final bool canAssignOwner;
  final bool canManageTasks;
  final ImpWallet? wallet;
  final ValueChanged<String> onSelectInvestor;
  final ImpService service;
  final ValueChanged<String>? onChanged;

  @override
  ConsumerState<_Investor360Panel> createState() => _Investor360PanelState();
}

class _Investor360PanelState extends ConsumerState<_Investor360Panel> {
  bool _verifying = false;
  bool _notifying = false;
  bool _assigning = false;
  bool _publishingDoc = false;
  bool _messaging = false;
  bool _inviting = false;
  bool _assigningOwner = false;
  bool _savingTask = false;
  bool _publishingReport = false;
  bool _awardingReferral = false;
  String? _ownerStaffId;
  String _taskPriority = 'medium';
  final _notesCtrl = TextEditingController();
  final _notifyTitleCtrl = TextEditingController();
  final _notifyBodyCtrl = TextEditingController();
  final _assignLabelCtrl = TextEditingController();
  final _assignCostCtrl = TextEditingController();
  final _assignValueCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  final _taskTitleCtrl = TextEditingController();
  final _messageSubjectCtrl = TextEditingController(
    text: 'Message from HD Homes',
  );
  final _reportTitleCtrl = TextEditingController();
  final _reportPeriodCtrl = TextEditingController();
  final _reportUrlCtrl = TextEditingController();
  final _referralAmountCtrl = TextEditingController();
  final _referralCodeCtrl = TextEditingController();
  String _notifyRoute = '/investor/notifications';
  String? _opportunityId;
  String? _documentId;
  String? _replyConversationId;
  String _reportType = 'portfolio';
  String _referralStatus = 'pending';
  int _section = _Imp360Section.profile;
  List<({String id, String title})> _documents = const [];
  bool _docsLoaded = false;
  Object? _docsError;
  List<ImpLedgerEntry> _ledgerEntries = const [];
  List<ImpKycDocument> _kycDocuments = const [];
  bool _detailsLoaded = false;
  Object? _detailsError;

  @override
  void initState() {
    super.initState();
    _referralCodeCtrl.text = widget.investor.shareableReferralCode ?? '';
    _loadInvestorDetails();
    if (widget.canPublishDocuments) {
      _loadDocuments();
    } else {
      _docsLoaded = true;
    }
  }

  @override
  void didUpdateWidget(covariant _Investor360Panel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.investor.id != widget.investor.id) {
      _opportunityId = null;
      _documentId = null;
      _replyConversationId = null;
      _reportType = 'portfolio';
      _referralStatus = 'pending';
      _section = _Imp360Section.profile;
      _reportTitleCtrl.clear();
      _reportPeriodCtrl.clear();
      _reportUrlCtrl.clear();
      _referralAmountCtrl.clear();
      _referralCodeCtrl.text = widget.investor.shareableReferralCode ?? '';
      _messageSubjectCtrl.text = 'Message from HD Homes';
      _loadInvestorDetails();
    }
  }

  Future<void> _loadInvestorDetails() async {
    setState(() {
      _detailsLoaded = false;
      _detailsError = null;
    });
    try {
      final ledger = await widget.service.listInvestorLedger(
        widget.investor.id,
      );
      final kycDocuments = await widget.service.listInvestorKycDocuments(
        widget.investor.id,
      );
      if (!mounted) return;
      setState(() {
        _ledgerEntries = ledger;
        _kycDocuments = kycDocuments;
        _detailsLoaded = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _detailsError = error;
        _detailsLoaded = true;
      });
    }
  }

  Future<void> _loadDocuments() async {
    setState(() {
      _docsLoaded = false;
      _docsError = null;
    });
    try {
      final docs = await widget.service.listPublishableDocuments();
      if (!mounted) return;
      setState(() {
        _documents = docs;
        _docsLoaded = true;
        if (_documentId == null && docs.isNotEmpty) {
          _documentId = docs.first.id;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _docsError = error;
        _docsLoaded = true;
        _documents = const [];
      });
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _notifyTitleCtrl.dispose();
    _notifyBodyCtrl.dispose();
    _assignLabelCtrl.dispose();
    _assignCostCtrl.dispose();
    _assignValueCtrl.dispose();
    _messageCtrl.dispose();
    _taskTitleCtrl.dispose();
    _messageSubjectCtrl.dispose();
    _reportTitleCtrl.dispose();
    _reportPeriodCtrl.dispose();
    _reportUrlCtrl.dispose();
    _referralAmountCtrl.dispose();
    _referralCodeCtrl.dispose();
    super.dispose();
  }

  void _refresh(String message) => widget.onChanged?.call(message);

  Future<void> _inviteToPortal() async {
    final investor = widget.investor;
    final email = investor.email?.trim() ?? '';
    if (!email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add an email before inviting to portal')),
      );
      return;
    }
    if ((investor.userId ?? '').isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Investor already has portal access')),
      );
      return;
    }
    setState(() => _inviting = true);
    try {
      final parts = investor.fullName.trim().split(RegExp(r'\s+'));
      final first = parts.isEmpty ? null : parts.first;
      final last = parts.length > 1 ? parts.sublist(1).join(' ') : null;
      var invite = await ref
          .read(organizationServiceProvider)
          .invitePortalUser(
            email: email,
            roleSlug: 'investor',
            firstName: first,
            lastName: last,
            phone: investor.phone,
            investorId: investor.id,
          );
      if (!mounted) return;
      if (invite.status == 'accepted') {
        _refresh('Portal access linked');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Portal access linked for ${invite.email}')),
        );
        return;
      }
      if (!invite.hasUsableToken) {
        invite = await ref
            .read(organizationServiceProvider)
            .revealPortalInviteToken(invite.id);
      }
      final path = OrganizationService.portalInviteRegisterPath(invite);
      final link = '${Uri.base.origin}/#$path';
      await Clipboard.setData(ClipboardData(text: link));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Portal invite link copied — share securely'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(e))));
    } finally {
      if (mounted) setState(() => _inviting = false);
    }
  }

  Future<void> _verify(KycStatus status) async {
    setState(() => _verifying = true);
    try {
      await widget.service.verifyInvestorKyc(
        investorId: widget.investor.id,
        status: status,
        notes: _notesCtrl.text,
      );
      _refresh('KYC status updated');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('KYC set to ${status.label}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('KYC update failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  String _categoryForRoute(String route) {
    if (route.contains('payment')) return 'payments';
    if (route.contains('construction')) return 'construction';
    if (route.contains('document')) return 'documents';
    if (route.contains('report')) return 'reports';
    if (route.contains('message')) return 'messages';
    if (route.contains('setting')) return 'kyc';
    if (route.contains('referral')) return 'referrals';
    return 'general';
  }

  Future<void> _publishNotification() async {
    final title = _notifyTitleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification title is required')),
      );
      return;
    }
    setState(() => _notifying = true);
    try {
      await widget.service.publishInvestorNotification(
        investorId: widget.investor.id,
        title: title,
        body: _notifyBodyCtrl.text.trim().isEmpty
            ? null
            : _notifyBodyCtrl.text.trim(),
        route: _notifyRoute,
        category: _categoryForRoute(_notifyRoute),
      );
      _refresh('Notification sent');
      _notifyTitleCtrl.clear();
      _notifyBodyCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification sent to investor')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Notify failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _notifying = false);
    }
  }

  Future<void> _assignHolding() async {
    final label = _assignLabelCtrl.text.trim();
    final cost = double.tryParse(_assignCostCtrl.text.trim());
    final value = double.tryParse(_assignValueCtrl.text.trim());
    if (label.isEmpty || cost == null || cost < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Label and cost basis are required')),
      );
      return;
    }
    setState(() => _assigning = true);
    try {
      ImpOpportunity? opp;
      for (final o in widget.opportunities) {
        if (o.id == _opportunityId) {
          opp = o;
          break;
        }
      }
      await widget.service.assignInvestorHolding(
        investorId: widget.investor.id,
        label: label,
        costBasis: cost,
        currentValue: value ?? cost,
        opportunityId: _opportunityId,
        propertyId: opp?.propertyId,
      );
      _refresh('Investment assigned');
      _assignLabelCtrl.clear();
      _assignCostCtrl.clear();
      _assignValueCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Holding assigned to investor')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Assign failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _assigning = false);
    }
  }

  Future<void> _publishDocument() async {
    final docId = _documentId;
    if (docId == null || docId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a document to publish')),
      );
      return;
    }
    setState(() => _publishingDoc = true);
    try {
      String? title;
      for (final d in _documents) {
        if (d.id == docId) {
          title = d.title;
          break;
        }
      }
      await widget.service.publishDocumentToInvestor(
        documentId: docId,
        investorId: widget.investor.id,
        title: title,
      );
      _refresh('Document published to investor vault');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Document published')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Publish failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _publishingDoc = false);
    }
  }

  Future<void> _sendMessage() async {
    final body = _messageCtrl.text.trim();
    if (body.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Message body is required')));
      return;
    }
    setState(() => _messaging = true);
    try {
      await widget.service.messageInvestor(
        investorId: widget.investor.id,
        body: body,
        subject: _messageSubjectCtrl.text.trim().isEmpty
            ? 'Message from HD Homes'
            : _messageSubjectCtrl.text.trim(),
        conversationId: _replyConversationId,
      );
      _refresh('Message sent to investor');
      _messageCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Message delivered')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFacingError(e))));
      }
    } finally {
      if (mounted) setState(() => _messaging = false);
    }
  }

  Future<void> _publishReport() async {
    final title = _reportTitleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report title is required')),
      );
      return;
    }
    setState(() => _publishingReport = true);
    try {
      final period = _reportPeriodCtrl.text.trim();
      final url = _reportUrlCtrl.text.trim();
      await widget.service.publishInvestorReport(
        investorId: widget.investor.id,
        title: title,
        reportType: _reportType,
        periodLabel: period.isEmpty ? null : period,
        fileUrl: url.isEmpty ? null : url,
      );
      _refresh('Report published');
      _reportTitleCtrl.clear();
      _reportPeriodCtrl.clear();
      _reportUrlCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report published to investor')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFacingError(e))));
      }
    } finally {
      if (mounted) setState(() => _publishingReport = false);
    }
  }

  Future<void> _saveReferralCode() async {
    setState(() => _awardingReferral = true);
    try {
      await widget.service.setInvestorReferralCode(
        investorId: widget.investor.id,
        code: _referralCodeCtrl.text.trim(),
      );
      _refresh('Referral code saved');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _referralCodeCtrl.text.trim().isEmpty
                  ? 'Referral code cleared'
                  : 'Referral code is live in the investor portal',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFacingError(e))));
      }
    } finally {
      if (mounted) setState(() => _awardingReferral = false);
    }
  }

  Future<void> _awardReferral() async {
    final amount = double.tryParse(_referralAmountCtrl.text.trim());
    if (amount == null || amount < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Referral amount is required')),
      );
      return;
    }
    setState(() => _awardingReferral = true);
    try {
      final code = _referralCodeCtrl.text.trim();
      await widget.service.awardInvestorReferral(
        investorId: widget.investor.id,
        amount: amount,
        referralCode: code.isEmpty ? null : code,
        status: _referralStatus,
      );
      if (code.isNotEmpty) {
        await widget.service.setInvestorReferralCode(
          investorId: widget.investor.id,
          code: code,
        );
      }
      _refresh('Referral commission recorded');
      _referralAmountCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Referral commission awarded')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFacingError(e))));
      }
    } finally {
      if (mounted) setState(() => _awardingReferral = false);
    }
  }

  Future<void> _assignOwner() async {
    final staffId = _ownerStaffId;
    if (staffId == null || staffId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a relationship manager')),
      );
      return;
    }
    setState(() => _assigningOwner = true);
    try {
      await widget.service.assignInvestorOwner(
        investorId: widget.investor.id,
        staffId: staffId,
      );
      _refresh('Investor owner assigned');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Owner assignment saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _assigningOwner = false);
    }
  }

  Future<void> _createTask() async {
    final title = _taskTitleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task title is required')),
      );
      return;
    }
    setState(() => _savingTask = true);
    try {
      await widget.service.saveInvestorTask(
        investorId: widget.investor.id,
        title: title,
        priority: _taskPriority,
        assignedTo: widget.investor.assignedStaffId,
      );
      _taskTitleCtrl.clear();
      _refresh('Investor task created');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Task created')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _savingTask = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final investor = widget.investor;
    final investors = widget.investors;
    final holdings = widget.holdings;
    final distributions = widget.distributions;
    final activities = widget.activities;
    final wallet = widget.wallet;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey(investor.id),
          initialValue: investor.id,
          decoration: const InputDecoration(
            labelText: 'Investor',
            isDense: true,
          ),
          items: investors
              .map(
                (i) => DropdownMenuItem(value: i.id, child: Text(i.fullName)),
              )
              .toList(),
          onChanged: (id) {
            if (id != null) widget.onSelectInvestor(id);
          },
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(label: Text(investor.investorType.label)),
            Chip(label: Text(investor.lifecycleStatus.label)),
            Chip(label: Text('KYC ${investor.kycStatus.label}')),
            Chip(label: Text(investor.riskLevel.label)),
            ...investor.tags.map((t) => Chip(label: Text(t))),
          ],
        ),
        const SizedBox(height: 12),
        _ImpSegmentBar(
          labels: _Imp360Section.labels,
          selectedIndex: _section,
          onSelected: (i) => setState(() => _section = i),
        ),
        if (_section == _Imp360Section.profile) ...[
        if (investor.assignedStaffName != null ||
            investor.assignedStaffId != null) ...[
          const SizedBox(height: 8),
          Text(
            'Owner: ${investor.assignedStaffName ?? investor.assignedStaffId}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
        if (widget.canAssignOwner) ...[
          const SizedBox(height: 16),
          Text(
            'Relationship ownership',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          ref
              .watch(impInvestorManagersProvider)
              .when(
                loading: () => const LinearProgressIndicator(),
                error: (error, _) => Text(userFacingError(error)),
                data: (managers) {
                  final assignedId = investor.assignedStaffId;
                  final assignedInList = assignedId != null &&
                      managers.any((manager) => manager.id == assignedId);
                  final selected = _ownerStaffId ??
                      (assignedInList ? assignedId : null) ??
                      (managers.isEmpty ? null : managers.first.id);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
                        key: ValueKey('owner-${investor.id}-$selected'),
                        initialValue: selected,
                        decoration: const InputDecoration(
                          labelText: 'Relationship manager',
                          isDense: true,
                        ),
                        items: [
                          if (assignedId != null && !assignedInList)
                            DropdownMenuItem(
                              value: assignedId,
                              child: Text(
                                investor.assignedStaffName == null ||
                                        investor.assignedStaffName!.isEmpty
                                    ? 'Current owner (inactive)'
                                    : '${investor.assignedStaffName} (inactive)',
                              ),
                            ),
                          ...managers.map(
                            (manager) => DropdownMenuItem(
                              value: manager.id,
                              child: Text(
                                manager.email == null ||
                                        manager.email!.isEmpty
                                    ? manager.name
                                    : '${manager.name} (${manager.email})',
                              ),
                            ),
                          ),
                        ],
                        onChanged: _assigningOwner
                            ? null
                            : (value) =>
                                  setState(() => _ownerStaffId = value),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: _assigningOwner || managers.isEmpty
                            ? null
                            : () {
                                _ownerStaffId ??= selected;
                                _assignOwner();
                              },
                        icon: const Icon(LucideIcons.userCheck, size: 16),
                        label: const Text('Assign owner'),
                      ),
                      if (_assigningOwner) ...[
                        const SizedBox(height: 8),
                        const LinearProgressIndicator(),
                      ],
                    ],
                  );
                },
              ),
        ],
        if (widget.canManageTasks) ...[
          const SizedBox(height: 16),
          Text(
            'Follow-up task',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _taskTitleCtrl,
            decoration: const InputDecoration(
              labelText: 'Task title',
              isDense: true,
            ),
            enabled: !_savingTask,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: ValueKey('task-priority-${investor.id}-$_taskPriority'),
            initialValue: _taskPriority,
            decoration: const InputDecoration(
              labelText: 'Priority',
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(value: 'low', child: Text('Low')),
              DropdownMenuItem(value: 'medium', child: Text('Medium')),
              DropdownMenuItem(value: 'high', child: Text('High')),
              DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
            ],
            onChanged: _savingTask
                ? null
                : (value) {
                    if (value != null) setState(() => _taskPriority = value);
                  },
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _savingTask ? null : _createTask,
            icon: const Icon(LucideIcons.listChecks, size: 16),
            label: const Text('Create task'),
          ),
          if (_savingTask) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
          ],
        ],
        const SizedBox(height: 12),
        Text(
          'AUM ${investor.aumDisplay} · Committed ${formatImpMoney(investor.totalCommitted)}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        if (investor.email != null) Text(investor.email!),
        if (investor.company != null) Text(investor.company!),
        const SizedBox(height: 8),
        if ((investor.userId ?? '').isNotEmpty)
          const Text(
            'Portal linked',
            style: TextStyle(fontWeight: FontWeight.w600),
          )
        else if (widget.canInvite)
          FilledButton.icon(
            onPressed: _inviting ? null : _inviteToPortal,
            icon: const Icon(LucideIcons.userPlus, size: 16),
            label: Text(_inviting ? 'Inviting…' : 'Invite to portal'),
          ),
        if (widget.canInvite && _inviting) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
        ],
        if (wallet != null) ...[
          const SizedBox(height: 8),
          Text('Wallet available ${formatImpMoney(wallet.availableBalance)}'),
        ],
        const SizedBox(height: 12),
        ],
        if (_section == _Imp360Section.compliance) ...[
        if (widget.canManageKyc) ...[
          const SizedBox(height: 12),
          Text(
            'KYC verification',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _notesCtrl,
            decoration: const InputDecoration(
              labelText: 'Review notes (optional)',
              isDense: true,
            ),
            maxLines: 2,
            enabled: !_verifying,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: _verifying
                    ? null
                    : () => _verify(KycStatus.underReview),
                child: const Text('Under review'),
              ),
              FilledButton(
                onPressed: _verifying
                    ? null
                    : () => _verify(KycStatus.approved),
                child: const Text('Approve'),
              ),
              OutlinedButton(
                onPressed: _verifying
                    ? null
                    : () => _verify(KycStatus.rejected),
                child: const Text('Reject'),
              ),
              OutlinedButton(
                onPressed: _verifying
                    ? null
                    : () => _verify(KycStatus.needsResubmission),
                child: const Text('Needs resubmission'),
              ),
            ],
          ),
          if (_verifying) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
          ],
        ],
        if (widget.canPublishDocuments || widget.documents.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Document vault',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          if (widget.documents.isEmpty)
            const Text('No vault documents yet.')
          else
            ...widget.documents.map(
              (doc) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(LucideIcons.fileText, size: 18),
                title: Text(doc.title),
                subtitle: Text('${doc.documentType} · v${doc.version}'),
              ),
            ),
          if (widget.canPublishDocuments) ...[
            const SizedBox(height: 8),
            Text(
              'Publish document',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            if (!_docsLoaded)
              const LinearProgressIndicator()
            else if (_docsError != null)
              Text(
                userFacingError(
                  _docsError!,
                  fallback: 'Unable to load publishable documents.',
                ),
              )
            else if (_documents.isEmpty)
              const Text('No documents available to publish.')
            else ...[
              DropdownButtonFormField<String>(
                key: ValueKey('doc-${investor.id}-$_documentId'),
                initialValue: _documentId,
                decoration: const InputDecoration(
                  labelText: 'Document',
                  isDense: true,
                ),
                items: _documents
                    .map(
                      (d) => DropdownMenuItem(
                        value: d.id,
                        child: Text(d.title, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: _publishingDoc
                    ? null
                    : (v) {
                        if (v != null) setState(() => _documentId = v);
                      },
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _publishingDoc ? null : _publishDocument,
                icon: const Icon(LucideIcons.fileUp, size: 16),
                label: const Text('Publish to vault'),
              ),
              if (_publishingDoc) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(),
              ],
            ],
          ],
        ],
        Text(
          'KYC evidence',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (!_detailsLoaded)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          )
        else if (_detailsError != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              userFacingError(
                _detailsError!,
                fallback: 'Unable to load KYC evidence.',
              ),
            ),
          )
        else if (_kycDocuments.isEmpty)
          const Text('No KYC evidence linked.')
        else
          ..._kycDocuments.map(
            (document) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(LucideIcons.fileCheck2, size: 18),
              title: Text(document.documentType.replaceAll('_', ' ')),
              trailing: Chip(label: Text(document.verificationStatus)),
            ),
          ),
        ],
        if (_section == _Imp360Section.capital) ...[
        if (widget.canAssignInvestments) ...[
          const SizedBox(height: 16),
          Text(
            'Assign investment',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String?>(
            key: ValueKey('opp-${investor.id}-$_opportunityId'),
            initialValue: _opportunityId,
            decoration: const InputDecoration(
              labelText: 'Opportunity (optional)',
              isDense: true,
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('No opportunity'),
              ),
              ...widget.opportunities.map(
                (o) => DropdownMenuItem<String?>(
                  value: o.id,
                  child: Text(o.title, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            onChanged: _assigning
                ? null
                : (v) {
                    setState(() {
                      _opportunityId = v;
                      if (v != null) {
                        ImpOpportunity? opp;
                        for (final o in widget.opportunities) {
                          if (o.id == v) {
                            opp = o;
                            break;
                          }
                        }
                        if (opp != null &&
                            _assignLabelCtrl.text.trim().isEmpty) {
                          _assignLabelCtrl.text = opp.title;
                        }
                      }
                    });
                  },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _assignLabelCtrl,
            decoration: const InputDecoration(
              labelText: 'Holding label',
              isDense: true,
            ),
            enabled: !_assigning,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _assignCostCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Cost basis (₦)',
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  enabled: !_assigning,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _assignValueCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Current value (₦)',
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  enabled: !_assigning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _assigning ? null : _assignHolding,
            icon: const Icon(LucideIcons.briefcase, size: 16),
            label: const Text('Assign holding'),
          ),
          if (_assigning) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
          ],
        ],
        Text(
          'Canonical ledger',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (!_detailsLoaded)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          )
        else if (_detailsError != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              userFacingError(
                _detailsError!,
                fallback: 'Unable to load investor financial history.',
              ),
            ),
          )
        else if (_ledgerEntries.isEmpty)
          const Text('No posted ledger entries.')
        else
          ..._ledgerEntries.map(
            (entry) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(
                entry.direction == 'in'
                    ? LucideIcons.arrowDownLeft
                    : LucideIcons.arrowUpRight,
                size: 18,
              ),
              title: Text(entry.transactionType.replaceAll('_', ' ')),
              subtitle: Text(
                [
                  if (entry.reference != null) entry.reference!,
                  if (entry.postedAt != null)
                    DateFormat.yMMMd().format(entry.postedAt!),
                ].join(' · '),
              ),
              trailing: Text(
                '${entry.direction == 'out' ? '−' : '+'}${formatImpMoney(entry.amount)}',
              ),
            ),
          ),
        const SizedBox(height: 12),
        if (holdings.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Holdings',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          ...holdings.map(
            (h) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(h.label),
              trailing: Text(formatImpMoney(h.currentValue)),
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (distributions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Distributions',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          ...distributions.map(
            (d) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(d.status.label),
              trailing: Text(d.amountDisplay),
            ),
          ),
        ],
        ],
        if (_section == _Imp360Section.engage) ...[
        if (!widget.canNotify && !widget.canMessage)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              'Read-only: you can review conversations, but notify/message actions require communicate permission.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (widget.canNotify) ...[
          const SizedBox(height: 16),
          Text(
            'Notify investor',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _notifyTitleCtrl,
            decoration: const InputDecoration(
              labelText: 'Title',
              isDense: true,
            ),
            enabled: !_notifying,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notifyBodyCtrl,
            decoration: const InputDecoration(
              labelText: 'Body (optional)',
              isDense: true,
            ),
            maxLines: 2,
            enabled: !_notifying,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: ValueKey('route-${investor.id}-$_notifyRoute'),
            initialValue: _notifyRoute,
            decoration: const InputDecoration(
              labelText: 'Deep link',
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(value: '/investor', child: Text('Dashboard')),
              DropdownMenuItem(
                value: '/investor/payments',
                child: Text('Payments'),
              ),
              DropdownMenuItem(
                value: '/investor/construction',
                child: Text('Construction'),
              ),
              DropdownMenuItem(
                value: '/investor/documents',
                child: Text('Documents'),
              ),
              DropdownMenuItem(
                value: '/investor/reports',
                child: Text('Reports'),
              ),
              DropdownMenuItem(
                value: '/investor/messages',
                child: Text('Messages'),
              ),
              DropdownMenuItem(
                value: '/investor/referrals',
                child: Text('Referrals'),
              ),
              DropdownMenuItem(
                value: '/investor/settings',
                child: Text('Settings / KYC'),
              ),
              DropdownMenuItem(
                value: '/investor/notifications',
                child: Text('Notifications'),
              ),
            ],
            onChanged: _notifying
                ? null
                : (v) {
                    if (v != null) setState(() => _notifyRoute = v);
                  },
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _notifying ? null : _publishNotification,
            icon: const Icon(LucideIcons.bell, size: 16),
            label: const Text('Send notification'),
          ),
          if (_notifying) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
          ],
        ],
        if (widget.canMessage) ...[
          const SizedBox(height: 16),
          Text(
            'Conversations',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          if (widget.conversations.isEmpty)
            const Text('No conversations yet.')
          else
            ...widget.conversations.map(
              (c) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                selected: _replyConversationId == c.id,
                leading: const Icon(LucideIcons.messagesSquare, size: 18),
                title: Text(c.subject),
                subtitle: Text(
                  [
                    c.status,
                    if ((c.lastMessagePreview ?? '').isNotEmpty)
                      c.lastMessagePreview!,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  tooltip: 'Open in Support',
                  icon: const Icon(LucideIcons.externalLink, size: 16),
                  onPressed: () {
                    context.go(
                      '${RoutePaths.dashboardSupport}'
                      '?tab=clientMessages'
                      '&kind=investor'
                      '&conversation=${c.id}',
                    );
                  },
                ),
                onTap: _messaging
                    ? null
                    : () {
                        setState(() {
                          _replyConversationId = c.id;
                          _messageSubjectCtrl.text = c.subject;
                        });
                      },
              ),
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                final id = _replyConversationId ??
                    (widget.conversations.isNotEmpty
                        ? widget.conversations.first.id
                        : null);
                if (id == null) {
                  context.go(
                    '${RoutePaths.dashboardSupport}?tab=clientMessages',
                  );
                  return;
                }
                context.go(
                  '${RoutePaths.dashboardSupport}'
                  '?tab=clientMessages'
                  '&kind=investor'
                  '&conversation=$id',
                );
              },
              icon: const Icon(LucideIcons.headphones, size: 16),
              label: const Text('Open Account Messages'),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Message investor',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          if (_replyConversationId != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _messaging
                    ? null
                    : () {
                        setState(() {
                          _replyConversationId = null;
                          _messageSubjectCtrl.text = 'Message from HD Homes';
                        });
                      },
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('New thread'),
              ),
            ),
          TextField(
            controller: _messageSubjectCtrl,
            decoration: const InputDecoration(
              labelText: 'Subject',
              isDense: true,
            ),
            enabled: !_messaging,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _messageCtrl,
            decoration: const InputDecoration(
              labelText: 'Message',
              isDense: true,
            ),
            maxLines: 3,
            enabled: !_messaging,
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _messaging ? null : _sendMessage,
            icon: const Icon(LucideIcons.messageSquare, size: 16),
            label: Text(
              _replyConversationId == null ? 'Send message' : 'Reply in thread',
            ),
          ),
          if (_messaging) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
          ],
        ],
        ],
        if (_section == _Imp360Section.reports) ...[
          const SizedBox(height: 16),
          Text(
            'Reports',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (!widget.canManageReports && !widget.canManageReferrals)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Read-only: publish and award actions require reports/referrals permission.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: 6),
          if (widget.reports.isEmpty)
            const Text('No reports yet.')
          else
            ...widget.reports.map(
              (r) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(LucideIcons.fileBarChart, size: 18),
                title: Text(r.title),
                subtitle: Text(
                  [
                    r.reportType,
                    if ((r.periodLabel ?? '').isNotEmpty) r.periodLabel!,
                  ].join(' · '),
                ),
              ),
            ),
          if (widget.statements.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Statements',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            ...widget.statements.map(
              (s) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(LucideIcons.fileSpreadsheet, size: 18),
                title: Text(s.periodLabel),
                subtitle: Text(
                  [
                    if (s.openingBalance != null)
                      'Open ${formatImpMoney(s.openingBalance!)}',
                    if (s.closingBalance != null)
                      'Close ${formatImpMoney(s.closingBalance!)}',
                    s.currency,
                  ].join(' · '),
                ),
              ),
            ),
          ],
          if (widget.canManageReports) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _reportTitleCtrl,
              decoration: const InputDecoration(
                labelText: 'Report title',
                isDense: true,
              ),
              enabled: !_publishingReport,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: ValueKey('report-type-${investor.id}-$_reportType'),
              initialValue: _reportType,
              decoration: const InputDecoration(
                labelText: 'Report type',
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: 'portfolio', child: Text('Portfolio')),
                DropdownMenuItem(
                  value: 'performance',
                  child: Text('Performance'),
                ),
                DropdownMenuItem(value: 'tax', child: Text('Tax')),
                DropdownMenuItem(
                  value: 'compliance',
                  child: Text('Compliance'),
                ),
                DropdownMenuItem(value: 'market', child: Text('Market')),
                DropdownMenuItem(value: 'custom', child: Text('Custom')),
              ],
              onChanged: _publishingReport
                  ? null
                  : (v) {
                      if (v != null) setState(() => _reportType = v);
                    },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reportPeriodCtrl,
              decoration: const InputDecoration(
                labelText: 'Period label (optional)',
                isDense: true,
              ),
              enabled: !_publishingReport,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reportUrlCtrl,
              decoration: const InputDecoration(
                labelText: 'File URL (optional)',
                isDense: true,
              ),
              enabled: !_publishingReport,
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _publishingReport ? null : _publishReport,
              icon: const Icon(LucideIcons.fileBarChart, size: 16),
              label: const Text('Publish report'),
            ),
            if (_publishingReport) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
            ],
          ],
          const SizedBox(height: 16),
          Text(
            'Referrals',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          if (widget.referrals.isEmpty)
            const Text('No referral commissions yet.')
          else
            ...widget.referrals.map(
              (r) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(LucideIcons.gift, size: 18),
                title: Text(
                  '${formatImpMoney(r.amount)} ${r.currency}',
                ),
                subtitle: Text(
                  [
                    r.status,
                    if ((r.referralCode ?? '').isNotEmpty) r.referralCode!,
                  ].join(' · '),
                ),
              ),
            ),
          if (widget.canManageReferrals) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _referralAmountCtrl,
              decoration: const InputDecoration(
                labelText: 'Commission amount',
                isDense: true,
              ),
              keyboardType: TextInputType.number,
              enabled: !_awardingReferral,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _referralCodeCtrl,
              decoration: InputDecoration(
                labelText: 'Shareable referral code',
                isDense: true,
                helperText: widget.investor.shareableReferralCode == null
                    ? 'Investors only see a code after you save one here.'
                    : 'Shown live in the investor portal.',
              ),
              enabled: !_awardingReferral,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _awardingReferral ? null : _saveReferralCode,
                icon: const Icon(LucideIcons.save, size: 16),
                label: const Text('Save code'),
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: ValueKey('referral-status-${investor.id}-$_referralStatus'),
              initialValue: _referralStatus,
              decoration: const InputDecoration(
                labelText: 'Status',
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: 'pending', child: Text('Pending')),
                DropdownMenuItem(value: 'approved', child: Text('Approved')),
                DropdownMenuItem(value: 'paid', child: Text('Paid')),
              ],
              onChanged: _awardingReferral
                  ? null
                  : (v) {
                      if (v != null) setState(() => _referralStatus = v);
                    },
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _awardingReferral ? null : _awardReferral,
              icon: const Icon(LucideIcons.gift, size: 16),
              label: const Text('Award referral'),
            ),
            if (_awardingReferral) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
            ],
          ],
        ],
        if (_section == _Imp360Section.construction) ...[
          Builder(
            builder: (context) {
              final constructionAsync =
                  ref.watch(impInvestorConstructionProvider(investor.id));
              return ImpConstruction360Panel(
                snapshot: constructionAsync.asData?.value,
                loading: constructionAsync.isLoading,
                error: constructionAsync.hasError
                    ? userFacingError(
                        constructionAsync.error!,
                        fallback: 'Unable to load construction progress.',
                      )
                    : null,
                onOpenConstructionDesk: () =>
                    context.go(RoutePaths.dashboardConstruction),
              );
            },
          ),
          if (activities.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Recent activity',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            ...activities
                .take(5)
                .map(
                  (a) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(a.title),
                    subtitle:
                        a.description != null ? Text(a.description!) : null,
                  ),
                ),
          ],
        ],
      ],
    );
  }
}
