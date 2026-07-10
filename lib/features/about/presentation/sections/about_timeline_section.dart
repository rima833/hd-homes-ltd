import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/features/about/data/models/about_cms_content.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Section 6 — Company timeline.
class AboutTimelineSection extends StatelessWidget {
  const AboutTimelineSection({super.key, required this.items});

  final List<AboutTimelineItem> items;

  @override
  Widget build(BuildContext context) {
    return SectionWrapper(
      backgroundColor: AppColors.charcoal,
      child: Column(
        children: [
          const AnimatedSectionTitle(
            overline: 'MILESTONES',
            title: 'Company timeline',
            subtitle: 'Key moments that shaped HD Homes.',
          ),
          const SizedBox(height: AppSpacing.xxl),
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isLeft = index.isEven;
            return _TimelineRow(item: item, alignLeft: isLeft || context.isMobile);
          }),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.item, required this.alignLeft});

  final AboutTimelineItem item;
  final bool alignLeft;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: AppColors.gold,
                  shape: BoxShape.circle,
                ),
              ),
              Container(width: 2, height: 60, color: AppColors.gold.withValues(alpha: 0.4)),
            ],
          ),
          const SizedBox(width: AppSpacing.base),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.darkSurface,
                borderRadius: AppRadius.cardBorder,
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.date,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.gold,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.white,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    item.description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondaryDark,
                        ),
                  ),
                  if (item.videoUrl != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    const Row(
                      children: [
                        Icon(LucideIcons.playCircle, size: 16, color: AppColors.gold),
                        SizedBox(width: AppSpacing.xs),
                        Text('Watch video', style: TextStyle(color: AppColors.gold)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
