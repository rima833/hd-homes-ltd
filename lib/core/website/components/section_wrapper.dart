import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/page_container.dart';

/// Full-width section with optional background and scroll-reveal animation.
class SectionWrapper extends StatelessWidget {
  const SectionWrapper({
    super.key,
    required this.child,
    this.backgroundColor,
    this.padding,
    this.animate = true,
  });

  final Widget child;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    Widget content = PageContainer(
      padding: padding,
      child: child,
    );

    // Entrance animations are costly on Flutter web when many sections mount.
    if (animate && !kIsWeb) {
      content = content
          .animate()
          .fadeIn(duration: AppDurations.normal, curve: Curves.easeOut)
          .slideY(begin: 0.04, end: 0, duration: AppDurations.normal);
    }

    return Container(
      width: double.infinity,
      color: backgroundColor,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.section),
      child: content,
    );
  }
}
