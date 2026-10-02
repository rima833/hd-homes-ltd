import 'package:hdhomesproject/features/imp/domain/entities/imp_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Loads and manages Investor Command Center data in Supabase.
class ImpService {
  ImpService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  Future<ImpCommandCenterSnapshot> loadCommandCenter() async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase is not configured');
    }

    final investorRows = await client
        .from('investors')
        .select()
        .order('updated_at', ascending: false)
        .limit(100);
    final investorMaps = investorRows
        .map((row) => Map<String, dynamic>.from(row as Map))
        .where((row) => row['is_deleted'] != true && !_isDemo(row))
        .toList();
    final allowedInvestorIds = investorMaps
        .map((row) => row['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();

    final tagRows = await client
        .from('investor_tag_assignments')
        .select('investor_id, investor_tags(slug)');
    final tagsByInvestor = <String, List<String>>{};
    for (final row in tagRows) {
      final map = Map<String, dynamic>.from(row as Map);
      final investorId = map['investor_id']?.toString();
      final relation = map['investor_tags'];
      final slug = relation is Map ? relation['slug'] as String? : null;
      if (investorId == null ||
          !allowedInvestorIds.contains(investorId) ||
          slug == null) {
        continue;
      }
      tagsByInvestor.putIfAbsent(investorId, () => []).add(slug);
    }
    final investors = investorMaps.map((map) {
      map['tags'] = tagsByInvestor[map['id']?.toString()] ?? const <String>[];
      map['ai_summary'] = null;
      return ImpInvestor.fromJson(map);
    }).toList();

    final opportunityRows = await client
        .from('investment_opportunities')
        .select()
        .order('updated_at', ascending: false)
        .limit(50);
    final opportunityMaps = opportunityRows
        .map((row) => Map<String, dynamic>.from(row as Map))
        .where((row) => !_isDemo(row))
        .toList();
    final allowedOpportunityIds = opportunityMaps
        .map((row) => row['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    final opportunities = opportunityMaps.map(ImpOpportunity.fromJson).toList();

    final commitmentRows = await client
        .from('investment_commitments')
        .select('*, investors(full_name), investment_opportunities(title)')
        .order('committed_at', ascending: false)
        .limit(100);
    final commitments = commitmentRows
        .map((row) => Map<String, dynamic>.from(row as Map))
        .where(
          (row) =>
              !_isDemo(row) &&
              allowedInvestorIds.contains(row['investor_id']?.toString()) &&
              allowedOpportunityIds.contains(row['opportunity_id']?.toString()),
        )
        .map(ImpCommitment.fromJson)
        .toList();

    final holdingRows = await client
        .from('portfolio_holdings')
        .select('*, investor_portfolios(investor_id, investors(full_name))')
        .limit(100);
    final holdings = <ImpHolding>[];
    for (final row in holdingRows) {
      final map = Map<String, dynamic>.from(row as Map);
      final portfolio = map['investor_portfolios'];
      if (portfolio is! Map || _isDemo(map) || _isDemo(portfolio)) continue;
      final investorId = portfolio['investor_id']?.toString();
      final opportunityId = map['opportunity_id']?.toString();
      if (!allowedInvestorIds.contains(investorId) ||
          (opportunityId != null &&
              !allowedOpportunityIds.contains(opportunityId))) {
        continue;
      }
      map['investor_id'] = investorId;
      final investor = portfolio['investors'];
      if (investor is Map) map['investor_name'] = investor['full_name'];
      holdings.add(ImpHolding.fromJson(map));
    }

    final distributionRows = await client
        .from('investment_distributions')
        .select('*, investors(full_name), investment_opportunities(title)')
        .order('scheduled_at', ascending: true)
        .limit(100);
    final distributions = distributionRows
        .map((row) => Map<String, dynamic>.from(row as Map))
        .where(
          (row) =>
              !_isDemo(row) &&
              allowedInvestorIds.contains(row['investor_id']?.toString()) &&
              (row['opportunity_id'] == null ||
                  allowedOpportunityIds.contains(
                    row['opportunity_id']?.toString(),
                  )),
        )
        .map(ImpDistribution.fromJson)
        .toList();

    final walletRows = await client
        .from('investor_wallets')
        .select('*, investors(full_name)')
        .limit(100);
    final wallets = walletRows
        .map((row) => Map<String, dynamic>.from(row as Map))
        .where(
          (row) =>
              !_isDemo(row) &&
              allowedInvestorIds.contains(row['investor_id']?.toString()),
        )
        .map(ImpWallet.fromJson)
        .toList();

    final activityRows = await client
        .from('investor_activity_logs')
        .select('*, investors(full_name)')
        .order('occurred_at', ascending: false)
        .limit(40);
    final activities = activityRows
        .map((row) => Map<String, dynamic>.from(row as Map))
        .where(
          (row) =>
              !_isDemo(row) &&
              allowedInvestorIds.contains(row['investor_id']?.toString()) &&
              (row['opportunity_id'] == null ||
                  allowedOpportunityIds.contains(
                    row['opportunity_id']?.toString(),
                  )),
        )
        .map(ImpActivity.fromJson)
        .toList();

    final alertRows = await client
        .from('investor_alerts')
        .select()
        .order('created_at', ascending: false)
        .limit(40);
    final alerts = alertRows
        .map((row) => Map<String, dynamic>.from(row as Map))
        .where(
          (row) =>
              !_isDemo(row) &&
              (row['investor_id'] == null ||
                  allowedInvestorIds.contains(
                    row['investor_id']?.toString(),
                  )) &&
              (row['opportunity_id'] == null ||
                  allowedOpportunityIds.contains(
                    row['opportunity_id']?.toString(),
                  )),
        )
        .map(ImpAlert.fromJson)
        .toList();

    return ImpCommandCenterSnapshot(
      kpis: ImpMetrics.aggregateKpis(
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
      aiInsights: const [],
      fromRemote: true,
      loadedAt: DateTime.now(),
    );
  }

  static bool _isDemo(Map<dynamic, dynamic> row) {
    final metadata = row['metadata'];
    return metadata is Map && metadata['demo'] == true;
  }

  Future<String> saveInvestor({
    String? investorId,
    required String fullName,
    String? email,
    String? phone,
    String? company,
    String? nationality,
    required InvestorType investorType,
    required InvestorLifecycleStatus lifecycleStatus,
    required RiskLevel riskLevel,
    required String preferredCurrency,
  }) async {
    final id = await _requireClient.rpc(
      'admin_save_investor',
      params: {
        'p_investor_id': ?investorId,
        'p_full_name': fullName.trim(),
        if (email != null) 'p_email': email.trim(),
        if (phone != null) 'p_phone': phone.trim(),
        if (company != null) 'p_company': company.trim(),
        if (nationality != null) 'p_nationality': nationality.trim(),
        'p_investor_type': investorType.slug,
        'p_lifecycle_status': lifecycleStatus.slug,
        'p_risk_level': riskLevel.slug,
        'p_preferred_currency': preferredCurrency,
      },
    );
    return id?.toString() ?? '';
  }

  Future<void> archiveInvestor(String investorId) async {
    await _requireClient.rpc(
      'admin_archive_investor',
      params: {'p_investor_id': investorId},
    );
  }

  Future<ImpInvestorPage> listInvestorsPage({
    String? search,
    String? investorType,
    InvestorLifecycleStatus? lifecycleStatus,
    KycStatus? kycStatus,
    String? assignedStaffId,
    int limit = 50,
    int offset = 0,
  }) async {
    final result = await _requireClient.rpc(
      'admin_list_investors',
      params: {
        'p_search': ?search,
        'p_investor_type': ?investorType,
        'p_lifecycle_status': ?lifecycleStatus?.slug,
        'p_kyc_status': ?kycStatus?.slug,
        'p_assigned_staff_id': ?assignedStaffId,
        'p_limit': limit,
        'p_offset': offset,
      },
    );
    if (result is! Map) {
      throw const FormatException('Invalid investor directory response');
    }
    return ImpInvestorPage.fromJson(Map<String, dynamic>.from(result));
  }

  Future<ImpInvestorDetail> loadInvestor360(String investorId) async {
    final result = await _requireClient.rpc(
      'admin_get_investor_360',
      params: {'p_investor_id': investorId},
    );
    if (result is! Map) {
      throw const FormatException('Invalid investor detail response');
    }
    return ImpInvestorDetail.fromJson(Map<String, dynamic>.from(result));
  }

  Future<ImpDeskKpis> loadDeskKpis() async {
    final result = await _requireClient.rpc('admin_get_investor_desk_kpis');
    final map = result is Map
        ? Map<String, dynamic>.from(result)
        : <String, dynamic>{};
    return ImpDeskKpis.fromJson(map);
  }

  Future<ImpWorkQueues> loadWorkQueues() async {
    final result = await _requireClient.rpc('admin_get_investor_work_queues');
    if (result is! Map) {
      throw const FormatException('Invalid investor work-queue response');
    }
    return ImpWorkQueues.fromJson(Map<String, dynamic>.from(result));
  }

  Future<List<ImpStaffOption>> listInvestorManagers() async {
    final result = await _requireClient.rpc('admin_list_investor_managers');
    if (result is! List) return const [];
    return result
        .whereType<Map>()
        .map((row) => ImpStaffOption.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<void> assignInvestorOwner({
    required String investorId,
    required String staffId,
  }) async {
    await _requireClient.rpc(
      'admin_assign_investor_owner',
      params: {'p_investor_id': investorId, 'p_staff_id': staffId},
    );
  }

  Future<String> saveInvestorTask({
    required String investorId,
    required String title,
    String taskType = 'follow_up',
    String priority = 'medium',
    DateTime? dueAt,
    String? assignedTo,
    String? taskId,
  }) async {
    final id = await _requireClient.rpc(
      'admin_save_investor_task',
      params: {
        'p_investor_id': investorId,
        'p_title': title.trim(),
        'p_task_type': taskType,
        'p_priority': priority,
        if (dueAt != null) 'p_due_at': dueAt.toUtc().toIso8601String(),
        'p_assigned_to': ?assignedTo,
        'p_task_id': ?taskId,
      },
    );
    return id?.toString() ?? '';
  }

  Future<void> setInvestorTaskStatus(String taskId, String status) async {
    await _requireClient.rpc(
      'admin_set_investor_task_status',
      params: {'p_task_id': taskId, 'p_status': status},
    );
  }

  Future<Map<String, dynamic>> confirmInvestorIntent({
    required String intentId,
    String status = 'confirmed',
    String? notes,
  }) async {
    final result = await _requireClient.rpc(
      'admin_confirm_investor_intent',
      params: {
        'p_intent_id': intentId,
        'p_status': status,
        if (notes != null && notes.trim().isNotEmpty) 'p_notes': notes.trim(),
      },
    );
    if (result is Map) return Map<String, dynamic>.from(result);
    return const {};
  }

  Future<Map<String, dynamic>> fundInvestmentCommitment(
    String commitmentId,
  ) async {
    final result = await _requireClient.rpc(
      'admin_fund_investment_commitment',
      params: {'p_commitment_id': commitmentId},
    );
    if (result is Map) return Map<String, dynamic>.from(result);
    return const {};
  }

  Future<String> publishInvestorReport({
    required String investorId,
    required String title,
    String reportType = 'portfolio',
    String? fileUrl,
    String? periodLabel,
    bool notify = true,
  }) async {
    final id = await _requireClient.rpc(
      'admin_publish_investor_report',
      params: {
        'p_investor_id': investorId,
        'p_title': title.trim(),
        'p_report_type': reportType,
        'p_file_url': ?fileUrl,
        'p_period_label': ?periodLabel,
        'p_notify': notify,
      },
    );
    return id?.toString() ?? '';
  }

  Future<void> setInvestorReferralCode({
    required String investorId,
    required String code,
  }) async {
    await _requireClient.rpc(
      'admin_set_investor_referral_code',
      params: {
        'p_investor_id': investorId,
        'p_code': code.trim(),
      },
    );
  }

  Future<String> awardInvestorReferral({
    required String investorId,
    required double amount,
    String currency = 'NGN',
    String? referralCode,
    String? referredUserId,
    String status = 'pending',
    bool notify = true,
  }) async {
    final id = await _requireClient.rpc(
      'admin_award_investor_referral',
      params: {
        'p_investor_id': investorId,
        'p_commission_amount': amount,
        'p_currency': currency.trim().toUpperCase(),
        'p_referral_code': ?referralCode,
        'p_referred_user_id': ?referredUserId,
        'p_status': status,
        'p_notify': notify,
      },
    );
    return id?.toString() ?? '';
  }

  Future<String> saveOpportunity({
    String? opportunityId,
    required String title,
    String? description,
    required OpportunityStatus status,
    required double targetRaise,
    required double amountRaised,
    double? minTicket,
    double? maxTicket,
    double? projectedReturnPct,
    required String currency,
    required RiskLevel riskLevel,
  }) async {
    final id = await _requireClient.rpc(
      'admin_save_investment_opportunity',
      params: {
        'p_opportunity_id': ?opportunityId,
        'p_title': title.trim(),
        if (description != null) 'p_description': description.trim(),
        'p_status': status.slug,
        'p_target_raise': targetRaise,
        'p_amount_raised': amountRaised,
        'p_min_ticket': ?minTicket,
        'p_max_ticket': ?maxTicket,
        'p_projected_return_pct': ?projectedReturnPct,
        'p_currency': currency,
        'p_risk_level': riskLevel.slug,
      },
    );
    return id?.toString() ?? '';
  }

  Future<void> setCommitmentStatus(String commitmentId, String status) async {
    await _requireClient.rpc(
      'admin_set_investment_commitment_status',
      params: {'p_commitment_id': commitmentId, 'p_status': status},
    );
  }

  Future<String> saveCommitment({
    String? commitmentId,
    required String investorId,
    required String opportunityId,
    required double amount,
    required String currency,
    required String status,
    String? notes,
  }) async {
    final id = await _requireClient.rpc(
      'admin_save_investment_commitment',
      params: {
        'p_commitment_id': ?commitmentId,
        'p_investor_id': investorId,
        'p_opportunity_id': opportunityId,
        'p_amount': amount,
        'p_currency': currency,
        'p_status': status,
        if (notes != null) 'p_notes': notes.trim(),
      },
    );
    return id?.toString() ?? '';
  }

  Future<String> saveDistribution({
    String? distributionId,
    required String investorId,
    String? opportunityId,
    required double amount,
    required DistributionStatus status,
    required String distributionType,
    required String currency,
    DateTime? scheduledAt,
    String? reference,
  }) async {
    final id = await _requireClient.rpc(
      'admin_save_investment_distribution',
      params: {
        'p_distribution_id': ?distributionId,
        'p_investor_id': investorId,
        'p_opportunity_id': ?opportunityId,
        'p_amount': amount,
        'p_status': status.slug,
        'p_distribution_type': distributionType,
        'p_currency': currency,
        if (scheduledAt != null)
          'p_scheduled_at': scheduledAt.toUtc().toIso8601String(),
        if (reference != null) 'p_reference': reference.trim(),
      },
    );
    return id?.toString() ?? '';
  }

  Future<void> setDistributionStatus(
    String distributionId,
    DistributionStatus status,
  ) async {
    await _requireClient.rpc(
      'admin_set_investment_distribution_status',
      params: {'p_distribution_id': distributionId, 'p_status': status.slug},
    );
  }

  Future<void> setAlertStatus(String alertId, String status) async {
    await _requireClient.rpc(
      'admin_set_investor_alert_status',
      params: {'p_alert_id': alertId, 'p_status': status},
    );
  }

  Future<void> adjustHoldingValue(String holdingId, double currentValue) async {
    await _requireClient.rpc(
      'admin_adjust_investor_holding_value',
      params: {'p_holding_id': holdingId, 'p_current_value': currentValue},
    );
  }

  SupabaseClient get _requireClient {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    return client;
  }

  /// Staff KYC verification — syncs `investors.kyc_status` + appends review row.
  Future<String> verifyInvestorKyc({
    required String investorId,
    required KycStatus status,
    String? notes,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase is not configured');
    }
    final id = await client.rpc(
      'admin_verify_investor_kyc',
      params: {
        'p_investor_id': investorId,
        'p_status': status.slug,
        if (notes != null && notes.trim().isNotEmpty) 'p_notes': notes.trim(),
      },
    );
    return id?.toString() ?? '';
  }

  /// Staff publish an in-app investor notification (optional deep link).
  Future<String> publishInvestorNotification({
    required String investorId,
    required String title,
    String? body,
    String? route,
    String category = 'general',
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase is not configured');
    }
    final id = await client.rpc(
      'admin_publish_investor_notification',
      params: {
        'p_investor_id': investorId,
        'p_title': title,
        'p_body': ?body,
        if (route != null && route.isNotEmpty) 'p_route': route,
        'p_category': category,
        'p_channel': 'in_app',
        'p_metadata': <String, dynamic>{},
      },
    );
    return id?.toString() ?? '';
  }

  /// Assign a portfolio holding (optional opportunity + commitment + notify).
  Future<String> assignInvestorHolding({
    required String investorId,
    required String label,
    required double costBasis,
    double? currentValue,
    double units = 1,
    String currency = 'NGN',
    String? opportunityId,
    String? propertyId,
    bool createCommitment = true,
    bool notify = true,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase is not configured');
    }
    final id = await client.rpc(
      'admin_assign_investor_holding',
      params: {
        'p_investor_id': investorId,
        'p_label': label,
        'p_cost_basis': costBasis,
        'p_current_value': currentValue ?? costBasis,
        'p_units': units,
        'p_currency': currency,
        'p_opportunity_id': ?opportunityId,
        'p_property_id': ?propertyId,
        'p_create_commitment': createCommitment,
        'p_notify': notify,
      },
    );
    return id?.toString() ?? '';
  }

  /// Publish a DDCMS document into the investor vault (+ optional notify).
  Future<String> publishDocumentToInvestor({
    required String documentId,
    required String investorId,
    String documentType = 'shared',
    String? title,
    bool notify = true,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase is not configured');
    }
    final id = await client.rpc(
      'admin_publish_document_to_investor',
      params: {
        'p_document_id': documentId,
        'p_investor_id': investorId,
        'p_document_type': documentType,
        if (title != null && title.trim().isNotEmpty) 'p_title': title.trim(),
      },
    );
    if (notify) {
      await publishInvestorNotification(
        investorId: investorId,
        title: 'New document available',
        body: title?.trim().isNotEmpty == true
            ? title!.trim()
            : 'A document was shared to your vault.',
        route: '/investor/documents',
        category: 'documents',
      );
    }
    return id?.toString() ?? '';
  }

  /// Staff message (create/continue conversation) + notify.
  Future<String> messageInvestor({
    required String investorId,
    required String body,
    String subject = 'Message from HD Homes',
    String category = 'support',
    String? conversationId,
    bool notify = true,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase is not configured');
    }
    final id = await client.rpc(
      'admin_message_investor',
      params: {
        'p_investor_id': investorId,
        'p_body': body,
        'p_subject': subject,
        'p_category': category,
        'p_conversation_id': ?conversationId,
        'p_notify': notify,
      },
    );
    return id?.toString() ?? '';
  }

  Future<List<ImpSupportThreadMessage>> listConversationMessages(
    String conversationId, {
    int limit = 40,
  }) async {
    final client = _requireClient;
    try {
      final uid = client.auth.currentUser?.id;
      final rows = await client
          .from('investor_conversation_messages')
          .select('id, body, sender_id, created_at')
          .eq('conversation_id', conversationId)
          .eq('is_deleted', false)
          .order('created_at', ascending: true)
          .limit(limit);
      return rows
          .map(
            (row) => ImpSupportThreadMessage.fromConversationJson(
              Map<String, dynamic>.from(row as Map),
              currentUserId: uid,
            ),
          )
          .where((m) => m.id.isNotEmpty && m.body.trim().isNotEmpty)
          .toList();
    } catch (primary) {
      try {
        final uid = client.auth.currentUser?.id;
        final rows = await client
            .from('investor_conversation_messages')
            .select()
            .eq('conversation_id', conversationId)
            .order('created_at', ascending: true)
            .limit(limit);
        return rows
            .map(
              (row) => ImpSupportThreadMessage.fromConversationJson(
                Map<String, dynamic>.from(row as Map),
                currentUserId: uid,
              ),
            )
            .where((m) => m.id.isNotEmpty)
            .toList();
      } catch (_) {
        throw StateError('Unable to load conversation messages: $primary');
      }
    }
  }

  Future<List<ImpSupportThreadMessage>> listTicketMessages(
    String ticketId, {
    int limit = 40,
  }) async {
    final client = _requireClient;
    try {
      final rows = await client
          .from('ticket_messages')
          .select(
            'id, message, sender_type, sender_name, is_internal, created_at',
          )
          .eq('ticket_id', ticketId)
          .eq('is_deleted', false)
          .order('created_at', ascending: true)
          .limit(limit);
      return rows
          .map(
            (row) => ImpSupportThreadMessage.fromTicketJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .where((m) => m.id.isNotEmpty)
          .toList();
    } catch (error) {
      throw StateError('Unable to load ticket messages: $error');
    }
  }

  Future<void> replyToSupportTicket({
    required String ticketId,
    required String message,
    bool isInternal = false,
  }) async {
    await _requireClient.rpc(
      'support_ticket_send_message',
      params: {
        'p_ticket_id': ticketId,
        'p_message': message.trim(),
        'p_is_internal': isInternal,
        'p_channel': 'portal',
        'p_message_type': isInternal ? 'note' : 'reply',
      },
    );
  }

  Future<void> linkWebsiteOpportunity({
    required String opportunityId,
    required String websiteOpportunityId,
  }) async {
    await _requireClient.rpc(
      'admin_link_website_investment_opportunity',
      params: {
        'p_operational_opportunity_id': opportunityId,
        'p_website_opportunity_id': websiteOpportunityId,
      },
    );
  }

  /// Publish (`active`), unpublish (`draft`), or archive a website card.
  Future<void> setWebsiteOpportunityStatus({
    required String websiteOpportunityId,
    String? status,
    String? opportunityStatus,
    bool? isFeatured,
  }) async {
    await _requireClient.rpc(
      'admin_set_website_investment_opportunity_status',
      params: {
        'p_website_opportunity_id': websiteOpportunityId,
        'p_status': ?status,
        'p_opportunity_status': ?opportunityStatus,
        'p_is_featured': ?isFeatured,
      },
    );
  }

  Future<List<ImpWebsiteOpportunity>> listWebsiteOpportunities({
    int limit = 50,
  }) async {
    final client = _requireClient;
    try {
      final rows = await client
          .from('website_investment_opportunities')
          .select(
            'id, project_name, slug, status, opportunity_status, '
            'operational_opportunity_id, is_featured',
          )
          .eq('is_deleted', false)
          .order('updated_at', ascending: false)
          .limit(limit);
      return rows
          .map(
            (row) => ImpWebsiteOpportunity.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .where((row) => row.id.isNotEmpty)
          .toList();
    } catch (error) {
      throw StateError('Unable to load website investment cards: $error');
    }
  }

  Future<String> postLedgerEntry({
    required String investorId,
    required String transactionType,
    required double amount,
    required String currency,
    required String direction,
    required String idempotencyKey,
    String? sourceType,
    String? sourceId,
    String? portfolioId,
    String? opportunityId,
    String? description,
    String? reference,
    Map<String, dynamic> metadata = const {},
  }) async {
    final result = await _requireClient.rpc(
      'admin_post_investor_ledger_entry',
      params: {
        'p_investor_id': investorId,
        'p_transaction_type': transactionType,
        'p_amount': amount,
        'p_currency': currency.trim().toUpperCase(),
        'p_direction': direction,
        'p_idempotency_key': idempotencyKey.trim(),
        'p_source_type': ?sourceType,
        'p_source_id': ?sourceId,
        'p_portfolio_id': ?portfolioId,
        'p_opportunity_id': ?opportunityId,
        'p_description': ?description,
        'p_reference': ?reference,
        'p_metadata': metadata,
      },
    );
    if (result is Map) return result['id']?.toString() ?? '';
    return '';
  }

  Future<List<ImpLedgerEntry>> listInvestorLedger(
    String investorId, {
    int limit = 100,
  }) async {
    final rows = await _requireClient
        .from('investment_transactions')
        .select()
        .eq('investor_id', investorId)
        .order('posted_at', ascending: false)
        .limit(limit);
    return rows
        .map((row) => ImpLedgerEntry.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<List<ImpKycDocument>> listInvestorKycDocuments(
    String investorId,
  ) async {
    final rows = await _requireClient
        .from('investor_kyc_documents')
        .select()
        .eq('investor_id', investorId)
        .order('created_at', ascending: false);
    return rows
        .map((row) => ImpKycDocument.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<List<({String id, String title})>> listPublishableDocuments({
    int limit = 40,
  }) async {
    final client = _requireClient;
    try {
      final rows = await client
          .from('documents')
          .select('id, title')
          .order('created_at', ascending: false)
          .limit(limit);
      return rows
          .map((e) {
            final m = Map<String, dynamic>.from(e as Map);
            return (
              id: m['id']?.toString() ?? '',
              title: (m['title'] as String?)?.trim().isNotEmpty == true
                  ? m['title'] as String
                  : 'Untitled document',
            );
          })
          .where((e) => e.id.isNotEmpty)
          .toList();
    } catch (error) {
      throw StateError('Unable to load publishable documents: $error');
    }
  }

  Future<ImpConstructionSnapshot> loadInvestorConstruction(
    String investorId,
  ) async {
    final result = await _requireClient.rpc(
      'admin_get_investor_construction',
      params: {'p_investor_id': investorId},
    );
    final map = result is Map
        ? Map<String, dynamic>.from(result)
        : <String, dynamic>{};
    return ImpConstructionSnapshot.fromJson(map);
  }

  Future<ImpSupportInbox> loadSupportInbox({int limit = 40}) async {
    final client = _requireClient;
    List<ImpConversation> conversations = const [];
    List<ImpSupportTicketRow> tickets = const [];
    var conversationsFailed = false;
    var ticketsFailed = false;

    try {
      final rows = await client
          .from('investor_conversations')
          .select(
            'id, investor_id, subject, category, status, last_message_preview, '
            'staff_unread_count, last_message_at, '
            'investors:investor_id ( full_name )',
          )
          .eq('is_deleted', false)
          .order('last_message_at', ascending: false)
          .limit(limit);
      conversations = rows
          .map(
            (row) =>
                ImpConversation.fromJson(Map<String, dynamic>.from(row as Map)),
          )
          .toList();
    } catch (_) {
      try {
        final rows = await client
            .from('investor_conversations')
            .select()
            .eq('is_deleted', false)
            .order('last_message_at', ascending: false)
            .limit(limit);
        conversations = rows
            .map(
              (row) => ImpConversation.fromJson(
                Map<String, dynamic>.from(row as Map),
              ),
            )
            .toList();
      } catch (_) {
        conversationsFailed = true;
        conversations = const [];
      }
    }

    try {
      final rows = await client
          .from('tickets')
          .select(
            'id, subject, ticket_number, status, priority, user_id, updated_at',
          )
          .eq('customer_type', 'investor')
          .eq('is_deleted', false)
          .order('updated_at', ascending: false)
          .limit(limit);
      final ticketMaps = rows
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      final userIds = ticketMaps
          .map((m) => m['user_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      final nameByUser = <String, String>{};
      if (userIds.isNotEmpty) {
        try {
          final investors = await client
              .from('investors')
              .select('user_id, full_name')
              .inFilter('user_id', userIds);
          for (final row in investors) {
            final m = Map<String, dynamic>.from(row as Map);
            final uid = m['user_id']?.toString();
            final name = m['full_name'] as String?;
            if (uid != null && name != null) nameByUser[uid] = name;
          }
        } catch (_) {}
      }
      tickets = ticketMaps
          .map((m) {
            final uid = m['user_id']?.toString();
            return ImpSupportTicketRow.fromJson({
              ...m,
              'investor_name': uid == null ? null : nameByUser[uid],
            });
          })
          .toList();
    } catch (_) {
      ticketsFailed = true;
      tickets = const [];
    }

    if (conversationsFailed && ticketsFailed) {
      throw StateError('Unable to load investor support inbox');
    }

    return ImpSupportInbox(conversations: conversations, tickets: tickets);
  }

  Future<List<ImpNotificationRow>> listRecentNotifications({
    int limit = 40,
  }) async {
    final client = _requireClient;
    try {
      final rows = await client
          .from('investor_notifications')
          .select(
            'id, investor_id, channel, title, body, is_read, sent_at, created_at, metadata, '
            'investors:investor_id ( full_name )',
          )
          .order('created_at', ascending: false)
          .limit(limit);
      return rows
          .map(
            (row) => ImpNotificationRow.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList();
    } catch (primary) {
      try {
        final rows = await client
            .from('investor_notifications')
            .select()
            .order('created_at', ascending: false)
            .limit(limit);
        return rows
            .map(
              (row) => ImpNotificationRow.fromJson(
                Map<String, dynamic>.from(row as Map),
              ),
            )
            .toList();
      } catch (_) {
        throw StateError('Unable to load investor notifications: $primary');
      }
    }
  }

  /// AI is deferred; retained for presentation compatibility.
  String generatePortfolioSummary(ImpInvestor investor) => '';

  static double computePortfolioValue(List<ImpHolding> holdings) =>
      ImpMetrics.computePortfolioValue(holdings);

  static double computeAum(List<ImpInvestor> investors) =>
      investors.fold<double>(0, (s, i) => s + i.aum);
}
