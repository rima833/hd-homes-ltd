import 'package:intl/intl.dart';

final _ngn = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

String formatNgn(num value) => _ngn.format(value);

/// Server-side rollup from RPC `client_payment_summary`.
class ClientPaymentSummary {
  const ClientPaymentSummary({
    required this.clientId,
    this.currency = 'NGN',
    this.propertyValue = 0,
    this.totalPaid = 0,
    this.outstanding = 0,
    this.chargesOutstanding = 0,
    this.pendingVerification = 0,
    this.totalPayable = 0,
    this.nextPayment,
  });

  factory ClientPaymentSummary.fromJson(Map<String, dynamic> json) {
    final next = json['next_payment'];
    return ClientPaymentSummary(
      clientId: json['client_id'] as String? ?? '',
      currency: json['currency'] as String? ?? 'NGN',
      propertyValue: (json['property_value'] as num?)?.toDouble() ?? 0,
      totalPaid: (json['total_paid'] as num?)?.toDouble() ?? 0,
      outstanding: (json['outstanding'] as num?)?.toDouble() ?? 0,
      chargesOutstanding:
          (json['charges_outstanding'] as num?)?.toDouble() ?? 0,
      pendingVerification:
          (json['pending_verification'] as num?)?.toDouble() ?? 0,
      totalPayable: (json['total_payable'] as num?)?.toDouble() ?? 0,
      nextPayment: next is Map
          ? ClientNextPayment.fromJson(Map<String, dynamic>.from(next))
          : null,
    );
  }

  final String clientId;
  final String currency;
  final double propertyValue;
  final double totalPaid;
  final double outstanding;
  final double chargesOutstanding;
  final double pendingVerification;
  final double totalPayable;
  final ClientNextPayment? nextPayment;

  /// Progress 0–1 from total_paid / (total_paid + outstanding).
  double? get paidProgress {
    final denom = totalPaid + outstanding;
    if (denom <= 0) return null;
    return (totalPaid / denom).clamp(0.0, 1.0);
  }

  String get formattedPropertyValue => formatNgn(propertyValue);
  String get formattedTotalPaid => formatNgn(totalPaid);
  String get formattedOutstanding => formatNgn(outstanding);
  String get formattedNextPayment {
    final next = nextPayment;
    if (next == null) return '—';
    return formatNgn(next.amountOutstanding > 0 ? next.amountOutstanding : next.amount);
  }
}

class ClientNextPayment {
  const ClientNextPayment({
    required this.installmentId,
    this.propertyId,
    this.propertyTitle,
    required this.amount,
    this.amountOutstanding = 0,
    this.dueDate,
    this.status = 'pending',
  });

  factory ClientNextPayment.fromJson(Map<String, dynamic> json) {
    return ClientNextPayment(
      installmentId: json['installment_id'] as String,
      propertyId: json['property_id'] as String?,
      propertyTitle: json['property_title'] as String?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      amountOutstanding:
          (json['amount_outstanding'] as num?)?.toDouble() ?? 0,
      dueDate: json['due_date'] != null
          ? DateTime.tryParse(json['due_date'] as String)
          : null,
      status: json['status'] as String? ?? 'pending',
    );
  }

  final String installmentId;
  final String? propertyId;
  final String? propertyTitle;
  final double amount;
  final double amountOutstanding;
  final DateTime? dueDate;
  final String status;
}

class ClientPaymentMethodOption {
  const ClientPaymentMethodOption({
    required this.id,
    required this.slug,
    required this.name,
    this.provider,
    this.clientDescription,
    this.isRecommended = false,
    this.sortOrder = 0,
  });

  factory ClientPaymentMethodOption.fromJson(Map<String, dynamic> json) {
    return ClientPaymentMethodOption(
      id: json['id'] as String,
      slug: json['slug'] as String,
      name: json['name'] as String,
      provider: json['provider'] as String?,
      clientDescription: json['client_description'] as String?,
      isRecommended: json['is_recommended'] as bool? ?? false,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }

  final String id;
  final String slug;
  final String name;
  final String? provider;
  final String? clientDescription;
  final bool isRecommended;
  final int sortOrder;

  bool get isBankTransfer => slug == 'bank_transfer';
  bool get isOnlineCheckout =>
      slug == 'paystack' || slug == 'flutterwave';
}

class CompanyReceivingAccount {
  const CompanyReceivingAccount({
    required this.id,
    required this.accountName,
    required this.bankName,
    required this.accountNumber,
    this.currency = 'NGN',
    this.branch,
    this.accountReference,
    this.paymentInstructions,
    this.isDefault = false,
    this.sortOrder = 0,
  });

  factory CompanyReceivingAccount.fromJson(Map<String, dynamic> json) {
    return CompanyReceivingAccount(
      id: json['id'] as String,
      accountName: json['account_name'] as String,
      bankName: json['bank_name'] as String,
      accountNumber: json['account_number'] as String,
      currency: json['currency'] as String? ?? 'NGN',
      branch: json['branch'] as String?,
      accountReference: json['account_reference'] as String?,
      paymentInstructions: json['payment_instructions'] as String?,
      isDefault: json['is_default'] as bool? ?? false,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }

  final String id;
  final String accountName;
  final String bankName;
  final String accountNumber;
  final String currency;
  final String? branch;
  final String? accountReference;
  final String? paymentInstructions;
  final bool isDefault;
  final int sortOrder;
}

class ClientPaymentIntentRecord {
  const ClientPaymentIntentRecord({
    required this.id,
    required this.amount,
    this.currency = 'NGN',
    this.provider,
    this.paymentReference,
    this.providerReference,
    this.status = 'pending',
    this.propertyId,
    this.installmentId,
    this.propertyTitle,
    this.transferDate,
    this.senderName,
    this.senderBank,
    this.transactionReference,
    this.submittedAt,
    this.createdAt,
    this.rejectionReason,
  });

  factory ClientPaymentIntentRecord.fromJson(Map<String, dynamic> json) {
    final props = json['properties'];
    String? title;
    if (props is Map) {
      title = props['title'] as String?;
    }
    return ClientPaymentIntentRecord(
      id: json['id'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'NGN',
      provider: json['provider'] as String?,
      paymentReference: json['payment_reference'] as String?,
      providerReference: json['provider_reference'] as String?,
      status: json['status'] as String? ?? 'pending',
      propertyId: json['property_id'] as String?,
      installmentId: json['installment_id'] as String?,
      propertyTitle: title,
      transferDate: json['transfer_date'] != null
          ? DateTime.tryParse(json['transfer_date'] as String)
          : null,
      senderName: json['sender_name'] as String?,
      senderBank: json['sender_bank'] as String?,
      transactionReference: json['transaction_reference'] as String?,
      submittedAt: json['submitted_at'] != null
          ? DateTime.tryParse(json['submitted_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      rejectionReason: json['rejection_reason'] as String?,
    );
  }

  final String id;
  final double amount;
  final String currency;
  final String? provider;
  final String? paymentReference;
  final String? providerReference;
  final String status;
  final String? propertyId;
  final String? installmentId;
  final String? propertyTitle;
  final DateTime? transferDate;
  final String? senderName;
  final String? senderBank;
  final String? transactionReference;
  final DateTime? submittedAt;
  final DateTime? createdAt;
  final String? rejectionReason;

  bool get isPendingVerification =>
      status == 'pending_verification' || status == 'info_requested';

  String get formattedAmount => formatNgn(amount);
}

class ClientPaymentCharge {
  const ClientPaymentCharge({
    required this.id,
    required this.chargeType,
    required this.description,
    required this.amount,
    this.currency = 'NGN',
    this.status = 'pending',
    this.dueDate,
    this.propertyId,
    this.installmentId,
    this.propertyTitle,
    this.createdAt,
  });

  factory ClientPaymentCharge.fromJson(Map<String, dynamic> json) {
    final props = json['properties'];
    String? title;
    if (props is Map) {
      title = props['title'] as String?;
    }
    return ClientPaymentCharge(
      id: json['id'] as String,
      chargeType: json['charge_type'] as String,
      description: json['description'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'NGN',
      status: json['status'] as String? ?? 'pending',
      dueDate: json['due_date'] != null
          ? DateTime.tryParse(json['due_date'] as String)
          : null,
      propertyId: json['property_id'] as String?,
      installmentId: json['installment_id'] as String?,
      propertyTitle: title,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  final String id;
  final String chargeType;
  final String description;
  final double amount;
  final String currency;
  final String status;
  final DateTime? dueDate;
  final String? propertyId;
  final String? installmentId;
  final String? propertyTitle;
  final DateTime? createdAt;

  bool get isOutstanding => status == 'pending' || status == 'applied';

  String get formattedAmount => formatNgn(amount);
}

class ClientFinanceReceipt {
  const ClientFinanceReceipt({
    required this.id,
    required this.receiptNumber,
    required this.amount,
    this.currency = 'NGN',
    this.issuedAt,
    this.payerLabel,
    this.methodLabel,
    this.notes,
    this.paymentId,
    this.propertyTitle,
  });

  factory ClientFinanceReceipt.fromJson(Map<String, dynamic> json) {
    final payments = json['payments'];
    String? title;
    if (payments is Map) {
      final props = payments['properties'];
      if (props is Map) title = props['title'] as String?;
    }
    return ClientFinanceReceipt(
      id: json['id'] as String,
      receiptNumber: json['receipt_number'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'NGN',
      issuedAt: json['issued_at'] != null
          ? DateTime.tryParse(json['issued_at'] as String)
          : null,
      payerLabel: json['payer_label'] as String?,
      methodLabel: json['method_label'] as String?,
      notes: json['notes'] as String?,
      paymentId: json['payment_id'] as String?,
      propertyTitle: title,
    );
  }

  final String id;
  final String receiptNumber;
  final double amount;
  final String currency;
  final DateTime? issuedAt;
  final String? payerLabel;
  final String? methodLabel;
  final String? notes;
  final String? paymentId;
  final String? propertyTitle;

  String get formattedAmount => formatNgn(amount);
}

class BankTransferSubmissionResult {
  const BankTransferSubmissionResult({
    required this.intentId,
    required this.paymentReference,
    required this.amount,
    this.status = 'pending_verification',
    this.verificationId,
    this.receivingAccountId,
  });

  factory BankTransferSubmissionResult.fromJson(Map<String, dynamic> json) {
    return BankTransferSubmissionResult(
      intentId: json['intent_id'] as String,
      paymentReference: json['payment_reference'] as String,
      amount: (json['amount'] as num).toDouble(),
      status: json['status'] as String? ?? 'pending_verification',
      verificationId: json['verification_id'] as String?,
      receivingAccountId: json['receiving_account_id'] as String?,
    );
  }

  final String intentId;
  final String paymentReference;
  final double amount;
  final String status;
  final String? verificationId;
  final String? receivingAccountId;

  String get formattedAmount => formatNgn(amount);
}

/// Unified history row: pending intent or completed payment.
class ClientPaymentHistoryItem {
  const ClientPaymentHistoryItem({
    required this.id,
    required this.amount,
    required this.status,
    required this.kind,
    this.propertyTitle,
    this.reference,
    this.occurredAt,
    this.provider,
  });

  final String id;
  final double amount;
  final String status;
  final String kind; // 'intent' | 'payment'
  final String? propertyTitle;
  final String? reference;
  final DateTime? occurredAt;
  final String? provider;

  String get formattedAmount => formatNgn(amount);

  bool get isPendingVerification =>
      status == 'pending_verification' || status == 'info_requested';
}
