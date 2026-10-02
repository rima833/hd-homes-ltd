import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/media/widgets/delivery_image.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// CMS-managed top announcement bar (active row from `banners`).
class GlobalNotificationBar extends StatelessWidget {
  const GlobalNotificationBar({
    super.key,
    this.message,
    this.imageUrl,
    this.actionLabel,
    this.onAction,
    this.visible = true,
  });

  final String? message;
  final String? imageUrl;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible || message == null || message!.trim().isEmpty) {
      return const SizedBox.shrink();
    }

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
              if (imageUrl != null && imageUrl!.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: MediaDeliveryImage(
                      url: imageUrl!,
                      width: 36,
                      height: 28,
                      fit: BoxFit.cover,
                      errorWidget: const Icon(
                        LucideIcons.megaphone,
                        size: 16,
                        color: AppColors.deepBlack,
                      ),
                    ),
                  ),
                )
              else
                const Icon(
                  LucideIcons.megaphone,
                  size: 16,
                  color: AppColors.deepBlack,
                ),
              if (imageUrl == null || imageUrl!.trim().isEmpty)
                const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  message!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
