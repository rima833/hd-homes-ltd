import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/page_container.dart';

/// Full-width section band with optional background and scroll-reveal.
///
/// Owns vertical rhythm for the public site. Child content is already
/// wrapped in [PageContainer] — do **not** nest another PageContainer.
class SectionWrapper extends StatelessWidget {
  const SectionWrapper({
    super.key,
    required this.child,
    this.backgroundColor,
    this.padding,
    this.animate = true,
    this.compact = false,
    this.bandPadding,
  });

  final Widget child;
  final Color? backgroundColor;
  /// Optional override for the inner [PageContainer] padding.
  final EdgeInsetsGeometry? padding;
  final bool animate;
  /// Tighter vertical padding for consecutive related blocks.
  final bool compact;
  /// Override outer band padding. Use [EdgeInsets.zero] when the child
  /// already owns vertical rhythm (avoids double spacing).
  final EdgeInsetsGeometry? bandPadding;

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

    final vertical = compact ? AppSpacing.xxl : AppSpacing.section;

    return Container(
      width: double.infinity,
      color: backgroundColor,
      padding: bandPadding ?? EdgeInsets.symmetric(vertical: vertical),
      child: content,
    );
  }
}
