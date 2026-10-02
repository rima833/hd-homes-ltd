import 'dart:convert';

import 'package:hdhomesproject/features/investor/domain/entities/investor_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Investor portal service — all Supabase reads/writes for Investor Portal.
class InvestorService {
  InvestorService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  static const _holdingSelect = '''
    *,
    properties (
      id, title, slug,
      property_locations (city, state),
      property_images (url, is_cover)
    )
  ''';

  String _requireAuthUserId() {
    final uid = _client?.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('Not authenticated');
    }
    return uid;
  }

  Future<void> _requireApprovedInvestorKyc() async {
    final uid = _requireAuthUserId();
    final row = await _client!
        .from('investors')
        .select('kyc_status')
        .eq('user_id', uid)
        .maybeSingle();
    final status = (row?['kyc_status'] as String? ?? '').toLowerCase();
    if (status == 'approved' ||
        status == 'verified' ||
        status == 'partially_approved') {
      return;
    }
    throw StateError(
      'Finish identity verification before you submit a bank transfer. Open Settings and complete KYC.',
    );
  }

  Map<String, dynamic>? _coerceRowMap(dynamic row) {
    if (row == null) return null;
    if (row is Map<String, dynamic>) return row;
    if (row is Map) return Map<String, dynamic>.from(row);
    if (row is List && row.isNotEmpty) return _coerceRowMap(row.first);
    if (row is String) {
      try {
        return _coerceRowMap(jsonDecode(row));
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Ensures an [investors] row exists for the signed-in Supabase user.
  Future<InvestorRecord> ensureInvestor() async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase is not configured');
    }
    final authUserId = _requireAuthUserId();

    Future<InvestorRecord?> readOwn() async {
      final existing = await client
          .from('investors')
          .select()
          .eq('user_id', authUserId)
          .eq('is_deleted', false)
          .maybeSingle();
      if (existing == null) return null;
      return InvestorRecord.fromJson(Map<String, dynamic>.from(existing));
    }

    final already = await readOwn();
    if (already != null) return already;

    try {
      final row = await client.rpc('ensure_investor_record');
      final map = _coerceRowMap(row);
      if (map != null && map['id'] != null) {
        return InvestorRecord.fromJson(map);
      }
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('investor_not_provisioned')) {
        throw StateError(
          'Your investor account has not been provisioned yet. '
          'Please contact HD Homes support.',
        );
      }
      // Fall through to a final read — never raw INSERT from the app.
    }

    final afterRpc = await readOwn();
    if (afterRpc != null) return afterRpc;

    throw StateError(
      'Could not resolve your investor account. Please sign out and sign in again.',
    );
  }

  Future<String?> _portfolioIdForInvestor(String investorId) async {
    final row = await _client!
        .from('investor_portfolios')
        .select('id')
        .eq('investor_id', investorId)
        .maybeSingle();
    return row?['id'] as String?;
  }

  Future<InvestorDashboardSnapshot> loadDashboard({
    required String displayName,
    int unreadNotifications = 0,
  }) async {
    final record = await ensureInvestor();
    final holdings = await listHoldings(record.id);
    final distributions = await listDistributions(record.id);
    final activity = await listActivity(record.id, limit: 8);
    final performance = await listPerformance(record.id, limit: 6);
    final wallets = await listWallet(record.id);
    final intents = await listPaymentIntents(record.id);
    final commitments = await listCommitments();

    final portfolioValue = holdings.fold<double>(
      0,
      (sum, h) => sum + h.currentValue,
    );
    final totalInvested = holdings.fold<double>(
      0,
      (sum, h) => sum + h.costBasis,
    );
    final totalReturns = portfolioValue - totalInvested;
    final paid = distributions
        .where((d) => d.status == 'paid')
        .fold<double>(0, (sum, d) => sum + d.amount);
    final pending = distributions
        .where((d) => d.status == 'scheduled' || d.status == 'processing')
        .fold<double>(0, (sum, d) => sum + d.amount);
    final outstanding = intents
        .where(
          (i) =>
              i.status == 'pending' ||
              i.status == 'awaiting_confirmation' ||
              i.status == 'submitted',
        )
        .fold<double>(0, (sum, i) => sum + i.amount);
    final wallet = wallets.isNotEmpty ? wallets.first : null;
    final walletAvailable = wallet?.availableBalance ?? 0;

    final kyc = record.kycStatus.toLowerCase();
    final String portfolioStatus;
    if (holdings.isEmpty) {
      portfolioStatus = 'empty';
    } else if (outstanding > 0) {
      portfolioStatus = 'attention';
    } else if (kyc == 'pending' ||
        kyc == 'rejected' ||
        kyc == 'expired' ||
        kyc == 'requires_action') {
      portfolioStatus = 'kyc';
    } else {
      portfolioStatus = 'active';
    }

    return InvestorDashboardSnapshot(
      investor: record,
      displayName: displayName,
      holdingsCount: holdings.length,
      portfolioValue: portfolioValue,
      totalInvested: totalInvested,
      totalReturns: totalReturns,
      totalDistributions: paid,
      pendingDistributions: pending,
      outstandingPayments: outstanding,
      walletAvailable: walletAvailable,
      unreadNotifications: unreadNotifications,
      kycStatus: record.kycStatus,
      portfolioStatus: portfolioStatus,
      holdings: holdings,
      recentActivity: activity,
      recentDistributions: distributions.take(6).toList(),
      recentPerformance: performance,
      commitments: commitments,
      wallet: wallet,
      loadedAt: DateTime.now(),
    );
  }

  Future<List<InvestorCommitment>> listCommitments() async {
    final raw = await _client!.rpc('investor_portal_commitments');
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (row) =>
              InvestorCommitment.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  Future<List<InvestorHolding>> listHoldings(String investorId) async {
    final portfolioId = await _portfolioIdForInvestor(investorId);
    if (portfolioId == null) return [];

    try {
      final rows = await _client!
          .from('portfolio_holdings')
          .select(_holdingSelect)
          .eq('portfolio_id', portfolioId)
          .order('created_at', ascending: false);
      return rows
          .map((e) => InvestorHolding.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      final rows = await _client!
          .from('portfolio_holdings')
          .select()
          .eq('portfolio_id', portfolioId)
          .order('created_at', ascending: false);
      return rows
          .map((e) => InvestorHolding.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
  }

  Future<InvestorHolding?> getHolding(
    String investorId,
    String holdingId,
  ) async {
    final portfolioId = await _portfolioIdForInvestor(investorId);
    if (portfolioId == null) return null;

    try {
      final row = await _client!
          .from('portfolio_holdings')
          .select(_holdingSelect)
          .eq('id', holdingId)
          .eq('portfolio_id', portfolioId)
          .maybeSingle();
      if (row == null) return null;
      return InvestorHolding.fromJson(Map<String, dynamic>.from(row));
    } catch (_) {
      final row = await _client!
          .from('portfolio_holdings')
          .select()
          .eq('id', holdingId)
          .eq('portfolio_id', portfolioId)
          .maybeSingle();
      if (row == null) return null;
      return InvestorHolding.fromJson(Map<String, dynamic>.from(row));
    }
  }

  /// Full investment workspace for one holding (portfolio detail).
  Future<InvestorHoldingDetail?> loadHoldingDetail(
    String investorId,
    String holdingId,
  ) async {
    final holding = await getHolding(investorId, holdingId);
    if (holding == null) return null;

    final distributions = await listDistributions(investorId);
    final relatedDistributions = distributions.where((d) {
      if (d.portfolioId != null && d.portfolioId == holding.portfolioId) {
        return true;
      }
      if (holding.opportunityId != null &&
          d.opportunityId == holding.opportunityId) {
        return true;
      }
      final metaHolding = d.metadata['holding_id'] as String?;
      final metaProperty = d.metadata['property_id'] as String?;
      if (metaHolding == holding.id) return true;
      if (holding.propertyId != null && metaProperty == holding.propertyId) {
        return true;
      }
      return false;
    }).toList();

    final allHoldings = await listHoldings(investorId);
    final scopedDistributions = relatedDistributions.isNotEmpty
        ? relatedDistributions
        : (allHoldings.length <= 1 ? distributions : <InvestorDistribution>[]);

    final documents = await listDocuments(investorId);
    var relatedDocs = documents.where((doc) {
      if (doc.holdingId == holding.id) return true;
      if (holding.propertyId != null && doc.propertyId == holding.propertyId) {
        return true;
      }
      final title = doc.title.toLowerCase();
      final development = holding.developmentName?.toLowerCase();
      if (development != null &&
          development.isNotEmpty &&
          title.contains(development)) {
        return true;
      }
      final stem = holding.label
          .toLowerCase()
          .split(RegExp(r'[—–-]'))
          .first
          .trim();
      return stem.isNotEmpty && title.contains(stem);
    }).toList();
    if (relatedDocs.isEmpty && allHoldings.length <= 1) {
      relatedDocs = documents;
    }

    final intents = await listPaymentIntents(investorId);
    final relatedIntents = intents.where((intent) {
      final meta = intent.metadata;
      if (meta['holding_id'] == holding.id) return true;
      if (holding.propertyId != null &&
          meta['property_id'] == holding.propertyId) {
        return true;
      }
      return allHoldings.length <= 1;
    }).toList();

    final activity = await listActivity(investorId, limit: 40);
    final relatedActivity = activity.where((a) {
      final hay = '${a.title} ${a.description ?? ''}'.toLowerCase();
      final development = holding.developmentName?.toLowerCase();
      if (development != null &&
          development.isNotEmpty &&
          hay.contains(development)) {
        return true;
      }
      final stem = holding.label
          .toLowerCase()
          .split(RegExp(r'[—–-]'))
          .first
          .trim();
      return stem.isNotEmpty && hay.contains(stem);
    }).toList();
    final scopedActivity = relatedActivity.isNotEmpty
        ? relatedActivity
        : activity.take(8).toList();

    InvestorConstructionBundle? construction;
    try {
      final full = await loadConstruction(investorId);
      if (holding.propertyId == null) {
        construction = allHoldings.length <= 1 ? full : null;
      } else {
        construction = full.scopedToProperty(holding.propertyId);
      }
    } catch (_) {
      construction = null;
    }

    return InvestorHoldingDetail(
      holding: holding,
      distributions: scopedDistributions,
      documents: relatedDocs,
      paymentIntents: relatedIntents,
      activity: scopedActivity,
      construction: construction,
    );
  }

  Future<List<InvestorDistribution>> listDistributions(
    String investorId, {
    int limit = 100,
  }) async {
    final rows = await _client!
        .from('investment_distributions')
        .select()
        .eq('investor_id', investorId)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows
        .map((e) => InvestorDistribution.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<InvestorWallet>> listWallet(String investorId) async {
    final rows = await _client!
        .from('investor_wallets')
        .select()
        .eq('investor_id', investorId);
    return rows
        .map((e) => InvestorWallet.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<InvestorDocument>> listDocuments(
    String investorId, {
    int limit = 100,
  }) async {
    final rows = await _client!
        .from('investor_documents')
        .select()
        .eq('investor_id', investorId)
        .order('updated_at', ascending: false)
        .limit(limit);
    return rows
        .map((e) => InvestorDocument.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Resolves https / Cloudinary / storage://bucket/path / bucket/path into a usable URL.
  Future<String> resolveDocumentUrl(String raw) async {
    final value = raw.trim();
    if (value.isEmpty) {
      throw StateError('Document URL is empty');
    }
    final uri = Uri.tryParse(value);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      // Includes Cloudinary `res.cloudinary.com` delivery URLs.
      return value;
    }

    String bucket;
    String objectPath;
    if (value.startsWith('storage://')) {
      final stripped = value.substring('storage://'.length);
      final slash = stripped.indexOf('/');
      if (slash <= 0 || slash == stripped.length - 1) {
        throw StateError('Invalid storage URL format');
      }
      bucket = stripped.substring(0, slash);
      objectPath = stripped.substring(slash + 1);
    } else {
      final slash = value.indexOf('/');
      if (slash <= 0 || slash == value.length - 1) {
        throw StateError('Invalid document path format');
      }
      bucket = value.substring(0, slash);
      objectPath = value.substring(slash + 1);
    }

    return _client!.storage.from(bucket).createSignedUrl(objectPath, 3600);
  }

  /// Opens/downloads a vault document (current or historical version URL).
  Future<String> resolveInvestorDocumentUrl(
    InvestorDocument doc, {
    String? overrideFileUrl,
  }) async {
    final raw = (overrideFileUrl ?? doc.fileUrl)?.trim() ?? '';
    if (raw.isEmpty) {
      throw StateError('Document has no file attached');
    }
    if (doc.isExpired && overrideFileUrl == null) {
      throw StateError('This document has expired');
    }
    return resolveDocumentUrl(raw);
  }

  Future<List<InvestorReport>> listReports(
    String investorId, {
    int limit = 50,
  }) async {
    final rows = await _client!
        .from('investor_reports')
        .select()
        .eq('investor_id', investorId)
        .order('generated_at', ascending: false)
        .limit(limit);
    return rows
        .map((e) => InvestorReport.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<InvestorStatement>> listStatements(
    String investorId, {
    int limit = 50,
  }) async {
    final rows = await _client!
        .from('investor_statements')
        .select()
        .eq('investor_id', investorId)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows
        .map((e) => InvestorStatement.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<InvestorPerformance>> listPerformance(
    String investorId, {
    int limit = 24,
  }) async {
    final rows = await _client!
        .from('investment_performance')
        .select()
        .eq('investor_id', investorId)
        .order('as_of_date', ascending: false)
        .limit(limit);
    return rows
        .map((e) => InvestorPerformance.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Trusted aggregates from `investor_analytics_snapshot` (Phase 10).
  Future<InvestorAnalyticsSnapshot> loadAnalyticsSnapshot(
    String investorId, {
    int? months,
  }) async {
    final raw = await _client!.rpc(
      'investor_analytics_snapshot',
      params: {'p_investor_id': investorId, 'p_months': months},
    );
    if (raw is Map) {
      return InvestorAnalyticsSnapshot.fromJson(Map<String, dynamic>.from(raw));
    }
    if (raw is String) {
      // Unexpected string payload — treat as empty.
      return InvestorAnalyticsSnapshot(investorId: investorId, months: months);
    }
    return InvestorAnalyticsSnapshot(investorId: investorId, months: months);
  }

  Future<List<InvestorActivity>> listActivity(
    String investorId, {
    int limit = 30,
  }) async {
    final rows = await _client!
        .from('investor_activity_logs')
        .select()
        .eq('investor_id', investorId)
        .order('occurred_at', ascending: false)
        .limit(limit);
    return rows
        .map((e) => InvestorActivity.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<InvestorPortalNotification>> listNotifications(
    String investorId, {
    int limit = 100,
  }) async {
    final rows = await _client!
        .from('investor_notifications')
        .select()
        .eq('investor_id', investorId)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows
        .map(
          (e) =>
              InvestorPortalNotification.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList();
  }

  Future<void> markNotificationRead(String notificationId) async {
    await _client!.rpc(
      'investor_mark_notifications_read',
      params: {
        'p_notification_ids': [notificationId],
      },
    );
  }

  Future<int> markAllNotificationsRead() async {
    final count = await _client!.rpc(
      'investor_mark_notifications_read',
      params: {'p_notification_ids': null},
    );
    if (count is int) return count;
    if (count is num) return count.toInt();
    return int.tryParse('$count') ?? 0;
  }

  Future<InvestorConstructionBundle> loadConstruction(String investorId) async {
    final holdings = await listHoldings(investorId);
    final propertyIds = holdings
        .map((h) => h.propertyId)
        .whereType<String>()
        .toSet()
        .toList();
    if (propertyIds.isEmpty) {
      return const InvestorConstructionBundle();
    }

    try {
      final projectRows = await _client!
          .from('construction_projects')
          .select(
            'id, name, property_id, progress_pct, target_end_date, '
            'schedule_status, status, cover_image_url',
          )
          .inFilter('property_id', propertyIds)
          .order('name');

      if (projectRows.isEmpty) {
        return const InvestorConstructionBundle();
      }

      final projectIds = projectRows
          .map((p) => p['id'] as String)
          .toList(growable: false);
      final projectNameById = <String, String>{
        for (final p in projectRows)
          p['id'] as String: p['name'] as String? ?? 'Project',
      };
      final propertyByProject = <String, String?>{
        for (final p in projectRows)
          p['id'] as String: p['property_id'] as String?,
      };
      final targetByProject = <String, DateTime?>{
        for (final p in projectRows)
          p['id'] as String: DateTime.tryParse(
            p['target_end_date'] as String? ?? '',
          ),
      };

      final phaseRows = await _client!
          .from('project_phases')
          .select()
          .inFilter('project_id', projectIds)
          .order('sort_order');
      final phases = phaseRows
          .map(
            (e) => InvestorConstructionPhase.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList();

      final msRows = await _client!
          .from('project_milestones')
          .select()
          .inFilter('project_id', projectIds)
          .order('due_date');
      final milestones = msRows.map((e) {
        final m = Map<String, dynamic>.from(e);
        final projectId = m['project_id'] as String?;
        return InvestorMilestone(
          id: m['id'] as String,
          name: m['name'] as String? ?? 'Milestone',
          description: m['notes'] as String?,
          targetDate: DateTime.tryParse(m['due_date'] as String? ?? ''),
          completedAt: DateTime.tryParse(m['completed_at'] as String? ?? ''),
          status: m['status'] as String? ?? 'pending',
          projectId: projectId,
          projectName: projectId != null ? projectNameById[projectId] : null,
        );
      }).toList();

      final phaseNameById = <String, String>{
        for (final p in phases) p.id: p.name,
      };
      final milestoneNameById = <String, String>{
        for (final m in milestones) m.id: m.name,
      };

      final updateRows = await _client!
          .from('construction_progress_updates')
          .select('''
            id, project_id, phase_id, milestone_id, title, short_description,
            description, progress_pct, update_date, published_at,
            construction_update_media (
              id, media_type, file_url, thumbnail_url, caption, display_order,
              is_deleted, media_id, media:media_id (secure_url, thumbnail_url)
            )
          ''')
          .inFilter('project_id', projectIds)
          .contains('visibility', ['investors'])
          .eq('is_published', true)
          .eq('is_deleted', false)
          .order('published_at', ascending: false)
          .limit(60);

      final updates = updateRows.map((row) {
        final map = Map<String, dynamic>.from(row);
        final projectId = map['project_id'] as String?;
        final mediaRaw = map['construction_update_media'] as List? ?? [];
        final photos = <String>[];
        final videos = <InvestorConstructionVideo>[];

        final mediaItems =
            mediaRaw
                .whereType<Map>()
                .map((m) => Map<String, dynamic>.from(m))
                .where((m) => m['is_deleted'] != true)
                .toList()
              ..sort(
                (a, b) => ((a['display_order'] as num?)?.toInt() ?? 0)
                    .compareTo((b['display_order'] as num?)?.toInt() ?? 0),
              );

        for (final m in mediaItems) {
          final mediaJoin = m['media'];
          final secure = mediaJoin is Map
              ? mediaJoin['secure_url'] as String?
              : null;
          final fileUrl = (secure ?? m['file_url'] as String?)?.trim() ?? '';
          if (fileUrl.isEmpty) continue;
          final type = (m['media_type'] as String? ?? 'image').toLowerCase();
          final thumb = (m['thumbnail_url'] as String?)?.trim();
          final caption = m['caption'] as String?;
          if (type == 'video') {
            videos.add(
              InvestorConstructionVideo(
                id: m['id'] as String? ?? fileUrl,
                url: fileUrl,
                title: caption ?? 'Site video',
                thumbnailUrl: (thumb != null && thumb.isNotEmpty)
                    ? thumb
                    : (mediaJoin is Map
                          ? mediaJoin['thumbnail_url'] as String?
                          : null),
              ),
            );
          } else {
            photos.add(fileUrl);
          }
        }

        final phaseId = map['phase_id'] as String?;
        final milestoneId = map['milestone_id'] as String?;

        return InvestorConstructionUpdate(
          id: map['id'] as String,
          title: map['title'] as String? ?? 'Construction update',
          description:
              map['description'] as String? ??
              map['short_description'] as String?,
          completionPercent: (map['progress_pct'] as num?)?.toDouble(),
          updateDate: DateTime.tryParse(
            map['update_date'] as String? ??
                map['published_at'] as String? ??
                '',
          ),
          projectId: projectId,
          projectName: projectId != null ? projectNameById[projectId] : null,
          propertyId: projectId != null ? propertyByProject[projectId] : null,
          expectedCompletion: projectId != null
              ? targetByProject[projectId]
              : null,
          phaseName: phaseId != null ? phaseNameById[phaseId] : null,
          milestoneName: milestoneId != null
              ? milestoneNameById[milestoneId]
              : null,
          photos: photos,
          videos: videos,
        );
      }).toList();

      final projects = projectRows.map((row) {
        final id = row['id'] as String;
        return InvestorConstructionProject(
          id: id,
          name: row['name'] as String? ?? 'Project',
          propertyId: row['property_id'] as String?,
          progressPct: (row['progress_pct'] as num?)?.toDouble() ?? 0,
          targetEndDate: DateTime.tryParse(
            row['target_end_date'] as String? ?? '',
          ),
          scheduleStatus: row['schedule_status'] as String? ?? 'on_track',
          status: row['status'] as String? ?? 'active',
          coverImageUrl: row['cover_image_url'] as String?,
          phases: phases.where((p) => p.projectId == id).toList(),
          milestones: milestones.where((m) => m.projectId == id).toList(),
          updates: updates.where((u) => u.projectId == id).toList(),
        );
      }).toList();

      final overall = projects
          .map((p) => p.progressPct)
          .fold<double>(0, (a, b) => a > b ? a : b);

      return InvestorConstructionBundle(
        projects: projects,
        updates: updates,
        milestones: milestones,
        phases: phases,
        overallPercent: overall,
      );
    } catch (_) {
      return const InvestorConstructionBundle();
    }
  }

  Future<List<InvestmentReceivingAccount>> listReceivingAccounts() async {
    final rows = await _client!
        .from('investment_receiving_accounts')
        .select()
        .eq('is_active', true)
        .eq('is_deleted', false)
        .order('is_primary', ascending: false);
    return rows
        .map(
          (e) =>
              InvestmentReceivingAccount.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList();
  }

  Future<List<InvestorPaymentIntent>> listPaymentIntents(
    String investorId, {
    int limit = 50,
  }) async {
    final rows = await _client!
        .from('investor_payment_intents')
        .select()
        .eq('investor_id', investorId)
        .eq('is_deleted', false)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows
        .map(
          (e) => InvestorPaymentIntent.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList();
  }

  Future<List<InvestorSettledPayment>> listSettledPayments(
    String investorId, {
    int limit = 50,
  }) async {
    try {
      final rows = await _client!
          .from('payments')
          .select('*, finance_receipts(id, receipt_number)')
          .eq('investor_id', investorId)
          .eq('is_deleted', false)
          .order('paid_at', ascending: false)
          .limit(limit);
      return rows
          .map(
            (e) =>
                InvestorSettledPayment.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList();
    } catch (_) {
      final rows = await _client!
          .from('payments')
          .select()
          .eq('investor_id', investorId)
          .order('created_at', ascending: false)
          .limit(limit);
      return rows
          .map(
            (e) =>
                InvestorSettledPayment.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList();
    }
  }

  Future<List<InvestorPaymentReceipt>> listPaymentReceipts(
    String investorId, {
    int limit = 50,
  }) async {
    final payments = await listSettledPayments(investorId, limit: limit);
    final receiptIds = payments
        .map((p) => p.receiptId)
        .whereType<String>()
        .toSet()
        .toList();
    if (receiptIds.isEmpty) {
      // Fallback: receipts joined via payment ownership RLS.
      try {
        final rows = await _client!
            .from('finance_receipts')
            .select()
            .order('issued_at', ascending: false)
            .limit(limit);
        return rows
            .map(
              (e) =>
                  InvestorPaymentReceipt.fromJson(Map<String, dynamic>.from(e)),
            )
            .toList();
      } catch (_) {
        return const [];
      }
    }
    final rows = await _client!
        .from('finance_receipts')
        .select()
        .inFilter('id', receiptIds)
        .order('issued_at', ascending: false);
    return rows
        .map(
          (e) => InvestorPaymentReceipt.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList();
  }

  /// Submits a bank-transfer confirmation. Status is always awaiting finance.
  Future<InvestorPaymentIntent> submitBankTransfer({
    required double amount,
    String? notes,
    String? receivingAccountId,
    String? bankReference,
    String? holdingId,
    DateTime? transferDate,
    String? payerBank,
    Map<String, dynamic>? proof,
  }) async {
    await _requireApprovedInvestorKyc();
    final row = await _client!.rpc(
      'investor_submit_bank_transfer',
      params: {
        'p_amount': amount,
        'p_receiving_account_id': receivingAccountId,
        'p_notes': notes,
        'p_bank_reference': bankReference,
        'p_holding_id': holdingId,
        'p_transfer_date': transferDate?.toIso8601String().split('T').first,
        'p_payer_bank': payerBank,
        'p_proof': proof,
      },
    );
    final map = _coerceRowMap(row);
    if (map == null) {
      throw StateError('Payment could not be submitted. Please try again.');
    }
    return InvestorPaymentIntent.fromJson(map);
  }

  @Deprecated('Use submitBankTransfer')
  Future<InvestorPaymentIntent> createBankTransferIntent({
    required String investorId,
    required double amount,
    String? notes,
    String? receivingAccountId,
  }) {
    return submitBankTransfer(
      amount: amount,
      notes: notes,
      receivingAccountId: receivingAccountId,
    );
  }

  Future<List<InvestorConversation>> listConversations(
    String investorId,
  ) async {
    _requireAuthUserId();
    final rows = await _client!
        .from('investor_conversations')
        .select()
        .eq('investor_id', investorId)
        .eq('is_deleted', false)
        .order('last_message_at', ascending: false);

    return rows.map((e) {
      final map = Map<String, dynamic>.from(e);
      map['unread_count'] =
          map['investor_unread_count'] ?? map['unread_count'] ?? 0;
      return InvestorConversation.fromJson(map);
    }).toList();
  }

  /// Staff Support desk — all investor portal threads.
  Future<List<InvestorConversation>> listStaffConversations() async {
    _requireAuthUserId();
    List<dynamic> rows;
    try {
      rows = await _client!
          .from('investor_conversations')
          .select('''
            *,
            investors:investor_id (
              investor_code,
              profiles:user_id (
                preferred_name, first_name, last_name
              )
            )
          ''')
          .eq('is_deleted', false)
          .order('last_message_at', ascending: false)
          .limit(200)
          .timeout(const Duration(seconds: 6));
    } catch (_) {
      rows = await _client!
          .from('investor_conversations')
          .select()
          .eq('is_deleted', false)
          .order('last_message_at', ascending: false)
          .limit(200);
    }

    return rows.map((e) {
      final map = Map<String, dynamic>.from(e);
      map['unread_count'] =
          map['staff_unread_count'] ?? map['unread_count'] ?? 0;
      return InvestorConversation.fromJson(map);
    }).toList();
  }

  Future<int> markConversationRead(String conversationId) async {
    _requireAuthUserId();
    final result = await _client!.rpc(
      'investor_conversation_mark_read',
      params: {'p_conversation_id': conversationId},
    );
    if (result is num) return result.toInt();
    return 0;
  }

  Future<void> setConversationTyping({
    required String conversationId,
    required bool isTyping,
    String actor = 'investor',
  }) async {
    try {
      await _client!.rpc(
        'investor_conversation_set_typing',
        params: {
          'p_conversation_id': conversationId,
          'p_is_typing': isTyping,
          'p_actor': actor,
        },
      );
    } catch (_) {}
  }

  Future<List<InvestorMessage>> listMessages(
    String conversationId, {
    required String userId,
  }) async {
    final rows = await _client!
        .from('investor_conversation_messages')
        .select()
        .eq('conversation_id', conversationId)
        .eq('is_deleted', false)
        .order('created_at');
    return rows
        .map(
          (e) => InvestorMessage.fromJson(
            Map<String, dynamic>.from(e),
            userId: userId,
          ),
        )
        .toList();
  }

  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String body,
    List<InvestorMessageAttachment> attachments = const [],
    String actor = 'investor',
  }) async {
    if (senderId.isEmpty) {
      throw ArgumentError.value(senderId, 'senderId', 'required');
    }
    await _client!.rpc(
      'investor_conversation_send_message',
      params: {
        'p_conversation_id': conversationId,
        'p_body': body,
        'p_attachments': attachments.map((a) => a.toJson()).toList(),
      },
    );
    await setConversationTyping(
      conversationId: conversationId,
      isTyping: false,
      actor: actor,
    );
  }

  Future<String> startConversation({
    required String investorId,
    required String subject,
    required String category,
    required String senderId,
    required String initialMessage,
    List<InvestorMessageAttachment> attachments = const [],
  }) async {
    final conv = await _client!
        .from('investor_conversations')
        .insert({
          'investor_id': investorId,
          'subject': subject,
          'category': category,
          'last_message_at': DateTime.now().toIso8601String(),
        })
        .select('id')
        .single();
    final id = conv['id'] as String;
    await sendMessage(
      conversationId: id,
      senderId: senderId,
      body: initialMessage,
      attachments: attachments,
    );
    return id;
  }

  Future<List<InvestorSupportTicket>> listTickets() async {
    final userId = _requireAuthUserId();
    final rows = await _client!
        .from('tickets')
        .select()
        .eq('user_id', userId)
        .eq('is_deleted', false)
        .order('updated_at', ascending: false);
    return rows
        .map(
          (e) => InvestorSupportTicket.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList();
  }

  Future<List<InvestorTicketMessage>> listTicketMessages(
    String ticketId,
  ) async {
    final userId = _requireAuthUserId();
    final rows = await _client!
        .from('ticket_messages')
        .select()
        .eq('ticket_id', ticketId)
        .eq('is_deleted', false)
        .order('created_at');
    return rows
        .map(
          (e) => InvestorTicketMessage.fromJson(
            Map<String, dynamic>.from(e),
            userId: userId,
          ),
        )
        .toList();
  }

  Future<void> sendTicketMessage({
    required String ticketId,
    required String message,
    List<InvestorMessageAttachment> attachments = const [],
  }) async {
    _requireAuthUserId();
    await _client!.rpc(
      'support_ticket_send_message',
      params: {
        'p_ticket_id': ticketId,
        'p_message': message,
        'p_is_internal': false,
        'p_channel': 'investor_portal',
        'p_message_type': attachments.isEmpty ? 'reply' : 'attachment',
        'p_attachments': attachments.map((a) => a.toJson()).toList(),
      },
    );
  }

  Future<void> createTicket({
    required String subject,
    required String description,
    String priority = 'normal',
    List<InvestorMessageAttachment> attachments = const [],
  }) async {
    _requireAuthUserId();
    final ticket = await _client!.rpc(
      'create_support_ticket',
      params: {
        'p_subject': subject.trim(),
        'p_description': description.trim(),
        'p_priority': priority,
        'p_customer_type': 'investor',
        'p_source': 'investor_portal',
        'p_channel': 'investor_portal',
      },
    );
    if (attachments.isNotEmpty) {
      final ticketId = (ticket as Map)['id'] as String;
      await sendTicketMessage(
        ticketId: ticketId,
        message: 'Supporting attachment',
        attachments: attachments,
      );
    }
  }

  Future<void> transitionTicket({
    required String ticketId,
    required String action,
  }) async {
    _requireAuthUserId();
    await _client!.rpc(
      'customer_transition_support_ticket',
      params: {'p_ticket_id': ticketId, 'p_action': action},
    );
  }

  Future<InvestorReferralSummary> loadReferrals(String investorId) async {
    final rows = await _client!
        .from('investor_referral_commissions')
        .select()
        .eq('investor_id', investorId)
        .eq('is_deleted', false)
        .order('created_at', ascending: false);

    final commissions = rows
        .map(
          (e) =>
              InvestorReferralCommission.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList();

    final pending = commissions
        .where((c) => c.status == 'pending' || c.status == 'approved')
        .fold<double>(0, (s, c) => s + c.amount);
    final paid = commissions
        .where((c) => c.status == 'paid' || c.status == 'completed')
        .fold<double>(0, (s, c) => s + c.amount);

    final record = await _client
        .from('investors')
        .select('metadata')
        .eq('id', investorId)
        .maybeSingle();
    final metaRaw = record?['metadata'];
    final metadata = metaRaw is Map
        ? Map<String, dynamic>.from(metaRaw)
        : const <String, dynamic>{};
    final stored = '${metadata['referral_code'] ?? ''}'.trim();
    final codeFromCommission = commissions
        .map((c) => c.referralCode)
        .whereType<String>()
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty);
    final code = stored.isNotEmpty
        ? stored
        : (codeFromCommission.isEmpty ? '' : codeFromCommission.first);

    return InvestorReferralSummary(
      referralCode: code,
      pendingEarnings: pending,
      paidEarnings: paid,
      commissions: commissions,
    );
  }

  /// KYC status + review history + compliance profile for the investor portal.
  Future<InvestorKycBundle> loadKycBundle(String investorId) async {
    final investor = await _client!
        .from('investors')
        .select('kyc_status, user_id')
        .eq('id', investorId)
        .maybeSingle();
    final kycStatus = investor?['kyc_status'] as String? ?? 'pending';
    final userId = investor?['user_id'] as String?;

    List<InvestorKycReview> reviews = const [];
    try {
      final reviewRows = await _client!
          .from('investor_kyc_reviews')
          .select()
          .eq('investor_id', investorId)
          .order('created_at', ascending: false);
      reviews = reviewRows
          .map((e) => InvestorKycReview.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {}

    String? sourceOfFunds;
    String? riskProfile;
    String? investmentSource;
    if (userId != null && userId.isNotEmpty) {
      try {
        final compliance = await _client!
            .from('investor_compliance')
            .select('source_of_funds, risk_profile, investment_source')
            .eq('user_id', userId)
            .maybeSingle();
        sourceOfFunds = compliance?['source_of_funds'] as String?;
        riskProfile = compliance?['risk_profile'] as String?;
        investmentSource = compliance?['investment_source'] as String?;
      } catch (_) {}
    }

    return InvestorKycBundle(
      kycStatus: kycStatus,
      reviews: reviews,
      sourceOfFunds: sourceOfFunds,
      riskProfile: riskProfile,
      investmentSource: investmentSource,
    );
  }

  Future<Map<String, dynamic>> loadPreferences(String investorId) async {
    final row = await _client!
        .from('investor_preferences')
        .select('metadata')
        .eq('investor_id', investorId)
        .maybeSingle();
    if (row == null) return {};
    final meta = row['metadata'];
    if (meta is Map) return Map<String, dynamic>.from(meta);
    return {};
  }

  Future<void> savePreferences(
    String investorId,
    Map<String, dynamic> preferences,
  ) async {
    await _client!.from('investor_preferences').upsert({
      'investor_id': investorId,
      'metadata': preferences,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'investor_id');
  }
}
