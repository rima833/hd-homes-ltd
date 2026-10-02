import 'dart:convert';
import 'dart:typed_data';

import 'package:hdhomesproject/features/client/domain/entities/client_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Client portal service — all Supabase reads/writes for Volume 3 Client Portal.
class ClientService {
  ClientService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  static const _propertySelect = '''
    *,
    properties (
      id, title, slug, status, property_code, category_slug, bedrooms,
      listing_price, currency, city, state,
      property_locations (city, state, address),
      property_images (url, is_cover, sort_order),
      property_pricing (price, currency)
    )
  ''';

  String _requireAuthUserId() {
    final uid = _client?.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('Not authenticated');
    }
    return uid;
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

  /// Ensures a [clients] row exists for the signed-in Supabase user.
  /// Never inserts from the client SDK (RLS) — select first, then SECURITY DEFINER RPC.
  Future<ClientRecord> ensureClient() async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase is not configured');
    }
    final authUserId = _requireAuthUserId();

    Future<ClientRecord?> readOwn() async {
      final existing = await client
          .from('clients')
          .select()
          .eq('user_id', authUserId)
          .eq('is_deleted', false)
          .maybeSingle();
      if (existing == null) return null;
      return ClientRecord.fromJson(Map<String, dynamic>.from(existing));
    }

    final already = await readOwn();
    if (already != null) return already;

    try {
      final row = await client.rpc('ensure_client_record');
      final map = _coerceRowMap(row);
      if (map != null && map['id'] != null) {
        return ClientRecord.fromJson(map);
      }
    } catch (error) {
      if ('$error'.contains('client_not_provisioned')) {
        throw StateError(
          'This login is not a client account. Open the portal you were invited to.',
        );
      }
    }

    final afterRpc = await readOwn();
    if (afterRpc != null) return afterRpc;

    throw StateError(
      'Could not resolve your client account. Please sign out and sign in again.',
    );
  }

  Future<ClientDashboardSnapshot> loadDashboard({
    required String displayName,
    int unreadNotifications = 0,
  }) async {
    final record = await ensureClient();
    final properties = await listProperties(record.id);
    final installments = await listInstallments(record.id);
    final payments = await listPayments(record.id);
    final timeline = await listTimeline(record.id, limit: 8);
    final documents = await listDocuments(record.id, limit: 5);
    final inspections = await listInspections(record.id);

    final outstanding = installments
        .where((i) => i.status != 'paid' && i.status != 'completed')
        .fold<double>(0, (sum, i) => sum + i.amount);
    final totalPaid = payments
        .where((p) => p.status == 'completed' || p.status == 'paid')
        .fold<double>(0, (sum, p) => sum + p.amount);

    final upcoming =
        installments
            .where(
              (i) => i.status == 'pending' && i.dueDate.isAfter(DateTime.now()),
            )
            .toList()
          ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    return ClientDashboardSnapshot(
      client: record,
      displayName: displayName,
      propertiesCount: properties.length,
      outstandingBalance: outstanding,
      totalPaid: totalPaid,
      upcomingInspections: inspections
          .where(
            (i) =>
                (i.status == 'scheduled' || i.status == 'confirmed') &&
                i.scheduledAt.isAfter(DateTime.now()),
          )
          .length,
      unreadNotifications: unreadNotifications,
      properties: properties,
      recentTimeline: timeline,
      recentDocuments: documents,
      upcomingInstallments: upcoming.take(3).toList(),
      constructionProgress: properties
          .where((p) => p.constructionProgressPct > 0)
          .toList(),
      paymentHistory: payments.take(6).toList(),
      loadedAt: DateTime.now(),
    );
  }

  Future<List<ClientProperty>> listProperties(String clientId) async {
    final client = _client!;
    final rows = await client
        .from('client_properties')
        .select(_propertySelect)
        .eq('client_id', clientId)
        .eq('is_deleted', false)
        .order('created_at', ascending: false);
    return rows
        .map((e) => ClientProperty.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<ClientProperty?> getProperty(
    String clientId,
    String propertyId,
  ) async {
    final client = _client!;
    final row = await client
        .from('client_properties')
        .select(_propertySelect)
        .eq('client_id', clientId)
        .eq('property_id', propertyId)
        .maybeSingle();
    if (row == null) return null;
    return ClientProperty.fromJson(Map<String, dynamic>.from(row));
  }

  Future<List<ClientProperty>> listSavedProperties() async {
    final client = _client!;
    final userId = _requireAuthUserId();
    final favs = await client
        .from('favorite_items')
        .select('entity_id, title, metadata')
        .eq('user_id', userId)
        .eq('item_type', 'property')
        .order('created_at', ascending: false);
    if (favs.isEmpty) return [];

    final ids = favs.map((f) => f['entity_id'] as String).toList();
    final rows = await client
        .from('properties')
        .select('''
          id, title, slug, status,
          property_locations (city, state),
          property_images (url, is_cover),
          property_pricing (price, currency)
        ''')
        .inFilter('id', ids)
        .eq('is_deleted', false);

    return rows.map((row) {
      final json = {
        'id': 'saved-${row['id']}',
        'client_id': '',
        'property_id': row['id'],
        'properties': row,
      };
      return ClientProperty.fromJson(Map<String, dynamic>.from(json));
    }).toList();
  }

  Future<void> toggleSavedProperty(
    String propertyId, {
    String title = 'Property',
  }) async {
    final client = _client!;
    final userId = _requireAuthUserId();
    final existing = await client
        .from('favorite_items')
        .select('id')
        .eq('user_id', userId)
        .eq('item_type', 'property')
        .eq('entity_id', propertyId)
        .maybeSingle();
    if (existing != null) {
      await client.from('favorite_items').delete().eq('id', existing['id']);
    } else {
      await client.from('favorite_items').insert({
        'user_id': userId,
        'item_type': 'property',
        'entity_id': propertyId,
        'title': title,
      });
    }
  }

  Future<List<ClientPayment>> listPayments(
    String clientId, {
    int limit = 50,
  }) async {
    final rows = await _client!
        .from('payments')
        .select('*, properties (title)')
        .eq('client_id', clientId)
        .eq('is_deleted', false)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows
        .map((e) => ClientPayment.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<ClientInstallment>> listInstallments(String clientId) async {
    final rows = await _client!
        .from('installments')
        .select('*, properties (title)')
        .eq('client_id', clientId)
        .eq('is_deleted', false)
        .order('due_date');
    return rows
        .map((e) => ClientInstallment.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Deprecated: clients must use [ClientPaymentEngineService.submitBankTransfer]
  /// (RPC). Direct inserts are blocked by RLS; this remains only for staff tooling.
  Future<String> createPaymentIntent({
    required String clientId,
    required double amount,
    required String provider,
    String? propertyId,
    String? installmentId,
  }) async {
    throw StateError(
      'Direct payment intents are disabled. Use the bank transfer verification flow.',
    );
  }

  Future<List<ClientDocument>> listDocuments(
    String clientId, {
    int limit = 100,
  }) async {
    final rows = await _client!
        .from('client_documents')
        .select()
        .eq('client_id', clientId)
        .eq('is_deleted', false)
        .eq('is_client_visible', true)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows
        .map((e) => ClientDocument.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Resolves a safe access URL for client documents.
  /// Supported shapes:
  /// - `https://...` (already pre-signed or external URL)
  /// - `storage://bucket/path/to/file.pdf`
  /// - `<bucket>/<path/to/file.pdf>`
  Future<String> resolveDocumentUrl(String raw) async {
    final value = raw.trim();
    if (value.isEmpty) {
      throw StateError('Document URL is empty');
    }
    final uri = Uri.tryParse(value);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
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

  Future<List<ClientConstructionUpdate>> listConstructionUpdates(
    String clientId,
  ) async {
    final properties = await listProperties(clientId);
    if (properties.isEmpty) return [];

    // Unified construction progress updates (RLS-scoped to this client).
    try {
      final unified = await _client!
          .from('construction_progress_updates')
          .select('''
            *,
            construction_projects (name, property_id),
            construction_update_media (file_url, thumbnail_url, display_order)
          ''')
          .contains('visibility', ['clients'])
          .eq('is_published', true)
          .eq('is_deleted', false)
          .order('published_at', ascending: false)
          .limit(40);

      if (unified.isNotEmpty) {
        return unified.map((row) {
          final map = Map<String, dynamic>.from(row);
          final project = map['construction_projects'];
          final projectMap = project is Map
              ? Map<String, dynamic>.from(project)
              : null;
          final mediaRaw = map['construction_update_media'] as List? ?? [];
          final photos = <String>[];
          for (final m in mediaRaw) {
            if (m is! Map) continue;
            final url = (m['file_url'] as String?)?.trim();
            if (url != null && url.isNotEmpty) photos.add(url);
          }
          return ClientConstructionUpdate(
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
            projectName: projectMap?['name'] as String?,
            photos: photos,
          );
        }).toList();
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

  Future<List<ClientInspection>> listInspections(String clientId) async {
    final userId = _requireAuthUserId();
    final properties = await listProperties(clientId);
    final propertyIds = properties.map((p) => p.propertyId).toList();

    final byId = <String, Map<String, dynamic>>{};

    final visitorRows = await _client!
        .from('property_inspections')
        .select('*, properties (title)')
        .eq('visitor_profile_id', userId)
        .order('scheduled_at', ascending: false);
    for (final row in visitorRows) {
      byId[row['id'] as String] = Map<String, dynamic>.from(row);
    }

    if (propertyIds.isNotEmpty) {
      final propertyRows = await _client
          .from('property_inspections')
          .select('*, properties (title)')
          .inFilter('property_id', propertyIds)
          .order('scheduled_at', ascending: false);
      for (final row in propertyRows) {
        byId[row['id'] as String] = Map<String, dynamic>.from(row);
      }
    }

    final inspections =
        byId.values.map((e) => ClientInspection.fromJson(e)).toList()
          ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
    return inspections;
  }

  Future<void> bookInspection({
    required String clientId,
    required String propertyId,
    required DateTime scheduledAt,
    required String fullName,
    required String email,
    required String phone,
    String? notes,
    String meetingType = 'site_visit',
  }) async {
    final userId = _requireAuthUserId();
    try {
      await _client!.rpc(
        'book_public_inspection',
        params: {
          'p_full_name': fullName.trim(),
          'p_phone': phone.trim(),
          'p_email': email.trim(),
          'p_property_id': propertyId,
          'p_scheduled_at': scheduledAt.toUtc().toIso8601String(),
          'p_meeting_type': meetingType,
          'p_notes': notes?.trim().isEmpty ?? true ? null : notes!.trim(),
          'p_visitor_profile_id': userId,
        },
      );
    } on PostgrestException catch (e) {
      if (e.message.contains('slot_unavailable')) {
        throw StateError(
          'This inspection slot was just booked. Please select another available time.',
        );
      }
      throw StateError('We couldn\'t complete your booking. Please try again.');
    }
  }

  Future<void> cancelInspection(String inspectionId) async {
    await _client!.rpc(
      'cancel_client_property_inspection',
      params: {'p_inspection_id': inspectionId},
    );
  }

  Future<List<ClientTimelineEvent>> listTimeline(
    String clientId, {
    int limit = 30,
  }) async {
    final rows = await _client!
        .from('client_timeline')
        .select()
        .eq('client_id', clientId)
        .eq('is_deleted', false)
        .order('occurred_at', ascending: false)
        .limit(limit);
    return rows
        .map((e) => ClientTimelineEvent.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<ClientConversation>> listConversations(String clientId) async {
    List<dynamic> rows;
    try {
      rows = await _client!
          .from('client_conversations')
          .select('''
            *,
            profiles:assigned_staff_id (
              preferred_name, first_name, last_name
            )
          ''')
          .eq('client_id', clientId)
          .eq('is_deleted', false)
          .order('last_message_at', ascending: false);
    } catch (_) {
      rows = await _client!
          .from('client_conversations')
          .select()
          .eq('client_id', clientId)
          .eq('is_deleted', false)
          .order('last_message_at', ascending: false);
    }

    return rows.map((e) {
      final map = Map<String, dynamic>.from(e);
      map['unread_count'] =
          map['client_unread_count'] ?? map['unread_count'] ?? 0;
      return ClientConversation.fromJson(map);
    }).toList();
  }

  Future<List<ClientConversation>> listStaffConversations() async {
    List<dynamic> rows;
    try {
      rows = await _client!
          .from('client_conversations')
          .select('''
            *,
            clients:client_id (
              client_code,
              profiles:user_id (
                preferred_name, first_name, last_name
              )
            ),
            profiles:assigned_staff_id (
              preferred_name, first_name, last_name
            )
          ''')
          .eq('is_deleted', false)
          .order('last_message_at', ascending: false)
          .limit(200)
          .timeout(const Duration(seconds: 6));
    } catch (_) {
      // Join may fail or stall under RLS / schema drift — fall back to bare rows.
      rows = await _client!
          .from('client_conversations')
          .select()
          .eq('is_deleted', false)
          .order('last_message_at', ascending: false)
          .limit(200);
    }

    return rows.map((e) {
      final map = Map<String, dynamic>.from(e);
      map['unread_count'] =
          map['staff_unread_count'] ?? map['unread_count'] ?? 0;
      return ClientConversation.fromJson(map);
    }).toList();
  }

  Future<ClientConversation?> getConversation(String conversationId) async {
    final row = await _client!
        .from('client_conversations')
        .select('''
          *,
          profiles:assigned_staff_id (
            preferred_name, first_name, last_name
          )
        ''')
        .eq('id', conversationId)
        .eq('is_deleted', false)
        .maybeSingle();
    if (row == null) return null;
    return ClientConversation.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> setConversationTyping({
    required String conversationId,
    required bool isTyping,
    String actor = 'client',
  }) async {
    try {
      await _client!.rpc(
        'client_conversation_set_typing',
        params: {
          'p_conversation_id': conversationId,
          'p_is_typing': isTyping,
          'p_actor': actor,
        },
      );
    } catch (_) {
      // Migration may not be applied yet — typing is best-effort.
    }
  }

  Future<int> markConversationRead(String conversationId) async {
    final result = await _client!.rpc(
      'client_conversation_mark_read',
      params: {'p_conversation_id': conversationId},
    );
    if (result is num) return result.toInt();
    return 0;
  }

  Future<List<ClientMessage>> listMessages(
    String conversationId, {
    required String userId,
  }) async {
    final rows = await _client!
        .from('client_conversation_messages')
        .select()
        .eq('conversation_id', conversationId)
        .eq('is_deleted', false)
        .order('created_at');
    return rows
        .map(
          (e) => ClientMessage.fromJson(
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
    String actor = 'client',
  }) async {
    if (senderId.isEmpty) {
      throw ArgumentError.value(senderId, 'senderId', 'required');
    }
    await _client!.rpc(
      'client_conversation_send_message',
      params: {'p_conversation_id': conversationId, 'p_body': body},
    );
    await setConversationTyping(
      conversationId: conversationId,
      isTyping: false,
      actor: actor,
    );
  }

  Future<String> startConversation({
    required String clientId,
    required String subject,
    required String category,
    required String senderId,
    required String initialMessage,
  }) async {
    final conv = await _client!
        .from('client_conversations')
        .insert({
          'client_id': clientId,
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
    );
    return id;
  }

  Future<List<ClientSupportTicket>> listTickets() async {
    final userId = _requireAuthUserId();
    final rows = await _client!
        .from('tickets')
        .select()
        .eq('user_id', userId)
        .eq('is_deleted', false)
        .order('created_at', ascending: false);
    return rows
        .map((e) => ClientSupportTicket.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<ClientTicketMessage>> listTicketMessages(String ticketId) async {
    final userId = _requireAuthUserId();
    final rows = await _client!
        .from('ticket_messages')
        .select()
        .eq('ticket_id', ticketId)
        .eq('is_deleted', false)
        .order('created_at');
    return rows
        .map(
          (e) => ClientTicketMessage.fromJson(
            Map<String, dynamic>.from(e),
            userId: userId,
          ),
        )
        .toList();
  }

  Future<void> sendTicketMessage({
    required String ticketId,
    required String message,
  }) async {
    _requireAuthUserId();
    await _client!.rpc(
      'support_ticket_send_message',
      params: {
        'p_ticket_id': ticketId,
        'p_message': message,
        'p_is_internal': false,
        'p_channel': 'portal',
        'p_message_type': 'reply',
      },
    );
  }

  Future<void> createTicket({
    required String subject,
    required String description,
    String priority = 'normal',
  }) async {
    _requireAuthUserId();
    await _client!.rpc(
      'create_support_ticket',
      params: {
        'p_subject': subject.trim(),
        'p_description': description.trim(),
        'p_priority': priority,
        'p_customer_type': 'client',
        'p_source': 'client_portal',
        'p_channel': 'portal',
      },
    );
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

  Future<ClientReferralSummary> loadReferrals(String clientId) async {
    final rows = await _client!
        .from('client_referral_commissions')
        .select()
        .eq('client_id', clientId)
        .eq('is_deleted', false)
        .order('created_at', ascending: false);

    final commissions = rows
        .map(
          (e) =>
              ClientReferralCommission.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList();

    final pending = commissions
        .where((c) => c.status == 'pending')
        .fold<double>(0, (s, c) => s + c.amount);
    final paid = commissions
        .where((c) => c.status == 'paid' || c.status == 'completed')
        .fold<double>(0, (s, c) => s + c.amount);

    final code = commissions.isNotEmpty
        ? commissions.first.referralCode ?? 'HDHOMES-$clientId'
        : 'HDHOMES-$clientId';

    return ClientReferralSummary(
      referralCode: code,
      pendingEarnings: pending,
      paidEarnings: paid,
      commissions: commissions,
    );
  }

  Future<Map<String, dynamic>> loadPreferences(String clientId) async {
    final row = await _client!
        .from('client_preferences')
        .select('preferences')
        .eq('client_id', clientId)
        .maybeSingle();
    if (row == null) return {};
    final prefs = row['preferences'];
    if (prefs is Map<String, dynamic>) return prefs;
    if (prefs is Map) return Map<String, dynamic>.from(prefs);
    return {};
  }

  Future<void> savePreferences(
    String clientId,
    Map<String, dynamic> preferences,
  ) async {
    await _client!.from('client_preferences').upsert({
      'client_id': clientId,
      'preferences': preferences,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'client_id');
  }

  Future<List<ClientApplicationPropertyOption>>
  listApplicationPropertyOptions() async {
    final rows = await _client!
        .from('properties')
        .select('''
          id, title, bedrooms, category_slug, inventory_status,
          marketing_status, status, listing_price,
          property_locations (city, state),
          property_pricing (price, currency),
          property_images (url, is_cover)
        ''')
        .eq('is_deleted', false)
        .eq('is_published', true)
        .order('created_at', ascending: false)
        .limit(200);
    return rows
        .map(
          (row) => ClientApplicationPropertyOption.fromPropertyJson(
            Map<String, dynamic>.from(row),
          ),
        )
        .toList();
  }

  Future<List<ClientPropertyApplication>> listApplications(
    String clientId,
  ) async {
    final rows = await _client!
        .from('client_property_applications')
        .select('''
          *,
          properties (
            id, title, bedrooms, category_slug, listing_price,
            property_locations (city, state),
            property_pricing (price, currency),
            property_images (url, is_cover)
          )
        ''')
        .eq('client_id', clientId)
        .eq('is_deleted', false)
        .order('created_at', ascending: false);
    return rows
        .map(
          (e) =>
              ClientPropertyApplication.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList();
  }

  Future<ClientPropertyApplication?> getApplication({
    required String clientId,
    required String applicationId,
  }) async {
    final row = await _client!
        .from('client_property_applications')
        .select('''
          *,
          properties (
            id, title, bedrooms, category_slug, listing_price,
            property_locations (city, state),
            property_pricing (price, currency),
            property_images (url, is_cover)
          )
        ''')
        .eq('client_id', clientId)
        .eq('id', applicationId)
        .eq('is_deleted', false)
        .maybeSingle();
    if (row == null) return null;
    return ClientPropertyApplication.fromJson(Map<String, dynamic>.from(row));
  }

  Future<List<ApplicationPaymentPlan>> listApplicationPaymentPlans({
    String? propertyId,
  }) async {
    if (propertyId != null) {
      final propertyPlans = await _client!
          .from('property_payment_plans')
          .select()
          .eq('property_id', propertyId)
          .eq('is_deleted', false)
          .order('created_at');
      if (propertyPlans.isNotEmpty) {
        return propertyPlans.map((row) {
          final m = Map<String, dynamic>.from(row);
          return ApplicationPaymentPlan(
            code: (m['name'] as String? ?? 'plan').toLowerCase().replaceAll(
              ' ',
              '_',
            ),
            name: m['name'] as String? ?? 'Plan',
            description: m['details']?.toString(),
            installmentMonths: (m['installment_months'] as num?)?.toInt(),
            initialDepositPercent: (m['initial_deposit_percent'] as num?)
                ?.toDouble(),
          );
        }).toList();
      }
    }

    final catalog = await _client!
        .from('application_payment_plan_catalog')
        .select()
        .eq('is_active', true)
        .order('sort_order');
    return catalog
        .map(
          (e) => ApplicationPaymentPlan.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList();
  }

  Future<List<ApplicationRequiredDocumentType>>
  listRequiredApplicationDocumentTypes() async {
    final rows = await _client!
        .from('application_required_document_types')
        .select()
        .eq('is_active', true)
        .order('sort_order');
    return rows
        .map(
          (e) => ApplicationRequiredDocumentType.fromJson(
            Map<String, dynamic>.from(e),
          ),
        )
        .toList();
  }

  Future<List<ClientDocument>> listApplicationDocuments({
    required String clientId,
    required String applicationId,
  }) async {
    final rows = await _client!
        .from('client_documents')
        .select()
        .eq('client_id', clientId)
        .eq('application_id', applicationId)
        .eq('is_deleted', false)
        .order('created_at', ascending: false);
    return rows
        .map((e) => ClientDocument.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<ClientTimelineEvent>> listApplicationTimeline({
    required String clientId,
    required String applicationId,
  }) async {
    final rows = await _client!
        .from('client_timeline')
        .select()
        .eq('client_id', clientId)
        .eq('is_deleted', false)
        .contains('metadata', {'application_id': applicationId})
        .order('occurred_at', ascending: false)
        .limit(50);
    return rows
        .map((e) => ClientTimelineEvent.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<String> saveApplicationDraft({
    required String clientId,
    required String propertyId,
    String? applicationId,
    String? paymentPlan,
    double? amountOffered,
    String? notes,
  }) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');

    final payload = <String, dynamic>{
      'client_id': clientId,
      'property_id': propertyId,
      'payment_plan': paymentPlan,
      'amount_offered': amountOffered,
      'notes': notes,
      'status': 'draft',
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (applicationId != null) {
      await client
          .from('client_property_applications')
          .update(payload)
          .eq('id', applicationId)
          .eq('client_id', clientId)
          .eq('status', 'draft');
      return applicationId;
    }

    final existing = await client
        .from('client_property_applications')
        .select('id, status')
        .eq('client_id', clientId)
        .eq('property_id', propertyId)
        .eq('is_deleted', false)
        .inFilter('status', [
          'draft',
          'submitted',
          'under_review',
          'documents_required',
          'approved',
          'payment_pending',
          'payment_active',
          'contract_pending',
        ])
        .maybeSingle();

    if (existing != null) {
      final id = existing['id'] as String;
      if (existing['status'] == 'draft') {
        await client
            .from('client_property_applications')
            .update(payload)
            .eq('id', id);
      }
      return id;
    }

    final row = await client
        .from('client_property_applications')
        .insert(payload)
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<String> submitApplication({
    required String clientId,
    required String propertyId,
    required String paymentPlan,
    double? amountOffered,
    String? notes,
    String? applicationId,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase is not configured');
    }

    String id;
    if (applicationId != null) {
      await client
          .from('client_property_applications')
          .update({
            'property_id': propertyId,
            'payment_plan': paymentPlan,
            'amount_offered': amountOffered,
            'notes': notes,
            'status': 'submitted',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', applicationId)
          .eq('client_id', clientId);
      id = applicationId;
    } else {
      final existing = await client
          .from('client_property_applications')
          .select('id, status')
          .eq('client_id', clientId)
          .eq('property_id', propertyId)
          .eq('is_deleted', false)
          .eq('status', 'draft')
          .maybeSingle();

      if (existing != null) {
        id = existing['id'] as String;
        await client
            .from('client_property_applications')
            .update({
              'payment_plan': paymentPlan,
              'amount_offered': amountOffered,
              'notes': notes,
              'status': 'submitted',
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', id);
      } else {
        final row = await client
            .from('client_property_applications')
            .insert({
              'client_id': clientId,
              'property_id': propertyId,
              'payment_plan': paymentPlan,
              'amount_offered': amountOffered,
              'notes': notes,
              'status': 'submitted',
            })
            .select('id')
            .single();
        id = row['id'] as String;
      }
    }

    // Timeline/notification emitted by DB trigger — avoid duplicate reservation logs.
    return id;
  }

  Future<void> cancelApplication({
    required String clientId,
    required String applicationId,
  }) async {
    await _client!
        .from('client_property_applications')
        .update({
          'status': 'cancelled',
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', applicationId)
        .eq('client_id', clientId);
  }

  Future<ClientDocument> uploadApplicationDocument({
    required String clientId,
    required String applicationId,
    required String propertyId,
    required String documentType,
    required String fileName,
    required List<int> bytes,
    String? title,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase is not configured');
    }
    const bucket = 'kyc-documents';
    final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final userId = _requireAuthUserId();
    final path =
        '$userId/applications/$clientId/$applicationId/${documentType}_$safeName';

    await client.storage
        .from(bucket)
        .uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: const FileOptions(upsert: true),
        );

    final fileUrl = 'storage://$bucket/$path';
    final row = await client
        .from('client_documents')
        .insert({
          'client_id': clientId,
          'application_id': applicationId,
          'property_id': propertyId,
          'title': title ?? documentType.replaceAll('_', ' '),
          'file_url': fileUrl,
          'file_name': fileName,
          'document_type': documentType,
          'review_status': 'uploaded',
          'storage_bucket': bucket,
          'storage_path': path,
          'status': 'active',
        })
        .select()
        .single();

    return ClientDocument.fromJson(Map<String, dynamic>.from(row));
  }

  // ── Property Reservation & Purchase Flow ─────────────────────────────────

  /// Express interest / reserve a property.
  ///
  /// Production rule: client clients submit an application only.
  /// Allocation, installment generation, and payment reconciliation are
  /// finance/admin workflows and must not be client-side direct writes.
  Future<String> reserveProperty({
    required String propertyId,
    required String paymentPlan,
    String? notes,
  }) async {
    final record = await ensureClient();
    return submitApplication(
      clientId: record.id,
      propertyId: propertyId,
      paymentPlan: paymentPlan,
      notes: notes,
    );
  }
}
