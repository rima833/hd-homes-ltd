import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/features/about/data/models/about_cms_content.dart';
import 'package:hdhomesproject/features/about/presentation/widgets/core_values/core_value_bulb.dart';

/// About page Core Values — official HD Homes lightbulb artwork.
class CoreValuesSection extends StatelessWidget {
  const CoreValuesSection({super.key, required this.values});

  final List<AboutValueItem> values;

  @override
  Widget build(BuildContext context) {
    final maxWidth = context.isMobile
        ? double.infinity
        : math.min(
            760.0,
            MediaQuery.sizeOf(context).width - (context.pagePadding * 2),
          );

    // Match brand artwork navy (#050B17) so the PNG blends seamlessly.
    return SectionWrapper(
      backgroundColor: CoreValueBulb.artworkNavy,
      animate: false,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _BlueprintGridPainter()),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, -0.1),
                        radius: 0.95,
                        colors: [
                          const Color(0xFFFFC933).withValues(alpha: 0.06),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: context.isMobile ? 8 : 20,
                  vertical: context.isMobile ? 16 : 28,
                ),
                child: CoreValueBulb(
                  values: values,
                  maxWidth: maxWidth.isFinite ? maxWidth : 720,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlueprintGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final minor = Paint()
      ..color = Colors.white.withValues(alpha: 0.018)
      ..strokeWidth = 1;
    final major = Paint()
      ..color = const Color(0xFFFFD54A).withValues(alpha: 0.028)
      ..strokeWidth = 1;

    const step = 36.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        x % (step * 4) == 0 ? major : minor,
      );
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        y % (step * 4) == 0 ? major : minor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
