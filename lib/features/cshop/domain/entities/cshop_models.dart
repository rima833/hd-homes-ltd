// Volume 4 Part 11 — Customer Support Omnichannel Platform (CSHOP) domain models.

const String kCshopAiDisclaimer =
    'AI-generated — editable / advisory. Support AI Resolution Intelligence™ '
    'outputs are drafts for human review, not guarantees of CX or SLA outcomes.';

enum SupportChannel {
  portal,
  chat,
  email,
  whatsapp,
  phone,
  omni;

  String get label => switch (this) {
        SupportChannel.portal => 'Portal',
        SupportChannel.chat => 'Live Chat',
        SupportChannel.email => 'Email',
        SupportChannel.whatsapp => 'WhatsApp',
        SupportChannel.phone => 'Phone',
        SupportChannel.omni => 'Omni',
      };

  static SupportChannel fromSlug(String? slug) {
    return SupportChannel.values.firstWhere(
      (e) => e.name == (slug ?? '').toLowerCase(),
      orElse: () => SupportChannel.portal,
    );
  }
}

enum TicketStatus {
  open,
  inProgress,
  pendingCustomer,
  escalated,
  resolved,
  closed;

  String get label => switch (this) {
        TicketStatus.open => 'Open',
        TicketStatus.inProgress => 'In Progress',
        TicketStatus.pendingCustomer => 'Pending Customer',
        TicketStatus.escalated => 'Escalated',
        TicketStatus.resolved => 'Resolved',
        TicketStatus.closed => 'Closed',
      };

  String get slug => switch (this) {
        TicketStatus.inProgress => 'in_progress',
        TicketStatus.pendingCustomer => 'pending_customer',
        _ => name,
      };

  static TicketStatus fromSlug(String? slug) {
    final s = (slug ?? 'open').toLowerCase();
    return switch (s) {
      'in_progress' => TicketStatus.inProgress,
      'pending_customer' => TicketStatus.pendingCustomer,
      'escalated' => TicketStatus.escalated,
      'resolved' => TicketStatus.resolved,
      'closed' => TicketStatus.closed,
      _ => TicketStatus.open,
    };
  }
}

enum TicketPriority {
  low,
  normal,
  high,
  urgent;

  String get label => switch (this) {
        TicketPriority.low => 'Low',
        TicketPriority.normal => 'Normal',
        TicketPriority.high => 'High',
        TicketPriority.urgent => 'Urgent',
      };

  static TicketPriority fromSlug(String? slug) {
    return TicketPriority.values.firstWhere(
      (e) => e.name == (slug ?? 'normal').toLowerCase(),
      orElse: () => TicketPriority.normal,
    );
  }
}

class CshopKpi {
  const CshopKpi({
    required this.label,
    required this.value,
    this.unit = 'count',
    this.status = 'ok',
    this.changePct,
  });

  final String label;
  final double value;
  final String unit;
  final String status;
  final double? changePct;

  String get displayValue {
    if (unit == 'percent') {
      return value == value.roundToDouble()
          ? '${value.toStringAsFixed(0)}%'
          : '${value.toStringAsFixed(1)}%';
    }
    if (unit == 'score') {
      return value.toStringAsFixed(1);
    }
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }

  factory CshopKpi.fromJson(Map<String, dynamic> json) {
    return CshopKpi(
      label: json['label'] as String? ?? 'KPI',
      value: (json['value'] as num?)?.toDouble() ?? 0,
      unit: json['unit'] as String? ?? 'count',
      status: json['status'] as String? ?? 'ok',
      changePct: (json['change_pct'] as num?)?.toDouble(),
    );
  }
}

class CshopTicket {
  const CshopTicket({
    required this.id,
    required this.subject,
    this.ticketNumber,
    this.description,
    this.status = 'open',
    this.priority = 'normal',
    this.channel = 'portal',
    this.customerName,
    this.customerEmail,
    this.category,
    this.assigneeLabel,
    this.slaBreached = false,
    this.csatScore,
    this.tags = const [],
    this.createdAt,
  });

  final String id;
  final String subject;
  final String? ticketNumber;
  final String? description;
  final String status;
  final String priority;
  final String channel;
  final String? customerName;
  final String? customerEmail;
  final String? category;
  final String? assigneeLabel;
  final bool slaBreached;
  final double? csatScore;
  final List<String> tags;
  final DateTime? createdAt;

  TicketStatus get statusEnum => TicketStatus.fromSlug(status);
  TicketPriority get priorityEnum => TicketPriority.fromSlug(priority);
  SupportChannel get channelEnum => SupportChannel.fromSlug(channel);

  factory CshopTicket.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'];
    return CshopTicket(
      id: json['id'] as String? ?? '',
      subject: json['subject'] as String? ?? 'Ticket',
      ticketNumber: json['ticket_number'] as String?,
      description: json['description'] as String?,
      status: json['status'] as String? ?? 'open',
      priority: json['priority'] as String? ?? 'normal',
      channel: json['channel'] as String? ?? 'portal',
      customerName: json['customer_name'] as String?,
      customerEmail: json['customer_email'] as String?,
      category: json['subcategory'] as String? ?? json['category'] as String?,
      assigneeLabel: json['assignee_label'] as String?,
      slaBreached: json['sla_breached'] as bool? ?? false,
      csatScore: (json['csat_score'] as num?)?.toDouble(),
      tags: rawTags is List ? rawTags.map((e) => e.toString()).toList() : const [],
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }
}

class CshopInboxThread {
  const CshopInboxThread({
    required this.id,
    required this.title,
    required this.channel,
    this.preview,
    this.customerName,
    this.status = 'open',
    this.lastMessageAt,
  });

  final String id;
  final String title;
  final String channel;
  final String? preview;
  final String? customerName;
  final String status;
  final DateTime? lastMessageAt;
}

class CshopLiveChat {
  const CshopLiveChat({
    required this.id,
    required this.sessionCode,
    this.customerName,
    this.status = 'waiting',
    this.agentName,
    this.messageCount = 0,
    this.startedAt,
  });

  final String id;
  final String sessionCode;
  final String? customerName;
  final String status;
  final String? agentName;
  final int messageCount;
  final DateTime? startedAt;

  factory CshopLiveChat.fromJson(Map<String, dynamic> json) {
    return CshopLiveChat(
      id: json['id'] as String? ?? '',
      sessionCode: json['session_code'] as String? ?? '',
      customerName: json['customer_name'] as String?,
      status: json['status'] as String? ?? 'waiting',
      agentName: json['agent_name'] as String?,
      messageCount: (json['message_count'] as num?)?.toInt() ?? 0,
      startedAt: DateTime.tryParse(json['started_at'] as String? ?? ''),
    );
  }
}

class CshopChatMessage {
  const CshopChatMessage({
    required this.id,
    required this.sessionId,
    required this.body,
    this.senderType = 'customer',
    this.senderName,
    this.createdAt,
  });

  final String id;
  final String sessionId;
  final String body;
  final String senderType;
  final String? senderName;
  final DateTime? createdAt;

  factory CshopChatMessage.fromJson(Map<String, dynamic> json) {
    return CshopChatMessage(
      id: json['id'] as String? ?? '',
      sessionId: json['session_id'] as String? ?? '',
      body: json['body'] as String? ?? '',
      senderType: json['sender_type'] as String? ?? 'customer',
      senderName: json['sender_name'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }
}

class CshopEmailThread {
  const CshopEmailThread({
    required this.id,
    required this.subject,
    this.counterpartEmail,
    this.status = 'open',
    this.lastMessageAt,
  });

  final String id;
  final String subject;
  final String? counterpartEmail;
  final String status;
  final DateTime? lastMessageAt;

  factory CshopEmailThread.fromJson(Map<String, dynamic> json) {
    return CshopEmailThread(
      id: json['id'] as String? ?? '',
      subject: json['subject'] as String? ?? 'Email',
      counterpartEmail: json['counterpart_email'] as String?,
      status: json['status'] as String? ?? 'open',
      lastMessageAt: DateTime.tryParse(json['last_message_at'] as String? ?? ''),
    );
  }
}

class CshopWhatsappConversation {
  const CshopWhatsappConversation({
    required this.id,
    required this.phoneE164,
    this.customerName,
    this.status = 'open',
    this.lastPreview,
    this.lastMessageAt,
  });

  final String id;
  final String phoneE164;
  final String? customerName;
  final String status;
  final String? lastPreview;
  final DateTime? lastMessageAt;

  factory CshopWhatsappConversation.fromJson(Map<String, dynamic> json) {
    return CshopWhatsappConversation(
      id: json['id'] as String? ?? '',
      phoneE164: json['phone_e164'] as String? ?? '',
      customerName: json['customer_name'] as String?,
      status: json['status'] as String? ?? 'open',
      lastPreview: json['last_preview'] as String?,
      lastMessageAt: DateTime.tryParse(json['last_message_at'] as String? ?? ''),
    );
  }
}

class CshopKnowledgeArticle {
  const CshopKnowledgeArticle({
    required this.id,
    required this.slug,
    required this.title,
    required this.body,
    this.summary,
    this.category = 'general',
    this.status = 'published',
    this.tags = const [],
    this.viewCount = 0,
  });

  final String id;
  final String slug;
  final String title;
  final String body;
  final String? summary;
  final String category;
  final String status;
  final List<String> tags;
  final int viewCount;

  factory CshopKnowledgeArticle.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'];
    return CshopKnowledgeArticle(
      id: json['id'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      summary: json['summary'] as String?,
      category: json['category'] as String? ?? 'general',
      status: json['status'] as String? ?? 'published',
      tags: rawTags is List ? rawTags.map((e) => e.toString()).toList() : const [],
      viewCount: (json['view_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class CshopSla {
  const CshopSla({
    required this.id,
    required this.code,
    required this.name,
    this.channel = 'omni',
    this.firstResponseMins = 60,
    this.resolveMins = 1440,
    this.isActive = true,
  });

  final String id;
  final String code;
  final String name;
  final String channel;
  final int firstResponseMins;
  final int resolveMins;
  final bool isActive;

  factory CshopSla.fromJson(Map<String, dynamic> json) {
    return CshopSla(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      channel: json['channel'] as String? ?? 'omni',
      firstResponseMins: (json['first_response_mins'] as num?)?.toInt() ?? 60,
      resolveMins: (json['resolve_mins'] as num?)?.toInt() ?? 1440,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class CshopEscalation {
  const CshopEscalation({
    required this.id,
    required this.reason,
    this.level = 1,
    this.status = 'open',
    this.escalatedTo,
    this.ticketLabel,
    this.dueAt,
  });

  final String id;
  final String reason;
  final int level;
  final String status;
  final String? escalatedTo;
  final String? ticketLabel;
  final DateTime? dueAt;

  factory CshopEscalation.fromJson(Map<String, dynamic> json) {
    return CshopEscalation(
      id: json['id'] as String? ?? '',
      reason: json['reason'] as String? ?? 'Escalation',
      level: (json['level'] as num?)?.toInt() ?? 1,
      status: json['status'] as String? ?? 'open',
      escalatedTo: json['escalated_to'] as String?,
      ticketLabel: json['ticket_label'] as String?,
      dueAt: DateTime.tryParse(json['due_at'] as String? ?? ''),
    );
  }
}

class CshopAgent {
  const CshopAgent({
    required this.id,
    required this.displayName,
    this.email,
    this.roleTitle = 'Agent',
    this.status = 'available',
    this.teamName,
    this.skills = const [],
  });

  final String id;
  final String displayName;
  final String? email;
  final String roleTitle;
  final String status;
  final String? teamName;
  final List<String> skills;

  factory CshopAgent.fromJson(Map<String, dynamic> json) {
    final rawSkills = json['skills'];
    return CshopAgent(
      id: json['id'] as String? ?? '',
      displayName: json['display_name'] as String? ?? 'Agent',
      email: json['email'] as String?,
      roleTitle: json['role_title'] as String? ?? 'Agent',
      status: json['status'] as String? ?? 'available',
      teamName: json['team_name'] as String?,
      skills: rawSkills is List
          ? rawSkills.map((e) => e.toString()).toList()
          : const [],
    );
  }
}

class CshopFeedback {
  const CshopFeedback({
    required this.id,
    required this.label,
    this.score,
    this.comment,
    this.kind = 'csat',
    this.customerName,
    this.channel,
  });

  final String id;
  final String label;
  final double? score;
  final String? comment;
  final String kind;
  final String? customerName;
  final String? channel;
}

class CshopAiInsight {
  const CshopAiInsight({
    required this.id,
    required this.title,
    required this.body,
    this.category = 'ops',
    this.confidencePct,
    this.editable = true,
    this.disclaimer = kCshopAiDisclaimer,
  });

  final String id;
  final String title;
  final String body;
  final String category;
  final double? confidencePct;
  final bool editable;
  final String disclaimer;

  factory CshopAiInsight.fromJson(Map<String, dynamic> json) {
    return CshopAiInsight(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Insight',
      body: json['body'] as String? ?? '',
      category: json['category'] as String? ?? 'ops',
      confidencePct: (json['confidence_pct'] as num?)?.toDouble(),
      editable: json['is_editable'] as bool? ?? true,
      disclaimer: json['disclaimer'] as String? ?? kCshopAiDisclaimer,
    );
  }
}

class CshopTimelineEvent {
  const CshopTimelineEvent({
    required this.id,
    required this.label,
    this.detail,
    this.channel,
    this.occurredAt,
  });

  final String id;
  final String label;
  final String? detail;
  final String? channel;
  final DateTime? occurredAt;
}

class CshopActivity {
  const CshopActivity({
    required this.id,
    required this.action,
    required this.summary,
    this.actorLabel,
    this.channel,
    this.occurredAt,
  });

  final String id;
  final String action;
  final String summary;
  final String? actorLabel;
  final String? channel;
  final DateTime? occurredAt;

  factory CshopActivity.fromJson(Map<String, dynamic> json) {
    return CshopActivity(
      id: json['id'] as String? ?? '',
      action: json['action'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      actorLabel: json['actor_label'] as String?,
      channel: json['channel'] as String?,
      occurredAt: DateTime.tryParse(json['occurred_at'] as String? ?? ''),
    );
  }
}

class CshopCommandCenterSnapshot {
  const CshopCommandCenterSnapshot({
    required this.kpis,
    required this.tickets,
    required this.inbox,
    required this.liveChats,
    required this.chatMessages,
    required this.emailThreads,
    required this.whatsapp,
    required this.knowledge,
    required this.slas,
    required this.escalations,
    required this.agents,
    required this.feedback,
    required this.aiInsights,
    required this.timeline,
    required this.activities,
    this.fromRemote = false,
    this.loadedAt,
    this.aiDisclaimer = kCshopAiDisclaimer,
  });

  final List<CshopKpi> kpis;
  final List<CshopTicket> tickets;
  final List<CshopInboxThread> inbox;
  final List<CshopLiveChat> liveChats;
  final List<CshopChatMessage> chatMessages;
  final List<CshopEmailThread> emailThreads;
  final List<CshopWhatsappConversation> whatsapp;
  final List<CshopKnowledgeArticle> knowledge;
  final List<CshopSla> slas;
  final List<CshopEscalation> escalations;
  final List<CshopAgent> agents;
  final List<CshopFeedback> feedback;
  final List<CshopAiInsight> aiInsights;
  final List<CshopTimelineEvent> timeline;
  final List<CshopActivity> activities;
  final bool fromRemote;
  final DateTime? loadedAt;
  final String aiDisclaimer;
}

abstract final class CshopDemo {
  static CshopCommandCenterSnapshot snapshot() {
    final now = DateTime.now();
    final tickets = _tickets(now);
    return CshopCommandCenterSnapshot(
      kpis: _kpis(),
      tickets: tickets,
      inbox: _inbox(now),
      liveChats: _liveChats(now),
      chatMessages: _chatMessages(now),
      emailThreads: _email(now),
      whatsapp: _whatsapp(now),
      knowledge: _knowledge(),
      slas: _slas(),
      escalations: _escalations(now),
      agents: _agents(),
      feedback: _feedback(),
      aiInsights: _aiInsights(),
      timeline: _timeline(now),
      activities: _activities(now),
      fromRemote: false,
      loadedAt: now,
    );
  }

  static List<CshopKpi> _kpis() => const [
        CshopKpi(label: 'Open Tickets', value: 12, changePct: -8.3),
        CshopKpi(label: 'SLA Breaches', value: 2, status: 'watch', changePct: 100),
        CshopKpi(label: 'Avg First Response', value: 18, unit: 'count', changePct: -12),
        CshopKpi(label: 'Live Chats', value: 3, changePct: 50),
        CshopKpi(label: 'CSAT', value: 4.6, unit: 'score', changePct: 4.5),
        CshopKpi(label: 'NPS', value: 42, unit: 'score', changePct: 6.0),
        CshopKpi(label: 'Escalations', value: 2, status: 'watch'),
        CshopKpi(label: 'Agents Online', value: 2, changePct: 0),
      ];

  static List<CshopTicket> _tickets(DateTime now) => [
        CshopTicket(
          id: 'f110000a-0000-4000-8000-000000000001',
          ticketNumber: 'HD-T-2026-1101',
          subject: 'Installment receipt not reflecting',
          description: 'Paystack receipt missing in portal.',
          status: 'in_progress',
          priority: 'high',
          channel: 'email',
          customerName: 'Ngozi Adeyemi',
          customerEmail: 'ngozi.adeyemi@example.com',
          category: 'billing',
          assigneeLabel: 'Adaeze Okonkwo',
          tags: const ['billing', 'paystack'],
          createdAt: now.subtract(const Duration(hours: 2)),
        ),
        CshopTicket(
          id: 'f110000a-0000-4000-8000-000000000002',
          ticketNumber: 'HD-T-2026-1102',
          subject: 'WhatsApp: Plot allocation clarification',
          status: 'escalated',
          priority: 'urgent',
          channel: 'whatsapp',
          customerName: 'Tunde Bakare',
          category: 'allocation',
          assigneeLabel: 'Fatima Yusuf',
          slaBreached: true,
          tags: const ['whatsapp', 'sla_breach'],
          createdAt: now.subtract(const Duration(hours: 3)),
        ),
        CshopTicket(
          id: 'f110000a-0000-4000-8000-000000000003',
          ticketNumber: 'HD-T-2026-1103',
          subject: 'Live chat: Cannot upload KYC PDF',
          status: 'open',
          priority: 'high',
          channel: 'chat',
          customerName: 'Amaka Obi',
          category: 'kyc_upload',
          assigneeLabel: 'Ibrahim Ade',
          tags: const ['chat', 'kyc'],
          createdAt: now.subtract(const Duration(minutes: 15)),
        ),
        CshopTicket(
          id: 'f110000a-0000-4000-8000-000000000004',
          ticketNumber: 'HD-T-2026-1104',
          subject: 'Construction snag — bathroom tiling',
          status: 'pending_customer',
          priority: 'normal',
          channel: 'portal',
          customerName: 'Emeka Nwosu',
          category: 'snags',
          assigneeLabel: 'Chinedu Bello',
          createdAt: now.subtract(const Duration(days: 1)),
        ),
        CshopTicket(
          id: 'f110000a-0000-4000-8000-000000000005',
          ticketNumber: 'HD-T-2026-1105',
          subject: 'Title deed soft copy request',
          status: 'resolved',
          priority: 'normal',
          channel: 'email',
          customerName: 'Hadiza Danladi',
          category: 'title',
          csatScore: 5,
          createdAt: now.subtract(const Duration(days: 2)),
        ),
      ];

  static List<CshopInboxThread> _inbox(DateTime now) => [
        CshopInboxThread(
          id: 'inbox-wa-1',
          title: 'Plot allocation clarification',
          channel: 'whatsapp',
          preview: 'Please send Block B plot map today…',
          customerName: 'Tunde Bakare',
          status: 'escalated',
          lastMessageAt: now.subtract(const Duration(minutes: 20)),
        ),
        CshopInboxThread(
          id: 'inbox-em-1',
          title: 'Installment receipt not reflecting',
          channel: 'email',
          preview: 'Re-syncing your Paystack receipt…',
          customerName: 'Ngozi Adeyemi',
          lastMessageAt: now.subtract(const Duration(minutes: 35)),
        ),
        CshopInboxThread(
          id: 'inbox-ch-1',
          title: 'KYC PDF upload failure',
          channel: 'chat',
          preview: 'Uploads fail at ~8MB…',
          customerName: 'Amaka Obi',
          lastMessageAt: now.subtract(const Duration(minutes: 8)),
        ),
      ];

  static List<CshopLiveChat> _liveChats(DateTime now) => [
        CshopLiveChat(
          id: 'f110000f-0000-4000-8000-000000000001',
          sessionCode: 'LC-2026-441',
          customerName: 'Amaka Obi',
          status: 'active',
          agentName: 'Ibrahim Ade',
          messageCount: 3,
          startedAt: now.subtract(const Duration(minutes: 12)),
        ),
        CshopLiveChat(
          id: 'f110000f-0000-4000-8000-000000000002',
          sessionCode: 'LC-2026-442',
          customerName: 'Visitor — Lekki brochure',
          status: 'waiting',
          messageCount: 1,
          startedAt: now.subtract(const Duration(minutes: 2)),
        ),
      ];

  static List<CshopChatMessage> _chatMessages(DateTime now) => [
        CshopChatMessage(
          id: 'f1100010-0000-4000-8000-000000000001',
          sessionId: 'f110000f-0000-4000-8000-000000000001',
          body: 'Hi — KYC upload keeps failing at 8MB.',
          senderType: 'customer',
          senderName: 'Amaka Obi',
          createdAt: now.subtract(const Duration(minutes: 11)),
        ),
        CshopChatMessage(
          id: 'f1100010-0000-4000-8000-000000000002',
          sessionId: 'f110000f-0000-4000-8000-000000000001',
          body: 'Try compressing under 5MB or email docs@hdhomes.demo.',
          senderType: 'agent',
          senderName: 'Ibrahim Ade',
          createdAt: now.subtract(const Duration(minutes: 9)),
        ),
      ];

  static List<CshopEmailThread> _email(DateTime now) => [
        CshopEmailThread(
          id: 'f1100011-0000-4000-8000-000000000001',
          subject: 'Installment receipt not reflecting',
          counterpartEmail: 'ngozi.adeyemi@example.com',
          lastMessageAt: now.subtract(const Duration(minutes: 35)),
        ),
        CshopEmailThread(
          id: 'f1100011-0000-4000-8000-000000000002',
          subject: 'Title deed soft copy request',
          counterpartEmail: 'hadiza.danladi@example.com',
          status: 'closed',
          lastMessageAt: now.subtract(const Duration(hours: 18)),
        ),
      ];

  static List<CshopWhatsappConversation> _whatsapp(DateTime now) => [
        CshopWhatsappConversation(
          id: 'f1100013-0000-4000-8000-000000000001',
          phoneE164: '+2348022002202',
          customerName: 'Tunde Bakare',
          status: 'open',
          lastPreview: 'Acknowledged — escalated to Sales Care…',
          lastMessageAt: now.subtract(const Duration(minutes: 20)),
        ),
      ];

  static List<CshopKnowledgeArticle> _knowledge() => const [
        CshopKnowledgeArticle(
          id: 'f1100016-0000-4000-8000-000000000001',
          slug: 'paystack-receipt-sync',
          title: 'Paystack receipt sync delays',
          summary: 'When payments succeed but portal receipts lag.',
          body:
              'Paystack webhooks may lag up to 30 minutes. Check FAPMS reconciliation then force re-sync.',
          category: 'payments',
          tags: ['billing', 'paystack'],
          viewCount: 42,
        ),
        CshopKnowledgeArticle(
          id: 'f1100016-0000-4000-8000-000000000002',
          slug: 'kyc-upload-limits',
          title: 'How to upload KYC documents',
          summary: 'File size and format guidance.',
          body: 'Accepted: PDF/JPG/PNG under 5MB. Or email docs@hdhomes.demo.',
          category: 'documents',
          tags: ['kyc', 'portal'],
          viewCount: 88,
        ),
        CshopKnowledgeArticle(
          id: 'f1100016-0000-4000-8000-000000000003',
          slug: 'whatsapp-sla-playbook',
          title: 'WhatsApp urgent SLA playbook',
          summary: 'Internal first-response guide.',
          body: 'Urgent WhatsApp: first response 15m; resolve 2h. Breach → Sales Care Lead.',
          category: 'agents',
          tags: ['sla', 'whatsapp'],
          viewCount: 31,
        ),
      ];

  static List<CshopSla> _slas() => const [
        CshopSla(
          id: 'f1100006-0000-4000-8000-000000000001',
          code: 'SLA-OMNI-NORMAL',
          name: 'Omni Normal',
          firstResponseMins: 120,
          resolveMins: 1440,
        ),
        CshopSla(
          id: 'f1100006-0000-4000-8000-000000000002',
          code: 'SLA-CHAT-HIGH',
          name: 'Live Chat High',
          channel: 'chat',
          firstResponseMins: 5,
          resolveMins: 240,
        ),
        CshopSla(
          id: 'f1100006-0000-4000-8000-000000000003',
          code: 'SLA-WA-URGENT',
          name: 'WhatsApp Urgent',
          channel: 'whatsapp',
          firstResponseMins: 15,
          resolveMins: 120,
        ),
      ];

  static List<CshopEscalation> _escalations(DateTime now) => [
        CshopEscalation(
          id: 'f110000c-0000-4000-8000-000000000001',
          reason: 'SLA first-response breach on WhatsApp urgent allocation case',
          level: 2,
          escalatedTo: 'Sales Care Lead',
          ticketLabel: 'HD-T-2026-1102',
          dueAt: now.add(const Duration(hours: 1)),
        ),
        CshopEscalation(
          id: 'f110000c-0000-4000-8000-000000000002',
          reason: 'Billing sync delay beyond email billing resolve window risk',
          level: 1,
          status: 'acknowledged',
          escalatedTo: 'Tech Ops Desk',
          ticketLabel: 'HD-T-2026-1101',
          dueAt: now.add(const Duration(hours: 3)),
        ),
      ];

  static List<CshopAgent> _agents() => const [
        CshopAgent(
          id: 'f1100008-0000-4000-8000-000000000001',
          displayName: 'Adaeze Okonkwo',
          email: 'adaeze.support@hdhomes.demo',
          roleTitle: 'Senior Agent',
          status: 'available',
          teamName: 'Customer Support',
          skills: ['billing', 'live_chat'],
        ),
        CshopAgent(
          id: 'f1100008-0000-4000-8000-000000000002',
          displayName: 'Chinedu Bello',
          roleTitle: 'Agent',
          status: 'busy',
          teamName: 'Customer Support',
          skills: ['documents'],
        ),
        CshopAgent(
          id: 'f1100008-0000-4000-8000-000000000003',
          displayName: 'Fatima Yusuf',
          roleTitle: 'Sales Care Lead',
          status: 'available',
          teamName: 'Sales Care Desk',
          skills: ['sales'],
        ),
        CshopAgent(
          id: 'f1100008-0000-4000-8000-000000000004',
          displayName: 'Ibrahim Ade',
          roleTitle: 'Tech Desk',
          status: 'away',
          teamName: 'Technical Ops Desk',
          skills: ['live_chat'],
        ),
      ];

  static List<CshopFeedback> _feedback() => const [
        CshopFeedback(
          id: 'f1100019-0000-4000-8000-000000000001',
          label: 'CSAT — Title deed request',
          score: 5,
          comment: 'Fast and clear',
          kind: 'csat',
          customerName: 'Hadiza Danladi',
          channel: 'email',
        ),
        CshopFeedback(
          id: 'f110001a-0000-4000-8000-000000000001',
          label: 'NPS — Investor',
          score: 9,
          comment: 'Would recommend HD Homes after-sales care',
          kind: 'nps',
          customerName: 'Hadiza Danladi',
        ),
        CshopFeedback(
          id: 'f110001a-0000-4000-8000-000000000003',
          label: 'NPS — Client',
          score: 4,
          comment: 'Portal upload friction is frustrating',
          kind: 'nps',
          customerName: 'Amaka Obi',
        ),
      ];

  static List<CshopAiInsight> _aiInsights() => const [
        CshopAiInsight(
          id: 'f110001f-0000-4000-8000-000000000001',
          title: 'Allocation SLA pattern',
          body:
              'WhatsApp allocation tickets drive most urgent breaches. Pre-empt with plot-map macros for Sales Care.',
          category: 'sla',
          confidencePct: 78,
        ),
        CshopAiInsight(
          id: 'f110001f-0000-4000-8000-000000000002',
          title: 'KYC upload friction',
          body:
              'Live chat + portal tickets cluster on PDF size limits. Clarify guidance and consider 8MB soft limit (advisory).',
          category: 'portal',
          confidencePct: 71,
        ),
        CshopAiInsight(
          id: 'f110001f-0000-4000-8000-000000000003',
          title: 'CSAT uplift opportunity',
          body:
              'Resolved document cases score highest CSAT — reuse same-day email macros for billing receipt sync.',
          category: 'cx',
          confidencePct: 66,
        ),
      ];

  static List<CshopTimelineEvent> _timeline(DateTime now) => [
        CshopTimelineEvent(
          id: 'tl-1',
          label: 'Ticket opened via WhatsApp',
          detail: 'HD-T-2026-1102 — allocation clarification',
          channel: 'whatsapp',
          occurredAt: now.subtract(const Duration(hours: 3)),
        ),
        CshopTimelineEvent(
          id: 'tl-2',
          label: 'SLA breach detected',
          detail: 'First response overdue — auto-escalated L2',
          channel: 'whatsapp',
          occurredAt: now.subtract(const Duration(hours: 1)),
        ),
        CshopTimelineEvent(
          id: 'tl-3',
          label: 'Live chat started',
          detail: 'LC-2026-441 — KYC upload',
          channel: 'chat',
          occurredAt: now.subtract(const Duration(minutes: 12)),
        ),
        CshopTimelineEvent(
          id: 'tl-4',
          label: 'CSAT 5 received',
          detail: 'Hadiza Danladi — title soft copy',
          channel: 'email',
          occurredAt: now.subtract(const Duration(hours: 18)),
        ),
      ];

  static List<CshopActivity> _activities(DateTime now) => [
        CshopActivity(
          id: 'f110001c-0000-4000-8000-000000000001',
          action: 'ticket.opened',
          summary: 'Ticket HD-T-2026-1103 opened via live chat',
          actorLabel: 'System',
          channel: 'chat',
          occurredAt: now.subtract(const Duration(minutes: 14)),
        ),
        CshopActivity(
          id: 'f110001c-0000-4000-8000-000000000002',
          action: 'sla.breached',
          summary: 'WhatsApp urgent SLA breached on HD-T-2026-1102',
          actorLabel: 'SLA Engine',
          channel: 'whatsapp',
          occurredAt: now.subtract(const Duration(hours: 1)),
        ),
        CshopActivity(
          id: 'f110001c-0000-4000-8000-000000000003',
          action: 'escalation.opened',
          summary: 'Level-2 escalation to Sales Care Lead',
          actorLabel: 'Routing Engine',
          channel: 'whatsapp',
          occurredAt: now.subtract(const Duration(minutes: 50)),
        ),
      ];
}
