import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';

/// Max-width content column with responsive horizontal padding.
///
/// Vertical spacing belongs on [SectionWrapper] (or the caller) — this
/// container defaults to **horizontal padding only** so stacked sections
/// don't accumulate double gaps.
class PageContainer extends StatelessWidget {
  const PageContainer({
    super.key,
    required this.child,
    this.maxWidth = 1280,
    this.padding,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final horizontal = context.pagePadding;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final pad = padding ??
                EdgeInsets.symmetric(
                  horizontal: constraints.maxWidth < horizontal * 2
                      ? AppSpacing.base
                      : horizontal,
                );
            return Padding(
              padding: pad,
              child: child,
            );
          },
        ),
      ),
    );
  }
}
