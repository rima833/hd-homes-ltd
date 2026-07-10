import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/home/data/models/home_cms_content.dart';

/// Section 7 — Who we are.
class HomeAboutSection extends StatelessWidget {
  const HomeAboutSection({super.key, required this.content});

  final HomeAboutContent content;

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
                Expanded(child: _copy(context)),
                const SizedBox(width: AppSpacing.xxl),
                Expanded(child: _highlights(context)),
              ],
            ),
    );
  }

  List<Widget> _children(BuildContext context) => [
        _copy(context),
        const SizedBox(height: AppSpacing.xl),
        _highlights(context),
      ];

  Widget _copy(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSectionTitle(
          overline: 'ABOUT HD HOMES',
          title: content.title,
          subtitle: content.story,
          alignment: TextAlign.start,
        ),
        const SizedBox(height: AppSpacing.lg),
        _InfoBlock(label: 'Mission', text: content.mission),
        const SizedBox(height: AppSpacing.base),
        _InfoBlock(label: 'Vision', text: content.vision),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.sm,
          children: content.values
              .map(
                (v) => Chip(
                  label: Text(v),
                  backgroundColor: AppColors.gold.withValues(alpha: 0.12),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: content.ctaLabel,
          onPressed: () => context.go(content.ctaPath),
        ),
      ],
    );
  }

  Widget _highlights(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: AppRadius.cardBorder,
        boxShadow: AppShadows.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Company Highlights', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.base),
          for (final item in content.highlights)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.gold, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.gold,
              ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(text, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}
