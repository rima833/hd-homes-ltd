// Volume 4 Part 2 — Enterprise Property Management System domain models.

enum InventoryStatus {
  available,
  reserved,
  sold,
  underContract,
  rented,
  leased,
  archived;

  String get label => switch (this) {
        InventoryStatus.available => 'Available',
        InventoryStatus.reserved => 'Reserved',
        InventoryStatus.sold => 'Sold',
        InventoryStatus.underContract => 'Under Contract',
        InventoryStatus.rented => 'Rented',
        InventoryStatus.leased => 'Leased',
        InventoryStatus.archived => 'Archived',
      };

  String get slug => switch (this) {
        InventoryStatus.underContract => 'under_contract',
        _ => name,
      };

  static InventoryStatus fromSlug(String? raw) {
    return switch ((raw ?? 'available').toLowerCase()) {
      'reserved' => InventoryStatus.reserved,
      'sold' => InventoryStatus.sold,
      'under_contract' || 'undercontract' => InventoryStatus.underContract,
      'rented' => InventoryStatus.rented,
      'leased' => InventoryStatus.leased,
      'archived' => InventoryStatus.archived,
      _ => InventoryStatus.available,
    };
  }
}

enum DevelopmentStatus {
  planned,
  underConstruction,
  completed,
  renovating;

  String get label => switch (this) {
        DevelopmentStatus.planned => 'Planned',
        DevelopmentStatus.underConstruction => 'Under Construction',
        DevelopmentStatus.completed => 'Completed',
        DevelopmentStatus.renovating => 'Renovating',
      };

  String get slug => switch (this) {
        DevelopmentStatus.underConstruction => 'under_construction',
        _ => name,
      };

  static DevelopmentStatus fromSlug(String? raw) {
    return switch ((raw ?? 'planned').toLowerCase()) {
      'under_construction' || 'underconstruction' =>
        DevelopmentStatus.underConstruction,
      'completed' => DevelopmentStatus.completed,
      'renovating' => DevelopmentStatus.renovating,
      _ => DevelopmentStatus.planned,
    };
  }
}

enum MarketingStatus {
  featured,
  premium,
  newListing,
  hotDeal,
  soldOut;

  String get label => switch (this) {
        MarketingStatus.featured => 'Featured',
        MarketingStatus.premium => 'Premium',
        MarketingStatus.newListing => 'New Listing',
        MarketingStatus.hotDeal => 'Hot Deal',
        MarketingStatus.soldOut => 'Sold Out',
      };

  String get slug => switch (this) {
        MarketingStatus.newListing => 'new_listing',
        MarketingStatus.hotDeal => 'hot_deal',
        MarketingStatus.soldOut => 'sold_out',
        _ => name,
      };

  static MarketingStatus fromSlug(String? raw) {
    return switch ((raw ?? 'new_listing').toLowerCase()) {
      'featured' => MarketingStatus.featured,
      'premium' => MarketingStatus.premium,
      'hot_deal' || 'hotdeal' => MarketingStatus.hotDeal,
      'sold_out' || 'soldout' => MarketingStatus.soldOut,
      _ => MarketingStatus.newListing,
    };
  }
}

enum PublishWorkflowStatus {
  draft,
  pendingReview,
  published,
  archived;

  String get label => switch (this) {
        PublishWorkflowStatus.draft => 'Draft',
        PublishWorkflowStatus.pendingReview => 'Pending Review',
        PublishWorkflowStatus.published => 'Published',
        PublishWorkflowStatus.archived => 'Archived',
      };

  String get slug => switch (this) {
        PublishWorkflowStatus.pendingReview => 'pending_review',
        _ => name,
      };

  static PublishWorkflowStatus fromSlug(String? raw) {
    return switch ((raw ?? 'draft').toLowerCase()) {
      'pending_review' || 'pendingreview' => PublishWorkflowStatus.pendingReview,
      'published' => PublishWorkflowStatus.published,
      'archived' => PublishWorkflowStatus.archived,
      _ => PublishWorkflowStatus.draft,
    };
  }
}

enum InspectionType {
  siteVisit,
  virtualTour,
  openHouse,
  investorVisit,
  handover;

  String get label => switch (this) {
        InspectionType.siteVisit => 'Site Visit',
        InspectionType.virtualTour => 'Virtual Tour',
        InspectionType.openHouse => 'Open House',
        InspectionType.investorVisit => 'Investor Visit',
        InspectionType.handover => 'Handover',
      };

  String get slug => switch (this) {
        InspectionType.siteVisit => 'site_visit',
        InspectionType.virtualTour => 'virtual_tour',
        InspectionType.openHouse => 'open_house',
        InspectionType.investorVisit => 'investor_visit',
        _ => name,
      };

  static InspectionType fromSlug(String? raw) {
    return switch ((raw ?? 'site_visit').toLowerCase()) {
      'virtual_tour' || 'virtualtour' => InspectionType.virtualTour,
      'open_house' || 'openhouse' => InspectionType.openHouse,
      'investor_visit' || 'investorvisit' => InspectionType.investorVisit,
      'handover' => InspectionType.handover,
      _ => InspectionType.siteVisit,
    };
  }
}

enum InspectionStatus {
  scheduled,
  confirmed,
  completed,
  cancelled,
  noShow;

  String get label => switch (this) {
        InspectionStatus.scheduled => 'Scheduled',
        InspectionStatus.confirmed => 'Confirmed',
        InspectionStatus.completed => 'Completed',
        InspectionStatus.cancelled => 'Cancelled',
        InspectionStatus.noShow => 'No Show',
      };

  String get slug => switch (this) {
        InspectionStatus.noShow => 'no_show',
        _ => name,
      };

  static InspectionStatus fromSlug(String? raw) {
    return switch ((raw ?? 'scheduled').toLowerCase()) {
      'confirmed' => InspectionStatus.confirmed,
      'completed' => InspectionStatus.completed,
      'cancelled' => InspectionStatus.cancelled,
      'no_show' || 'noshow' => InspectionStatus.noShow,
      _ => InspectionStatus.scheduled,
    };
  }
}

enum ApprovalStep {
  salesTeam,
  managerReview,
  legalReview,
  executiveApproval,
  published;

  String get label => switch (this) {
        ApprovalStep.salesTeam => 'Sales Team',
        ApprovalStep.managerReview => 'Manager Review',
        ApprovalStep.legalReview => 'Legal Review',
        ApprovalStep.executiveApproval => 'Executive Approval',
        ApprovalStep.published => 'Published',
      };

  String get slug => switch (this) {
        ApprovalStep.salesTeam => 'sales_team',
        ApprovalStep.managerReview => 'manager_review',
        ApprovalStep.legalReview => 'legal_review',
        ApprovalStep.executiveApproval => 'executive_approval',
        _ => name,
      };

  static ApprovalStep fromSlug(String? raw) {
    return switch ((raw ?? 'sales_team').toLowerCase()) {
      'manager_review' || 'managerreview' => ApprovalStep.managerReview,
      'legal_review' || 'legalreview' => ApprovalStep.legalReview,
      'executive_approval' || 'executiveapproval' =>
        ApprovalStep.executiveApproval,
      'published' => ApprovalStep.published,
      _ => ApprovalStep.salesTeam,
    };
  }
}

class PmsProperty {
  const PmsProperty({
    required this.id,
    required this.slug,
    required this.title,
    this.propertyCode,
    this.propertyType = 'apartment',
    this.estateName,
    this.hierarchyPath = const [],
    this.city,
    this.inventoryStatus = InventoryStatus.available,
    this.developmentStatus = DevelopmentStatus.planned,
    this.marketingStatus = MarketingStatus.newListing,
    this.publishWorkflowStatus = PublishWorkflowStatus.draft,
    this.bedrooms,
    this.bathrooms,
    this.listingPrice,
    this.promoPrice,
    this.investorPrice,
    this.rentalPrice,
    this.currency = 'NGN',
    this.performanceScore = 0,
    this.tags = const [],
    this.aiSummary,
    this.isFeatured = false,
  });

  final String id;
  final String slug;
  final String title;
  final String? propertyCode;
  final String propertyType;
  final String? estateName;
  final List<String> hierarchyPath;
  final String? city;
  final InventoryStatus inventoryStatus;
  final DevelopmentStatus developmentStatus;
  final MarketingStatus marketingStatus;
  final PublishWorkflowStatus publishWorkflowStatus;
  final double? bedrooms;
  final double? bathrooms;
  final double? listingPrice;
  final double? promoPrice;
  final double? investorPrice;
  final double? rentalPrice;
  final String currency;
  final double performanceScore;
  final List<String> tags;
  final String? aiSummary;
  final bool isFeatured;

  String get hierarchyBreadcrumb => hierarchyPath.isEmpty
      ? (estateName ?? '—')
      : hierarchyPath.join(' → ');

  String formatPrice(double? value) {
    if (value == null) return '—';
    final n = value;
    if (currency == 'NGN') {
      if (n >= 1e9) return '₦${(n / 1e9).toStringAsFixed(1)}B';
      if (n >= 1e6) return '₦${(n / 1e6).toStringAsFixed(1)}M';
      if (n >= 1e3) return '₦${(n / 1e3).toStringAsFixed(0)}K';
      return '₦${n.toStringAsFixed(0)}';
    }
    return '$currency ${n.toStringAsFixed(0)}';
  }

  factory PmsProperty.fromJson(Map<String, dynamic> json) {
    final tagsRaw = json['tags'];
    final tags = tagsRaw is List
        ? tagsRaw.map((e) => e.toString()).toList()
        : const <String>[];
    final hierarchyRaw = json['hierarchy_path'] ?? json['hierarchyPath'];
    final hierarchy = hierarchyRaw is List
        ? hierarchyRaw.map((e) => e.toString()).toList()
        : const <String>[];
    return PmsProperty(
      id: json['id']?.toString() ?? '',
      slug: json['slug'] as String? ?? '',
      title: json['title'] as String? ?? '',
      propertyCode: json['property_code'] as String?,
      propertyType: json['property_type'] as String? ??
          json['category_slug'] as String? ??
          'apartment',
      estateName: json['estate_name'] as String?,
      hierarchyPath: hierarchy,
      city: json['city'] as String?,
      inventoryStatus:
          InventoryStatus.fromSlug(json['inventory_status'] as String?),
      developmentStatus:
          DevelopmentStatus.fromSlug(json['development_status'] as String?),
      marketingStatus:
          MarketingStatus.fromSlug(json['marketing_status'] as String?),
      publishWorkflowStatus: PublishWorkflowStatus.fromSlug(
        json['publish_workflow_status'] as String?,
      ),
      bedrooms: (json['bedrooms'] as num?)?.toDouble(),
      bathrooms: (json['bathrooms'] as num?)?.toDouble(),
      listingPrice: (json['listing_price'] as num?)?.toDouble(),
      promoPrice: (json['promo_price'] as num?)?.toDouble(),
      investorPrice: (json['investor_price'] as num?)?.toDouble(),
      rentalPrice: (json['rental_price'] as num?)?.toDouble(),
      currency: json['currency'] as String? ?? 'NGN',
      performanceScore: (json['performance_score'] as num?)?.toDouble() ?? 0,
      tags: tags,
      aiSummary: json['ai_summary'] as String?,
      isFeatured: json['is_featured'] as bool? ?? false,
    );
  }
}

class PmsInventoryKpi {
  const PmsInventoryKpi({
    required this.label,
    required this.value,
    this.unit = 'count',
  });

  final String label;
  final double value;
  final String unit;

  String get displayValue {
    if (unit == 'ngn') {
      final n = value;
      if (n >= 1e9) return '₦${(n / 1e9).toStringAsFixed(1)}B';
      if (n >= 1e6) return '₦${(n / 1e6).toStringAsFixed(1)}M';
      if (n >= 1e3) return '₦${(n / 1e3).toStringAsFixed(0)}K';
      return '₦${n.toStringAsFixed(0)}';
    }
    if (unit == 'score') {
      return value == value.roundToDouble()
          ? value.toStringAsFixed(0)
          : value.toStringAsFixed(1);
    }
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }
}

class PmsLifecycleEvent {
  const PmsLifecycleEvent({
    required this.id,
    required this.propertyId,
    required this.eventType,
    required this.title,
    this.description,
    this.propertyTitle,
    this.occurredAt,
  });

  final String id;
  final String propertyId;
  final String eventType;
  final String title;
  final String? description;
  final String? propertyTitle;
  final DateTime? occurredAt;

  factory PmsLifecycleEvent.fromJson(Map<String, dynamic> json) {
    return PmsLifecycleEvent(
      id: json['id']?.toString() ?? '',
      propertyId: json['property_id']?.toString() ?? '',
      eventType: json['event_type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      propertyTitle: json['property_title'] as String?,
      occurredAt: DateTime.tryParse(json['occurred_at'] as String? ?? ''),
    );
  }
}

class PmsInspection {
  const PmsInspection({
    required this.id,
    required this.propertyId,
    required this.inspectionType,
    required this.status,
    required this.scheduledAt,
    this.propertyTitle,
    this.visitorName,
    this.assignedStaffName,
    this.reportSummary,
  });

  final String id;
  final String propertyId;
  final InspectionType inspectionType;
  final InspectionStatus status;
  final DateTime scheduledAt;
  final String? propertyTitle;
  final String? visitorName;
  final String? assignedStaffName;
  final String? reportSummary;

  factory PmsInspection.fromJson(Map<String, dynamic> json) {
    return PmsInspection(
      id: json['id']?.toString() ?? '',
      propertyId: json['property_id']?.toString() ?? '',
      inspectionType:
          InspectionType.fromSlug(json['inspection_type'] as String?),
      status: InspectionStatus.fromSlug(json['status'] as String?),
      scheduledAt: DateTime.tryParse(json['scheduled_at'] as String? ?? '') ??
          DateTime.now(),
      propertyTitle: json['property_title'] as String?,
      visitorName: json['visitor_name'] as String?,
      assignedStaffName: json['assigned_staff_name'] as String?,
      reportSummary: json['report_summary'] as String?,
    );
  }
}

class PmsApprovalStep {
  const PmsApprovalStep({
    required this.id,
    required this.propertyId,
    required this.step,
    required this.status,
    this.propertyTitle,
    this.comments,
    this.stepOrder = 1,
    this.decidedAt,
  });

  final String id;
  final String propertyId;
  final ApprovalStep step;
  final String status;
  final String? propertyTitle;
  final String? comments;
  final int stepOrder;
  final DateTime? decidedAt;

  bool get isPending => status.toLowerCase() == 'pending';

  factory PmsApprovalStep.fromJson(Map<String, dynamic> json) {
    return PmsApprovalStep(
      id: json['id']?.toString() ?? '',
      propertyId: json['property_id']?.toString() ?? '',
      step: ApprovalStep.fromSlug(json['step_key'] as String?),
      status: json['status'] as String? ?? 'pending',
      propertyTitle: json['property_title'] as String?,
      comments: json['comments'] as String?,
      stepOrder: (json['step_order'] as num?)?.toInt() ?? 1,
      decidedAt: DateTime.tryParse(json['decided_at'] as String? ?? ''),
    );
  }
}

class PmsAiInsight {
  const PmsAiInsight({
    required this.id,
    required this.title,
    required this.body,
    this.category = 'assistant',
    this.isAiGenerated = true,
    this.propertyId,
  });

  final String id;
  final String title;
  final String body;
  final String category;
  final bool isAiGenerated;
  final String? propertyId;
}

class PmsEstateTwin {
  const PmsEstateTwin({
    required this.estateName,
    required this.availableUnits,
    required this.reservedUnits,
    required this.soldUnits,
    this.constructionLabel = 'On track',
    this.hierarchySample = const [],
  });

  final String estateName;
  final int availableUnits;
  final int reservedUnits;
  final int soldUnits;
  final String constructionLabel;
  final List<String> hierarchySample;

  int get totalUnits => availableUnits + reservedUnits + soldUnits;
}

/// Full Property Command Center snapshot.
class PmsCommandCenterSnapshot {
  const PmsCommandCenterSnapshot({
    required this.kpis,
    required this.properties,
    required this.inspections,
    required this.lifecycle,
    required this.approvalsPending,
    required this.aiInsights,
    required this.estateTwin,
    required this.inventoryIntelligence,
    this.fromRemote = false,
    this.loadedAt,
  });

  final List<PmsInventoryKpi> kpis;
  final List<PmsProperty> properties;
  final List<PmsInspection> inspections;
  final List<PmsLifecycleEvent> lifecycle;
  final List<PmsApprovalStep> approvalsPending;
  final List<PmsAiInsight> aiInsights;
  final PmsEstateTwin estateTwin;
  final List<String> inventoryIntelligence;
  final bool fromRemote;
  final DateTime? loadedAt;
}

/// Eight-step property creation wizard draft (local until SQL applied).
class PmsWizardDraft {
  const PmsWizardDraft({
    this.step = 0,
    this.title = '',
    this.propertyCode = '',
    this.propertyType = 'apartment',
    this.estateName = 'Victoria Crest',
    this.city = 'Lekki, Lagos',
    this.addressLine = '',
    this.latitude,
    this.longitude,
    this.bedrooms = 3,
    this.bathrooms = 3,
    this.toilets = 4,
    this.builtUpAreaSqm,
    this.parkingSpaces = 2,
    this.amenities = const [],
    this.listingPrice,
    this.promoPrice,
    this.investorPrice,
    this.rentalPrice,
    this.mediaNote = '',
    this.documentsNote = '',
    this.publishStatus = PublishWorkflowStatus.draft,
    this.inventoryStatus = InventoryStatus.available,
    this.marketingStatus = MarketingStatus.newListing,
  });

  /// Current wizard step index (0–7).
  final int step;

  // Step 1 — Basic
  final String title;
  final String propertyCode;
  final String propertyType;

  // Step 2 — Location
  final String estateName;
  final String city;
  final String addressLine;
  final double? latitude;
  final double? longitude;

  // Step 3 — Specs
  final double bedrooms;
  final double bathrooms;
  final double toilets;
  final double? builtUpAreaSqm;
  final int parkingSpaces;

  // Step 4 — Amenities
  final List<String> amenities;

  // Step 5 — Pricing
  final double? listingPrice;
  final double? promoPrice;
  final double? investorPrice;
  final double? rentalPrice;

  // Step 6 — Media
  final String mediaNote;

  // Step 7 — Documents
  final String documentsNote;

  // Step 8 — Publishing
  final PublishWorkflowStatus publishStatus;
  final InventoryStatus inventoryStatus;
  final MarketingStatus marketingStatus;

  PmsWizardDraft copyWith({
    int? step,
    String? title,
    String? propertyCode,
    String? propertyType,
    String? estateName,
    String? city,
    String? addressLine,
    double? latitude,
    double? longitude,
    double? bedrooms,
    double? bathrooms,
    double? toilets,
    double? builtUpAreaSqm,
    int? parkingSpaces,
    List<String>? amenities,
    double? listingPrice,
    double? promoPrice,
    double? investorPrice,
    double? rentalPrice,
    String? mediaNote,
    String? documentsNote,
    PublishWorkflowStatus? publishStatus,
    InventoryStatus? inventoryStatus,
    MarketingStatus? marketingStatus,
  }) {
    return PmsWizardDraft(
      step: step ?? this.step,
      title: title ?? this.title,
      propertyCode: propertyCode ?? this.propertyCode,
      propertyType: propertyType ?? this.propertyType,
      estateName: estateName ?? this.estateName,
      city: city ?? this.city,
      addressLine: addressLine ?? this.addressLine,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      bedrooms: bedrooms ?? this.bedrooms,
      bathrooms: bathrooms ?? this.bathrooms,
      toilets: toilets ?? this.toilets,
      builtUpAreaSqm: builtUpAreaSqm ?? this.builtUpAreaSqm,
      parkingSpaces: parkingSpaces ?? this.parkingSpaces,
      amenities: amenities ?? this.amenities,
      listingPrice: listingPrice ?? this.listingPrice,
      promoPrice: promoPrice ?? this.promoPrice,
      investorPrice: investorPrice ?? this.investorPrice,
      rentalPrice: rentalPrice ?? this.rentalPrice,
      mediaNote: mediaNote ?? this.mediaNote,
      documentsNote: documentsNote ?? this.documentsNote,
      publishStatus: publishStatus ?? this.publishStatus,
      inventoryStatus: inventoryStatus ?? this.inventoryStatus,
      marketingStatus: marketingStatus ?? this.marketingStatus,
    );
  }

  static const List<String> amenityCatalog = [
    'Swimming Pool',
    'Gym',
    '24/7 Security',
    'Backup Power',
    'Parking',
    'Smart Home',
    'Balcony',
    'Servant Quarters',
    'CCTV',
    'Elevator',
  ];
}

/// Default / offline PMS dataset when DB is empty or unavailable.
abstract final class PmsDemo {
  static const hierarchySample = [
    'Victoria Crest',
    'Phase A',
    'Block B',
    'Building 12',
    'Unit 4',
  ];

  static PmsCommandCenterSnapshot snapshot() {
    final now = DateTime.now();
    final properties = _properties();
    final kpis = aggregateKpis(properties);

    return PmsCommandCenterSnapshot(
      kpis: kpis,
      properties: properties,
      inspections: [
        PmsInspection(
          id: 'insp-1',
          propertyId: 'pms-1',
          inspectionType: InspectionType.siteVisit,
          status: InspectionStatus.confirmed,
          scheduledAt: now.add(const Duration(hours: 5)),
          propertyTitle: 'Victoria Crest — Unit 4B',
          visitorName: 'Adaeze Nwosu',
          assignedStaffName: 'Field Ops — Kemi A.',
        ),
        PmsInspection(
          id: 'insp-2',
          propertyId: 'pms-3',
          inspectionType: InspectionType.investorVisit,
          status: InspectionStatus.scheduled,
          scheduledAt: now.add(const Duration(days: 1, hours: 2)),
          propertyTitle: 'Harbour View Penthouse',
          visitorName: 'Horizon Capital',
          assignedStaffName: 'Investor Relations',
        ),
        PmsInspection(
          id: 'insp-3',
          propertyId: 'pms-2',
          inspectionType: InspectionType.openHouse,
          status: InspectionStatus.scheduled,
          scheduledAt: now.add(const Duration(days: 2)),
          propertyTitle: 'Palm Duplex Lekki',
          visitorName: 'Public open house',
        ),
        PmsInspection(
          id: 'insp-4',
          propertyId: 'pms-5',
          inspectionType: InspectionType.virtualTour,
          status: InspectionStatus.confirmed,
          scheduledAt: now.add(const Duration(hours: 28)),
          propertyTitle: 'Azure Court 3-Bed',
          visitorName: 'Chuka Okonkwo',
        ),
      ],
      lifecycle: [
        PmsLifecycleEvent(
          id: 'lc-1',
          propertyId: 'pms-1',
          eventType: 'status_change',
          title: 'Reserved — Unit 4B',
          description: 'Client reservation deposited; 72h hold active.',
          propertyTitle: 'Victoria Crest — Unit 4B',
          occurredAt: now.subtract(const Duration(hours: 2)),
        ),
        PmsLifecycleEvent(
          id: 'lc-2',
          propertyId: 'pms-4',
          eventType: 'published',
          title: 'Listing published',
          description: 'Garden Terrace Maisonette went live on marketplace.',
          propertyTitle: 'Garden Terrace Maisonette',
          occurredAt: now.subtract(const Duration(hours: 6)),
        ),
        PmsLifecycleEvent(
          id: 'lc-3',
          propertyId: 'pms-3',
          eventType: 'price_update',
          title: 'Investor price adjusted',
          description: 'Investor tranche updated to ₦185M.',
          propertyTitle: 'Harbour View Penthouse',
          occurredAt: now.subtract(const Duration(hours: 14)),
        ),
        PmsLifecycleEvent(
          id: 'lc-4',
          propertyId: 'pms-6',
          eventType: 'inspection',
          title: 'Handover inspection completed',
          description: 'QA punch-list cleared for Crest Studio A1.',
          propertyTitle: 'Crest Studio A1',
          occurredAt: now.subtract(const Duration(days: 1)),
        ),
        PmsLifecycleEvent(
          id: 'lc-5',
          propertyId: 'pms-2',
          eventType: 'approval',
          title: 'Legal review approved',
          description: 'Title pack verified for Palm Duplex Lekki.',
          propertyTitle: 'Palm Duplex Lekki',
          occurredAt: now.subtract(const Duration(days: 1, hours: 4)),
        ),
      ],
      approvalsPending: [
        PmsApprovalStep(
          id: 'ap-1',
          propertyId: 'pms-5',
          step: ApprovalStep.managerReview,
          status: 'pending',
          propertyTitle: 'Azure Court 3-Bed',
          stepOrder: 2,
          comments: 'Awaiting media completeness check',
        ),
        PmsApprovalStep(
          id: 'ap-2',
          propertyId: 'pms-3',
          step: ApprovalStep.legalReview,
          status: 'pending',
          propertyTitle: 'Harbour View Penthouse',
          stepOrder: 3,
        ),
        PmsApprovalStep(
          id: 'ap-3',
          propertyId: 'pms-4',
          step: ApprovalStep.executiveApproval,
          status: 'pending',
          propertyTitle: 'Garden Terrace Maisonette',
          stepOrder: 4,
          comments: 'Promo pricing needs director sign-off',
        ),
      ],
      aiInsights: [
        const PmsAiInsight(
          id: 'ai-1',
          title: 'Pricing opportunity — Victoria Crest Phase A',
          body:
              'Comparable Lekki closings suggest a 4–6% upside on Unit 4B listing while demand is elevated.',
          category: 'pricing',
          propertyId: 'pms-1',
        ),
        const PmsAiInsight(
          id: 'ai-2',
          title: 'SEO stub — Palm Duplex Lekki',
          body:
              'Suggested title: “4-Bed Palm Duplex in Lekki Phase 1 | HD Homes”. Add “serviced estate” to meta description.',
          category: 'seo',
          propertyId: 'pms-2',
        ),
        const PmsAiInsight(
          id: 'ai-3',
          title: 'Inventory alert',
          body:
              'Block B availability dropped below 20%. Prioritize Phase B marketing or open waitlist for similar units.',
          category: 'inventory',
        ),
        const PmsAiInsight(
          id: 'ai-4',
          title: 'Summary — Harbour View Penthouse',
          body:
              'Premium waterfront penthouse with strong investor score. Media quality is high; push featured placement this week.',
          category: 'summary',
          propertyId: 'pms-3',
        ),
      ],
      estateTwin: const PmsEstateTwin(
        estateName: 'Victoria Crest',
        availableUnits: 42,
        reservedUnits: 18,
        soldUnits: 67,
        constructionLabel: 'Phase A 78% · Block B cladding in progress',
        hierarchySample: hierarchySample,
      ),
      inventoryIntelligence: const [
        'Smart Inventory Intelligence™ detected 3 units stuck in reserved > 72h — consider auto-release.',
        'Under-construction inventory in Phase A is converting 1.4× faster than completed stock.',
        'Azure Court engagement spike (+31% views WoW) without matching bookings — schedule open house.',
        'Duplicate media tags found on 2 draft listings — clean before publish.',
      ],
      fromRemote: false,
      loadedAt: now,
    );
  }

  static List<PmsInventoryKpi> aggregateKpis(List<PmsProperty> properties) {
    var available = 0.0;
    var reserved = 0.0;
    var sold = 0.0;
    var underContract = 0.0;
    var scoreSum = 0.0;
    var pipeline = 0.0;

    for (final p in properties) {
      switch (p.inventoryStatus) {
        case InventoryStatus.available:
          available++;
          pipeline += p.listingPrice ?? 0;
        case InventoryStatus.reserved:
          reserved++;
          pipeline += p.listingPrice ?? 0;
        case InventoryStatus.sold:
          sold++;
        case InventoryStatus.underContract:
          underContract++;
          pipeline += p.listingPrice ?? 0;
        case InventoryStatus.rented:
        case InventoryStatus.leased:
        case InventoryStatus.archived:
          break;
      }
      scoreSum += p.performanceScore;
    }

    final avgScore = properties.isEmpty ? 0.0 : scoreSum / properties.length;

    return [
      PmsInventoryKpi(label: 'Available', value: available),
      PmsInventoryKpi(label: 'Reserved', value: reserved),
      PmsInventoryKpi(label: 'Sold', value: sold),
      PmsInventoryKpi(label: 'Under Contract', value: underContract),
      PmsInventoryKpi(
        label: 'Avg Performance Score',
        value: avgScore,
        unit: 'score',
      ),
      PmsInventoryKpi(
        label: 'Pipeline Value',
        value: pipeline,
        unit: 'ngn',
      ),
    ];
  }

  static List<PmsProperty> _properties() {
    return const [
      PmsProperty(
        id: 'pms-1',
        slug: 'victoria-crest-unit-4b',
        title: 'Victoria Crest — Unit 4B',
        propertyCode: 'VC-PA-BB-B12-U4',
        propertyType: 'apartment',
        estateName: 'Victoria Crest',
        hierarchyPath: hierarchySample,
        city: 'Lekki',
        inventoryStatus: InventoryStatus.reserved,
        developmentStatus: DevelopmentStatus.underConstruction,
        marketingStatus: MarketingStatus.hotDeal,
        publishWorkflowStatus: PublishWorkflowStatus.published,
        bedrooms: 3,
        bathrooms: 3,
        listingPrice: 95000000,
        promoPrice: 89500000,
        investorPrice: 82000000,
        performanceScore: 86,
        tags: ['lekki', 'victoria-crest', 'phase-a', 'hot-deal'],
        aiSummary:
            'High-demand mid-rise unit in Victoria Crest Phase A with strong reservation velocity.',
        isFeatured: true,
      ),
      PmsProperty(
        id: 'pms-2',
        slug: 'palm-duplex-lekki',
        title: 'Palm Duplex Lekki',
        propertyCode: 'PD-LK-01',
        propertyType: 'duplex',
        estateName: 'Palm Estate',
        hierarchyPath: ['Palm Estate', 'Phase 1', 'Block C', 'Unit 8'],
        city: 'Lekki',
        inventoryStatus: InventoryStatus.available,
        developmentStatus: DevelopmentStatus.completed,
        marketingStatus: MarketingStatus.featured,
        publishWorkflowStatus: PublishWorkflowStatus.published,
        bedrooms: 4,
        bathrooms: 5,
        listingPrice: 185000000,
        investorPrice: 168000000,
        performanceScore: 91,
        tags: ['duplex', 'featured', 'completed'],
        aiSummary:
            'Completed 4-bed duplex with top engagement scores in Lekki Phase 1.',
        isFeatured: true,
      ),
      PmsProperty(
        id: 'pms-3',
        slug: 'harbour-view-penthouse',
        title: 'Harbour View Penthouse',
        propertyCode: 'HV-PH-01',
        propertyType: 'penthouse',
        estateName: 'Harbour View',
        hierarchyPath: ['Harbour View', 'Tower A', 'Floor 18', 'PH-1'],
        city: 'Port Harcourt',
        inventoryStatus: InventoryStatus.underContract,
        developmentStatus: DevelopmentStatus.completed,
        marketingStatus: MarketingStatus.premium,
        publishWorkflowStatus: PublishWorkflowStatus.published,
        bedrooms: 5,
        bathrooms: 6,
        listingPrice: 220000000,
        investorPrice: 185000000,
        performanceScore: 88,
        tags: ['penthouse', 'premium', 'investor'],
        aiSummary:
            'Waterfront penthouse under contract — strong investor interest retained.',
      ),
      PmsProperty(
        id: 'pms-4',
        slug: 'garden-terrace-maisonette',
        title: 'Garden Terrace Maisonette',
        propertyCode: 'GT-M-03',
        propertyType: 'maisonette',
        estateName: 'Victoria Crest',
        hierarchyPath: [
          'Victoria Crest',
          'Phase B',
          'Block A',
          'Building 3',
          'Unit 2',
        ],
        city: 'Lekki',
        inventoryStatus: InventoryStatus.available,
        developmentStatus: DevelopmentStatus.underConstruction,
        marketingStatus: MarketingStatus.newListing,
        publishWorkflowStatus: PublishWorkflowStatus.pendingReview,
        bedrooms: 3,
        bathrooms: 3.5,
        listingPrice: 78000000,
        promoPrice: 74500000,
        performanceScore: 74,
        tags: ['new-listing', 'victoria-crest', 'phase-b'],
        aiSummary:
            'New Phase B maisonette awaiting executive publish approval.',
      ),
      PmsProperty(
        id: 'pms-5',
        slug: 'azure-court-3bed',
        title: 'Azure Court 3-Bed',
        propertyCode: 'AC-3B-12',
        propertyType: 'apartment',
        estateName: 'Azure Court',
        hierarchyPath: ['Azure Court', 'Wing B', 'Floor 5', '12'],
        city: 'Abuja',
        inventoryStatus: InventoryStatus.available,
        developmentStatus: DevelopmentStatus.completed,
        marketingStatus: MarketingStatus.featured,
        publishWorkflowStatus: PublishWorkflowStatus.draft,
        bedrooms: 3,
        bathrooms: 3,
        listingPrice: 68000000,
        rentalPrice: 3500000,
        performanceScore: 79,
        tags: ['abuja', 'rental-ready', 'draft'],
        aiSummary:
            'Ready-to-occupy Abuja apartment with rising view count; publish queue pending manager review.',
      ),
      PmsProperty(
        id: 'pms-6',
        slug: 'crest-studio-a1',
        title: 'Crest Studio A1',
        propertyCode: 'VC-PA-BA-B02-U1',
        propertyType: 'studio',
        estateName: 'Victoria Crest',
        hierarchyPath: [
          'Victoria Crest',
          'Phase A',
          'Block A',
          'Building 02',
          'Unit 1',
        ],
        city: 'Lekki',
        inventoryStatus: InventoryStatus.sold,
        developmentStatus: DevelopmentStatus.completed,
        marketingStatus: MarketingStatus.soldOut,
        publishWorkflowStatus: PublishWorkflowStatus.archived,
        bedrooms: 1,
        bathrooms: 1,
        listingPrice: 42000000,
        performanceScore: 82,
        tags: ['sold', 'studio', 'victoria-crest'],
        aiSummary: 'Studio sold and handed over — retained for analytics only.',
      ),
    ];
  }
}
