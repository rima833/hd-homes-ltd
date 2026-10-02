import 'package:hdhomesproject/features/fapms/domain/entities/fapms_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Loads Finance Command Center snapshot from Supabase.
/// When Supabase is configured, never substitutes the full demo dataset —
/// empty lists are returned for missing slices so LIVE means live.
class FapmsService {
  FapmsService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  Future<T> _guardLoad<T>(
    List<String> warnings,
    String slice,
    Future<T> Function() load,
    T fallback,
  ) async {
    try {
      return await load();
    } catch (e) {
      warnings.add('$slice: $e');
      return fallback;
    }
  }

  Future<List<T>> _guardLoadList<T>(
    List<String> warnings,
    String slice,
    Future<List<T>> Function() load,
  ) async {
    try {
      return await load();
    } catch (e) {
      warnings.add('$slice: $e');
      return <T>[];
    }
  }

  Future<FapmsCommandCenterSnapshot> loadCommandCenter() async {
    final client = _client;
    if (client == null) {
      return FapmsCommandCenterSnapshot.empty();
    }

    final warnings = <String>[];

    final invoices = await _guardLoadList(
      warnings,
      'invoices',
      () => _loadInvoices(client),
    );
    final gatewayTxs = await _guardLoadList(
      warnings,
      'payment_transactions',
      () => _loadGatewayTxs(client),
    );
    final clientPayments = await _guardLoadList(
      warnings,
      'payments',
      () => _loadClientPayments(client),
    );
    final paymentTxs = _mergePaymentLedger(gatewayTxs, clientPayments);
    final expenses = await _guardLoadList(
      warnings,
      'expenses',
      () => _loadExpenses(client),
    );
    final budgets = await _guardLoadList(
      warnings,
      'budgets',
      () => _loadBudgets(client),
    );
    final budgetLines = await _guardLoadList(
      warnings,
      'budget_lines',
      () => _loadBudgetLines(client),
    );
    final variances = await _guardLoadList(
      warnings,
      'budget_variances',
      () => _loadVariances(client),
    );
    final banks = await _guardLoadList(
      warnings,
      'bank_accounts',
      () => _loadBanks(client),
    );
    final bankTxs = await _guardLoadList(
      warnings,
      'bank_transactions',
      () => _loadBankTxs(client),
    );
    final journals = await _guardLoadList(
      warnings,
      'journal_entries',
      () => _loadJournals(client),
    );
    final arRows = await _guardLoadList(
      warnings,
      'accounts_receivable',
      () => _loadAr(client),
    );
    final apRows = await _guardLoadList(
      warnings,
      'accounts_payable',
      () => _loadAp(client),
    );
    final activities = await _guardLoadList(
      warnings,
      'finance_activity_logs',
      () => _loadActivities(client),
    );
    final alerts = await _guardLoadList(
      warnings,
      'finance_notifications',
      () => _loadAlerts(client),
    );
    await _guardLoadList(
      warnings,
      'cash_flow',
      () => _loadCashFlow(client),
    );
    final pendingClient = await _guardLoad(
      warnings,
      'client_payment_intents',
      () => _countPendingClientVerifications(client),
      0,
    );
    final pendingInvestor = await _guardLoad(
      warnings,
      'investor_payment_intents',
      () => _countPendingInvestorIntents(client),
      0,
    );
    final investorIntents = await _guardLoadList(
      warnings,
      'investor_payment_intents',
      () => _loadInvestorIntents(client),
    );
    final installments = await _guardLoadList(
      warnings,
      'installments',
      () => _loadInstallments(client),
    );
    final receipts = await _guardLoadList(
      warnings,
      'finance_receipts',
      () => _loadReceipts(client),
    );
    final charges = await _guardLoadList(
      warnings,
      'payment_charges',
      () => _loadCharges(client),
    );
    final distributions = await _guardLoadList(
      warnings,
      'investment_distributions',
      () => _loadDistributions(client),
    );
    final investmentAccounts = await _guardLoadList(
      warnings,
      'investment_receiving_accounts',
      () => _loadInvestmentReceivingAccounts(client),
    );
    final depositApps = await _guardLoadList(
      warnings,
      'client_property_applications',
      () => _loadDepositApplications(client),
    );
    final paymentSettings = await _guardLoad(
      warnings,
      'payment_settings',
      () => _loadPaymentSettings(client),
      null,
    );
    final calculatorLeads = await _guardLoadList(
      warnings,
      'calculator_applications',
      () => _loadCalculatorLeads(client),
    );
    final commissions = await _guardLoadList(
      warnings,
      'commissions',
      () => _loadCommissions(client),
    );
    final liveInvoices = invoices.where((e) => !_isDemoSeed(e.id)).toList();
    final liveTxs = paymentTxs.where((e) => !_isDemoSeed(e.id)).toList();
    final liveExpenses = expenses.where((e) => !_isDemoSeed(e.id)).toList();
    final liveBudgets = budgets.where((e) => !_isDemoSeed(e.id)).toList();
    final liveBudgetLines =
        budgetLines.where((e) => !_isDemoSeed(e.id)).toList();
    final liveVariances = variances.where((e) => !_isDemoSeed(e.id)).toList();
    final liveBanks = banks.where((e) => !_isDemoSeed(e.id)).toList();
    final liveBankTxs = bankTxs.where((e) => !_isDemoSeed(e.id)).toList();
    final liveJournals = journals.where((e) => !_isDemoSeed(e.id)).toList();
    final liveAr = arRows.where((e) => !_isDemoSeed(e.id)).toList();
    final liveAp = apRows.where((e) => !_isDemoSeed(e.id)).toList();
    final liveActivities = activities.where((e) => !_isDemoSeed(e.id)).toList();
    final liveAlerts = alerts.where((e) => !_isDemoSeed(e.id)).toList();
    final liveInstallments =
        installments.where((e) => !_isDemoSeed(e.id)).toList();
    final liveReceipts = receipts.where((e) => !_isDemoSeed(e.id)).toList();
    final liveCharges = charges.where((e) => !_isDemoSeed(e.id)).toList();
    final liveIntents =
        investorIntents.where((e) => !_isDemoSeed(e.id)).toList();

    final clientCaptured = clientPayments
        .where(
          (t) =>
              t.status == PaymentTxStatus.succeeded && !_isDemoSeed(t.id),
        )
        .fold<double>(0, (s, t) => s + t.amount);

    final kpis = FapmsDemo.aggregateKpis(
      invoices: liveInvoices,
      paymentTxs: liveTxs,
      expenses: liveExpenses,
      bankAccounts: liveBanks,
      arRows: liveAr,
      apRows: liveAp,
      pendingClientVerifications: pendingClient,
      pendingInvestorIntents: pendingInvestor,
      clientCapturedAmount: clientCaptured,
    );
    // Append live ops KPIs for website money desk.
    final liveKpis = [
      ...kpis,
      FapmsKpi(
        label: 'Overdue Installments',
        value: liveInstallments
            .where((i) => i.status == 'overdue' || i.isOverdue)
            .length
            .toDouble(),
      ),
      FapmsKpi(
        label: 'Open Charges',
        value: liveCharges
            .where((c) => c.status == 'pending' || c.status == 'applied')
            .length
            .toDouble(),
      ),
      FapmsKpi(label: 'Deposit Queue', value: depositApps.length.toDouble()),
      FapmsKpi(
        label: 'Website Leads',
        value: calculatorLeads
            .where((l) => l.status == 'new' || l.status == 'contacted')
            .length
            .toDouble(),
      ),
      FapmsKpi(
        label: 'Open Commissions',
        value: commissions
            .where((c) => c.status == 'pending' || c.status == 'approved')
            .length
            .toDouble(),
      ),
    ];

    return FapmsCommandCenterSnapshot(
      kpis: liveKpis,
      invoices: liveInvoices,
      paymentTxs: liveTxs,
      expenses: liveExpenses,
      budgets: liveBudgets,
      budgetLines: liveBudgetLines,
      budgetVariances: liveVariances,
      bankAccounts: liveBanks,
      bankTxs: liveBankTxs,
      journals: liveJournals,
      arRows: liveAr,
      apRows: liveAp,
      arBuckets: FapmsDemo.rollupAging(liveAr, side: 'ar'),
      apBuckets: FapmsDemo.rollupAging(liveAp, side: 'ap'),
      cashFlow: const [],
      activities: liveActivities,
      alerts: liveAlerts,
      aiInsights: const [],
      investorIntents: liveIntents,
      installments: liveInstallments,
      receipts: liveReceipts,
      charges: liveCharges,
      distributions: distributions,
      investmentReceivingAccounts: investmentAccounts,
      depositApplications: depositApps,
      paymentSettings: paymentSettings,
      calculatorLeads: calculatorLeads,
      commissions: commissions,
      pendingClientVerifications: pendingClient,
      pendingInvestorIntents: pendingInvestor,
      fromRemote: true,
      loadedAt: DateTime.now(),
      loadWarnings: warnings,
    );
  }

  Future<void> updateExpenseStatus({
    required String expenseId,
    required String status,
  }) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    await client
        .from('expenses')
        .update({
          'status': status,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', expenseId);
  }

  Future<void> confirmInvestorIntent({
    required String intentId,
    required String status,
  }) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    await client.rpc(
      'admin_confirm_investor_intent',
      params: {'p_intent_id': intentId, 'p_status': status},
    );
  }

  Future<Map<String, dynamic>> createInvoice({
    required String partyName,
    required double amount,
    String? clientId,
    String? propertyId,
    DateTime? dueDate,
    String? notes,
  }) async {
    final client = _requireClient;
    final result = await client.rpc(
      'admin_create_invoice',
      params: {
        'p_party_name': partyName,
        'p_amount': amount,
        if (clientId != null) 'p_client_id': clientId,
        if (propertyId != null) 'p_property_id': propertyId,
        if (dueDate != null)
          'p_due_date':
              '${dueDate.year.toString().padLeft(4, '0')}-'
              '${dueDate.month.toString().padLeft(2, '0')}-'
              '${dueDate.day.toString().padLeft(2, '0')}',
        if (notes != null) 'p_notes': notes,
      },
    );
    return Map<String, dynamic>.from(result as Map? ?? {});
  }

  Future<Map<String, dynamic>> setInvoiceStatus({
    required String invoiceId,
    required String status,
  }) async {
    final client = _requireClient;
    final result = await client.rpc(
      'admin_set_invoice_status',
      params: {'p_invoice_id': invoiceId, 'p_status': status},
    );
    return Map<String, dynamic>.from(result as Map? ?? {});
  }

  Future<Map<String, dynamic>> generateInstallments({
    required String clientId,
    required String propertyId,
    required double totalAmount,
    double depositAmount = 0,
    int installmentCount = 0,
    DateTime? firstDue,
    int frequencyDays = 30,
    String? paymentPlanLabel,
    String? applicationId,
  }) async {
    final client = _requireClient;
    final due = firstDue ?? DateTime.now();
    final result = await client.rpc(
      'admin_generate_installments',
      params: {
        'p_client_id': clientId,
        'p_property_id': propertyId,
        'p_total_amount': totalAmount,
        'p_deposit_amount': depositAmount,
        'p_installment_count': installmentCount,
        'p_first_due':
            '${due.year.toString().padLeft(4, '0')}-'
            '${due.month.toString().padLeft(2, '0')}-'
            '${due.day.toString().padLeft(2, '0')}',
        'p_frequency_days': frequencyDays,
        if (paymentPlanLabel != null) 'p_payment_plan_label': paymentPlanLabel,
        if (applicationId != null) 'p_application_id': applicationId,
      },
    );
    return Map<String, dynamic>.from(result as Map? ?? {});
  }

  Future<Map<String, dynamic>> updateInstallmentStatus({
    required String installmentId,
    required String status,
  }) async {
    final client = _requireClient;
    final result = await client.rpc(
      'admin_update_installment_status',
      params: {'p_installment_id': installmentId, 'p_status': status},
    );
    return Map<String, dynamic>.from(result as Map? ?? {});
  }

  Future<Map<String, dynamic>> createDepositFromApplication({
    required String applicationId,
    double? depositAmount,
    int installmentCount = 0,
  }) async {
    final client = _requireClient;
    final result = await client.rpc(
      'admin_create_deposit_from_application',
      params: {
        'p_application_id': applicationId,
        if (depositAmount != null) 'p_deposit_amount': depositAmount,
        'p_installment_count': installmentCount,
      },
    );
    return Map<String, dynamic>.from(result as Map? ?? {});
  }

  Future<Map<String, dynamic>> createExpense({
    required String title,
    required double amount,
    String? vendorLabel,
    String? notes,
  }) async {
    final client = _requireClient;
    final result = await client.rpc(
      'admin_create_expense',
      params: {
        'p_title': title,
        'p_amount': amount,
        if (vendorLabel != null) 'p_vendor_label': vendorLabel,
        if (notes != null) 'p_notes': notes,
      },
    );
    return Map<String, dynamic>.from(result as Map? ?? {});
  }

  Future<Map<String, dynamic>> setDistributionStatus({
    required String distributionId,
    required String status,
  }) async {
    final client = _requireClient;
    final result = await client.rpc(
      'admin_set_distribution_status',
      params: {'p_distribution_id': distributionId, 'p_status': status},
    );
    return Map<String, dynamic>.from(result as Map? ?? {});
  }

  Future<Map<String, dynamic>> createDistribution({
    required String investorId,
    required double amount,
    String distributionType = 'dividend',
    String? notes,
  }) async {
    final client = _requireClient;
    final result = await client.rpc(
      'admin_create_distribution',
      params: {
        'p_investor_id': investorId,
        'p_amount': amount,
        'p_distribution_type': distributionType,
        if (notes != null) 'p_notes': notes,
      },
    );
    return Map<String, dynamic>.from(result as Map? ?? {});
  }

  Future<Map<String, dynamic>> updatePaymentSettings({
    bool? allowPartial,
    String? overpaymentPolicy,
    bool? requireTransferProof,
  }) async {
    final client = _requireClient;
    final result = await client.rpc(
      'admin_update_payment_settings',
      params: {
        if (allowPartial != null) 'p_allow_partial': allowPartial,
        if (overpaymentPolicy != null)
          'p_overpayment_policy': overpaymentPolicy,
        if (requireTransferProof != null)
          'p_require_transfer_proof': requireTransferProof,
      },
    );
    return Map<String, dynamic>.from(result as Map? ?? {});
  }

  Future<Map<String, dynamic>> convertCalculatorLead({
    required String applicationId,
    String status = 'converted',
    bool createInvoice = true,
    String? notes,
  }) async {
    final client = _requireClient;
    final result = await client.rpc(
      'admin_convert_calculator_lead',
      params: {
        'p_application_id': applicationId,
        'p_status': status,
        'p_create_invoice': createInvoice,
        if (notes != null) 'p_notes': notes,
      },
    );
    return Map<String, dynamic>.from(result as Map? ?? {});
  }

  Future<void> replyCalculatorLead({
    required String applicationId,
    required String reply,
    String? status,
  }) async {
    final client = _requireClient;
    await client.rpc(
      'reply_calculator_application',
      params: {
        'p_application_id': applicationId,
        'p_reply': reply.trim(),
        if (status != null) 'p_status': status,
      },
    );
  }

  Future<Map<String, dynamic>> setCommissionStatus({
    required String source,
    required String commissionId,
    required String status,
  }) async {
    final client = _requireClient;
    final result = await client.rpc(
      'admin_set_commission_status',
      params: {
        'p_source': source,
        'p_commission_id': commissionId,
        'p_status': status,
      },
    );
    return Map<String, dynamic>.from(result as Map? ?? {});
  }

  Future<void> upsertInvestmentReceivingAccount({
    String? id,
    required String bankName,
    required String accountName,
    required String accountNumber,
    String? instructions,
    bool isPrimary = false,
    bool isActive = true,
  }) async {
    final client = _requireClient;
    final payload = {
      'bank_name': bankName,
      'account_name': accountName,
      'account_number': accountNumber,
      'instructions': instructions,
      'is_primary': isPrimary,
      'is_active': isActive,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (id == null) {
      await client.from('investment_receiving_accounts').insert(payload);
    } else {
      await client
          .from('investment_receiving_accounts')
          .update(payload)
          .eq('id', id);
    }
    if (isPrimary) {
      final rows = await client
          .from('investment_receiving_accounts')
          .select('id')
          .eq('is_primary', true);
      for (final row in rows as List) {
        final rowId = '${(row as Map)['id']}';
        if (rowId != id) {
          await client
              .from('investment_receiving_accounts')
              .update({'is_primary': false})
              .eq('id', rowId);
        }
      }
    }
  }

  /// Rows inserted by the original FAPMS sample migration. Live desks ignore them.
  static bool _isDemoSeed(String id) =>
      id.startsWith('f4700000-0000-4000-8000-');

  Future<void> createBankAccount({
    required String accountName,
    required String bankName,
    String? accountNumberMasked,
    double openingBalance = 0,
  }) async {
    final client = _requireClient;
    final row = await client
        .from('bank_accounts')
        .insert({
          'account_name': accountName,
          'bank_name': bankName,
          if (accountNumberMasked != null && accountNumberMasked.isNotEmpty)
            'account_number_masked': accountNumberMasked,
          'balance': openingBalance,
          'currency': 'NGN',
          'is_active': true,
        })
        .select('id')
        .single();
    if (openingBalance != 0) {
      await client.from('bank_transactions').insert({
        'bank_account_id': row['id'],
        'description': 'Opening balance',
        'amount': openingBalance.abs(),
        'direction': openingBalance < 0 ? 'debit' : 'credit',
        'status': 'posted',
        'reference': 'opening',
      });
    }
  }

  Future<void> recordBankMovement({
    required String bankAccountId,
    required String description,
    required double amount,
    required String direction,
    String? reference,
  }) async {
    final client = _requireClient;
    final current = await client
        .from('bank_accounts')
        .select('balance')
        .eq('id', bankAccountId)
        .single();
    final balance = (current['balance'] as num?)?.toDouble() ?? 0;
    final next = direction == 'debit' ? balance - amount : balance + amount;
    await client.from('bank_transactions').insert({
      'bank_account_id': bankAccountId,
      'description': description,
      'amount': amount,
      'direction': direction,
      'status': 'posted',
      if (reference != null && reference.isNotEmpty) 'reference': reference,
    });
    await client
        .from('bank_accounts')
        .update({
          'balance': next,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', bankAccountId);
  }

  SupabaseClient get _requireClient {
    final c = _client;
    if (c == null) throw StateError('Supabase is not configured');
    return c;
  }

  String generateFinancialBriefing(FapmsCommandCenterSnapshot snap) {
    final overdue = snap.invoices
        .where((i) => i.status == InvoiceStatus.overdue)
        .length;
    final pending = snap.pendingApprovals.length;
    final cash = snap.bankAccounts.fold<double>(0, (s, b) => s + b.balance);
    return '$kFinanceProjectionDisclaimer Today: cash ${formatFapmsMoney(cash)} · '
        '$overdue overdue invoice(s) · $pending expense approval(s) · '
        '${snap.pendingClientVerifications} client payment(s) awaiting verification · '
        '${snap.pendingInvestorIntents} investor transfer(s) pending · '
        '${snap.depositApplications.length} deposit schedule(s) needed · '
        '${snap.openLeadCount} website calculator lead(s) · '
        '${snap.openCommissionCount} commission(s) open.';
  }

  static List<String> detectAnomalies(FapmsCommandCenterSnapshot snap) {
    final out = <String>[];
    for (final inv in snap.invoices) {
      if (inv.status == InvoiceStatus.overdue) {
        out.add('Overdue invoice ${inv.invoiceNumber} (${inv.amountDisplay})');
      }
    }
    for (final tx in snap.paymentTxs) {
      if (tx.status == PaymentTxStatus.failed) {
        out.add(
          'Failed payment ${tx.provider} ${tx.providerReference ?? tx.id}',
        );
      }
    }
    for (final v in snap.budgetVariances) {
      if (v.severity == 'watch' || v.severity == 'critical') {
        out.add(
          'Budget ${v.severity}: ${v.category} ${formatFapmsMoney(v.varianceAmount)}',
        );
      }
    }
    if (snap.pendingClientVerifications > 0) {
      out.add(
        '${snap.pendingClientVerifications} client bank transfer(s) need verification',
      );
    }
    if (snap.pendingInvestorIntents > 0) {
      out.add(
        '${snap.pendingInvestorIntents} investor transfer(s) awaiting confirmation',
      );
    }
    if (out.isEmpty) {
      out.add('No material anomalies in the live finance snapshot.');
    }
    return out;
  }

  List<FapmsPaymentTx> _mergePaymentLedger(
    List<FapmsPaymentTx> gateway,
    List<FapmsPaymentTx> clientPaid,
  ) {
    final merged = [...clientPaid, ...gateway];
    merged.sort((a, b) {
      final aAt = a.occurredAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bAt = b.occurredAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bAt.compareTo(aAt);
    });
    return merged;
  }

  Future<List<FapmsInvoice>> _loadInvoices(SupabaseClient client) async {
    try {
      final rows = await client
          .from('invoices')
          .select()
          .order('updated_at', ascending: false)
          .limit(200);
      return rows
          .map(
            (e) => FapmsInvoice.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<FapmsPaymentTx>> _loadGatewayTxs(SupabaseClient client) async {
    try {
      final rows = await client
          .from('payment_transactions')
          .select()
          .order('occurred_at', ascending: false)
          .limit(100);
      return rows
          .map(
            (e) => FapmsPaymentTx.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<FapmsPaymentTx>> _loadClientPayments(
    SupabaseClient client,
  ) async {
    try {
      final rows = await client
          .from('payments')
          .select()
          .order('paid_at', ascending: false)
          .limit(200);
      return rows.expand((raw) {
        final e = Map<String, dynamic>.from(raw as Map);
        final meta = e['metadata'];
        final reference = e['provider_reference'] as String? ?? '';
        final demo = meta is Map && meta['demo'] == true;
        if (demo ||
            reference.startsWith('PSK-demo') ||
            _isDemoSeed('${e['id']}')) {
          return const <FapmsPaymentTx>[];
        }
        final hasInvestor = e['investor_id'] != null;
        final metaSource = meta is Map ? meta['source']?.toString() : null;
        final source = hasInvestor || metaSource == 'investor_portal'
            ? 'investor'
            : 'client';
        return [
          FapmsPaymentTx(
            id: '${e['id']}',
            provider:
                e['payment_provider'] as String? ??
                e['payment_method'] as String? ??
                'bank_transfer',
            amount: (e['amount'] as num?)?.toDouble() ?? 0,
            status: PaymentTxStatus.fromSlug(e['status'] as String?),
            providerReference: e['provider_reference'] as String?,
            occurredAt: DateTime.tryParse(
              '${e['paid_at'] ?? e['created_at'] ?? ''}',
            ),
            currency: e['currency'] as String? ?? 'NGN',
            direction: 'inbound',
            source: source,
          ),
        ];
      }).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<FapmsExpense>> _loadExpenses(SupabaseClient client) async {
    try {
      final rows = await client
          .from('expenses')
          .select()
          .order('updated_at', ascending: false)
          .limit(200);
      return rows
          .map(
            (e) => FapmsExpense.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<FapmsBudget>> _loadBudgets(SupabaseClient client) async {
    try {
      final rows = await client
          .from('budgets')
          .select()
          .order('updated_at', ascending: false)
          .limit(40);
      return rows
          .map((e) => FapmsBudget.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<FapmsBudgetLine>> _loadBudgetLines(SupabaseClient client) async {
    try {
      final rows = await client.from('budget_lines').select().limit(100);
      return rows
          .map(
            (e) =>
                FapmsBudgetLine.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<FapmsBudgetVariance>> _loadVariances(
    SupabaseClient client,
  ) async {
    try {
      final rows = await client.from('budget_variances').select().limit(50);
      return rows
          .map(
            (e) => FapmsBudgetVariance.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<FapmsBankAccount>> _loadBanks(SupabaseClient client) async {
    try {
      final rows = await client
          .from('bank_accounts')
          .select()
          .order('updated_at', ascending: false)
          .limit(40);
      return rows
          .map(
            (e) =>
                FapmsBankAccount.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<FapmsBankTx>> _loadBankTxs(SupabaseClient client) async {
    try {
      final rows = await client
          .from('bank_transactions')
          .select()
          .order('transaction_date', ascending: false)
          .limit(80);
      return rows
          .map((e) => FapmsBankTx.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<FapmsJournalSummary>> _loadJournals(SupabaseClient client) async {
    try {
      final rows = await client
          .from('journal_entries')
          .select()
          .order('entry_date', ascending: false)
          .limit(40);
      return rows
          .map(
            (e) => FapmsJournalSummary.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<FapmsAgingRow>> _loadAr(SupabaseClient client) async {
    try {
      final rows = await client
          .from('accounts_receivable')
          .select()
          .order('as_of_date', ascending: false)
          .limit(80);
      return rows
          .map(
            (e) =>
                FapmsAgingRow.fromArJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<FapmsAgingRow>> _loadAp(SupabaseClient client) async {
    try {
      final rows = await client
          .from('accounts_payable')
          .select()
          .order('as_of_date', ascending: false)
          .limit(80);
      return rows
          .map(
            (e) =>
                FapmsAgingRow.fromApJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<FapmsActivity>> _loadActivities(SupabaseClient client) async {
    try {
      final rows = await client
          .from('finance_activity_logs')
          .select()
          .order('occurred_at', ascending: false)
          .limit(40);
      return rows
          .map(
            (e) => FapmsActivity.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<FapmsAlert>> _loadAlerts(SupabaseClient client) async {
    try {
      final rows = await client
          .from('finance_notifications')
          .select()
          .order('created_at', ascending: false)
          .limit(40);
      return rows
          .map((e) => FapmsAlert.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<FapmsCashFlowPoint>> _loadCashFlow(SupabaseClient client) async {
    try {
      final rows = await client
          .from('financial_statements')
          .select()
          .eq('is_projection', true)
          .limit(5);
      if (rows.isEmpty) return const [];
      final first = Map<String, dynamic>.from(rows.first as Map);
      final items = first['line_items'];
      final disclaimer =
          first['disclaimer'] as String? ?? kFinanceProjectionDisclaimer;
      if (items is! List || items.isEmpty) return const [];
      return items.map((raw) {
        final m = Map<String, dynamic>.from(raw as Map);
        return FapmsCashFlowPoint(
          label: m['label'] as String? ?? 'Period',
          inflow: (m['inflow'] as num?)?.toDouble() ?? 0,
          outflow: (m['outflow'] as num?)?.toDouble() ?? 0,
          isProjection: true,
          disclaimer: disclaimer,
        );
      }).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<int> _countPendingClientVerifications(SupabaseClient client) async {
    try {
      final rows = await client
          .from('client_payment_intents')
          .select('id')
          .inFilter('status', ['pending_verification', 'info_requested']);
      return (rows as List).length;
    } catch (e) {
      rethrow;
    }
  }

  Future<int> _countPendingInvestorIntents(SupabaseClient client) async {
    try {
      final rows = await client
          .from('investor_payment_intents')
          .select('id')
          .eq('is_deleted', false)
          .inFilter('status', [
            'pending',
            'submitted',
            'awaiting_confirmation',
          ]);
      return (rows as List).length;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<FapmsInvestorIntent>> _loadInvestorIntents(
    SupabaseClient client,
  ) async {
    try {
      final rows = await client
          .from('investor_payment_intents')
          .select()
          .eq('is_deleted', false)
          .order('created_at', ascending: false)
          .limit(100);
      return rows
          .map(
            (e) => FapmsInvestorIntent.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<FapmsInstallment>> _loadInstallments(
    SupabaseClient client,
  ) async {
    try {
      final rows = await client
          .from('installments')
          .select('*, properties(title)')
          .eq('is_deleted', false)
          .order('due_date', ascending: true)
          .limit(300);
      return rows
          .map(
            (e) =>
                FapmsInstallment.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<FapmsReceipt>> _loadReceipts(SupabaseClient client) async {
    try {
      final rows = await client
          .from('finance_receipts')
          .select()
          .order('issued_at', ascending: false)
          .limit(150);
      return rows
          .map(
            (e) => FapmsReceipt.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<FapmsCharge>> _loadCharges(SupabaseClient client) async {
    try {
      final rows = await client
          .from('payment_charges')
          .select('*, properties(title)')
          .order('created_at', ascending: false)
          .limit(150);
      return rows
          .map((e) => FapmsCharge.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<FapmsDistribution>> _loadDistributions(
    SupabaseClient client,
  ) async {
    try {
      final rows = await client
          .from('investment_distributions')
          .select('*, investors(full_name, email)')
          .order('scheduled_at', ascending: false)
          .limit(100);
      return rows
          .map(
            (e) =>
                FapmsDistribution.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<FapmsInvestmentReceivingAccount>>
  _loadInvestmentReceivingAccounts(SupabaseClient client) async {
    try {
      final rows = await client
          .from('investment_receiving_accounts')
          .select()
          .eq('is_deleted', false)
          .order('is_primary', ascending: false);
      return rows
          .map(
            (e) => FapmsInvestmentReceivingAccount.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<FapmsDepositApplication>> _loadDepositApplications(
    SupabaseClient client,
  ) async {
    try {
      final rows = await client
          .from('client_property_applications')
          .select('*, properties(title)')
          .eq('is_deleted', false)
          .inFilter('status', ['approved', 'payment_pending'])
          .order('updated_at', ascending: false)
          .limit(80);
      return rows
          .map(
            (e) => FapmsDepositApplication.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<FapmsPaymentSettings?> _loadPaymentSettings(
    SupabaseClient client,
  ) async {
    try {
      final rows = await client.from('payment_settings').select().limit(1);
      if ((rows as List).isEmpty) return null;
      return FapmsPaymentSettings.fromJson(
        Map<String, dynamic>.from(rows.first as Map),
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<List<FapmsCalculatorLead>> _loadCalculatorLeads(
    SupabaseClient client,
  ) async {
    try {
      final rows = await client
          .from('calculator_applications')
          .select()
          .order('created_at', ascending: false)
          .limit(150);
      return rows
          .map(
            (e) => FapmsCalculatorLead.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<FapmsCommission>> _loadCommissions(SupabaseClient client) async {
    final out = <FapmsCommission>[];
    try {
      final clientRows = await client
          .from('client_referral_commissions')
          .select()
          .eq('is_deleted', false)
          .order('created_at', ascending: false)
          .limit(80);
      out.addAll(
        (clientRows as List).map(
          (e) => FapmsCommission.fromClientJson(
            Map<String, dynamic>.from(e as Map),
          ),
        ),
      );
    } catch (_) {}
    try {
      final investorRows = await client
          .from('investor_referral_commissions')
          .select()
          .eq('is_deleted', false)
          .order('created_at', ascending: false)
          .limit(80);
      out.addAll(
        (investorRows as List).map(
          (e) => FapmsCommission.fromInvestorJson(
            Map<String, dynamic>.from(e as Map),
          ),
        ),
      );
    } catch (_) {}
    try {
      final salesRows = await client
          .from('sales_commissions')
          .select()
          .order('created_at', ascending: false)
          .limit(80);
      out.addAll(
        (salesRows as List).map(
          (e) => FapmsCommission.fromSalesJson(
            Map<String, dynamic>.from(e as Map),
          ),
        ),
      );
    } catch (_) {}
    return out;
  }
}
