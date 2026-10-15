import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/live_chat/presentation/providers/live_chat_providers.dart';
import 'package:hdhomesproject/features/live_chat/presentation/widgets/public_live_chat_panel.dart';

/// Full-width live chat on phones — composer stays above the software keyboard.
class PublicLiveChatMobileOverlay extends ConsumerWidget {
  const PublicLiveChatMobileOverlay({super.key, required this.topInset});

  /// Distance from the top of the screen to the chat panel (below public nav).
  final double topInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () =>
                ref.read(liveChatPanelOpenProvider.notifier).state = false,
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.45),
            ),
          ),
        ),
        Positioned(
          left: AppSpacing.sm,
          right: AppSpacing.sm,
          top: topInset,
          bottom: keyboard + (keyboard > 0 ? AppSpacing.xs : safeBottom),
          child: const PublicLiveChatPanel(sheetLayout: true),
        ),
      ],
    );
  }
}
