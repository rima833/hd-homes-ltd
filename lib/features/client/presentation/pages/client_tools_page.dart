import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/client/presentation/widgets/client_portal_widgets.dart';
import 'package:hdhomesproject/features/home/presentation/sections/home_payment_calculator_section.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Client buying tools — payment plan calculator + how-buying-works flow.
///
/// Properties appear after staff approve an application (auto-allocation).
/// Clients fund via bank-transfer intents; finance confirms offline.
class ClientToolsPage extends StatelessWidget {
  const ClientToolsPage({super.key});

  EdgeInsets _padding(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return EdgeInsets.all(w >= AppBreakpoints.tablet ? 24 : 16);
  }

  @override
  Widget build(BuildContext context) {
    final pad = _padding(context);

    return DefaultTabController(
      length: 2,
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
                    'Buying tools',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Model payment plans, then apply. HD Homes allocates your '
                  'property after approval — it appears in My Properties in real time.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.slate400),
                ),
                const SizedBox(height: 16),
                ClientPortalCard(
                  padding: const EdgeInsets.all(4),
                  child: TabBar(
                    indicatorColor: AppColors.gold,
                    labelColor: AppColors.gold,
                    unselectedLabelColor: AppColors.slate400,
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(
                        text: 'Payment plans',
                        icon: Icon(LucideIcons.calculator, size: 16),
                      ),
                      Tab(
                        text: 'How buying works',
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
                    HomePaymentCalculatorSection(wrapInSection: false),
                  ],
                ),
                ListView(padding: pad, children: const [_BuyingFlowSteps()]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BuyingFlowSteps extends StatelessWidget {
  const _BuyingFlowSteps();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ClientSectionHeader(
          title: 'How buying works',
          subtitle:
              'From property interest to a live allocation in your portal.',
        ),
        const _FlowStep(
          step: '1',
          title: 'Browse & shortlist',
          body:
              'Explore listings on the marketplace or save favorites, then open an application for the unit you want.',
          actionLabel: 'Browse properties',
          icon: LucideIcons.building2,
          onPath: RoutePaths.properties,
        ),
        const SizedBox(height: 12),
        const _FlowStep(
          step: '2',
          title: 'Model your payment plan',
          body:
              'Use the payment calculator to estimate deposits and installments before you apply.',
          actionLabel: 'Open payment calculator',
          icon: LucideIcons.calculator,
          onPaymentTab: true,
        ),
        const SizedBox(height: 12),
        const _FlowStep(
          step: '3',
          title: 'Submit an application',
          body:
              'Start an application in the portal, upload required documents, and track status live.',
          actionLabel: 'New application',
          icon: LucideIcons.filePlus2,
          onPath: RoutePaths.clientApplications,
        ),
        const SizedBox(height: 12),
        const _FlowStep(
          step: '4',
          title: 'Staff approve & allocate',
          body:
              'When HD Homes approves your application, a property allocation is created automatically and appears under My Properties.',
          actionLabel: 'View applications',
          icon: LucideIcons.badgeCheck,
          onPath: RoutePaths.clientApplications,
        ),
        const SizedBox(height: 12),
        const _FlowStep(
          step: '5',
          title: 'Fund via bank transfer',
          body:
              'Create a payment intent with a unique reference. Finance confirms offline — you never self-settle.',
          actionLabel: 'Open payments',
          icon: LucideIcons.landmark,
          onPath: RoutePaths.clientPayments,
        ),
        const SizedBox(height: 12),
        const _FlowStep(
          step: '6',
          title: 'Track progress live',
          body:
              'Documents, construction updates, inspections, and messages refresh in real time as staff publish them.',
          actionLabel: 'My properties',
          icon: LucideIcons.home,
          onPath: RoutePaths.clientProperties,
        ),
        const SizedBox(height: 24),
        ClientPortalCard(
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
                'Chat on Messages, or open a tracked ticket on Support.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.slate400),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: () => context.go(RoutePaths.clientMessages),
                    icon: const Icon(LucideIcons.messageCircle, size: 16),
                    label: const Text('Messages'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.charcoal,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.go(RoutePaths.clientConsultations),
                    icon: const Icon(LucideIcons.calendar, size: 16),
                    label: const Text('Book consultation'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.gold,
                      side: BorderSide(
                        color: AppColors.gold.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.go(RoutePaths.clientSupport),
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
    this.onPaymentTab = false,
  });

  final String step;
  final String title;
  final String body;
  final String actionLabel;
  final IconData icon;
  final String? onPath;
  final bool onPaymentTab;

  @override
  Widget build(BuildContext context) {
    return ClientPortalCard(
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
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.slate400),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () {
                    if (onPaymentTab) {
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
