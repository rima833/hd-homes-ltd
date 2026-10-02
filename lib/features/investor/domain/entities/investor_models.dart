import 'package:intl/intl.dart';

/// Investor portal domain models — Volume 4 Investor Portal.

class InvestorRecord {
  const InvestorRecord({
    required this.id,
    this.userId,
    this.investorCode,
    this.fullName,
    this.email,
    this.phone,
    this.kycStatus = 'pending',
    this.lifecycleStatus = 'prospect',
    this.aum = 0,
    this.totalCommitted = 0,
    this.preferredCurrency = 'NGN',
    this.status = 'active',
    this.referralCode,
  });

  factory InvestorRecord.fromJson(Map<String, dynamic> json) {
    final metaRaw = json['metadata'];
    final metadata = metaRaw is Map
        ? Map<String, dynamic>.from(metaRaw)
        : const <String, dynamic>{};
    final code = '${metadata['referral_code'] ?? ''}'.trim();
    return InvestorRecord(
        id: json['id'] as String,
        userId: json['user_id'] as String?,
        investorCode: json['investor_code'] as String?,
        fullName: json['full_name'] as String?,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        kycStatus: json['kyc_status'] as String? ?? 'pending',
        lifecycleStatus: json['lifecycle_status'] as String? ?? 'prospect',
        aum: (json['aum'] as num?)?.toDouble() ?? 0,
        totalCommitted: (json['total_committed'] as num?)?.toDouble() ?? 0,
        preferredCurrency: json['preferred_currency'] as String? ?? 'NGN',
        status: json['status'] as String? ?? 'active',
        referralCode: code.isEmpty ? null : code,
      );
  }

  final String id;
  final String? userId;
  final String? investorCode;
  final String? fullName;
  final String? email;
  final String? phone;
  final String kycStatus;
  final String lifecycleStatus;
  final double aum;
  final double totalCommitted;
  final String preferredCurrency;
  final String status;
  /// Shareable code set by admin. Empty until staff publishes one.
  final String? referralCode;

  String get formattedAum =>
      NumberFormat.currency(symbol: '₦', decimalDigits: 0).format(aum);

  String get formattedCommitted =>
      NumberFormat.currency(symbol: '₦', decimalDigits: 0).format(totalCommitted);
}

class InvestorHolding {
  const InvestorHolding({
    required this.id,
    required this.portfolioId,
    this.propertyId,
    this.opportunityId,
    required this.label,
    this.units = 1,
    this.costBasis = 0,
    this.currentValue = 0,
    this.currency = 'NGN',
    this.acquiredAt,
    this.imageUrl,
    this.location,
    this.slug,
    this.developmentName,
    this.buildingLabel,
    this.unitLabel,
    this.ownershipPct,
    this.paymentStatus,
    this.constructionStatus,
    this.expectedCompletion,
    this.metadata = const {},
  });

  factory InvestorHolding.fromJson(Map<String, dynamic> json) {
    final property = json['properties'] as Map<String, dynamic>?;
    final location = property?['property_locations'] as List?;
    final loc = location != null && location.isNotEmpty
        ? Map<String, dynamic>.from(location.first as Map)
        : null;
    final images = property?['property_images'] as List?;
    String? cover;
    if (images != null) {
      for (final img in images) {
        final m = Map<String, dynamic>.from(img as Map);
        if (m['is_cover'] == true) {
          cover = m['url'] as String?;
          break;
        }
      }
      cover ??= images.isNotEmpty
          ? Map<String, dynamic>.from(images.first as Map)['url'] as String?
          : null;
    }

    final label = property?['title'] as String? ??
        json['label'] as String? ??
        'Holding';
    final metaRaw = json['metadata'];
    final metadata = metaRaw is Map
        ? Map<String, dynamic>.from(metaRaw)
        : <String, dynamic>{};

    final parsed = _parseHoldingLabel(label);
    final ownership = (metadata['ownership_pct'] as num?)?.toDouble() ??
        (metadata['ownership_percent'] as num?)?.toDouble();

    DateTime? expected;
    final expectedRaw = metadata['expected_completion'] ??
        metadata['expected_completion_at'];
    if (expectedRaw is String) {
      expected = DateTime.tryParse(expectedRaw);
    }

    return InvestorHolding(
      id: json['id'] as String,
      portfolioId: json['portfolio_id'] as String,
      propertyId: json['property_id'] as String?,
      opportunityId: json['opportunity_id'] as String?,
      label: label,
      units: (json['units'] as num?)?.toDouble() ?? 1,
      costBasis: (json['cost_basis'] as num?)?.toDouble() ?? 0,
      currentValue: (json['current_value'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'NGN',
      acquiredAt: json['acquired_at'] != null
          ? DateTime.tryParse(json['acquired_at'] as String)
          : null,
      imageUrl: cover,
      location: loc != null
          ? [loc['city'], loc['state']].whereType<String>().join(', ')
          : null,
      slug: property?['slug'] as String?,
      developmentName: metadata['development'] as String? ??
          metadata['development_name'] as String? ??
          parsed.$1,
      buildingLabel: metadata['building'] as String? ??
          metadata['building_label'] as String? ??
          parsed.$2,
      unitLabel: metadata['unit'] as String? ??
          metadata['unit_label'] as String? ??
          parsed.$3,
      ownershipPct: ownership,
      paymentStatus: metadata['payment_status'] as String?,
      constructionStatus: metadata['construction_status'] as String? ??
          metadata['construction_stage'] as String?,
      expectedCompletion: expected,
      metadata: metadata,
    );
  }

  /// Parses labels like `Victoria Crest — Building 12 Unit 4`.
  static (String?, String?, String?) _parseHoldingLabel(String label) {
    final parts = label.split(RegExp(r'\s*[—–-]\s*'));
    if (parts.length < 2) return (label.trim().isEmpty ? null : label.trim(), null, null);
    final development = parts.first.trim();
    final rest = parts.sublist(1).join(' — ').trim();
    final buildingMatch =
        RegExp(r'Building\s+([A-Za-z0-9-]+)', caseSensitive: false)
            .firstMatch(rest);
    final unitMatch =
        RegExp(r'Unit\s+([A-Za-z0-9-]+)', caseSensitive: false).firstMatch(rest);
    return (
      development.isEmpty ? null : development,
      buildingMatch?.group(1) != null ? 'Building ${buildingMatch!.group(1)}' : null,
      unitMatch?.group(1) != null ? 'Unit ${unitMatch!.group(1)}' : null,
    );
  }

  final String id;
  final String portfolioId;
  final String? propertyId;
  final String? opportunityId;
  final String label;
  final double units;
  final double costBasis;
  final double currentValue;
  final String currency;
  final DateTime? acquiredAt;
  final String? imageUrl;
  final String? location;
  final String? slug;
  final String? developmentName;
  final String? buildingLabel;
  final String? unitLabel;
  final double? ownershipPct;
  final String? paymentStatus;
  final String? constructionStatus;
  final DateTime? expectedCompletion;
  final Map<String, dynamic> metadata;

  double get gainLoss => currentValue - costBasis;

  double get gainLossPct =>
      costBasis > 0 ? ((currentValue - costBasis) / costBasis) * 100 : 0;

  String get formattedCurrentValue =>
      NumberFormat.currency(symbol: '₦', decimalDigits: 0).format(currentValue);

  String get formattedCostBasis =>
      NumberFormat.currency(symbol: '₦', decimalDigits: 0).format(costBasis);

  String get subtitle {
    final bits = <String>[
      if (buildingLabel != null) buildingLabel!,
      if (unitLabel != null) unitLabel!,
      if (location != null && location!.isNotEmpty) location!,
    ];
    if (bits.isNotEmpty) return bits.join(' · ');
    return '${units.toStringAsFixed(units == units.roundToDouble() ? 0 : 1)} units';
  }
}

/// Full investment detail payload for a single holding (Phase 5).
class InvestorHoldingDetail {
  const InvestorHoldingDetail({
    required this.holding,
    this.distributions = const [],
    this.documents = const [],
    this.paymentIntents = const [],
    this.activity = const [],
    this.construction,
  });

  final InvestorHolding holding;
  final List<InvestorDistribution> distributions;
  final List<InvestorDocument> documents;
  final List<InvestorPaymentIntent> paymentIntents;
  final List<InvestorActivity> activity;
  final InvestorConstructionBundle? construction;

  double get distributionsPaid => distributions
      .where((d) => d.status == 'paid')
      .fold<double>(0, (s, d) => s + d.amount);

  double get distributionsPending => distributions
      .where((d) => d.status == 'scheduled' || d.status == 'processing')
      .fold<double>(0, (s, d) => s + d.amount);

  double get outstandingPayments => paymentIntents
      .where(
        (i) =>
            i.status == 'pending' ||
            i.status == 'awaiting_confirmation' ||
            i.status == 'submitted',
      )
      .fold<double>(0, (s, i) => s + i.amount);

  /// Book investment amount (cost basis from Admin-assigned holding).
  double get amountInvested => holding.costBasis;

  /// Amount still open on related payment intents (not inventing installments).
  double get amountOutstanding => outstandingPayments;
}

class InvestorDistribution {
  const InvestorDistribution({
    required this.id,
    required this.amount,
    this.currency = 'NGN',
    this.status = 'scheduled',
    this.distributionType = 'dividend',
    this.scheduledAt,
    this.paidAt,
    this.reference,
    this.notes,
    this.portfolioId,
    this.opportunityId,
    this.metadata = const {},
  });

  factory InvestorDistribution.fromJson(Map<String, dynamic> json) {
    final metaRaw = json['metadata'];
    return InvestorDistribution(
      id: json['id'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'NGN',
      status: json['status'] as String? ?? 'scheduled',
      distributionType: json['distribution_type'] as String? ?? 'dividend',
      scheduledAt: json['scheduled_at'] != null
          ? DateTime.tryParse(json['scheduled_at'] as String)
          : null,
      paidAt: json['paid_at'] != null
          ? DateTime.tryParse(json['paid_at'] as String)
          : null,
      reference: json['reference'] as String?,
      notes: json['notes'] as String?,
      portfolioId: json['portfolio_id'] as String?,
      opportunityId: json['opportunity_id'] as String?,
      metadata: metaRaw is Map
          ? Map<String, dynamic>.from(metaRaw)
          : const {},
    );
  }

  final String id;
  final double amount;
  final String currency;
  final String status;
  final String distributionType;
  final DateTime? scheduledAt;
  final DateTime? paidAt;
  final String? reference;
  final String? notes;
  final String? portfolioId;
  final String? opportunityId;
  final Map<String, dynamic> metadata;

  String get formattedAmount =>
      NumberFormat.currency(symbol: '₦', decimalDigits: 0).format(amount);
}

class InvestorWallet {
  const InvestorWallet({
    required this.id,
    required this.investorId,
    this.currency = 'NGN',
    this.availableBalance = 0,
    this.pendingBalance = 0,
    this.reservedBalance = 0,
  });

  factory InvestorWallet.fromJson(Map<String, dynamic> json) => InvestorWallet(
        id: json['id'] as String,
        investorId: json['investor_id'] as String,
        currency: json['currency'] as String? ?? 'NGN',
        availableBalance: (json['available_balance'] as num?)?.toDouble() ?? 0,
        pendingBalance: (json['pending_balance'] as num?)?.toDouble() ?? 0,
        reservedBalance: (json['reserved_balance'] as num?)?.toDouble() ?? 0,
      );

  final String id;
  final String investorId;
  final String currency;
  final double availableBalance;
  final double pendingBalance;
  final double reservedBalance;

  double get totalBalance =>
      availableBalance + pendingBalance + reservedBalance;

  String get formattedAvailable =>
      NumberFormat.currency(symbol: '₦', decimalDigits: 0).format(availableBalance);

  String get formattedTotal =>
      NumberFormat.currency(symbol: '₦', decimalDigits: 0).format(totalBalance);
}

class InvestorDocument {
  const InvestorDocument({
    required this.id,
    required this.title,
    this.fileUrl,
    this.documentType,
    this.createdAt,
    this.updatedAt,
    this.expiresAt,
    this.version = 1,
    this.isSensitive = false,
    this.metadata = const {},
  });

  factory InvestorDocument.fromJson(Map<String, dynamic> json) {
    final metaRaw = json['metadata'];
    return InvestorDocument(
      id: json['id'] as String,
      title: json['title'] as String,
      fileUrl: json['file_url'] as String?,
      documentType: json['document_type'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'] as String)
          : null,
      version: (json['version'] as num?)?.toInt() ?? 1,
      isSensitive: json['is_sensitive'] as bool? ?? false,
      metadata: metaRaw is Map
          ? Map<String, dynamic>.from(metaRaw)
          : const {},
    );
  }

  final String id;
  final String title;
  final String? fileUrl;
  final String? documentType;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? expiresAt;
  final int version;
  final bool isSensitive;
  final Map<String, dynamic> metadata;

  bool get hasFile => (fileUrl ?? '').trim().isNotEmpty;

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());

  String? get propertyId =>
      metadata['property_id'] as String? ?? metadata['propertyId'] as String?;

  String? get holdingId =>
      metadata['holding_id'] as String? ?? metadata['holdingId'] as String?;

  String? get sourceDocumentId =>
      metadata['source_document_id'] as String?;

  String? get mimeType => metadata['mime_type'] as String?;

  String? get fileName => metadata['file_name'] as String?;

  String get deliveryKind {
    final tagged = metadata['delivery'] as String?;
    if (tagged != null && tagged.isNotEmpty) return tagged;
    final url = (fileUrl ?? '').trim();
    if (url.contains('res.cloudinary.com')) return 'cloudinary';
    if (url.startsWith('http://') || url.startsWith('https://')) return 'https';
    if (url.startsWith('storage://')) return 'storage';
    return url.isEmpty ? 'none' : 'path';
  }

  List<InvestorDocumentVersion> get versionHistory {
    final raw = metadata['version_history'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (e) => InvestorDocumentVersion.fromJson(
            Map<String, dynamic>.from(e),
          ),
        )
        .toList()
      ..sort((a, b) => b.version.compareTo(a.version));
  }

  bool get hasPriorVersions => versionHistory.isNotEmpty;
}

class InvestorDocumentVersion {
  const InvestorDocumentVersion({
    required this.version,
    required this.fileUrl,
    this.replacedAt,
  });

  factory InvestorDocumentVersion.fromJson(Map<String, dynamic> json) =>
      InvestorDocumentVersion(
        version: (json['version'] as num?)?.toInt() ?? 1,
        fileUrl: json['file_url'] as String? ?? '',
        replacedAt: json['replaced_at'] != null
            ? DateTime.tryParse(json['replaced_at'] as String)
            : null,
      );

  final int version;
  final String fileUrl;
  final DateTime? replacedAt;
}

class InvestorReport {
  const InvestorReport({
    required this.id,
    required this.title,
    this.reportType,
    this.fileUrl,
    this.periodLabel,
    this.generatedAt,
  });

  factory InvestorReport.fromJson(Map<String, dynamic> json) => InvestorReport(
        id: json['id'] as String,
        title: json['title'] as String,
        reportType: json['report_type'] as String?,
        fileUrl: json['file_url'] as String?,
        periodLabel: json['period_label'] as String?,
        generatedAt: json['generated_at'] != null
            ? DateTime.tryParse(json['generated_at'] as String)
            : null,
      );

  final String id;
  final String title;
  final String? reportType;
  final String? fileUrl;
  final String? periodLabel;
  final DateTime? generatedAt;
}

class InvestorStatement {
  const InvestorStatement({
    required this.id,
    required this.periodLabel,
    this.periodStart,
    this.periodEnd,
    this.fileUrl,
    this.openingBalance,
    this.closingBalance,
    this.currency = 'NGN',
    this.createdAt,
  });

  factory InvestorStatement.fromJson(Map<String, dynamic> json) =>
      InvestorStatement(
        id: json['id'] as String,
        periodLabel: json['period_label'] as String,
        periodStart: json['period_start'] != null
            ? DateTime.tryParse(json['period_start'] as String)
            : null,
        periodEnd: json['period_end'] != null
            ? DateTime.tryParse(json['period_end'] as String)
            : null,
        fileUrl: json['file_url'] as String?,
        openingBalance: (json['opening_balance'] as num?)?.toDouble(),
        closingBalance: (json['closing_balance'] as num?)?.toDouble(),
        currency: json['currency'] as String? ?? 'NGN',
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
      );

  final String id;
  final String periodLabel;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final String? fileUrl;
  final double? openingBalance;
  final double? closingBalance;
  final String currency;
  final DateTime? createdAt;
}

class InvestorPerformance {
  const InvestorPerformance({
    required this.id,
    this.nav = 0,
    this.twrPct,
    this.irrPct,
    this.yieldPct,
    this.asOfDate,
    this.currency = 'NGN',
  });

  factory InvestorPerformance.fromJson(Map<String, dynamic> json) =>
      InvestorPerformance(
        id: json['id'] as String? ?? '',
        nav: (json['nav'] as num?)?.toDouble() ?? 0,
        twrPct: (json['twr_pct'] as num?)?.toDouble(),
        irrPct: (json['irr_pct'] as num?)?.toDouble(),
        yieldPct: (json['yield_pct'] as num?)?.toDouble(),
        asOfDate: json['as_of_date'] != null
            ? DateTime.tryParse(json['as_of_date'] as String)
            : null,
        currency: json['currency'] as String? ?? 'NGN',
      );

  final String id;
  final double nav;
  final double? twrPct;
  final double? irrPct;
  final double? yieldPct;
  final DateTime? asOfDate;
  final String currency;

  String get formattedNav =>
      NumberFormat.currency(symbol: '₦', decimalDigits: 0).format(nav);
}

/// Trusted backend analytics aggregate (`investor_analytics_snapshot`).
class InvestorAnalyticsSnapshot {
  const InvestorAnalyticsSnapshot({
    required this.investorId,
    this.months,
    this.since,
    this.portfolioValue = 0,
    this.costBasis = 0,
    this.unrealizedPnl = 0,
    this.roiPct = 0,
    this.distributionsPaid = 0,
    this.distributionsPending = 0,
    this.totalReturnPct = 0,
    this.latest,
    this.series = const [],
    this.generatedAt,
  });

  factory InvestorAnalyticsSnapshot.fromJson(Map<String, dynamic> json) {
    final latestRaw = json['latest'];
    final seriesRaw = json['series'];
    return InvestorAnalyticsSnapshot(
      investorId: json['investor_id'] as String? ?? '',
      months: (json['months'] as num?)?.toInt(),
      since: json['since'] != null
          ? DateTime.tryParse(json['since'] as String)
          : null,
      portfolioValue: (json['portfolio_value'] as num?)?.toDouble() ?? 0,
      costBasis: (json['cost_basis'] as num?)?.toDouble() ?? 0,
      unrealizedPnl: (json['unrealized_pnl'] as num?)?.toDouble() ?? 0,
      roiPct: (json['roi_pct'] as num?)?.toDouble() ?? 0,
      distributionsPaid:
          (json['distributions_paid'] as num?)?.toDouble() ?? 0,
      distributionsPending:
          (json['distributions_pending'] as num?)?.toDouble() ?? 0,
      totalReturnPct: (json['total_return_pct'] as num?)?.toDouble() ?? 0,
      latest: latestRaw is Map && latestRaw.isNotEmpty
          ? InvestorPerformance.fromJson(Map<String, dynamic>.from(latestRaw))
          : null,
      series: seriesRaw is List
          ? seriesRaw
              .whereType<Map>()
              .map(
                (e) => InvestorPerformance.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList()
          : const [],
      generatedAt: json['generated_at'] != null
          ? DateTime.tryParse(json['generated_at'] as String)
          : null,
    );
  }

  final String investorId;
  final int? months;
  final DateTime? since;
  final double portfolioValue;
  final double costBasis;
  final double unrealizedPnl;
  final double roiPct;
  final double distributionsPaid;
  final double distributionsPending;
  final double totalReturnPct;
  final InvestorPerformance? latest;
  final List<InvestorPerformance> series;
  final DateTime? generatedAt;

  bool get hasPerformance => latest != null || series.isNotEmpty;
}

class InvestorActivity {
  const InvestorActivity({
    required this.id,
    required this.eventType,
    required this.title,
    this.description,
    required this.occurredAt,
  });

  factory InvestorActivity.fromJson(Map<String, dynamic> json) =>
      InvestorActivity(
        id: json['id'] as String,
        eventType: json['event_type'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        occurredAt: DateTime.parse(json['occurred_at'] as String),
      );

  final String id;
  final String eventType;
  final String title;
  final String? description;
  final DateTime occurredAt;
}

class InvestorPortalNotification {
  const InvestorPortalNotification({
    required this.id,
    required this.title,
    this.body,
    this.channel = 'in_app',
    this.isRead = false,
    this.sentAt,
    this.createdAt,
    this.category = 'general',
    this.actionRoute,
    this.metadata = const {},
  });

  factory InvestorPortalNotification.fromJson(Map<String, dynamic> json) {
    final meta = json['metadata'] is Map
        ? Map<String, dynamic>.from(json['metadata'] as Map)
        : <String, dynamic>{};
    final category = (meta['category'] as String?)?.trim().toLowerCase() ??
        (json['category'] as String?)?.trim().toLowerCase() ??
        'general';
    final route = (meta['route'] as String?)?.trim() ??
        (meta['action_url'] as String?)?.trim() ??
        (json['action_url'] as String?)?.trim();
    return InvestorPortalNotification(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String?,
      channel: json['channel'] as String? ?? 'in_app',
      isRead: json['is_read'] as bool? ?? false,
      sentAt: json['sent_at'] != null
          ? DateTime.tryParse(json['sent_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      category: category.isEmpty ? 'general' : category,
      actionRoute: route != null && route.isNotEmpty ? route : null,
      metadata: meta,
    );
  }

  final String id;
  final String title;
  final String? body;
  final String channel;
  final bool isRead;
  final DateTime? sentAt;
  final DateTime? createdAt;
  final String category;
  final String? actionRoute;
  final Map<String, dynamic> metadata;

  String get categoryLabel {
    switch (category) {
      case 'payments':
      case 'distribution':
      case 'dividend':
        return 'Payments';
      case 'construction':
        return 'Construction';
      case 'documents':
      case 'document':
        return 'Documents';
      case 'reports':
      case 'statement':
        return 'Reports';
      case 'kyc':
        return 'KYC';
      case 'announcement':
      case 'announcements':
        return 'Announcement';
      case 'messages':
      case 'message':
      case 'support':
        return 'Messages';
      case 'referrals':
        return 'Referrals';
      case 'portfolio':
      case 'holding':
        return 'Portfolio';
      default:
        return 'General';
    }
  }

  /// Portal deep link if present and safe for in-app navigation.
  String? get portalRoute {
    final r = actionRoute;
    if (r == null || r.isEmpty) return null;
    if (r.startsWith('/investor')) return r;
    return null;
  }
}

class InvestorConversation {
  const InvestorConversation({
    required this.id,
    required this.subject,
    required this.category,
    this.investorId,
    this.lastMessageAt,
    this.lastMessagePreview,
    this.investorDisplayName,
    this.status = 'open',
    this.unreadCount = 0,
    this.staffTypingAt,
    this.investorTypingAt,
  });

  factory InvestorConversation.fromJson(Map<String, dynamic> json) {
    String? displayName;
    final investors = json['investors'];
    if (investors is Map) {
      final code = (investors['investor_code'] as String?)?.trim();
      final profiles = investors['profiles'];
      if (profiles is Map) {
        final preferred = (profiles['preferred_name'] as String?)?.trim();
        if (preferred != null && preferred.isNotEmpty) {
          displayName = preferred;
        } else {
          final f = (profiles['first_name'] as String?)?.trim() ?? '';
          final l = (profiles['last_name'] as String?)?.trim() ?? '';
          final joined = '$f $l'.trim();
          if (joined.isNotEmpty) displayName = joined;
        }
      }
      displayName ??= code;
    }
    final meta = json['metadata'];
    DateTime? staffTypingAt;
    DateTime? investorTypingAt;
    if (meta is Map) {
      final staffRaw = meta['staff_typing_at'];
      if (staffRaw != null && staffRaw.toString() != 'null') {
        staffTypingAt = DateTime.tryParse(staffRaw.toString());
      }
      final invRaw = meta['investor_typing_at'];
      if (invRaw != null && invRaw.toString() != 'null') {
        investorTypingAt = DateTime.tryParse(invRaw.toString());
      }
    }
    return InvestorConversation(
      id: json['id'] as String,
      subject: json['subject'] as String,
      category: json['category'] as String? ?? 'support',
      investorId: json['investor_id'] as String?,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.tryParse(json['last_message_at'] as String)
          : null,
      lastMessagePreview: json['last_message_preview'] as String?,
      investorDisplayName: displayName,
      status: json['status'] as String? ?? 'open',
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      staffTypingAt: staffTypingAt,
      investorTypingAt: investorTypingAt,
    );
  }

  final String id;
  final String subject;
  final String category;
  final String? investorId;
  final DateTime? lastMessageAt;
  final String? lastMessagePreview;
  final String? investorDisplayName;
  final String status;
  final int unreadCount;
  final DateTime? staffTypingAt;
  final DateTime? investorTypingAt;

  bool get investorIsTyping {
    final at = investorTypingAt;
    if (at == null) return false;
    return DateTime.now().difference(at).inSeconds < 8;
  }

  bool get staffIsTyping {
    final at = staffTypingAt;
    if (at == null) return false;
    return DateTime.now().difference(at).inSeconds < 8;
  }
}

class InvestorMessage {
  const InvestorMessage({
    required this.id,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.readAt,
    this.isMine = false,
    this.attachments = const [],
    this.senderName,
  });

  factory InvestorMessage.fromJson(Map<String, dynamic> json, {String? userId}) {
    final attachmentsRaw = json['attachments'];
    return InvestorMessage(
      id: json['id'] as String,
      senderId: json['sender_id'] as String? ?? '',
      body: json['body'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      readAt: json['read_at'] != null
          ? DateTime.tryParse(json['read_at'] as String)
          : null,
      isMine: userId != null && json['sender_id'] == userId,
      attachments: _parseMessageAttachments(attachmentsRaw),
      senderName: json['sender_name'] as String?,
    );
  }

  final String id;
  final String senderId;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;
  final bool isMine;
  final List<InvestorMessageAttachment> attachments;
  final String? senderName;
}

class InvestorMessageAttachment {
  const InvestorMessageAttachment({
    required this.url,
    this.name,
    this.mimeType,
    this.mediaId,
  });

  factory InvestorMessageAttachment.fromJson(Map<String, dynamic> json) =>
      InvestorMessageAttachment(
        url: json['url'] as String? ??
            json['secure_url'] as String? ??
            json['file_url'] as String? ??
            '',
        name: json['name'] as String? ?? json['file_name'] as String?,
        mimeType: json['mime_type'] as String? ?? json['content_type'] as String?,
        mediaId: json['media_id'] as String? ?? json['public_id'] as String?,
      );

  final String url;
  final String? name;
  final String? mimeType;
  final String? mediaId;

  Map<String, dynamic> toJson() => {
        'url': url,
        if (name != null) 'name': name,
        if (mimeType != null) 'mime_type': mimeType,
        if (mediaId != null) 'media_id': mediaId,
        'secure_url': url,
      };
}

List<InvestorMessageAttachment> _parseMessageAttachments(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((e) => InvestorMessageAttachment.fromJson(Map<String, dynamic>.from(e)))
      .where((a) => a.url.trim().isNotEmpty)
      .toList();
}

class InvestorSupportTicket {
  const InvestorSupportTicket({
    required this.id,
    required this.subject,
    this.description,
    this.status = 'open',
    this.priority = 'normal',
    this.ticketNumber,
    this.channel,
    this.createdAt,
    this.updatedAt,
  });

  factory InvestorSupportTicket.fromJson(Map<String, dynamic> json) =>
      InvestorSupportTicket(
        id: json['id'] as String,
        subject: json['subject'] as String? ?? 'Support request',
        description: json['description'] as String?,
        status: json['status'] as String? ?? 'open',
        priority: json['priority'] as String? ?? 'normal',
        ticketNumber: json['ticket_number'] as String?,
        channel: json['channel'] as String?,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
        updatedAt: json['updated_at'] != null
            ? DateTime.tryParse(json['updated_at'] as String)
            : null,
      );

  final String id;
  final String subject;
  final String? description;
  final String status;
  final String priority;
  final String? ticketNumber;
  final String? channel;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isClosed => status == 'closed' || status == 'resolved';
}

class InvestorTicketMessage {
  const InvestorTicketMessage({
    required this.id,
    required this.ticketId,
    required this.message,
    this.senderId,
    this.senderName,
    this.senderType = 'customer',
    this.createdAt,
    this.isMine = false,
    this.attachments = const [],
  });

  factory InvestorTicketMessage.fromJson(
    Map<String, dynamic> json, {
    String? userId,
  }) =>
      InvestorTicketMessage(
        id: json['id'] as String,
        ticketId: json['ticket_id'] as String,
        message: json['message'] as String? ?? '',
        senderId: json['sender_id'] as String?,
        senderName: json['sender_name'] as String?,
        senderType: json['sender_type'] as String? ?? 'customer',
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
        isMine: userId != null && json['sender_id'] == userId,
        attachments: _parseMessageAttachments(json['attachments']),
      );

  final String id;
  final String ticketId;
  final String message;
  final String? senderId;
  final String? senderName;
  final String senderType;
  final DateTime? createdAt;
  final bool isMine;
  final List<InvestorMessageAttachment> attachments;
}

class InvestorReferralSummary {
  const InvestorReferralSummary({
    this.referralCode = '',
    this.pendingEarnings = 0,
    this.paidEarnings = 0,
    this.commissions = const [],
    this.programRules = const InvestorReferralProgramRules(),
  });

  final String referralCode;
  final double pendingEarnings;
  final double paidEarnings;
  final List<InvestorReferralCommission> commissions;
  final InvestorReferralProgramRules programRules;

  double get totalEarnings => pendingEarnings + paidEarnings;

  int get successfulReferrals => commissions
      .where((c) => c.status == 'paid' || c.status == 'completed')
      .length;
}

/// Static program copy shown in the investor referrals hub (admin awards commissions).
class InvestorReferralProgramRules {
  const InvestorReferralProgramRules({
    this.headline = 'Earn when friends invest',
    this.rewardLabel = 'Commission on funded commitments',
    this.steps = const [
      'Share your unique referral code with fellow investors.',
      'They invest with HD Homes using your code at funding.',
      'Finance confirms the commitment — your commission appears here live.',
      'Paid commissions settle to your investor wallet per program rules.',
    ],
    this.notes =
        'Commissions are awarded by HD Homes after funded commitments clear. '
        'Rates and eligibility are set by the investment team — investors cannot self-award rewards.',
  });

  final String headline;
  final String rewardLabel;
  final List<String> steps;
  final String notes;
}

class InvestorReferralCommission {
  const InvestorReferralCommission({
    required this.id,
    required this.amount,
    this.referralCode,
    this.status = 'pending',
    this.paidAt,
    this.createdAt,
    this.currency = 'NGN',
  });

  factory InvestorReferralCommission.fromJson(Map<String, dynamic> json) =>
      InvestorReferralCommission(
        id: json['id'] as String,
        amount: (json['commission_amount'] as num).toDouble(),
        referralCode: json['referral_code'] as String?,
        status: json['status'] as String? ?? 'pending',
        paidAt: json['paid_at'] != null
            ? DateTime.tryParse(json['paid_at'] as String)
            : null,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
        currency: json['currency'] as String? ?? 'NGN',
      );

  final String id;
  final double amount;
  final String? referralCode;
  final String status;
  final DateTime? paidAt;
  final DateTime? createdAt;
  final String currency;

  String get formattedAmount =>
      NumberFormat.currency(symbol: '₦', decimalDigits: 0).format(amount);
}

class InvestorKycBundle {
  const InvestorKycBundle({
    this.kycStatus = 'pending',
    this.reviews = const [],
    this.sourceOfFunds,
    this.riskProfile,
    this.investmentSource,
  });

  final String kycStatus;
  final List<InvestorKycReview> reviews;
  final String? sourceOfFunds;
  final String? riskProfile;
  final String? investmentSource;

  InvestorKycReview? get latestReview =>
      reviews.isEmpty ? null : reviews.first;

  bool get needsAction {
    final s = kycStatus.toLowerCase();
    return s == 'pending' ||
        s == 'awaiting_documents' ||
        s == 'needs_resubmission' ||
        s == 'rejected' ||
        s == 'expired';
  }

  String get statusLabel => kycStatus.replaceAll('_', ' ');
}

class InvestorKycReview {
  const InvestorKycReview({
    required this.id,
    required this.status,
    this.notes,
    this.reviewerId,
    this.reviewedAt,
    this.createdAt,
    this.riskFlags = const [],
  });

  factory InvestorKycReview.fromJson(Map<String, dynamic> json) =>
      InvestorKycReview(
        id: json['id'] as String,
        status: json['status'] as String? ?? 'pending',
        notes: json['notes'] as String?,
        reviewerId: json['reviewer_id'] as String?,
        reviewedAt: json['reviewed_at'] != null
            ? DateTime.tryParse(json['reviewed_at'] as String)
            : null,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
        riskFlags: (json['risk_flags'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
      );

  final String id;
  final String status;
  final String? notes;
  final String? reviewerId;
  final DateTime? reviewedAt;
  final DateTime? createdAt;
  final List<String> riskFlags;

  String get statusLabel => status.replaceAll('_', ' ');
}

class InvestorConstructionPhase {
  const InvestorConstructionPhase({
    required this.id,
    required this.name,
    this.projectId,
    this.status = 'planned',
    this.progressPct = 0,
    this.sortOrder = 0,
    this.startDate,
    this.endDate,
  });

  factory InvestorConstructionPhase.fromJson(Map<String, dynamic> json) =>
      InvestorConstructionPhase(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Phase',
        projectId: json['project_id'] as String?,
        status: json['status'] as String? ?? 'planned',
        progressPct: (json['progress_pct'] as num?)?.toDouble() ?? 0,
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
        startDate: DateTime.tryParse(json['start_date'] as String? ?? ''),
        endDate: DateTime.tryParse(json['end_date'] as String? ?? ''),
      );

  final String id;
  final String name;
  final String? projectId;
  final String status;
  final double progressPct;
  final int sortOrder;
  final DateTime? startDate;
  final DateTime? endDate;

  bool get isComplete =>
      status == 'completed' || status == 'done' || progressPct >= 100;
  bool get isActive =>
      status == 'in_progress' || status == 'active' || status == 'ongoing';
}

class InvestorConstructionProject {
  const InvestorConstructionProject({
    required this.id,
    required this.name,
    this.propertyId,
    this.progressPct = 0,
    this.targetEndDate,
    this.scheduleStatus = 'on_track',
    this.status = 'active',
    this.coverImageUrl,
    this.phases = const [],
    this.milestones = const [],
    this.updates = const [],
  });

  final String id;
  final String name;
  final String? propertyId;
  final double progressPct;
  final DateTime? targetEndDate;
  final String scheduleStatus;
  final String status;
  final String? coverImageUrl;
  final List<InvestorConstructionPhase> phases;
  final List<InvestorMilestone> milestones;
  final List<InvestorConstructionUpdate> updates;

  InvestorConstructionPhase? get currentPhase {
    final active = phases.where((p) => p.isActive).toList();
    if (active.isNotEmpty) return active.first;
    final incomplete = phases.where((p) => !p.isComplete).toList();
    if (incomplete.isNotEmpty) return incomplete.first;
    return phases.isEmpty ? null : phases.last;
  }
}

class InvestorConstructionUpdate {
  const InvestorConstructionUpdate({
    required this.id,
    required this.title,
    this.description,
    this.completionPercent,
    this.updateDate,
    this.projectId,
    this.projectName,
    this.propertyId,
    this.expectedCompletion,
    this.phaseName,
    this.milestoneName,
    this.photos = const [],
    this.videos = const [],
  });

  factory InvestorConstructionUpdate.fromJson(Map<String, dynamic> json) {
    final project = json['projects'] as Map<String, dynamic>?;
    final photosRaw = json['construction_photos'] as List? ?? [];
    final videosRaw = json['construction_videos'] as List? ?? [];
    return InvestorConstructionUpdate(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      completionPercent: (json['completion_percent'] as num?)?.toDouble(),
      updateDate: json['update_date'] != null
          ? DateTime.tryParse(json['update_date'] as String)
          : null,
      projectId: json['project_id'] as String? ?? project?['id'] as String?,
      projectName: project?['name'] as String?,
      propertyId:
          json['property_id'] as String? ?? project?['property_id'] as String?,
      photos: photosRaw
          .map((e) => Map<String, dynamic>.from(e as Map)['url'] as String)
          .whereType<String>()
          .toList(),
      videos: videosRaw
          .map((e) => InvestorConstructionVideo.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList(),
    );
  }

  final String id;
  final String title;
  final String? description;
  final double? completionPercent;
  final DateTime? updateDate;
  final String? projectId;
  final String? projectName;
  final String? propertyId;
  final DateTime? expectedCompletion;
  final String? phaseName;
  final String? milestoneName;
  final List<String> photos;
  final List<InvestorConstructionVideo> videos;
}

class InvestorConstructionVideo {
  const InvestorConstructionVideo({
    required this.id,
    required this.url,
    this.title,
    this.thumbnailUrl,
  });

  factory InvestorConstructionVideo.fromJson(Map<String, dynamic> json) =>
      InvestorConstructionVideo(
        id: json['id'] as String? ?? json['url'] as String,
        url: json['url'] as String? ?? json['file_url'] as String? ?? '',
        title: json['title'] as String? ?? json['caption'] as String?,
        thumbnailUrl: json['thumbnail_url'] as String?,
      );

  final String id;
  final String url;
  final String? title;
  final String? thumbnailUrl;
}

class InvestorMilestone {
  const InvestorMilestone({
    required this.id,
    required this.name,
    this.description,
    this.targetDate,
    this.completedAt,
    this.status = 'pending',
    this.sortOrder = 0,
    this.projectId,
    this.projectName,
  });

  factory InvestorMilestone.fromJson(Map<String, dynamic> json) =>
      InvestorMilestone(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        targetDate: json['target_date'] != null
            ? DateTime.tryParse(json['target_date'] as String)
            : null,
        completedAt: json['completed_at'] != null
            ? DateTime.tryParse(json['completed_at'] as String)
            : null,
        status: json['status'] as String? ?? 'pending',
        sortOrder: json['sort_order'] as int? ?? 0,
        projectId: json['project_id'] as String?,
        projectName: json['project_name'] as String?,
      );

  final String id;
  final String name;
  final String? description;
  final DateTime? targetDate;
  final DateTime? completedAt;
  final String status;
  final int sortOrder;
  final String? projectId;
  final String? projectName;
}

class InvestmentReceivingAccount {
  const InvestmentReceivingAccount({
    required this.id,
    required this.bankName,
    required this.accountName,
    required this.accountNumber,
    this.sortCode,
    this.currency = 'NGN',
    this.instructions,
    this.isPrimary = false,
  });

  factory InvestmentReceivingAccount.fromJson(Map<String, dynamic> json) =>
      InvestmentReceivingAccount(
        id: json['id'] as String,
        bankName: json['bank_name'] as String,
        accountName: json['account_name'] as String,
        accountNumber: json['account_number'] as String,
        sortCode: json['sort_code'] as String?,
        currency: json['currency'] as String? ?? 'NGN',
        instructions: json['instructions'] as String?,
        isPrimary: json['is_primary'] as bool? ?? false,
      );

  final String id;
  final String bankName;
  final String accountName;
  final String accountNumber;
  final String? sortCode;
  final String currency;
  final String? instructions;
  final bool isPrimary;
}

class InvestorPaymentIntent {
  const InvestorPaymentIntent({
    required this.id,
    required this.amount,
    this.currency = 'NGN',
    this.provider = 'bank_transfer',
    this.providerReference,
    this.bankReference,
    this.status = 'pending',
    this.createdAt,
    this.notes,
    this.metadata = const {},
  });

  factory InvestorPaymentIntent.fromJson(Map<String, dynamic> json) {
    final metaRaw = json['metadata'];
    final metadata = metaRaw is Map
        ? Map<String, dynamic>.from(metaRaw)
        : <String, dynamic>{};
    return InvestorPaymentIntent(
      id: json['id'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'NGN',
      provider: json['provider'] as String? ?? 'bank_transfer',
      providerReference: json['provider_reference'] as String?,
      bankReference: json['bank_reference'] as String?,
      status: json['status'] as String? ?? 'pending',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      notes: json['notes'] as String?,
      metadata: metadata,
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
  final Map<String, dynamic> metadata;

  String get formattedAmount =>
      NumberFormat.currency(symbol: '₦', decimalDigits: 0).format(amount);

  bool get isAwaitingVerification =>
      status == 'awaiting_confirmation' ||
      status == 'pending' ||
      status == 'submitted';

  bool get isVerified => status == 'confirmed' || status == 'completed';

  bool get isRejected => status == 'failed' || status == 'cancelled';

  String get displayStatus {
    if (isAwaitingVerification) return 'Pending verification';
    if (isVerified) return 'Verified';
    if (status == 'cancelled') return 'Cancelled';
    if (status == 'failed') return 'Failed';
    return status.replaceAll('_', ' ');
  }

  String? get holdingId => metadata['holding_id'] as String?;

  String? get holdingLabel => metadata['holding_label'] as String?;

  String? get payerBank => metadata['payer_bank'] as String?;

  String? get proofSecureUrl =>
      metadata['proof_secure_url'] as String? ??
      (metadata['proof'] is Map
          ? (metadata['proof'] as Map)['secure_url'] as String?
          : null);

  DateTime? get transferDate {
    final raw = metadata['transfer_date'];
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }
}

class InvestorPaymentReceipt {
  const InvestorPaymentReceipt({
    required this.id,
    required this.receiptNumber,
    required this.amount,
    this.currency = 'NGN',
    this.paymentId,
    this.issuedAt,
    this.methodLabel,
    this.notes,
  });

  factory InvestorPaymentReceipt.fromJson(Map<String, dynamic> json) =>
      InvestorPaymentReceipt(
        id: json['id'] as String,
        receiptNumber: json['receipt_number'] as String? ?? 'Receipt',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        currency: json['currency'] as String? ?? 'NGN',
        paymentId: json['payment_id'] as String?,
        issuedAt: json['issued_at'] != null
            ? DateTime.tryParse(json['issued_at'] as String)
            : null,
        methodLabel: json['method_label'] as String?,
        notes: json['notes'] as String?,
      );

  final String id;
  final String receiptNumber;
  final double amount;
  final String currency;
  final String? paymentId;
  final DateTime? issuedAt;
  final String? methodLabel;
  final String? notes;

  String get formattedAmount =>
      NumberFormat.currency(symbol: '₦', decimalDigits: 0).format(amount);
}

class InvestorSettledPayment {
  const InvestorSettledPayment({
    required this.id,
    required this.amount,
    this.currency = 'NGN',
    this.status = 'completed',
    this.paidAt,
    this.providerReference,
    this.receiptId,
    this.receiptNumber,
  });

  factory InvestorSettledPayment.fromJson(Map<String, dynamic> json) {
    final receipt = json['finance_receipts'];
    Map<String, dynamic>? receiptMap;
    if (receipt is Map) {
      receiptMap = Map<String, dynamic>.from(receipt);
    } else if (receipt is List && receipt.isNotEmpty && receipt.first is Map) {
      receiptMap = Map<String, dynamic>.from(receipt.first as Map);
    }
    return InvestorSettledPayment(
      id: json['id'] as String,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'NGN',
      status: json['status'] as String? ?? 'completed',
      paidAt: json['paid_at'] != null
          ? DateTime.tryParse(json['paid_at'] as String)
          : null,
      providerReference: json['provider_reference'] as String?,
      receiptId: receiptMap?['id'] as String? ??
          json['finance_receipt_id'] as String?,
      receiptNumber: receiptMap?['receipt_number'] as String?,
    );
  }

  final String id;
  final double amount;
  final String currency;
  final String status;
  final DateTime? paidAt;
  final String? providerReference;
  final String? receiptId;
  final String? receiptNumber;

  String get formattedAmount =>
      NumberFormat.currency(symbol: '₦', decimalDigits: 0).format(amount);
}

class InvestorConstructionBundle {
  const InvestorConstructionBundle({
    this.projects = const [],
    this.updates = const [],
    this.milestones = const [],
    this.phases = const [],
    this.overallPercent = 0,
  });

  final List<InvestorConstructionProject> projects;
  final List<InvestorConstructionUpdate> updates;
  final List<InvestorMilestone> milestones;
  final List<InvestorConstructionPhase> phases;
  final double overallPercent;

  bool get isEmpty =>
      projects.isEmpty && updates.isEmpty && milestones.isEmpty;

  List<InvestorConstructionVideo> get allVideos =>
      updates.expand((u) => u.videos).toList();

  List<String> get allPhotos => updates.expand((u) => u.photos).toList();

  InvestorConstructionProject? get primaryProject =>
      projects.isEmpty ? null : projects.first;

  /// Narrow a full portal feed to one holding's property.
  InvestorConstructionBundle scopedToProperty(String? propertyId) {
    if (propertyId == null) {
      return projects.length <= 1 ? this : const InvestorConstructionBundle();
    }
    final scopedProjects =
        projects.where((p) => p.propertyId == propertyId).toList();
    final projectIds = scopedProjects.map((p) => p.id).toSet();
    final scopedUpdates = updates
        .where(
          (u) =>
              u.propertyId == propertyId ||
              (u.projectId != null && projectIds.contains(u.projectId)),
        )
        .toList();
    final scopedMilestones = milestones
        .where((m) => m.projectId != null && projectIds.contains(m.projectId))
        .toList();
    final scopedPhases = phases
        .where((p) => p.projectId != null && projectIds.contains(p.projectId))
        .toList();
    final overall = scopedProjects.isNotEmpty
        ? scopedProjects
            .map((p) => p.progressPct)
            .fold<double>(0, (a, b) => a > b ? a : b)
        : scopedUpdates
            .map((u) => u.completionPercent ?? 0)
            .fold<double>(0, (a, b) => a > b ? a : b);
    return InvestorConstructionBundle(
      projects: scopedProjects,
      updates: scopedUpdates,
      milestones: scopedMilestones,
      phases: scopedPhases,
      overallPercent: overall,
    );
  }
}

class InvestorCommitment {
  const InvestorCommitment({
    required this.id,
    required this.amount,
    required this.opportunityTitle,
    this.currency = 'NGN',
    this.status = 'pending',
    this.committedAt,
    this.fundedAt,
    this.notes,
  });

  factory InvestorCommitment.fromJson(Map<String, dynamic> json) =>
      InvestorCommitment(
        id: json['id'] as String,
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        opportunityTitle: '${json['opportunity_title'] ?? 'Investment'}',
        currency: json['currency'] as String? ?? 'NGN',
        status: json['status'] as String? ?? 'pending',
        committedAt: json['committed_at'] != null
            ? DateTime.tryParse(json['committed_at'] as String)
            : null,
        fundedAt: json['funded_at'] != null
            ? DateTime.tryParse(json['funded_at'] as String)
            : null,
        notes: json['notes'] as String?,
      );

  final String id;
  final double amount;
  final String opportunityTitle;
  final String currency;
  final String status;
  final DateTime? committedAt;
  final DateTime? fundedAt;
  final String? notes;

  bool get isOpen =>
      status == 'pending' || status == 'reserved' || status == 'confirmed';

  String get formattedAmount =>
      NumberFormat.currency(symbol: '₦', decimalDigits: 0).format(amount);
}

class InvestorDashboardSnapshot {
  const InvestorDashboardSnapshot({
    required this.investor,
    this.displayName = 'Investor',
    this.holdingsCount = 0,
    this.portfolioValue = 0,
    this.totalInvested = 0,
    this.totalReturns = 0,
    this.totalDistributions = 0,
    this.pendingDistributions = 0,
    this.outstandingPayments = 0,
    this.walletAvailable = 0,
    this.unreadNotifications = 0,
    this.kycStatus = 'pending',
    this.portfolioStatus = 'active',
    this.holdings = const [],
    this.recentActivity = const [],
    this.recentDistributions = const [],
    this.recentPerformance = const [],
    this.commitments = const [],
    this.wallet,
    this.loadedAt,
  });

  final InvestorRecord investor;
  final String displayName;
  final int holdingsCount;
  /// Sum of holding current values (source of truth — not client invention).
  final double portfolioValue;
  /// Sum of holding cost basis.
  final double totalInvested;
  /// portfolioValue - totalInvested (capital appreciation on book).
  final double totalReturns;
  final double totalDistributions;
  final double pendingDistributions;
  /// Open bank-transfer intents awaiting finance verification.
  final double outstandingPayments;
  final double walletAvailable;
  final int unreadNotifications;
  final String kycStatus;
  /// Human portfolio state for status chips (active / attention / empty / kyc).
  final String portfolioStatus;
  final List<InvestorHolding> holdings;
  final List<InvestorActivity> recentActivity;
  final List<InvestorDistribution> recentDistributions;
  final List<InvestorPerformance> recentPerformance;
  final List<InvestorCommitment> commitments;
  final InvestorWallet? wallet;
  final DateTime? loadedAt;

  String get formattedPortfolioValue =>
      NumberFormat.currency(symbol: '₦', decimalDigits: 0).format(portfolioValue);

  String get formattedTotalInvested =>
      NumberFormat.currency(symbol: '₦', decimalDigits: 0).format(totalInvested);

  String get formattedTotalReturns =>
      NumberFormat.currency(symbol: '₦', decimalDigits: 0).format(totalReturns);

  String get formattedTotalDistributions =>
      NumberFormat.currency(symbol: '₦', decimalDigits: 0).format(totalDistributions);

  String get formattedPendingDistributions =>
      NumberFormat.currency(symbol: '₦', decimalDigits: 0).format(pendingDistributions);

  String get formattedOutstandingPayments =>
      NumberFormat.currency(symbol: '₦', decimalDigits: 0)
          .format(outstandingPayments);

  String get formattedWalletAvailable =>
      NumberFormat.currency(symbol: '₦', decimalDigits: 0).format(walletAvailable);

  bool get hasOutstandingPayments => outstandingPayments > 0;

  double get returnsPct =>
      totalInvested > 0 ? (totalReturns / totalInvested) * 100 : 0;
}
