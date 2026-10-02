// Volume 4 Part 7 — Enterprise Finance, Accounting & Payment Management domain models.

const String kFinanceProjectionDisclaimer =
    'PROJECTION — Cash flow and forecast figures are estimates only and are not '
    'guarantees of future liquidity, collections, or results.';

String formatFapmsMoney(double? value) {
  if (value == null) return '—';
  final n = value;
  if (n.abs() >= 1e9) return '₦${(n / 1e9).toStringAsFixed(1)}B';
  if (n.abs() >= 1e6) return '₦${(n / 1e6).toStringAsFixed(1)}M';
  if (n.abs() >= 1e3) return '₦${(n / 1e3).toStringAsFixed(0)}K';
  return '₦${n.toStringAsFixed(0)}';
}

enum InvoiceStatus {
  draft,
  sent,
  paid,
  overdue,
  cancelled,
  partial;

  String get label => switch (this) {
        InvoiceStatus.draft => 'Draft',
        InvoiceStatus.sent => 'Sent',
        InvoiceStatus.paid => 'Paid',
        InvoiceStatus.overdue => 'Overdue',
        InvoiceStatus.cancelled => 'Cancelled',
        InvoiceStatus.partial => 'Partial',
      };

  String get slug => name;

  static InvoiceStatus fromSlug(String? raw) {
    return switch ((raw ?? 'draft').toLowerCase()) {
      'sent' || 'open' => InvoiceStatus.sent,
      'paid' || 'completed' => InvoiceStatus.paid,
      'overdue' => InvoiceStatus.overdue,
      'cancelled' || 'canceled' || 'void' => InvoiceStatus.cancelled,
      'partial' => InvoiceStatus.partial,
      _ => InvoiceStatus.draft,
    };
  }
}

enum PaymentTxStatus {
  pending,
  processing,
  succeeded,
  failed,
  refunded,
  cancelled;

  String get label => switch (this) {
        PaymentTxStatus.pending => 'Pending',
        PaymentTxStatus.processing => 'Processing',
        PaymentTxStatus.succeeded => 'Succeeded',
        PaymentTxStatus.failed => 'Failed',
        PaymentTxStatus.refunded => 'Refunded',
        PaymentTxStatus.cancelled => 'Cancelled',
      };

  String get slug => name;

  static PaymentTxStatus fromSlug(String? raw) {
    return switch ((raw ?? 'pending').toLowerCase()) {
      'processing' => PaymentTxStatus.processing,
      'succeeded' || 'success' || 'completed' => PaymentTxStatus.succeeded,
      'failed' => PaymentTxStatus.failed,
      'refunded' => PaymentTxStatus.refunded,
      'cancelled' || 'canceled' => PaymentTxStatus.cancelled,
      _ => PaymentTxStatus.pending,
    };
  }
}

enum ExpenseStatus {
  draft,
  pending,
  approved,
  rejected,
  paid,
  cancelled;

  String get label => switch (this) {
        ExpenseStatus.draft => 'Draft',
        ExpenseStatus.pending => 'Pending',
        ExpenseStatus.approved => 'Approved',
        ExpenseStatus.rejected => 'Rejected',
        ExpenseStatus.paid => 'Paid',
        ExpenseStatus.cancelled => 'Cancelled',
      };

  String get slug => name;

  static ExpenseStatus fromSlug(String? raw) {
    return switch ((raw ?? 'pending').toLowerCase()) {
      'draft' => ExpenseStatus.draft,
      'approved' => ExpenseStatus.approved,
      'rejected' => ExpenseStatus.rejected,
      'paid' => ExpenseStatus.paid,
      'cancelled' || 'canceled' => ExpenseStatus.cancelled,
      _ => ExpenseStatus.pending,
    };
  }
}

enum AgingBucketKind {
  current,
  d1_30,
  d31_60,
  d61_90,
  d90Plus;

  String get label => switch (this) {
        AgingBucketKind.current => 'Current',
        AgingBucketKind.d1_30 => '1–30',
        AgingBucketKind.d31_60 => '31–60',
        AgingBucketKind.d61_90 => '61–90',
        AgingBucketKind.d90Plus => '90+',
      };

  String get slug => switch (this) {
        AgingBucketKind.current => 'current',
        AgingBucketKind.d1_30 => '1_30',
        AgingBucketKind.d31_60 => '31_60',
        AgingBucketKind.d61_90 => '61_90',
        AgingBucketKind.d90Plus => '90_plus',
      };

  static AgingBucketKind fromSlug(String? raw) {
    return switch ((raw ?? 'current').toLowerCase()) {
      '1_30' || '1-30' => AgingBucketKind.d1_30,
      '31_60' || '31-60' => AgingBucketKind.d31_60,
      '61_90' || '61-90' => AgingBucketKind.d61_90,
      '90_plus' || '90+' || '90plus' => AgingBucketKind.d90Plus,
      _ => AgingBucketKind.current,
    };
  }
}

class FapmsKpi {
  const FapmsKpi({
    required this.label,
    required this.value,
    this.unit = 'count',
  });

  final String label;
  final double value;
  final String unit;

  String get displayValue {
    if (unit == 'ngn') return formatFapmsMoney(value);
    if (unit == 'percent') {
      return value == value.roundToDouble()
          ? '${value.toStringAsFixed(0)}%'
          : '${value.toStringAsFixed(1)}%';
    }
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }
}

class FapmsInvoice {
  const FapmsInvoice({
    required this.id,
    required this.invoiceNumber,
    required this.partyName,
    this.amount = 0,
    this.balanceDue = 0,
    this.status = InvoiceStatus.draft,
    this.dueDate,
    this.issuedAt,
    this.currency = 'NGN',
  });

  final String id;
  final String invoiceNumber;
  final String partyName;
  final double amount;
  final double balanceDue;
  final InvoiceStatus status;
  final DateTime? dueDate;
  final DateTime? issuedAt;
  final String currency;

  String get amountDisplay => formatFapmsMoney(amount);
  String get balanceDisplay => formatFapmsMoney(balanceDue);

  factory FapmsInvoice.fromJson(Map<String, dynamic> json) {
    return FapmsInvoice(
      id: json['id'] as String,
      invoiceNumber: json['invoice_number'] as String? ?? '',
      partyName: json['party_name'] as String? ?? 'Unknown party',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      balanceDue: (json['balance_due'] as num?)?.toDouble() ??
          (json['amount'] as num?)?.toDouble() ??
          0,
      status: InvoiceStatus.fromSlug(json['status'] as String?),
      dueDate: DateTime.tryParse(json['due_date'] as String? ?? ''),
      issuedAt: DateTime.tryParse(json['issued_at'] as String? ?? ''),
      currency: json['currency'] as String? ?? 'NGN',
    );
  }
}

class FapmsPaymentTx {
  const FapmsPaymentTx({
    required this.id,
    required this.provider,
    required this.amount,
    this.status = PaymentTxStatus.pending,
    this.providerReference,
    this.occurredAt,
    this.currency = 'NGN',
    this.direction = 'inbound',
    this.source = 'gateway',
  });

  final String id;
  final String provider;
  final double amount;
  final PaymentTxStatus status;
  final String? providerReference;
  final DateTime? occurredAt;
  final String currency;
  final String direction;
  /// `gateway` | `client` | `investor`
  final String source;

  String get amountDisplay => formatFapmsMoney(amount);
  String get sourceLabel => switch (source) {
        'client' => 'Client portal',
        'investor' => 'Investor portal',
        _ => 'Gateway',
      };

  factory FapmsPaymentTx.fromJson(Map<String, dynamic> json) {
    return FapmsPaymentTx(
      id: json['id'] as String,
      provider: json['provider'] as String? ?? 'manual',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      status: PaymentTxStatus.fromSlug(json['status'] as String?),
      providerReference: json['provider_reference'] as String?,
      occurredAt: DateTime.tryParse(json['occurred_at'] as String? ?? ''),
      currency: json['currency'] as String? ?? 'NGN',
      direction: json['direction'] as String? ?? 'inbound',
      source: json['source'] as String? ?? 'gateway',
    );
  }
}

class FapmsExpense {
  const FapmsExpense({
    required this.id,
    required this.expenseCode,
    required this.title,
    this.amount = 0,
    this.status = ExpenseStatus.pending,
    this.vendorLabel,
    this.submittedByLabel,
    this.incurredAt,
    this.currency = 'NGN',
  });

  final String id;
  final String expenseCode;
  final String title;
  final double amount;
  final ExpenseStatus status;
  final String? vendorLabel;
  final String? submittedByLabel;
  final DateTime? incurredAt;
  final String currency;

  String get amountDisplay => formatFapmsMoney(amount);

  factory FapmsExpense.fromJson(Map<String, dynamic> json) {
    return FapmsExpense(
      id: json['id'] as String,
      expenseCode: json['expense_code'] as String? ?? '',
      title: json['title'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      status: ExpenseStatus.fromSlug(json['status'] as String?),
      vendorLabel: json['vendor_label'] as String?,
      submittedByLabel: json['submitted_by_label'] as String?,
      incurredAt: DateTime.tryParse(json['incurred_at'] as String? ?? ''),
      currency: json['currency'] as String? ?? 'NGN',
    );
  }
}

class FapmsBudget {
  const FapmsBudget({
    required this.id,
    required this.budgetCode,
    required this.name,
    this.totalAmount = 0,
    this.status = 'active',
    this.lines = const [],
    this.variances = const [],
  });

  final String id;
  final String budgetCode;
  final String name;
  final double totalAmount;
  final String status;
  final List<FapmsBudgetLine> lines;
  final List<FapmsBudgetVariance> variances;

  String get totalDisplay => formatFapmsMoney(totalAmount);

  factory FapmsBudget.fromJson(Map<String, dynamic> json) {
    return FapmsBudget(
      id: json['id'] as String,
      budgetCode: json['budget_code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'active',
    );
  }
}

class FapmsBudgetLine {
  const FapmsBudgetLine({
    required this.id,
    required this.budgetId,
    required this.category,
    this.budgetedAmount = 0,
    this.actualAmount = 0,
  });

  final String id;
  final String budgetId;
  final String category;
  final double budgetedAmount;
  final double actualAmount;

  factory FapmsBudgetLine.fromJson(Map<String, dynamic> json) {
    return FapmsBudgetLine(
      id: json['id'] as String,
      budgetId: json['budget_id'] as String? ?? '',
      category: json['category'] as String? ?? '',
      budgetedAmount: (json['budgeted_amount'] as num?)?.toDouble() ?? 0,
      actualAmount: (json['actual_amount'] as num?)?.toDouble() ?? 0,
    );
  }
}

class FapmsBudgetVariance {
  const FapmsBudgetVariance({
    required this.id,
    required this.category,
    this.budgetedAmount = 0,
    this.actualAmount = 0,
    this.varianceAmount = 0,
    this.variancePct,
    this.severity = 'normal',
    this.notes,
  });

  final String id;
  final String category;
  final double budgetedAmount;
  final double actualAmount;
  final double varianceAmount;
  final double? variancePct;
  final String severity;
  final String? notes;

  factory FapmsBudgetVariance.fromJson(Map<String, dynamic> json) {
    return FapmsBudgetVariance(
      id: json['id'] as String,
      category: json['category'] as String? ?? '',
      budgetedAmount: (json['budgeted_amount'] as num?)?.toDouble() ?? 0,
      actualAmount: (json['actual_amount'] as num?)?.toDouble() ?? 0,
      varianceAmount: (json['variance_amount'] as num?)?.toDouble() ?? 0,
      variancePct: (json['variance_pct'] as num?)?.toDouble(),
      severity: json['severity'] as String? ?? 'normal',
      notes: json['notes'] as String?,
    );
  }
}

class FapmsBankAccount {
  const FapmsBankAccount({
    required this.id,
    required this.accountName,
    required this.bankName,
    this.balance = 0,
    this.accountNumberMasked,
    this.currency = 'NGN',
    this.isActive = true,
  });

  final String id;
  final String accountName;
  final String bankName;
  final double balance;
  final String? accountNumberMasked;
  final String currency;
  final bool isActive;

  String get balanceDisplay => formatFapmsMoney(balance);

  factory FapmsBankAccount.fromJson(Map<String, dynamic> json) {
    return FapmsBankAccount(
      id: json['id'] as String,
      accountName: json['account_name'] as String? ?? '',
      bankName: json['bank_name'] as String? ?? '',
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
      accountNumberMasked: json['account_number_masked'] as String?,
      currency: json['currency'] as String? ?? 'NGN',
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class FapmsBankTx {
  const FapmsBankTx({
    required this.id,
    required this.bankAccountId,
    required this.description,
    this.amount = 0,
    this.direction = 'credit',
    this.status = 'posted',
    this.transactionDate,
    this.reference,
  });

  final String id;
  final String bankAccountId;
  final String description;
  final double amount;
  final String direction;
  final String status;
  final DateTime? transactionDate;
  final String? reference;

  String get amountDisplay => formatFapmsMoney(amount);

  factory FapmsBankTx.fromJson(Map<String, dynamic> json) {
    return FapmsBankTx(
      id: json['id'] as String,
      bankAccountId: json['bank_account_id'] as String? ?? '',
      description: json['description'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      direction: json['direction'] as String? ?? 'credit',
      status: json['status'] as String? ?? 'posted',
      transactionDate:
          DateTime.tryParse(json['transaction_date'] as String? ?? ''),
      reference: json['reference'] as String?,
    );
  }
}

class FapmsCashFlowPoint {
  const FapmsCashFlowPoint({
    required this.label,
    this.inflow = 0,
    this.outflow = 0,
    this.isProjection = true,
    this.disclaimer = kFinanceProjectionDisclaimer,
  });

  final String label;
  final double inflow;
  final double outflow;
  final bool isProjection;
  final String disclaimer;

  double get net => inflow - outflow;
  String get netDisplay => formatFapmsMoney(net);
}

class FapmsJournalSummary {
  const FapmsJournalSummary({
    required this.id,
    required this.entryNumber,
    this.memo,
    this.status = 'draft',
    this.entryDate,
    this.lineCount = 0,
    this.totalDebit = 0,
  });

  final String id;
  final String entryNumber;
  final String? memo;
  final String status;
  final DateTime? entryDate;
  final int lineCount;
  final double totalDebit;

  String get debitDisplay => formatFapmsMoney(totalDebit);

  factory FapmsJournalSummary.fromJson(Map<String, dynamic> json) {
    return FapmsJournalSummary(
      id: json['id'] as String,
      entryNumber: json['entry_number'] as String? ?? '',
      memo: json['memo'] as String?,
      status: json['status'] as String? ?? 'draft',
      entryDate: DateTime.tryParse(json['entry_date'] as String? ?? ''),
    );
  }
}

class FapmsAgingBucket {
  const FapmsAgingBucket({
    required this.kind,
    required this.amount,
    this.count = 0,
    this.side = 'ar',
  });

  final AgingBucketKind kind;
  final double amount;
  final int count;
  final String side;

  String get amountDisplay => formatFapmsMoney(amount);
}

class FapmsAgingRow {
  const FapmsAgingRow({
    required this.id,
    required this.partyName,
    required this.amountDue,
    required this.bucket,
    this.side = 'ar',
    this.dueDate,
    this.status = 'open',
  });

  final String id;
  final String partyName;
  final double amountDue;
  final AgingBucketKind bucket;
  final String side;
  final DateTime? dueDate;
  final String status;

  String get amountDisplay => formatFapmsMoney(amountDue);

  factory FapmsAgingRow.fromArJson(Map<String, dynamic> json) {
    return FapmsAgingRow(
      id: json['id'] as String,
      partyName: json['party_name'] as String? ?? '',
      amountDue: (json['amount_due'] as num?)?.toDouble() ?? 0,
      bucket: AgingBucketKind.fromSlug(json['aging_bucket'] as String?),
      side: 'ar',
      dueDate: DateTime.tryParse(json['due_date'] as String? ?? ''),
      status: json['status'] as String? ?? 'open',
    );
  }

  factory FapmsAgingRow.fromApJson(Map<String, dynamic> json) {
    return FapmsAgingRow(
      id: json['id'] as String,
      partyName: json['vendor_name'] as String? ?? '',
      amountDue: (json['amount_due'] as num?)?.toDouble() ?? 0,
      bucket: AgingBucketKind.fromSlug(json['aging_bucket'] as String?),
      side: 'ap',
      dueDate: DateTime.tryParse(json['due_date'] as String? ?? ''),
      status: json['status'] as String? ?? 'open',
    );
  }
}

class FapmsAiInsight {
  const FapmsAiInsight({
    required this.id,
    required this.title,
    required this.body,
    this.category = 'assistant',
    this.isAiGenerated = true,
    this.confidencePct,
    this.disclaimer = kFinanceProjectionDisclaimer,
  });

  final String id;
  final String title;
  final String body;
  final String category;
  final bool isAiGenerated;
  final double? confidencePct;
  final String disclaimer;
}

class FapmsActivity {
  const FapmsActivity({
    required this.id,
    required this.summary,
    this.action,
    this.actorLabel,
    this.occurredAt,
  });

  final String id;
  final String summary;
  final String? action;
  final String? actorLabel;
  final DateTime? occurredAt;

  factory FapmsActivity.fromJson(Map<String, dynamic> json) {
    return FapmsActivity(
      id: json['id'] as String,
      summary: json['summary'] as String? ?? '',
      action: json['action'] as String?,
      actorLabel: json['actor_label'] as String?,
      occurredAt: DateTime.tryParse(json['occurred_at'] as String? ?? ''),
    );
  }
}

class FapmsAlert {
  const FapmsAlert({
    required this.id,
    required this.title,
    this.body,
    this.severity = 'info',
    this.category,
  });

  final String id;
  final String title;
  final String? body;
  final String severity;
  final String? category;

  factory FapmsAlert.fromJson(Map<String, dynamic> json) {
    return FapmsAlert(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      body: json['body'] as String?,
      severity: json['severity'] as String? ?? 'info',
      category: json['category'] as String?,
    );
  }
}

class FapmsCommandCenterSnapshot {
  const FapmsCommandCenterSnapshot({
    required this.kpis,
    required this.invoices,
    required this.paymentTxs,
    required this.expenses,
    required this.budgets,
    required this.budgetLines,
    required this.budgetVariances,
    required this.bankAccounts,
    required this.bankTxs,
    required this.journals,
    required this.arRows,
    required this.apRows,
    required this.arBuckets,
    required this.apBuckets,
    required this.cashFlow,
    required this.activities,
    required this.alerts,
    required this.aiInsights,
    this.investorIntents = const [],
    this.installments = const [],
    this.receipts = const [],
    this.charges = const [],
    this.distributions = const [],
    this.investmentReceivingAccounts = const [],
    this.depositApplications = const [],
    this.paymentSettings,
    this.calculatorLeads = const [],
    this.commissions = const [],
    this.pendingClientVerifications = 0,
    this.pendingInvestorIntents = 0,
    this.fromRemote = false,
    this.loadedAt,
    this.loadWarnings = const [],
    this.projectionDisclaimer = kFinanceProjectionDisclaimer,
  });

  /// Empty snapshot when Supabase is not configured — no demo placeholder data.
  factory FapmsCommandCenterSnapshot.empty() {
    return FapmsCommandCenterSnapshot(
      kpis: const [],
      invoices: const [],
      paymentTxs: const [],
      expenses: const [],
      budgets: const [],
      budgetLines: const [],
      budgetVariances: const [],
      bankAccounts: const [],
      bankTxs: const [],
      journals: const [],
      arRows: const [],
      apRows: const [],
      arBuckets: const [],
      apBuckets: const [],
      cashFlow: const [],
      activities: const [],
      alerts: const [],
      aiInsights: const [],
      loadWarnings: const ['Supabase is not configured — connect to load live finance data.'],
    );
  }

  final List<FapmsKpi> kpis;
  final List<FapmsInvoice> invoices;
  final List<FapmsPaymentTx> paymentTxs;
  final List<FapmsExpense> expenses;
  final List<FapmsBudget> budgets;
  final List<FapmsBudgetLine> budgetLines;
  final List<FapmsBudgetVariance> budgetVariances;
  final List<FapmsBankAccount> bankAccounts;
  final List<FapmsBankTx> bankTxs;
  final List<FapmsJournalSummary> journals;
  final List<FapmsAgingRow> arRows;
  final List<FapmsAgingRow> apRows;
  final List<FapmsAgingBucket> arBuckets;
  final List<FapmsAgingBucket> apBuckets;
  final List<FapmsCashFlowPoint> cashFlow;
  final List<FapmsActivity> activities;
  final List<FapmsAlert> alerts;
  final List<FapmsAiInsight> aiInsights;
  final List<FapmsInvestorIntent> investorIntents;
  final List<FapmsInstallment> installments;
  final List<FapmsReceipt> receipts;
  final List<FapmsCharge> charges;
  final List<FapmsDistribution> distributions;
  final List<FapmsInvestmentReceivingAccount> investmentReceivingAccounts;
  final List<FapmsDepositApplication> depositApplications;
  final FapmsPaymentSettings? paymentSettings;
  final List<FapmsCalculatorLead> calculatorLeads;
  final List<FapmsCommission> commissions;
  final int pendingClientVerifications;
  final int pendingInvestorIntents;
  final bool fromRemote;
  final DateTime? loadedAt;
  /// Non-fatal load issues (RLS, missing tables) — surfaced in admin UI.
  final List<String> loadWarnings;
  final String projectionDisclaimer;

  List<FapmsExpense> get pendingApprovals => expenses
      .where((e) => e.status == ExpenseStatus.pending)
      .toList(growable: false);

  int get overdueInstallmentCount => installments
      .where((i) => i.status == 'overdue' || i.isOverdue)
      .length;

  int get openChargeCount =>
      charges.where((c) => c.status == 'pending' || c.status == 'applied').length;

  int get openLeadCount => calculatorLeads
      .where((l) => l.status == 'new' || l.status == 'contacted')
      .length;

  int get openCommissionCount =>
      commissions.where((c) => c.status == 'pending' || c.status == 'approved').length;
}

/// Client installment schedule row for finance ops.
class FapmsInstallment {
  const FapmsInstallment({
    required this.id,
    required this.amount,
    required this.dueDate,
    this.clientId,
    this.propertyId,
    this.propertyTitle,
    this.status = 'pending',
    this.amountPaid = 0,
    this.amountOutstanding,
    this.installmentNumber,
  });

  factory FapmsInstallment.fromJson(Map<String, dynamic> json) {
    final props = json['properties'];
    String? title;
    if (props is Map) {
      title = props['title'] as String?;
    }
    return FapmsInstallment(
      id: '${json['id']}',
      clientId: json['client_id']?.toString(),
      propertyId: json['property_id']?.toString(),
      propertyTitle: title,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      amountPaid: (json['amount_paid'] as num?)?.toDouble() ?? 0,
      amountOutstanding: (json['amount_outstanding'] as num?)?.toDouble(),
      dueDate: DateTime.tryParse('${json['due_date'] ?? ''}') ?? DateTime.now(),
      status: json['status'] as String? ?? 'pending',
      installmentNumber: json['installment_number'] as int?,
    );
  }

  final String id;
  final String? clientId;
  final String? propertyId;
  final String? propertyTitle;
  final double amount;
  final double amountPaid;
  final double? amountOutstanding;
  final DateTime dueDate;
  final String status;
  final int? installmentNumber;

  String get amountDisplay => formatFapmsMoney(amount);
  String get outstandingDisplay =>
      formatFapmsMoney(amountOutstanding ?? (amount - amountPaid));
  bool get isOverdue =>
      status != 'paid' &&
      status != 'completed' &&
      status != 'cancelled' &&
      status != 'waived' &&
      dueDate.isBefore(DateTime.now());
  String get label {
    if (installmentNumber == 0) return 'Deposit';
    if (installmentNumber != null) return 'Installment #$installmentNumber';
    return 'Installment';
  }
}

class FapmsReceipt {
  const FapmsReceipt({
    required this.id,
    required this.receiptNumber,
    required this.amount,
    this.payerLabel,
    this.methodLabel,
    this.issuedAt,
    this.currency = 'NGN',
    this.paymentId,
  });

  factory FapmsReceipt.fromJson(Map<String, dynamic> json) {
    return FapmsReceipt(
      id: '${json['id']}',
      receiptNumber: json['receipt_number'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      payerLabel: json['payer_label'] as String?,
      methodLabel: json['method_label'] as String?,
      issuedAt: DateTime.tryParse('${json['issued_at'] ?? ''}'),
      currency: json['currency'] as String? ?? 'NGN',
      paymentId: json['payment_id']?.toString(),
    );
  }

  final String id;
  final String receiptNumber;
  final double amount;
  final String? payerLabel;
  final String? methodLabel;
  final DateTime? issuedAt;
  final String currency;
  final String? paymentId;

  String get amountDisplay => formatFapmsMoney(amount);
}

class FapmsCharge {
  const FapmsCharge({
    required this.id,
    required this.description,
    required this.amount,
    this.clientId,
    this.chargeType = 'late_payment_fee',
    this.status = 'applied',
    this.dueDate,
    this.propertyTitle,
  });

  factory FapmsCharge.fromJson(Map<String, dynamic> json) {
    final props = json['properties'];
    String? title;
    if (props is Map) title = props['title'] as String?;
    return FapmsCharge(
      id: '${json['id']}',
      clientId: json['client_id']?.toString(),
      description: json['description'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      chargeType: json['charge_type'] as String? ?? 'late_payment_fee',
      status: json['status'] as String? ?? 'applied',
      dueDate: DateTime.tryParse('${json['due_date'] ?? ''}'),
      propertyTitle: title,
    );
  }

  final String id;
  final String? clientId;
  final String description;
  final double amount;
  final String chargeType;
  final String status;
  final DateTime? dueDate;
  final String? propertyTitle;

  String get amountDisplay => formatFapmsMoney(amount);
  bool get canWaive => status == 'pending' || status == 'applied';
}

class FapmsDistribution {
  const FapmsDistribution({
    required this.id,
    required this.investorId,
    required this.amount,
    this.status = 'scheduled',
    this.distributionType = 'dividend',
    this.reference,
    this.scheduledAt,
    this.paidAt,
    this.notes,
    this.investorName,
  });

  factory FapmsDistribution.fromJson(Map<String, dynamic> json) {
    final inv = json['investors'];
    String? name;
    if (inv is Map) {
      name = inv['full_name'] as String? ?? inv['email'] as String?;
    }
    return FapmsDistribution(
      id: '${json['id']}',
      investorId: '${json['investor_id']}',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'scheduled',
      distributionType: json['distribution_type'] as String? ?? 'dividend',
      reference: json['reference'] as String?,
      scheduledAt: DateTime.tryParse('${json['scheduled_at'] ?? ''}'),
      paidAt: DateTime.tryParse('${json['paid_at'] ?? ''}'),
      notes: json['notes'] as String?,
      investorName: name,
    );
  }

  final String id;
  final String investorId;
  final double amount;
  final String status;
  final String distributionType;
  final String? reference;
  final DateTime? scheduledAt;
  final DateTime? paidAt;
  final String? notes;
  final String? investorName;

  String get amountDisplay => formatFapmsMoney(amount);
  bool get canMarkPaid => status == 'scheduled' || status == 'pending';
}

class FapmsInvestmentReceivingAccount {
  const FapmsInvestmentReceivingAccount({
    required this.id,
    required this.bankName,
    required this.accountName,
    required this.accountNumber,
    this.currency = 'NGN',
    this.instructions,
    this.isPrimary = false,
    this.isActive = true,
  });

  factory FapmsInvestmentReceivingAccount.fromJson(Map<String, dynamic> json) {
    return FapmsInvestmentReceivingAccount(
      id: '${json['id']}',
      bankName: json['bank_name'] as String? ?? '',
      accountName: json['account_name'] as String? ?? '',
      accountNumber: json['account_number'] as String? ?? '',
      currency: json['currency'] as String? ?? 'NGN',
      instructions: json['instructions'] as String?,
      isPrimary: json['is_primary'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  final String id;
  final String bankName;
  final String accountName;
  final String accountNumber;
  final String currency;
  final String? instructions;
  final bool isPrimary;
  final bool isActive;
}

class FapmsDepositApplication {
  const FapmsDepositApplication({
    required this.id,
    required this.clientId,
    this.propertyId,
    this.propertyTitle,
    this.amountOffered,
    this.paymentPlan,
    this.status = 'payment_pending',
    this.createdAt,
  });

  factory FapmsDepositApplication.fromJson(Map<String, dynamic> json) {
    final props = json['properties'];
    String? title;
    if (props is Map) title = props['title'] as String?;
    return FapmsDepositApplication(
      id: '${json['id']}',
      clientId: '${json['client_id']}',
      propertyId: json['property_id']?.toString(),
      propertyTitle: title,
      amountOffered: (json['amount_offered'] as num?)?.toDouble(),
      paymentPlan: json['payment_plan'] as String?,
      status: json['status'] as String? ?? 'payment_pending',
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
    );
  }

  final String id;
  final String clientId;
  final String? propertyId;
  final String? propertyTitle;
  final double? amountOffered;
  final String? paymentPlan;
  final String status;
  final DateTime? createdAt;

  String get amountDisplay => formatFapmsMoney(amountOffered);
}

class FapmsCalculatorLead {
  const FapmsCalculatorLead({
    required this.id,
    required this.fullName,
    this.email,
    this.phone,
    this.city = '',
    this.preferredContact = 'phone',
    this.occupation = '',
    this.applicantMessage = '',
    this.adminReply = '',
    this.propertyId,
    this.propertyPrice,
    this.depositAmount,
    this.monthlyPayment,
    this.durationMonths,
    this.status = 'new',
    this.createdAt,
  });

  factory FapmsCalculatorLead.fromJson(Map<String, dynamic> json) {
    return FapmsCalculatorLead(
      id: '${json['id']}',
      fullName: json['full_name'] as String? ?? 'Website lead',
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      city: json['city'] as String? ?? '',
      preferredContact: json['preferred_contact'] as String? ?? 'phone',
      occupation: json['occupation'] as String? ?? '',
      applicantMessage: json['applicant_message'] as String? ?? '',
      adminReply: json['admin_reply'] as String? ?? '',
      propertyId: json['property_id']?.toString(),
      propertyPrice: (json['property_price'] as num?)?.toDouble(),
      depositAmount: (json['deposit_amount'] as num?)?.toDouble(),
      monthlyPayment: (json['monthly_payment'] as num?)?.toDouble(),
      durationMonths: (json['duration_months'] as num?)?.toInt(),
      status: json['status'] as String? ?? 'new',
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
    );
  }

  final String id;
  final String fullName;
  final String? email;
  final String? phone;
  final String city;
  final String preferredContact;
  final String occupation;
  final String applicantMessage;
  final String adminReply;
  final String? propertyId;
  final double? propertyPrice;
  final double? depositAmount;
  final double? monthlyPayment;
  final int? durationMonths;
  final String status;
  final DateTime? createdAt;

  String get depositDisplay => formatFapmsMoney(depositAmount);
  String get priceDisplay => formatFapmsMoney(propertyPrice);
  bool get canConvert => status == 'new' || status == 'contacted' || status == 'qualified';
  bool get hasReply => adminReply.trim().isNotEmpty;

  String get preferredContactLabel => switch (preferredContact) {
        'email' => 'Email',
        'whatsapp' => 'WhatsApp',
        _ => 'Phone',
      };
}

class FapmsCommission {
  const FapmsCommission({
    required this.id,
    required this.source,
    required this.amount,
    this.label,
    this.referralCode,
    this.status = 'pending',
    this.paidAt,
    this.currency = 'NGN',
  });

  factory FapmsCommission.fromClientJson(Map<String, dynamic> json) {
    return FapmsCommission(
      id: '${json['id']}',
      source: 'client_referral',
      amount: (json['commission_amount'] as num?)?.toDouble() ?? 0,
      label: 'Client referral',
      referralCode: json['referral_code'] as String?,
      status: json['status'] as String? ?? 'pending',
      paidAt: DateTime.tryParse('${json['paid_at'] ?? ''}'),
      currency: json['currency'] as String? ?? 'NGN',
    );
  }

  factory FapmsCommission.fromInvestorJson(Map<String, dynamic> json) {
    return FapmsCommission(
      id: '${json['id']}',
      source: 'investor_referral',
      amount: (json['commission_amount'] as num?)?.toDouble() ?? 0,
      label: 'Investor referral',
      referralCode: json['referral_code'] as String?,
      status: json['status'] as String? ?? 'pending',
      paidAt: DateTime.tryParse('${json['paid_at'] ?? ''}'),
      currency: json['currency'] as String? ?? 'NGN',
    );
  }

  factory FapmsCommission.fromSalesJson(Map<String, dynamic> json) {
    return FapmsCommission(
      id: '${json['id']}',
      source: 'sales',
      amount: (json['commission_amount'] as num?)?.toDouble() ?? 0,
      label: json['agent_name'] as String? ??
          json['commission_code'] as String? ??
          'Sales commission',
      referralCode: json['commission_code'] as String?,
      status: json['status'] as String? ?? 'pending',
      paidAt: DateTime.tryParse('${json['paid_at'] ?? ''}'),
      currency: json['currency'] as String? ?? 'NGN',
    );
  }

  final String id;
  /// `client_referral` | `investor_referral` | `sales`
  final String source;
  final double amount;
  final String? label;
  final String? referralCode;
  final String status;
  final DateTime? paidAt;
  final String currency;

  String get amountDisplay => formatFapmsMoney(amount);
  bool get canApprove => status == 'pending';
  bool get canPay => status == 'pending' || status == 'approved';
}

class FapmsPaymentSettings {
  const FapmsPaymentSettings({
    required this.id,
    this.allowPartialPayments = false,
    this.overpaymentPolicy = 'reject',
    this.requireTransferProof = true,
  });

  factory FapmsPaymentSettings.fromJson(Map<String, dynamic> json) {
    return FapmsPaymentSettings(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 1,
      allowPartialPayments: json['allow_partial_payments'] as bool? ?? false,
      overpaymentPolicy: json['overpayment_policy'] as String? ?? 'reject',
      requireTransferProof: json['require_transfer_proof'] as bool? ?? true,
    );
  }

  final int id;
  final bool allowPartialPayments;
  final String overpaymentPolicy;
  final bool requireTransferProof;
}

/// Investor bank-transfer intents surfaced in finance admin for confirmation.
class FapmsInvestorIntent {
  const FapmsInvestorIntent({
    required this.id,
    required this.amount,
    this.currency = 'NGN',
    this.provider = 'bank_transfer',
    this.providerReference,
    this.bankReference,
    this.status = 'pending',
    this.createdAt,
    this.notes,
  });

  factory FapmsInvestorIntent.fromJson(Map<String, dynamic> json) {
    return FapmsInvestorIntent(
      id: '${json['id']}',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'NGN',
      provider: json['provider'] as String? ?? 'bank_transfer',
      providerReference: json['provider_reference'] as String?,
      bankReference: json['bank_reference'] as String?,
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
      notes: json['notes'] as String?,
    );
  }

  final String id;
  final double amount;
  final String currency;
  final String provider;
  final String? providerReference;
  final String? bankReference;
  final String status;
  final DateTime? createdAt;
  final String? notes;

  String get amountDisplay => formatFapmsMoney(amount);
  bool get isPending =>
      status == 'pending' ||
      status == 'submitted' ||
      status == 'awaiting_confirmation';
}

/// Default / offline FAPMS dataset when DB is empty or unavailable.
abstract final class FapmsDemo {
  static FapmsCommandCenterSnapshot snapshot() {
    final now = DateTime.now();
    final invoices = _invoices(now);
    final txs = _paymentTxs(now);
    final expenses = _expenses(now);
    final budgets = _budgets();
    final lines = _budgetLines();
    final variances = _variances();
    final banks = _banks();
    final bankTxs = _bankTxs(now);
    final journals = _journals(now);
    final ar = _ar(now);
    final ap = _ap(now);
    final cashFlow = _cashFlow();
    final activities = _activities(now);
    final alerts = _alerts();

    return FapmsCommandCenterSnapshot(
      kpis: aggregateKpis(
        invoices: invoices,
        paymentTxs: txs,
        expenses: expenses,
        bankAccounts: banks,
        arRows: ar,
        apRows: ap,
      ),
      invoices: invoices,
      paymentTxs: txs,
      expenses: expenses,
      budgets: budgets,
      budgetLines: lines,
      budgetVariances: variances,
      bankAccounts: banks,
      bankTxs: bankTxs,
      journals: journals,
      arRows: ar,
      apRows: ap,
      arBuckets: rollupAging(ar, side: 'ar'),
      apBuckets: rollupAging(ap, side: 'ap'),
      cashFlow: cashFlow,
      activities: activities,
      alerts: alerts,
      aiInsights: _aiInsights(),
      fromRemote: false,
      loadedAt: now,
    );
  }

  static List<FapmsKpi> aggregateKpis({
    required List<FapmsInvoice> invoices,
    required List<FapmsPaymentTx> paymentTxs,
    required List<FapmsExpense> expenses,
    required List<FapmsBankAccount> bankAccounts,
    required List<FapmsAgingRow> arRows,
    required List<FapmsAgingRow> apRows,
    int pendingClientVerifications = 0,
    int pendingInvestorIntents = 0,
    double clientCapturedAmount = 0,
  }) {
    final cash = bankAccounts.fold<double>(0, (s, b) => s + b.balance);
    final arOpen = arRows.fold<double>(0, (s, r) => s + r.amountDue);
    final apOpen = apRows.fold<double>(0, (s, r) => s + r.amountDue);
    final overdue = invoices.where((i) => i.status == InvoiceStatus.overdue);
    final overdueAmount =
        overdue.fold<double>(0, (s, i) => s + i.amount);
    final openInvoiceAmount = invoices
        .where(
          (i) =>
              i.status == InvoiceStatus.sent ||
              i.status == InvoiceStatus.partial ||
              i.status == InvoiceStatus.overdue,
        )
        .fold<double>(0, (s, i) => s + i.amount);
    final gatewaySucceeded = paymentTxs
        .where(
          (t) =>
              t.status == PaymentTxStatus.succeeded && t.source != 'client',
        )
        .fold<double>(0, (s, t) => s + t.amount);
    final captured = gatewaySucceeded + clientCapturedAmount;
    final pendingExp =
        expenses.where((e) => e.status == ExpenseStatus.pending).length;

    // Collections health: share of open invoice value that is not overdue.
    double collectionsHealth;
    if (openInvoiceAmount <= 0 && overdueAmount <= 0) {
      collectionsHealth = 100;
    } else if (openInvoiceAmount <= 0) {
      collectionsHealth = 0;
    } else {
      collectionsHealth =
          ((1 - (overdueAmount / openInvoiceAmount)) * 100).clamp(0, 100);
    }

    return [
      FapmsKpi(label: 'Cash on Hand', value: cash, unit: 'ngn'),
      FapmsKpi(label: 'Open AR', value: arOpen, unit: 'ngn'),
      FapmsKpi(label: 'Open AP', value: apOpen, unit: 'ngn'),
      FapmsKpi(label: 'Overdue Invoices', value: overdue.length.toDouble()),
      FapmsKpi(label: 'Payments Captured', value: captured, unit: 'ngn'),
      FapmsKpi(
        label: 'Pending Approvals',
        value: pendingExp.toDouble() +
            pendingClientVerifications.toDouble() +
            pendingInvestorIntents.toDouble(),
      ),
      FapmsKpi(
        label: 'Invoice Volume',
        value: invoices.fold<double>(0, (s, i) => s + i.amount),
        unit: 'ngn',
      ),
      FapmsKpi(
        label: 'Collections Health',
        value: collectionsHealth,
        unit: 'percent',
      ),
    ];
  }

  static List<FapmsAgingBucket> rollupAging(
    List<FapmsAgingRow> rows, {
    required String side,
  }) {
    final map = <AgingBucketKind, FapmsAgingBucket>{};
    for (final kind in AgingBucketKind.values) {
      map[kind] = FapmsAgingBucket(kind: kind, amount: 0, count: 0, side: side);
    }
    for (final row in rows) {
      final cur = map[row.bucket]!;
      map[row.bucket] = FapmsAgingBucket(
        kind: row.bucket,
        amount: cur.amount + row.amountDue,
        count: cur.count + 1,
        side: side,
      );
    }
    return AgingBucketKind.values.map((k) => map[k]!).toList();
  }

  static List<FapmsInvoice> _invoices(DateTime now) => [
        FapmsInvoice(
          id: 'f4700000-0000-4000-8000-000000000060',
          invoiceNumber: 'INV-FAPMS-001',
          partyName: 'Adaeze Okonkwo',
          amount: 45000000,
          balanceDue: 0,
          status: InvoiceStatus.paid,
          dueDate: now.subtract(const Duration(days: 10)),
          issuedAt: now.subtract(const Duration(days: 40)),
        ),
        FapmsInvoice(
          id: 'f4700000-0000-4000-8000-000000000061',
          invoiceNumber: 'INV-FAPMS-002',
          partyName: 'Chinedu Mensah',
          amount: 18500000,
          balanceDue: 18500000,
          status: InvoiceStatus.overdue,
          dueDate: now.subtract(const Duration(days: 21)),
          issuedAt: now.subtract(const Duration(days: 50)),
        ),
        FapmsInvoice(
          id: 'f4700000-0000-4000-8000-000000000062',
          invoiceNumber: 'INV-FAPMS-003',
          partyName: 'Lekki Holdings Ltd',
          amount: 9200000,
          balanceDue: 9200000,
          status: InvoiceStatus.sent,
          dueDate: now.add(const Duration(days: 14)),
          issuedAt: now.subtract(const Duration(days: 5)),
        ),
      ];

  static List<FapmsPaymentTx> _paymentTxs(DateTime now) => [
        FapmsPaymentTx(
          id: 'f4700000-0000-4000-8000-000000000090',
          provider: 'paystack',
          amount: 45000000,
          status: PaymentTxStatus.succeeded,
          providerReference: 'PSK-demo-001',
          occurredAt: now.subtract(const Duration(days: 12)),
        ),
        FapmsPaymentTx(
          id: 'f4700000-0000-4000-8000-000000000091',
          provider: 'flutterwave',
          amount: 18500000,
          status: PaymentTxStatus.pending,
          providerReference: 'FLW-demo-pending',
          occurredAt: now.subtract(const Duration(days: 1)),
        ),
        FapmsPaymentTx(
          id: 'f4700000-0000-4000-8000-000000000092',
          provider: 'bank_transfer',
          amount: 5000000,
          status: PaymentTxStatus.succeeded,
          providerReference: 'BT-demo-8842',
          occurredAt: now.subtract(const Duration(days: 3)),
        ),
      ];

  static List<FapmsExpense> _expenses(DateTime now) => [
        FapmsExpense(
          id: 'f4700000-0000-4000-8000-0000000000e0',
          expenseCode: 'EXP-FAPMS-001',
          title: 'Block B rebar delivery',
          amount: 12500000,
          status: ExpenseStatus.pending,
          vendorLabel: 'SteelHub Lagos',
          submittedByLabel: 'Engr. Ngozi Eze',
          incurredAt: now.subtract(const Duration(days: 2)),
        ),
        FapmsExpense(
          id: 'f4700000-0000-4000-8000-0000000000e1',
          expenseCode: 'EXP-FAPMS-002',
          title: 'Q3 digital ads boost',
          amount: 3200000,
          status: ExpenseStatus.pending,
          vendorLabel: 'Meta Ads',
          submittedByLabel: 'Marketing Ops',
          incurredAt: now.subtract(const Duration(days: 1)),
        ),
      ];

  static List<FapmsBudget> _budgets() => const [
        FapmsBudget(
          id: 'f4700000-0000-4000-8000-0000000000d0',
          budgetCode: 'BUD-FY26-Q3',
          name: 'Q3 Operating Budget',
          totalAmount: 250000000,
        ),
      ];

  static List<FapmsBudgetLine> _budgetLines() => const [
        FapmsBudgetLine(
          id: 'f4700000-0000-4000-8000-0000000000d1',
          budgetId: 'f4700000-0000-4000-8000-0000000000d0',
          category: 'Operating Expenses',
          budgetedAmount: 80000000,
          actualAmount: 62000000,
        ),
        FapmsBudgetLine(
          id: 'f4700000-0000-4000-8000-0000000000d2',
          budgetId: 'f4700000-0000-4000-8000-0000000000d0',
          category: 'Construction Costs',
          budgetedAmount: 140000000,
          actualAmount: 152000000,
        ),
        FapmsBudgetLine(
          id: 'f4700000-0000-4000-8000-0000000000d3',
          budgetId: 'f4700000-0000-4000-8000-0000000000d0',
          category: 'Sales Commissions',
          budgetedAmount: 30000000,
          actualAmount: 18500000,
        ),
      ];

  static List<FapmsBudgetVariance> _variances() => const [
        FapmsBudgetVariance(
          id: 'f4700000-0000-4000-8000-0000000000d8',
          category: 'Construction Costs',
          budgetedAmount: 140000000,
          actualAmount: 152000000,
          varianceAmount: 12000000,
          variancePct: 8.57,
          severity: 'watch',
          notes: 'Construction spend ahead of plan — review change orders',
        ),
      ];

  static List<FapmsBankAccount> _banks() => const [
        FapmsBankAccount(
          id: 'f4700000-0000-4000-8000-000000000050',
          accountName: 'HD Homes Operating',
          bankName: 'Access Bank',
          balance: 428500000,
          accountNumberMasked: '****8842',
        ),
      ];

  static List<FapmsBankTx> _bankTxs(DateTime now) => [
        FapmsBankTx(
          id: 'f4700000-0000-4000-8000-0000000000c0',
          bankAccountId: 'f4700000-0000-4000-8000-000000000050',
          description: 'Paystack settlement INV-FAPMS-001',
          amount: 45000000,
          direction: 'credit',
          status: 'reconciled',
          transactionDate: now.subtract(const Duration(days: 12)),
          reference: 'PSK-demo-001',
        ),
        FapmsBankTx(
          id: 'f4700000-0000-4000-8000-0000000000c2',
          bankAccountId: 'f4700000-0000-4000-8000-000000000050',
          description: 'Site materials vendor payout',
          amount: 8500000,
          direction: 'debit',
          status: 'posted',
          transactionDate: now.subtract(const Duration(days: 2)),
          reference: 'AP-out-001',
        ),
      ];

  static List<FapmsJournalSummary> _journals(DateTime now) => [
        FapmsJournalSummary(
          id: 'f4700000-0000-4000-8000-0000000000b0',
          entryNumber: 'JE-2026-0001',
          memo: 'Recognize Paystack receipt INV-FAPMS-001',
          status: 'posted',
          entryDate: now.subtract(const Duration(days: 12)),
          lineCount: 2,
          totalDebit: 45000000,
        ),
      ];

  static List<FapmsAgingRow> _ar(DateTime now) => [
        FapmsAgingRow(
          id: 'f4700000-0000-4000-8000-0000000000f0',
          partyName: 'Chinedu Mensah',
          amountDue: 18500000,
          bucket: AgingBucketKind.d1_30,
          dueDate: now.subtract(const Duration(days: 21)),
        ),
        FapmsAgingRow(
          id: 'f4700000-0000-4000-8000-0000000000f1',
          partyName: 'Lekki Holdings Ltd',
          amountDue: 9200000,
          bucket: AgingBucketKind.current,
          dueDate: now.add(const Duration(days: 14)),
        ),
      ];

  static List<FapmsAgingRow> _ap(DateTime now) => [
        FapmsAgingRow(
          id: 'f4700000-0000-4000-8000-0000000000f8',
          partyName: 'SteelHub Lagos',
          amountDue: 12500000,
          bucket: AgingBucketKind.current,
          side: 'ap',
          dueDate: now.add(const Duration(days: 7)),
        ),
        FapmsAgingRow(
          id: 'f4700000-0000-4000-8000-0000000000f9',
          partyName: 'Utility Co. Ajah',
          amountDue: 4800000,
          bucket: AgingBucketKind.d31_60,
          side: 'ap',
          dueDate: now.subtract(const Duration(days: 40)),
        ),
      ];

  static List<FapmsCashFlowPoint> _cashFlow() => const [
        FapmsCashFlowPoint(label: 'Week 1–4', inflow: 45000000, outflow: 38000000),
        FapmsCashFlowPoint(label: 'Week 5–8', inflow: 52000000, outflow: 41000000),
        FapmsCashFlowPoint(label: 'Week 9–12', inflow: 48000000, outflow: 44000000),
      ];

  static List<FapmsActivity> _activities(DateTime now) => [
        FapmsActivity(
          id: 'f4700000-0000-4000-8000-000000000120',
          summary: 'Paystack captured ₦45M for INV-FAPMS-001',
          action: 'payment.captured',
          actorLabel: 'System',
          occurredAt: now.subtract(const Duration(days: 12)),
        ),
        FapmsActivity(
          id: 'f4700000-0000-4000-8000-000000000121',
          summary: 'Expense EXP-FAPMS-001 submitted for approval',
          action: 'expense.submitted',
          actorLabel: 'Engr. Ngozi Eze',
          occurredAt: now.subtract(const Duration(days: 2)),
        ),
        FapmsActivity(
          id: 'f4700000-0000-4000-8000-000000000122',
          summary: 'INV-FAPMS-002 marked overdue',
          action: 'invoice.overdue',
          actorLabel: 'Finance Bot',
          occurredAt: now.subtract(const Duration(days: 1)),
        ),
      ];

  static List<FapmsAlert> _alerts() => const [
        FapmsAlert(
          id: 'f4700000-0000-4000-8000-000000000128',
          title: 'Overdue invoice alert',
          body: 'INV-FAPMS-002 is 21+ days past due (₦18.5M).',
          severity: 'warning',
          category: 'ar',
        ),
        FapmsAlert(
          id: 'f4700000-0000-4000-8000-000000000129',
          title: 'Expense approval needed',
          body: 'Two expenses await finance approval.',
          severity: 'info',
          category: 'approvals',
        ),
        FapmsAlert(
          id: 'f4700000-0000-4000-8000-00000000012a',
          title: 'Budget watch',
          body: 'Construction Costs variance +8.6% vs plan.',
          severity: 'warning',
          category: 'budgets',
        ),
      ];

  static List<FapmsAiInsight> _aiInsights() => const [
        FapmsAiInsight(
          id: 'ai-1',
          title: 'Collections risk concentrated',
          body:
              'One overdue invoice (INV-FAPMS-002) accounts for majority of AR pressure. '
              'Prioritize reminder cadence and optional settlement offer.',
          category: 'collections',
          confidencePct: 81,
        ),
        FapmsAiInsight(
          id: 'ai-2',
          title: 'Construction budget watch',
          body:
              'Construction Costs are ~8.6% over plan. Cross-check CPMS change orders '
              'before approving further site expenses.',
          category: 'budget',
          confidencePct: 76,
        ),
        FapmsAiInsight(
          id: 'ai-3',
          title: 'Liquidity outlook (projection)',
          body:
              'Next 90 days net cash remains positive if overdue AR collects within 14 days. '
              'Gateway pending Flutterwave capture remains unresolved.',
          category: 'cashflow',
          confidencePct: 68,
        ),
      ];
}
