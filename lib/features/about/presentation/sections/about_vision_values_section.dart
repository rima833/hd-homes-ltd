import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/features/about/data/models/about_cms_content.dart';
import 'package:hdhomesproject/features/about/presentation/widgets/about_icons.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Sections 4–5 — Vision, mission, and core values.
class AboutVisionValuesSection extends StatelessWidget {
  const AboutVisionValuesSection({
    super.key,
    required this.vision,
    required this.mission,
    required this.values,
  });

  final String vision;
  final String mission;
  final List<AboutValueItem> values;

  @override
  Widget build(BuildContext context) {
    return SectionWrapper(
      child: Column(
        children: [
          context.isMobile
              ? Column(
                  children: [
                    _VisionMissionCard(
                      title: 'Vision',
                      body: vision,
                      icon: LucideIcons.eye,
                    ),
                    const SizedBox(height: AppSpacing.base),
                    _VisionMissionCard(
                      title: 'Mission',
                      body: mission,
                      icon: LucideIcons.target,
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: _VisionMissionCard(
                        title: 'Vision',
                        body: vision,
                        icon: LucideIcons.eye,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.base),
                    Expanded(
                      child: _VisionMissionCard(
                        title: 'Mission',
                        body: mission,
                        icon: LucideIcons.target,
                      ),
                    ),
                  ],
                ),
          const SizedBox(height: AppSpacing.section),
          Text(
            'Core values',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xxl),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = context.isMobile ? 1 : context.isTablet ? 2 : 4;
              final width =
                  (constraints.maxWidth - (columns - 1) * AppSpacing.base) /
                      columns;
              return Wrap(
                spacing: AppSpacing.base,
                runSpacing: AppSpacing.base,
                children: values
                    .map(
                      (v) => SizedBox(
                        width: width,
                        child: _ValueCard(item: v),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _VisionMissionCard extends StatefulWidget {
  const _VisionMissionCard({
    required this.title,
    required this.body,
    required this.icon,
  });

  final String title;
  final String body;
  final IconData icon;

  @override
  State<_VisionMissionCard> createState() => _VisionMissionCardState();
}

class _VisionMissionCardState extends State<_VisionMissionCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppDurations.fast,
        transform: Matrix4.translationValues(0, _hovered ? -4 : 0, 0),
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.charcoal,
              AppColors.gold.withValues(alpha: _hovered ? 0.2 : 0.1),
            ],
          ),
          borderRadius: AppRadius.cardBorder,
          boxShadow: _hovered ? AppShadows.lg : AppShadows.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(widget.icon, color: AppColors.gold, size: 28),
            const SizedBox(height: AppSpacing.base),
            Text(
              widget.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.white,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              widget.body,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ValueCard extends StatefulWidget {
  const _ValueCard({required this.item});

  final AboutValueItem item;

  @override
  State<_ValueCard> createState() => _ValueCardState();
}

class _ValueCardState extends State<_ValueCard> {
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
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: AppRadius.cardBorder,
          border: Border.all(
            color: _hovered ? AppColors.gold : AppColors.neutral200,
          ),
          boxShadow: _hovered ? AppShadows.md : AppShadows.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(AboutIcons.resolve(widget.item.iconName), color: AppColors.gold),
            const SizedBox(height: AppSpacing.base),
            Text(widget.item.title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            Text(widget.item.description, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
