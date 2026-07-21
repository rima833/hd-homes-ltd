import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';

/// Max-width page container with responsive horizontal padding.
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
                  vertical: AppSpacing.xl,
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
