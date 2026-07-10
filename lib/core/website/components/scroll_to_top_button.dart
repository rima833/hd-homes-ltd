import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';

/// Back-to-top floating action.
class ScrollToTopButton extends StatelessWidget {
  const ScrollToTopButton({
    super.key,
    required this.visible,
    required this.onPressed,
  });

  final bool visible;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: AppDurations.fast,
      child: IgnorePointer(
        ignoring: !visible,
        child: FloatingActionButton.small(
          heroTag: 'scroll_top',
          backgroundColor: AppColors.charcoal,
          onPressed: onPressed,
          child: const Icon(Icons.arrow_upward_rounded, color: AppColors.white),
        ),
      ),
    );
  }
}
