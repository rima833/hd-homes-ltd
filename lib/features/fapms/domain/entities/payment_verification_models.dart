import 'package:hdhomesproject/features/fapms/domain/entities/fapms_models.dart';
import 'package:intl/intl.dart';

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _asMapList(dynamic value) {
  if (value == null) return const [];
  if (value is List) {
    return value.map(_asMap).where((m) => m.isNotEmpty).toList();
  }
  final single = _asMap(value);
  return single.isEmpty ? const [] : [single];
}

Map<String, dynamic>? _firstMap(dynamic value) {
  final list = _asMapList(value);
  return list.isEmpty ? null : list.first;
}

String _profileDisplayName(Map<String, dynamic>? profile) {
  if (profile == null) return '';
  final preferred = (profile['preferred_name'] as String?)?.trim() ?? '';
  if (preferred.isNotEmpty) return preferred;
  final first = (profile['first_name'] as String?)?.trim() ?? '';
  final last = (profile['last_name'] as String?)?.trim() ?? '';
  final combined = '$first $last'.trim();
  if (combined.isNotEmpty) return combined;
  return (profile['email'] as String?)?.trim() ?? '';
}

/// Client bank-transfer / payment intent awaiting (or past) finance verification.
enum PaymentIntentStatus {
  pendingVerification,
  infoRequested,
  completed,
  rejected,
  pending,
  other;

  String get slug => switch (this) {
        PaymentIntentStatus.pendingVerification => 'pending_verification',
        PaymentIntentStatus.infoRequested => 'info_requested',
        PaymentIntentStatus.completed => 'completed',
        PaymentIntentStatus.rejected => 'rejected',
        PaymentIntentStatus.pending => 'pending',
        PaymentIntentStatus.other => 'other',
      };

  String get label => switch (this) {
        PaymentIntentStatus.pendingVerification => 'Pending verification',
        PaymentIntentStatus.infoRequested => 'Info requested',
        PaymentIntentStatus.completed => 'Completed',
        PaymentIntentStatus.rejected => 'Rejected',
        PaymentIntentStatus.pending => 'Pending',
        PaymentIntentStatus.other => 'Other',
      };

  bool get isActionable =>
      this == PaymentIntentStatus.pendingVerification ||
      this == PaymentIntentStatus.infoRequested;

  static PaymentIntentStatus fromSlug(String? raw) {
    return switch ((raw ?? '').toLowerCase()) {
      'pending_verification' => PaymentIntentStatus.pendingVerification,
      'info_requested' => PaymentIntentStatus.infoRequested,
      'completed' || 'approved' => PaymentIntentStatus.completed,
      'rejected' => PaymentIntentStatus.rejected,
      'pending' => PaymentIntentStatus.pending,
      _ => PaymentIntentStatus.other,
    };
  }
}

class PaymentVerificationRecord {
  const PaymentVerificationRecord({
    required this.id,
    required this.intentId,
    required this.status,
    this.paymentId,
    this.reviewerId,
    this.reviewerNotes,
    this.decidedAt,
    this.createdAt,
  });

  final String id;
  final String intentId;
  final String status;
  final String? paymentId;
  final String? reviewerId;
  final String? reviewerNotes;
  final DateTime? decidedAt;
  final DateTime? createdAt;

  factory PaymentVerificationRecord.fromJson(Map<String, dynamic> json) {
    return PaymentVerificationRecord(
      id: json['id'] as String? ?? '',
      intentId: json['intent_id'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      paymentId: json['payment_id'] as String?,
      reviewerId: json['reviewer_id'] as String?,
      reviewerNotes: json['reviewer_notes'] as String?,
      decidedAt: DateTime.tryParse(json['decided_at'] as String? ?? ''),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }
}

class PaymentIntentRow {
  const PaymentIntentRow({
    required this.id,
    required this.clientId,
    required this.amount,
    required this.status,
    this.currency = 'NGN',
    this.propertyId,
    this.installmentId,
    this.paymentReference,
    this.provider,
    this.providerReference,
    this.receivingAccountId,
    this.transferDate,
    this.senderName,
    this.senderBank,
    this.transactionReference,
    this.transferNote,
    this.proofStoragePath,
    this.paymentId,
    this.verifiedBy,
    this.verifiedAt,
    this.rejectionReason,
    this.infoRequestMessage,
    this.submittedAt,
    this.createdAt,
    this.clientCode,
    this.clientName,
    this.clientEmail,
    this.propertyTitle,
    this.receivingAccountLabel,
    this.verifications = const [],
  });

  final String id;
  final String clientId;
  final double amount;
  final PaymentIntentStatus status;
  final String currency;
  final String? propertyId;
  final String? installmentId;
  final String? paymentReference;
  final String? provider;
  final String? providerReference;
  final String? receivingAccountId;
  final DateTime? transferDate;
  final String? senderName;
  final String? senderBank;
  final String? transactionReference;
  final String? transferNote;
  final String? proofStoragePath;
  final String? paymentId;
  final String? verifiedBy;
  final DateTime? verifiedAt;
  final String? rejectionReason;
  final String? infoRequestMessage;
  final DateTime? submittedAt;
  final DateTime? createdAt;
  final String? clientCode;
  final String? clientName;
  final String? clientEmail;
  final String? propertyTitle;
  final String? receivingAccountLabel;
  final List<PaymentVerificationRecord> verifications;

  String get amountDisplay => formatFapmsMoney(amount);

  String get clientDisplay {
    if (clientName != null && clientName!.trim().isNotEmpty) {
      return clientName!;
    }
    if (clientCode != null && clientCode!.trim().isNotEmpty) {
      return clientCode!;
    }
    return 'Client ${clientId.substring(0, 8)}';
  }

  String get propertyDisplay =>
      (propertyTitle != null && propertyTitle!.trim().isNotEmpty)
          ? propertyTitle!
          : (propertyId ?? '—');

  String get referenceDisplay =>
      paymentReference?.trim().isNotEmpty == true
          ? paymentReference!
          : (providerReference ?? '—');

  DateTime? get submittedOrCreated => submittedAt ?? createdAt;

  String get submittedDisplay {
    final at = submittedOrCreated;
    if (at == null) return '—';
    return DateFormat.yMMMd().add_jm().format(at.toLocal());
  }

  bool get hasProof =>
      proofStoragePath != null && proofStoragePath!.trim().isNotEmpty;

  factory PaymentIntentRow.fromJson(Map<String, dynamic> json) {
    final client = _firstMap(json['clients']);
    final profile = _firstMap(client?['profiles']);
    final property = _firstMap(json['properties']);
    final account = _firstMap(json['company_receiving_accounts']);
    final bankName = account?['bank_name'] as String?;
    final accountName = account?['account_name'] as String?;
    final accountNumber = account?['account_number'] as String?;
    final accountLabel = [
      if (accountName != null && accountName.isNotEmpty) accountName,
      if (bankName != null && bankName.isNotEmpty) bankName,
      if (accountNumber != null && accountNumber.isNotEmpty) accountNumber,
    ].join(' · ');

    final verifications = _asMapList(json['payment_verifications'])
        .map(PaymentVerificationRecord.fromJson)
        .toList()
      ..sort((a, b) {
        final aAt = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bAt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bAt.compareTo(aAt);
      });

    return PaymentIntentRow(
      id: json['id'] as String,
      clientId: json['client_id'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      status: PaymentIntentStatus.fromSlug(json['status'] as String?),
      currency: json['currency'] as String? ?? 'NGN',
      propertyId: json['property_id'] as String?,
      installmentId: json['installment_id'] as String?,
      paymentReference: json['payment_reference'] as String?,
      provider: json['provider'] as String?,
      providerReference: json['provider_reference'] as String?,
      receivingAccountId: json['receiving_account_id'] as String?,
      transferDate: DateTime.tryParse(json['transfer_date'] as String? ?? ''),
      senderName: json['sender_name'] as String?,
      senderBank: json['sender_bank'] as String?,
      transactionReference: json['transaction_reference'] as String?,
      transferNote: json['transfer_note'] as String?,
      proofStoragePath: json['proof_storage_path'] as String?,
      paymentId: json['payment_id'] as String?,
      verifiedBy: json['verified_by'] as String?,
      verifiedAt: DateTime.tryParse(json['verified_at'] as String? ?? ''),
      rejectionReason: json['rejection_reason'] as String?,
      infoRequestMessage: json['info_request_message'] as String?,
      submittedAt: DateTime.tryParse(json['submitted_at'] as String? ?? ''),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      clientCode: client?['client_code'] as String?,
      clientName: _profileDisplayName(profile),
      clientEmail: profile?['email'] as String?,
      propertyTitle: property?['title'] as String?,
      receivingAccountLabel: accountLabel.isEmpty ? null : accountLabel,
      verifications: verifications,
    );
  }
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
    this.isActive = true,
    this.isDefault = false,
    this.availableForClients = true,
    this.sortOrder = 0,
  });

  final String id;
  final String accountName;
  final String bankName;
  final String accountNumber;
  final String currency;
  final String? branch;
  final String? accountReference;
  final String? paymentInstructions;
  final bool isActive;
  final bool isDefault;
  final bool availableForClients;
  final int sortOrder;

  String get label => '$accountName · $bankName · $accountNumber';

  factory CompanyReceivingAccount.fromJson(Map<String, dynamic> json) {
    return CompanyReceivingAccount(
      id: json['id'] as String,
      accountName: json['account_name'] as String? ?? '',
      bankName: json['bank_name'] as String? ?? '',
      accountNumber: json['account_number'] as String? ?? '',
      currency: json['currency'] as String? ?? 'NGN',
      branch: json['branch'] as String?,
      accountReference: json['account_reference'] as String?,
      paymentInstructions: json['payment_instructions'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      isDefault: json['is_default'] as bool? ?? false,
      availableForClients: json['available_for_clients'] as bool? ?? true,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toUpsertMap({String? idOverride}) {
    return {
      if (idOverride != null || id.isNotEmpty) 'id': idOverride ?? id,
      'account_name': accountName,
      'bank_name': bankName,
      'account_number': accountNumber,
      'currency': currency,
      'branch': branch,
      'account_reference': accountReference,
      'payment_instructions': paymentInstructions,
      'is_active': isActive,
      'is_default': isDefault,
      'available_for_clients': availableForClients,
      'sort_order': sortOrder,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'is_deleted': false,
    };
  }
}

class PaymentMethodConfig {
  const PaymentMethodConfig({
    required this.id,
    required this.slug,
    required this.name,
    this.provider,
    this.isActive = true,
    this.clientEnabled = false,
    this.isRecommended = false,
    this.clientDescription,
    this.sortOrder = 0,
  });

  final String id;
  final String slug;
  final String name;
  final String? provider;
  final bool isActive;
  final bool clientEnabled;
  final bool isRecommended;
  final String? clientDescription;
  final int sortOrder;

  factory PaymentMethodConfig.fromJson(Map<String, dynamic> json) {
    return PaymentMethodConfig(
      id: json['id'] as String,
      slug: json['slug'] as String? ?? '',
      name: json['name'] as String? ?? '',
      provider: json['provider'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      clientEnabled: json['client_enabled'] as bool? ?? false,
      isRecommended: json['is_recommended'] as bool? ?? false,
      clientDescription: json['client_description'] as String?,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

class LateFeeRule {
  const LateFeeRule({
    required this.id,
    required this.name,
    required this.calculationType,
    required this.value,
    this.chargeTypeSlug = 'late_payment_fee',
    this.gracePeriodDays = 0,
    this.maximumCharge,
    this.enabled = false,
    this.appliesTo = 'installments',
  });

  final String id;
  final String name;
  final String calculationType;
  final double value;
  final String chargeTypeSlug;
  final int gracePeriodDays;
  final double? maximumCharge;
  final bool enabled;
  final String appliesTo;

  String get valueDisplay {
    final isPct = calculationType.contains('percentage');
    if (isPct) return '${value.toStringAsFixed(2)}%';
    return formatFapmsMoney(value);
  }

  factory LateFeeRule.fromJson(Map<String, dynamic> json) {
    return LateFeeRule(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      calculationType: json['calculation_type'] as String? ?? 'fixed',
      value: (json['value'] as num?)?.toDouble() ?? 0,
      chargeTypeSlug: json['charge_type_slug'] as String? ?? 'late_payment_fee',
      gracePeriodDays: (json['grace_period_days'] as num?)?.toInt() ?? 0,
      maximumCharge: (json['maximum_charge'] as num?)?.toDouble(),
      enabled: json['enabled'] as bool? ?? false,
      appliesTo: json['applies_to'] as String? ?? 'installments',
    );
  }
}
