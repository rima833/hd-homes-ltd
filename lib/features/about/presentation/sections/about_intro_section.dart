import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/features/about/data/models/about_cms_content.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Section 2 — Company introduction.
class AboutIntroSection extends StatelessWidget {
  const AboutIntroSection({super.key, required this.content});

  final AboutIntroContent content;

  @override
  Widget build(BuildContext context) {
    return SectionWrapper(
      child: context.isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _children(context),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _copy(context)),
                const SizedBox(width: AppSpacing.xxl),
                Expanded(flex: 2, child: _imagePanel(context)),
              ],
            ),
    );
  }

  List<Widget> _children(BuildContext context) => [
        _copy(context),
        const SizedBox(height: AppSpacing.xl),
        _imagePanel(context),
      ];

  Widget _copy(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSectionTitle(
          overline: 'WHO WE ARE',
          title: 'Company overview',
          subtitle: content.description,
          alignment: TextAlign.start,
        ),
        const SizedBox(height: AppSpacing.lg),
        _HighlightChip(
          icon: LucideIcons.calendar,
          label: '${content.yearsOperating}+ years of operation',
        ),
        const SizedBox(height: AppSpacing.base),
        Text('Specializations', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: content.specializations
              .map((s) => Chip(label: Text(s)))
              .toList(),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Geographic presence', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: content.geographicPresence
              .map((g) => Chip(
                    avatar: const Icon(LucideIcons.mapPin, size: 14),
                    label: Text(g),
                  ))
              .toList(),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Philosophy', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        Text(content.philosophy, style: Theme.of(context).textTheme.bodyLarge),
      ],
    );
  }

  Widget _imagePanel(BuildContext context) {
    return Container(
      height: context.isMobile ? 280 : 420,
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardBorder,
        gradient: LinearGradient(
          colors: [
            AppColors.charcoal,
            AppColors.gold.withValues(alpha: 0.25),
          ],
        ),
        boxShadow: AppShadows.lg,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.building2, size: 64, color: AppColors.gold),
          const SizedBox(height: AppSpacing.base),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              children: content.achievements
                  .map(
                    (a) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              color: AppColors.gold, size: 16),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              a,
                              style: const TextStyle(color: AppColors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _HighlightChip extends StatelessWidget {
  const _HighlightChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.12),
        borderRadius: AppRadius.buttonBorder,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.gold),
          const SizedBox(width: AppSpacing.sm),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
