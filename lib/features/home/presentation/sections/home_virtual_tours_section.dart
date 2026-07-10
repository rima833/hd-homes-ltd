import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Section 17 — Virtual property tours.
class HomeVirtualToursSection extends StatelessWidget {
  const HomeVirtualToursSection({super.key});

  @override
  Widget build(BuildContext context) {
    final tours = const [
      ('360° Walkthrough', LucideIcons.rotate3d),
      ('Estate Video Tour', LucideIcons.video),
      ('Drone Flyover', LucideIcons.plane),
      ('Interactive Floor Plans', LucideIcons.layout),
    ];

    return SectionWrapper(
      backgroundColor: AppColors.charcoal,
      child: Column(
        children: [
          const AnimatedSectionTitle(
            overline: 'IMMERSIVE EXPERIENCES',
            title: 'Virtual property tours',
            subtitle: 'Explore homes before you visit — from anywhere.',
          ),
          const SizedBox(height: AppSpacing.xxl),
          Wrap(
            spacing: AppSpacing.base,
            runSpacing: AppSpacing.base,
            children: tours
                .map(
                  (t) => SizedBox(
                    width: context.isMobile ? double.infinity : 260,
                    child: _TourCard(title: t.$1, icon: t.$2),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _TourCard extends StatefulWidget {
  const _TourCard({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  State<_TourCard> createState() => _TourCardState();
}

class _TourCardState extends State<_TourCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppDurations.fast,
        transform: Matrix4.translationValues(0, _hovered ? -4 : 0, 0),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: AppRadius.cardBorder,
          border: Border.all(
            color: _hovered ? AppColors.gold : AppColors.neutral700,
          ),
        ),
        child: Row(
          children: [
            Icon(widget.icon, color: AppColors.gold),
            const SizedBox(width: AppSpacing.base),
            Expanded(
              child: Text(
                widget.title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.white,
                    ),
              ),
            ),
            const Icon(Icons.play_circle_outline_rounded, color: AppColors.gold),
          ],
        ),
      ),
    );
  }
}
