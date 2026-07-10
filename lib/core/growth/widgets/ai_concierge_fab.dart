import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/growth/ai/ai_concierge.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Floating AI Concierge™ chat entry point.
class AiConciergeFab extends HookConsumerWidget {
  const AiConciergeFab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = useState(false);
    final controller = useTextEditingController();
    final messages = ref.watch(aiConciergeProvider);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (open.value)
          Positioned(
            right: 0,
            bottom: 64,
            child: Material(
              elevation: 12,
              borderRadius: AppRadius.cardBorder,
              color: Theme.of(context).colorScheme.surface,
              child: SizedBox(
                width: 320,
                height: 400,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.base),
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                        gradient: AppColors.goldGradient,
                      ),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.bot, color: AppColors.deepBlack),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'HD Homes AI Concierge™',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: AppColors.deepBlack,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: AppColors.deepBlack),
                            onPressed: () => open.value = false,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        itemCount: messages.length,
                        itemBuilder: (_, i) {
                          final m = messages[i];
                          final isUser = m.role == 'user';
                          return Align(
                            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              decoration: BoxDecoration(
                                color: isUser
                                    ? AppColors.gold.withValues(alpha: 0.2)
                                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                                borderRadius: AppRadius.cardBorder,
                              ),
                              child: Text(m.content, style: const TextStyle(fontSize: 13)),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: controller,
                              decoration: const InputDecoration(
                                hintText: 'Ask about properties…',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              onSubmitted: (v) {
                                if (v.trim().isEmpty) return;
                                ref.read(aiConciergeProvider.notifier).sendMessage(v.trim());
                                controller.clear();
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(LucideIcons.send, color: AppColors.gold),
                            onPressed: () {
                              final v = controller.text.trim();
                              if (v.isEmpty) return;
                              ref.read(aiConciergeProvider.notifier).sendMessage(v);
                              controller.clear();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        FloatingActionButton(
          onPressed: () => open.value = !open.value,
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.deepBlack,
          child: Icon(open.value ? Icons.close : LucideIcons.messageCircle),
        ),
      ],
    );
  }
}
