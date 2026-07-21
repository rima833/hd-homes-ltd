import 'package:flutter/foundation.dart';
import 'package:hdhomesproject/core/auth/models/security_event.dart';
import 'package:hdhomesproject/core/auth/services/security_service.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/app_role.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/kyc_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Enterprise KYC & Identity Verification — metadata in Postgres, files in private storage.
class KycService {
  KycService({
    required SecurityService security,
    SupabaseClient? client,
  })  : _security = security,
        _client = client;

  final SecurityService _security;
  final SupabaseClient? _client;

  static const bucket = 'kyc-documents';
  static const maxBytes = 10 * 1024 * 1024; // 10 MB
  static const allowedMime = {
    'image/jpeg',
    'image/png',
    'image/webp',
    'application/pdf',
  };

  bool get isConfigured => _client != null;

  Future<KycHubSnapshot> loadHub({
    required AppRole? role,
    required bool emailVerified,
    required bool phoneVerified,
    required bool mfaEnabled,
  }) async {
    final client = _client;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) {
      throw const AuthenticationException('Sign in to manage KYC.');
    }

    final profile = await _ensureKycProfile(userId, role);
    final docs = await listDocuments(userId);
    final compliance = await _fetchCompliance(userId);
    final timeline = await _fetchEvents(userId);
    final target = KycLevel.targetForRole(role);
    final current = KycLevel.fromRank(profile['current_level'] as int?);
    final status = KycStatus.fromSlug(profile['status'] as String?);
    final isInvestor = role == AppRole.investor;

    final progress = IntelligentVerificationEngine.evaluateProgress(
      emailVerified: emailVerified,
      phoneVerified: phoneVerified,
      documents: docs,
      compliance: compliance,
      targetLevel: target,
      isInvestor: isInvestor,
    );

    final approvedCount =
        docs.where((d) => d.status == KycDocumentStatus.approved).length;
    final trust = IntelligentVerificationEngine.trustScore(
      emailVerified: emailVerified,
      phoneVerified: phoneVerified,
      level: current,
      status: status,
      mfaEnabled: mfaEnabled,
      approvedDocuments: approvedCount,
    );

    final passport = DigitalVerificationPassport(
      userId: userId,
      level: current,
      status: status,
      trustScore: trust,
      verifiedDocumentTypes: docs
          .where((d) => d.status == KycDocumentStatus.approved)
          .map((d) => d.documentType)
          .toSet()
          .toList(),
      verifiedAt: profile['verified_at'] != null
          ? DateTime.tryParse(profile['verified_at'] as String)
          : null,
      expiresAt: profile['expires_at'] != null
          ? DateTime.tryParse(profile['expires_at'] as String)
          : null,
      complianceStatus: status.isTerminalSuccess ? 'compliant' : 'incomplete',
    );

    return KycHubSnapshot(
      userId: userId,
      status: status,
      currentLevel: current,
      targetLevel: target,
      progress: progress,
      passport: passport,
      documents: docs,
      compliance: compliance,
      timeline: timeline,
      reviewerNotes: profile['reviewer_notes'] as String?,
      submittedAt: profile['submitted_at'] != null
          ? DateTime.tryParse(profile['submitted_at'] as String)
          : null,
    );
  }

  Future<List<KycDocument>> listDocuments(String userId) async {
    final client = _client;
    if (client == null) return const [];
    try {
      final rows = await client
          .from('kyc_documents')
          .select()
          .eq('user_id', userId)
          .neq('status', 'replaced')
          .order('created_at', ascending: false);
      final docs = <KycDocument>[];
      for (final raw in rows as List) {
        final map = Map<String, dynamic>.from(raw as Map);
        String? url;
        try {
          url = await client.storage.from(bucket).createSignedUrl(
                map['storage_path'] as String,
                3600,
              );
        } catch (_) {}
        docs.add(KycDocument.fromJson(map, signedUrl: url));
      }
      return docs;
    } catch (_) {
      return const [];
    }
  }

  Future<KycDocument> uploadDocument({
    required String userId,
    required KycDocumentType type,
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    final client = _client;
    if (client == null) {
      throw const AuthenticationException('Authentication is not configured.');
    }
    if (bytes.length > maxBytes) {
      throw const ValidationException('File exceeds the 10 MB limit.');
    }
    if (!allowedMime.contains(mimeType)) {
      throw const ValidationException(
        'Unsupported file type. Use JPEG, PNG, WEBP, or PDF.',
      );
    }

    final ext = switch (mimeType) {
      'application/pdf' => 'pdf',
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
    final path =
        '$userId/${type.slug}_${DateTime.now().millisecondsSinceEpoch}.$ext';

    try {
      await client.storage.from(bucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(upsert: false, contentType: mimeType),
          );
    } catch (_) {
      throw const ValidationException(
        'Unable to upload document. Ensure the KYC storage bucket is configured.',
      );
    }

    // Mark previous same-type drafts as replaced
    try {
      await client
          .from('kyc_documents')
          .update({'status': KycDocumentStatus.replaced.slug})
          .eq('user_id', userId)
          .eq('document_type', type.slug)
          .inFilter('status', [
            KycDocumentStatus.uploaded.slug,
            KycDocumentStatus.draft.slug,
            KycDocumentStatus.rejected.slug,
          ]);
    } catch (_) {}

    final row = await client.from('kyc_documents').insert({
      'user_id': userId,
      'document_type': type.slug,
      'storage_path': path,
      'file_name': fileName,
      'mime_type': mimeType,
      'file_size_bytes': bytes.length,
      'status': KycDocumentStatus.uploaded.slug,
    }).select().single();

    await _setStatus(userId, KycStatus.inProgress);
    await _audit(userId, 'document_uploaded', {'document_type': type.slug});

    String? url;
    try {
      url = await client.storage.from(bucket).createSignedUrl(path, 3600);
    } catch (_) {}
    return KycDocument.fromJson(Map<String, dynamic>.from(row), signedUrl: url);
  }

  Future<void> deleteDraftDocument({
    required String userId,
    required String documentId,
  }) async {
    final client = _client;
    if (client == null) return;
    final row = await client
        .from('kyc_documents')
        .select()
        .eq('id', documentId)
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return;
    final status = KycDocumentStatus.fromSlug(row['status'] as String?);
    if (status != KycDocumentStatus.uploaded &&
        status != KycDocumentStatus.draft &&
        status != KycDocumentStatus.rejected) {
      throw const ValidationException(
        'Submitted documents cannot be deleted. Request resubmission instead.',
      );
    }
    final path = row['storage_path'] as String;
    try {
      await client.storage.from(bucket).remove([path]);
    } catch (_) {}
    await client.from('kyc_documents').delete().eq('id', documentId);
    await _audit(userId, 'document_deleted', {'document_id': documentId});
  }

  Future<void> saveCompliance(String userId, InvestorComplianceInfo info) async {
    final client = _client;
    if (client == null) return;
    await client.from('investor_compliance').upsert(info.toUpsertMap(userId));
    await _audit(userId, 'compliance_updated', {});
  }

  Future<void> submitForReview(String userId, {required KycLevel target}) async {
    final client = _client;
    if (client == null) return;
    await client.from('kyc_documents').update({
      'status': KycDocumentStatus.submitted.slug,
    }).eq('user_id', userId).inFilter('status', [
      KycDocumentStatus.uploaded.slug,
      KycDocumentStatus.draft.slug,
    ]);

    await client.from('kyc_profiles').upsert({
      'user_id': userId,
      'status': KycStatus.underReview.slug,
      'target_level': target.rank,
      'submitted_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });

    await client.from('verification_requests').insert({
      'user_id': userId,
      'target_level': target.rank,
      'status': KycStatus.underReview.slug,
    });

    await _audit(userId, 'submitted_for_review', {'target_level': target.rank});
  }

  Future<List<KycReviewQueueItem>> loadReviewQueue() async {
    final client = _client;
    if (client == null) return const [];
    try {
      final rows = await client
          .from('kyc_profiles')
          .select(
            'user_id, status, current_level, target_level, submitted_at, priority, '
            'profiles!inner(email, first_name, last_name)',
          )
          .inFilter('status', [
            KycStatus.underReview.slug,
            KycStatus.awaitingDocuments.slug,
            KycStatus.needsResubmission.slug,
          ])
          .order('priority', ascending: false)
          .order('submitted_at', ascending: true);
      final items = <KycReviewQueueItem>[];
      for (final raw in rows as List) {
        final map = Map<String, dynamic>.from(raw as Map);
        final profile = Map<String, dynamic>.from(map['profiles'] as Map? ?? {});
        final docs = await client
            .from('kyc_documents')
            .select('id')
            .eq('user_id', map['user_id'])
            .neq('status', 'replaced');
        final name = [
          profile['first_name'],
          profile['last_name'],
        ].whereType<String>().join(' ');
        items.add(
          KycReviewQueueItem(
            userId: map['user_id'] as String,
            status: KycStatus.fromSlug(map['status'] as String?),
            level: KycLevel.fromRank(
              (map['target_level'] as int?) ?? (map['current_level'] as int?),
            ),
            email: profile['email'] as String?,
            displayName: name.isEmpty ? null : name,
            submittedAt: map['submitted_at'] != null
                ? DateTime.tryParse(map['submitted_at'] as String)
                : null,
            documentCount: (docs as List).length,
            priority: map['priority'] as int? ?? 0,
          ),
        );
      }
      return items;
    } catch (_) {
      return const [];
    }
  }

  Future<void> reviewSubmission({
    required String userId,
    required KycReviewDecision decision,
    required String notes,
    required int approveLevel,
    String? reviewerId,
  }) async {
    final client = _client;
    if (client == null) return;

    final newStatus = switch (decision) {
      KycReviewDecision.approved => KycStatus.approved,
      KycReviewDecision.needsMoreInfo ||
      KycReviewDecision.needsBetterImage =>
        KycStatus.needsResubmission,
      KycReviewDecision.expired => KycStatus.expired,
      KycReviewDecision.duplicate ||
      KycReviewDecision.potentialFraud ||
      KycReviewDecision.rejected =>
        KycStatus.rejected,
    };

    final docStatus = decision == KycReviewDecision.approved
        ? KycDocumentStatus.approved
        : (newStatus == KycStatus.needsResubmission
            ? KycDocumentStatus.rejected
            : KycDocumentStatus.rejected);

    await client.from('kyc_documents').update({
      'status': docStatus.slug,
      'review_notes': notes,
      'reviewed_at': DateTime.now().toUtc().toIso8601String(),
      'reviewed_by': reviewerId,
    }).eq('user_id', userId).inFilter('status', [
      KycDocumentStatus.submitted.slug,
      KycDocumentStatus.underReview.slug,
      KycDocumentStatus.uploaded.slug,
    ]);

    await client.from('document_reviews').insert({
      'user_id': userId,
      'reviewer_id': reviewerId,
      'decision': decision.slug,
      'notes': notes,
      'approved_level':
          decision == KycReviewDecision.approved ? approveLevel : null,
    });

    await client.from('kyc_profiles').update({
      'status': newStatus.slug,
      if (decision == KycReviewDecision.approved) 'current_level': approveLevel,
      'reviewer_notes': notes,
      'reviewed_at': DateTime.now().toUtc().toIso8601String(),
      'reviewed_by': reviewerId,
      if (decision == KycReviewDecision.approved)
        'verified_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('user_id', userId);

    await _audit(userId, 'review_${decision.slug}', {
      'notes': notes,
      'reviewer_id': reviewerId,
    });
  }

  Future<Map<String, dynamic>> _ensureKycProfile(
    String userId,
    AppRole? role,
  ) async {
    final client = _client!;
    try {
      final existing = await client
          .from('kyc_profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (existing != null) return Map<String, dynamic>.from(existing);
      final target = KycLevel.targetForRole(role).rank;
      final inserted = await client.from('kyc_profiles').insert({
        'user_id': userId,
        'status': KycStatus.pending.slug,
        'current_level': 0,
        'target_level': target,
      }).select().single();
      await _audit(userId, 'kyc_started', {'target_level': target});
      return Map<String, dynamic>.from(inserted);
    } catch (_) {
      return {
        'user_id': userId,
        'status': 'pending',
        'current_level': 0,
        'target_level': KycLevel.targetForRole(role).rank,
      };
    }
  }

  Future<void> _setStatus(String userId, KycStatus status) async {
    final client = _client;
    if (client == null) return;
    try {
      await client.from('kyc_profiles').update({
        'status': status.slug,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('user_id', userId);
    } catch (_) {}
  }

  Future<InvestorComplianceInfo> _fetchCompliance(String userId) async {
    final client = _client!;
    try {
      final row = await client
          .from('investor_compliance')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      return InvestorComplianceInfo.fromJson(
        row == null ? null : Map<String, dynamic>.from(row),
      );
    } catch (_) {
      return const InvestorComplianceInfo();
    }
  }

  Future<List<KycEvent>> _fetchEvents(String userId) async {
    final client = _client!;
    try {
      final rows = await client
          .from('kyc_events')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(30);
      return (rows as List)
          .map((r) => KycEvent.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _audit(
    String userId,
    String action,
    Map<String, dynamic> metadata,
  ) async {
    _security.record(
      SecurityEvent(
        type: SecurityEventType.profileUpdated,
        timestamp: DateTime.now(),
        userId: userId,
        userAgent: kIsWeb ? 'web' : defaultTargetPlatform.name,
        metadata: {'action': action, 'module': 'kyc', ...metadata},
      ),
    );
    final client = _client;
    if (client == null) return;
    // ignore: unawaited_futures
    client.from('kyc_events').insert({
      'user_id': userId,
      'actor_id': client.auth.currentUser?.id,
      'event_type': action,
      'metadata': metadata,
      'user_agent': kIsWeb ? 'web' : defaultTargetPlatform.name,
    }).then((_) {}, onError: (_) {});
  }
}
