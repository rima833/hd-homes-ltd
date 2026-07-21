// Volume 4 Part 12 — DDCMS domain models + demo command-center snapshot.

const String kDdcmsAiDisclaimer = 'AI-generated — editable / advisory';

enum DocStatus {
  draft,
  inReview,
  approved,
  published,
  archived,
  expired;

  String get dbValue => switch (this) {
        DocStatus.draft => 'draft',
        DocStatus.inReview => 'in_review',
        DocStatus.approved => 'approved',
        DocStatus.published => 'published',
        DocStatus.archived => 'archived',
        DocStatus.expired => 'expired',
      };

  static DocStatus fromDb(String? raw) => switch (raw) {
        'in_review' => DocStatus.inReview,
        'approved' => DocStatus.approved,
        'published' => DocStatus.published,
        'archived' => DocStatus.archived,
        'expired' => DocStatus.expired,
        _ => DocStatus.draft,
      };
}

enum ContractStatus {
  draft,
  negotiation,
  pendingSignature,
  active,
  amended,
  expired,
  terminated;

  String get dbValue => switch (this) {
        ContractStatus.draft => 'draft',
        ContractStatus.negotiation => 'negotiation',
        ContractStatus.pendingSignature => 'pending_signature',
        ContractStatus.active => 'active',
        ContractStatus.amended => 'amended',
        ContractStatus.expired => 'expired',
        ContractStatus.terminated => 'terminated',
      };

  static ContractStatus fromDb(String? raw) => switch (raw) {
        'negotiation' => ContractStatus.negotiation,
        'pending_signature' => ContractStatus.pendingSignature,
        'active' => ContractStatus.active,
        'amended' => ContractStatus.amended,
        'expired' => ContractStatus.expired,
        'terminated' => ContractStatus.terminated,
        _ => ContractStatus.draft,
      };
}

enum SignatureStatus {
  pending,
  sent,
  partiallySigned,
  completed,
  declined,
  expired,
  cancelled;

  String get dbValue => switch (this) {
        SignatureStatus.pending => 'pending',
        SignatureStatus.sent => 'sent',
        SignatureStatus.partiallySigned => 'partially_signed',
        SignatureStatus.completed => 'completed',
        SignatureStatus.declined => 'declined',
        SignatureStatus.expired => 'expired',
        SignatureStatus.cancelled => 'cancelled',
      };

  static SignatureStatus fromDb(String? raw) => switch (raw) {
        'sent' => SignatureStatus.sent,
        'partially_signed' => SignatureStatus.partiallySigned,
        'completed' => SignatureStatus.completed,
        'declined' => SignatureStatus.declined,
        'expired' => SignatureStatus.expired,
        'cancelled' => SignatureStatus.cancelled,
        _ => SignatureStatus.pending,
      };
}

enum AssetType {
  image,
  video,
  audio,
  design,
  brochure,
  other;

  String get dbValue => name;

  static AssetType fromDb(String? raw) => switch (raw) {
        'video' => AssetType.video,
        'audio' => AssetType.audio,
        'design' => AssetType.design,
        'brochure' => AssetType.brochure,
        'other' => AssetType.other,
        _ => AssetType.image,
      };
}

class DdcmsKpi {
  const DdcmsKpi({
    required this.label,
    required this.value,
    this.unit = 'count',
    this.changePct,
    this.status = 'ok',
  });

  final String label;
  final double value;
  final String unit;
  final double? changePct;
  final String status;

  String get displayValue {
    if (unit == 'score') {
      return value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
    }
    return value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  }
}

class DdcmsFolder {
  const DdcmsFolder({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.path,
    this.sortOrder = 100,
  });

  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? path;
  final int sortOrder;

  factory DdcmsFolder.fromJson(Map<String, dynamic> json) {
    return DdcmsFolder(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      description: json['description'] as String?,
      path: json['path'] as String?,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 100,
    );
  }
}

class DdcmsDocument {
  const DdcmsDocument({
    required this.id,
    required this.title,
    this.code,
    this.description,
    this.status = 'draft',
    this.category,
    this.folderName,
    this.mimeType,
    this.fileName,
    this.ownerLabel,
    this.sensitivity = 'internal',
    this.tags = const [],
    this.currentVersion = 1,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String? code;
  final String? description;
  final String status;
  final String? category;
  final String? folderName;
  final String? mimeType;
  final String? fileName;
  final String? ownerLabel;
  final String sensitivity;
  final List<String> tags;
  final int currentVersion;
  final DateTime? updatedAt;

  DocStatus get statusEnum => DocStatus.fromDb(status);

  factory DdcmsDocument.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'];
    final meta = json['metadata'];
    String? category;
    if (meta is Map && meta['category'] != null) {
      category = meta['category'].toString();
    }
    return DdcmsDocument(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      code: json['code'] as String?,
      description: json['description'] as String?,
      status: json['status'] as String? ?? 'draft',
      category: category,
      mimeType: json['mime_type'] as String?,
      fileName: json['file_name'] as String?,
      ownerLabel: json['owner_label'] as String?,
      sensitivity: json['sensitivity'] as String? ?? 'internal',
      tags: rawTags is List ? rawTags.map((e) => e.toString()).toList() : const [],
      currentVersion: (json['current_version'] as num?)?.toInt() ?? 1,
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
    );
  }
}

class DdcmsContract {
  const DdcmsContract({
    required this.id,
    required this.contractNumber,
    required this.title,
    this.contractType = 'sale',
    this.status = 'draft',
    this.counterpartyName,
    this.valueAmount,
    this.currency = 'NGN',
    this.effectiveDate,
    this.expiryDate,
  });

  final String id;
  final String contractNumber;
  final String title;
  final String contractType;
  final String status;
  final String? counterpartyName;
  final double? valueAmount;
  final String currency;
  final DateTime? effectiveDate;
  final DateTime? expiryDate;

  ContractStatus get statusEnum => ContractStatus.fromDb(status);

  factory DdcmsContract.fromJson(Map<String, dynamic> json) {
    return DdcmsContract(
      id: json['id'] as String? ?? '',
      contractNumber: json['contract_number'] as String? ?? '',
      title: json['title'] as String? ?? '',
      contractType: json['contract_type'] as String? ?? 'sale',
      status: json['status'] as String? ?? 'draft',
      counterpartyName: json['counterparty_name'] as String?,
      valueAmount: (json['value_amount'] as num?)?.toDouble(),
      currency: json['currency'] as String? ?? 'NGN',
      effectiveDate: DateTime.tryParse(json['effective_date'] as String? ?? ''),
      expiryDate: DateTime.tryParse(json['expiry_date'] as String? ?? ''),
    );
  }
}

class DdcmsSignatureRequest {
  const DdcmsSignatureRequest({
    required this.id,
    required this.title,
    this.status = 'pending',
    this.requesterLabel,
    this.dueAt,
    this.completedAt,
  });

  final String id;
  final String title;
  final String status;
  final String? requesterLabel;
  final DateTime? dueAt;
  final DateTime? completedAt;

  SignatureStatus get statusEnum => SignatureStatus.fromDb(status);

  factory DdcmsSignatureRequest.fromJson(Map<String, dynamic> json) {
    return DdcmsSignatureRequest(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      requesterLabel: json['requester_label'] as String?,
      dueAt: DateTime.tryParse(json['due_at'] as String? ?? ''),
      completedAt: DateTime.tryParse(json['completed_at'] as String? ?? ''),
    );
  }
}

class DdcmsApproval {
  const DdcmsApproval({
    required this.id,
    required this.title,
    this.status = 'pending',
    this.requesterLabel,
    this.approverLabel,
    this.decisionNote,
    this.decidedAt,
  });

  final String id;
  final String title;
  final String status;
  final String? requesterLabel;
  final String? approverLabel;
  final String? decisionNote;
  final DateTime? decidedAt;

  factory DdcmsApproval.fromJson(Map<String, dynamic> json) {
    return DdcmsApproval(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      requesterLabel: json['requester_label'] as String?,
      approverLabel: json['approver_label'] as String?,
      decisionNote: json['decision_note'] as String?,
      decidedAt: DateTime.tryParse(json['decided_at'] as String? ?? ''),
    );
  }
}

class DdcmsAsset {
  const DdcmsAsset({
    required this.id,
    required this.title,
    this.assetType = 'image',
    this.status = 'active',
    this.mimeType,
    this.usageRights,
    this.tags = const [],
  });

  final String id;
  final String title;
  final String assetType;
  final String status;
  final String? mimeType;
  final String? usageRights;
  final List<String> tags;

  AssetType get typeEnum => AssetType.fromDb(assetType);

  factory DdcmsAsset.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'];
    return DdcmsAsset(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      assetType: json['asset_type'] as String? ?? 'image',
      status: json['status'] as String? ?? 'active',
      mimeType: json['mime_type'] as String?,
      usageRights: json['usage_rights'] as String?,
      tags: rawTags is List ? rawTags.map((e) => e.toString()).toList() : const [],
    );
  }
}

class DdcmsOcrJob {
  const DdcmsOcrJob({
    required this.id,
    this.documentId,
    this.status = 'queued',
    this.engine = 'tesseract',
    this.pages = 1,
    this.progressPct = 0,
    this.errorMessage,
  });

  final String id;
  final String? documentId;
  final String status;
  final String engine;
  final int pages;
  final int progressPct;
  final String? errorMessage;

  factory DdcmsOcrJob.fromJson(Map<String, dynamic> json) {
    return DdcmsOcrJob(
      id: json['id'] as String? ?? '',
      documentId: json['document_id'] as String?,
      status: json['status'] as String? ?? 'queued',
      engine: json['engine'] as String? ?? 'tesseract',
      pages: (json['pages'] as num?)?.toInt() ?? 1,
      progressPct: (json['progress_pct'] as num?)?.toInt() ?? 0,
      errorMessage: json['error_message'] as String?,
    );
  }
}

class DdcmsShare {
  const DdcmsShare({
    required this.id,
    required this.documentId,
    this.recipientLabel,
    this.recipientEmail,
    this.accessLevel = 'view',
    this.expiresAt,
    this.isRevoked = false,
  });

  final String id;
  final String documentId;
  final String? recipientLabel;
  final String? recipientEmail;
  final String accessLevel;
  final DateTime? expiresAt;
  final bool isRevoked;

  factory DdcmsShare.fromJson(Map<String, dynamic> json) {
    return DdcmsShare(
      id: json['id'] as String? ?? '',
      documentId: json['document_id'] as String? ?? '',
      recipientLabel: json['recipient_label'] as String?,
      recipientEmail: json['recipient_email'] as String?,
      accessLevel: json['access_level'] as String? ?? 'view',
      expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? ''),
      isRevoked: json['is_revoked'] as bool? ?? false,
    );
  }
}

class DdcmsRetentionPolicy {
  const DdcmsRetentionPolicy({
    required this.id,
    required this.name,
    required this.slug,
    this.categorySlug,
    this.retainMonths = 84,
    this.actionOnExpiry = 'review',
    this.isActive = true,
  });

  final String id;
  final String name;
  final String slug;
  final String? categorySlug;
  final int retainMonths;
  final String actionOnExpiry;
  final bool isActive;

  factory DdcmsRetentionPolicy.fromJson(Map<String, dynamic> json) {
    return DdcmsRetentionPolicy(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      categorySlug: json['category_slug'] as String?,
      retainMonths: (json['retain_months'] as num?)?.toInt() ?? 84,
      actionOnExpiry: json['action_on_expiry'] as String? ?? 'review',
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class DdcmsArchivalRecord {
  const DdcmsArchivalRecord({
    required this.id,
    this.documentId,
    this.status = 'scheduled',
    this.scheduledAt,
    this.note,
  });

  final String id;
  final String? documentId;
  final String status;
  final DateTime? scheduledAt;
  final String? note;

  factory DdcmsArchivalRecord.fromJson(Map<String, dynamic> json) {
    return DdcmsArchivalRecord(
      id: json['id'] as String? ?? '',
      documentId: json['document_id'] as String?,
      status: json['status'] as String? ?? 'scheduled',
      scheduledAt: DateTime.tryParse(json['scheduled_at'] as String? ?? ''),
      note: json['note'] as String?,
    );
  }
}

class DdcmsAiInsight {
  const DdcmsAiInsight({
    required this.id,
    required this.title,
    required this.body,
    this.insightType = 'advisory',
    this.confidencePct,
    this.editable = true,
    this.disclaimer = kDdcmsAiDisclaimer,
  });

  final String id;
  final String title;
  final String body;
  final String insightType;
  final double? confidencePct;
  final bool editable;
  final String disclaimer;

  factory DdcmsAiInsight.fromJson(Map<String, dynamic> json) {
    return DdcmsAiInsight(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      insightType: json['insight_type'] as String? ?? 'advisory',
      confidencePct: (json['confidence_pct'] as num?)?.toDouble(),
      editable: json['editable'] as bool? ?? true,
      disclaimer: json['disclaimer'] as String? ?? kDdcmsAiDisclaimer,
    );
  }
}

class DdcmsActivity {
  const DdcmsActivity({
    required this.id,
    required this.action,
    required this.summary,
    this.actorLabel,
    this.occurredAt,
  });

  final String id;
  final String action;
  final String summary;
  final String? actorLabel;
  final DateTime? occurredAt;

  factory DdcmsActivity.fromJson(Map<String, dynamic> json) {
    return DdcmsActivity(
      id: json['id'] as String? ?? '',
      action: json['action'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      actorLabel: json['actor_label'] as String?,
      occurredAt: DateTime.tryParse(json['occurred_at'] as String? ?? ''),
    );
  }
}

class DdcmsReport {
  const DdcmsReport({
    required this.id,
    required this.title,
    this.reportType = 'usage',
    this.periodLabel,
    this.summary,
  });

  final String id;
  final String title;
  final String reportType;
  final String? periodLabel;
  final String? summary;

  factory DdcmsReport.fromJson(Map<String, dynamic> json) {
    return DdcmsReport(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      reportType: json['report_type'] as String? ?? 'usage',
      periodLabel: json['period_label'] as String?,
      summary: json['summary'] as String?,
    );
  }
}

class DdcmsCommandCenterSnapshot {
  const DdcmsCommandCenterSnapshot({
    required this.kpis,
    required this.folders,
    required this.documents,
    required this.contracts,
    required this.signatures,
    required this.approvals,
    required this.assets,
    required this.ocrJobs,
    required this.shares,
    required this.retention,
    required this.archival,
    required this.aiInsights,
    required this.activities,
    required this.reports,
    this.fromRemote = false,
    this.loadedAt,
    this.aiDisclaimer = kDdcmsAiDisclaimer,
  });

  final List<DdcmsKpi> kpis;
  final List<DdcmsFolder> folders;
  final List<DdcmsDocument> documents;
  final List<DdcmsContract> contracts;
  final List<DdcmsSignatureRequest> signatures;
  final List<DdcmsApproval> approvals;
  final List<DdcmsAsset> assets;
  final List<DdcmsOcrJob> ocrJobs;
  final List<DdcmsShare> shares;
  final List<DdcmsRetentionPolicy> retention;
  final List<DdcmsArchivalRecord> archival;
  final List<DdcmsAiInsight> aiInsights;
  final List<DdcmsActivity> activities;
  final List<DdcmsReport> reports;
  final bool fromRemote;
  final DateTime? loadedAt;
  final String aiDisclaimer;
}

abstract final class DdcmsDemo {
  static DdcmsCommandCenterSnapshot snapshot() {
    final now = DateTime.now();
    return DdcmsCommandCenterSnapshot(
      kpis: _kpis(),
      folders: _folders(),
      documents: _documents(now),
      contracts: _contracts(now),
      signatures: _signatures(now),
      approvals: _approvals(now),
      assets: _assets(),
      ocrJobs: _ocrJobs(),
      shares: _shares(now),
      retention: _retention(),
      archival: _archival(now),
      aiInsights: _aiInsights(),
      activities: _activities(now),
      reports: _reports(),
      fromRemote: false,
      loadedAt: now,
    );
  }

  static List<DdcmsKpi> _kpis() => const [
        DdcmsKpi(label: 'Active Docs', value: 6),
        DdcmsKpi(label: 'Contracts', value: 3),
        DdcmsKpi(label: 'Pending Signatures', value: 2, status: 'watch'),
        DdcmsKpi(label: 'Approvals', value: 2, status: 'watch'),
        DdcmsKpi(label: 'OCR Queue', value: 2),
        DdcmsKpi(label: 'DAM Assets', value: 3),
        DdcmsKpi(label: 'Retention Alerts', value: 2, status: 'watch'),
      ];

  static List<DdcmsFolder> _folders() => const [
        DdcmsFolder(
          id: 'd1200001-0000-4000-8000-000000000001',
          name: 'Legal & Title',
          slug: 'legal-title',
          description: 'Deeds, titles, and legal packs',
          path: '/legal-title',
          sortOrder: 10,
        ),
        DdcmsFolder(
          id: 'd1200001-0000-4000-8000-000000000002',
          name: 'Construction',
          slug: 'construction',
          path: '/construction',
          sortOrder: 20,
        ),
        DdcmsFolder(
          id: 'd1200001-0000-4000-8000-000000000003',
          name: 'Marketing',
          slug: 'marketing',
          path: '/marketing',
          sortOrder: 30,
        ),
        DdcmsFolder(
          id: 'd1200001-0000-4000-8000-000000000004',
          name: 'HR & Policies',
          slug: 'hr-policies',
          path: '/hr-policies',
          sortOrder: 40,
        ),
        DdcmsFolder(
          id: 'd1200001-0000-4000-8000-000000000005',
          name: 'Finance',
          slug: 'finance',
          path: '/finance',
          sortOrder: 50,
        ),
      ];

  static List<DdcmsDocument> _documents(DateTime now) => [
        DdcmsDocument(
          id: 'd1200004-0000-4000-8000-000000000001',
          title: 'Lekki Phase 2 — Block B Title Deed',
          code: 'DOC-2026-1201',
          description: 'Certified soft-copy title deed for Block B.',
          status: 'approved',
          category: 'property-deed',
          folderName: 'Legal & Title',
          mimeType: 'application/pdf',
          fileName: 'lekki-b-title-deed.pdf',
          ownerLabel: 'Legal Desk',
          sensitivity: 'confidential',
          tags: const ['confidential', 'legal'],
          currentVersion: 2,
          updatedAt: now.subtract(const Duration(hours: 5)),
        ),
        DdcmsDocument(
          id: 'd1200004-0000-4000-8000-000000000002',
          title: 'Unit C-12 Architectural Drawing (Stub)',
          code: 'DOC-2026-1202',
          status: 'in_review',
          category: 'construction-drawing',
          folderName: 'Construction',
          ownerLabel: 'Site Office',
          tags: const ['construction'],
          updatedAt: now.subtract(const Duration(hours: 2)),
        ),
        DdcmsDocument(
          id: 'd1200004-0000-4000-8000-000000000003',
          title: 'Oceanview Estates Marketing Brochure Q3',
          code: 'DOC-2026-1203',
          status: 'published',
          category: 'marketing-brochure',
          folderName: 'Marketing',
          ownerLabel: 'Marketing',
          sensitivity: 'public',
          tags: const ['client-facing', 'marketing'],
          currentVersion: 3,
          updatedAt: now.subtract(const Duration(days: 1)),
        ),
        DdcmsDocument(
          id: 'd1200004-0000-4000-8000-000000000004',
          title: 'Employee Code of Conduct 2026',
          code: 'DOC-2026-1204',
          status: 'approved',
          category: 'hr-policy',
          folderName: 'HR & Policies',
          ownerLabel: 'HR Ops',
          tags: const ['hr'],
          updatedAt: now.subtract(const Duration(days: 3)),
        ),
        DdcmsDocument(
          id: 'd1200004-0000-4000-8000-000000000005',
          title: 'June Installment Invoice — Adeyemi',
          code: 'DOC-2026-1205',
          status: 'approved',
          category: 'finance-invoice',
          folderName: 'Finance',
          ownerLabel: 'Finance',
          sensitivity: 'confidential',
          tags: const ['finance', 'confidential'],
          updatedAt: now.subtract(const Duration(hours: 8)),
        ),
        DdcmsDocument(
          id: 'd1200004-0000-4000-8000-000000000006',
          title: 'Sale Agreement — Plot B-14 Oceanview',
          code: 'DOC-2026-1206',
          status: 'in_review',
          category: 'contract',
          folderName: 'Legal & Title',
          ownerLabel: 'Sales Legal',
          sensitivity: 'confidential',
          tags: const ['requires-signature', 'contract'],
          updatedAt: now.subtract(const Duration(hours: 1)),
        ),
      ];

  static List<DdcmsContract> _contracts(DateTime now) => [
        DdcmsContract(
          id: 'd120000b-0000-4000-8000-000000000001',
          contractNumber: 'CTR-2026-1401',
          title: 'Sale Agreement — Plot B-14 Oceanview',
          contractType: 'sale',
          status: 'pending_signature',
          counterpartyName: 'Tunde Bakare',
          valueAmount: 45000000,
          effectiveDate: now,
          expiryDate: now.add(const Duration(days: 540)),
        ),
        DdcmsContract(
          id: 'd120000b-0000-4000-8000-000000000002',
          contractNumber: 'CTR-2026-1402',
          title: 'Construction Phase 2 Subcontract',
          contractType: 'construction',
          status: 'active',
          counterpartyName: 'Apex Build Co.',
          valueAmount: 120000000,
        ),
        DdcmsContract(
          id: 'd120000b-0000-4000-8000-000000000003',
          contractNumber: 'CTR-2026-1403',
          title: 'Marketing Agency Retainer Q3',
          contractType: 'service',
          status: 'negotiation',
          counterpartyName: 'Nova Creative',
          valueAmount: 8500000,
        ),
      ];

  static List<DdcmsSignatureRequest> _signatures(DateTime now) => [
        DdcmsSignatureRequest(
          id: 'd120000e-0000-4000-8000-000000000001',
          title: 'Sign Sale Agreement B-14',
          status: 'sent',
          requesterLabel: 'Sales Legal',
          dueAt: now.add(const Duration(days: 5)),
        ),
        DdcmsSignatureRequest(
          id: 'd120000e-0000-4000-8000-000000000002',
          title: 'Sign Marketing Retainer Q3',
          status: 'pending',
          requesterLabel: 'Marketing',
          dueAt: now.add(const Duration(days: 10)),
        ),
      ];

  static List<DdcmsApproval> _approvals(DateTime now) => [
        const DdcmsApproval(
          id: 'd120000a-0000-4000-8000-000000000001',
          title: 'Approve Sale Agreement B-14',
          status: 'pending',
          requesterLabel: 'Sales Legal',
        ),
        const DdcmsApproval(
          id: 'd120000a-0000-4000-8000-000000000002',
          title: 'Approve Unit C-12 Drawing Stub',
          status: 'pending',
          requesterLabel: 'Site Office',
        ),
        DdcmsApproval(
          id: 'd120000a-0000-4000-8000-000000000003',
          title: 'Approve Code of Conduct 2026',
          status: 'approved',
          requesterLabel: 'HR Ops',
          approverLabel: 'Admin',
          decidedAt: now.subtract(const Duration(days: 2)),
        ),
      ];

  static List<DdcmsAsset> _assets() => const [
        DdcmsAsset(
          id: 'd1200012-0000-4000-8000-000000000001',
          title: 'Oceanview Hero Aerial',
          assetType: 'image',
          usageRights: 'HD Homes internal + ads',
          tags: ['brochure', 'hero'],
        ),
        DdcmsAsset(
          id: 'd1200012-0000-4000-8000-000000000002',
          title: 'Site Progress Reel June',
          assetType: 'video',
          usageRights: 'Client portal only',
          tags: ['construction'],
        ),
        DdcmsAsset(
          id: 'd1200012-0000-4000-8000-000000000003',
          title: 'Brand Logo Pack 2026',
          assetType: 'design',
          usageRights: 'Brand guidelines',
          tags: ['brand'],
        ),
      ];

  static List<DdcmsOcrJob> _ocrJobs() => const [
        DdcmsOcrJob(
          id: 'd1200010-0000-4000-8000-000000000001',
          documentId: 'd1200004-0000-4000-8000-000000000001',
          status: 'completed',
          pages: 4,
          progressPct: 100,
        ),
        DdcmsOcrJob(
          id: 'd1200010-0000-4000-8000-000000000002',
          documentId: 'd1200004-0000-4000-8000-000000000005',
          status: 'processing',
          pages: 2,
          progressPct: 55,
        ),
        DdcmsOcrJob(
          id: 'd1200010-0000-4000-8000-000000000003',
          documentId: 'd1200004-0000-4000-8000-000000000002',
          status: 'queued',
          pages: 1,
        ),
      ];

  static List<DdcmsShare> _shares(DateTime now) => [
        DdcmsShare(
          id: 'd1200015-0000-4000-8000-000000000001',
          documentId: 'd1200004-0000-4000-8000-000000000003',
          recipientLabel: 'Open House Guests',
          accessLevel: 'view',
          expiresAt: now.add(const Duration(days: 14)),
        ),
        DdcmsShare(
          id: 'd1200015-0000-4000-8000-000000000002',
          documentId: 'd1200004-0000-4000-8000-000000000005',
          recipientLabel: 'Ngozi Adeyemi',
          recipientEmail: 'ngozi.adeyemi@example.com',
          accessLevel: 'download',
          expiresAt: now.add(const Duration(days: 7)),
        ),
      ];

  static List<DdcmsRetentionPolicy> _retention() => const [
        DdcmsRetentionPolicy(
          id: 'd1200016-0000-4000-8000-000000000001',
          name: 'Financial Records 7y',
          slug: 'finance-7y',
          categorySlug: 'finance-invoice',
          retainMonths: 84,
          actionOnExpiry: 'archive',
        ),
        DdcmsRetentionPolicy(
          id: 'd1200016-0000-4000-8000-000000000002',
          name: 'HR Policies Active',
          slug: 'hr-active',
          categorySlug: 'hr-policy',
          retainMonths: 36,
        ),
        DdcmsRetentionPolicy(
          id: 'd1200016-0000-4000-8000-000000000003',
          name: 'Marketing Collateral 2y',
          slug: 'marketing-2y',
          categorySlug: 'marketing-brochure',
          retainMonths: 24,
          actionOnExpiry: 'archive',
        ),
      ];

  static List<DdcmsArchivalRecord> _archival(DateTime now) => [
        DdcmsArchivalRecord(
          id: 'd1200017-0000-4000-8000-000000000001',
          documentId: 'd1200004-0000-4000-8000-000000000005',
          status: 'scheduled',
          scheduledAt: now.add(const Duration(days: 90)),
          note: 'Retention alert seeded for finance invoice',
        ),
        DdcmsArchivalRecord(
          id: 'd1200017-0000-4000-8000-000000000002',
          documentId: 'd1200004-0000-4000-8000-000000000003',
          status: 'scheduled',
          scheduledAt: now.add(const Duration(days: 180)),
          note: 'Marketing brochure retention window',
        ),
      ];

  static List<DdcmsAiInsight> _aiInsights() => const [
        DdcmsAiInsight(
          id: 'd120001c-0000-4000-8000-000000000001',
          title: 'Contract risk — pending buyer signature',
          body:
              'Sale Agreement B-14 has vendor signed but buyer pending. Recommend gentle reminder within 48 hours.',
          insightType: 'contract_risk',
          confidencePct: 82,
        ),
        DdcmsAiInsight(
          id: 'd120001c-0000-4000-8000-000000000002',
          title: 'OCR backlog advisory',
          body:
              'Two jobs are active/queued. Prioritize invoice OCR before month-end finance close.',
          insightType: 'ops',
          confidencePct: 74,
        ),
        DdcmsAiInsight(
          id: 'd120001c-0000-4000-8000-000000000003',
          title: 'Retention compliance watch',
          body:
              'One finance archival is scheduled. Confirm no active disputes before auto-archive.',
          insightType: 'compliance',
          confidencePct: 79,
        ),
      ];

  static List<DdcmsActivity> _activities(DateTime now) => [
        DdcmsActivity(
          id: 'd120001a-0000-4000-8000-000000000001',
          action: 'workflow_started',
          summary: 'Sale Agreement B-14 entered approval workflow',
          actorLabel: 'Sales Legal',
          occurredAt: now.subtract(const Duration(hours: 3)),
        ),
        DdcmsActivity(
          id: 'd120001a-0000-4000-8000-000000000002',
          action: 'ocr_completed',
          summary: 'OCR completed for title deed (4 pages)',
          actorLabel: 'System',
          occurredAt: now.subtract(const Duration(hours: 2)),
        ),
        DdcmsActivity(
          id: 'd120001a-0000-4000-8000-000000000003',
          action: 'shared',
          summary: 'Brochure shared for open-house guests',
          actorLabel: 'Marketing',
          occurredAt: now.subtract(const Duration(hours: 1)),
        ),
        DdcmsActivity(
          id: 'd120001a-0000-4000-8000-000000000004',
          action: 'retention_alert',
          summary: 'Finance invoice retention window scheduled',
          actorLabel: 'Compliance',
          occurredAt: now.subtract(const Duration(minutes: 30)),
        ),
      ];

  static List<DdcmsReport> _reports() => const [
        DdcmsReport(
          id: 'd1200019-0000-4000-8000-000000000001',
          title: 'Document Usage Weekly',
          reportType: 'usage',
          periodLabel: 'W28 2026',
          summary:
              'Most viewed: marketing brochure; highest sensitivity downloads: title deed.',
        ),
        DdcmsReport(
          id: 'd1200019-0000-4000-8000-000000000002',
          title: 'Contract Pipeline',
          reportType: 'contracts',
          periodLabel: 'Jul 2026',
          summary: '1 pending signature, 1 active construction, 1 negotiation.',
        ),
      ];
}
