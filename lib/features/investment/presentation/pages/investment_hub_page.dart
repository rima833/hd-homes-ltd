import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/features/investment/data/providers/investment_cms_provider.dart';
import 'package:hdhomesproject/features/investment/presentation/sections/investment_closing_sections.dart';
import 'package:hdhomesproject/features/investment/presentation/sections/investment_hero_section.dart';
import 'package:hdhomesproject/features/investment/presentation/sections/investment_hub_sections.dart';

/// Investment Hub — Volume 2 Part 7.
class InvestmentHubPage extends ConsumerStatefulWidget {
  const InvestmentHubPage({super.key});

  @override
  ConsumerState<InvestmentHubPage> createState() => _InvestmentHubPageState();
}

class _InvestmentHubPageState extends ConsumerState<InvestmentHubPage> {
  final _opportunitiesKey = GlobalKey();
  final _processKey = GlobalKey();
  final _calculatorKey = GlobalKey();
  final _faqKey = GlobalKey();

  void _scrollTo(GlobalKey key) {
    final target = key.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cms = ref.watch(investmentHubCmsProvider);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: InvestmentHeroSection(
            headline: cms.heroHeadline,
            subheadline: cms.heroSubheadline,
            onExploreOpportunities: () => _scrollTo(_opportunitiesKey),
            onCalculateRoi: () => _scrollTo(_calculatorKey),
          ),
        ),
        SliverToBoxAdapter(
          child: InvestmentHubSections(
            opportunitiesKey: _opportunitiesKey,
            processKey: _processKey,
          ),
        ),
        SliverToBoxAdapter(
          child: InvestmentClosingSections(
            calculatorKey: _calculatorKey,
            faqKey: _faqKey,
          ),
        ),
      ],
    );
  }
}
