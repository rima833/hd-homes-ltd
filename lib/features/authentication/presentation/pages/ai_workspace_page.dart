import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/ai_models.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/ai_workspace_controller.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Enterprise AI Chat Workspace — sidebar + chat + context panel.
class AiWorkspacePage extends HookConsumerWidget {
  const AiWorkspacePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapAsync = ref.watch(aiWorkspaceSnapshotProvider);
    final ui = ref.watch(aiWorkspaceControllerProvider);
    final controller = ref.read(aiWorkspaceControllerProvider.notifier);
    final draft = useTextEditingController(text: ui.draft);
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 1100;
    final showSidebar = width >= 800;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Workspace'),
        actions: [
          IconButton(
            tooltip: 'AI Governance',
            icon: const Icon(LucideIcons.shieldCheck),
            onPressed: () => context.go(RoutePaths.aiGovernance),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: () => ref.invalidate(aiWorkspaceSnapshotProvider),
          ),
        ],
      ),
      body: snapAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Unable to load AI workspace: $e')),
        data: (snap) {
          if (snap == null) {
            return const Center(child: Text('Sign in to use the AI Workspace.'));
          }
          return Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    for (final kind in AiAssistantKind.values)
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: ChoiceChip(
                          label: Text(kind.label),
                          selected: ui.assistant == kind,
                          onSelected: (_) => controller.setAssistant(kind),
                        ),
                      ),
                  ],
                ),
              ),
              if (ui.message != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      ui.message!,
                      style: const TextStyle(color: AppColors.success),
                    ),
                  ),
                ),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showSidebar)
                      SizedBox(
                        width: 260,
                        child: _ConversationSidebar(
                          conversations: snap.conversations,
                          activeId: snap.activeConversationId,
                          onSelect: controller.selectConversation,
                        ),
                      ),
                    Expanded(
                      child: _ChatPanel(
                        messages: snap.messages,
                        isTyping: ui.isTyping,
                        suggestions: snap.suggestions,
                        draft: draft,
                        isBusy: ui.isBusy,
                        onSend: () => controller.send(draft.text),
                        onSuggestion: (s) {
                          draft.text = s;
                          controller.send(s);
                        },
                        onFeedback: controller.feedback,
                      ),
                    ),
                    if (isWide)
                      SizedBox(
                        width: 280,
                        child: _ContextPanel(
                          assistant: snap.assistant,
                          provider: snap.provider,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ConversationSidebar extends StatelessWidget {
  const _ConversationSidebar({
    required this.conversations,
    required this.activeId,
    required this.onSelect,
  });

  final List<AiConversation> conversations;
  final String? activeId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text('Conversations', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          ...conversations.map(
            (c) => ListTile(
              selected: c.id == activeId,
              leading: const Icon(LucideIcons.messageSquare, size: 18),
              title: Text(c.title, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text(c.assistant.label),
              onTap: () => onSelect(c.id),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatPanel extends StatelessWidget {
  const _ChatPanel({
    required this.messages,
    required this.isTyping,
    required this.suggestions,
    required this.draft,
    required this.isBusy,
    required this.onSend,
    required this.onSuggestion,
    required this.onFeedback,
  });

  final List<AiMessage> messages;
  final bool isTyping;
  final List<String> suggestions;
  final TextEditingController draft;
  final bool isBusy;
  final VoidCallback onSend;
  final ValueChanged<String> onSuggestion;
  final void Function(AiFeedbackVote vote, String messageId) onFeedback;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              if (messages.isEmpty)
                Text(
                  'Start a conversation with the Digital Assistant.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ...messages.map((m) => _MessageBubble(message: m, onFeedback: onFeedback)),
              if (isTyping)
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.sm),
                  child: Text('Assistant is typing…'),
                ),
            ],
          ),
        ),
        if (suggestions.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                for (final s in suggestions)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ActionChip(
                      label: Text(s),
                      onPressed: isBusy ? null : () => onSuggestion(s),
                    ),
                  ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: draft,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Ask HD Homes AI…',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => onSend(),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              PrimaryButton(
                label: 'Send',
                icon: LucideIcons.send,
                isLoading: isBusy,
                onPressed: isBusy ? null : onSend,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.onFeedback});

  final AiMessage message;
  final void Function(AiFeedbackVote vote, String messageId) onFeedback;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == AiMessageRole.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.md),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? AppColors.gold.withValues(alpha: 0.18)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message.content),
            if (message.requiresApproval) ...[
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Requires human approval before execution.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
            if (message.explanation != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                message.explanation!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (message.linkedResources.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final r in message.linkedResources)
                    ActionChip(
                      label: Text(r.label),
                      onPressed: () => context.go(r.path),
                    ),
                ],
              ),
            ],
            if (message.suggestedFollowUps.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final f in message.suggestedFollowUps)
                    Chip(label: Text(f, style: const TextStyle(fontSize: 12))),
                ],
              ),
            ],
            if (!isUser) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Helpful',
                    icon: const Icon(LucideIcons.thumbsUp, size: 16),
                    onPressed: () =>
                        onFeedback(AiFeedbackVote.helpful, message.id),
                  ),
                  IconButton(
                    tooltip: 'Not helpful',
                    icon: const Icon(LucideIcons.thumbsDown, size: 16),
                    onPressed: () =>
                        onFeedback(AiFeedbackVote.notHelpful, message.id),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ContextPanel extends StatelessWidget {
  const _ContextPanel({
    required this.assistant,
    required this.provider,
  });

  final AiAssistantKind assistant;
  final AiProviderKind provider;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text('Context', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          ListTile(
            dense: true,
            leading: const Icon(LucideIcons.bot),
            title: Text(assistant.label),
            subtitle: const Text('Active assistant'),
          ),
          ListTile(
            dense: true,
            leading: const Icon(LucideIcons.cpu),
            title: Text(provider.label),
            subtitle: const Text('Provider (swappable)'),
          ),
          const Divider(),
          Text(
            'AI assists — humans approve high-impact actions. '
            'Responses stay within your permissions.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
