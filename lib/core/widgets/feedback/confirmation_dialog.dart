import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';

Future<bool?> showConfirmationDialog({
  required BuildContext context,
  required String title,
  String? message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool isDestructive = false,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: message != null ? Text(message) : null,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        PrimaryButton(
          label: confirmLabel,
          variant: isDestructive ? ButtonVariant.secondary : ButtonVariant.primary,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );
}

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    this.imageUrl,
    this.name,
    this.size = 48,
    this.onTap,
  });

  final String? imageUrl;
  final String? name;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(name);

    return GestureDetector(
      onTap: onTap,
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor: AppColors.gold.withValues(alpha: 0.2),
        foregroundImage: imageUrl != null ? NetworkImage(imageUrl!) : null,
        child: imageUrl == null
            ? Text(
                initials,
                style: TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w600,
                  fontSize: size * 0.35,
                ),
              )
            : null,
      ),
    );
  }

  String _initials(String? value) {
    if (value == null || value.isEmpty) return '?';
    final parts = value.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return value[0].toUpperCase();
  }
}
