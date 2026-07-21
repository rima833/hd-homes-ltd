import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/ai_models.dart';
import 'package:hdhomesproject/features/authentication/domain/services/ai_gateway.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/audit_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/auth_controller.dart';

final aiGatewayProvider = Provider<AiGateway>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return AiGateway(
    audit: ref.watch(auditServiceProvider),
    client: configured ? ref.watch(supabaseClientProvider) : null,
  );
});

final aiWorkspaceSnapshotProvider =
    FutureProvider<AiWorkspaceSnapshot?>((ref) async {
  final session = ref.watch(identitySessionProvider);
  final userId = session.userId;
  if (userId == null) return null;
  final ui = ref.watch(aiWorkspaceControllerProvider);
  return ref.watch(aiGatewayProvider).loadWorkspace(
        userId: userId,
        assistant: ui.assistant,
        activeConversationId: ui.activeConversationId,
      );
});

class AiWorkspaceUiState {
  const AiWorkspaceUiState({
    this.assistant = AiAssistantKind.general,
    this.activeConversationId,
    this.isBusy = false,
    this.isTyping = false,
    this.draft = '',
    this.message,
    this.error,
  });

  final AiAssistantKind assistant;
  final String? activeConversationId;
  final bool isBusy;
  final bool isTyping;
  final String draft;
  final String? message;
  final String? error;

  AiWorkspaceUiState copyWith({
    AiAssistantKind? assistant,
    String? activeConversationId,
    bool? isBusy,
    bool? isTyping,
    String? draft,
    String? message,
    String? error,
    bool clearConversation = false,
    bool clearMessage = false,
    bool clearError = false,
  }) {
    return AiWorkspaceUiState(
      assistant: assistant ?? this.assistant,
      activeConversationId: clearConversation
          ? null
          : (activeConversationId ?? this.activeConversationId),
      isBusy: isBusy ?? this.isBusy,
      isTyping: isTyping ?? this.isTyping,
      draft: draft ?? this.draft,
      message: clearMessage ? null : (message ?? this.message),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final aiWorkspaceControllerProvider =
    NotifierProvider<AiWorkspaceController, AiWorkspaceUiState>(
  AiWorkspaceController.new,
);

class AiWorkspaceController extends Notifier<AiWorkspaceUiState> {
  @override
  AiWorkspaceUiState build() => const AiWorkspaceUiState();

  AiGateway get _gateway => ref.read(aiGatewayProvider);

  void setAssistant(AiAssistantKind assistant) {
    state = state.copyWith(assistant: assistant, clearConversation: true);
    ref.invalidate(aiWorkspaceSnapshotProvider);
  }

  void selectConversation(String id) {
    state = state.copyWith(activeConversationId: id);
    ref.invalidate(aiWorkspaceSnapshotProvider);
  }

  void setDraft(String value) => state = state.copyWith(draft: value);

  Future<void> send([String? override]) async {
    final session = ref.read(identitySessionProvider);
    final userId = session.userId;
    if (userId == null) return;
    final text = (override ?? state.draft).trim();
    if (text.isEmpty) return;

    state = state.copyWith(
      isBusy: true,
      isTyping: true,
      draft: '',
      clearError: true,
    );

    final name = [
      session.profile?.firstName,
      session.profile?.lastName,
    ].whereType<String>().where((e) => e.isNotEmpty).join(' ');

    final context = AiContextEngine.build(
      userId: userId,
      displayName: name.isEmpty ? session.email : name,
      role: session.primaryRole,
      permissions: session.permissions,
      isStaff: session.isStaff,
      currentPage: '/account/ai',
    );

    final response = await _gateway.chat(
      AiGatewayRequest(
        message: text,
        context: context,
        assistant: state.assistant,
        conversationId: state.activeConversationId == 'welcome'
            ? null
            : state.activeConversationId,
      ),
    );

    state = state.copyWith(
      isBusy: false,
      isTyping: false,
      activeConversationId: response.conversationId,
      message: response.blocked ? response.blockReason : 'Response ready.',
    );
    ref.invalidate(aiWorkspaceSnapshotProvider);
  }

  Future<void> feedback(AiFeedbackVote vote, String messageId) async {
    final session = ref.read(identitySessionProvider);
    final userId = session.userId;
    final conversationId = state.activeConversationId;
    if (userId == null || conversationId == null) return;
    await _gateway.submitFeedback(
      userId: userId,
      conversationId: conversationId,
      messageId: messageId,
      vote: vote,
    );
    state = state.copyWith(message: 'Thanks for your feedback.');
  }
}
