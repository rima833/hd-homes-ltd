import 'package:hdhomesproject/features/authentication/domain/entities/app_role.dart';

/// Configurable KYC verification tiers.
enum KycLevel {
  guest(0, 'Guest'),
  basic(1, 'Basic Verification'),
  identity(2, 'Identity Verified'),
  investor(3, 'Investor Verified'),
  enterprise(4, 'Enterprise Verified');

  const KycLevel(this.rank, this.label);
  final int rank;
  final String label;

  static KycLevel fromRank(int? rank) {
    final r = rank ?? 0;
    return KycLevel.values.firstWhere(
      (l) => l.rank == r,
      orElse: () => KycLevel.guest,
    );
  }

  /// Target level for a platform role.
  static KycLevel targetForRole(AppRole? role) => switch (role) {
        AppRole.investor => KycLevel.investor,
        AppRole.admin || AppRole.superAdmin => KycLevel.identity,
        AppRole.salesTeam ||
        AppRole.finance ||
        AppRole.marketing ||
        AppRole.constructionManager =>
          KycLevel.basic,
        AppRole.client || null => KycLevel.basic,
      };
}

/// Lifecycle status for a KYC application.
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
        KycStatus.inProgress => 'In progress',
        KycStatus.awaitingDocuments => 'Awaiting documents',
        KycStatus.underReview => 'Under review',
        KycStatus.approved => 'Approved',
        KycStatus.partiallyApproved => 'Partially approved',
        KycStatus.rejected => 'Rejected',
        KycStatus.expired => 'Expired',
        KycStatus.suspended => 'Suspended',
        KycStatus.needsResubmission => 'Needs resubmission',
      };

  String get slug => name.replaceAllMapped(
        RegExp(r'[A-Z]'),
        (m) => '_${m.group(0)!.toLowerCase()}',
      ).replaceFirst(RegExp(r'^_'), '');

  static KycStatus fromSlug(String? raw) {
    final s = (raw ?? 'pending').toLowerCase().replaceAll('-', '_');
    return switch (s) {
      'in_progress' => KycStatus.inProgress,
      'awaiting_documents' => KycStatus.awaitingDocuments,
      'under_review' => KycStatus.underReview,
      'approved' => KycStatus.approved,
      'partially_approved' => KycStatus.partiallyApproved,
      'rejected' => KycStatus.rejected,
      'expired' => KycStatus.expired,
      'suspended' => KycStatus.suspended,
      'needs_resubmission' => KycStatus.needsResubmission,
      _ => KycStatus.pending,
    };
  }

  bool get isTerminalSuccess =>
      this == KycStatus.approved || this == KycStatus.partiallyApproved;

  bool get canSubmit =>
      this == KycStatus.pending ||
      this == KycStatus.inProgress ||
      this == KycStatus.awaitingDocuments ||
      this == KycStatus.needsResubmission ||
      this == KycStatus.rejected;
}

/// Configurable document type catalog.
enum KycDocumentType {
  nationalId('national_id', 'National ID', true),
  passport('passport', 'International Passport', true),
  driversLicense('drivers_license', "Driver's License", true),
  voterCard('voter_card', 'Voter Card', false),
  residencePermit('residence_permit', 'Residence Permit', false),
  taxId('tax_id', 'Tax Identification', false),
  proofOfAddress('proof_of_address', 'Proof of Address', true),
  utilityBill('utility_bill', 'Utility Bill', false),
  bankStatement('bank_statement', 'Bank Statement', false),
  tenancyAgreement('tenancy_agreement', 'Tenancy Agreement', false),
  selfie('selfie', 'Selfie / Liveness', true),
  businessRegistration('business_registration', 'Business Registration', false),
  certificateOfIncorporation(
    'certificate_of_incorporation',
    'Certificate of Incorporation',
    false,
  ),
  corporateDocument('corporate_document', 'Corporate Document', false),
  boardResolution('board_resolution', 'Board Resolution', false);

  const KycDocumentType(this.slug, this.label, this.common);
  final String slug;
  final String label;
  final bool common;

  static KycDocumentType? fromSlug(String? slug) {
    if (slug == null) return null;
    for (final t in KycDocumentType.values) {
      if (t.slug == slug) return t;
    }
    return null;
  }

  bool get isIdentityDoc =>
      this == nationalId ||
      this == passport ||
      this == driversLicense ||
      this == voterCard ||
      this == residencePermit;

  bool get isAddressDoc =>
      this == proofOfAddress ||
      this == utilityBill ||
      this == bankStatement ||
      this == tenancyAgreement;
}

enum KycDocumentStatus {
  draft,
  uploaded,
  submitted,
  underReview,
  approved,
  rejected,
  expired,
  replaced;

  String get slug => name.replaceAllMapped(
        RegExp(r'[A-Z]'),
        (m) => '_${m.group(0)!.toLowerCase()}',
      ).replaceFirst(RegExp(r'^_'), '');

  static KycDocumentStatus fromSlug(String? raw) {
    final s = (raw ?? 'uploaded').toLowerCase();
    return switch (s) {
      'draft' => KycDocumentStatus.draft,
      'submitted' => KycDocumentStatus.submitted,
      'under_review' => KycDocumentStatus.underReview,
      'approved' => KycDocumentStatus.approved,
      'rejected' => KycDocumentStatus.rejected,
      'expired' => KycDocumentStatus.expired,
      'replaced' => KycDocumentStatus.replaced,
      _ => KycDocumentStatus.uploaded,
    };
  }
}

enum KycReviewDecision {
  approved,
  rejected,
  needsMoreInfo,
  needsBetterImage,
  expired,
  duplicate,
  potentialFraud;

  String get label => switch (this) {
        KycReviewDecision.approved => 'Approved',
        KycReviewDecision.rejected => 'Rejected',
        KycReviewDecision.needsMoreInfo => 'Needs more information',
        KycReviewDecision.needsBetterImage => 'Needs better image',
        KycReviewDecision.expired => 'Document expired',
        KycReviewDecision.duplicate => 'Duplicate submission',
        KycReviewDecision.potentialFraud => 'Potential fraud',
      };

  String get slug => switch (this) {
        KycReviewDecision.approved => 'approved',
        KycReviewDecision.rejected => 'rejected',
        KycReviewDecision.needsMoreInfo => 'needs_more_info',
        KycReviewDecision.needsBetterImage => 'needs_better_image',
        KycReviewDecision.expired => 'expired',
        KycReviewDecision.duplicate => 'duplicate',
        KycReviewDecision.potentialFraud => 'potential_fraud',
      };

  static KycReviewDecision fromSlug(String? raw) {
    return switch ((raw ?? '').toLowerCase()) {
      'approved' => KycReviewDecision.approved,
      'needs_more_info' => KycReviewDecision.needsMoreInfo,
      'needs_better_image' => KycReviewDecision.needsBetterImage,
      'expired' => KycReviewDecision.expired,
      'duplicate' => KycReviewDecision.duplicate,
      'potential_fraud' => KycReviewDecision.potentialFraud,
      _ => KycReviewDecision.rejected,
    };
  }
}

class KycDocument {
  const KycDocument({
    required this.id,
    required this.userId,
    required this.documentType,
    required this.storagePath,
    this.fileName,
    this.mimeType,
    this.fileSizeBytes,
    this.status = KycDocumentStatus.uploaded,
    this.expiresAt,
    this.reviewNotes,
    this.createdAt,
    this.signedUrl,
  });

  final String id;
  final String userId;
  final KycDocumentType documentType;
  final String storagePath;
  final String? fileName;
  final String? mimeType;
  final int? fileSizeBytes;
  final KycDocumentStatus status;
  final DateTime? expiresAt;
  final String? reviewNotes;
  final DateTime? createdAt;
  final String? signedUrl;

  factory KycDocument.fromJson(Map<String, dynamic> json, {String? signedUrl}) {
    return KycDocument(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      documentType:
          KycDocumentType.fromSlug(json['document_type'] as String?) ??
              KycDocumentType.nationalId,
      storagePath: json['storage_path'] as String,
      fileName: json['file_name'] as String?,
      mimeType: json['mime_type'] as String?,
      fileSizeBytes: json['file_size_bytes'] as int?,
      status: KycDocumentStatus.fromSlug(json['status'] as String?),
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'] as String)
          : null,
      reviewNotes: json['review_notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      signedUrl: signedUrl,
    );
  }
}

class InvestorComplianceInfo {
  const InvestorComplianceInfo({
    this.investmentSource,
    this.sourceOfFunds,
    this.investmentObjectives,
    this.estimatedAmount,
    this.riskProfile,
    this.declarationsAccepted = false,
  });

  final String? investmentSource;
  final String? sourceOfFunds;
  final String? investmentObjectives;
  final String? estimatedAmount;
  final String? riskProfile;
  final bool declarationsAccepted;

  bool get isComplete =>
      (investmentSource?.trim().isNotEmpty ?? false) &&
      (sourceOfFunds?.trim().isNotEmpty ?? false) &&
      declarationsAccepted;

  Map<String, dynamic> toUpsertMap(String userId) => {
        'user_id': userId,
        'investment_source': investmentSource?.trim(),
        'source_of_funds': sourceOfFunds?.trim(),
        'investment_objectives': investmentObjectives?.trim(),
        'estimated_amount': estimatedAmount?.trim(),
        'risk_profile': riskProfile?.trim(),
        'declarations_accepted': declarationsAccepted,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

  factory InvestorComplianceInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const InvestorComplianceInfo();
    return InvestorComplianceInfo(
      investmentSource: json['investment_source'] as String?,
      sourceOfFunds: json['source_of_funds'] as String?,
      investmentObjectives: json['investment_objectives'] as String?,
      estimatedAmount: json['estimated_amount'] as String?,
      riskProfile: json['risk_profile'] as String?,
      declarationsAccepted: json['declarations_accepted'] as bool? ?? false,
    );
  }

  InvestorComplianceInfo copyWith({
    String? investmentSource,
    String? sourceOfFunds,
    String? investmentObjectives,
    String? estimatedAmount,
    String? riskProfile,
    bool? declarationsAccepted,
  }) {
    return InvestorComplianceInfo(
      investmentSource: investmentSource ?? this.investmentSource,
      sourceOfFunds: sourceOfFunds ?? this.sourceOfFunds,
      investmentObjectives: investmentObjectives ?? this.investmentObjectives,
      estimatedAmount: estimatedAmount ?? this.estimatedAmount,
      riskProfile: riskProfile ?? this.riskProfile,
      declarationsAccepted: declarationsAccepted ?? this.declarationsAccepted,
    );
  }
}

class KycEvent {
  const KycEvent({
    required this.eventType,
    required this.createdAt,
    this.actorId,
    this.metadata = const {},
  });

  final String eventType;
  final DateTime createdAt;
  final String? actorId;
  final Map<String, dynamic> metadata;

  factory KycEvent.fromJson(Map<String, dynamic> json) {
    return KycEvent(
      eventType: json['event_type'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      actorId: json['actor_id'] as String?,
      metadata: Map<String, dynamic>.from(
        (json['metadata'] as Map?)?.cast<String, dynamic>() ?? {},
      ),
    );
  }
}

class KycReviewQueueItem {
  const KycReviewQueueItem({
    required this.userId,
    required this.status,
    required this.level,
    this.email,
    this.displayName,
    this.submittedAt,
    this.documentCount = 0,
    this.priority = 0,
  });

  final String userId;
  final KycStatus status;
  final KycLevel level;
  final String? email;
  final String? displayName;
  final DateTime? submittedAt;
  final int documentCount;
  final int priority;
}

/// Digital Verification Passport — reusable summary for other modules.
class DigitalVerificationPassport {
  const DigitalVerificationPassport({
    required this.userId,
    required this.level,
    required this.status,
    required this.trustScore,
    this.verifiedDocumentTypes = const [],
    this.verifiedAt,
    this.expiresAt,
    this.complianceStatus = 'incomplete',
  });

  final String userId;
  final KycLevel level;
  final KycStatus status;
  final int trustScore;
  final List<KycDocumentType> verifiedDocumentTypes;
  final DateTime? verifiedAt;
  final DateTime? expiresAt;
  final String complianceStatus;

  bool get isInvestorReady =>
      level.rank >= KycLevel.investor.rank && status.isTerminalSuccess;

  bool get isIdentityReady =>
      level.rank >= KycLevel.identity.rank && status.isTerminalSuccess;
}

class KycRequirementItem {
  const KycRequirementItem({
    required this.id,
    required this.label,
    required this.completed,
    this.hint,
  });

  final String id;
  final String label;
  final bool completed;
  final String? hint;
}

class KycProgress {
  const KycProgress({
    required this.percent,
    required this.requirements,
  });

  final int percent;
  final List<KycRequirementItem> requirements;

  List<KycRequirementItem> get missing =>
      requirements.where((r) => !r.completed).toList();
}

/// Intelligent Verification Engine™ — trust score + progress.
abstract final class IntelligentVerificationEngine {
  static KycProgress evaluateProgress({
    required bool emailVerified,
    required bool phoneVerified,
    required List<KycDocument> documents,
    required InvestorComplianceInfo compliance,
    required KycLevel targetLevel,
    required bool isInvestor,
  }) {
    final hasId = documents.any(
      (d) =>
          d.documentType.isIdentityDoc &&
          d.status != KycDocumentStatus.rejected &&
          d.status != KycDocumentStatus.replaced,
    );
    final hasSelfie = documents.any(
      (d) =>
          d.documentType == KycDocumentType.selfie &&
          d.status != KycDocumentStatus.rejected,
    );
    final hasAddress = documents.any(
      (d) =>
          d.documentType.isAddressDoc &&
          d.status != KycDocumentStatus.rejected,
    );
    final hasCorporate = documents.any(
      (d) =>
          d.documentType == KycDocumentType.businessRegistration ||
          d.documentType == KycDocumentType.certificateOfIncorporation,
    );

    final items = <KycRequirementItem>[
      KycRequirementItem(
        id: 'email',
        label: 'Email verified',
        completed: emailVerified,
      ),
      KycRequirementItem(
        id: 'phone',
        label: 'Phone verified',
        completed: phoneVerified,
      ),
      if (targetLevel.rank >= KycLevel.identity.rank) ...[
        KycRequirementItem(
          id: 'gov_id',
          label: 'Government ID uploaded',
          completed: hasId,
          hint: 'Passport, National ID, or Driver\'s License',
        ),
        KycRequirementItem(
          id: 'selfie',
          label: 'Selfie uploaded',
          completed: hasSelfie,
        ),
        KycRequirementItem(
          id: 'address',
          label: 'Proof of address uploaded',
          completed: hasAddress,
        ),
      ],
      if (isInvestor && targetLevel.rank >= KycLevel.investor.rank)
        KycRequirementItem(
          id: 'compliance',
          label: 'Investor compliance declarations',
          completed: compliance.isComplete,
        ),
      if (targetLevel.rank >= KycLevel.enterprise.rank)
        KycRequirementItem(
          id: 'company',
          label: 'Corporate documents',
          completed: hasCorporate,
        ),
    ];

    final done = items.where((i) => i.completed).length;
    final percent =
        items.isEmpty ? 0 : ((done / items.length) * 100).round().clamp(0, 100);
    return KycProgress(percent: percent, requirements: items);
  }

  static int trustScore({
    required bool emailVerified,
    required bool phoneVerified,
    required KycLevel level,
    required KycStatus status,
    required bool mfaEnabled,
    required int approvedDocuments,
  }) {
    var score = 0;
    if (emailVerified) score += 15;
    if (phoneVerified) score += 15;
    score += (level.rank * 12).clamp(0, 48);
    if (status == KycStatus.approved) score += 15;
    if (status == KycStatus.partiallyApproved) score += 8;
    if (mfaEnabled) score += 10;
    score += (approvedDocuments * 3).clamp(0, 12);
    return score.clamp(0, 100);
  }

  static bool canSubmitForReview(KycProgress progress, KycLevel target) {
    if (target.rank <= KycLevel.basic.rank) {
      return progress.requirements
          .where((r) => r.id == 'email' || r.id == 'phone')
          .every((r) => r.completed);
    }
    return progress.missing.isEmpty;
  }
}

class KycHubSnapshot {
  const KycHubSnapshot({
    required this.userId,
    required this.status,
    required this.currentLevel,
    required this.targetLevel,
    required this.progress,
    required this.passport,
    required this.documents,
    required this.compliance,
    this.timeline = const [],
    this.reviewerNotes,
    this.submittedAt,
  });

  final String userId;
  final KycStatus status;
  final KycLevel currentLevel;
  final KycLevel targetLevel;
  final KycProgress progress;
  final DigitalVerificationPassport passport;
  final List<KycDocument> documents;
  final InvestorComplianceInfo compliance;
  final List<KycEvent> timeline;
  final String? reviewerNotes;
  final DateTime? submittedAt;
}
