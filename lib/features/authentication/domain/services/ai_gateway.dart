import 'dart:async';

import 'package:hdhomesproject/features/authentication/domain/entities/ai_models.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/app_role.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/observability_models.dart';
import 'package:hdhomesproject/features/authentication/domain/services/audit_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider-independent AI provider contract.
abstract class AiModelProvider {
  AiProviderKind get kind;

  Future<AiGatewayResponse> complete(AiGatewayRequest request);
}

/// Phase 1 local foundation — deterministic, offline-capable responses.
class LocalFoundationProvider implements AiModelProvider {
  @override
  AiProviderKind get kind => AiProviderKind.localFoundation;

  @override
  Future<AiGatewayResponse> complete(AiGatewayRequest request) async {
    // Simulate light streaming latency without calling external APIs.
    await Future<void>.delayed(const Duration(milliseconds: 40));
    return AiResponseFoundation.generate(request);
  }
}

/// Central AI Gateway — sole entry for feature modules.
class AiGateway {
  AiGateway({
    required AuditService audit,
    AiModelProvider? provider,
    SupabaseClient? client,
  })  : _audit = audit,
        _provider = provider ?? LocalFoundationProvider(),
        _client = client;

  final AuditService _audit;
  final AiModelProvider _provider;
  final SupabaseClient? _client;

  final Map<String, List<AiMessage>> _localMessages = {};
  final Map<String, AiConversation> _localConversations = {};
  final List<({String conversationId, AiFeedbackVote vote})> _feedback = [];

  bool get isConfigured => _client != null;

  AiProviderKind get activeProvider => _provider.kind;

  Future<AiWorkspaceSnapshot> loadWorkspace({
    required String userId,
    AiAssistantKind assistant = AiAssistantKind.general,
    String? activeConversationId,
  }) async {
    final conversations = await listConversations(userId);
    final activeId = activeConversationId ??
        (conversations.isNotEmpty ? conversations.first.id : null);
    final messages =
        activeId == null ? const <AiMessage>[] : await listMessages(activeId);
    return AiWorkspaceSnapshot(
      conversations: conversations,
      activeConversationId: activeId,
      messages: messages,
      assistant: assistant,
      provider: _provider.kind,
      suggestions: _starterSuggestions(assistant),
      governance: governanceDemo(),
    );
  }

  Future<AiGatewayResponse> chat(AiGatewayRequest request) async {
    final response = await _provider.complete(request);
    final conversationId = response.conversationId;

    _localConversations.putIfAbsent(
      conversationId,
      () => AiConversation(
        id: conversationId,
        title: _titleFrom(request.message),
        assistant: request.assistant,
        updatedAt: DateTime.now().toUtc(),
        messageCount: 0,
      ),
    );
    final existing = _localMessages[conversationId] ?? [];
    _localMessages[conversationId] = [
      ...existing,
      response.userMessage,
      response.assistantMessage,
    ];
    final conv = _localConversations[conversationId]!;
    _localConversations[conversationId] = AiConversation(
      id: conv.id,
      title: conv.title,
      assistant: request.assistant,
      updatedAt: DateTime.now().toUtc(),
      messageCount: (_localMessages[conversationId]?.length ?? 0),
    );

    await _persistTurn(request, response);
    await _audit.publish(
      AuditPublishRequest(
        action: response.blocked ? 'ai_request_blocked' : 'ai_chat_completed',
        module: 'ai_workspace',
        category: AuditEventCategory.ai,
        userId: request.context.userId,
        actorRole: request.context.role?.slug,
        severity: response.blocked ? AuditSeverity.notice : AuditSeverity.info,
        metadata: {
          'assistant': request.assistant.slug,
          'provider': response.provider.name,
          'latency_ms': response.latencyMs,
          'tokens_estimated': response.tokensEstimated,
          'blocked': response.blocked,
          if (response.blockReason != null) 'block_reason': response.blockReason,
        },
        visibleToUser: false,
      ),
    );
    return response;
  }

  Future<List<AiConversation>> listConversations(String userId) async {
    final client = _client;
    if (client != null) {
      try {
        final rows = await client
            .from('ai_conversations')
            .select()
            .eq('user_id', userId)
            .order('updated_at', ascending: false)
            .limit(40);
        final list = (rows as List)
            .map((e) => AiConversation.fromRow(Map<String, dynamic>.from(e as Map)))
            .toList();
        if (list.isNotEmpty) return list;
      } catch (_) {}
    }
    final local = _localConversations.values.toList()
      ..sort((a, b) => (b.updatedAt ?? DateTime(0))
          .compareTo(a.updatedAt ?? DateTime(0)));
    if (local.isNotEmpty) return local;
    return [
      AiConversation(
        id: 'welcome',
        title: 'Welcome to AI Workspace',
        assistant: AiAssistantKind.general,
        updatedAt: DateTime.now().toUtc(),
        messageCount: 1,
      ),
    ];
  }

  Future<List<AiMessage>> listMessages(String conversationId) async {
    final client = _client;
    if (client != null && conversationId != 'welcome') {
      try {
        final rows = await client
            .from('ai_messages')
            .select()
            .eq('conversation_id', conversationId)
            .order('created_at');
        final list = (rows as List)
            .map((e) => AiMessage.fromRow(Map<String, dynamic>.from(e as Map)))
            .toList();
        if (list.isNotEmpty) return list;
      } catch (_) {}
    }
    if (_localMessages.containsKey(conversationId)) {
      return List.unmodifiable(_localMessages[conversationId]!);
    }
    if (conversationId == 'welcome') {
      return [
        AiMessage(
          id: 'welcome-1',
          role: AiMessageRole.assistant,
          content:
              'Welcome to the HD Homes AI Workspace. I assist — I do not replace people. '
              'Ask about properties, investments, CRM drafts, reports, or company knowledge. '
              'High-impact actions always need your approval.',
          createdAt: DateTime.now().toUtc(),
          suggestedFollowUps: const [
            'Show available 4-bedroom homes in Lekki under ₦250M',
            'Summarize today’s executive KPIs',
            'How does the buying process work?',
          ],
          explanation: 'Starter message',
        ),
      ];
    }
    return const [];
  }

  Future<void> submitFeedback({
    required String userId,
    required String conversationId,
    required String messageId,
    required AiFeedbackVote vote,
    String? comment,
  }) async {
    _feedback.add((conversationId: conversationId, vote: vote));
    final client = _client;
    if (client != null) {
      try {
        await client.from('ai_feedback').insert({
          'user_id': userId,
          'conversation_id': conversationId,
          'message_id': messageId,
          'vote': vote == AiFeedbackVote.helpful ? 'helpful' : 'not_helpful',
          'comment': comment,
        });
      } catch (_) {}
    }
    unawaited(
      _audit.publish(
        AuditPublishRequest(
          action: 'ai_feedback_submitted',
          module: 'ai_workspace',
          category: AuditEventCategory.ai,
          userId: userId,
          metadata: {
            'vote': vote.name,
            'conversation_id': conversationId,
          },
          visibleToUser: false,
        ),
      ),
    );
  }

  AiGovernanceSnapshot governanceDemo() {
    final helpful = _feedback.where((f) => f.vote == AiFeedbackVote.helpful).length;
    final total = _feedback.isEmpty ? 1 : _feedback.length;
    return AiGovernanceSnapshot(
      conversationsToday: _localConversations.length.clamp(1, 99),
      avgLatencyMs: 85,
      helpfulRate: helpful / total,
      usageByDepartment: const [
        (department: 'Sales & Marketing', count: 42),
        (department: 'Investor Relations', count: 18),
        (department: 'Executive Management', count: 11),
        (department: 'Customer Support', count: 9),
      ],
      topFeatures: const [
        (feature: 'Property Assistant', count: 36),
        (feature: 'AI Sales Copilot™', count: 22),
        (feature: 'AI Executive Copilot™', count: 14),
        (feature: 'AI Knowledge Hub™', count: 19),
      ],
      errorRate: 0.012,
      estimatedTokens: 128400,
      policyEvents: const [
        'Prompt injection attempt blocked (2)',
        'Unauthorized CRM assistant access denied (1)',
      ],
    );
  }

  List<String> _starterSuggestions(AiAssistantKind assistant) {
    return switch (assistant) {
      AiAssistantKind.executive => const [
          'Summarize today’s business performance',
          'Highlight sales trends',
          'List pending investor KYC',
        ],
      AiAssistantKind.sales => const [
          'Prioritize my leads',
          'Draft a follow-up message',
          'Suggest similar properties',
        ],
      AiAssistantKind.knowledge => const [
          'Explain the buying process',
          'What is our KYC workflow?',
          'Sales follow-up SOP',
        ],
      AiAssistantKind.investment => const [
          'Explain ROI assumptions',
          'Summarize portfolio reporting',
          'Show investment opportunities',
        ],
      _ => const [
          'Show available 4-bedroom homes in Lekki under ₦250M',
          'Help me book an inspection',
          'How does buying work at HD Homes?',
        ],
    };
  }

  String _titleFrom(String message) {
    final t = message.trim();
    if (t.length <= 42) return t.isEmpty ? 'New conversation' : t;
    return '${t.substring(0, 42)}…';
  }

  Future<void> _persistTurn(
    AiGatewayRequest request,
    AiGatewayResponse response,
  ) async {
    final client = _client;
    if (client == null) return;
    try {
      await client.from('ai_conversations').upsert({
        'id': response.conversationId,
        'user_id': request.context.userId,
        'title': _titleFrom(request.message),
        'assistant_kind': request.assistant.slug,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'message_count':
            (_localMessages[response.conversationId]?.length ?? 2),
      });
      await client.from('ai_messages').insert([
        {
          'id': response.userMessage.id,
          'conversation_id': response.conversationId,
          'role': 'user',
          'content': response.userMessage.content,
        },
        {
          'id': response.assistantMessage.id,
          'conversation_id': response.conversationId,
          'role': 'assistant',
          'content': response.assistantMessage.content,
          'suggested_follow_ups': response.assistantMessage.suggestedFollowUps,
          'linked_resources':
              response.assistantMessage.linkedResources.map((e) => e.toJson()).toList(),
          'requires_approval': response.assistantMessage.requiresApproval,
          'explanation': response.assistantMessage.explanation,
          'prompt_template_slug': response.assistantMessage.promptTemplateSlug,
        },
      ]);
      await client.from('ai_usage_logs').insert({
        'user_id': request.context.userId,
        'conversation_id': response.conversationId,
        'assistant_kind': request.assistant.slug,
        'provider': response.provider.name,
        'latency_ms': response.latencyMs,
        'tokens_estimated': response.tokensEstimated,
        'blocked': response.blocked,
      });
    } catch (_) {}
  }
}

/// Builds permission-aware context for the gateway.
abstract final class AiContextEngine {
  static AiRequestContext build({
    required String userId,
    String? displayName,
    AppRole? role,
    Set<String> permissions = const {},
    bool isStaff = false,
    String? department,
    String? currentPage,
    String? currentPropertyId,
    List<String> recentActivity = const [],
    List<String> savedSearchHints = const [],
  }) {
    // Only include activity/search hints already scoped to the user.
    return AiRequestContext(
      userId: userId,
      displayName: displayName,
      role: role,
      permissions: permissions,
      isStaff: isStaff,
      department: department,
      currentPage: currentPage,
      currentPropertyId: currentPropertyId,
      recentActivity: recentActivity.take(5).toList(),
      savedSearchHints: savedSearchHints.take(5).toList(),
    );
  }
}
