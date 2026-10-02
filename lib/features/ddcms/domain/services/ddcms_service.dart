import 'dart:typed_data';

import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/features/ddcms/domain/entities/ddcms_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A client or investor who can receive an issued document.
class DocumentRecipient {
  const DocumentRecipient({
    required this.id,
    required this.audience,
    required this.name,
    required this.email,
    required this.code,
  });

  final String id;

  /// `client` or `investor`.
  final String audience;
  final String name;
  final String email;
  final String code;

  String get kindLabel => audience == 'investor' ? 'Investor' : 'Client';

  /// Name when we have one, otherwise the code or email.
  String get displayName {
    if (name.isNotEmpty) return name;
    if (email.isNotEmpty) return email;
    if (code.isNotEmpty) return code;
    return kindLabel;
  }

  String get initials {
    final source = name.isNotEmpty ? name : displayName;
    final parts = source
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .toList();
    if (parts.isEmpty) return kindLabel.substring(0, 1);
    return parts.map((part) => part.substring(0, 1).toUpperCase()).join();
  }

  String get label {
    return [
      kindLabel,
      if (name.isNotEmpty) name,
      if (code.isNotEmpty) code,
      if (email.isNotEmpty) email,
    ].join(' · ');
  }

  String get searchText =>
      '${label.toLowerCase()} ${id.toLowerCase()} ${displayName.toLowerCase()}';

  factory DocumentRecipient.fromRow(
    Map<String, dynamic> row, {
    required String audience,
    required String codeColumn,
  }) {
    final profile = _asMap(row['profiles']);
    final preferred = _text(profile?['preferred_name']);
    final composed = [
      _text(profile?['first_name']),
      _text(profile?['last_name']),
    ].where((part) => part.isNotEmpty).join(' ');
    final rawName = preferred.isNotEmpty
        ? preferred
        : composed.isNotEmpty
        ? composed
        : _text(row['full_name']);
    final email = _text(row['email']).isNotEmpty
        ? _text(row['email'])
        : _text(profile?['email']);
    return DocumentRecipient(
      id: '${row['id']}',
      audience: audience,
      name: _titleCase(rawName),
      email: email,
      code: _text(row[codeColumn]),
    );
  }

  static Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is List && value.isNotEmpty && value.first is Map) {
      return Map<String, dynamic>.from(value.first as Map);
    }
    return null;
  }

  static String _text(Object? value) => '${value ?? ''}'.trim();

  static String _titleCase(String raw) {
    if (raw.isEmpty) return raw;
    return raw
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) {
          if (part.length == 1) return part.toUpperCase();
          return part[0].toUpperCase() + part.substring(1).toLowerCase();
        })
        .join(' ');
  }
}

/// Loads Document Command Center from Supabase — never invents demo rows when
/// the backend is configured.
class DdcmsService {
  DdcmsService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  static const enterpriseBucket = 'enterprise-documents';

  Future<DdcmsCommandCenterSnapshot> loadCommandCenter() async {
    final client = _client;
    if (client == null) {
      return DdcmsCommandCenterSnapshot.empty(
        fromRemote: false,
        loadedAt: DateTime.now(),
      );
    }

    try {
      final folders = await _safeList(() async {
        final rows = await client
            .from('document_folders')
            .select()
            .order('sort_order')
            .limit(80);
        return rows
            .map(
              (e) => DdcmsFolder.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
      });

      final documents = await _safeList(() async {
        final rows = await client
            .from('documents')
            .select()
            .neq('status', 'archived')
            .order('updated_at', ascending: false)
            .limit(200);
        return rows
            .map(
              (e) =>
                  DdcmsDocument.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
      });

      final contracts = await _safeList(() async {
        final rows = await client
            .from('contract_records')
            .select()
            .neq('status', 'cancelled')
            .order('created_at', ascending: false)
            .limit(100);
        return rows
            .map(
              (e) =>
                  DdcmsContract.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
      });

      final signatures = await _safeList(() async {
        final rows = await client
            .from('signature_requests')
            .select()
            .order('created_at', ascending: false)
            .limit(100);
        return rows
            .map(
              (e) => DdcmsSignatureRequest.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList();
      });

      final approvals = await _safeList(() async {
        final rows = await client
            .from('document_approvals')
            .select()
            .order('created_at', ascending: false)
            .limit(100);
        return rows
            .map(
              (e) =>
                  DdcmsApproval.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
      });

      final assets = await _safeList(() async {
        final rows = await client
            .from('digital_assets')
            .select()
            .order('updated_at', ascending: false)
            .limit(100);
        return rows
            .map(
              (e) => DdcmsAsset.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
      });

      final ocrJobs = await _safeList(() async {
        final rows = await client
            .from('ocr_processing_jobs')
            .select()
            .order('created_at', ascending: false)
            .limit(100);
        return rows
            .map(
              (e) => DdcmsOcrJob.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
      });

      final shares = await _safeList(() async {
        final rows = await client
            .from('document_shares')
            .select()
            .order('created_at', ascending: false)
            .limit(100);
        return rows
            .map(
              (e) => DdcmsShare.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
      });

      final retention = await _safeList(() async {
        final rows = await client.from('retention_policies').select().limit(40);
        return rows
            .map(
              (e) => DdcmsRetentionPolicy.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList();
      });

      final archival = await _safeList(() async {
        final rows = await client
            .from('archival_records')
            .select()
            .order('created_at', ascending: false)
            .limit(40);
        return rows
            .map(
              (e) => DdcmsArchivalRecord.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList();
      });

      final aiInsights = await _safeList(() async {
        final rows = await client
            .from('document_ai_insights')
            .select()
            .order('created_at', ascending: false)
            .limit(40);
        return rows
            .map(
              (e) =>
                  DdcmsAiInsight.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
      });

      final activities = await _safeList(() async {
        final rows = await client
            .from('document_activity_logs')
            .select()
            .order('occurred_at', ascending: false)
            .limit(60);
        return rows
            .map(
              (e) =>
                  DdcmsActivity.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
      });

      final reports = await _safeList(() async {
        final rows = await client
            .from('document_reports')
            .select()
            .order('created_at', ascending: false)
            .limit(40);
        return rows
            .map(
              (e) => DdcmsReport.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
      });

      return DdcmsCommandCenterSnapshot(
        kpis: _deriveKpis(
          documents: documents,
          contracts: contracts,
          signatures: signatures,
          approvals: approvals,
          ocrJobs: ocrJobs,
          assets: assets,
          archival: archival,
        ),
        folders: folders,
        documents: documents,
        contracts: contracts,
        signatures: signatures,
        approvals: approvals,
        assets: assets,
        ocrJobs: ocrJobs,
        shares: shares,
        retention: retention,
        archival: archival,
        aiInsights: aiInsights,
        activities: activities,
        reports: reports,
        fromRemote: true,
        loadedAt: DateTime.now(),
      );
    } catch (e) {
      throw mapToAppException(e);
    }
  }

  Future<List<T>> _safeList<T>(Future<List<T>> Function() load) async {
    try {
      return await load();
    } catch (_) {
      return const [];
    }
  }

  Future<String> issueToRecipient({
    required String audience,
    required String targetId,
    required String title,
    required String fileName,
    required List<int> bytes,
    String documentType = 'allocation',
    String? description,
  }) async {
    if (audience == 'investor') {
      return issueToInvestor(
        investorId: targetId,
        title: title,
        fileName: fileName,
        bytes: bytes,
        documentType: documentType,
        description: description,
      );
    }
    return issueToClient(
      clientId: targetId,
      title: title,
      fileName: fileName,
      bytes: bytes,
      documentType: documentType,
      description: description,
    );
  }

  Future<String> issueToInvestor({
    required String investorId,
    required String title,
    required String fileName,
    required List<int> bytes,
    String documentType = 'allocation',
    String? description,
  }) async {
    final documentId = await uploadDocument(
      title: title,
      fileName: fileName,
      bytes: bytes,
      description: description,
      category: documentType,
      status: 'published',
      sensitivity: documentType == 'allocation' || documentType == 'contract'
          ? 'confidential'
          : 'internal',
    );
    await publishToInvestor(
      documentId: documentId,
      investorId: investorId,
      documentType: documentType,
      title: title,
    );
    return documentId;
  }

  Future<String> issueToClient({
    required String clientId,
    required String title,
    required String fileName,
    required List<int> bytes,
    String documentType = 'allocation',
    String? description,
  }) async {
    final documentId = await uploadDocument(
      title: title,
      fileName: fileName,
      bytes: bytes,
      description: description,
      category: documentType,
      status: 'published',
      sensitivity: documentType == 'allocation' || documentType == 'contract'
          ? 'confidential'
          : 'internal',
    );
    await publishToClient(
      documentId: documentId,
      clientId: clientId,
      documentType: documentType,
      title: title,
    );
    return documentId;
  }

  Future<String> uploadDocument({
    required String title,
    required String fileName,
    required List<int> bytes,
    String? description,
    String status = 'published',
    String sensitivity = 'internal',
    String? category,
    String? folderId,
  }) async {
    final client = _client;
    if (client == null) {
      throw const DatabaseException('Supabase is not configured');
    }

    final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final path = 'vault/$stamp-$safeName';
    final mime = _guessMime(fileName);

    await client.storage
        .from(enterpriseBucket)
        .uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: FileOptions(upsert: true, contentType: mime),
        );

    final code =
        'DOC-${DateTime.now().year}-${stamp.toString().substring(stamp.toString().length - 4)}';

    final row = await client
        .from('documents')
        .insert({
          'title': title.trim(),
          'code': code,
          'description': description?.trim(),
          'status': status,
          'mime_type': mime,
          'file_name': fileName,
          'storage_bucket': enterpriseBucket,
          'storage_path': path,
          'current_version': 1,
          'owner_label': 'Admin',
          'sensitivity': sensitivity,
          'folder_id': folderId,
          'metadata': {
            if (category != null && category.isNotEmpty) 'category': category,
          },
          'tags': category == null || category.isEmpty ? [] : [category],
        })
        .select('id')
        .single();

    try {
      await client.from('document_activity_logs').insert({
        'document_id': row['id'],
        'action': 'uploaded',
        'summary': 'Document uploaded to enterprise vault',
        'actor_label': 'Admin',
        'occurred_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {}

    return '${row['id']}';
  }

  Future<void> updateDocumentStatus(String id, String status) async {
    final client = _client;
    if (client == null) {
      throw const DatabaseException('Supabase is not configured');
    }
    await client
        .from('documents')
        .update({
          'status': status,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id);
  }

  Future<String> resolveDocumentUrl(DdcmsDocument doc) async {
    final client = _client;
    if (client == null) {
      throw const DatabaseException('Supabase is not configured');
    }
    final bucket = doc.storageBucket;
    final path = doc.storagePath;
    if (bucket == null || path == null || path.isEmpty) {
      throw const DatabaseException(
        'This document has no file attached yet. Upload a file first.',
      );
    }
    return client.storage.from(bucket).createSignedUrl(path, 3600);
  }

  Future<String> publishToClient({
    required String documentId,
    required String clientId,
    String documentType = 'shared',
    String? title,
  }) async {
    final client = _client;
    if (client == null) {
      throw const DatabaseException('Supabase is not configured');
    }
    final result = await client.rpc(
      'admin_publish_document_to_client',
      params: {
        'p_document_id': documentId,
        'p_client_id': clientId,
        'p_document_type': documentType,
        'p_title': title,
      },
    );
    return '$result';
  }

  Future<String> publishToInvestor({
    required String documentId,
    required String investorId,
    String documentType = 'shared',
    String? title,
  }) async {
    final client = _client;
    if (client == null) {
      throw const DatabaseException('Supabase is not configured');
    }
    final result = await client.rpc(
      'admin_publish_document_to_investor',
      params: {
        'p_document_id': documentId,
        'p_investor_id': investorId,
        'p_document_type': documentType,
        'p_title': title,
      },
    );
    return '$result';
  }

  Future<List<({String id, String label})>> listClientsForPublish() async {
    final people = await listRecipients(
      includeClients: true,
      includeInvestors: false,
    );
    return [for (final person in people) (id: person.id, label: person.label)];
  }

  Future<List<({String id, String label})>> listInvestorsForPublish() async {
    final people = await listRecipients(
      includeClients: false,
      includeInvestors: true,
    );
    return [for (final person in people) (id: person.id, label: person.label)];
  }

  /// Clients and investors that can receive an issued document.
  /// Labels include name, email, and code so staff can search.
  Future<List<DocumentRecipient>> listRecipients({
    required bool includeClients,
    required bool includeInvestors,
  }) async {
    final people = <DocumentRecipient>[];
    if (includeClients) {
      people.addAll(
        await _loadParty(
          table: 'clients',
          audience: 'client',
          codeColumn: 'client_code',
        ),
      );
    }
    if (includeInvestors) {
      people.addAll(
        await _loadParty(
          table: 'investors',
          audience: 'investor',
          codeColumn: 'investor_code',
        ),
      );
    }
    people.sort(
      (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
    );
    return people;
  }

  Future<List<DocumentRecipient>> _loadParty({
    required String table,
    required String audience,
    required String codeColumn,
  }) async {
    final client = _client;
    if (client == null) return const [];
    try {
      final rows = await _selectPartyRows(
        client: client,
        table: table,
        codeColumn: codeColumn,
        withProfile: audience == 'client',
      );
      return [
        for (final raw in rows)
          DocumentRecipient.fromRow(
            Map<String, dynamic>.from(raw as Map),
            audience: audience,
            codeColumn: codeColumn,
          ),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Clients keep their name on `profiles`, not on the clients row.
  Future<List<dynamic>> _selectPartyRows({
    required SupabaseClient client,
    required String table,
    required String codeColumn,
    required bool withProfile,
  }) async {
    if (withProfile) {
      final select =
          '''
        id, $codeColumn,
        profiles:user_id (
          preferred_name, first_name, last_name, email
        )
      ''';
      try {
        return await client
            .from(table)
            .select(select)
            .eq('is_deleted', false)
            .order('created_at', ascending: false)
            .limit(200);
      } catch (_) {
        try {
          return await client
              .from(table)
              .select(select)
              .order('created_at', ascending: false)
              .limit(200);
        } catch (_) {
          // Schema or RLS drift — fall through to a bare select.
        }
      }
    }
    try {
      return await client
          .from(table)
          .select('id, $codeColumn, full_name, email')
          .order('created_at', ascending: false)
          .limit(200);
    } catch (_) {
      return client
          .from(table)
          .select('id, $codeColumn')
          .order('created_at', ascending: false)
          .limit(200);
    }
  }

  List<DdcmsKpi> _deriveKpis({
    required List<DdcmsDocument> documents,
    required List<DdcmsContract> contracts,
    required List<DdcmsSignatureRequest> signatures,
    required List<DdcmsApproval> approvals,
    required List<DdcmsOcrJob> ocrJobs,
    required List<DdcmsAsset> assets,
    required List<DdcmsArchivalRecord> archival,
  }) {
    final activeDocs = documents
        .where((d) => !{'archived', 'expired'}.contains(d.status))
        .length
        .toDouble();
    final pendingSig = signatures
        .where(
          (s) => {'pending', 'sent', 'partially_signed'}.contains(s.status),
        )
        .length
        .toDouble();
    final pendingAppr = approvals
        .where((a) => a.status == 'pending')
        .length
        .toDouble();
    final ocrQueue = ocrJobs
        .where((j) => j.status == 'queued' || j.status == 'processing')
        .length
        .toDouble();
    final activeContracts = contracts
        .where((c) => c.status == 'active' || c.status == 'pending_signature')
        .length
        .toDouble();
    final retentionAlerts = archival
        .where((a) => a.status == 'scheduled')
        .length
        .toDouble();

    return [
      DdcmsKpi(label: 'Active Docs', value: activeDocs),
      DdcmsKpi(label: 'Contracts', value: activeContracts),
      DdcmsKpi(
        label: 'Pending Signatures',
        value: pendingSig,
        status: pendingSig > 0 ? 'watch' : 'ok',
      ),
      DdcmsKpi(
        label: 'Approvals',
        value: pendingAppr,
        status: pendingAppr > 0 ? 'watch' : 'ok',
      ),
      DdcmsKpi(label: 'OCR Queue', value: ocrQueue),
      DdcmsKpi(label: 'DAM Assets', value: assets.length.toDouble()),
      DdcmsKpi(
        label: 'Retention Alerts',
        value: retentionAlerts,
        status: retentionAlerts > 0 ? 'watch' : 'ok',
      ),
    ];
  }

  String _guessMime(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.doc')) return 'application/msword';
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (lower.endsWith('.xls') || lower.endsWith('.xlsx')) {
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    }
    return 'application/octet-stream';
  }

  String generateIntelligenceBriefing(DdcmsCommandCenterSnapshot snap) {
    final pendingSig = snap.signatures
        .where(
          (s) => {'pending', 'sent', 'partially_signed'}.contains(s.status),
        )
        .length;
    final ocrQueue = snap.ocrJobs
        .where((j) => j.status == 'queued' || j.status == 'processing')
        .length;
    final retention = snap.archival
        .where((a) => a.status == 'scheduled')
        .length;
    return 'Smart Document Intelligence™ advisory brief: '
        '$pendingSig pending signature(s), $ocrQueue OCR job(s) in queue, '
        '$retention retention alert(s). Prioritize buyer signature on open '
        'sale agreements and month-end invoice OCR. ${snap.aiDisclaimer}';
  }

  static List<String> detectDocumentSignals(DdcmsCommandCenterSnapshot snap) {
    final signals = <String>[];
    if (snap.signatures.any(
      (s) => {'pending', 'sent', 'partially_signed'}.contains(s.status),
    )) {
      signals.add('Pending digital signatures require follow-up');
    }
    if (snap.approvals.any((a) => a.status == 'pending')) {
      signals.add('Document approvals waiting on decision');
    }
    if (snap.ocrJobs.any((j) => j.status == 'queued')) {
      signals.add('OCR queue has unstarted jobs');
    }
    if (snap.archival.any((a) => a.status == 'scheduled')) {
      signals.add('Retention / archival alerts scheduled');
    }
    return signals;
  }
}
