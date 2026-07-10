import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';

/// Floating action button with brand styling.
class FabButton extends StatelessWidget {
  const FabButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.label,
    this.heroTag,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? label;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    if (label != null) {
      return FloatingActionButton.extended(
        heroTag: heroTag,
        onPressed: onPressed,
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.white,
        icon: Icon(icon),
        label: Text(label!),
      );
    }

    return FloatingActionButton(
      heroTag: heroTag,
      onPressed: onPressed,
      backgroundColor: AppColors.gold,
      foregroundColor: AppColors.white,
      child: Icon(icon),
    );
  }
}
