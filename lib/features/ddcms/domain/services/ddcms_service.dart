import 'package:hdhomesproject/features/ddcms/domain/entities/ddcms_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Loads Document Command Center snapshot from Supabase (falls back to demo).
class DdcmsService {
  DdcmsService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  Future<DdcmsCommandCenterSnapshot> loadCommandCenter() async {
    final demo = DdcmsDemo.snapshot();
    final client = _client;
    if (client == null) return demo;

    try {
      List<DdcmsFolder> folders = demo.folders;
      try {
        final rows = await client
            .from('document_folders')
            .select()
            .order('sort_order')
            .limit(40);
        if (rows.isNotEmpty) {
          folders = rows
              .map(
                (e) =>
                    DdcmsFolder.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<DdcmsDocument> documents = demo.documents;
      try {
        final rows = await client
            .from('documents')
            .select()
            .order('updated_at', ascending: false)
            .limit(50);
        if (rows.isNotEmpty) {
          documents = rows
              .map(
                (e) => DdcmsDocument.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<DdcmsContract> contracts = demo.contracts;
      try {
        final rows = await client
            .from('contract_records')
            .select()
            .order('created_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          contracts = rows
              .map(
                (e) => DdcmsContract.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<DdcmsSignatureRequest> signatures = demo.signatures;
      try {
        final rows = await client
            .from('signature_requests')
            .select()
            .order('created_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          signatures = rows
              .map(
                (e) => DdcmsSignatureRequest.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<DdcmsApproval> approvals = demo.approvals;
      try {
        final rows = await client
            .from('document_approvals')
            .select()
            .order('created_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          approvals = rows
              .map(
                (e) =>
                    DdcmsApproval.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<DdcmsAsset> assets = demo.assets;
      try {
        final rows = await client
            .from('digital_assets')
            .select()
            .order('updated_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          assets = rows
              .map(
                (e) =>
                    DdcmsAsset.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<DdcmsOcrJob> ocrJobs = demo.ocrJobs;
      try {
        final rows = await client
            .from('ocr_processing_jobs')
            .select()
            .order('created_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          ocrJobs = rows
              .map(
                (e) =>
                    DdcmsOcrJob.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<DdcmsShare> shares = demo.shares;
      try {
        final rows = await client
            .from('document_shares')
            .select()
            .order('created_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          shares = rows
              .map(
                (e) =>
                    DdcmsShare.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<DdcmsRetentionPolicy> retention = demo.retention;
      try {
        final rows =
            await client.from('retention_policies').select().limit(20);
        if (rows.isNotEmpty) {
          retention = rows
              .map(
                (e) => DdcmsRetentionPolicy.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<DdcmsArchivalRecord> archival = demo.archival;
      try {
        final rows = await client
            .from('archival_records')
            .select()
            .order('created_at', ascending: false)
            .limit(20);
        if (rows.isNotEmpty) {
          archival = rows
              .map(
                (e) => DdcmsArchivalRecord.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<DdcmsAiInsight> aiInsights = demo.aiInsights;
      try {
        final rows = await client
            .from('document_ai_insights')
            .select()
            .order('created_at', ascending: false)
            .limit(20);
        if (rows.isNotEmpty) {
          aiInsights = rows
              .map(
                (e) => DdcmsAiInsight.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<DdcmsActivity> activities = demo.activities;
      try {
        final rows = await client
            .from('document_activity_logs')
            .select()
            .order('occurred_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          activities = rows
              .map(
                (e) => DdcmsActivity.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<DdcmsReport> reports = demo.reports;
      try {
        final rows = await client
            .from('document_reports')
            .select()
            .order('created_at', ascending: false)
            .limit(20);
        if (rows.isNotEmpty) {
          reports = rows
              .map(
                (e) =>
                    DdcmsReport.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      final kpis = _deriveKpis(
        documents: documents,
        contracts: contracts,
        signatures: signatures,
        approvals: approvals,
        ocrJobs: ocrJobs,
        assets: assets,
        archival: archival,
      );

      return DdcmsCommandCenterSnapshot(
        kpis: kpis,
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
    } catch (_) {
      return demo;
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
        .where((s) => {'pending', 'sent', 'partially_signed'}.contains(s.status))
        .length
        .toDouble();
    final pendingAppr =
        approvals.where((a) => a.status == 'pending').length.toDouble();
    final ocrQueue = ocrJobs
        .where((j) => j.status == 'queued' || j.status == 'processing')
        .length
        .toDouble();
    final activeContracts = contracts
        .where((c) => c.status == 'active' || c.status == 'pending_signature')
        .length
        .toDouble();
    final retentionAlerts =
        archival.where((a) => a.status == 'scheduled').length.toDouble();

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

  String generateIntelligenceBriefing(DdcmsCommandCenterSnapshot snap) {
    final pendingSig = snap.signatures
        .where((s) => {'pending', 'sent', 'partially_signed'}.contains(s.status))
        .length;
    final ocrQueue = snap.ocrJobs
        .where((j) => j.status == 'queued' || j.status == 'processing')
        .length;
    final retention = snap.archival.where((a) => a.status == 'scheduled').length;
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
