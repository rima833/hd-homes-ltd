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
      'awaiting_documents' || 'awaitingdocuments' => KycStatus.awaitingDocuments,
      'under_review' || 'underreview' => KycStatus.underReview,
      'approved' => KycStatus.approved,
      'partially_approved' || 'partiallyapproved' => KycStatus.partiallyApproved,
      'rejected' => KycStatus.rejected,
      'expired' => KycStatus.expired,
      'suspended' => KycStatus.suspended,
      'needs_resubmission' || 'needsresubmission' =>
        KycStatus.needsResubmission,
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
  });

  final String id;
  final String investorCode;
  final String fullName;
  final String? email;
  final String? phone;
  final String? company;
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

  String get aumDisplay => formatImpMoney(aum);

  factory ImpInvestor.fromJson(Map<String, dynamic> json) {
    final tagsRaw = json['tags'];
    final locs = json['preferred_locations'];
    return ImpInvestor(
      id: json['id']?.toString() ?? '',
      investorCode: json['investor_code'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      company: json['company'] as String?,
      investorType: InvestorType.fromSlug(json['investor_type'] as String?),
      lifecycleStatus:
          InvestorLifecycleStatus.fromSlug(json['lifecycle_status'] as String?),
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
      returnDisclaimer: json['return_disclaimer'] as String? ??
          kProjectedReturnDisclaimer,
      riskLevel: RiskLevel.fromSlug(json['risk_level'] as String?),
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
      investorName: json['investor_name'] as String? ??
          (invRel is Map ? invRel['full_name'] as String? : null),
      opportunityTitle: json['opportunity_title'] as String? ??
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
      investorName: json['investor_name'] as String? ??
          (invRel is Map ? invRel['full_name'] as String? : null),
      opportunityTitle: json['opportunity_title'] as String? ??
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
      investorName: json['investor_name'] as String? ??
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
      investorName: json['investor_name'] as String? ??
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

class ImpKpi {
  const ImpKpi({
    required this.label,
    required this.value,
    this.unit = 'count',
  });

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

/// Default / offline IMP dataset when DB is empty or unavailable.
abstract final class ImpDemo {
  static ImpCommandCenterSnapshot snapshot() {
    final now = DateTime.now();
    final investors = _investors();
    final opportunities = _opportunities();
    final commitments = _commitments(now);
    final holdings = _holdings();
    final distributions = _distributions(now);
    final wallets = _wallets();
    final activities = _activities(now);
    final alerts = _alerts(now);

    return ImpCommandCenterSnapshot(
      kpis: aggregateKpis(
        investors: investors,
        opportunities: opportunities,
        distributions: distributions,
        commitments: commitments,
      ),
      investors: investors,
      opportunities: opportunities,
      commitments: commitments,
      holdings: holdings,
      distributions: distributions,
      wallets: wallets,
      activities: activities,
      alerts: alerts,
      aiInsights: const [
        ImpAiInsight(
          id: 'imp-ai-1',
          title: 'VIP upsell — Folake Adeyemi',
          body:
              'Victoria Crest open raise fits HNWI coastal mandate. Convert confirmed ₦75M commit to funded this week.',
          category: 'raise',
          investorId: 'imp-1',
        ),
        ImpAiInsight(
          id: 'imp-ai-2',
          title: 'Institutional KYC unblock — Meridian',
          body:
              'UBO schedule is blocking next tranche. Finance + compliance joint review recommended within 48h.',
          category: 'compliance',
          investorId: 'imp-2',
        ),
        ImpAiInsight(
          id: 'imp-ai-3',
          title: 'First-time nurture — Tunde Bakare',
          body:
              'Keep ticket under ₦30M with estimate disclaimers front-and-center. Complete KYC docs before funding.',
          category: 'onboarding',
          investorId: 'imp-3',
        ),
        ImpAiInsight(
          id: 'imp-ai-4',
          title: 'Distribution queue',
          body:
              'Two scheduled payouts due within 25 days — confirm wallet balances and bank verification.',
          category: 'distributions',
        ),
      ],
      fromRemote: false,
      loadedAt: now,
    );
  }

  static List<ImpKpi> aggregateKpis({
    required List<ImpInvestor> investors,
    required List<ImpOpportunity> opportunities,
    required List<ImpDistribution> distributions,
    required List<ImpCommitment> commitments,
  }) {
    final aum = investors.fold<double>(0, (s, i) => s + i.aum);
    final activeInvestors = investors
        .where((i) =>
            i.lifecycleStatus == InvestorLifecycleStatus.active ||
            i.lifecycleStatus == InvestorLifecycleStatus.vip ||
            i.lifecycleStatus == InvestorLifecycleStatus.onboarding)
        .length
        .toDouble();
    final capitalRaised =
        opportunities.fold<double>(0, (s, o) => s + o.amountRaised);
    final upcomingPayouts = distributions
        .where((d) =>
            d.status == DistributionStatus.scheduled ||
            d.status == DistributionStatus.processing)
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

  static List<ImpInvestor> _investors() => const [
        ImpInvestor(
          id: 'imp-1',
          investorCode: 'INV-VIP-001',
          fullName: 'Folake Adeyemi',
          email: 'folake.adeyemi@example.com',
          phone: '+2348021000001',
          company: 'Adeyemi Family Office',
          investorType: InvestorType.hnwi,
          lifecycleStatus: InvestorLifecycleStatus.vip,
          kycStatus: KycStatus.approved,
          riskLevel: RiskLevel.moderate,
          nationality: 'Nigerian',
          aum: 420000000,
          totalCommitted: 185000000,
          aiSummary:
              'VIP HNWI with strong appetite for Lekki coastal assets. Prioritize Victoria Crest upsell.',
          tags: ['vip', 'platinum', 'hnwi'],
          preferredLocations: ['Lekki', 'Victoria Island'],
        ),
        ImpInvestor(
          id: 'imp-2',
          investorCode: 'INV-CORP-002',
          fullName: 'Meridian Equity Partners',
          email: 'deals@meridianequity.example',
          phone: '+2348021000002',
          company: 'Meridian Equity Partners',
          investorType: InvestorType.institutional,
          lifecycleStatus: InvestorLifecycleStatus.active,
          kycStatus: KycStatus.underReview,
          riskLevel: RiskLevel.conservative,
          nationality: 'Nigerian',
          aum: 980000000,
          totalCommitted: 450000000,
          aiSummary:
              'Institutional buyer seeking multi-unit tranches with audited yield packs.',
          tags: ['institutional', 'platinum'],
          preferredLocations: ['Lekki', 'Port Harcourt', 'Abuja'],
        ),
        ImpInvestor(
          id: 'imp-3',
          investorCode: 'INV-FT-003',
          fullName: 'Tunde Bakare',
          email: 'tunde.bakare@example.com',
          phone: '+2348021000003',
          investorType: InvestorType.firstTime,
          lifecycleStatus: InvestorLifecycleStatus.onboarding,
          kycStatus: KycStatus.awaitingDocuments,
          riskLevel: RiskLevel.moderate,
          nationality: 'Nigerian',
          aum: 25000000,
          totalCommitted: 15000000,
          aiSummary:
              'First-time investor mid-KYC. Guide with smaller tickets and clear estimate disclaimers.',
          tags: ['first_time'],
          preferredLocations: ['Abuja', 'Lekki'],
        ),
      ];

  static List<ImpOpportunity> _opportunities() => const [
        ImpOpportunity(
          id: 'opp-1',
          code: 'OPP-VC-OPEN',
          title: 'Victoria Crest Unit 4 — Capital Raise',
          description:
              'Open raise for Victoria Crest residential unit targeting yield-oriented HNWI allocations.',
          status: OpportunityStatus.open,
          targetRaise: 250000000,
          amountRaised: 96000000,
          minTicket: 25000000,
          maxTicket: 100000000,
          projectedReturnPct: 13.5,
          returnDisclaimer: kProjectedReturnDisclaimer,
          riskLevel: RiskLevel.moderate,
        ),
        ImpOpportunity(
          id: 'opp-2',
          code: 'OPP-HV-FUNDED',
          title: 'Harbour View Multi-Unit Tranche',
          description:
              'Fully funded institutional tranche with scheduled distributions underway.',
          status: OpportunityStatus.fullyFunded,
          targetRaise: 500000000,
          amountRaised: 500000000,
          minTicket: 100000000,
          maxTicket: 250000000,
          projectedReturnPct: 11.25,
          returnDisclaimer: kProjectedReturnDisclaimer,
          riskLevel: RiskLevel.conservative,
        ),
      ];

  static List<ImpCommitment> _commitments(DateTime now) => [
        ImpCommitment(
          id: 'cmt-1',
          investorId: 'imp-1',
          opportunityId: 'opp-1',
          amount: 75000000,
          investorName: 'Folake Adeyemi',
          opportunityTitle: 'Victoria Crest Unit 4 — Capital Raise',
          status: 'confirmed',
          committedAt: now.subtract(const Duration(days: 7)),
        ),
        ImpCommitment(
          id: 'cmt-2',
          investorId: 'imp-2',
          opportunityId: 'opp-2',
          amount: 250000000,
          investorName: 'Meridian Equity Partners',
          opportunityTitle: 'Harbour View Multi-Unit Tranche',
          status: 'funded',
          committedAt: now.subtract(const Duration(days: 90)),
        ),
        ImpCommitment(
          id: 'cmt-3',
          investorId: 'imp-3',
          opportunityId: 'opp-1',
          amount: 15000000,
          investorName: 'Tunde Bakare',
          opportunityTitle: 'Victoria Crest Unit 4 — Capital Raise',
          status: 'reserved',
          committedAt: now.subtract(const Duration(days: 2)),
        ),
      ];

  static List<ImpHolding> _holdings() => const [
        ImpHolding(
          id: 'h-1',
          portfolioId: 'pf-1',
          label: 'Victoria Crest allocation',
          opportunityId: 'opp-1',
          investorId: 'imp-1',
          investorName: 'Folake Adeyemi',
          costBasis: 70000000,
          currentValue: 78000000,
        ),
        ImpHolding(
          id: 'h-2',
          portfolioId: 'pf-2',
          label: 'Harbour View tranche A',
          opportunityId: 'opp-2',
          investorId: 'imp-2',
          investorName: 'Meridian Equity Partners',
          costBasis: 250000000,
          currentValue: 275000000,
        ),
      ];

  static List<ImpDistribution> _distributions(DateTime now) => [
        ImpDistribution(
          id: 'dist-1',
          investorId: 'imp-2',
          amount: 12500000,
          investorName: 'Meridian Equity Partners',
          opportunityTitle: 'Harbour View Multi-Unit Tranche',
          status: DistributionStatus.paid,
          scheduledAt: now.subtract(const Duration(days: 20)),
          paidAt: now.subtract(const Duration(days: 18)),
          reference: 'DIST-HV-001',
        ),
        ImpDistribution(
          id: 'dist-2',
          investorId: 'imp-1',
          amount: 4800000,
          investorName: 'Folake Adeyemi',
          opportunityTitle: 'Victoria Crest Unit 4 — Capital Raise',
          status: DistributionStatus.scheduled,
          scheduledAt: now.add(const Duration(days: 12)),
          reference: 'DIST-VC-002',
        ),
        ImpDistribution(
          id: 'dist-3',
          investorId: 'imp-2',
          amount: 12500000,
          investorName: 'Meridian Equity Partners',
          opportunityTitle: 'Harbour View Multi-Unit Tranche',
          status: DistributionStatus.scheduled,
          scheduledAt: now.add(const Duration(days: 25)),
          reference: 'DIST-HV-002',
        ),
      ];

  static List<ImpWallet> _wallets() => const [
        ImpWallet(
          id: 'w-1',
          investorId: 'imp-1',
          investorName: 'Folake Adeyemi',
          availableBalance: 18500000,
          pendingBalance: 2500000,
          reservedBalance: 5000000,
        ),
        ImpWallet(
          id: 'w-2',
          investorId: 'imp-2',
          investorName: 'Meridian Equity Partners',
          availableBalance: 42000000,
          reservedBalance: 10000000,
        ),
        ImpWallet(
          id: 'w-3',
          investorId: 'imp-3',
          investorName: 'Tunde Bakare',
          availableBalance: 3200000,
          pendingBalance: 1500000,
        ),
      ];

  static List<ImpActivity> _activities(DateTime now) => [
        ImpActivity(
          id: 'act-1',
          investorId: 'imp-1',
          eventType: 'commitment',
          title: 'VIP commitment confirmed',
          description: '₦75M reserved on Victoria Crest raise',
          investorName: 'Folake Adeyemi',
          occurredAt: now.subtract(const Duration(days: 7)),
        ),
        ImpActivity(
          id: 'act-2',
          investorId: 'imp-2',
          eventType: 'distribution',
          title: 'Dividend paid',
          description: 'Harbour View Q1 dividend settled',
          investorName: 'Meridian Equity Partners',
          occurredAt: now.subtract(const Duration(days: 18)),
        ),
        ImpActivity(
          id: 'act-3',
          investorId: 'imp-3',
          eventType: 'kyc',
          title: 'KYC documents requested',
          description: 'Awaiting utility bill and BVN proof',
          investorName: 'Tunde Bakare',
          occurredAt: now.subtract(const Duration(days: 1)),
        ),
      ];

  static List<ImpAlert> _alerts(DateTime now) => [
        ImpAlert(
          id: 'al-1',
          investorId: 'imp-3',
          severity: AlertSeverity.high,
          title: 'KYC stalled — first-time investor',
          body:
              'Tunde Bakare awaiting documents for 48h+. Assign onboarding specialist.',
          createdAt: now.subtract(const Duration(hours: 6)),
        ),
        ImpAlert(
          id: 'al-2',
          investorId: 'imp-1',
          severity: AlertSeverity.medium,
          title: 'Capital raise pacing',
          body:
              'Victoria Crest open raise at ~38% of target. Engage VIP network this week.',
          createdAt: now.subtract(const Duration(hours: 2)),
        ),
        ImpAlert(
          id: 'al-3',
          investorId: 'imp-2',
          severity: AlertSeverity.info,
          title: 'Institutional KYC review queued',
          body: 'Meridian Equity under_review — finance pack attached.',
          status: 'acknowledged',
          createdAt: now.subtract(const Duration(days: 1)),
        ),
      ];
}
