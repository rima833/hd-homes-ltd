import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/features/investment/data/models/investment_hub_content.dart';
import 'package:hdhomesproject/features/investment/data/providers/investment_cms_provider.dart';
import 'package:hdhomesproject/features/investment/presentation/widgets/investment_icons.dart';
import 'package:hdhomesproject/features/investment/presentation/widgets/investment_opportunity_card.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Hub sections 2–7 — pillars, stats, opportunities, process, market insights.
class InvestmentHubSections extends HookConsumerWidget {
  const InvestmentHubSections({
    super.key,
    this.opportunitiesKey,
    this.processKey,
  });

  final GlobalKey? opportunitiesKey;
  final GlobalKey? processKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cms = ref.watch(investmentHubCmsProvider);
    final typeFilter = useState<InvestmentProductType?>(null);

    final filtered = typeFilter.value == null
        ? cms.opportunities
        : cms.opportunities.where((o) => o.type == typeFilter.value).toList();

    return Column(
      children: [
        SectionWrapper(
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'WHY INVEST',
                title: 'Why invest with HD Homes',
                subtitle: 'Institutional-grade developments with transparent investor protections.',
              ),
              const SizedBox(height: AppSpacing.xl),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cross = context.isMobile ? 2 : 3;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cross,
                      mainAxisSpacing: AppSpacing.base,
                      crossAxisSpacing: AppSpacing.base,
                      childAspectRatio: context.isMobile ? 0.9 : 1.1,
                    ),
                    itemCount: cms.pillars.length,
                    itemBuilder: (_, i) {
                      final pillar = cms.pillars[i];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(InvestmentIcons.resolve(pillar.iconName), color: AppColors.gold),
                              const SizedBox(height: AppSpacing.sm),
                              Text(pillar.title, style: Theme.of(context).textTheme.titleSmall),
                              const SizedBox(height: AppSpacing.xs),
                              Expanded(
                                child: Text(pillar.description, style: Theme.of(context).textTheme.bodySmall),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: AppSpacing.xxl),
              Wrap(
                spacing: AppSpacing.lg,
                runSpacing: AppSpacing.lg,
                alignment: WrapAlignment.center,
                children: cms.statistics
                    .map(
                      (s) => SizedBox(
                        width: context.isMobile ? 140 : 180,
                        child: Column(
                          children: [
                            Text(
                              '${s.value}${s.suffix ?? ''}',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    color: AppColors.gold,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            Text(s.label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        SectionWrapper(
          key: opportunitiesKey,
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AnimatedSectionTitle(
                overline: 'OPPORTUNITIES',
                title: 'Current investment opportunities',
                subtitle: 'Off-plan, rental income, land banking, commercial, and fractional products.',
              ),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  FilterChip(
                    label: const Text('All'),
                    selected: typeFilter.value == null,
                    onSelected: (_) => typeFilter.value = null,
                  ),
                  ...InvestmentProductType.values.map(
                    (t) => FilterChip(
                      label: Text(t.label),
                      selected: typeFilter.value == t,
                      onSelected: (selected) => typeFilter.value = selected ? t : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cross = context.isMobile ? 1 : 2;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cross,
                      mainAxisSpacing: AppSpacing.base,
                      crossAxisSpacing: AppSpacing.base,
                      childAspectRatio: context.isMobile ? 0.85 : 1.15,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => InvestmentOpportunityCard(opportunity: filtered[i]),
                  );
                },
              ),
            ],
          ),
        ),
        SectionWrapper(
          key: processKey,
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'PROCESS',
                title: 'How investing works',
                subtitle: 'A structured journey from discovery to returns.',
              ),
              const SizedBox(height: AppSpacing.xl),
              ...cms.processSteps.map(
                (step) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.gold.withValues(alpha: 0.2),
                        child: Text('${step.step}', style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: AppSpacing.base),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(step.title, style: Theme.of(context).textTheme.titleSmall),
                            Text(step.description, style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        SectionWrapper(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'MARKET',
                title: 'Market insights',
                subtitle: 'Data-driven outlook across key Nigerian corridors.',
              ),
              const SizedBox(height: AppSpacing.lg),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cross = context.isMobile ? 1 : 2;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cross,
                      mainAxisSpacing: AppSpacing.base,
                      crossAxisSpacing: AppSpacing.base,
                      childAspectRatio: context.isMobile ? 1.6 : 2.2,
                    ),
                    itemCount: cms.marketInsights.length,
                    itemBuilder: (_, i) {
                      final insight = cms.marketInsights[i];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text(insight.title, style: Theme.of(context).textTheme.titleSmall)),
                                  Text(insight.value, style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700)),
                                ],
                              ),
                              Text(insight.trend, style: Theme.of(context).textTheme.labelSmall),
                              const SizedBox(height: AppSpacing.sm),
                              Text(insight.summary, style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
