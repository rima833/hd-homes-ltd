import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// CMS-managed announcement bar (placeholder until Part 5 CMS wired).
class GlobalNotificationBar extends StatelessWidget {
  const GlobalNotificationBar({
    super.key,
    this.message,
    this.actionLabel,
    this.onAction,
    this.visible = true,
  });

  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible || message == null) return const SizedBox.shrink();

    return Material(
      color: AppColors.gold,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              const Icon(LucideIcons.megaphone, size: 16, color: AppColors.deepBlack),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  message!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.deepBlack,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              if (actionLabel != null && onAction != null)
                TextButton(
                  onPressed: onAction,
                  child: Text(
                    actionLabel!,
                    style: const TextStyle(
                      color: AppColors.deepBlack,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
