import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/feedback/confirmation_dialog.dart';

/// Standardized global dialogs — no custom one-off dialogs.
abstract final class AppDialogs {
  static Future<bool?> confirm(
    BuildContext context, {
    required String title,
    String? message,
    String confirmLabel = 'Confirm',
    bool destructive = false,
  }) =>
      showConfirmationDialog(
        context: context,
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        isDestructive: destructive,
      );

  static void success(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(AppIcons.success, color: AppColors.white),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.success,
      ),
    );
  }

  static void error(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(AppIcons.error, color: AppColors.white),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.error,
      ),
    );
  }

  static Future<void> loading(BuildContext context, {String? message}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(color: AppColors.gold),
            const SizedBox(width: AppSpacing.base),
            Expanded(child: Text(message ?? 'Please wait...')),
          ],
        ),
      ),
    );
  }
}
