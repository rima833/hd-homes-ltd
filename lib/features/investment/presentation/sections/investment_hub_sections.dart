import 'package:flutter/material.dart';
import 'package:hdhomesproject/features/investment/data/providers/investment_cms_provider.dart';
import 'package:hdhomesproject/features/investment/presentation/sections/investment_market_insights_section.dart';
import 'package:hdhomesproject/features/investment/presentation/sections/investment_opportunities_section.dart';
import 'package:hdhomesproject/features/investment/presentation/sections/investment_process_section.dart';
import 'package:hdhomesproject/features/investment/presentation/sections/investment_why_invest_section.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Hub sections — pillars, opportunities, process, market insights.
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

    return Column(
      children: [
        InvestmentWhyInvestSection(
          pillars: cms.pillars,
          statistics: cms.statistics,
        ),
        KeyedSubtree(
          key: opportunitiesKey,
          child: const InvestmentOpportunitiesSection(),
        ),
        KeyedSubtree(
          key: processKey,
          child: InvestmentProcessSection(steps: cms.processSteps),
        ),
        const InvestmentMarketInsightsSection(),
      ],
    );
  }
}
