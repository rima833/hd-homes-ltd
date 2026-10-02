import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/home/data/providers/roi_calculator_provider.dart';
import 'package:hdhomesproject/features/home/presentation/sections/home_payment_calculator_section.dart';
import 'package:hdhomesproject/features/home/presentation/sections/home_roi_calculator_section.dart';
import 'package:hdhomesproject/features/investor/presentation/widgets/investor_portal_widgets.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Investor investment tools — ROI + payment plan calculators and next-step CTAs.
///
/// Reuses the public CMS-backed calculators. Holdings are still staff-assigned
/// via IMP; these tools help investors evaluate opportunities and funding plans.
class InvestorToolsPage extends ConsumerStatefulWidget {
  const InvestorToolsPage({super.key, this.initialAmount});

  /// Optional seed amount (e.g. holding cost basis) for the ROI calculator.
  final double? initialAmount;

  @override
  ConsumerState<InvestorToolsPage> createState() => _InvestorToolsPageState();
}

class _InvestorToolsPageState extends ConsumerState<InvestorToolsPage> {
  var _seededAmount = false;

  void _seedRoiAmountIfNeeded() {
    if (_seededAmount) return;
    final amount = widget.initialAmount;
    if (amount == null || amount <= 0) return;
    final state = ref.read(roiCalculatorControllerProvider);
    if (state == null) return;
    ref.read(roiCalculatorControllerProvider.notifier).setAmount(amount);
    _seededAmount = true;
  }

  EdgeInsets _padding(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return EdgeInsets.all(w >= AppBreakpoints.tablet ? 24 : 16);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(roiCalculatorControllerProvider, (_, next) {
      if (next != null) _seedRoiAmountIfNeeded();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _seedRoiAmountIfNeeded();
    });

    final pad = _padding(context);

    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: pad.copyWith(bottom: 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    'Investment tools',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Project returns, model payment plans, then request allocation. '
                  'HD Homes assigns holdings after consultation and due diligence.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.slate400,
                      ),
                ),
                const SizedBox(height: 16),
                InvestorPortalCard(
                  padding: const EdgeInsets.all(4),
                  child: TabBar(
                    indicatorColor: AppColors.gold,
                    labelColor: AppColors.gold,
                    unselectedLabelColor: AppColors.slate400,
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(
                        text: 'ROI calculator',
                        icon: Icon(LucideIcons.lineChart, size: 16),
                      ),
                      Tab(
                        text: 'Payment plans',
                        icon: Icon(LucideIcons.calculator, size: 16),
                      ),
                      Tab(
                        text: 'Next steps',
                        icon: Icon(LucideIcons.map, size: 16),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                ListView(
                  padding: pad,
                  children: const [
                    HomeRoiCalculatorSection(wrapInSection: false),
                  ],
                ),
                ListView(
                  padding: pad,
                  children: const [
                    HomePaymentCalculatorSection(wrapInSection: false),
                  ],
                ),
                ListView(
                  padding: pad,
                  children: const [_InvestFlowSteps()],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InvestFlowSteps extends StatelessWidget {
  const _InvestFlowSteps();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const InvestorSectionHeader(
          title: 'How investing works',
          subtitle:
              'From property interest to a live holding in your portal.',
        ),
        const _FlowStep(
          step: '1',
          title: 'Choose an opportunity',
          body:
              'Browse investment opportunities and shortlist the property or unit you want.',
          actionLabel: 'Browse opportunities',
          icon: LucideIcons.building2,
          onPath: RoutePaths.investment,
        ),
        const SizedBox(height: 12),
        const _FlowStep(
          step: '2',
          title: 'Project returns & payment plan',
          body:
              'Use the ROI and payment calculators to model growth and installments before you commit.',
          actionLabel: 'Open ROI calculator',
          icon: LucideIcons.lineChart,
          onRoiTab: true,
        ),
        const SizedBox(height: 12),
        const _FlowStep(
          step: '3',
          title: 'Book consultation',
          body:
              'Speak with investor relations for due diligence, unit selection, and allocation.',
          actionLabel: 'Book consultation',
          icon: LucideIcons.calendarCheck,
          onPath: RoutePaths.bookConsultation,
        ),
        const SizedBox(height: 12),
        const _FlowStep(
          step: '4',
          title: 'Fund via bank transfer',
          body:
              'Create a payment intent with a unique reference. Finance confirms offline — you never self-settle.',
          actionLabel: 'Open payments',
          icon: LucideIcons.landmark,
          onPath: RoutePaths.investorPayments,
        ),
        const SizedBox(height: 12),
        const _FlowStep(
          step: '5',
          title: 'Holding appears live',
          body:
              'After staff assign the investment in IMP, your portfolio, construction, and documents update in real time.',
          actionLabel: 'View portfolio',
          icon: LucideIcons.pieChart,
          onPath: RoutePaths.investorPortfolio,
        ),
        const SizedBox(height: 24),
        InvestorPortalCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Need help?',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Chat with IR on Messages, or open a tracked ticket on Support.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.slate400,
                    ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: () => context.go(RoutePaths.investorMessages),
                    icon: const Icon(LucideIcons.messageCircle, size: 16),
                    label: const Text('Messages'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.charcoal,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.go(RoutePaths.investorSupport),
                    icon: const Icon(LucideIcons.ticket, size: 16),
                    label: const Text('Open a ticket'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.gold,
                      side: BorderSide(
                        color: AppColors.gold.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _FlowStep extends StatelessWidget {
  const _FlowStep({
    required this.step,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.icon,
    this.onPath,
    this.onRoiTab = false,
  });

  final String step;
  final String title;
  final String body;
  final String actionLabel;
  final IconData icon;
  final String? onPath;
  final bool onRoiTab;

  @override
  Widget build(BuildContext context) {
    return InvestorPortalCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              step,
              style: const TextStyle(
                color: AppColors.gold,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 16, color: AppColors.gold),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AppColors.white,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.slate400,
                      ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () {
                    if (onRoiTab) {
                      DefaultTabController.of(context).animateTo(0);
                      return;
                    }
                    final path = onPath;
                    if (path != null) context.go(path);
                  },
                  icon: Icon(icon, size: 14),
                  label: Text(actionLabel),
                  style: TextButton.styleFrom(foregroundColor: AppColors.gold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
