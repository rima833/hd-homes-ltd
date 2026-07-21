import 'package:hdhomesproject/features/cshop/domain/entities/cshop_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Loads Support Command Center snapshot from Supabase (falls back to demo).
class CshopService {
  CshopService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  Future<CshopCommandCenterSnapshot> loadCommandCenter() async {
    final demo = CshopDemo.snapshot();
    final client = _client;
    if (client == null) return demo;

    try {
      List<CshopTicket> tickets = demo.tickets;
      try {
        final rows = await client
            .from('tickets')
            .select()
            .order('created_at', ascending: false)
            .limit(50);
        if (rows.isNotEmpty) {
          tickets = rows
              .map(
                (e) =>
                    CshopTicket.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<CshopLiveChat> liveChats = demo.liveChats;
      try {
        final rows = await client
            .from('live_chat_sessions')
            .select()
            .order('started_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          liveChats = rows
              .map(
                (e) =>
                    CshopLiveChat.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<CshopChatMessage> chatMessages = demo.chatMessages;
      try {
        final rows = await client
            .from('live_chat_messages')
            .select()
            .order('created_at', ascending: false)
            .limit(80);
        if (rows.isNotEmpty) {
          chatMessages = rows
              .map(
                (e) => CshopChatMessage.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<CshopEmailThread> emailThreads = demo.emailThreads;
      try {
        final rows = await client
            .from('support_email_threads')
            .select()
            .order('last_message_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          emailThreads = rows
              .map(
                (e) => CshopEmailThread.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<CshopWhatsappConversation> whatsapp = demo.whatsapp;
      try {
        final rows = await client
            .from('whatsapp_conversations')
            .select()
            .order('last_message_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          whatsapp = rows
              .map(
                (e) => CshopWhatsappConversation.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<CshopKnowledgeArticle> knowledge = demo.knowledge;
      try {
        final rows = await client
            .from('support_knowledge_articles')
            .select()
            .order('updated_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          knowledge = rows
              .map(
                (e) => CshopKnowledgeArticle.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<CshopSla> slas = demo.slas;
      try {
        final rows = await client.from('support_slas').select().limit(20);
        if (rows.isNotEmpty) {
          slas = rows
              .map(
                (e) => CshopSla.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<CshopEscalation> escalations = demo.escalations;
      try {
        final rows = await client
            .from('support_escalations')
            .select()
            .order('created_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          escalations = rows
              .map(
                (e) => CshopEscalation.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<CshopAgent> agents = demo.agents;
      try {
        final rows = await client.from('support_agents').select().limit(40);
        if (rows.isNotEmpty) {
          agents = rows
              .map(
                (e) =>
                    CshopAgent.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<CshopAiInsight> aiInsights = demo.aiInsights;
      try {
        final rows = await client
            .from('support_ai_insights')
            .select()
            .order('created_at', ascending: false)
            .limit(20);
        if (rows.isNotEmpty) {
          aiInsights = rows
              .map(
                (e) => CshopAiInsight.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<CshopActivity> activities = demo.activities;
      try {
        final rows = await client
            .from('support_activity_logs')
            .select()
            .order('occurred_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          activities = rows
              .map(
                (e) => CshopActivity.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<CshopFeedback> feedback = demo.feedback;
      try {
        final csat = await client.from('csat_surveys').select().limit(20);
        final nps = await client.from('nps_surveys').select().limit(20);
        final merged = <CshopFeedback>[];
        for (final e in csat) {
          final m = Map<String, dynamic>.from(e as Map);
          merged.add(
            CshopFeedback(
              id: m['id'] as String? ?? '',
              label: 'CSAT',
              score: (m['score'] as num?)?.toDouble(),
              comment: m['comment'] as String?,
              kind: 'csat',
              customerName: m['customer_name'] as String?,
              channel: m['channel'] as String?,
            ),
          );
        }
        for (final e in nps) {
          final m = Map<String, dynamic>.from(e as Map);
          merged.add(
            CshopFeedback(
              id: m['id'] as String? ?? '',
              label: 'NPS',
              score: (m['score'] as num?)?.toDouble(),
              comment: m['comment'] as String?,
              kind: 'nps',
              customerName: m['customer_name'] as String?,
            ),
          );
        }
        if (merged.isNotEmpty) feedback = merged;
      } catch (_) {}

      final kpis = _deriveKpis(tickets, liveChats, escalations, agents, feedback);

      return CshopCommandCenterSnapshot(
        kpis: kpis,
        tickets: tickets,
        inbox: demo.inbox,
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
        timeline: demo.timeline,
        activities: activities,
        fromRemote: true,
        loadedAt: DateTime.now(),
      );
    } catch (_) {
      return demo;
    }
  }

  List<CshopKpi> _deriveKpis(
    List<CshopTicket> tickets,
    List<CshopLiveChat> chats,
    List<CshopEscalation> escalations,
    List<CshopAgent> agents,
    List<CshopFeedback> feedback,
  ) {
    final open = tickets
        .where((t) => !{'resolved', 'closed'}.contains(t.status))
        .length
        .toDouble();
    final breaches =
        tickets.where((t) => t.slaBreached).length.toDouble();
    final live =
        chats.where((c) => c.status == 'active' || c.status == 'waiting').length
            .toDouble();
    final online =
        agents.where((a) => a.status == 'available').length.toDouble();
    final csatScores =
        feedback.where((f) => f.kind == 'csat' && f.score != null).toList();
    final avgCsat = csatScores.isEmpty
        ? 0.0
        : csatScores.map((f) => f.score!).reduce((a, b) => a + b) /
            csatScores.length;
    final openEsc =
        escalations.where((e) => e.status == 'open').length.toDouble();

    return [
      CshopKpi(label: 'Open Tickets', value: open),
      CshopKpi(
        label: 'SLA Breaches',
        value: breaches,
        status: breaches > 0 ? 'watch' : 'ok',
      ),
      CshopKpi(label: 'Live Chats', value: live),
      CshopKpi(label: 'CSAT', value: avgCsat, unit: 'score'),
      CshopKpi(label: 'Escalations', value: openEsc, status: openEsc > 0 ? 'watch' : 'ok'),
      CshopKpi(label: 'Agents Online', value: online),
    ];
  }

  String generateResolutionBriefing(CshopCommandCenterSnapshot snap) {
    final breaches = snap.tickets.where((t) => t.slaBreached).length;
    final openEsc = snap.escalations.where((e) => e.status == 'open').length;
    final waiting = snap.liveChats.where((c) => c.status == 'waiting').length;
    return 'AI Resolution Intelligence™ advisory brief: '
        '$breaches SLA breach(es), $openEsc open escalation(s), '
        '$waiting waiting chat(s). Prioritize WhatsApp urgent allocation '
        'macros and KYC upload guidance. ${snap.aiDisclaimer}';
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
