import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Section 11 — Interactive Nigeria map (GIS-ready placeholder).
class HomeMapSection extends StatelessWidget {
  const HomeMapSection({super.key});

  @override
  Widget build(BuildContext context) {
    return SectionWrapper(
      child: Column(
        children: [
          const AnimatedSectionTitle(
            overline: 'EXPLORE BY LOCATION',
            title: 'Developments across Nigeria',
            subtitle:
                'Discover HD Homes estates and upcoming projects on an interactive map.',
          ),
          const SizedBox(height: AppSpacing.xxl),
          Container(
            height: context.isMobile ? 320 : 420,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: AppRadius.cardBorder,
              gradient: LinearGradient(
                colors: [
                  AppColors.charcoal,
                  AppColors.gold.withValues(alpha: 0.15),
                ],
              ),
              border: Border.all(color: AppColors.neutral200),
            ),
            child: Stack(
              children: [
                CustomPaint(
                  size: Size.infinite,
                  painter: _NigeriaMapPlaceholderPainter(),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.map, size: 48, color: AppColors.gold),
                      const SizedBox(height: AppSpacing.base),
                      Text(
                        'Interactive map — GIS integration ready',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppColors.white,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Lagos · Abuja · Port Harcourt · Enugu',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondaryDark,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NigeriaMapPlaceholderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(size.width * 0.35, size.height * 0.55), 8, paint);
    canvas.drawCircle(Offset(size.width * 0.48, size.height * 0.42), 10, paint);
    canvas.drawCircle(Offset(size.width * 0.62, size.height * 0.68), 7, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
