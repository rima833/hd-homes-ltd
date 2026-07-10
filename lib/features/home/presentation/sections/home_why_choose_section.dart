import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/features/home/data/models/home_cms_content.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Section 8 — Why choose HD Homes.
class HomeWhyChooseSection extends StatelessWidget {
  const HomeWhyChooseSection({super.key, required this.items});

  final List<HomeWhyChooseItem> items;

  @override
  Widget build(BuildContext context) {
    final columns = context.isMobile ? 1 : context.isTablet ? 2 : 3;

    return SectionWrapper(
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          const AnimatedSectionTitle(
            overline: 'WHY HD HOMES',
            title: 'Why choose HD Homes',
            subtitle:
                'A developer built on trust, quality, and long-term value creation.',
          ),
          const SizedBox(height: AppSpacing.xxl),
          LayoutBuilder(
            builder: (context, constraints) {
              final width =
                  (constraints.maxWidth - (columns - 1) * AppSpacing.base) /
                      columns;
              return Wrap(
                spacing: AppSpacing.base,
                runSpacing: AppSpacing.base,
                children: items
                    .map(
                      (item) => SizedBox(
                        width: width,
                        child: _WhyCard(item: item),
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

class _WhyCard extends StatefulWidget {
  const _WhyCard({required this.item});

  final HomeWhyChooseItem item;

  @override
  State<_WhyCard> createState() => _WhyCardState();
}

class _WhyCardState extends State<_WhyCard> {
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
          boxShadow: _hovered ? AppShadows.lg : AppShadows.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_iconFor(widget.item.iconName), color: AppColors.gold),
            const SizedBox(height: AppSpacing.base),
            Text(widget.item.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              widget.item.description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondaryLight,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String name) => switch (name) {
        'shield' => LucideIcons.shieldCheck,
        'hard_hat' => LucideIcons.hardHat,
        'wallet' => LucideIcons.wallet,
        'map_pin' => LucideIcons.mapPin,
        'trending_up' => LucideIcons.trendingUp,
        'headphones' => LucideIcons.headphones,
        _ => LucideIcons.star,
      };
}
