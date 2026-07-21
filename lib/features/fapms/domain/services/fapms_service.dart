import 'package:hdhomesproject/features/fapms/domain/entities/fapms_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Loads Finance Command Center snapshot from Supabase (falls back to demo).
class FapmsService {
  FapmsService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  Future<FapmsCommandCenterSnapshot> loadCommandCenter() async {
    final demo = FapmsDemo.snapshot();
    final client = _client;
    if (client == null) return demo;

    try {
      List<FapmsInvoice> invoices = demo.invoices;
      try {
        final rows = await client
            .from('invoices')
            .select()
            .order('updated_at', ascending: false)
            .limit(100);
        if (rows.isNotEmpty) {
          invoices = rows
              .map(
                (e) =>
                    FapmsInvoice.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      if (invoices.isEmpty) return demo;

      List<FapmsPaymentTx> paymentTxs = demo.paymentTxs;
      try {
        final rows = await client
            .from('payment_transactions')
            .select()
            .order('occurred_at', ascending: false)
            .limit(100);
        if (rows.isNotEmpty) {
          paymentTxs = rows
              .map(
                (e) => FapmsPaymentTx.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<FapmsExpense> expenses = demo.expenses;
      try {
        final rows = await client
            .from('expenses')
            .select()
            .order('updated_at', ascending: false)
            .limit(100);
        if (rows.isNotEmpty) {
          expenses = rows
              .map(
                (e) =>
                    FapmsExpense.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<FapmsBudget> budgets = demo.budgets;
      try {
        final rows = await client
            .from('budgets')
            .select()
            .order('updated_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          budgets = rows
              .map(
                (e) =>
                    FapmsBudget.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<FapmsBudgetLine> budgetLines = demo.budgetLines;
      try {
        final rows = await client.from('budget_lines').select().limit(100);
        if (rows.isNotEmpty) {
          budgetLines = rows
              .map(
                (e) => FapmsBudgetLine.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<FapmsBudgetVariance> variances = demo.budgetVariances;
      try {
        final rows = await client.from('budget_variances').select().limit(50);
        if (rows.isNotEmpty) {
          variances = rows
              .map(
                (e) => FapmsBudgetVariance.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<FapmsBankAccount> banks = demo.bankAccounts;
      try {
        final rows = await client
            .from('bank_accounts')
            .select()
            .order('updated_at', ascending: false)
            .limit(20);
        if (rows.isNotEmpty) {
          banks = rows
              .map(
                (e) => FapmsBankAccount.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<FapmsBankTx> bankTxs = demo.bankTxs;
      try {
        final rows = await client
            .from('bank_transactions')
            .select()
            .order('transaction_date', ascending: false)
            .limit(80);
        if (rows.isNotEmpty) {
          bankTxs = rows
              .map(
                (e) =>
                    FapmsBankTx.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<FapmsJournalSummary> journals = demo.journals;
      try {
        final rows = await client
            .from('journal_entries')
            .select()
            .order('entry_date', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          journals = rows
              .map(
                (e) => FapmsJournalSummary.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<FapmsAgingRow> arRows = demo.arRows;
      try {
        final rows = await client
            .from('accounts_receivable')
            .select()
            .order('as_of_date', ascending: false)
            .limit(80);
        if (rows.isNotEmpty) {
          arRows = rows
              .map(
                (e) => FapmsAgingRow.fromArJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<FapmsAgingRow> apRows = demo.apRows;
      try {
        final rows = await client
            .from('accounts_payable')
            .select()
            .order('as_of_date', ascending: false)
            .limit(80);
        if (rows.isNotEmpty) {
          apRows = rows
              .map(
                (e) => FapmsAgingRow.fromApJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<FapmsActivity> activities = demo.activities;
      try {
        final rows = await client
            .from('finance_activity_logs')
            .select()
            .order('occurred_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          activities = rows
              .map(
                (e) => FapmsActivity.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<FapmsAlert> alerts = demo.alerts;
      try {
        final rows = await client
            .from('finance_notifications')
            .select()
            .order('created_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          alerts = rows
              .map(
                (e) =>
                    FapmsAlert.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<FapmsCashFlowPoint> cashFlow = demo.cashFlow;
      try {
        final rows = await client
            .from('financial_statements')
            .select()
            .eq('is_projection', true)
            .limit(5);
        if (rows.isNotEmpty) {
          final first = Map<String, dynamic>.from(rows.first as Map);
          final items = first['line_items'];
          final disclaimer = first['disclaimer'] as String? ??
              kFinanceProjectionDisclaimer;
          if (items is List && items.isNotEmpty) {
            cashFlow = items.map((raw) {
              final m = Map<String, dynamic>.from(raw as Map);
              return FapmsCashFlowPoint(
                label: m['label'] as String? ?? 'Period',
                inflow: (m['inflow'] as num?)?.toDouble() ?? 0,
                outflow: (m['outflow'] as num?)?.toDouble() ?? 0,
                isProjection: true,
                disclaimer: disclaimer,
              );
            }).toList();
          }
        }
      } catch (_) {}

      return FapmsCommandCenterSnapshot(
        kpis: FapmsDemo.aggregateKpis(
          invoices: invoices,
          paymentTxs: paymentTxs,
          expenses: expenses,
          bankAccounts: banks,
          arRows: arRows,
          apRows: apRows,
        ),
        invoices: invoices,
        paymentTxs: paymentTxs,
        expenses: expenses,
        budgets: budgets,
        budgetLines: budgetLines,
        budgetVariances: variances,
        bankAccounts: banks,
        bankTxs: bankTxs,
        journals: journals,
        arRows: arRows,
        apRows: apRows,
        arBuckets: FapmsDemo.rollupAging(arRows, side: 'ar'),
        apBuckets: FapmsDemo.rollupAging(apRows, side: 'ap'),
        cashFlow: cashFlow,
        activities: activities,
        alerts: alerts,
        aiInsights: demo.aiInsights,
        fromRemote: true,
        loadedAt: DateTime.now(),
      );
    } catch (_) {
      return demo;
    }
  }

  /// Stub AI financial briefing for CFO Workspace.
  String generateFinancialBriefing(FapmsCommandCenterSnapshot snap) {
    final overdue = snap.invoices
        .where((i) => i.status == InvoiceStatus.overdue)
        .length;
    final pending = snap.pendingApprovals.length;
    final cash = snap.bankAccounts.fold<double>(0, (s, b) => s + b.balance);
    return 'AI financial briefing: cash ${formatFapmsMoney(cash)} · '
        '$overdue overdue invoice(s) · $pending expense approval(s) · '
        '${snap.arBuckets.fold<double>(0, (s, b) => s + b.amount).toStringAsFixed(0)} AR face. '
        'Review collections cadence and construction budget variance this week. '
        '(${snap.projectionDisclaimer})';
  }

  /// Stub anomaly detection — overdue invoices, failed txs, critical variances.
  static List<String> detectAnomalies(FapmsCommandCenterSnapshot snap) {
    final out = <String>[];
    for (final inv in snap.invoices) {
      if (inv.status == InvoiceStatus.overdue) {
        out.add('Overdue invoice ${inv.invoiceNumber} (${inv.amountDisplay})');
      }
    }
    for (final tx in snap.paymentTxs) {
      if (tx.status == PaymentTxStatus.failed) {
        out.add('Failed gateway tx ${tx.provider} ${tx.providerReference ?? tx.id}');
      }
    }
    for (final v in snap.budgetVariances) {
      if (v.severity == 'watch' || v.severity == 'critical') {
        out.add('Budget ${v.severity}: ${v.category} ${formatFapmsMoney(v.varianceAmount)}');
      }
    }
    if (out.isEmpty) {
      out.add('No material anomalies in current demo snapshot.');
    }
    return out;
  }
}
