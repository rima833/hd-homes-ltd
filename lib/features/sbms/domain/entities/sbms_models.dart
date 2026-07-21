// Volume 4 Part 5 — Enterprise Sales & Booking Management System domain models.

const String kSalesEstimateDisclaimer =
    'Quoted totals and forecasts are estimates only and are not guarantees. '
    'Subject to survey, title, and management approval.';

String formatSbmsMoney(double? value) {
  if (value == null) return '—';
  final n = value;
  if (n >= 1e9) return '₦${(n / 1e9).toStringAsFixed(1)}B';
  if (n >= 1e6) return '₦${(n / 1e6).toStringAsFixed(1)}M';
  if (n >= 1e3) return '₦${(n / 1e3).toStringAsFixed(0)}K';
  return '₦${n.toStringAsFixed(0)}';
}

enum ReservationStatus {
  draft,
  reserved,
  confirmed,
  expired,
  cancelled,
  converted;

  String get label => switch (this) {
        ReservationStatus.draft => 'Draft',
        ReservationStatus.reserved => 'Reserved',
        ReservationStatus.confirmed => 'Confirmed',
        ReservationStatus.expired => 'Expired',
        ReservationStatus.cancelled => 'Cancelled',
        ReservationStatus.converted => 'Converted',
      };

  String get slug => name;

  static ReservationStatus fromSlug(String? raw) {
    return switch ((raw ?? 'draft').toLowerCase()) {
      'reserved' => ReservationStatus.reserved,
      'confirmed' => ReservationStatus.confirmed,
      'expired' => ReservationStatus.expired,
      'cancelled' => ReservationStatus.cancelled,
      'converted' => ReservationStatus.converted,
      _ => ReservationStatus.draft,
    };
  }
}

enum BookingType {
  inspection,
  office,
  virtualTour,
  siteVisit,
  investmentConsultation;

  String get label => switch (this) {
        BookingType.inspection => 'Inspection',
        BookingType.office => 'Office',
        BookingType.virtualTour => 'Virtual Tour',
        BookingType.siteVisit => 'Site Visit',
        BookingType.investmentConsultation => 'Investment Consultation',
      };

  String get slug => switch (this) {
        BookingType.virtualTour => 'virtual_tour',
        BookingType.siteVisit => 'site_visit',
        BookingType.investmentConsultation => 'investment_consultation',
        _ => name,
      };

  static BookingType fromSlug(String? raw) {
    return switch ((raw ?? 'inspection').toLowerCase()) {
      'office' => BookingType.office,
      'virtual_tour' || 'virtualtour' => BookingType.virtualTour,
      'site_visit' || 'sitevisit' => BookingType.siteVisit,
      'investment_consultation' || 'investmentconsultation' =>
        BookingType.investmentConsultation,
      _ => BookingType.inspection,
    };
  }
}

enum DealStatus {
  open,
  negotiation,
  contract,
  won,
  lost,
  cancelled,
  onHold;

  String get label => switch (this) {
        DealStatus.open => 'Open',
        DealStatus.negotiation => 'Negotiation',
        DealStatus.contract => 'Contract',
        DealStatus.won => 'Won',
        DealStatus.lost => 'Lost',
        DealStatus.cancelled => 'Cancelled',
        DealStatus.onHold => 'On Hold',
      };

  String get slug => switch (this) {
        DealStatus.onHold => 'on_hold',
        _ => name,
      };

  static DealStatus fromSlug(String? raw) {
    return switch ((raw ?? 'open').toLowerCase()) {
      'negotiation' => DealStatus.negotiation,
      'contract' => DealStatus.contract,
      'won' => DealStatus.won,
      'lost' => DealStatus.lost,
      'cancelled' => DealStatus.cancelled,
      'on_hold' || 'onhold' => DealStatus.onHold,
      _ => DealStatus.open,
    };
  }
}

enum QuoteStatus {
  draft,
  sent,
  accepted,
  rejected,
  expired,
  superseded;

  String get label => switch (this) {
        QuoteStatus.draft => 'Draft',
        QuoteStatus.sent => 'Sent',
        QuoteStatus.accepted => 'Accepted',
        QuoteStatus.rejected => 'Rejected',
        QuoteStatus.expired => 'Expired',
        QuoteStatus.superseded => 'Superseded',
      };

  String get slug => name;

  static QuoteStatus fromSlug(String? raw) {
    return switch ((raw ?? 'draft').toLowerCase()) {
      'sent' => QuoteStatus.sent,
      'accepted' => QuoteStatus.accepted,
      'rejected' => QuoteStatus.rejected,
      'expired' => QuoteStatus.expired,
      'superseded' => QuoteStatus.superseded,
      _ => QuoteStatus.draft,
    };
  }
}

enum ContractStatus {
  draft,
  pendingReview,
  awaitingSignature,
  partiallySigned,
  executed,
  cancelled,
  expired;

  String get label => switch (this) {
        ContractStatus.draft => 'Draft',
        ContractStatus.pendingReview => 'Pending Review',
        ContractStatus.awaitingSignature => 'Awaiting Signature',
        ContractStatus.partiallySigned => 'Partially Signed',
        ContractStatus.executed => 'Executed',
        ContractStatus.cancelled => 'Cancelled',
        ContractStatus.expired => 'Expired',
      };

  String get slug => switch (this) {
        ContractStatus.pendingReview => 'pending_review',
        ContractStatus.awaitingSignature => 'awaiting_signature',
        ContractStatus.partiallySigned => 'partially_signed',
        _ => name,
      };

  static ContractStatus fromSlug(String? raw) {
    return switch ((raw ?? 'draft').toLowerCase()) {
      'pending_review' || 'pendingreview' => ContractStatus.pendingReview,
      'awaiting_signature' || 'awaitingsignature' =>
        ContractStatus.awaitingSignature,
      'partially_signed' || 'partiallysigned' => ContractStatus.partiallySigned,
      'executed' => ContractStatus.executed,
      'cancelled' => ContractStatus.cancelled,
      'expired' => ContractStatus.expired,
      _ => ContractStatus.draft,
    };
  }
}

enum InstallmentStatus {
  pending,
  due,
  paid,
  overdue,
  waived,
  cancelled;

  String get label => switch (this) {
        InstallmentStatus.pending => 'Pending',
        InstallmentStatus.due => 'Due',
        InstallmentStatus.paid => 'Paid',
        InstallmentStatus.overdue => 'Overdue',
        InstallmentStatus.waived => 'Waived',
        InstallmentStatus.cancelled => 'Cancelled',
      };

  String get slug => name;

  static InstallmentStatus fromSlug(String? raw) {
    return switch ((raw ?? 'pending').toLowerCase()) {
      'due' => InstallmentStatus.due,
      'paid' => InstallmentStatus.paid,
      'overdue' => InstallmentStatus.overdue,
      'waived' => InstallmentStatus.waived,
      'cancelled' => InstallmentStatus.cancelled,
      _ => InstallmentStatus.pending,
    };
  }
}

enum CommissionStatus {
  earned,
  pending,
  approved,
  paid,
  cancelled;

  String get label => switch (this) {
        CommissionStatus.earned => 'Earned',
        CommissionStatus.pending => 'Pending',
        CommissionStatus.approved => 'Approved',
        CommissionStatus.paid => 'Paid',
        CommissionStatus.cancelled => 'Cancelled',
      };

  String get slug => name;

  static CommissionStatus fromSlug(String? raw) {
    return switch ((raw ?? 'pending').toLowerCase()) {
      'earned' => CommissionStatus.earned,
      'approved' => CommissionStatus.approved,
      'paid' => CommissionStatus.paid,
      'cancelled' => CommissionStatus.cancelled,
      _ => CommissionStatus.pending,
    };
  }
}

enum DiscountRequestStatus {
  pending,
  approved,
  rejected,
  withdrawn,
  expired;

  String get label => switch (this) {
        DiscountRequestStatus.pending => 'Pending',
        DiscountRequestStatus.approved => 'Approved',
        DiscountRequestStatus.rejected => 'Rejected',
        DiscountRequestStatus.withdrawn => 'Withdrawn',
        DiscountRequestStatus.expired => 'Expired',
      };

  String get slug => name;

  static DiscountRequestStatus fromSlug(String? raw) {
    return switch ((raw ?? 'pending').toLowerCase()) {
      'approved' => DiscountRequestStatus.approved,
      'rejected' => DiscountRequestStatus.rejected,
      'withdrawn' => DiscountRequestStatus.withdrawn,
      'expired' => DiscountRequestStatus.expired,
      _ => DiscountRequestStatus.pending,
    };
  }
}

class SbmsPipelineStage {
  const SbmsPipelineStage({
    required this.id,
    required this.slug,
    required this.name,
    this.sortOrder = 0,
    this.isTerminal = false,
    this.color,
  });

  final String id;
  final String slug;
  final String name;
  final int sortOrder;
  final bool isTerminal;
  final String? color;

  factory SbmsPipelineStage.fromJson(Map<String, dynamic> json) {
    return SbmsPipelineStage(
      id: json['id']?.toString() ?? '',
      slug: json['slug'] as String? ?? '',
      name: json['name'] as String? ?? '',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isTerminal: json['is_terminal'] as bool? ?? false,
      color: json['color'] as String?,
    );
  }
}

class SbmsReservation {
  const SbmsReservation({
    required this.id,
    required this.reservationCode,
    required this.status,
    this.clientId,
    this.propertyId,
    this.orderId,
    this.clientName,
    this.propertyLabel,
    this.reservedAmount = 0,
    this.reservedAt,
    this.expiresAt,
    this.confirmedAt,
    this.notes,
  });

  final String id;
  final String reservationCode;
  final ReservationStatus status;
  final String? clientId;
  final String? propertyId;
  final String? orderId;
  final String? clientName;
  final String? propertyLabel;
  final double reservedAmount;
  final DateTime? reservedAt;
  final DateTime? expiresAt;
  final DateTime? confirmedAt;
  final String? notes;

  String get amountDisplay => formatSbmsMoney(reservedAmount);

  bool get isExpiringSoon {
    final exp = expiresAt;
    if (exp == null) return false;
    if (status != ReservationStatus.reserved) return false;
    final hours = exp.difference(DateTime.now()).inHours;
    return hours >= 0 && hours <= 48;
  }

  bool get isExpired {
    final exp = expiresAt;
    if (exp == null) return status == ReservationStatus.expired;
    return status == ReservationStatus.expired ||
        (status == ReservationStatus.reserved && exp.isBefore(DateTime.now()));
  }

  factory SbmsReservation.fromJson(Map<String, dynamic> json) {
    final clientRel = json['crm_clients'];
    final propRel = json['properties'];
    return SbmsReservation(
      id: json['id']?.toString() ?? '',
      reservationCode: json['reservation_code'] as String? ?? '',
      status: ReservationStatus.fromSlug(json['status'] as String?),
      clientId: json['client_id']?.toString(),
      propertyId: json['property_id']?.toString(),
      orderId: json['order_id']?.toString(),
      clientName: json['client_name'] as String? ??
          (clientRel is Map ? clientRel['full_name'] as String? : null),
      propertyLabel: json['property_label'] as String? ??
          (propRel is Map
              ? (propRel['title'] as String? ?? propRel['slug'] as String?)
              : null),
      reservedAmount: (json['reserved_amount'] as num?)?.toDouble() ?? 0,
      reservedAt: DateTime.tryParse(json['reserved_at'] as String? ?? ''),
      expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? ''),
      confirmedAt: DateTime.tryParse(json['confirmed_at'] as String? ?? ''),
      notes: json['notes'] as String?,
    );
  }
}

class SbmsBooking {
  const SbmsBooking({
    required this.id,
    required this.bookingCode,
    required this.bookingType,
    required this.scheduledAt,
    this.status = 'scheduled',
    this.clientId,
    this.propertyId,
    this.orderId,
    this.clientName,
    this.location,
    this.durationMinutes = 60,
    this.notes,
  });

  final String id;
  final String bookingCode;
  final BookingType bookingType;
  final DateTime scheduledAt;
  final String status;
  final String? clientId;
  final String? propertyId;
  final String? orderId;
  final String? clientName;
  final String? location;
  final int durationMinutes;
  final String? notes;

  factory SbmsBooking.fromJson(Map<String, dynamic> json) {
    final clientRel = json['crm_clients'];
    return SbmsBooking(
      id: json['id']?.toString() ?? '',
      bookingCode: json['booking_code'] as String? ?? '',
      bookingType: BookingType.fromSlug(json['booking_type'] as String?),
      scheduledAt: DateTime.tryParse(json['scheduled_at'] as String? ?? '') ??
          DateTime.now(),
      status: json['status'] as String? ?? 'scheduled',
      clientId: json['client_id']?.toString(),
      propertyId: json['property_id']?.toString(),
      orderId: json['order_id']?.toString(),
      clientName: json['client_name'] as String? ??
          (clientRel is Map ? clientRel['full_name'] as String? : null),
      location: json['location'] as String?,
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 60,
      notes: json['notes'] as String?,
    );
  }
}

class SbmsQuote {
  const SbmsQuote({
    required this.id,
    required this.quoteCode,
    required this.status,
    this.clientId,
    this.propertyId,
    this.orderId,
    this.clientName,
    this.subtotal = 0,
    this.discountAmount = 0,
    this.totalAmount = 0,
    this.validUntil,
    this.sentAt,
    this.notes,
    this.estimateDisclaimer = kSalesEstimateDisclaimer,
    this.items = const [],
  });

  final String id;
  final String quoteCode;
  final QuoteStatus status;
  final String? clientId;
  final String? propertyId;
  final String? orderId;
  final String? clientName;
  final double subtotal;
  final double discountAmount;
  final double totalAmount;
  final DateTime? validUntil;
  final DateTime? sentAt;
  final String? notes;
  final String estimateDisclaimer;
  final List<SbmsQuoteItem> items;

  String get totalDisplay => formatSbmsMoney(totalAmount);

  factory SbmsQuote.fromJson(Map<String, dynamic> json) {
    final clientRel = json['crm_clients'];
    final itemsRaw = json['sales_quote_items'];
    return SbmsQuote(
      id: json['id']?.toString() ?? '',
      quoteCode: json['quote_code'] as String? ?? '',
      status: QuoteStatus.fromSlug(json['status'] as String?),
      clientId: json['client_id']?.toString(),
      propertyId: json['property_id']?.toString(),
      orderId: json['order_id']?.toString(),
      clientName: json['client_name'] as String? ??
          (clientRel is Map ? clientRel['full_name'] as String? : null),
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
      validUntil: DateTime.tryParse(json['valid_until'] as String? ?? ''),
      sentAt: DateTime.tryParse(json['sent_at'] as String? ?? ''),
      notes: json['notes'] as String?,
      estimateDisclaimer:
          json['estimate_disclaimer'] as String? ?? kSalesEstimateDisclaimer,
      items: itemsRaw is List
          ? itemsRaw
              .map(
                (e) => SbmsQuoteItem.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList()
          : const [],
    );
  }
}

class SbmsQuoteItem {
  const SbmsQuoteItem({
    required this.id,
    required this.label,
    this.description,
    this.quantity = 1,
    this.unitPrice = 0,
    this.lineTotal = 0,
  });

  final String id;
  final String label;
  final String? description;
  final double quantity;
  final double unitPrice;
  final double lineTotal;

  factory SbmsQuoteItem.fromJson(Map<String, dynamic> json) {
    return SbmsQuoteItem(
      id: json['id']?.toString() ?? '',
      label: json['label'] as String? ?? '',
      description: json['description'] as String?,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0,
      lineTotal: (json['line_total'] as num?)?.toDouble() ?? 0,
    );
  }
}

class SbmsDeal {
  const SbmsDeal({
    required this.id,
    required this.orderCode,
    required this.title,
    this.clientId,
    this.propertyId,
    this.stageSlug,
    this.stageName,
    this.dealValue = 0,
    this.probabilityPct = 50,
    this.status = DealStatus.open,
    this.expectedCloseAt,
    this.clientName,
    this.aiSummary,
    this.notes,
  });

  final String id;
  final String orderCode;
  final String title;
  final String? clientId;
  final String? propertyId;
  final String? stageSlug;
  final String? stageName;
  final double dealValue;
  final double probabilityPct;
  final DealStatus status;
  final DateTime? expectedCloseAt;
  final String? clientName;
  final String? aiSummary;
  final String? notes;

  String get valueDisplay => formatSbmsMoney(dealValue);

  double get weightedValue => dealValue * (probabilityPct / 100);

  factory SbmsDeal.fromJson(Map<String, dynamic> json) {
    final clientRel = json['crm_clients'];
    final stageRel = json['sales_pipeline_stages'];
    return SbmsDeal(
      id: json['id']?.toString() ?? '',
      orderCode: json['order_code'] as String? ?? '',
      title: json['title'] as String? ?? '',
      clientId: json['client_id']?.toString(),
      propertyId: json['property_id']?.toString(),
      stageSlug: json['stage_slug'] as String? ??
          (stageRel is Map ? stageRel['slug'] as String? : null),
      stageName: json['stage_name'] as String? ??
          (stageRel is Map ? stageRel['name'] as String? : null),
      dealValue: (json['deal_value'] as num?)?.toDouble() ?? 0,
      probabilityPct: (json['probability_pct'] as num?)?.toDouble() ?? 50,
      status: DealStatus.fromSlug(json['status'] as String?),
      expectedCloseAt:
          DateTime.tryParse(json['expected_close_at'] as String? ?? ''),
      clientName: json['client_name'] as String? ??
          (clientRel is Map ? clientRel['full_name'] as String? : null),
      aiSummary: json['ai_summary'] as String?,
      notes: json['notes'] as String?,
    );
  }
}

class SbmsNegotiation {
  const SbmsNegotiation({
    required this.id,
    required this.orderId,
    required this.eventType,
    this.quoteId,
    this.actorLabel,
    this.amount,
    this.body,
    this.occurredAt,
  });

  final String id;
  final String orderId;
  final String eventType;
  final String? quoteId;
  final String? actorLabel;
  final double? amount;
  final String? body;
  final DateTime? occurredAt;

  String get amountDisplay => formatSbmsMoney(amount);

  factory SbmsNegotiation.fromJson(Map<String, dynamic> json) {
    return SbmsNegotiation(
      id: json['id']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      eventType: json['event_type'] as String? ?? 'note',
      quoteId: json['quote_id']?.toString(),
      actorLabel: json['actor_label'] as String?,
      amount: (json['amount'] as num?)?.toDouble(),
      body: json['body'] as String?,
      occurredAt: DateTime.tryParse(json['occurred_at'] as String? ?? ''),
    );
  }
}

class SbmsContract {
  const SbmsContract({
    required this.id,
    required this.contractCode,
    required this.status,
    this.orderId,
    this.clientId,
    this.propertyId,
    this.clientName,
    this.contractValue = 0,
    this.issuedAt,
    this.expiresAt,
    this.notes,
  });

  final String id;
  final String contractCode;
  final ContractStatus status;
  final String? orderId;
  final String? clientId;
  final String? propertyId;
  final String? clientName;
  final double contractValue;
  final DateTime? issuedAt;
  final DateTime? expiresAt;
  final String? notes;

  String get valueDisplay => formatSbmsMoney(contractValue);

  factory SbmsContract.fromJson(Map<String, dynamic> json) {
    final clientRel = json['crm_clients'];
    return SbmsContract(
      id: json['id']?.toString() ?? '',
      contractCode: json['contract_code'] as String? ?? '',
      status: ContractStatus.fromSlug(json['status'] as String?),
      orderId: json['order_id']?.toString(),
      clientId: json['client_id']?.toString(),
      propertyId: json['property_id']?.toString(),
      clientName: json['client_name'] as String? ??
          (clientRel is Map ? clientRel['full_name'] as String? : null),
      contractValue: (json['contract_value'] as num?)?.toDouble() ?? 0,
      issuedAt: DateTime.tryParse(json['issued_at'] as String? ?? ''),
      expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? ''),
      notes: json['notes'] as String?,
    );
  }
}

class SbmsInstallment {
  const SbmsInstallment({
    required this.id,
    required this.paymentPlanId,
    required this.installmentNo,
    required this.amount,
    required this.dueDate,
    required this.status,
    this.paidAt,
    this.notes,
  });

  final String id;
  final String paymentPlanId;
  final int installmentNo;
  final double amount;
  final DateTime dueDate;
  final InstallmentStatus status;
  final DateTime? paidAt;
  final String? notes;

  String get amountDisplay => formatSbmsMoney(amount);

  bool get isDueSoon {
    if (status == InstallmentStatus.paid ||
        status == InstallmentStatus.cancelled ||
        status == InstallmentStatus.waived) {
      return false;
    }
    final days = dueDate.difference(DateTime.now()).inDays;
    return days <= 7;
  }

  factory SbmsInstallment.fromJson(Map<String, dynamic> json) {
    return SbmsInstallment(
      id: json['id']?.toString() ?? '',
      paymentPlanId: json['payment_plan_id']?.toString() ?? '',
      installmentNo: (json['installment_no'] as num?)?.toInt() ?? 0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      dueDate: DateTime.tryParse(json['due_date'] as String? ?? '') ??
          DateTime.now(),
      status: InstallmentStatus.fromSlug(json['status'] as String?),
      paidAt: DateTime.tryParse(json['paid_at'] as String? ?? ''),
      notes: json['notes'] as String?,
    );
  }
}

class SbmsCommission {
  const SbmsCommission({
    required this.id,
    required this.commissionCode,
    required this.status,
    this.orderId,
    this.agentName,
    this.baseAmount = 0,
    this.commissionPercent = 0,
    this.commissionAmount = 0,
    this.earnedAt,
    this.approvedAt,
    this.notes,
  });

  final String id;
  final String commissionCode;
  final CommissionStatus status;
  final String? orderId;
  final String? agentName;
  final double baseAmount;
  final double commissionPercent;
  final double commissionAmount;
  final DateTime? earnedAt;
  final DateTime? approvedAt;
  final String? notes;

  String get amountDisplay => formatSbmsMoney(commissionAmount);

  factory SbmsCommission.fromJson(Map<String, dynamic> json) {
    return SbmsCommission(
      id: json['id']?.toString() ?? '',
      commissionCode: json['commission_code'] as String? ?? '',
      status: CommissionStatus.fromSlug(json['status'] as String?),
      orderId: json['order_id']?.toString(),
      agentName: json['agent_name'] as String?,
      baseAmount: (json['base_amount'] as num?)?.toDouble() ?? 0,
      commissionPercent: (json['commission_percent'] as num?)?.toDouble() ?? 0,
      commissionAmount: (json['commission_amount'] as num?)?.toDouble() ?? 0,
      earnedAt: DateTime.tryParse(json['earned_at'] as String? ?? ''),
      approvedAt: DateTime.tryParse(json['approved_at'] as String? ?? ''),
      notes: json['notes'] as String?,
    );
  }
}

class SbmsHandover {
  const SbmsHandover({
    required this.id,
    required this.status,
    this.orderId,
    this.clientId,
    this.propertyId,
    this.clientName,
    this.checklist = const [],
    this.scheduledAt,
    this.notes,
  });

  final String id;
  final String status;
  final String? orderId;
  final String? clientId;
  final String? propertyId;
  final String? clientName;
  final List<SbmsChecklistItem> checklist;
  final DateTime? scheduledAt;
  final String? notes;

  int get doneCount => checklist.where((c) => c.done).length;

  factory SbmsHandover.fromJson(Map<String, dynamic> json) {
    final clientRel = json['crm_clients'];
    final raw = json['checklist'];
    final items = <SbmsChecklistItem>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) {
          items.add(
            SbmsChecklistItem(
              item: e['item']?.toString() ?? '',
              done: e['done'] == true,
            ),
          );
        }
      }
    }
    return SbmsHandover(
      id: json['id']?.toString() ?? '',
      status: json['status'] as String? ?? 'pending',
      orderId: json['order_id']?.toString(),
      clientId: json['client_id']?.toString(),
      propertyId: json['property_id']?.toString(),
      clientName: json['client_name'] as String? ??
          (clientRel is Map ? clientRel['full_name'] as String? : null),
      checklist: items,
      scheduledAt: DateTime.tryParse(json['scheduled_at'] as String? ?? ''),
      notes: json['notes'] as String?,
    );
  }
}

class SbmsChecklistItem {
  const SbmsChecklistItem({required this.item, this.done = false});

  final String item;
  final bool done;
}

class SbmsDiscountRequest {
  const SbmsDiscountRequest({
    required this.id,
    required this.requestedValue,
    required this.status,
    this.orderId,
    this.requesterLabel,
    this.justification,
    this.discountName,
  });

  final String id;
  final double requestedValue;
  final DiscountRequestStatus status;
  final String? orderId;
  final String? requesterLabel;
  final String? justification;
  final String? discountName;

  factory SbmsDiscountRequest.fromJson(Map<String, dynamic> json) {
    final discRel = json['sales_discounts'];
    return SbmsDiscountRequest(
      id: json['id']?.toString() ?? '',
      requestedValue: (json['requested_value'] as num?)?.toDouble() ?? 0,
      status: DiscountRequestStatus.fromSlug(json['status'] as String?),
      orderId: json['order_id']?.toString(),
      requesterLabel: json['requester_label'] as String?,
      justification: json['justification'] as String?,
      discountName: json['discount_name'] as String? ??
          (discRel is Map ? discRel['name'] as String? : null),
    );
  }
}

class SbmsActivity {
  const SbmsActivity({
    required this.id,
    required this.title,
    this.orderId,
    this.clientId,
    this.eventType = 'note',
    this.description,
    this.actorLabel,
    this.occurredAt,
  });

  final String id;
  final String title;
  final String? orderId;
  final String? clientId;
  final String eventType;
  final String? description;
  final String? actorLabel;
  final DateTime? occurredAt;

  factory SbmsActivity.fromJson(Map<String, dynamic> json) {
    return SbmsActivity(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      orderId: json['order_id']?.toString(),
      clientId: json['client_id']?.toString(),
      eventType: json['event_type'] as String? ?? 'note',
      description: json['description'] as String?,
      actorLabel: json['actor_label'] as String?,
      occurredAt: DateTime.tryParse(json['occurred_at'] as String? ?? ''),
    );
  }
}

class SbmsAlert {
  const SbmsAlert({
    required this.id,
    required this.title,
    this.body,
    this.severity = 'info',
    this.status = 'open',
    this.orderId,
    this.createdAt,
  });

  final String id;
  final String title;
  final String? body;
  final String severity;
  final String status;
  final String? orderId;
  final DateTime? createdAt;

  factory SbmsAlert.fromJson(Map<String, dynamic> json) {
    return SbmsAlert(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String?,
      severity: json['severity'] as String? ?? 'info',
      status: json['status'] as String? ?? 'open',
      orderId: json['order_id']?.toString(),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }
}

class SbmsLeaderboardRow {
  const SbmsLeaderboardRow({
    required this.id,
    required this.periodLabel,
    required this.agentName,
    required this.rank,
    this.dealsWon = 0,
    this.revenue = 0,
  });

  final String id;
  final String periodLabel;
  final String agentName;
  final int rank;
  final int dealsWon;
  final double revenue;

  String get revenueDisplay => formatSbmsMoney(revenue);

  factory SbmsLeaderboardRow.fromJson(Map<String, dynamic> json) {
    return SbmsLeaderboardRow(
      id: json['id']?.toString() ?? '',
      periodLabel: json['period_label'] as String? ?? '',
      agentName: json['agent_name'] as String? ?? '',
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      dealsWon: (json['deals_won'] as num?)?.toInt() ?? 0,
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
    );
  }
}

class SbmsKpi {
  const SbmsKpi({
    required this.label,
    required this.value,
    this.unit = 'count',
  });

  final String label;
  final double value;
  final String unit;

  String get displayValue {
    if (unit == 'ngn') return formatSbmsMoney(value);
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

class SbmsAiInsight {
  const SbmsAiInsight({
    required this.id,
    required this.title,
    required this.body,
    this.category = 'assistant',
    this.isAiGenerated = true,
    this.dealId,
  });

  final String id;
  final String title;
  final String body;
  final String category;
  final bool isAiGenerated;
  final String? dealId;
}

class SbmsCommandCenterSnapshot {
  const SbmsCommandCenterSnapshot({
    required this.kpis,
    required this.stages,
    required this.deals,
    required this.reservations,
    required this.bookings,
    required this.quotes,
    required this.negotiations,
    required this.contracts,
    required this.installments,
    required this.commissions,
    required this.handovers,
    required this.discountRequests,
    required this.activities,
    required this.alerts,
    required this.leaderboard,
    required this.aiInsights,
    required this.dealIntelligence,
    this.fromRemote = false,
    this.loadedAt,
    this.forecastDisclaimer = kSalesEstimateDisclaimer,
  });

  final List<SbmsKpi> kpis;
  final List<SbmsPipelineStage> stages;
  final List<SbmsDeal> deals;
  final List<SbmsReservation> reservations;
  final List<SbmsBooking> bookings;
  final List<SbmsQuote> quotes;
  final List<SbmsNegotiation> negotiations;
  final List<SbmsContract> contracts;
  final List<SbmsInstallment> installments;
  final List<SbmsCommission> commissions;
  final List<SbmsHandover> handovers;
  final List<SbmsDiscountRequest> discountRequests;
  final List<SbmsActivity> activities;
  final List<SbmsAlert> alerts;
  final List<SbmsLeaderboardRow> leaderboard;
  final List<SbmsAiInsight> aiInsights;
  final List<String> dealIntelligence;
  final bool fromRemote;
  final DateTime? loadedAt;
  final String forecastDisclaimer;

  Map<String, int> stageCounts() {
    final counts = <String, int>{};
    for (final s in stages) {
      counts[s.slug] = 0;
    }
    for (final d in deals) {
      final slug = d.stageSlug;
      if (slug == null) continue;
      counts[slug] = (counts[slug] ?? 0) + 1;
    }
    return counts;
  }
}

/// Default / offline SBMS dataset when DB is empty or unavailable.
abstract final class SbmsDemo {
  static SbmsCommandCenterSnapshot snapshot() {
    final now = DateTime.now();
    final stages = _stages();
    final deals = _deals(now);
    final reservations = _reservations(now);
    final bookings = _bookings(now);
    final quotes = _quotes(now);
    final negotiations = _negotiations(now);
    final contracts = _contracts(now);
    final installments = _installments(now);
    final commissions = _commissions(now);
    final handovers = _handovers(now);
    final discountRequests = _discountRequests();
    final activities = _activities(now);
    final alerts = _alerts(now);
    final leaderboard = _leaderboard();

    return SbmsCommandCenterSnapshot(
      kpis: aggregateKpis(
        deals: deals,
        reservations: reservations,
        contracts: contracts,
        installments: installments,
      ),
      stages: stages,
      deals: deals,
      reservations: reservations,
      bookings: bookings,
      quotes: quotes,
      negotiations: negotiations,
      contracts: contracts,
      installments: installments,
      commissions: commissions,
      handovers: handovers,
      discountRequests: discountRequests,
      activities: activities,
      alerts: alerts,
      leaderboard: leaderboard,
      aiInsights: const [
        SbmsAiInsight(
          id: 'sbms-ai-1',
          title: 'Close VIP negotiation — Adaeze',
          body:
              'Meet at ₦125M with optional furnishings. Confirm reservation extension before 48h expiry.',
          category: 'negotiation',
          dealId: 'deal-1',
        ),
        SbmsAiInsight(
          id: 'sbms-ai-2',
          title: 'Signature chase — Chuka contract',
          body:
              'Contract CT-LP-001 awaiting signature. Schedule office review and clear installment #2 due window.',
          category: 'contracts',
          dealId: 'deal-2',
        ),
        SbmsAiInsight(
          id: 'sbms-ai-3',
          title: 'Discount approval bottleneck',
          body:
              'Early Bird 5% request is pending. Finance/sales_team approval unlocks faster close.',
          category: 'approvals',
        ),
      ],
      dealIntelligence: const [
        'Weighted pipeline favors negotiation + contract stages this week.',
        'One reservation expires within 48h — prioritize deposit confirm call.',
        'Commission CM-PEND-001 blocked until deal moves past negotiation.',
        'Forecast stubs are estimates only — not guaranteed revenue.',
      ],
      fromRemote: false,
      loadedAt: now,
    );
  }

  static List<SbmsKpi> aggregateKpis({
    required List<SbmsDeal> deals,
    required List<SbmsReservation> reservations,
    required List<SbmsContract> contracts,
    required List<SbmsInstallment> installments,
  }) {
    final totalSales = deals.fold<double>(0, (s, d) => s + d.dealValue);
    final monthRevenue = deals
        .where((d) =>
            d.status == DealStatus.contract ||
            d.status == DealStatus.won ||
            d.status == DealStatus.negotiation)
        .fold<double>(0, (s, d) => s + d.weightedValue);
    final todayRevenue = monthRevenue * 0.08;
    final pendingReservations = reservations
        .where((r) =>
            r.status == ReservationStatus.reserved ||
            r.status == ReservationStatus.draft)
        .length
        .toDouble();
    final activeNeg = deals
        .where((d) => d.status == DealStatus.negotiation)
        .length
        .toDouble();
    final awaitingSignature = contracts
        .where((c) => c.status == ContractStatus.awaitingSignature)
        .length
        .toDouble();
    final installmentsDue = installments
        .where((i) =>
            i.status == InstallmentStatus.due ||
            i.status == InstallmentStatus.overdue ||
            i.isDueSoon)
        .length
        .toDouble();
    final pipelineValue = computePipelineValue(deals);

    return [
      SbmsKpi(label: 'Total Sales', value: totalSales, unit: 'ngn'),
      SbmsKpi(label: 'Today Revenue', value: todayRevenue, unit: 'ngn'),
      SbmsKpi(label: 'Month Revenue', value: monthRevenue, unit: 'ngn'),
      SbmsKpi(label: 'Pending Reservations', value: pendingReservations),
      SbmsKpi(label: 'Active Negotiations', value: activeNeg),
      SbmsKpi(label: 'Contracts Awaiting Signature', value: awaitingSignature),
      SbmsKpi(label: 'Installments Due', value: installmentsDue),
      SbmsKpi(label: 'Pipeline Value', value: pipelineValue, unit: 'ngn'),
    ];
  }

  static double computePipelineValue(List<SbmsDeal> deals) {
    return deals
        .where((d) =>
            d.status != DealStatus.won &&
            d.status != DealStatus.lost &&
            d.status != DealStatus.cancelled)
        .fold<double>(0, (s, d) => s + d.weightedValue);
  }

  static List<SbmsPipelineStage> _stages() => const [
        SbmsPipelineStage(
          id: 'stg-1',
          slug: 'enquiry',
          name: 'Enquiry',
          sortOrder: 10,
          color: '#94A3B8',
        ),
        SbmsPipelineStage(
          id: 'stg-2',
          slug: 'qualification',
          name: 'Qualification',
          sortOrder: 20,
          color: '#60A5FA',
        ),
        SbmsPipelineStage(
          id: 'stg-3',
          slug: 'viewing',
          name: 'Viewing',
          sortOrder: 30,
          color: '#34D399',
        ),
        SbmsPipelineStage(
          id: 'stg-4',
          slug: 'negotiation',
          name: 'Negotiation',
          sortOrder: 40,
          color: '#FBBF24',
        ),
        SbmsPipelineStage(
          id: 'stg-5',
          slug: 'contract',
          name: 'Contract',
          sortOrder: 50,
          color: '#F59E0B',
        ),
        SbmsPipelineStage(
          id: 'stg-6',
          slug: 'closed_won',
          name: 'Closed Won',
          sortOrder: 60,
          isTerminal: true,
          color: '#22C55E',
        ),
        SbmsPipelineStage(
          id: 'stg-7',
          slug: 'closed_lost',
          name: 'Closed Lost',
          sortOrder: 70,
          isTerminal: true,
          color: '#EF4444',
        ),
      ];

  static List<SbmsDeal> _deals(DateTime now) => [
        SbmsDeal(
          id: 'deal-1',
          orderCode: 'SO-VC-NEG-001',
          title: 'Adaeze Nwosu — Victoria Crest Unit 4',
          clientId: 'a1000000-0000-4000-8000-000000000001',
          clientName: 'Adaeze Nwosu',
          stageSlug: 'negotiation',
          stageName: 'Negotiation',
          dealValue: 125000000,
          probabilityPct: 65,
          status: DealStatus.negotiation,
          expectedCloseAt: now.add(const Duration(days: 21)),
          aiSummary:
              'Hot VIP duplex negotiation. Counter offer expected after reservation deposit.',
        ),
        SbmsDeal(
          id: 'deal-2',
          orderCode: 'SO-VC-CTR-002',
          title: 'Chuka Okonkwo — Lekki 3-bed payment plan',
          clientId: 'a1000000-0000-4000-8000-000000000002',
          clientName: 'Chuka Okonkwo',
          stageSlug: 'contract',
          stageName: 'Contract',
          dealValue: 85000000,
          probabilityPct: 85,
          status: DealStatus.contract,
          expectedCloseAt: now.add(const Duration(days: 10)),
          aiSummary:
              'Near contract. Payment plan + installments drafted. Awaiting signature pack.',
        ),
      ];

  static List<SbmsReservation> _reservations(DateTime now) => [
        SbmsReservation(
          id: 'rsv-1',
          reservationCode: 'RSV-EXP-001',
          status: ReservationStatus.reserved,
          clientId: 'a1000000-0000-4000-8000-000000000001',
          clientName: 'Adaeze Nwosu',
          propertyLabel: 'Victoria Crest Unit 4',
          orderId: 'deal-1',
          reservedAmount: 5000000,
          reservedAt: now.subtract(const Duration(days: 5)),
          expiresAt: now.add(const Duration(hours: 36)),
          notes: 'Deposit held — expires soon. Follow up before expiry.',
        ),
        SbmsReservation(
          id: 'rsv-2',
          reservationCode: 'RSV-CFM-002',
          status: ReservationStatus.confirmed,
          clientId: 'a1000000-0000-4000-8000-000000000002',
          clientName: 'Chuka Okonkwo',
          propertyLabel: 'Victoria Crest Unit 4',
          orderId: 'deal-2',
          reservedAmount: 8500000,
          reservedAt: now.subtract(const Duration(days: 12)),
          expiresAt: now.add(const Duration(days: 14)),
          confirmedAt: now.subtract(const Duration(days: 10)),
        ),
        SbmsReservation(
          id: 'rsv-3',
          reservationCode: 'RSV-DFT-003',
          status: ReservationStatus.draft,
          clientName: 'Horizon Capital Partners',
          reservedAmount: 0,
          expiresAt: now.add(const Duration(days: 7)),
          notes: 'Draft hold for multi-unit interest.',
        ),
      ];

  static List<SbmsBooking> _bookings(DateTime now) => [
        SbmsBooking(
          id: 'bk-1',
          bookingCode: 'BK-SITE-001',
          bookingType: BookingType.siteVisit,
          scheduledAt: now.add(const Duration(days: 2)),
          status: 'confirmed',
          clientName: 'Adaeze Nwosu',
          location: 'Victoria Crest showflat',
          durationMinutes: 90,
          orderId: 'deal-1',
        ),
        SbmsBooking(
          id: 'bk-2',
          bookingCode: 'BK-OFF-002',
          bookingType: BookingType.office,
          scheduledAt: now.add(const Duration(days: 5)),
          clientName: 'Chuka Okonkwo',
          location: 'HD Homes Lekki HQ',
          orderId: 'deal-2',
        ),
        SbmsBooking(
          id: 'bk-3',
          bookingCode: 'BK-VIRT-003',
          bookingType: BookingType.virtualTour,
          scheduledAt: now.add(const Duration(days: 1)),
          location: 'Zoom',
          durationMinutes: 45,
        ),
      ];

  static List<SbmsQuote> _quotes(DateTime now) => [
        SbmsQuote(
          id: 'qt-1',
          quoteCode: 'QT-VC-001',
          status: QuoteStatus.sent,
          clientName: 'Adaeze Nwosu',
          orderId: 'deal-1',
          subtotal: 128000000,
          discountAmount: 3000000,
          totalAmount: 125000000,
          validUntil: now.add(const Duration(days: 14)),
          sentAt: now.subtract(const Duration(days: 3)),
          items: const [
            SbmsQuoteItem(
              id: 'qi-1',
              label: 'Victoria Crest Unit 4',
              description: 'Duplex purchase price (estimate)',
              unitPrice: 125000000,
              lineTotal: 125000000,
            ),
            SbmsQuoteItem(
              id: 'qi-2',
              label: 'Furnishings allowance',
              unitPrice: 3000000,
              lineTotal: 3000000,
            ),
          ],
        ),
        SbmsQuote(
          id: 'qt-2',
          quoteCode: 'QT-LP-002',
          status: QuoteStatus.accepted,
          clientName: 'Chuka Okonkwo',
          orderId: 'deal-2',
          subtotal: 88000000,
          discountAmount: 3000000,
          totalAmount: 85000000,
          validUntil: now.add(const Duration(days: 7)),
          sentAt: now.subtract(const Duration(days: 8)),
        ),
      ];

  static List<SbmsNegotiation> _negotiations(DateTime now) => [
        SbmsNegotiation(
          id: 'neg-1',
          orderId: 'deal-1',
          eventType: 'offer',
          actorLabel: 'Sales — Amaka',
          amount: 128000000,
          body: 'Initial offer at list price',
          occurredAt: now.subtract(const Duration(days: 6)),
        ),
        SbmsNegotiation(
          id: 'neg-2',
          orderId: 'deal-1',
          eventType: 'counter',
          actorLabel: 'Client — Adaeze',
          amount: 120000000,
          body: 'Client countered at ₦120M',
          occurredAt: now.subtract(const Duration(days: 4)),
        ),
        SbmsNegotiation(
          id: 'neg-3',
          orderId: 'deal-1',
          eventType: 'concession',
          actorLabel: 'Sales — Amaka',
          amount: 125000000,
          body: 'Meet-in-middle at ₦125M with furnishings optional',
          occurredAt: now.subtract(const Duration(days: 3)),
        ),
      ];

  static List<SbmsContract> _contracts(DateTime now) => [
        SbmsContract(
          id: 'ct-1',
          contractCode: 'CT-LP-001',
          status: ContractStatus.awaitingSignature,
          orderId: 'deal-2',
          clientName: 'Chuka Okonkwo',
          contractValue: 85000000,
          issuedAt: now.subtract(const Duration(days: 1)),
          expiresAt: now.add(const Duration(days: 10)),
          notes: 'Digital signature pack sent to buyer counsel.',
        ),
      ];

  static List<SbmsInstallment> _installments(DateTime now) => [
        SbmsInstallment(
          id: 'ins-1',
          paymentPlanId: 'pp-1',
          installmentNo: 1,
          amount: 17000000,
          dueDate: now.subtract(const Duration(days: 5)),
          status: InstallmentStatus.paid,
          paidAt: now.subtract(const Duration(days: 5)),
        ),
        SbmsInstallment(
          id: 'ins-2',
          paymentPlanId: 'pp-1',
          installmentNo: 2,
          amount: 5666667,
          dueDate: now.add(const Duration(days: 3)),
          status: InstallmentStatus.due,
        ),
        SbmsInstallment(
          id: 'ins-3',
          paymentPlanId: 'pp-1',
          installmentNo: 3,
          amount: 5666667,
          dueDate: now.add(const Duration(days: 33)),
          status: InstallmentStatus.pending,
        ),
      ];

  static List<SbmsCommission> _commissions(DateTime now) => [
        SbmsCommission(
          id: 'cm-1',
          commissionCode: 'CM-PEND-001',
          status: CommissionStatus.pending,
          orderId: 'deal-1',
          agentName: 'Amaka Eze',
          baseAmount: 125000000,
          commissionPercent: 2.5,
          commissionAmount: 3125000,
          earnedAt: now.subtract(const Duration(days: 1)),
        ),
        SbmsCommission(
          id: 'cm-2',
          commissionCode: 'CM-APPR-002',
          status: CommissionStatus.approved,
          orderId: 'deal-2',
          agentName: 'Tobi Lawal',
          baseAmount: 85000000,
          commissionPercent: 2.0,
          commissionAmount: 1700000,
          earnedAt: now.subtract(const Duration(days: 5)),
          approvedAt: now.subtract(const Duration(days: 2)),
        ),
      ];

  static List<SbmsHandover> _handovers(DateTime now) => [
        SbmsHandover(
          id: 'ho-1',
          status: 'in_progress',
          orderId: 'deal-2',
          clientName: 'Chuka Okonkwo',
          scheduledAt: now.add(const Duration(days: 20)),
          checklist: const [
            SbmsChecklistItem(item: 'Title pack ready', done: true),
            SbmsChecklistItem(item: 'Keys scheduled'),
            SbmsChecklistItem(item: 'Snag list signed'),
            SbmsChecklistItem(item: 'Utility transfer'),
          ],
          notes: 'Handover checklist started after near-contract acceptance.',
        ),
      ];

  static List<SbmsDiscountRequest> _discountRequests() => const [
        SbmsDiscountRequest(
          id: 'dr-1',
          orderId: 'deal-1',
          requestedValue: 5,
          status: DiscountRequestStatus.pending,
          requesterLabel: 'Amaka Eze',
          justification: 'VIP early-bird 5% to close within 10 days',
          discountName: 'Early Bird 5%',
        ),
      ];

  static List<SbmsActivity> _activities(DateTime now) => [
        SbmsActivity(
          id: 'act-1',
          title: 'Counter received',
          orderId: 'deal-1',
          eventType: 'negotiation',
          description: 'Client countered at ₦120M',
          actorLabel: 'Adaeze Nwosu',
          occurredAt: now.subtract(const Duration(days: 4)),
        ),
        SbmsActivity(
          id: 'act-2',
          title: 'Contract awaiting signature',
          orderId: 'deal-2',
          eventType: 'contract',
          description: 'Signature pack sent',
          actorLabel: 'System',
          occurredAt: now.subtract(const Duration(days: 1)),
        ),
        SbmsActivity(
          id: 'act-3',
          title: 'Reservation expiring soon',
          orderId: 'deal-1',
          eventType: 'reservation',
          description: 'RSV-EXP-001 expires within 48h',
          actorLabel: 'System',
          occurredAt: now.subtract(const Duration(hours: 2)),
        ),
      ];

  static List<SbmsAlert> _alerts(DateTime now) => [
        SbmsAlert(
          id: 'al-1',
          title: 'Reservation expiring',
          body: 'RSV-EXP-001 expires within 36 hours — action required.',
          severity: 'high',
          orderId: 'deal-1',
          createdAt: now.subtract(const Duration(hours: 2)),
        ),
        SbmsAlert(
          id: 'al-2',
          title: 'Discount approval pending',
          body: 'Early Bird 5% request awaits manager approval.',
          severity: 'medium',
          orderId: 'deal-1',
          createdAt: now.subtract(const Duration(hours: 6)),
        ),
      ];

  static List<SbmsLeaderboardRow> _leaderboard() => const [
        SbmsLeaderboardRow(
          id: 'lb-1',
          periodLabel: 'July 2026',
          agentName: 'Amaka Eze',
          rank: 1,
          dealsWon: 4,
          revenue: 185000000,
        ),
        SbmsLeaderboardRow(
          id: 'lb-2',
          periodLabel: 'July 2026',
          agentName: 'Tobi Lawal',
          rank: 2,
          dealsWon: 3,
          revenue: 142000000,
        ),
        SbmsLeaderboardRow(
          id: 'lb-3',
          periodLabel: 'July 2026',
          agentName: 'Ngozi Bello',
          rank: 3,
          dealsWon: 2,
          revenue: 96000000,
        ),
      ];
}
