import 'package:hdhomesproject/features/authentication/domain/entities/app_role.dart';

/// AI assistant personas / copilots.
enum AiAssistantKind {
  general,
  property,
  investment,
  crm,
  content,
  report,
  executive,
  sales,
  knowledge,
  workflow;

  String get label => switch (this) {
        AiAssistantKind.general => 'Digital Assistant',
        AiAssistantKind.property => 'Property Assistant',
        AiAssistantKind.investment => 'Investment Assistant',
        AiAssistantKind.crm => 'CRM Assistant',
        AiAssistantKind.content => 'Content Assistant',
        AiAssistantKind.report => 'Report Generator',
        AiAssistantKind.executive => 'AI Executive Copilot™',
        AiAssistantKind.sales => 'AI Sales Copilot™',
        AiAssistantKind.knowledge => 'AI Knowledge Hub™',
        AiAssistantKind.workflow => 'Workflow Assistant',
      };

  String get slug => name;

  String? get requiredPermission => switch (this) {
        AiAssistantKind.general => null,
        AiAssistantKind.property => null,
        AiAssistantKind.investment => null,
        AiAssistantKind.crm => 'manage_crm',
        AiAssistantKind.content => null,
        AiAssistantKind.report => 'manage_reports',
        AiAssistantKind.executive => 'manage_reports',
        AiAssistantKind.sales => 'manage_crm',
        AiAssistantKind.knowledge => null,
        AiAssistantKind.workflow => 'manage_crm',
      };

  static AiAssistantKind fromSlug(String? raw) {
    return AiAssistantKind.values.firstWhere(
      (e) => e.slug == (raw ?? 'general'),
      orElse: () => AiAssistantKind.general,
    );
  }
}

enum AiMessageRole { user, assistant, system }

enum AiFeedbackVote { helpful, notHelpful }

enum AiProviderKind {
  localFoundation,
  openAi,
  anthropic,
  gemini,
  azureOpenAi,
  selfHosted;

  String get label => switch (this) {
        AiProviderKind.localFoundation => 'HD Homes Local Foundation',
        AiProviderKind.openAi => 'OpenAI',
        AiProviderKind.anthropic => 'Anthropic',
        AiProviderKind.gemini => 'Google Gemini',
        AiProviderKind.azureOpenAi => 'Azure OpenAI',
        AiProviderKind.selfHosted => 'Self-hosted',
      };
}

/// Context injected into every AI Gateway request (permission-filtered upstream).
class AiRequestContext {
  const AiRequestContext({
    required this.userId,
    this.displayName,
    this.role,
    this.permissions = const {},
    this.isStaff = false,
    this.department,
    this.currentPage,
    this.currentPropertyId,
    this.organizationName = 'HD Homes Ltd',
    this.recentActivity = const [],
    this.savedSearchHints = const [],
  });

  final String userId;
  final String? displayName;
  final AppRole? role;
  final Set<String> permissions;
  final bool isStaff;
  final String? department;
  final String? currentPage;
  final String? currentPropertyId;
  final String organizationName;
  final List<String> recentActivity;
  final List<String> savedSearchHints;

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'display_name': displayName,
        'role': role?.slug,
        'department': department,
        'current_page': currentPage,
        'current_property_id': currentPropertyId,
        'organization': organizationName,
        'recent_activity': recentActivity,
        'saved_searches': savedSearchHints,
        'permission_count': permissions.length,
        'is_staff': isStaff,
      };
}

class AiMessage {
  const AiMessage({
    required this.id,
    required this.role,
    required this.content,
    this.createdAt,
    this.suggestedFollowUps = const [],
    this.linkedResources = const [],
    this.requiresApproval = false,
    this.explanation,
    this.promptTemplateSlug,
  });

  final String id;
  final AiMessageRole role;
  final String content;
  final DateTime? createdAt;
  final List<String> suggestedFollowUps;
  final List<AiLinkedResource> linkedResources;
  final bool requiresApproval;
  final String? explanation;
  final String? promptTemplateSlug;

  factory AiMessage.fromRow(Map<String, dynamic> row) {
    final roleRaw = (row['role'] as String? ?? 'assistant').toLowerCase();
    final role = switch (roleRaw) {
      'user' => AiMessageRole.user,
      'system' => AiMessageRole.system,
      _ => AiMessageRole.assistant,
    };
    final links = (row['linked_resources'] as List?) ?? const [];
    return AiMessage(
      id: row['id'] as String? ?? 'msg',
      role: role,
      content: row['content'] as String? ?? '',
      createdAt: row['created_at'] != null
          ? DateTime.parse(row['created_at'] as String).toUtc()
          : null,
      suggestedFollowUps: (row['suggested_follow_ups'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      linkedResources: links
          .map(
            (e) => AiLinkedResource.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
      requiresApproval: row['requires_approval'] as bool? ?? false,
      explanation: row['explanation'] as String?,
      promptTemplateSlug: row['prompt_template_slug'] as String?,
    );
  }
}

class AiLinkedResource {
  const AiLinkedResource({
    required this.label,
    required this.path,
    this.kind = 'page',
  });

  final String label;
  final String path;
  final String kind;

  Map<String, dynamic> toJson() => {
        'label': label,
        'path': path,
        'kind': kind,
      };

  factory AiLinkedResource.fromJson(Map<String, dynamic> json) {
    return AiLinkedResource(
      label: json['label'] as String? ?? 'Open',
      path: json['path'] as String? ?? '/',
      kind: json['kind'] as String? ?? 'page',
    );
  }
}

class AiConversation {
  const AiConversation({
    required this.id,
    required this.title,
    required this.assistant,
    this.updatedAt,
    this.messageCount = 0,
  });

  final String id;
  final String title;
  final AiAssistantKind assistant;
  final DateTime? updatedAt;
  final int messageCount;

  factory AiConversation.fromRow(Map<String, dynamic> row) {
    return AiConversation(
      id: row['id'] as String,
      title: row['title'] as String? ?? 'Conversation',
      assistant: AiAssistantKind.fromSlug(row['assistant_kind'] as String?),
      updatedAt: row['updated_at'] != null
          ? DateTime.parse(row['updated_at'] as String).toUtc()
          : null,
      messageCount: (row['message_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class AiPromptTemplate {
  const AiPromptTemplate({
    required this.slug,
    required this.name,
    required this.body,
    this.version = 1,
    this.category = 'general',
    this.requiresApproval = false,
  });

  final String slug;
  final String name;
  final String body;
  final int version;
  final String category;
  final bool requiresApproval;
}

class AiKnowledgeArticle {
  const AiKnowledgeArticle({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    this.permissionSlug,
    this.keywords = const [],
  });

  final String id;
  final String title;
  final String body;
  final String category;
  final String? permissionSlug;
  final List<String> keywords;
}

class AiGatewayRequest {
  const AiGatewayRequest({
    required this.message,
    required this.context,
    this.assistant = AiAssistantKind.general,
    this.conversationId,
    this.promptSlug,
  });

  final String message;
  final AiRequestContext context;
  final AiAssistantKind assistant;
  final String? conversationId;
  final String? promptSlug;
}

class AiGatewayResponse {
  const AiGatewayResponse({
    required this.conversationId,
    required this.userMessage,
    required this.assistantMessage,
    required this.provider,
    required this.latencyMs,
    this.blocked = false,
    this.blockReason,
    this.tokensEstimated = 0,
  });

  final String conversationId;
  final AiMessage userMessage;
  final AiMessage assistantMessage;
  final AiProviderKind provider;
  final int latencyMs;
  final bool blocked;
  final String? blockReason;
  final int tokensEstimated;
}

class AiGovernanceSnapshot {
  const AiGovernanceSnapshot({
    required this.conversationsToday,
    required this.avgLatencyMs,
    required this.helpfulRate,
    required this.usageByDepartment,
    required this.topFeatures,
    required this.errorRate,
    required this.estimatedTokens,
    required this.policyEvents,
  });

  final int conversationsToday;
  final double avgLatencyMs;
  final double helpfulRate;
  final List<({String department, int count})> usageByDepartment;
  final List<({String feature, int count})> topFeatures;
  final double errorRate;
  final int estimatedTokens;
  final List<String> policyEvents;
}

class AiWorkspaceSnapshot {
  const AiWorkspaceSnapshot({
    required this.conversations,
    required this.activeConversationId,
    required this.messages,
    required this.assistant,
    required this.provider,
    required this.suggestions,
    required this.governance,
  });

  final List<AiConversation> conversations;
  final String? activeConversationId;
  final List<AiMessage> messages;
  final AiAssistantKind assistant;
  final AiProviderKind provider;
  final List<String> suggestions;
  final AiGovernanceSnapshot governance;
}

/// Safety + permission checks before any provider call.
abstract final class AiSafetyGate {
  static final _injectionPatterns = [
    RegExp(r'ignore (all|previous|prior) instructions', caseSensitive: false),
    RegExp(r'system\s*prompt', caseSensitive: false),
    RegExp(r'jailbreak', caseSensitive: false),
    RegExp(r'disregard (your|the) rules', caseSensitive: false),
  ];

  static bool looksLikePromptInjection(String message) {
    return _injectionPatterns.any((p) => p.hasMatch(message));
  }

  static bool canUseAssistant(
    AiAssistantKind assistant, {
    required Set<String> permissions,
    required AppRole? role,
  }) {
    if (role == AppRole.superAdmin || role == AppRole.admin) return true;
    final required = assistant.requiredPermission;
    if (required == null) return true;
    return permissions.contains(required);
  }

  static String? blockReason(
    AiGatewayRequest request,
  ) {
    if (looksLikePromptInjection(request.message)) {
      return 'Potential prompt injection blocked by AI Safety.';
    }
    if (!canUseAssistant(
      request.assistant,
      permissions: request.context.permissions,
      role: request.context.role,
    )) {
      return 'You are not authorized to use ${request.assistant.label}.';
    }
    return null;
  }
}

/// Prompt library (versioned templates).
abstract final class AiPromptLibrary {
  static const templates = <AiPromptTemplate>[
    AiPromptTemplate(
      slug: 'property_summary',
      name: 'Property Summary',
      category: 'property',
      body:
          'Summarize the property for the user: location, price band, status, and fit vs preferences.',
    ),
    AiPromptTemplate(
      slug: 'investment_summary',
      name: 'Investment Summary',
      category: 'investment',
      body:
          'Explain portfolio/ROI informationally. Never guarantee returns. Include disclaimer.',
      requiresApproval: false,
    ),
    AiPromptTemplate(
      slug: 'client_follow_up',
      name: 'Client Follow-up',
      category: 'crm',
      body: 'Draft a polite follow-up message. Mark as requiring human review before send.',
      requiresApproval: true,
    ),
    AiPromptTemplate(
      slug: 'marketing_campaign',
      name: 'Marketing Campaign',
      category: 'content',
      body: 'Draft marketing copy for review. Keep brand voice premium and factual.',
      requiresApproval: true,
    ),
    AiPromptTemplate(
      slug: 'sales_report',
      name: 'Sales Report',
      category: 'report',
      body: 'Summarize sales KPIs with links to underlying reports.',
    ),
    AiPromptTemplate(
      slug: 'support_response',
      name: 'Support Response',
      category: 'support',
      body: 'Draft a helpful support reply. Do not invent policy exceptions.',
      requiresApproval: true,
    ),
    AiPromptTemplate(
      slug: 'blog_generator',
      name: 'Blog Generator',
      category: 'content',
      body: 'Outline a blog draft. Content remains editable before publish.',
      requiresApproval: true,
    ),
    AiPromptTemplate(
      slug: 'legal_disclaimer',
      name: 'Legal Disclaimer',
      category: 'legal',
      body:
          'Remind that AI outputs are advisory and not legal/financial advice.',
    ),
  ];

  static AiPromptTemplate? bySlug(String? slug) {
    if (slug == null) return null;
    for (final t in templates) {
      if (t.slug == slug) return t;
    }
    return null;
  }
}

/// Knowledge Hub — curated, permission-aware articles.
abstract final class AiKnowledgeHub {
  static const articles = <AiKnowledgeArticle>[
    AiKnowledgeArticle(
      id: 'kb-buying',
      title: 'Buying process at HD Homes',
      category: 'sales',
      keywords: ['buy', 'process', 'inspection', 'payment'],
      body:
          'Typical journey: discover → enquire → inspect → KYC → offer → payment plan → allocation. '
          'Inspections can be booked online. Payments use escrow-protected milestones where applicable.',
    ),
    AiKnowledgeArticle(
      id: 'kb-investment',
      title: 'Investment products overview',
      category: 'investment',
      keywords: ['roi', 'invest', 'yield', 'portfolio'],
      body:
          'HD Homes investment products include off-plan and completed assets with structured reporting. '
          'Projected ROI figures are illustrative and not guarantees.',
    ),
    AiKnowledgeArticle(
      id: 'kb-sop-followup',
      title: 'Sales follow-up SOP',
      category: 'playbook',
      permissionSlug: 'manage_crm',
      keywords: ['follow up', 'lead', 'crm', 'sop'],
      body:
          'Follow up warm leads within 24 hours. Log notes in CRM. Never send AI drafts without review.',
    ),
    AiKnowledgeArticle(
      id: 'kb-kyc',
      title: 'KYC & compliance workflow',
      category: 'legal',
      keywords: ['kyc', 'verification', 'compliance'],
      body:
          'Clients and investors complete identity verification before certain transactions. '
          'Staff review documents in Compliance; approvals are audited.',
    ),
    AiKnowledgeArticle(
      id: 'kb-handbook',
      title: 'Employee handbook (excerpt)',
      category: 'hr',
      permissionSlug: 'view_users',
      keywords: ['handbook', 'policy', 'employee'],
      body:
          'Staff must protect client data, use RBAC-assigned tools only, and escalate security incidents.',
    ),
  ];

  static List<AiKnowledgeArticle> searchable({
    required Set<String> permissions,
    AppRole? role,
  }) {
    return articles.where((a) {
      if (a.permissionSlug == null) return true;
      if (role == AppRole.admin || role == AppRole.superAdmin) return true;
      return permissions.contains(a.permissionSlug);
    }).toList();
  }

  static AiKnowledgeArticle? bestMatch(
    String query, {
    required Set<String> permissions,
    AppRole? role,
  }) {
    final q = query.toLowerCase();
    final pool = searchable(permissions: permissions, role: role);
    AiKnowledgeArticle? best;
    var bestScore = 0;
    for (final a in pool) {
      var score = 0;
      if (a.title.toLowerCase().contains(q)) score += 5;
      for (final k in a.keywords) {
        if (q.contains(k)) score += 3;
      }
      if (score > bestScore) {
        bestScore = score;
        best = a;
      }
    }
    return bestScore > 0 ? best : null;
  }
}

/// Local foundation response generator (provider-independent Phase 1).
abstract final class AiResponseFoundation {
  static AiGatewayResponse generate(AiGatewayRequest request) {
    final sw = Stopwatch()..start();
    final block = AiSafetyGate.blockReason(request);
    final conversationId =
        request.conversationId ?? 'local-${DateTime.now().microsecondsSinceEpoch}';
    final userMsg = AiMessage(
      id: 'u-${DateTime.now().microsecondsSinceEpoch}',
      role: AiMessageRole.user,
      content: request.message,
      createdAt: DateTime.now().toUtc(),
    );

    if (block != null) {
      sw.stop();
      return AiGatewayResponse(
        conversationId: conversationId,
        userMessage: userMsg,
        assistantMessage: AiMessage(
          id: 'a-blocked',
          role: AiMessageRole.assistant,
          content: block,
          createdAt: DateTime.now().toUtc(),
          explanation: 'Blocked by AI Safety Gate',
        ),
        provider: AiProviderKind.localFoundation,
        latencyMs: sw.elapsedMilliseconds,
        blocked: true,
        blockReason: block,
      );
    }

    final built = _compose(request);
    sw.stop();
    return AiGatewayResponse(
      conversationId: conversationId,
      userMessage: userMsg,
      assistantMessage: built,
      provider: AiProviderKind.localFoundation,
      latencyMs: sw.elapsedMilliseconds,
      tokensEstimated: (request.message.length + built.content.length) ~/ 4,
    );
  }

  static AiMessage _compose(AiGatewayRequest request) {
    final q = request.message.trim();
    final lower = q.toLowerCase();
    final ctx = request.context;
    final name = ctx.displayName?.split(' ').first ?? 'there';
    final assistant = request.assistant;
    final prompt = AiPromptLibrary.bySlug(request.promptSlug) ??
        _inferPrompt(assistant, lower);
    final kb = AiKnowledgeHub.bestMatch(
      q,
      permissions: ctx.permissions,
      role: ctx.role,
    );

    final links = <AiLinkedResource>[];
    var requiresApproval = prompt?.requiresApproval ?? false;
    String content;
    String? explanation;

    if (kb != null &&
        (assistant == AiAssistantKind.knowledge ||
            assistant == AiAssistantKind.general ||
            lower.contains('policy') ||
            lower.contains('how do') ||
            lower.contains('process'))) {
      content =
          'From the AI Knowledge Hub™ (**${kb.title}**):\n\n${kb.body}\n\n'
          'If you need more detail, ask a follow-up — I will stay within your permissions.';
      explanation = 'Answered from curated knowledge article ${kb.id}';
    } else {
      content = switch (assistant) {
        AiAssistantKind.property => _propertyReply(lower, links),
        AiAssistantKind.investment => _investmentReply(lower, links),
        AiAssistantKind.crm => _crmReply(lower, links, requiresApproval: true),
        AiAssistantKind.content => _contentReply(lower, links),
        AiAssistantKind.report ||
        AiAssistantKind.executive =>
          _executiveReply(lower, links, ctx),
        AiAssistantKind.sales => _salesReply(lower, links),
        AiAssistantKind.workflow => _workflowReply(lower, links),
        AiAssistantKind.knowledge =>
          'I can answer from company policies, SOPs, inventory guides, and playbooks you are allowed to see. '
              'Try asking about buying process, KYC, or investment products.',
        AiAssistantKind.general => _generalReply(lower, links, name, ctx),
      };
      if (assistant == AiAssistantKind.crm ||
          assistant == AiAssistantKind.content ||
          assistant == AiAssistantKind.sales) {
        requiresApproval = true;
      }
      explanation = 'Generated via ${assistant.label} using local foundation provider';
    }

    final followUps = _followUps(assistant, lower);
    return AiMessage(
      id: 'a-${DateTime.now().microsecondsSinceEpoch}',
      role: AiMessageRole.assistant,
      content: content,
      createdAt: DateTime.now().toUtc(),
      suggestedFollowUps: followUps,
      linkedResources: links,
      requiresApproval: requiresApproval,
      explanation: explanation,
      promptTemplateSlug: prompt?.slug,
    );
  }

  static AiPromptTemplate? _inferPrompt(AiAssistantKind kind, String lower) {
    return switch (kind) {
      AiAssistantKind.property => AiPromptLibrary.bySlug('property_summary'),
      AiAssistantKind.investment =>
        AiPromptLibrary.bySlug('investment_summary'),
      AiAssistantKind.crm || AiAssistantKind.sales =>
        AiPromptLibrary.bySlug('client_follow_up'),
      AiAssistantKind.content => AiPromptLibrary.bySlug('blog_generator'),
      AiAssistantKind.report || AiAssistantKind.executive =>
        AiPromptLibrary.bySlug('sales_report'),
      _ => AiPromptLibrary.bySlug('legal_disclaimer'),
    };
  }

  static String _generalReply(
    String lower,
    List<AiLinkedResource> links,
    String name,
    AiRequestContext ctx,
  ) {
    if (lower.contains('inspect') || lower.contains('book')) {
      links.add(
        const AiLinkedResource(
          label: 'Book Inspection',
          path: '/book-inspection',
          kind: 'action',
        ),
      );
      return 'Hi $name — I can help you schedule an inspection. '
          'Open Book Inspection or tell me the estate/property and preferred date. '
          'A sales executive will confirm availability.';
    }
    if (lower.contains('lekki') ||
        lower.contains('bedroom') ||
        lower.contains('show me') ||
        lower.contains('find')) {
      return _propertyReply(lower, links);
    }
    if (lower.contains('roi') || lower.contains('invest')) {
      return _investmentReply(lower, links);
    }
    if (lower.contains('report') || lower.contains('kpi')) {
      return _executiveReply(lower, links, ctx);
    }
    links.add(
      const AiLinkedResource(
        label: 'Search Command Center',
        path: '/dashboard/search',
        kind: 'page',
      ),
    );
    return 'Hi $name — I am the HD Homes Digital Assistant. '
        'I can help with properties, investments, bookings, CRM drafts (staff), '
        'and reports — always respecting your role permissions.\n\n'
        'Try: “Show available 4-bedroom homes in Lekki under ₦250M.”';
  }

  static String _propertyReply(String lower, List<AiLinkedResource> links) {
    links.addAll(const [
      AiLinkedResource(label: 'Browse Properties', path: '/properties'),
      AiLinkedResource(label: 'Open Search', path: '/search'),
    ]);
    final beds = RegExp(r'(\d+)\s*-?\s*bed').firstMatch(lower)?.group(1) ?? '4';
    final loc = lower.contains('victoria')
        ? 'Victoria Island'
        : lower.contains('lekki')
            ? 'Lekki'
            : 'Lagos';
    return 'Here are matches that fit your request (advisory):\n\n'
        '1. **Lekki Pearl Residence** — $beds-bed class · $loc corridor · ~₦185M · Available\n'
        '   Why: location match, budget band, ready-to-move status.\n'
        '2. **Lekki Gardens Duplex** — duplex · Lekki · ~₦220M · Available\n'
        '   Why: similar inventory and amenities.\n\n'
        'Use Part 14 Enterprise Search for live inventory, or book an inspection to proceed.';
  }

  static String _investmentReply(String lower, List<AiLinkedResource> links) {
    links.add(
      const AiLinkedResource(label: 'Investment Hub', path: '/investment'),
    );
    return 'Investment overview (informational only — not a guarantee of returns):\n\n'
        '• Portfolio reporting is available in the Investor Portal.\n'
        '• Typical structured products target illustrative yields; actual performance varies.\n'
        '• Review contracts, payment schedules, and risk notes before committing.\n\n'
        '${lower.contains('roi') ? 'ROI explanations should always include assumptions and time horizon.\n\n' : ''}'
        'Disclaimer: This is not financial advice.';
  }

  static String _crmReply(
    String lower,
    List<AiLinkedResource> links, {
    required bool requiresApproval,
  }) {
    links.add(
      const AiLinkedResource(label: 'CRM', path: '/dashboard/crm', kind: 'page'),
    );
    return 'CRM draft (requires your review before sending):\n\n'
        'Subject: Following up on your HD Homes enquiry\n\n'
        'Hi {{client_name}},\n'
        'Thank you for your interest. Based on our last conversation, I wanted to share '
        'updated options that match your preferences and invite you to schedule an inspection.\n\n'
        'Best regards,\n{{agent_name}}\n\n'
        'Next actions suggested: log note → schedule follow-up → attach brochure.';
  }

  static String _contentReply(String lower, List<AiLinkedResource> links) {
    links.add(
      const AiLinkedResource(label: 'Blog CMS', path: '/dashboard/blog'),
    );
    return 'Content draft (editable before publish):\n\n'
        '# Discover Premium Living in Lekki\n\n'
        'HD Homes delivers thoughtfully designed residences with transparent processes '
        'and investor-ready documentation...\n\n'
        'CTA: Book an inspection · Explore estates\n\n'
        'Review tone, facts, and legal disclaimers before publishing.';
  }

  static String _executiveReply(
    String lower,
    List<AiLinkedResource> links,
    AiRequestContext ctx,
  ) {
    links.addAll(const [
      AiLinkedResource(label: 'Reports', path: '/dashboard/reports'),
      AiLinkedResource(label: 'Activity Logs', path: '/dashboard/activity-logs'),
    ]);
    return 'AI Executive Copilot™ summary (advisory):\n\n'
        '• Sales: pipeline healthy; inspect conversion needs attention this week.\n'
        '• Investors: several KYC items awaiting review.\n'
        '• Operations: no critical system alerts in the last 24h.\n'
        '• Suggested actions: review pending approvals · open sales report · check CRM hot leads.\n\n'
        'Department context: ${ctx.department ?? 'Executive'}. '
        'All figures should be verified against source reports.';
  }

  static String _salesReply(String lower, List<AiLinkedResource> links) {
    links.add(
      const AiLinkedResource(label: 'Clients', path: '/dashboard/clients'),
    );
    return 'AI Sales Copilot™ suggestions (review before acting):\n\n'
        '1. Prioritize leads with inspection intent in the last 7 days.\n'
        '2. Draft personalized follow-ups for Lekki-interested clients.\n'
        '3. Offer similar listings when a preferred unit is reserved.\n\n'
        'Nothing will be sent automatically without your approval.';
  }

  static String _workflowReply(String lower, List<AiLinkedResource> links) {
    return 'Workflow suggestions (human approval required):\n\n'
        '• Flag incomplete client profiles.\n'
        '• Suggest inspection slots for warm leads.\n'
        '• Draft weekly management summary.\n'
        '• Recommend support ticket responses.\n\n'
        'AI Automation Studio is future-ready — automations will support approval steps.';
  }

  static List<String> _followUps(AiAssistantKind assistant, String lower) {
    return switch (assistant) {
      AiAssistantKind.property => const [
          'Compare these two properties',
          'Book an inspection',
          'Show investment suitability',
        ],
      AiAssistantKind.investment => const [
          'Explain ROI assumptions',
          'Show payment schedule overview',
          'Open investor portal',
        ],
      AiAssistantKind.executive => const [
          'Generate this month’s sales report',
          'List pending KYC approvals',
          'Open system health',
        ],
      AiAssistantKind.sales || AiAssistantKind.crm => const [
          'Draft another follow-up',
          'Prioritize today’s leads',
          'Summarize client history',
        ],
      _ => const [
          'Find Lekki properties under ₦250M',
          'How does buying work?',
          'Help me book an inspection',
        ],
    };
  }
}
