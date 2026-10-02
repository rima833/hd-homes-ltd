import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/constants/permissions.dart';
import 'package:hdhomesproject/core/widgets/offline_updates_note.dart';
import 'package:hdhomesproject/features/authentication/presentation/widgets/permission_gate.dart';
import 'package:hdhomesproject/features/fapms/domain/entities/fapms_models.dart';
import 'package:hdhomesproject/features/fapms/domain/services/fapms_service.dart';
import 'package:hdhomesproject/features/fapms/presentation/pages/payment_verification_page.dart';
import 'package:hdhomesproject/features/fapms/presentation/providers/fapms_controller.dart';
import 'package:hdhomesproject/features/fapms/presentation/widgets/finance_command_center_shell.dart';
import 'package:hdhomesproject/features/fapms/presentation/widgets/finance_admin_shared.dart';
import 'package:hdhomesproject/features/fapms/presentation/widgets/finance_ops_panels.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Admin Finance Command Center — live ops shell for HD Homes money flows.
class FinanceCommandCenterPage extends ConsumerStatefulWidget {
  const FinanceCommandCenterPage({super.key});

  @override
  ConsumerState<FinanceCommandCenterPage> createState() =>
      _FinanceCommandCenterPageState();
}

class _FinanceCommandCenterPageState extends ConsumerState<FinanceCommandCenterPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _kpiScroll = ScrollController();
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _kpiScroll.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await ref.read(fapmsControllerProvider.notifier).refresh();
  }

  void _goTab(FapmsCommandTab tab) {
    ref.read(fapmsControllerProvider.notifier).setTab(tab);
  }

  void _openKpi(String label) {
    final l = label.toLowerCase();
    if (l.contains('cash')) {
      _goTab(FapmsCommandTab.banking);
    } else if (l.contains('receivable') ||
        l.contains(' ar') ||
        l == 'open ar' ||
        l.contains('invoice')) {
      _goTab(FapmsCommandTab.invoices);
    } else if (l.contains('payable') ||
        l.contains(' ap') ||
        l == 'open ap' ||
        l.contains('approval') ||
        l.contains('expense')) {
      _goTab(FapmsCommandTab.expenses);
    } else if (l.contains('installment') || l.contains('deposit')) {
      _goTab(FapmsCommandTab.installments);
    } else if (l.contains('lead')) {
      _goTab(FapmsCommandTab.leads);
    } else if (l.contains('commission')) {
      _goTab(FapmsCommandTab.commissions);
    } else if (l.contains('investor')) {
      _goTab(FapmsCommandTab.investor);
    } else if (l.contains('payment') || l.contains('charge')) {
      _goTab(FapmsCommandTab.payments);
    } else if (l.contains('pending') || l.contains('verif')) {
      _goTab(FapmsCommandTab.verification);
    }
  }

  Color _statusColor(String slug) {
    final s = slug.toLowerCase();
    if (s.contains('paid') ||
        s.contains('success') ||
        s.contains('approv') ||
        s.contains('confirm') ||
        s == 'active') {
      return FinanceAdminUi.success;
    }
    if (s.contains('overdue') ||
        s.contains('fail') ||
        s.contains('reject') ||
        s.contains('cancel')) {
      return FinanceAdminUi.danger;
    }
    if (s.contains('pending') || s.contains('draft') || s.contains('sent')) {
      return FinanceAdminUi.gold;
    }
    return FinanceAdminUi.info;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(fapmsRealtimeProvider);
    final asyncSnap = ref.watch(fapmsSnapshotProvider);
    final ui = ref.watch(fapmsControllerProvider);
    final controller = ref.read(fapmsControllerProvider.notifier);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: FinanceDeskColors.bg,
      drawer: MediaQuery.sizeOf(context).width < 1100
          ? Drawer(
              backgroundColor: FinanceDeskColors.sidebar,
              child: FinanceDeskSidebar(
                sections: asyncSnap.valueOrNull == null
                    ? const []
                    : buildFinanceNavSections(asyncSnap.requireValue),
                selected: ui.selectedTab,
                onSelect: (tab) {
                  controller.setTab(tab);
                  Navigator.pop(context);
                },
                live: asyncSnap.valueOrNull?.fromRemote ?? false,
                onClose: () => Navigator.pop(context),
              ),
            )
          : null,
      body: asyncSnap.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: FinanceDeskColors.gold),
        ),
        error: (_, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Could not load finance data',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                      ),
                ),
                const SizedBox(height: 8),
                const OfflineUpdatesNote(color: FinanceDeskColors.muted),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _refresh,
                  style: FilledButton.styleFrom(
                    backgroundColor: FinanceDeskColors.gold,
                    foregroundColor: FinanceDeskColors.bg,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (snap) {
          final wide = MediaQuery.sizeOf(context).width >= 1100;
          final navSections = buildFinanceNavSections(snap);

          Widget mainPane() {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FinanceDeskTopBar(
                  tab: ui.selectedTab,
                  live: snap.fromRemote,
                  loadedAt: snap.loadedAt,
                  showMenu: !wide,
                  onMenu: wide
                      ? null
                      : () => _scaffoldKey.currentState?.openDrawer(),
                  onRefresh: _refresh,
                  pendingVerify: snap.pendingClientVerifications,
                  onOpenVerification: () => _goTab(FapmsCommandTab.verification),
                  onCreateInvoice: () =>
                      showCreateInvoiceSheet(context: context, ref: ref),
                  onCreateExpense: () =>
                      showCreateExpenseSheet(context: context, ref: ref),
                ),
                if (ui.lastMessage != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: _MessageBanner(
                      message: ui.lastMessage!,
                      onDismiss: controller.clearMessage,
                    ),
                  ),
                if (financeTabShowsKpis(ui.selectedTab)) ...[
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: FinanceDeskKpiStrip(
                      kpis: snap.kpis,
                      scrollController: _kpiScroll,
                      onKpi: _openKpi,
                    ),
                  ),
                ],
                if (financeTabUsesSearch(ui.selectedTab)) ...[
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: FinanceDeskSearchBar(
                      controller: _searchCtrl,
                      statusFilter: ui.statusFilter,
                      onSearch: controller.setSearch,
                      onStatus: controller.setStatusFilter,
                      showStatus: financeTabUsesStatusFilter(ui.selectedTab),
                    ),
                  ),
                ],
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                    child: _FinanceTabBody(
                      snap: snap,
                      ui: ui,
                      statusColor: _statusColor,
                      onGoTab: _goTab,
                      onRefresh: _refresh,
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
                child: FinanceDeskSidebar(
                  sections: navSections,
                  selected: ui.selectedTab,
                  onSelect: controller.setTab,
                  live: snap.fromRemote,
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

class _FinanceTabBody extends ConsumerWidget {
  const _FinanceTabBody({
    required this.snap,
    required this.ui,
    required this.statusColor,
    required this.onGoTab,
    required this.onRefresh,
  });

  final FapmsCommandCenterSnapshot snap;
  final FapmsUiState ui;
  final Color Function(String) statusColor;
  final ValueChanged<FapmsCommandTab> onGoTab;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(fapmsControllerProvider.notifier);

    return switch (ui.selectedTab) {
      FapmsCommandTab.overview => _OverviewTab(
          snap: snap,
          onOpenTab: onGoTab,
          anomalies: FapmsService.detectAnomalies(snap),
          briefing: ref.read(fapmsServiceProvider).generateFinancialBriefing(snap),
          alerts: snap.alerts,
          loadWarnings: snap.loadWarnings,
          onAddBank: () => showCreateBankAccountSheet(context: context, ref: ref),
        ),
      FapmsCommandTab.verification =>
        const PaymentVerificationPage(embedded: true),
      FapmsCommandTab.payments => _PaymentsTab(
          payments: controller.filteredPayments(snap),
          receipts: snap.receipts,
          query: ui.searchQuery,
        ),
      FapmsCommandTab.installments => FinanceInstallmentsTab(snap: snap),
      FapmsCommandTab.invoices => _InvoicesTab(
          invoices: controller.filteredInvoices(snap),
          statusColor: statusColor,
          onCreate: () => showCreateInvoiceSheet(context: context, ref: ref),
          onMarkPaid: (id) async {
            await ref.read(fapmsServiceProvider).setInvoiceStatus(
                  invoiceId: id,
                  status: 'paid',
                );
            controller.setMessage('Invoice marked paid.');
            await onRefresh();
          },
        ),
      FapmsCommandTab.expenses => _ExpensesTab(
          expenses: controller.filteredExpenses(snap),
          pending: snap.pendingApprovals,
          statusColor: statusColor,
          onCreate: () => showCreateExpenseSheet(context: context, ref: ref),
          onApprove: (id) async {
            await ref.read(fapmsServiceProvider).updateExpenseStatus(
                  expenseId: id,
                  status: 'approved',
                );
            controller.setMessage('Expense approved.');
            await onRefresh();
          },
          onReject: (id) async {
            await ref.read(fapmsServiceProvider).updateExpenseStatus(
                  expenseId: id,
                  status: 'rejected',
                );
            controller.setMessage('Expense rejected.');
            await onRefresh();
          },
        ),
      FapmsCommandTab.banking => _BankingTab(
          accounts: snap.bankAccounts,
          txs: snap.bankTxs,
          onAddAccount: () =>
              showCreateBankAccountSheet(context: context, ref: ref),
          onRecordMovement: snap.bankAccounts.isEmpty
              ? null
              : () => showRecordBankMovementSheet(
                    context: context,
                    ref: ref,
                    accounts: snap.bankAccounts,
                  ),
        ),
      FapmsCommandTab.investor => FinanceInvestorOpsTab(
          snap: snap,
          onConfirmIntent: (id) async {
            await ref.read(fapmsServiceProvider).confirmInvestorIntent(
                  intentId: id,
                  status: 'confirmed',
                );
            controller.setMessage(
              'Investor transfer confirmed — payment, receipt & wallet updated.',
            );
            await onRefresh();
          },
          onRejectIntent: (id) async {
            await ref.read(fapmsServiceProvider).confirmInvestorIntent(
                  intentId: id,
                  status: 'rejected',
                );
            controller.setMessage('Investor transfer rejected.');
            await onRefresh();
          },
        ),
      FapmsCommandTab.leads => FinanceLeadsTab(snap: snap),
      FapmsCommandTab.commissions => FinanceCommissionsTab(snap: snap),
      FapmsCommandTab.setup => ListView(
          children: [
            FinancePaymentSettingsCard(settings: snap.paymentSettings),
            const SizedBox(height: 16),
            const ClientPaymentsSettingsPanel(),
          ],
        ),
    };
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: FinanceDeskColors.gold.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      child: ListTile(
        dense: true,
        leading: const Icon(
          LucideIcons.checkCircle2,
          color: FinanceDeskColors.gold,
          size: 18,
        ),
        title: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        trailing: IconButton(
          icon: const Icon(LucideIcons.x, size: 16, color: FinanceDeskColors.muted),
          onPressed: onDismiss,
        ),
      ),
    );
  }
}

class _LoadWarningsBanner extends StatelessWidget {
  const _LoadWarningsBanner({required this.warnings});

  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: FinanceAdminUi.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: FinanceAdminUi.danger.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            LucideIcons.alertTriangle,
            size: 16,
            color: FinanceAdminUi.danger,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Some finance data could not load',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                for (final w in warnings.take(4))
                  Text(
                    w,
                    style: const TextStyle(
                      color: FinanceAdminUi.muted,
                      fontSize: 12,
                    ),
                  ),
                if (warnings.length > 4)
                  Text(
                    '+ ${warnings.length - 4} more',
                    style: const TextStyle(
                      color: FinanceAdminUi.muted,
                      fontSize: 12,
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

class _AlertsBanner extends StatefulWidget {
  const _AlertsBanner({required this.alerts, required this.onOpenTab});

  final List<FapmsAlert> alerts;
  final ValueChanged<FapmsCommandTab> onOpenTab;

  @override
  State<_AlertsBanner> createState() => _AlertsBannerState();
}

class _AlertsBannerState extends State<_AlertsBanner> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final alerts = widget.alerts;
    final first = alerts.first;
    final preview = first.body == null || first.body!.isEmpty
        ? first.title
        : '${first.title} — ${first.body}';

    if (!_expanded) {
      return InkWell(
        onTap: () => setState(() => _expanded = true),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: FinanceAdminUi.gold.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: FinanceAdminUi.gold.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                LucideIcons.bell,
                size: 16,
                color: FinanceAdminUi.gold,
              ),
              const SizedBox(width: 8),
              Text(
                '${alerts.length} live alert${alerts.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: FinanceAdminUi.muted,
                    fontSize: 12,
                  ),
                ),
              ),
              const Icon(
                LucideIcons.chevronDown,
                size: 16,
                color: FinanceAdminUi.muted,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: FinanceAdminUi.gold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: FinanceAdminUi.gold.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.bell,
                size: 16,
                color: FinanceAdminUi.gold,
              ),
              const SizedBox(width: 8),
              Text(
                '${alerts.length} live alert${alerts.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => setState(() => _expanded = false),
                icon: const Icon(
                  LucideIcons.chevronUp,
                  size: 16,
                  color: FinanceAdminUi.muted,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final a in alerts.take(5))
            InkWell(
              onTap: () {
                final tab = _tabForAlert(a);
                if (tab != null) widget.onOpenTab(tab);
              },
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  a.body == null || a.body!.isEmpty
                      ? a.title
                      : '${a.title} — ${a.body}',
                  style: const TextStyle(
                    color: FinanceAdminUi.muted,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.snap,
    required this.onOpenTab,
    required this.anomalies,
    required this.briefing,
    required this.alerts,
    required this.loadWarnings,
    required this.onAddBank,
  });

  final FapmsCommandCenterSnapshot snap;
  final ValueChanged<FapmsCommandTab> onOpenTab;
  final List<String> anomalies;
  final String briefing;
  final List<FapmsAlert> alerts;
  final List<String> loadWarnings;
  final VoidCallback onAddBank;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 4),
      children: [
        if (loadWarnings.isNotEmpty) ...[
          _LoadWarningsBanner(warnings: loadWarnings),
          const SizedBox(height: 10),
        ],
        if (alerts.isNotEmpty) ...[
          _AlertsBanner(alerts: alerts, onOpenTab: onOpenTab),
          const SizedBox(height: 10),
        ],
        FinanceAdminCard(
          title: 'Ops briefing',
          subtitle: 'What needs attention across the site right now',
          child: Text(
            briefing,
            style: const TextStyle(
              color: Colors.white,
              height: 1.45,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 900;
            final queues = _QueuesCard(
              snap: snap,
              onOpenTab: onOpenTab,
            );
            final cash = FinanceAdminCard(
              title: 'Cash position',
              subtitle: 'Bank balances from live accounts',
              child: snap.bankAccounts.isEmpty
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'No operating account yet. Add one so cash on hand follows the real balance.',
                          style: TextStyle(color: FinanceAdminUi.muted),
                        ),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: FinanceAdminUi.gold,
                            foregroundColor: Colors.black,
                          ),
                          onPressed: onAddBank,
                          icon: const Icon(LucideIcons.plus, size: 16),
                          label: const Text('Add bank account'),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        for (final b in snap.bankAccounts.take(5))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    b.accountName,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                Text(
                                  b.balanceDisplay,
                                  style: const TextStyle(
                                    color: FinanceAdminUi.gold,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            );
            if (!wide) {
              return Column(
                children: [
                  queues,
                  const SizedBox(height: 12),
                  cash,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: queues),
                const SizedBox(width: 12),
                Expanded(child: cash),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 900;
            final ar = FinanceAdminCard(
              title: 'Receivables aging',
              trailing: TextButton(
                onPressed: () => onOpenTab(FapmsCommandTab.invoices),
                child: const Text('Invoices'),
              ),
              child: _AgingBars(buckets: snap.arBuckets),
            );
            final ap = FinanceAdminCard(
              title: 'Payables aging',
              trailing: TextButton(
                onPressed: () => onOpenTab(FapmsCommandTab.expenses),
                child: const Text('Expenses'),
              ),
              child: _AgingBars(buckets: snap.apBuckets),
            );
            if (!wide) {
              return Column(
                children: [
                  ar,
                  const SizedBox(height: 12),
                  ap,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: ar),
                const SizedBox(width: 12),
                Expanded(child: ap),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        FinanceAdminCard(
          title: 'Attention',
          subtitle: 'Anomalies from live ledger data',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final a in anomalies.take(8))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Icon(
                          LucideIcons.alertTriangle,
                          size: 14,
                          color: FinanceAdminUi.gold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          a,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FinanceAdminCard(
          title: 'Recent activity',
          child: snap.activities.isEmpty
              ? const Text(
                  'No finance activity logged yet.',
                  style: TextStyle(color: FinanceAdminUi.muted),
                )
              : Column(
                  children: [
                    for (final a in snap.activities.take(10))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: const Icon(
                          LucideIcons.activity,
                          size: 16,
                          color: FinanceAdminUi.muted,
                        ),
                        title: Text(
                          a.summary,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          [
                            if (a.actorLabel != null) a.actorLabel!,
                            if (a.occurredAt != null)
                              DateFormat('dd MMM · HH:mm')
                                  .format(a.occurredAt!.toLocal()),
                          ].join(' · '),
                          style: const TextStyle(
                            color: FinanceAdminUi.muted,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
        ),
        if (snap.budgets.isNotEmpty) ...[
          const SizedBox(height: 12),
          FinanceAdminCard(
            title: 'Budgets',
            child: Column(
              children: [
                for (final b in snap.budgets.take(5))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(
                      b.name,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      b.budgetCode,
                      style: const TextStyle(
                        color: FinanceAdminUi.muted,
                        fontSize: 12,
                      ),
                    ),
                    trailing: Text(
                      b.totalDisplay,
                      style: const TextStyle(
                        color: FinanceAdminUi.gold,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

class _QueuesCard extends StatelessWidget {
  const _QueuesCard({required this.snap, required this.onOpenTab});

  final FapmsCommandCenterSnapshot snap;
  final ValueChanged<FapmsCommandTab> onOpenTab;

  @override
  Widget build(BuildContext context) {
    return FinanceAdminCard(
      title: 'Work queues',
      subtitle: 'Jump into the backlog that moves money',
      child: Column(
        children: [
          _QueueRow(
            label: 'Client payment verification',
            count: snap.pendingClientVerifications,
            onTap: () => onOpenTab(FapmsCommandTab.verification),
          ),
          _QueueRow(
            label: 'Investor transfer confirmations',
            count: snap.pendingInvestorIntents,
            onTap: () => onOpenTab(FapmsCommandTab.investor),
          ),
          _QueueRow(
            label: 'Deposit / installment schedules',
            count: snap.depositApplications.length,
            onTap: () => onOpenTab(FapmsCommandTab.installments),
          ),
          _QueueRow(
            label: 'Website calculator leads',
            count: snap.openLeadCount,
            onTap: () => onOpenTab(FapmsCommandTab.leads),
          ),
          _QueueRow(
            label: 'Expense approvals',
            count: snap.pendingApprovals.length,
            onTap: () => onOpenTab(FapmsCommandTab.expenses),
          ),
          _QueueRow(
            label: 'Open commissions',
            count: snap.openCommissionCount,
            onTap: () => onOpenTab(FapmsCommandTab.commissions),
          ),
          _QueueRow(
            label: 'Overdue invoices',
            count: snap.invoices
                .where((i) => i.status == InvoiceStatus.overdue)
                .length,
            onTap: () => onOpenTab(FapmsCommandTab.invoices),
          ),
          _QueueRow(
            label: 'Overdue installments',
            count: snap.overdueInstallmentCount,
            onTap: () => onOpenTab(FapmsCommandTab.installments),
          ),
        ],
      ),
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({
    required this.label,
    required this.count,
    required this.onTap,
  });

  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
            FinanceStatusPill(
              label: '$count',
              color: count > 0 ? FinanceAdminUi.gold : FinanceAdminUi.muted,
            ),
            const SizedBox(width: 6),
            const Icon(
              LucideIcons.chevronRight,
              size: 16,
              color: FinanceAdminUi.muted,
            ),
          ],
        ),
      ),
    );
  }
}

class _AgingBars extends StatelessWidget {
  const _AgingBars({required this.buckets});

  final List<FapmsAgingBucket> buckets;

  @override
  Widget build(BuildContext context) {
    if (buckets.isEmpty) {
      return const Text(
        'No aging rows yet.',
        style: TextStyle(color: FinanceAdminUi.muted),
      );
    }
    final max = buckets.fold<double>(
      0,
      (m, b) => b.amount > m ? b.amount : m,
    );
    return Column(
      children: [
        for (final b in buckets)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        b.kind.label,
                        style: const TextStyle(
                          color: FinanceAdminUi.muted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Text(
                      formatFapmsMoney(b.amount),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: max <= 0 ? 0 : (b.amount / max).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: Colors.white10,
                    color: FinanceAdminUi.gold,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PaymentsTab extends StatelessWidget {
  const _PaymentsTab({
    required this.payments,
    required this.receipts,
    required this.query,
  });

  final List<FapmsPaymentTx> payments;
  final List<FapmsReceipt> receipts;
  final String query;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        if (payments.isEmpty)
          FinanceEmptyState(
            title: 'No payments yet',
            message: query.isEmpty
                ? 'Client, investor, and gateway payments appear here in realtime.'
                : 'No payments match “$query”.',
            icon: LucideIcons.banknote,
          )
        else
          for (final tx in payments)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: FinanceAdminUi.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: FinanceAdminUi.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: FinanceAdminUi.surfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      tx.source == 'client'
                          ? LucideIcons.user
                          : tx.source == 'investor'
                              ? LucideIcons.trendingUp
                              : LucideIcons.creditCard,
                      size: 18,
                      color: FinanceAdminUi.gold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${tx.sourceLabel} · ${tx.provider}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (tx.providerReference != null)
                              tx.providerReference!,
                            if (tx.occurredAt != null)
                              DateFormat('dd MMM yyyy · HH:mm')
                                  .format(tx.occurredAt!.toLocal()),
                          ].join(' · '),
                          style: const TextStyle(
                            color: FinanceAdminUi.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        tx.amountDisplay,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      FinanceStatusPill(label: tx.status.label),
                    ],
                  ),
                ],
              ),
            ),
        FinanceReceiptsSection(receipts: receipts),
      ],
    );
  }
}

class _InvoicesTab extends StatelessWidget {
  const _InvoicesTab({
    required this.invoices,
    required this.statusColor,
    this.onCreate,
    this.onMarkPaid,
  });

  final List<FapmsInvoice> invoices;
  final Color Function(String) statusColor;
  final VoidCallback? onCreate;
  final Future<void> Function(String id)? onMarkPaid;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Invoices',
                style: TextStyle(
                  color: FinanceAdminUi.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (onCreate != null)
              PermissionGateAny(
                permissions: const [
                  PermissionSlugs.financeInvoices,
                  PermissionSlugs.financeWrite,
                ],
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: FinanceAdminUi.gold,
                    foregroundColor: Colors.black,
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: onCreate,
                  icon: const Icon(LucideIcons.plus, size: 16),
                  label: const Text('Create'),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (invoices.isEmpty)
          const FinanceEmptyState(
            title: 'No invoices',
            message: 'Create an invoice or convert a website calculator lead.',
            icon: LucideIcons.fileText,
          )
        else
          for (final inv in invoices) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: FinanceAdminUi.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: FinanceAdminUi.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          inv.invoiceNumber,
                          style: const TextStyle(
                            color: FinanceAdminUi.gold,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          inv.partyName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (inv.dueDate != null)
                          Text(
                            'Due ${DateFormat('dd MMM yyyy').format(inv.dueDate!)}',
                            style: const TextStyle(
                              color: FinanceAdminUi.muted,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        inv.amountDisplay,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Bal ${inv.balanceDisplay}',
                        style: const TextStyle(
                          color: FinanceAdminUi.muted,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),
                      FinanceStatusPill(
                        label: inv.status.label,
                        color: statusColor(inv.status.slug),
                      ),
                      if (onMarkPaid != null &&
                          inv.status != InvoiceStatus.paid &&
                          inv.status != InvoiceStatus.cancelled)
                        PermissionGateAny(
                          permissions: const [
                            PermissionSlugs.financePayments,
                            PermissionSlugs.financeWrite,
                          ],
                          child: TextButton(
                            onPressed: () => onMarkPaid!(inv.id),
                            child: const Text('Mark paid'),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
      ],
    );
  }
}

class _ExpensesTab extends StatelessWidget {
  const _ExpensesTab({
    required this.expenses,
    required this.pending,
    required this.statusColor,
    required this.onApprove,
    required this.onReject,
    this.onCreate,
  });

  final List<FapmsExpense> expenses;
  final List<FapmsExpense> pending;
  final Color Function(String) statusColor;
  final Future<void> Function(String id) onApprove;
  final Future<void> Function(String id) onReject;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Expenses',
                style: TextStyle(
                  color: FinanceAdminUi.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (onCreate != null)
              PermissionGateAny(
                permissions: const [
                  PermissionSlugs.financeExpenses,
                  PermissionSlugs.financeWrite,
                ],
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: FinanceAdminUi.gold,
                    foregroundColor: Colors.black,
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: onCreate,
                  icon: const Icon(LucideIcons.plus, size: 16),
                  label: const Text('Submit'),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (pending.isNotEmpty) ...[
          FinanceAdminCard(
            title: 'Needs approval',
            subtitle: '${pending.length} waiting',
            child: Column(
              children: [
                for (final e in pending)
                  _ExpenseTile(
                    expense: e,
                    statusColor: statusColor,
                    denseActions: true,
                    onApprove: () => onApprove(e.id),
                    onReject: () => onReject(e.id),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        Text(
          'All expenses',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: FinanceAdminUi.muted,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        if (expenses.isEmpty)
          const FinanceEmptyState(
            title: 'No expenses',
            message: 'Approved and pending expenses from Supabase appear here.',
            icon: LucideIcons.receipt,
          )
        else
          for (final e in expenses) ...[
            _ExpenseTile(
              expense: e,
              statusColor: statusColor,
              onApprove: e.status == ExpenseStatus.pending
                  ? () => onApprove(e.id)
                  : null,
              onReject: e.status == ExpenseStatus.pending
                  ? () => onReject(e.id)
                  : null,
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({
    required this.expense,
    required this.statusColor,
    this.onApprove,
    this.onReject,
    this.denseActions = false,
  });

  final FapmsExpense expense;
  final Color Function(String) statusColor;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final bool denseActions;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: denseActions ? 8 : 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FinanceAdminUi.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FinanceAdminUi.border),
      ),
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
                      expense.expenseCode.isEmpty
                          ? 'Expense'
                          : expense.expenseCode,
                      style: const TextStyle(
                        color: FinanceAdminUi.gold,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      expense.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      [
                        if (expense.vendorLabel != null) expense.vendorLabel!,
                        if (expense.submittedByLabel != null)
                          expense.submittedByLabel!,
                      ].join(' · '),
                      style: const TextStyle(
                        color: FinanceAdminUi.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    expense.amountDisplay,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FinanceStatusPill(
                    label: expense.status.label,
                    color: statusColor(expense.status.slug),
                  ),
                ],
              ),
            ],
          ),
          if (onApprove != null || onReject != null) ...[
            const SizedBox(height: 10),
            PermissionGate(
              permission: PermissionSlugs.financeApprovals,
              child: Row(
                children: [
                  if (onApprove != null)
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: FinanceAdminUi.success,
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: onApprove,
                      child: const Text('Approve'),
                    ),
                  if (onReject != null) ...[
                    const SizedBox(width: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: FinanceAdminUi.danger,
                        side: const BorderSide(color: FinanceAdminUi.danger),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: onReject,
                      child: const Text('Reject'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

FapmsCommandTab? _tabForAlert(FapmsAlert alert) {
  final haystack = '${alert.category ?? ''} ${alert.title}'.toLowerCase();
  if (haystack.contains('invoice') || haystack.contains('receivable') || haystack == 'ar') {
    return FapmsCommandTab.invoices;
  }
  if (haystack.contains('expense') || haystack.contains('approval')) {
    return FapmsCommandTab.expenses;
  }
  if (haystack.contains('bank') || haystack.contains('cash')) {
    return FapmsCommandTab.banking;
  }
  if (haystack.contains('investor')) return FapmsCommandTab.investor;
  if (haystack.contains('commission')) return FapmsCommandTab.commissions;
  if (haystack.contains('payment') || haystack.contains('verif')) {
    return FapmsCommandTab.verification;
  }
  return null;
}

class _BankingTab extends StatelessWidget {
  const _BankingTab({
    required this.accounts,
    required this.txs,
    required this.onAddAccount,
    this.onRecordMovement,
  });

  final List<FapmsBankAccount> accounts;
  final List<FapmsBankTx> txs;
  final VoidCallback onAddAccount;
  final VoidCallback? onRecordMovement;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Row(
          children: [
            const Spacer(),
            if (onRecordMovement != null) ...[
              OutlinedButton.icon(
                onPressed: onRecordMovement,
                icon: const Icon(LucideIcons.arrowLeftRight, size: 16),
                label: const Text('Record movement'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: FinanceAdminUi.border),
                ),
              ),
              const SizedBox(width: 8),
            ],
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: FinanceAdminUi.gold,
                foregroundColor: Colors.black,
              ),
              onPressed: onAddAccount,
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('Add account'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FinanceAdminCard(
          title: 'Bank accounts',
          child: accounts.isEmpty
              ? const Text(
                  'No operating account yet. Add one and cash on hand updates with each movement.',
                  style: TextStyle(color: FinanceAdminUi.muted),
                )
              : Column(
                  children: [
                    for (final a in accounts)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          LucideIcons.landmark,
                          color: FinanceAdminUi.gold,
                          size: 20,
                        ),
                        title: Text(
                          a.accountName,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          [
                            if (a.bankName.isNotEmpty) a.bankName,
                            if (a.accountNumberMasked != null)
                              a.accountNumberMasked!,
                          ].join(' · '),
                          style: const TextStyle(
                            color: FinanceAdminUi.muted,
                            fontSize: 12,
                          ),
                        ),
                        trailing: Text(
                          a.balanceDisplay,
                          style: const TextStyle(
                            color: FinanceAdminUi.gold,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        FinanceAdminCard(
          title: 'Recent bank movements',
          child: txs.isEmpty
              ? const Text(
                  'No bank transactions yet.',
                  style: TextStyle(color: FinanceAdminUi.muted),
                )
              : Column(
                  children: [
                    for (final t in txs.take(40))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(
                          t.description.isNotEmpty
                              ? t.description
                              : (t.reference ?? t.id),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: t.transactionDate == null
                            ? null
                            : Text(
                                DateFormat('dd MMM yyyy · HH:mm')
                                    .format(t.transactionDate!.toLocal()),
                                style: const TextStyle(
                                  color: FinanceAdminUi.muted,
                                  fontSize: 11,
                                ),
                              ),
                        trailing: Text(
                          t.amountDisplay,
                          style: TextStyle(
                            color: t.direction == 'debit' || t.amount < 0
                                ? FinanceAdminUi.danger
                                : FinanceAdminUi.success,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
