import 'package:hdhomesproject/features/cshop/domain/entities/cshop_models.dart';
import 'package:hdhomesproject/features/cshop/domain/entities/support_foundation_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Loads Support Command Center snapshot from Supabase. Empty lists when
/// a table has no rows or is unavailable — never mixes demo records with live data.
class CshopService {
  CshopService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  Future<CshopCommandCenterSnapshot> loadCommandCenter() async {
    final client = _client;
    if (client == null) {
      return CshopCommandCenterSnapshot(
        kpis: const [],
        tickets: const [],
        inbox: const [],
        liveChats: const [],
        chatMessages: const [],
        emailThreads: const [],
        whatsapp: const [],
        knowledge: const [],
        slas: const [],
        escalations: const [],
        agents: const [],
        feedback: const [],
        aiInsights: const [],
        timeline: const [],
        activities: const [],
        fromRemote: false,
        loadedAt: DateTime.now(),
        liveChatError:
            'Support desk is unavailable — Supabase is not configured.',
      );
    }

    try {
      List<CshopTicket> tickets = const [];
      try {
        final rows = await client
            .from('tickets')
            .select(
              '*, '
              'assignee:profiles!tickets_assigned_to_fkey('
              'preferred_name, first_name, last_name, email), '
              'category:support_categories(name, slug), '
              'property:properties(title, slug), '
              'estate:estates(name, slug), '
              'attachments:support_ticket_attachments(id)',
            )
            .order('created_at', ascending: false)
            .limit(50);
        tickets = (rows as List)
            .where((e) => !_isDemoRow(Map<String, dynamic>.from(e as Map)))
            .map(
              (e) => CshopTicket.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
      } catch (_) {
        try {
          final rows = await client
              .from('tickets')
              .select()
              .order('created_at', ascending: false)
              .limit(50);
          tickets = (rows as List)
              .where((e) => !_isDemoRow(Map<String, dynamic>.from(e as Map)))
              .map(
                (e) =>
                    CshopTicket.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        } catch (_) {}
      }

      List<CshopLiveChat> liveChats = const [];
      String? liveChatError;
      try {
        dynamic rows;
        try {
          rows = await client
              .from('live_chat_sessions')
              .select(
                '*, agent:support_agents!live_chat_sessions_agent_id_fkey(display_name)',
              )
              .order('started_at', ascending: false)
              .limit(80);
        } catch (_) {
          try {
            rows = await client
                .from('live_chat_sessions')
                .select()
                .order('started_at', ascending: false)
                .limit(80);
          } catch (_) {
            rows = await client.from('live_chat_sessions').select().limit(80);
          }
        }
        liveChats = (rows as List)
            .map(
              (e) =>
                  CshopLiveChat.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
      } catch (e) {
        liveChatError = 'Live chat queue unavailable: $e';
      }

      List<CshopChatMessage> chatMessages = const [];
      try {
        final rows = await client
            .from('live_chat_messages')
            .select()
            .order('created_at', ascending: false)
            .limit(80);
        chatMessages = (rows as List)
            .map(
              (e) => CshopChatMessage.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList();
      } catch (_) {}

      List<CshopEmailThread> emailThreads = const [];
      try {
        final rows = await client
            .from('support_email_threads')
            .select()
            .order('last_message_at', ascending: false)
            .limit(40);
        emailThreads = (rows as List)
            .where((e) => !_isDemoRow(Map<String, dynamic>.from(e as Map)))
            .map(
              (e) => CshopEmailThread.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList();
      } catch (_) {}

      List<CshopWhatsappConversation> whatsapp = const [];
      try {
        final rows = await client
            .from('whatsapp_conversations')
            .select()
            .order('last_message_at', ascending: false)
            .limit(40);
        whatsapp = (rows as List)
            .where((e) => !_isDemoRow(Map<String, dynamic>.from(e as Map)))
            .map(
              (e) => CshopWhatsappConversation.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList();
      } catch (_) {}

      List<CshopKnowledgeArticle> knowledge = const [];
      try {
        final rows = await client
            .from('support_knowledge_articles')
            .select('*, category:support_knowledge_categories(name, slug)')
            .neq('status', 'archived')
            .order('updated_at', ascending: false)
            .limit(80);
        knowledge = (rows as List)
            .map(
              (e) => CshopKnowledgeArticle.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList();
      } catch (_) {
        try {
          final rows = await client
              .from('support_knowledge_articles')
              .select()
              .order('updated_at', ascending: false)
              .limit(80);
          knowledge = (rows as List)
              .where((e) {
                final m = Map<String, dynamic>.from(e as Map);
                return (m['status'] as String?) != 'archived';
              })
              .map(
                (e) => CshopKnowledgeArticle.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        } catch (_) {}
      }

      List<CshopSla> slas = const [];
      try {
        final rows = await client.from('support_slas').select().limit(20);
        slas = (rows as List)
            .map((e) => CshopSla.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (_) {}

      List<CshopEscalation> escalations = const [];
      try {
        final rows = await client
            .from('support_escalations')
            .select()
            .order('created_at', ascending: false)
            .limit(40);
        escalations = (rows as List)
            .where((e) => !_isDemoRow(Map<String, dynamic>.from(e as Map)))
            .map(
              (e) =>
                  CshopEscalation.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
      } catch (_) {}

      List<CshopAgent> agents = const [];
      try {
        final rows = await client.from('support_agents').select().limit(40);
        agents = (rows as List)
            .where((e) {
              final m = Map<String, dynamic>.from(e as Map);
              if (_isDemoRow(m)) return false;
              final email = (m['email'] as String? ?? '').toLowerCase();
              return !email.endsWith('@hdhomes.demo');
            })
            .map(
              (e) => CshopAgent.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
      } catch (_) {}

      List<CshopAiInsight> aiInsights = const [];
      try {
        final rows = await client
            .from('support_ai_insights')
            .select()
            .order('created_at', ascending: false)
            .limit(20);
        aiInsights = (rows as List)
            .map(
              (e) =>
                  CshopAiInsight.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
      } catch (_) {}

      List<CshopActivity> activities = const [];
      try {
        final rows = await client
            .from('support_activity_logs')
            .select()
            .order('occurred_at', ascending: false)
            .limit(40);
        activities = (rows as List)
            .map(
              (e) =>
                  CshopActivity.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
      } catch (_) {}

      // Seed CSAT/NPS rows are demo-only; omit until real survey capture ships.
      const feedback = <CshopFeedback>[];

      final portalInbox = <CshopInboxThread>[];
      var portalUnread = 0;
      try {
        final rows = await client
            .from('client_conversations')
            .select(
              'id, subject, status, last_message_at, last_message_preview, '
              'category, staff_unread_count',
            )
            .eq('is_deleted', false)
            .order('last_message_at', ascending: false)
            .limit(40);

        for (final raw in rows as List) {
          final m = Map<String, dynamic>.from(raw as Map);
          final id = m['id'] as String? ?? '';
          if (id.isEmpty) continue;
          final unread = (m['staff_unread_count'] as num?)?.toInt() ?? 0;
          portalUnread += unread;
          portalInbox.add(
            CshopInboxThread(
              id: 'portal-client:$id',
              title: m['subject'] as String? ?? 'Client message',
              channel: 'portal',
              preview:
                  m['last_message_preview'] as String? ??
                  (m['status'] as String? ?? 'open'),
              customerName: 'Client · ${m['category'] as String? ?? 'support'}',
              status: m['status'] as String? ?? 'open',
              lastMessageAt: DateTime.tryParse(
                m['last_message_at'] as String? ?? '',
              ),
              unreadCount: unread,
            ),
          );
        }
      } catch (_) {}

      try {
        final rows = await client
            .from('investor_conversations')
            .select(
              'id, subject, status, last_message_at, last_message_preview, '
              'category, staff_unread_count',
            )
            .eq('is_deleted', false)
            .order('last_message_at', ascending: false)
            .limit(40);

        for (final raw in rows as List) {
          final m = Map<String, dynamic>.from(raw as Map);
          final id = m['id'] as String? ?? '';
          if (id.isEmpty) continue;
          final unread = (m['staff_unread_count'] as num?)?.toInt() ?? 0;
          portalUnread += unread;
          portalInbox.add(
            CshopInboxThread(
              id: 'portal-investor:$id',
              title: m['subject'] as String? ?? 'Investor message',
              channel: 'portal',
              preview:
                  m['last_message_preview'] as String? ??
                  (m['status'] as String? ?? 'open'),
              customerName:
                  'Investor · ${m['category'] as String? ?? 'support'}',
              status: m['status'] as String? ?? 'open',
              lastMessageAt: DateTime.tryParse(
                m['last_message_at'] as String? ?? '',
              ),
              unreadCount: unread,
            ),
          );
        }
      } catch (_) {}

      portalInbox.sort((a, b) {
        final aAt = a.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bAt = b.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bAt.compareTo(aAt);
      });
      if (portalInbox.length > 40) {
        portalInbox.removeRange(40, portalInbox.length);
      }

      // Email / WhatsApp stay out of the unified inbox until connectors ship.
      final inbox = _buildInbox(
        tickets: tickets,
        liveChats: liveChats,
        portalThreads: portalInbox,
      );
      final timeline = _buildTimeline(
        tickets: tickets,
        liveChats: liveChats,
        activities: activities,
      );
      final kpis = _deriveKpis(
        tickets: tickets,
        chats: liveChats,
        escalations: escalations,
        agents: agents,
        portalUnread: portalUnread,
      );

      return CshopCommandCenterSnapshot(
        kpis: kpis,
        tickets: tickets,
        inbox: inbox,
        liveChats: liveChats,
        chatMessages: chatMessages,
        emailThreads: emailThreads,
        whatsapp: whatsapp,
        knowledge: knowledge,
        slas: slas,
        escalations: escalations,
        agents: agents,
        feedback: feedback,
        aiInsights: aiInsights,
        timeline: timeline,
        activities: activities,
        fromRemote: true,
        loadedAt: DateTime.now(),
        liveChatError: liveChatError,
        portalUnreadCount: portalUnread,
      );
    } catch (e) {
      return CshopCommandCenterSnapshot(
        kpis: const [],
        tickets: const [],
        inbox: const [],
        liveChats: const [],
        chatMessages: const [],
        emailThreads: const [],
        whatsapp: const [],
        knowledge: const [],
        slas: const [],
        escalations: const [],
        agents: const [],
        feedback: const [],
        aiInsights: const [],
        timeline: const [],
        activities: const [],
        fromRemote: false,
        loadedAt: DateTime.now(),
        liveChatError: 'Could not load support desk: $e',
      );
    }
  }

  List<CshopInboxThread> _buildInbox({
    required List<CshopTicket> tickets,
    required List<CshopLiveChat> liveChats,
    List<CshopInboxThread> portalThreads = const [],
  }) {
    final threads = <CshopInboxThread>[
      ...liveChats.map(
        (c) => CshopInboxThread(
          id: 'chat-${c.id}',
          title: c.customerName?.trim().isNotEmpty == true
              ? c.customerName!
              : 'Live chat ${c.sessionCode}',
          channel: 'chat',
          preview: '${c.sessionCode} · ${c.status}',
          customerName: c.customerName,
          status: c.status,
          lastMessageAt: c.startedAt,
        ),
      ),
      ...tickets.map(
        (t) => CshopInboxThread(
          id: 'ticket-${t.id}',
          title: t.subject,
          channel: t.channel,
          preview: t.description,
          customerName: t.customerName,
          status: t.status,
          lastMessageAt: t.createdAt,
        ),
      ),
      ...portalThreads,
    ];
    threads.sort((a, b) {
      final at = a.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bt = b.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bt.compareTo(at);
    });
    return threads;
  }

  List<CshopTimelineEvent> _buildTimeline({
    required List<CshopTicket> tickets,
    required List<CshopLiveChat> liveChats,
    required List<CshopActivity> activities,
  }) {
    final events = <CshopTimelineEvent>[
      ...activities.map(
        (a) => CshopTimelineEvent(
          id: a.id,
          label: a.summary,
          detail: a.actorLabel,
          channel: a.channel,
        ),
      ),
      ...liveChats
          .take(8)
          .map(
            (c) => CshopTimelineEvent(
              id: 'tl-chat-${c.id}',
              label: 'Live chat ${c.sessionCode}',
              detail: '${c.customerName ?? 'Visitor'} · ${c.status}',
              channel: 'chat',
            ),
          ),
      ...tickets
          .take(8)
          .map(
            (t) => CshopTimelineEvent(
              id: 'tl-ticket-${t.id}',
              label: t.subject,
              detail: '${t.customerName ?? 'Customer'} · ${t.status}',
              channel: t.channel,
            ),
          ),
    ];
    return events.take(20).toList();
  }

  List<CshopKpi> _deriveKpis({
    required List<CshopTicket> tickets,
    required List<CshopLiveChat> chats,
    required List<CshopEscalation> escalations,
    required List<CshopAgent> agents,
    int portalUnread = 0,
  }) {
    final open = tickets
        .where((t) => !{'resolved', 'closed'}.contains(t.status))
        .length
        .toDouble();
    final breaches = tickets.where((t) => t.slaBreached).length.toDouble();
    final waiting = chats
        .where((c) => {'waiting', 'queued'}.contains(c.status))
        .length
        .toDouble();
    final live = chats
        .where((c) => {'active', 'waiting', 'queued'}.contains(c.status))
        .length
        .toDouble();
    final openEsc = escalations
        .where((e) => e.status == 'open')
        .length
        .toDouble();
    final present = agents.where((a) => a.isPresent).length.toDouble();

    final responseSamples = tickets
        .map((t) => t.firstResponseMins)
        .whereType<double>()
        .toList();
    double? avgFirstResponse;
    if (responseSamples.isNotEmpty) {
      avgFirstResponse =
          responseSamples.reduce((a, b) => a + b) / responseSamples.length;
    }

    // Only operational counts from live desks — no seed CSAT / fake agent KPIs.
    return [
      CshopKpi(label: 'Open Tickets', value: open),
      CshopKpi(
        label: 'SLA Breaches',
        value: breaches,
        status: breaches > 0 ? 'watch' : 'ok',
      ),
      CshopKpi(
        label: 'Waiting Chats',
        value: waiting,
        status: waiting > 0 ? 'watch' : 'ok',
      ),
      CshopKpi(label: 'Open Live Chats', value: live),
      CshopKpi(
        label: 'Portal Unread',
        value: portalUnread.toDouble(),
        status: portalUnread > 0 ? 'watch' : 'ok',
      ),
      CshopKpi(
        label: 'Escalations',
        value: openEsc,
        status: openEsc > 0 ? 'watch' : 'ok',
      ),
      CshopKpi(label: 'Agents Present', value: present),
      if (avgFirstResponse != null)
        CshopKpi(
          label: 'Avg First Response',
          value: avgFirstResponse,
          unit: 'minutes',
        ),
    ];
  }

  static bool _isDemoRow(Map<String, dynamic> row) {
    final meta = row['metadata'];
    if (meta is Map && meta['demo'] == true) return true;
    if (row['is_demo'] == true) return true;
    return false;
  }

  Future<List<CshopTicketMessage>> listTicketMessages(String ticketId) async {
    final client = _client;
    if (client == null) return const [];
    final rows = await client
        .from('ticket_messages')
        .select()
        .eq('ticket_id', ticketId)
        .eq('is_deleted', false)
        .order('created_at', ascending: true);
    return (rows as List)
        .map(
          (e) =>
              CshopTicketMessage.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<void> replyToTicket({
    required String ticketId,
    required String message,
    bool isInternal = false,
    String? senderName,
  }) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    await client.rpc(
      'support_ticket_send_message',
      params: {
        'p_ticket_id': ticketId,
        'p_message': message.trim(),
        'p_is_internal': isInternal,
        'p_channel': 'portal',
        'p_message_type': isInternal ? 'note' : 'reply',
        'p_sender_name': senderName,
      },
    );
  }

  Future<void> updateTicket({
    required String ticketId,
    String? status,
    String? priority,
    String? assignedTo,
    bool unassign = false,
    String? categoryId,
    String? teamId,
    String? queueId,
    String? propertyId,
    String? adminNotes,
  }) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    await client.rpc(
      'manage_support_ticket',
      params: {
        'p_ticket_id': ticketId,
        'p_status': status,
        'p_priority': priority,
        'p_assignment_action': unassign
            ? 'unassign'
            : assignedTo == null
            ? 'keep'
            : 'assign',
        'p_assigned_to': assignedTo,
        'p_category_id': categoryId,
        'p_team_id': teamId,
        'p_queue_id': queueId,
        'p_property_id': propertyId,
        'p_admin_notes': adminNotes,
      },
    );
  }

  Future<void> assignTicketToMe(String ticketId) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    final uid = client.auth.currentUser?.id;
    if (uid == null) throw StateError('Not signed in');
    await updateTicket(ticketId: ticketId, assignedTo: uid);
  }

  Future<CshopTicket> createTicket({
    required String subject,
    required String description,
    String priority = 'normal',
    String customerType = 'client',
    String? categoryId,
    String? propertyId,
    String? customerUserId,
    String? customerName,
    String? customerEmail,
    String? customerPhone,
    String source = 'admin',
    String channel = 'portal',
  }) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    final row = await client.rpc(
      'create_support_ticket',
      params: {
        'p_subject': subject.trim(),
        'p_description': description.trim(),
        'p_priority': priority,
        'p_customer_type': customerType,
        'p_category_id': categoryId,
        'p_property_id': propertyId,
        'p_source': source,
        'p_channel': channel,
        'p_customer_user_id': customerUserId,
        'p_customer_name': customerName,
        'p_customer_email': customerEmail,
        'p_customer_phone': customerPhone,
      },
    );
    return CshopTicket.fromJson(Map<String, dynamic>.from(row as Map));
  }

  Future<List<SupportCategory>> listTicketCategories() async {
    final client = _client;
    if (client == null) return const [];
    final rows = await client
        .from('support_categories')
        .select()
        .eq('is_active', true)
        .order('sort_order');
    return (rows as List)
        .map(
          (row) =>
              SupportCategory.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList(growable: false);
  }

  Future<List<LiveChatPropertyOption>> listLiveChatProperties() async {
    final client = _client;
    if (client == null) return const [];
    final rows = await client
        .from('properties')
        .select(
          'id, title, slug, city, bedrooms, '
          'property_images(url, is_cover, sort_order, is_deleted)',
        )
        .eq('is_deleted', false)
        .order('title')
        .limit(120);
    return (rows as List)
        .map(
          (row) => LiveChatPropertyOption.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList(growable: false);
  }

  Future<List<SupportPropertyOption>> listTicketProperties() async {
    final client = _client;
    if (client == null) return const [];
    final rows = await client
        .from('properties')
        .select('id, title, estate:estates!properties_estate_id_fkey(name)')
        .eq('is_deleted', false)
        .order('title')
        .limit(200);
    return (rows as List)
        .map(
          (row) => SupportPropertyOption.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList(growable: false);
  }

  static String slugifyKnowledgeTitle(String title) {
    final base = title
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (base.isEmpty) {
      return 'article-${DateTime.now().millisecondsSinceEpoch}';
    }
    return base;
  }

  Future<CshopKnowledgeArticle> createKnowledgeArticle({
    required String title,
    required String body,
    String? summary,
    String status = 'draft',
    String? categoryId,
    List<String> tags = const [],
  }) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) throw ArgumentError('Title is required');
    final trimmedBody = body.trim();
    if (trimmedBody.isEmpty) throw ArgumentError('Body is required');
    final uid = client.auth.currentUser?.id;
    final email = client.auth.currentUser?.email;
    final payload = <String, dynamic>{
      'slug': slugifyKnowledgeTitle(trimmedTitle),
      'title': trimmedTitle,
      'body': trimmedBody,
      'summary': summary?.trim().isEmpty == true ? null : summary?.trim(),
      'status': status,
      'tags': tags,
      'authored_by': email ?? uid,
      'category_id': ?categoryId,
      if (status == 'published')
        'published_at': DateTime.now().toUtc().toIso8601String(),
    };
    final row = await client
        .from('support_knowledge_articles')
        .insert(payload)
        .select('*, category:support_knowledge_categories(name, slug)')
        .single();
    return CshopKnowledgeArticle.fromJson(Map<String, dynamic>.from(row));
  }

  Future<CshopKnowledgeArticle> updateKnowledgeArticle({
    required String id,
    String? title,
    String? body,
    String? summary,
    String? status,
    String? categoryId,
    List<String>? tags,
  }) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    final payload = <String, dynamic>{
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (title != null) payload['title'] = title.trim();
    if (body != null) payload['body'] = body.trim();
    if (summary != null) {
      payload['summary'] = summary.trim().isEmpty ? null : summary.trim();
    }
    if (status != null) {
      payload['status'] = status;
      if (status == 'published') {
        payload['published_at'] = DateTime.now().toUtc().toIso8601String();
      }
    }
    if (categoryId != null) payload['category_id'] = categoryId;
    if (tags != null) payload['tags'] = tags;
    final row = await client
        .from('support_knowledge_articles')
        .update(payload)
        .eq('id', id)
        .select('*, category:support_knowledge_categories(name, slug)')
        .single();
    return CshopKnowledgeArticle.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> archiveKnowledgeArticle(String id) async {
    await updateKnowledgeArticle(id: id, status: 'archived');
  }

  Future<void> updateEscalationStatus({
    required String id,
    required String status,
  }) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    final payload = <String, dynamic>{'status': status};
    if (status == 'resolved' || status == 'cancelled') {
      payload['resolved_at'] = DateTime.now().toUtc().toIso8601String();
    }
    await client.from('support_escalations').update(payload).eq('id', id);
  }

  Future<void> setMyAgentPresence(String status) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    await client.rpc(
      'set_my_support_agent_presence',
      params: {'p_status': status},
    );
  }

  Future<void> heartbeatMyAgent() async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    await client.rpc('heartbeat_my_support_agent');
  }

  String generateResolutionBriefing(CshopCommandCenterSnapshot snap) {
    final breaches = snap.tickets.where((t) => t.slaBreached).length;
    final openEsc = snap.escalations.where((e) => e.status == 'open').length;
    final waiting = snap.liveChats.where((c) => c.status == 'waiting').length;
    return 'Support brief: '
        '$breaches SLA breach(es), $openEsc open escalation(s), '
        '$waiting waiting chat(s). Prioritize waiting live chats first. '
        '${snap.aiDisclaimer}';
  }

  static List<String> detectSupportSignals(CshopCommandCenterSnapshot snap) {
    final signals = <String>[];
    if (snap.tickets.any((t) => t.slaBreached)) {
      signals.add('Critical: SLA breach on active ticket(s)');
    }
    if (snap.escalations.any((e) => e.status == 'open')) {
      signals.add('Open escalations require owner action');
    }
    if (snap.liveChats.any((c) => c.status == 'waiting')) {
      signals.add('Live chat queue has waiting visitors');
    }
    if (snap.feedback.any((f) => f.kind == 'nps' && (f.score ?? 10) <= 6)) {
      signals.add('NPS detractor feedback needs follow-up');
    }
    return signals;
  }
}
