import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/client/domain/entities/client_models.dart';
import 'package:hdhomesproject/features/client/presentation/providers/client_payment_engine_providers.dart';
import 'package:hdhomesproject/features/client/presentation/providers/client_providers.dart';
import 'package:hdhomesproject/features/client/presentation/widgets/client_payment_intent_dialog.dart';
import 'package:hdhomesproject/features/client/presentation/widgets/client_portal_widgets.dart';
import 'package:hdhomesproject/features/client/presentation/widgets/payments/payment_summary_header.dart';
import 'package:hdhomesproject/features/client/presentation/widgets/payments/payment_tab_lists.dart';
import 'package:lucide_icons/lucide_icons.dart';

class ClientPaymentsPage extends ConsumerStatefulWidget {
  const ClientPaymentsPage({super.key});

  @override
  ConsumerState<ClientPaymentsPage> createState() => _ClientPaymentsPageState();
}

class _ClientPaymentsPageState extends ConsumerState<ClientPaymentsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  EdgeInsets _padding(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return EdgeInsets.all(w >= AppBreakpoints.tablet ? 24 : 16);
  }

  Future<void> _openPaymentFlow({ClientInstallment? installment}) =>
      showClientPaymentFlowSheet(context, ref, installment: installment);

  Future<void> _refreshAll() async {
    ref.invalidate(clientPaymentsProvider);
    ref.invalidate(clientPaymentSummaryProvider);
    ref.invalidate(clientPaymentIntentsProvider);
    ref.invalidate(clientPaymentChargesProvider);
    ref.invalidate(clientFinanceReceiptsProvider);
    ref.invalidate(clientPaymentHistoryProvider);
  }

  @override
  Widget build(BuildContext context) {
    final paymentsAsync = ref.watch(clientPaymentsProvider);
    final summaryAsync = ref.watch(clientPaymentSummaryProvider);
    final historyAsync = ref.watch(clientPaymentHistoryProvider);
    final receiptsAsync = ref.watch(clientFinanceReceiptsProvider);
    final chargesAsync = ref.watch(clientPaymentChargesProvider);

    return paymentsAsync.when(
      skipLoadingOnReload: true,
      loading: () => const ClientPageSkeleton(),
      error: (e, _) => ClientErrorView(
        message: e,
        onRetry: _refreshAll,
      ),
      data: (bundle) {
        final summary = summaryAsync.valueOrNull ?? bundle.summary;
        final pad = _padding(context);

        return NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(
                child: Padding(
                  padding: pad.copyWith(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Payments',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    color: AppColors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Track installments, submit bank transfers for '
                              'verification, and view receipts.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppColors.textSecondaryDark,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: () => _openPaymentFlow(),
                        icon: const Icon(LucideIcons.plus, size: 16),
                        label: const Text('Pay Now'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: AppColors.charcoal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: pad.copyWith(top: 0, bottom: 8),
                  child: PaymentSummaryHeader(
                    summary: summary,
                    fallbackPaid: bundle.totalPaid,
                    fallbackOutstanding: bundle.outstanding,
                  ),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _PaymentsTabBarDelegate(
                  tabBar: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: AppColors.gold,
                    unselectedLabelColor: AppColors.slate400,
                    indicatorColor: AppColors.gold,
                    tabs: const [
                      Tab(text: 'Schedule'),
                      Tab(text: 'History'),
                      Tab(text: 'Receipts'),
                      Tab(text: 'Charges'),
                    ],
                  ),
                ),
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              PaymentScheduleList(
                installments: bundle.installments,
                padding: pad,
                onRefresh: _refreshAll,
                onPayInstallment: (inst) =>
                    _openPaymentFlow(installment: inst),
              ),
              historyAsync.when(
                skipLoadingOnReload: true,
                loading: () => const ClientPageSkeleton(
                  showKpis: false,
                  rows: 4,
                ),
                error: (e, _) => ClientErrorView(
                  message: e,
                  onRetry: () =>
                      ref.invalidate(clientPaymentHistoryProvider),
                ),
                data: (items) => PaymentHistoryList(
                  items: items,
                  padding: pad,
                  onRefresh: _refreshAll,
                ),
              ),
              receiptsAsync.when(
                skipLoadingOnReload: true,
                loading: () => const ClientPageSkeleton(
                  showKpis: false,
                  rows: 4,
                ),
                error: (e, _) => ClientErrorView(
                  message: e,
                  onRetry: () =>
                      ref.invalidate(clientFinanceReceiptsProvider),
                ),
                data: (receipts) => PaymentReceiptsList(
                  receipts: receipts,
                  padding: pad,
                  onRefresh: _refreshAll,
                ),
              ),
              chargesAsync.when(
                skipLoadingOnReload: true,
                loading: () => const ClientPageSkeleton(
                  showKpis: false,
                  rows: 4,
                ),
                error: (e, _) => ClientErrorView(
                  message: e,
                  onRetry: () =>
                      ref.invalidate(clientPaymentChargesProvider),
                ),
                data: (charges) => PaymentChargesList(
                  charges: charges,
                  padding: pad,
                  onRefresh: _refreshAll,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PaymentsTabBarDelegate extends SliverPersistentHeaderDelegate {
  _PaymentsTabBarDelegate({required this.tabBar});

  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: AppColors.charcoal,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _PaymentsTabBarDelegate oldDelegate) =>
      tabBar != oldDelegate.tabBar;
}
