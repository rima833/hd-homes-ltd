import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/page_container.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/features/estates/data/models/estate_detail_content.dart';
import 'package:hdhomesproject/features/estates/presentation/widgets/interactive_master_plan.dart';
import 'package:hdhomesproject/features/home/presentation/widgets/animated_statistic.dart';

/// Sections 2–4 — Overview, statistics, master plan.
class EstateOverviewSections extends StatelessWidget {
  const EstateOverviewSections({super.key, required this.detail});

  final EstateDetailContent detail;

  @override
  Widget build(BuildContext context) {
    final o = detail.overview;

    return Column(
      children: [
        SectionWrapper(
          child: PageContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AnimatedSectionTitle(
                  overline: 'OVERVIEW',
                  title: 'Estate overview',
                  alignment: TextAlign.start,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(o.description, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: AppSpacing.base),
                ExpansionTile(title: const Text('Vision'), children: [Text(o.vision)]),
                ExpansionTile(title: const Text('Design philosophy'), children: [Text(o.designPhilosophy)]),
                ExpansionTile(title: const Text('Developer'), children: [Text(o.developerInfo)]),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.xl,
                  children: [
                    _meta('Land area', o.totalLandArea),
                    _meta('Phases', '${o.phaseCount}'),
                    _meta('Completion', o.expectedCompletion),
                    _meta('Target market', o.targetMarket),
                  ],
                ),
              ],
            ),
          ),
        ),
        SectionWrapper(
          backgroundColor: AppColors.charcoal,
          child: PageContainer(
            child: Column(
              children: [
                const AnimatedSectionTitle(
                  overline: 'STATISTICS',
                  title: 'Estate at a glance',
                ),
                const SizedBox(height: AppSpacing.xl),
                Wrap(
                  spacing: AppSpacing.xl,
                  runSpacing: AppSpacing.xl,
                  alignment: WrapAlignment.center,
                  children: detail.statistics
                      .map(
                        (s) => SizedBox(
                          width: context.isMobile ? 140 : 160,
                          child: AnimatedStatistic(
                            value: s.value,
                            label: s.label,
                            suffix: s.suffix,
                            textColor: AppColors.textSecondaryDark,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ),
        SectionWrapper(
          child: PageContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AnimatedSectionTitle(
                  overline: 'MASTER PLAN',
                  title: 'Interactive master plan',
                  subtitle: 'Zoom, pan, search plots, and reserve directly from the map.',
                  alignment: TextAlign.start,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(detail.masterPlan.description),
                const SizedBox(height: AppSpacing.xl),
                InteractiveMasterPlan(masterPlan: detail.masterPlan),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _meta(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
