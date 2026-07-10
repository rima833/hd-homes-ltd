import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/home/data/models/home_cms_content.dart';

/// Section 12 — Investment opportunities.
class HomeInvestmentSection extends StatelessWidget {
  const HomeInvestmentSection({super.key, required this.items});

  final List<HomeInvestmentItem> items;

  @override
  Widget build(BuildContext context) {
    return SectionWrapper(
      backgroundColor: AppColors.charcoal,
      child: Column(
        children: [
          const AnimatedSectionTitle(
            overline: 'INVEST WITH HD HOMES',
            title: 'Investment opportunities',
            subtitle: 'Structured products designed for capital growth and income.',
          ),
          const SizedBox(height: AppSpacing.xxl),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.base),
                child: _InvestmentCard(item: item),
              )),
        ],
      ),
    );
  }
}

class _InvestmentCard extends StatelessWidget {
  const _InvestmentCard({required this.item});

  final HomeInvestmentItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
      ),
      child: context.isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _content(context),
            )
          : Row(
              children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _text(context),
                )),
                PrimaryButton(
                  label: 'View Opportunity',
                  onPressed: () => context.go(item.route),
                ),
              ],
            ),
    );
  }

  List<Widget> _content(BuildContext context) => [
        ..._text(context),
        const SizedBox(height: AppSpacing.base),
        PrimaryButton(
          label: 'View Opportunity',
          expand: true,
          onPressed: () => context.go(item.route),
        ),
      ];

  List<Widget> _text(BuildContext context) => [
        Text(
          item.title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.white,
              ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.sm,
          children: [
            _Metric(label: 'Expected ROI', value: item.roi),
            _Metric(label: 'Type', value: item.type),
            _Metric(label: 'Duration', value: item.duration),
            _Metric(label: 'Risk', value: item.risk),
            _Metric(label: 'Growth', value: item.growth),
          ],
        ),
      ];
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondaryDark,
            )),
        Text(value, style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.gold,
            )),
      ],
    );
  }
}
