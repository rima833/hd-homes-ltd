// Volume 4 Part 4 — Enterprise Investor Management Platform domain models.

enum InvestorType {
  individual,
  hnwi,
  corporate,
  institutional,
  familyOffice,
  firstTime,
  fund;

  String get label => switch (this) {
    InvestorType.individual => 'Individual',
    InvestorType.hnwi => 'HNWI',
    InvestorType.corporate => 'Corporate',
    InvestorType.institutional => 'Institutional',
    InvestorType.familyOffice => 'Family Office',
    InvestorType.firstTime => 'First Time',
    InvestorType.fund => 'Fund',
  };

  String get slug => switch (this) {
    InvestorType.familyOffice => 'family_office',
    InvestorType.firstTime => 'first_time',
    _ => name,
  };

  static InvestorType fromSlug(String? raw) {
    return switch ((raw ?? 'individual').toLowerCase()) {
      'hnwi' => InvestorType.hnwi,
      'corporate' => InvestorType.corporate,
      'institutional' => InvestorType.institutional,
      'family_office' || 'familyoffice' => InvestorType.familyOffice,
      'first_time' || 'firsttime' => InvestorType.firstTime,
      'fund' => InvestorType.fund,
      _ => InvestorType.individual,
    };
  }
}

enum InvestorLifecycleStatus {
  prospect,
  onboarding,
  active,
  vip,
  dormant,
  exited,
  suspended;

  String get label => switch (this) {
    InvestorLifecycleStatus.prospect => 'Prospect',
    InvestorLifecycleStatus.onboarding => 'Onboarding',
    InvestorLifecycleStatus.active => 'Active',
    InvestorLifecycleStatus.vip => 'VIP',
    InvestorLifecycleStatus.dormant => 'Dormant',
    InvestorLifecycleStatus.exited => 'Exited',
    InvestorLifecycleStatus.suspended => 'Suspended',
  };

  String get slug => name;

  static InvestorLifecycleStatus fromSlug(String? raw) {
    return switch ((raw ?? 'prospect').toLowerCase()) {
      'onboarding' => InvestorLifecycleStatus.onboarding,
      'active' => InvestorLifecycleStatus.active,
      'vip' => InvestorLifecycleStatus.vip,
      'dormant' => InvestorLifecycleStatus.dormant,
      'exited' => InvestorLifecycleStatus.exited,
      'suspended' => InvestorLifecycleStatus.suspended,
      _ => InvestorLifecycleStatus.prospect,
    };
  }
}

enum KycStatus {
  pending,
  inProgress,
  awaitingDocuments,
  underReview,
  approved,
  partiallyApproved,
  rejected,
  expired,
  suspended,
  needsResubmission;

  String get label => switch (this) {
    KycStatus.pending => 'Pending',
    KycStatus.inProgress => 'In Progress',
    KycStatus.awaitingDocuments => 'Awaiting Documents',
    KycStatus.underReview => 'Under Review',
    KycStatus.approved => 'Approved',
    KycStatus.partiallyApproved => 'Partially Approved',
    KycStatus.rejected => 'Rejected',
    KycStatus.expired => 'Expired',
    KycStatus.suspended => 'Suspended',
    KycStatus.needsResubmission => 'Needs Resubmission',
  };

  String get slug => switch (this) {
    KycStatus.inProgress => 'in_progress',
    KycStatus.awaitingDocuments => 'awaiting_documents',
    KycStatus.underReview => 'under_review',
    KycStatus.partiallyApproved => 'partially_approved',
    KycStatus.needsResubmission => 'needs_resubmission',
    _ => name,
  };

  static KycStatus fromSlug(String? raw) {
    return switch ((raw ?? 'pending').toLowerCase()) {
      'in_progress' || 'inprogress' => KycStatus.inProgress,
      'awaiting_documents' ||
      'awaitingdocuments' => KycStatus.awaitingDocuments,
      'under_review' || 'underreview' => KycStatus.underReview,
      'approved' => KycStatus.approved,
      'partially_approved' ||
      'partiallyapproved' => KycStatus.partiallyApproved,
      'rejected' => KycStatus.rejected,
      'expired' => KycStatus.expired,
      'suspended' => KycStatus.suspended,
      'needs_resubmission' ||
      'needsresubmission' => KycStatus.needsResubmission,
      _ => KycStatus.pending,
    };
  }
}

enum OpportunityStatus {
  open,
  closed,
  fullyFunded,
  suspended,
  completed;

  String get label => switch (this) {
    OpportunityStatus.open => 'Open',
    OpportunityStatus.closed => 'Closed',
    OpportunityStatus.fullyFunded => 'Fully Funded',
    OpportunityStatus.suspended => 'Suspended',
    OpportunityStatus.completed => 'Completed',
  };

  String get slug => switch (this) {
    OpportunityStatus.fullyFunded => 'fully_funded',
    _ => name,
  };

  static OpportunityStatus fromSlug(String? raw) {
    return switch ((raw ?? 'open').toLowerCase()) {
      'closed' => OpportunityStatus.closed,
      'fully_funded' || 'fullyfunded' => OpportunityStatus.fullyFunded,
      'suspended' => OpportunityStatus.suspended,
      'completed' => OpportunityStatus.completed,
      _ => OpportunityStatus.open,
    };
  }
}

enum DistributionStatus {
  scheduled,
  processing,
  paid,
  failed,
  cancelled;

  String get label => switch (this) {
    DistributionStatus.scheduled => 'Scheduled',
    DistributionStatus.processing => 'Processing',
    DistributionStatus.paid => 'Paid',
    DistributionStatus.failed => 'Failed',
    DistributionStatus.cancelled => 'Cancelled',
  };

  String get slug => name;

  static DistributionStatus fromSlug(String? raw) {
    return switch ((raw ?? 'scheduled').toLowerCase()) {
      'processing' => DistributionStatus.processing,
      'paid' => DistributionStatus.paid,
      'failed' => DistributionStatus.failed,
      'cancelled' => DistributionStatus.cancelled,
      _ => DistributionStatus.scheduled,
    };
  }
}

enum RiskLevel {
  conservative,
  moderate,
  aggressive,
  speculative;

  String get label => switch (this) {
    RiskLevel.conservative => 'Conservative',
    RiskLevel.moderate => 'Moderate',
    RiskLevel.aggressive => 'Aggressive',
    RiskLevel.speculative => 'Speculative',
  };

  String get slug => name;

  static RiskLevel fromSlug(String? raw) {
    return switch ((raw ?? 'moderate').toLowerCase()) {
      'conservative' => RiskLevel.conservative,
      'aggressive' => RiskLevel.aggressive,
      'speculative' => RiskLevel.speculative,
      _ => RiskLevel.moderate,
    };
  }
}

enum AlertSeverity {
  info,
  low,
  medium,
  high,
  critical;

  String get label => switch (this) {
    AlertSeverity.info => 'Info',
    AlertSeverity.low => 'Low',
    AlertSeverity.medium => 'Medium',
    AlertSeverity.high => 'High',
    AlertSeverity.critical => 'Critical',
  };

  String get slug => name;

  static AlertSeverity fromSlug(String? raw) {
    return switch ((raw ?? 'info').toLowerCase()) {
      'low' => AlertSeverity.low,
      'medium' => AlertSeverity.medium,
      'high' => AlertSeverity.high,
      'critical' => AlertSeverity.critical,
      _ => AlertSeverity.info,
    };
  }
}

const String kProjectedReturnDisclaimer =
    'Projected returns are estimates only and are not guaranteed. '
    'Past performance does not predict future results.';

String formatImpMoney(double? value) {
  if (value == null) return '—';
  final n = value;
  if (n >= 1e9) return '₦${(n / 1e9).toStringAsFixed(1)}B';
  if (n >= 1e6) return '₦${(n / 1e6).toStringAsFixed(1)}M';
  if (n >= 1e3) return '₦${(n / 1e3).toStringAsFixed(0)}K';
  return '₦${n.toStringAsFixed(0)}';
}

class ImpInvestor {
  const ImpInvestor({
    required this.id,
    required this.investorCode,
    required this.fullName,
    this.email,
    this.phone,
    this.company,
    this.userId,
    this.assignedStaffId,
    this.assignedStaffName,
    this.investorType = InvestorType.individual,
    this.lifecycleStatus = InvestorLifecycleStatus.prospect,
    this.kycStatus = KycStatus.pending,
    this.riskLevel = RiskLevel.moderate,
    this.nationality,
    this.preferredCurrency = 'NGN',
    this.aum = 0,
    this.totalCommitted = 0,
    this.aiSummary,
    this.tags = const [],
    this.preferredLocations = const [],
    this.shareableReferralCode,
  });

  final String id;
  final String investorCode;
  final String fullName;
  final String? email;
  final String? phone;
  final String? company;
  final String? userId;
  final String? assignedStaffId;
  final String? assignedStaffName;
  final InvestorType investorType;
  final InvestorLifecycleStatus lifecycleStatus;
  final KycStatus kycStatus;
  final RiskLevel riskLevel;
  final String? nationality;
  final String preferredCurrency;
  final double aum;
  final double totalCommitted;
  final String? aiSummary;
  final List<String> tags;
  final List<String> preferredLocations;
  final String? shareableReferralCode;

  String get aumDisplay => formatImpMoney(aum);

  factory ImpInvestor.fromJson(Map<String, dynamic> json) {
    final tagsRaw = json['tags'];
    final locs = json['preferred_locations'];
    final metaRaw = json['metadata'];
    final metadata = metaRaw is Map
        ? Map<String, dynamic>.from(metaRaw)
        : const <String, dynamic>{};
    final referral = '${metadata['referral_code'] ?? ''}'.trim();
    return ImpInvestor(
      id: json['id']?.toString() ?? '',
      investorCode: json['investor_code'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      company: json['company'] as String?,
      userId: json['user_id']?.toString(),
      assignedStaffId: json['assigned_staff_id']?.toString(),
      assignedStaffName: json['assigned_staff_name'] as String?,
      investorType: InvestorType.fromSlug(json['investor_type'] as String?),
      lifecycleStatus: InvestorLifecycleStatus.fromSlug(
        json['lifecycle_status'] as String?,
      ),
      kycStatus: KycStatus.fromSlug(json['kyc_status'] as String?),
      riskLevel: RiskLevel.fromSlug(json['risk_level'] as String?),
      nationality: json['nationality'] as String?,
      preferredCurrency: json['preferred_currency'] as String? ?? 'NGN',
      aum: (json['aum'] as num?)?.toDouble() ?? 0,
      totalCommitted: (json['total_committed'] as num?)?.toDouble() ?? 0,
      aiSummary: json['ai_summary'] as String?,
      tags: tagsRaw is List
          ? tagsRaw.map((e) => e.toString()).toList()
          : const <String>[],
      preferredLocations: locs is List
          ? locs.map((e) => e.toString()).toList()
          : const <String>[],
      shareableReferralCode: referral.isEmpty ? null : referral,
    );
  }
}

class ImpOpportunity {
  const ImpOpportunity({
    required this.id,
    required this.code,
    required this.title,
    this.description,
    this.propertyId,
    this.status = OpportunityStatus.open,
    this.targetRaise = 0,
    this.amountRaised = 0,
    this.minTicket,
    this.maxTicket,
    this.currency = 'NGN',
    this.projectedReturnPct,
    this.returnDisclaimer = kProjectedReturnDisclaimer,
    this.riskLevel = RiskLevel.moderate,
  });

  final String id;
  final String code;
  final String title;
  final String? description;
  final String? propertyId;
  final OpportunityStatus status;
  final double targetRaise;
  final double amountRaised;
  final double? minTicket;
  final double? maxTicket;
  final String currency;
  final double? projectedReturnPct;
  final String returnDisclaimer;
  final RiskLevel riskLevel;

  double get fundedPct =>
      targetRaise <= 0 ? 0 : (amountRaised / targetRaise * 100).clamp(0, 100);

  String get projectedReturnLabel {
    final pct = projectedReturnPct;
    if (pct == null) return 'Estimate TBD';
    return '${pct.toStringAsFixed(1)}% est.';
  }

  factory ImpOpportunity.fromJson(Map<String, dynamic> json) {
    return ImpOpportunity(
      id: json['id']?.toString() ?? '',
      code: json['code'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      propertyId: json['property_id']?.toString(),
      status: OpportunityStatus.fromSlug(json['status'] as String?),
      targetRaise: (json['target_raise'] as num?)?.toDouble() ?? 0,
      amountRaised: (json['amount_raised'] as num?)?.toDouble() ?? 0,
      minTicket: (json['min_ticket'] as num?)?.toDouble(),
      maxTicket: (json['max_ticket'] as num?)?.toDouble(),
      currency: json['currency'] as String? ?? 'NGN',
      projectedReturnPct: (json['projected_return_pct'] as num?)?.toDouble(),
      returnDisclaimer:
          json['return_disclaimer'] as String? ?? kProjectedReturnDisclaimer,
      riskLevel: RiskLevel.fromSlug(json['risk_level'] as String?),
    );
  }
}

/// Public CMS investment card that can be linked to an operational opportunity.
class ImpWebsiteOpportunity {
  const ImpWebsiteOpportunity({
    required this.id,
    required this.projectName,
    required this.slug,
    this.status = 'active',
    this.opportunityStatus,
    this.operationalOpportunityId,
    this.isFeatured = false,
  });

  final String id;
  final String projectName;
  final String slug;
  final String status;
  final String? opportunityStatus;
  final String? operationalOpportunityId;
  final bool isFeatured;

  bool get isLinked =>
      operationalOpportunityId != null && operationalOpportunityId!.isNotEmpty;

  /// Public website RLS only exposes `status = active`.
  bool get isPublished => status == 'active';

  factory ImpWebsiteOpportunity.fromJson(Map<String, dynamic> json) {
    return ImpWebsiteOpportunity(
      id: json['id']?.toString() ?? '',
      projectName: json['project_name'] as String? ?? 'Website opportunity',
      slug: json['slug'] as String? ?? '',
      status: json['status'] as String? ?? 'active',
      opportunityStatus: json['opportunity_status'] as String?,
      operationalOpportunityId: json['operational_opportunity_id']?.toString(),
      isFeatured: json['is_featured'] == true,
    );
  }
}

class ImpCommitment {
  const ImpCommitment({
    required this.id,
    required this.investorId,
    required this.opportunityId,
    required this.amount,
    this.investorName,
    this.opportunityTitle,
    this.currency = 'NGN',
    this.status = 'pending',
    this.committedAt,
  });

  final String id;
  final String investorId;
  final String opportunityId;
  final double amount;
  final String? investorName;
  final String? opportunityTitle;
  final String currency;
  final String status;
  final DateTime? committedAt;

  String get amountDisplay => formatImpMoney(amount);

  factory ImpCommitment.fromJson(Map<String, dynamic> json) {
    final invRel = json['investors'];
    final oppRel = json['investment_opportunities'];
    return ImpCommitment(
      id: json['id']?.toString() ?? '',
      investorId: json['investor_id']?.toString() ?? '',
      opportunityId: json['opportunity_id']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      investorName:
          json['investor_name'] as String? ??
          (invRel is Map ? invRel['full_name'] as String? : null),
      opportunityTitle:
          json['opportunity_title'] as String? ??
          (oppRel is Map ? oppRel['title'] as String? : null),
      currency: json['currency'] as String? ?? 'NGN',
      status: json['status'] as String? ?? 'pending',
      committedAt: DateTime.tryParse(json['committed_at'] as String? ?? ''),
    );
  }
}

class ImpHolding {
  const ImpHolding({
    required this.id,
    required this.portfolioId,
    required this.label,
    this.opportunityId,
    this.investorId,
    this.investorName,
    this.units = 1,
    this.costBasis = 0,
    this.currentValue = 0,
    this.currency = 'NGN',
  });

  final String id;
  final String portfolioId;
  final String label;
  final String? opportunityId;
  final String? investorId;
  final String? investorName;
  final double units;
  final double costBasis;
  final double currentValue;
  final String currency;

  double get gain => currentValue - costBasis;

  factory ImpHolding.fromJson(Map<String, dynamic> json) {
    return ImpHolding(
      id: json['id']?.toString() ?? '',
      portfolioId: json['portfolio_id']?.toString() ?? '',
      label: json['label'] as String? ?? '',
      opportunityId: json['opportunity_id']?.toString(),
      investorId: json['investor_id']?.toString(),
      investorName: json['investor_name'] as String?,
      units: (json['units'] as num?)?.toDouble() ?? 1,
      costBasis: (json['cost_basis'] as num?)?.toDouble() ?? 0,
      currentValue: (json['current_value'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'NGN',
    );
  }
}

class ImpDistribution {
  const ImpDistribution({
    required this.id,
    required this.investorId,
    required this.amount,
    this.investorName,
    this.opportunityTitle,
    this.status = DistributionStatus.scheduled,
    this.distributionType = 'dividend',
    this.currency = 'NGN',
    this.scheduledAt,
    this.paidAt,
    this.reference,
  });

  final String id;
  final String investorId;
  final double amount;
  final String? investorName;
  final String? opportunityTitle;
  final DistributionStatus status;
  final String distributionType;
  final String currency;
  final DateTime? scheduledAt;
  final DateTime? paidAt;
  final String? reference;

  String get amountDisplay => formatImpMoney(amount);

  factory ImpDistribution.fromJson(Map<String, dynamic> json) {
    final invRel = json['investors'];
    final oppRel = json['investment_opportunities'];
    return ImpDistribution(
      id: json['id']?.toString() ?? '',
      investorId: json['investor_id']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      investorName:
          json['investor_name'] as String? ??
          (invRel is Map ? invRel['full_name'] as String? : null),
      opportunityTitle:
          json['opportunity_title'] as String? ??
          (oppRel is Map ? oppRel['title'] as String? : null),
      status: DistributionStatus.fromSlug(json['status'] as String?),
      distributionType: json['distribution_type'] as String? ?? 'dividend',
      currency: json['currency'] as String? ?? 'NGN',
      scheduledAt: DateTime.tryParse(json['scheduled_at'] as String? ?? ''),
      paidAt: DateTime.tryParse(json['paid_at'] as String? ?? ''),
      reference: json['reference'] as String?,
    );
  }
}

class ImpWallet {
  const ImpWallet({
    required this.id,
    required this.investorId,
    this.investorName,
    this.currency = 'NGN',
    this.availableBalance = 0,
    this.pendingBalance = 0,
    this.reservedBalance = 0,
  });

  final String id;
  final String investorId;
  final String? investorName;
  final String currency;
  final double availableBalance;
  final double pendingBalance;
  final double reservedBalance;

  double get totalBalance =>
      availableBalance + pendingBalance + reservedBalance;

  factory ImpWallet.fromJson(Map<String, dynamic> json) {
    final invRel = json['investors'];
    return ImpWallet(
      id: json['id']?.toString() ?? '',
      investorId: json['investor_id']?.toString() ?? '',
      investorName:
          json['investor_name'] as String? ??
          (invRel is Map ? invRel['full_name'] as String? : null),
      currency: json['currency'] as String? ?? 'NGN',
      availableBalance: (json['available_balance'] as num?)?.toDouble() ?? 0,
      pendingBalance: (json['pending_balance'] as num?)?.toDouble() ?? 0,
      reservedBalance: (json['reserved_balance'] as num?)?.toDouble() ?? 0,
    );
  }
}

class ImpActivity {
  const ImpActivity({
    required this.id,
    required this.investorId,
    required this.eventType,
    required this.title,
    this.description,
    this.investorName,
    this.occurredAt,
  });

  final String id;
  final String investorId;
  final String eventType;
  final String title;
  final String? description;
  final String? investorName;
  final DateTime? occurredAt;

  factory ImpActivity.fromJson(Map<String, dynamic> json) {
    final invRel = json['investors'];
    return ImpActivity(
      id: json['id']?.toString() ?? '',
      investorId: json['investor_id']?.toString() ?? '',
      eventType: json['event_type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      investorName:
          json['investor_name'] as String? ??
          (invRel is Map ? invRel['full_name'] as String? : null),
      occurredAt: DateTime.tryParse(json['occurred_at'] as String? ?? ''),
    );
  }
}

class ImpAlert {
  const ImpAlert({
    required this.id,
    required this.title,
    this.investorId,
    this.body,
    this.severity = AlertSeverity.info,
    this.status = 'open',
    this.createdAt,
  });

  final String id;
  final String title;
  final String? investorId;
  final String? body;
  final AlertSeverity severity;
  final String status;
  final DateTime? createdAt;

  factory ImpAlert.fromJson(Map<String, dynamic> json) {
    return ImpAlert(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      investorId: json['investor_id']?.toString(),
      body: json['body'] as String?,
      severity: AlertSeverity.fromSlug(json['severity'] as String?),
      status: json['status'] as String? ?? 'open',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }
}

class ImpLedgerEntry {
  const ImpLedgerEntry({
    required this.id,
    required this.investorId,
    required this.transactionType,
    required this.amount,
    required this.currency,
    required this.direction,
    required this.status,
    this.reference,
    this.description,
    this.sourceType,
    this.sourceId,
    this.postedAt,
  });

  final String id;
  final String investorId;
  final String transactionType;
  final double amount;
  final String currency;
  final String direction;
  final String status;
  final String? reference;
  final String? description;
  final String? sourceType;
  final String? sourceId;
  final DateTime? postedAt;

  factory ImpLedgerEntry.fromJson(Map<String, dynamic> json) {
    return ImpLedgerEntry(
      id: json['id']?.toString() ?? '',
      investorId: json['investor_id']?.toString() ?? '',
      transactionType: json['transaction_type'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'NGN',
      direction: json['direction'] as String? ?? '',
      status: json['status'] as String? ?? '',
      reference: json['reference'] as String?,
      description: json['description'] as String?,
      sourceType: json['source_type'] as String?,
      sourceId: json['source_id']?.toString(),
      postedAt: DateTime.tryParse(json['posted_at'] as String? ?? ''),
    );
  }
}

class ImpKycDocument {
  const ImpKycDocument({
    required this.id,
    required this.investorId,
    required this.documentId,
    required this.documentType,
    required this.verificationStatus,
    this.rejectionReason,
    this.expiresAt,
    this.verifiedAt,
  });

  final String id;
  final String investorId;
  final String documentId;
  final String documentType;
  final String verificationStatus;
  final String? rejectionReason;
  final DateTime? expiresAt;
  final DateTime? verifiedAt;

  factory ImpKycDocument.fromJson(Map<String, dynamic> json) {
    return ImpKycDocument(
      id: json['id']?.toString() ?? '',
      investorId: json['investor_id']?.toString() ?? '',
      documentId: json['document_id']?.toString() ?? '',
      documentType: json['document_type'] as String? ?? '',
      verificationStatus: json['verification_status'] as String? ?? 'pending',
      rejectionReason: json['rejection_reason'] as String?,
      expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? ''),
      verifiedAt: DateTime.tryParse(json['verified_at'] as String? ?? ''),
    );
  }
}

class ImpKpi {
  const ImpKpi({required this.label, required this.value, this.unit = 'count'});

  final String label;
  final double value;
  final String unit;

  String get displayValue {
    if (unit == 'ngn') return formatImpMoney(value);
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

/// Full-book desk KPIs from `admin_get_investor_desk_kpis` (not limit-100 snapshot).
class ImpDeskKpis {
  const ImpDeskKpis({
    required this.totalInvestors,
    required this.activeInvestors,
    required this.totalAum,
    required this.capitalRaised,
    required this.upcomingDistributions,
    required this.pendingPayments,
    required this.kycPending,
    required this.overdueActions,
    required this.openOpportunities,
    this.generatedAt,
  });

  final int totalInvestors;
  final int activeInvestors;
  final double totalAum;
  final double capitalRaised;
  final double upcomingDistributions;
  final int pendingPayments;
  final int kycPending;
  final int overdueActions;
  final int openOpportunities;
  final DateTime? generatedAt;

  factory ImpDeskKpis.fromJson(Map<String, dynamic> json) {
    return ImpDeskKpis(
      totalInvestors: (json['total_investors'] as num?)?.toInt() ?? 0,
      activeInvestors: (json['active_investors'] as num?)?.toInt() ?? 0,
      totalAum: (json['total_aum'] as num?)?.toDouble() ?? 0,
      capitalRaised: (json['capital_raised'] as num?)?.toDouble() ?? 0,
      upcomingDistributions:
          (json['upcoming_distributions'] as num?)?.toDouble() ?? 0,
      pendingPayments: (json['pending_payments'] as num?)?.toInt() ?? 0,
      kycPending: (json['kyc_pending'] as num?)?.toInt() ?? 0,
      overdueActions: (json['overdue_actions'] as num?)?.toInt() ?? 0,
      openOpportunities: (json['open_opportunities'] as num?)?.toInt() ?? 0,
      generatedAt: DateTime.tryParse(json['generated_at'] as String? ?? ''),
    );
  }

  List<ImpKpi> toKpiCards() => [
        ImpKpi(label: 'Total Investors', value: totalInvestors.toDouble()),
        ImpKpi(label: 'Active Investors', value: activeInvestors.toDouble()),
        ImpKpi(label: 'Total AUM', value: totalAum, unit: 'ngn'),
        ImpKpi(label: 'Capital Raised', value: capitalRaised, unit: 'ngn'),
        ImpKpi(
          label: 'Upcoming Distributions',
          value: upcomingDistributions,
          unit: 'ngn',
        ),
        ImpKpi(label: 'Pending Payments', value: pendingPayments.toDouble()),
        ImpKpi(label: 'KYC Pending', value: kycPending.toDouble()),
        ImpKpi(label: 'Overdue Actions', value: overdueActions.toDouble()),
        ImpKpi(label: 'Open Opportunities', value: openOpportunities.toDouble()),
      ];
}

class ImpAiInsight {
  const ImpAiInsight({
    required this.id,
    required this.title,
    required this.body,
    this.category = 'assistant',
    this.isAiGenerated = true,
    this.investorId,
  });

  final String id;
  final String title;
  final String body;
  final String category;
  final bool isAiGenerated;
  final String? investorId;
}

class ImpCommandCenterSnapshot {
  const ImpCommandCenterSnapshot({
    required this.kpis,
    required this.investors,
    required this.opportunities,
    required this.commitments,
    required this.holdings,
    required this.distributions,
    required this.wallets,
    required this.activities,
    required this.alerts,
    required this.aiInsights,
    this.fromRemote = false,
    this.loadedAt,
  });

  final List<ImpKpi> kpis;
  final List<ImpInvestor> investors;
  final List<ImpOpportunity> opportunities;
  final List<ImpCommitment> commitments;
  final List<ImpHolding> holdings;
  final List<ImpDistribution> distributions;
  final List<ImpWallet> wallets;
  final List<ImpActivity> activities;
  final List<ImpAlert> alerts;
  final List<ImpAiInsight> aiInsights;
  final bool fromRemote;
  final DateTime? loadedAt;
}

class ImpInvestorPage {
  const ImpInvestorPage({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
    required this.hasMore,
  });

  final List<ImpInvestor> items;
  final int total;
  final int limit;
  final int offset;
  final bool hasMore;

  factory ImpInvestorPage.fromJson(Map<String, dynamic> json) {
    final rows = json['items'];
    return ImpInvestorPage(
      items: rows is List
          ? rows
                .whereType<Map>()
                .map(
                  (row) => ImpInvestor.fromJson(Map<String, dynamic>.from(row)),
                )
                .toList()
          : const [],
      total: (json['total'] as num?)?.toInt() ?? 0,
      limit: (json['limit'] as num?)?.toInt() ?? 50,
      offset: (json['offset'] as num?)?.toInt() ?? 0,
      hasMore: json['has_more'] as bool? ?? false,
    );
  }
}

class ImpVaultDocument {
  const ImpVaultDocument({
    required this.id,
    required this.investorId,
    required this.title,
    required this.documentType,
    this.fileUrl,
    this.version = 1,
    this.createdAt,
  });

  final String id;
  final String investorId;
  final String title;
  final String documentType;
  final String? fileUrl;
  final int version;
  final DateTime? createdAt;

  factory ImpVaultDocument.fromJson(Map<String, dynamic> json) {
    return ImpVaultDocument(
      id: json['id']?.toString() ?? '',
      investorId: json['investor_id']?.toString() ?? '',
      title: json['title'] as String? ?? 'Document',
      documentType: json['document_type'] as String? ?? 'shared',
      fileUrl: json['file_url'] as String?,
      version: (json['version'] as num?)?.toInt() ?? 1,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }
}

class ImpConversation {
  const ImpConversation({
    required this.id,
    required this.investorId,
    required this.subject,
    this.category,
    this.status = 'open',
    this.lastMessagePreview,
    this.staffUnreadCount = 0,
    this.lastMessageAt,
    this.investorName,
  });

  final String id;
  final String investorId;
  final String subject;
  final String? category;
  final String status;
  final String? lastMessagePreview;
  final int staffUnreadCount;
  final DateTime? lastMessageAt;
  final String? investorName;

  factory ImpConversation.fromJson(Map<String, dynamic> json) {
    final invRel = json['investors'];
    return ImpConversation(
      id: json['id']?.toString() ?? '',
      investorId: json['investor_id']?.toString() ?? '',
      subject: json['subject'] as String? ?? 'Conversation',
      category: json['category'] as String?,
      status: json['status'] as String? ?? 'open',
      lastMessagePreview: json['last_message_preview'] as String?,
      staffUnreadCount: (json['staff_unread_count'] as num?)?.toInt() ?? 0,
      lastMessageAt: DateTime.tryParse(json['last_message_at'] as String? ?? ''),
      investorName:
          json['investor_name'] as String? ??
          (invRel is Map ? invRel['full_name'] as String? : null),
    );
  }
}

class ImpReport {
  const ImpReport({
    required this.id,
    required this.investorId,
    required this.title,
    required this.reportType,
    this.fileUrl,
    this.periodLabel,
    this.generatedAt,
  });

  final String id;
  final String investorId;
  final String title;
  final String reportType;
  final String? fileUrl;
  final String? periodLabel;
  final DateTime? generatedAt;

  factory ImpReport.fromJson(Map<String, dynamic> json) {
    return ImpReport(
      id: json['id']?.toString() ?? '',
      investorId: json['investor_id']?.toString() ?? '',
      title: json['title'] as String? ?? 'Report',
      reportType: json['report_type'] as String? ?? 'custom',
      fileUrl: json['file_url'] as String?,
      periodLabel: json['period_label'] as String?,
      generatedAt: DateTime.tryParse(json['generated_at'] as String? ?? ''),
    );
  }
}

class ImpStatement {
  const ImpStatement({
    required this.id,
    required this.investorId,
    required this.periodLabel,
    this.fileUrl,
    this.openingBalance,
    this.closingBalance,
    this.currency = 'NGN',
    this.createdAt,
  });

  final String id;
  final String investorId;
  final String periodLabel;
  final String? fileUrl;
  final double? openingBalance;
  final double? closingBalance;
  final String currency;
  final DateTime? createdAt;

  factory ImpStatement.fromJson(Map<String, dynamic> json) {
    return ImpStatement(
      id: json['id']?.toString() ?? '',
      investorId: json['investor_id']?.toString() ?? '',
      periodLabel: json['period_label'] as String? ?? 'Statement',
      fileUrl: json['file_url'] as String?,
      openingBalance: (json['opening_balance'] as num?)?.toDouble(),
      closingBalance: (json['closing_balance'] as num?)?.toDouble(),
      currency: json['currency'] as String? ?? 'NGN',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }
}

class ImpReferralCommission {
  const ImpReferralCommission({
    required this.id,
    required this.investorId,
    required this.amount,
    required this.currency,
    required this.status,
    this.referralCode,
    this.referredUserId,
    this.paidAt,
    this.createdAt,
  });

  final String id;
  final String investorId;
  final double amount;
  final String currency;
  final String status;
  final String? referralCode;
  final String? referredUserId;
  final DateTime? paidAt;
  final DateTime? createdAt;

  factory ImpReferralCommission.fromJson(Map<String, dynamic> json) {
    return ImpReferralCommission(
      id: json['id']?.toString() ?? '',
      investorId: json['investor_id']?.toString() ?? '',
      amount: (json['commission_amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'NGN',
      status: json['status'] as String? ?? 'pending',
      referralCode: json['referral_code'] as String?,
      referredUserId: json['referred_user_id']?.toString(),
      paidAt: DateTime.tryParse(json['paid_at'] as String? ?? ''),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }
}

/// Construction summary for admin 360 (from admin_get_investor_construction).
class ImpConstructionProjectSummary {
  const ImpConstructionProjectSummary({
    required this.id,
    required this.name,
    this.propertyId,
    this.progressPct = 0,
    this.status = 'active',
    this.scheduleStatus = 'on_track',
    this.targetEndDate,
    this.coverImageUrl,
  });

  final String id;
  final String name;
  final String? propertyId;
  final double progressPct;
  final String status;
  final String scheduleStatus;
  final DateTime? targetEndDate;
  final String? coverImageUrl;

  factory ImpConstructionProjectSummary.fromJson(Map<String, dynamic> json) {
    return ImpConstructionProjectSummary(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? 'Project',
      propertyId: json['property_id']?.toString(),
      progressPct: (json['progress_pct'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'active',
      scheduleStatus: json['schedule_status'] as String? ?? 'on_track',
      targetEndDate: DateTime.tryParse(json['target_end_date'] as String? ?? ''),
      coverImageUrl: json['cover_image_url'] as String?,
    );
  }
}

class ImpConstructionMediaThumb {
  const ImpConstructionMediaThumb({
    required this.id,
    required this.url,
    this.thumbnailUrl,
    this.mediaType = 'image',
  });

  final String id;
  final String url;
  final String? thumbnailUrl;
  final String mediaType;

  String get displayUrl {
    final thumb = thumbnailUrl?.trim();
    if (thumb != null && thumb.isNotEmpty) return thumb;
    return url;
  }

  bool get isVideo => mediaType.toLowerCase() == 'video';

  factory ImpConstructionMediaThumb.fromJson(Map<String, dynamic> json) {
    final fileUrl =
        (json['file_url'] as String? ?? json['secure_url'] as String? ?? '')
            .trim();
    final thumb = (json['thumbnail_url'] as String?)?.trim();
    return ImpConstructionMediaThumb(
      id: json['id']?.toString() ?? fileUrl,
      url: fileUrl,
      thumbnailUrl: (thumb != null && thumb.isNotEmpty) ? thumb : null,
      mediaType: json['media_type'] as String? ?? 'image',
    );
  }
}

class ImpConstructionUpdateSummary {
  const ImpConstructionUpdateSummary({
    required this.id,
    required this.title,
    this.projectId,
    this.projectName,
    this.shortDescription,
    this.progressPct,
    this.publishedAt,
    this.media = const [],
  });

  final String id;
  final String title;
  final String? projectId;
  final String? projectName;
  final String? shortDescription;
  final double? progressPct;
  final DateTime? publishedAt;
  final List<ImpConstructionMediaThumb> media;

  factory ImpConstructionUpdateSummary.fromJson(Map<String, dynamic> json) {
    final mediaRaw = json['media'];
    final media = mediaRaw is List
        ? mediaRaw
            .whereType<Map>()
            .map(
              (row) => ImpConstructionMediaThumb.fromJson(
                Map<String, dynamic>.from(row),
              ),
            )
            .where((m) => m.url.isNotEmpty)
            .toList()
        : const <ImpConstructionMediaThumb>[];
    return ImpConstructionUpdateSummary(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? 'Update',
      projectId: json['project_id']?.toString(),
      projectName: json['project_name'] as String?,
      shortDescription: json['short_description'] as String?,
      progressPct: (json['progress_pct'] as num?)?.toDouble(),
      publishedAt: DateTime.tryParse(json['published_at'] as String? ?? ''),
      media: media,
    );
  }
}

class ImpConstructionSnapshot {
  const ImpConstructionSnapshot({
    this.projects = const [],
    this.updates = const [],
    this.overallPercent = 0,
  });

  final List<ImpConstructionProjectSummary> projects;
  final List<ImpConstructionUpdateSummary> updates;
  final double overallPercent;

  bool get isEmpty => projects.isEmpty && updates.isEmpty;

  factory ImpConstructionSnapshot.fromJson(Map<String, dynamic> json) {
    List<T> parse<T>(String key, T Function(Map<String, dynamic>) convert) {
      final rows = json[key];
      if (rows is! List) return const [];
      return rows
          .whereType<Map>()
          .map((row) => convert(Map<String, dynamic>.from(row)))
          .toList();
    }

    return ImpConstructionSnapshot(
      projects: parse('projects', ImpConstructionProjectSummary.fromJson),
      updates: parse('updates', ImpConstructionUpdateSummary.fromJson),
      overallPercent: (json['overall_percent'] as num?)?.toDouble() ?? 0,
    );
  }
}

class ImpSupportTicketRow {
  const ImpSupportTicketRow({
    required this.id,
    required this.subject,
    this.ticketNumber,
    this.status = 'open',
    this.priority = 'normal',
    this.userId,
    this.investorName,
    this.updatedAt,
  });

  final String id;
  final String subject;
  final String? ticketNumber;
  final String status;
  final String priority;
  final String? userId;
  final String? investorName;
  final DateTime? updatedAt;

  factory ImpSupportTicketRow.fromJson(Map<String, dynamic> json) {
    return ImpSupportTicketRow(
      id: json['id']?.toString() ?? '',
      subject: json['subject'] as String? ?? 'Support request',
      ticketNumber: json['ticket_number'] as String?,
      status: json['status'] as String? ?? 'open',
      priority: json['priority'] as String? ?? 'normal',
      userId: json['user_id']?.toString(),
      investorName: json['investor_name'] as String?,
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
    );
  }
}

/// Unified thread line for IMP support desk (portal convo or ticket).
class ImpSupportThreadMessage {
  const ImpSupportThreadMessage({
    required this.id,
    required this.body,
    this.senderName,
    this.senderType,
    this.isInternal = false,
    this.createdAt,
    this.isStaff = false,
  });

  final String id;
  final String body;
  final String? senderName;
  final String? senderType;
  final bool isInternal;
  final DateTime? createdAt;
  final bool isStaff;

  factory ImpSupportThreadMessage.fromConversationJson(
    Map<String, dynamic> json, {
    String? currentUserId,
  }) {
    final senderId = json['sender_id']?.toString();
    final senderType = json['sender_type'] as String?;
    final staff = senderType == 'staff' ||
        senderType == 'agent' ||
        (currentUserId != null &&
            senderId != null &&
            senderId == currentUserId);
    return ImpSupportThreadMessage(
      id: json['id']?.toString() ?? '',
      body: json['body'] as String? ?? '',
      senderName: json['sender_name'] as String?,
      senderType: senderType,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      isStaff: staff,
    );
  }

  factory ImpSupportThreadMessage.fromTicketJson(Map<String, dynamic> json) {
    final senderType = (json['sender_type'] as String? ?? '').toLowerCase();
    final isStaff = senderType == 'agent' || senderType == 'staff';
    return ImpSupportThreadMessage(
      id: json['id']?.toString() ?? '',
      body: json['message'] as String? ?? '',
      senderName: json['sender_name'] as String?,
      senderType: senderType.isEmpty ? null : senderType,
      isInternal: json['is_internal'] == true,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      isStaff: isStaff,
    );
  }
}

class ImpSupportInbox {
  const ImpSupportInbox({
    this.conversations = const [],
    this.tickets = const [],
  });

  final List<ImpConversation> conversations;
  final List<ImpSupportTicketRow> tickets;

  bool get isEmpty => conversations.isEmpty && tickets.isEmpty;
}

class ImpNotificationRow {
  const ImpNotificationRow({
    required this.id,
    required this.investorId,
    required this.title,
    this.body,
    this.channel = 'in_app',
    this.isRead = false,
    this.sentAt,
    this.investorName,
    this.route,
  });

  final String id;
  final String investorId;
  final String title;
  final String? body;
  final String channel;
  final bool isRead;
  final DateTime? sentAt;
  final String? investorName;
  final String? route;

  factory ImpNotificationRow.fromJson(Map<String, dynamic> json) {
    final meta = json['metadata'];
    final route = meta is Map ? meta['route'] as String? : null;
    final invRel = json['investors'];
    return ImpNotificationRow(
      id: json['id']?.toString() ?? '',
      investorId: json['investor_id']?.toString() ?? '',
      title: json['title'] as String? ?? 'Notification',
      body: json['body'] as String?,
      channel: json['channel'] as String? ?? 'in_app',
      isRead: json['is_read'] == true,
      sentAt: DateTime.tryParse(
        json['sent_at'] as String? ?? json['created_at'] as String? ?? '',
      ),
      investorName:
          json['investor_name'] as String? ??
          (invRel is Map ? invRel['full_name'] as String? : null),
      route: route,
    );
  }
}

class ImpInvestorDetail {
  const ImpInvestorDetail({
    required this.investor,
    required this.holdings,
    required this.distributions,
    required this.activities,
    this.wallet,
    this.documents = const [],
    this.conversations = const [],
    this.reports = const [],
    this.statements = const [],
    this.referrals = const [],
  });

  final ImpInvestor investor;
  final List<ImpHolding> holdings;
  final List<ImpDistribution> distributions;
  final List<ImpActivity> activities;
  final ImpWallet? wallet;
  final List<ImpVaultDocument> documents;
  final List<ImpConversation> conversations;
  final List<ImpReport> reports;
  final List<ImpStatement> statements;
  final List<ImpReferralCommission> referrals;

  factory ImpInvestorDetail.fromJson(Map<String, dynamic> json) {
    List<T> parseList<T>(String key, T Function(Map<String, dynamic>) convert) {
      final rows = json[key];
      if (rows is! List) return const [];
      return rows
          .whereType<Map>()
          .map((row) => convert(Map<String, dynamic>.from(row)))
          .toList();
    }

    final wallets = parseList('wallets', ImpWallet.fromJson);
    return ImpInvestorDetail(
      investor: ImpInvestor.fromJson(json),
      holdings: parseList('holdings', ImpHolding.fromJson),
      distributions: parseList('distributions', ImpDistribution.fromJson),
      activities: parseList('activities', ImpActivity.fromJson),
      wallet: wallets.isEmpty ? null : wallets.first,
      documents: parseList('documents', ImpVaultDocument.fromJson),
      conversations: parseList('conversations', ImpConversation.fromJson),
      reports: parseList('reports', ImpReport.fromJson),
      statements: parseList('statements', ImpStatement.fromJson),
      referrals: parseList('referrals', ImpReferralCommission.fromJson),
    );
  }
}

class ImpWorkQueueItem {
  const ImpWorkQueueItem({
    required this.id,
    required this.investorId,
    required this.title,
    required this.status,
    this.subtitle,
    this.amount,
    this.currency,
    this.priority,
    this.dueAt,
    this.createdAt,
  });

  final String id;
  final String investorId;
  final String title;
  final String status;
  final String? subtitle;
  final double? amount;
  final String? currency;
  final String? priority;
  final DateTime? dueAt;
  final DateTime? createdAt;

  factory ImpWorkQueueItem.fromJson(Map<String, dynamic> json) {
    return ImpWorkQueueItem(
      id: json['id']?.toString() ?? '',
      investorId: json['investor_id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      status: json['status'] as String? ?? '',
      subtitle: json['subtitle'] as String?,
      amount: (json['amount'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
      priority: json['priority'] as String?,
      dueAt: DateTime.tryParse(json['due_at'] as String? ?? ''),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }
}

class ImpWorkQueues {
  const ImpWorkQueues({
    this.unassigned = const [],
    this.kyc = const [],
    this.payments = const [],
    this.tasks = const [],
    this.stale = const [],
  });

  final List<ImpWorkQueueItem> unassigned;
  final List<ImpWorkQueueItem> kyc;
  final List<ImpWorkQueueItem> payments;
  final List<ImpWorkQueueItem> tasks;
  final List<ImpWorkQueueItem> stale;

  factory ImpWorkQueues.fromJson(Map<String, dynamic> json) {
    List<ImpWorkQueueItem> parse(String key) {
      final rows = json[key];
      if (rows is! List) return const [];
      return rows
          .whereType<Map>()
          .map(
            (row) => ImpWorkQueueItem.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList();
    }

    return ImpWorkQueues(
      unassigned: parse('unassigned'),
      kyc: parse('kyc'),
      payments: parse('payments'),
      tasks: parse('tasks'),
      stale: parse('stale'),
    );
  }
}

class ImpStaffOption {
  const ImpStaffOption({required this.id, required this.name, this.email});

  final String id;
  final String name;
  final String? email;

  factory ImpStaffOption.fromJson(Map<String, dynamic> json) {
    return ImpStaffOption(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String?,
    );
  }
}

/// Neutral calculations shared by IMP data sources and presentation.
abstract final class ImpMetrics {
  static List<ImpKpi> aggregateKpis({
    required List<ImpInvestor> investors,
    required List<ImpOpportunity> opportunities,
    required List<ImpDistribution> distributions,
    required List<ImpCommitment> commitments,
  }) {
    final aum = investors.fold<double>(0, (s, i) => s + i.aum);
    final activeInvestors = investors
        .where(
          (i) =>
              i.lifecycleStatus == InvestorLifecycleStatus.active ||
              i.lifecycleStatus == InvestorLifecycleStatus.vip ||
              i.lifecycleStatus == InvestorLifecycleStatus.onboarding,
        )
        .length
        .toDouble();
    final capitalRaised = opportunities.fold<double>(
      0,
      (s, o) => s + o.amountRaised,
    );
    final upcomingPayouts = distributions
        .where(
          (d) =>
              d.status == DistributionStatus.scheduled ||
              d.status == DistributionStatus.processing,
        )
        .fold<double>(0, (s, d) => s + d.amount);
    final avgInvestment = commitments.isEmpty
        ? 0.0
        : commitments.fold<double>(0, (s, c) => s + c.amount) /
              commitments.length;
    final openOpps = opportunities
        .where((o) => o.status == OpportunityStatus.open)
        .length
        .toDouble();

    return [
      ImpKpi(label: 'AUM', value: aum, unit: 'ngn'),
      ImpKpi(label: 'Active Investors', value: activeInvestors),
      ImpKpi(label: 'Capital Raised', value: capitalRaised, unit: 'ngn'),
      ImpKpi(label: 'Upcoming Payouts', value: upcomingPayouts, unit: 'ngn'),
      ImpKpi(label: 'Avg Investment', value: avgInvestment, unit: 'ngn'),
      ImpKpi(label: 'Open Opportunities', value: openOpps),
    ];
  }

  static double computePortfolioValue(List<ImpHolding> holdings) {
    return holdings.fold<double>(0, (s, h) => s + h.currentValue);
  }
}
