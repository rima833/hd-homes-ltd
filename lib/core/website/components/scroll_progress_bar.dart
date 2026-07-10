import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';

/// Scroll progress indicator below the app bar.
class ScrollProgressBar extends StatelessWidget {
  const ScrollProgressBar({
    super.key,
    required this.progress,
  });

  final double progress;

  @override
  Widget build(BuildContext context) {
    if (progress <= 0) return const SizedBox.shrink();

    return LinearProgressIndicator(
      value: progress.clamp(0, 1),
      minHeight: 2,
      backgroundColor: Colors.transparent,
      color: AppColors.gold,
    );
  }
}
