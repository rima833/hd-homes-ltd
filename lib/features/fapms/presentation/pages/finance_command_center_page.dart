import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/fapms/domain/entities/fapms_models.dart';
import 'package:hdhomesproject/features/fapms/domain/services/fapms_service.dart';
import 'package:hdhomesproject/features/fapms/presentation/providers/fapms_controller.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Volume 4 Part 7 — Finance Command Center™ admin workspace.
class FinanceCommandCenterPage extends ConsumerWidget {
  const FinanceCommandCenterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSnap = ref.watch(fapmsSnapshotProvider);
    final ui = ref.watch(fapmsControllerProvider);
    final controller = ref.read(fapmsControllerProvider.notifier);

    return Scaffold(
      body: asyncSnap.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Failed to load Finance Command Center: $e'),
        ),
        data: (snap) {
          final tickerKpis = snap.kpis;
          final ticker = tickerKpis.isEmpty
              ? 'Finance live'
              : '${tickerKpis[ui.tickerIndex % tickerKpis.length].label}: '
                  '${tickerKpis[ui.tickerIndex % tickerKpis.length].displayValue}';

          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: CustomScrollView(
              slivers: [
                ContainedPadding(
                  child: _FapmsHeader(
                    ticker: ticker,
                    fromRemote: snap.fromRemote,
                    onRefresh: controller.refresh,
                    onOpenCashFlow: () =>
                        controller.setTab(FapmsCommandTab.overview),
                    onOpenCfo: () => controller.setTab(FapmsCommandTab.ai),
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
    FapmsCommandCenterSnapshot snap,
    FapmsUiState ui,
    FapmsController controller,
  ) {
    switch (ui.selectedTab) {
      case FapmsCommandTab.overview:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Cash Flow Engine™',
              icon: LucideIcons.waves,
              child: _CashFlowPanel(snap: snap),
            ),
          ),
          ContainedPadding(
            child: _SectionCard(
              title: 'Audit Intelligence',
              icon: LucideIcons.shieldCheck,
              child: _ActivityList(activities: snap.activities),
            ),
          ),
          ContainedPadding(
            child: _SectionCard(
              title: 'Finance Alerts',
              icon: LucideIcons.bell,
              child: _AlertList(alerts: snap.alerts),
            ),
          ),
        ];
      case FapmsCommandTab.ledger:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Journal Entries',
              icon: LucideIcons.bookOpen,
              child: _JournalList(journals: snap.journals),
            ),
          ),
        ];
      case FapmsCommandTab.ar:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Accounts Receivable Aging',
              icon: LucideIcons.arrowDownLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AgingBucketRow(buckets: snap.arBuckets),
                  const Divider(height: 24),
                  _AgingList(rows: snap.arRows),
                ],
              ),
            ),
          ),
        ];
      case FapmsCommandTab.ap:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Accounts Payable Aging',
              icon: LucideIcons.arrowUpRight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AgingBucketRow(buckets: snap.apBuckets),
                  const Divider(height: 24),
                  _AgingList(rows: snap.apRows),
                ],
              ),
            ),
          ),
        ];
      case FapmsCommandTab.invoices:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Invoices',
              icon: LucideIcons.fileText,
              child: _InvoiceList(
                invoices: controller.filteredInvoices(snap),
              ),
            ),
          ),
        ];
      case FapmsCommandTab.payments:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Payment Gateway Ledger',
              icon: LucideIcons.creditCard,
              child: _PaymentTxList(txs: snap.paymentTxs),
            ),
          ),
        ];
      case FapmsCommandTab.banking:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Bank Accounts',
              icon: LucideIcons.landmark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BankList(accounts: snap.bankAccounts),
                  const Divider(height: 24),
                  Text(
                    'Recent bank transactions',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  _BankTxList(txs: snap.bankTxs),
                ],
              ),
            ),
          ),
        ];
      case FapmsCommandTab.budgets:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Budget Intelligence™',
              icon: LucideIcons.pieChart,
              child: _BudgetPanel(
                budgets: snap.budgets,
                lines: snap.budgetLines,
                variances: snap.budgetVariances,
              ),
            ),
          ),
        ];
      case FapmsCommandTab.expenses:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Expenses',
              icon: LucideIcons.receipt,
              child: _ExpenseList(
                expenses: controller.filteredExpenses(snap),
              ),
            ),
          ),
        ];
      case FapmsCommandTab.approvals:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Pending Approvals',
              icon: LucideIcons.checkCircle,
              child: _ExpenseList(expenses: snap.pendingApprovals),
            ),
          ),
        ];
      case FapmsCommandTab.ai:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'CFO Workspace™',
              icon: LucideIcons.brain,
              child: _CfoPanel(
                snap: snap,
                onBriefing: () {
                  final briefing = ref
                      .read(fapmsServiceProvider)
                      .generateFinancialBriefing(snap);
                  controller.setMessage(briefing);
                },
                onAnomalies: () {
                  final items = FapmsService.detectAnomalies(snap);
                  controller.setMessage(items.join(' · '));
                },
              ),
            ),
          ),
          ContainedPadding(
            child: _SectionCard(
              title: 'AI Insights',
              icon: LucideIcons.sparkles,
              child: _AiList(insights: snap.aiInsights),
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

class _FapmsHeader extends StatelessWidget {
  const _FapmsHeader({
    required this.ticker,
    required this.fromRemote,
    required this.onRefresh,
    required this.onOpenCashFlow,
    required this.onOpenCfo,
  });

  final String ticker;
  final bool fromRemote;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpenCashFlow;
  final VoidCallback onOpenCfo;

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
                'Finance Command Center™',
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
                    onPressed: onOpenCashFlow,
                    icon: const Icon(LucideIcons.waves, size: 16),
                    label: const Text('Cash Flow'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.deepBlack,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: onOpenCfo,
                    icon: const Icon(LucideIcons.briefcase, size: 16),
                    label: const Text('CFO Workspace'),
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
                      'GL · AR/AP · invoices · banking · budgets',
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
                        const SizedBox(height: 4),
                        Text(
                          'Accounting · payments · Cash Flow Engine · Audit Intelligence',
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
          Row(
            children: [
              const Icon(LucideIcons.activity, size: 14, color: AppColors.gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ticker,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.white.withValues(alpha: 0.85),
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KpiStrip extends StatelessWidget {
  const _KpiStrip({required this.kpis});

  final List<FapmsKpi> kpis;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: SizedBox(
        height: 96,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: kpis.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (context, i) {
            final k = kpis[i];
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
                    k.label,
                    style: Theme.of(context).textTheme.labelSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  Text(
                    k.displayValue,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            );
          },
        ),
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

  final FapmsUiState ui;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onStatus;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: onSearch,
              decoration: InputDecoration(
                hintText: 'Search invoices, expenses, vendors…',
                prefixIcon: const Icon(LucideIcons.search, size: 18),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: AppRadius.cardBorder,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          DropdownButton<String?>(
            value: ui.statusFilter,
            hint: const Text('Status'),
            underline: const SizedBox.shrink(),
            items: const [
              DropdownMenuItem(value: null, child: Text('All')),
              DropdownMenuItem(value: 'paid', child: Text('Paid')),
              DropdownMenuItem(value: 'overdue', child: Text('Overdue')),
              DropdownMenuItem(value: 'sent', child: Text('Sent')),
              DropdownMenuItem(value: 'pending', child: Text('Pending')),
            ],
            onChanged: onStatus,
          ),
        ],
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.selected, required this.onSelect});

  final FapmsCommandTab selected;
  final ValueChanged<FapmsCommandTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: FapmsCommandTab.values.map((tab) {
            final active = tab == selected;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(tab.label),
                selected: active,
                onSelected: (_) => onSelect(tab),
                selectedColor: AppColors.gold.withValues(alpha: 0.35),
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
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: AppRadius.cardBorder,
          border: Border.all(
            color: AppColors.gold.withValues(alpha: 0.15),
          ),
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

class _CashFlowPanel extends StatelessWidget {
  const _CashFlowPanel({required this.snap});

  final FapmsCommandCenterSnapshot snap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          snap.projectionDisclaimer,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondaryLight,
              ),
        ),
        const SizedBox(height: 12),
        ...snap.cashFlow.map((p) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(p.label),
            subtitle: Text(
              'In ${formatFapmsMoney(p.inflow)} · Out ${formatFapmsMoney(p.outflow)}'
              '${p.isProjection ? ' · PROJECTION' : ''}',
            ),
            trailing: Text(
              p.netDisplay,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: p.net >= 0 ? Colors.green.shade700 : Colors.red.shade700,
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _ActivityList extends StatelessWidget {
  const _ActivityList({required this.activities});

  final List<FapmsActivity> activities;

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return const Text('No activity yet.');
    }
    final fmt = DateFormat.MMMd().add_jm();
    return Column(
      children: activities.map((a) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: const Icon(LucideIcons.gitCommit, size: 16),
          title: Text(a.summary),
          subtitle: Text(
            [
              if (a.actorLabel != null) a.actorLabel!,
              if (a.occurredAt != null) fmt.format(a.occurredAt!),
            ].join(' · '),
          ),
        );
      }).toList(),
    );
  }
}

class _AlertList extends StatelessWidget {
  const _AlertList({required this.alerts});

  final List<FapmsAlert> alerts;

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) return const Text('No alerts.');
    return Column(
      children: alerts.map((a) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: Icon(
            LucideIcons.alertTriangle,
            size: 16,
            color: a.severity == 'warning' || a.severity == 'critical'
                ? Colors.orange
                : AppColors.gold,
          ),
          title: Text(a.title),
          subtitle: a.body == null ? null : Text(a.body!),
        );
      }).toList(),
    );
  }
}

class _JournalList extends StatelessWidget {
  const _JournalList({required this.journals});

  final List<FapmsJournalSummary> journals;

  @override
  Widget build(BuildContext context) {
    if (journals.isEmpty) return const Text('No journal entries.');
    return Column(
      children: journals.map((j) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text('${j.entryNumber} · ${j.status}'),
          subtitle: Text(j.memo ?? '—'),
          trailing: Text(j.debitDisplay),
        );
      }).toList(),
    );
  }
}

class _AgingBucketRow extends StatelessWidget {
  const _AgingBucketRow({required this.buckets});

  final List<FapmsAgingBucket> buckets;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: buckets.map((b) {
        return Chip(
          label: Text('${b.kind.label}: ${b.amountDisplay} (${b.count})'),
        );
      }).toList(),
    );
  }
}

class _AgingList extends StatelessWidget {
  const _AgingList({required this.rows});

  final List<FapmsAgingRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const Text('No aging rows.');
    return Column(
      children: rows.map((r) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(r.partyName),
          subtitle: Text('${r.bucket.label} · ${r.status}'),
          trailing: Text(r.amountDisplay),
        );
      }).toList(),
    );
  }
}

class _InvoiceList extends StatelessWidget {
  const _InvoiceList({required this.invoices});

  final List<FapmsInvoice> invoices;

  @override
  Widget build(BuildContext context) {
    if (invoices.isEmpty) return const Text('No invoices match filters.');
    return Column(
      children: invoices.map((inv) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text('${inv.invoiceNumber} · ${inv.partyName}'),
          subtitle: Text('${inv.status.label} · bal ${inv.balanceDisplay}'),
          trailing: Text(inv.amountDisplay),
        );
      }).toList(),
    );
  }
}

class _PaymentTxList extends StatelessWidget {
  const _PaymentTxList({required this.txs});

  final List<FapmsPaymentTx> txs;

  @override
  Widget build(BuildContext context) {
    if (txs.isEmpty) return const Text('No payment transactions.');
    return Column(
      children: txs.map((tx) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text('${tx.provider} · ${tx.status.label}'),
          subtitle: Text(tx.providerReference ?? tx.id),
          trailing: Text(tx.amountDisplay),
        );
      }).toList(),
    );
  }
}

class _BankList extends StatelessWidget {
  const _BankList({required this.accounts});

  final List<FapmsBankAccount> accounts;

  @override
  Widget build(BuildContext context) {
    if (accounts.isEmpty) return const Text('No bank accounts.');
    return Column(
      children: accounts.map((a) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(a.accountName),
          subtitle: Text('${a.bankName} · ${a.accountNumberMasked ?? ''}'),
          trailing: Text(a.balanceDisplay),
        );
      }).toList(),
    );
  }
}

class _BankTxList extends StatelessWidget {
  const _BankTxList({required this.txs});

  final List<FapmsBankTx> txs;

  @override
  Widget build(BuildContext context) {
    if (txs.isEmpty) return const Text('No bank transactions.');
    return Column(
      children: txs.map((t) {
        final sign = t.direction == 'debit' ? '-' : '+';
        return ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(t.description),
          subtitle: Text('${t.status} · ${t.reference ?? ''}'),
          trailing: Text('$sign${t.amountDisplay}'),
        );
      }).toList(),
    );
  }
}

class _BudgetPanel extends StatelessWidget {
  const _BudgetPanel({
    required this.budgets,
    required this.lines,
    required this.variances,
  });

  final List<FapmsBudget> budgets;
  final List<FapmsBudgetLine> lines;
  final List<FapmsBudgetVariance> variances;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...budgets.map((b) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text('${b.budgetCode} · ${b.name}'),
            subtitle: Text(b.status),
            trailing: Text(b.totalDisplay),
          );
        }),
        const Divider(height: 24),
        Text('Lines', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        ...lines.map((l) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(l.category),
            subtitle: Text(
              'Budget ${formatFapmsMoney(l.budgetedAmount)} · '
              'Actual ${formatFapmsMoney(l.actualAmount)}',
            ),
          );
        }),
        if (variances.isNotEmpty) ...[
          const Divider(height: 24),
          Text('Variances', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          ...variances.map((v) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text('${v.category} · ${v.severity}'),
              subtitle: Text(v.notes ?? ''),
              trailing: Text(formatFapmsMoney(v.varianceAmount)),
            );
          }),
        ],
      ],
    );
  }
}

class _ExpenseList extends StatelessWidget {
  const _ExpenseList({required this.expenses});

  final List<FapmsExpense> expenses;

  @override
  Widget build(BuildContext context) {
    if (expenses.isEmpty) return const Text('No expenses in this view.');
    return Column(
      children: expenses.map((e) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text('${e.expenseCode} · ${e.title}'),
          subtitle: Text(
            '${e.status.label} · ${e.vendorLabel ?? ''} · ${e.submittedByLabel ?? ''}',
          ),
          trailing: Text(e.amountDisplay),
        );
      }).toList(),
    );
  }
}

class _CfoPanel extends StatelessWidget {
  const _CfoPanel({
    required this.snap,
    required this.onBriefing,
    required this.onAnomalies,
  });

  final FapmsCommandCenterSnapshot snap;
  final VoidCallback onBriefing;
  final VoidCallback onAnomalies;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Executive finance stubs — briefing & anomaly scan (Phase 1).',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Text(
          snap.projectionDisclaimer,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
              ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: onBriefing,
              icon: const Icon(LucideIcons.fileBarChart, size: 16),
              label: const Text('AI Briefing'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.deepBlack,
              ),
            ),
            OutlinedButton.icon(
              onPressed: onAnomalies,
              icon: const Icon(LucideIcons.radar, size: 16),
              label: const Text('Detect Anomalies'),
            ),
          ],
        ),
      ],
    );
  }
}

class _AiList extends StatelessWidget {
  const _AiList({required this.insights});

  final List<FapmsAiInsight> insights;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: insights.map((i) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: const Icon(LucideIcons.sparkles, size: 16),
          title: Text(i.title),
          subtitle: Text(
            '${i.body}\n'
            'AI-generated · ${i.confidencePct?.toStringAsFixed(0) ?? 'n/a'}% · '
            '${i.disclaimer}',
          ),
          isThreeLine: true,
        );
      }).toList(),
    );
  }
}
