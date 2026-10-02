import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/investor/domain/entities/investor_models.dart';
import 'package:hdhomesproject/features/investor/presentation/providers/investor_providers.dart';
import 'package:hdhomesproject/features/investor/presentation/widgets/investor_bank_transfer_sheet.dart';
import 'package:hdhomesproject/features/investor/presentation/widgets/investor_portal_widgets.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

class InvestorPaymentsPage extends ConsumerStatefulWidget {
  const InvestorPaymentsPage({super.key});

  @override
  ConsumerState<InvestorPaymentsPage> createState() =>
      _InvestorPaymentsPageState();
}

class _InvestorPaymentsPageState extends ConsumerState<InvestorPaymentsPage>
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

  Future<void> _refresh() async {
    ref.invalidate(investorPaymentsProvider);
    ref.invalidate(investorDashboardProvider);
    await ref.read(investorPaymentsProvider.future);
  }

  Future<void> _openTransfer(InvestorPaymentsBundle bundle) {
    return showInvestorBankTransferSheet(
      context: context,
      ref: ref,
      bundle: bundle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final paymentsAsync = ref.watch(investorPaymentsProvider);
    final pad = _padding(context);
    final isWide = MediaQuery.sizeOf(context).width >= AppBreakpoints.tablet;

    return paymentsAsync.when(
      loading: () => const InvestorDashboardSkeleton(),
      error: (e, _) => InvestorErrorView(
        message: e,
        onRetry: _refresh,
      ),
      data: (bundle) {
        final paid = bundle.distributions
            .where((d) => d.status == 'paid')
            .toList();
        final scheduled = bundle.distributions
            .where((d) => d.status == 'scheduled' || d.status == 'processing')
            .toList();
        final outstanding = bundle.paymentIntents
            .where((i) => i.isAwaitingVerification)
            .toList();
        final wallet = bundle.primaryWallet;
        final account = bundle.primaryReceivingAccount;
        final fmt = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

        return Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                color: AppColors.gold,
                onRefresh: _refresh,
                child: NestedScrollView(
                  headerSliverBuilder: (context, _) => [
                    SliverPadding(
                      padding: pad.copyWith(bottom: 0),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                        'Submit bank transfers for finance verification. Settled payments and receipts update live.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: AppColors.slate400,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                FilledButton.icon(
                                  onPressed: () => _openTransfer(bundle),
                                  icon: const Icon(
                                    LucideIcons.landmark,
                                    size: 16,
                                  ),
                                  label: Text(
                                    isWide ? 'Make payment' : 'Pay',
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.gold,
                                    foregroundColor: AppColors.charcoal,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _PaymentsKpiRow(
                              isWide: isWide,
                              outstanding: fmt.format(bundle.outstandingIntents),
                              walletAvailable:
                                  wallet?.formattedAvailable ?? '₦0',
                              totalPaid: fmt.format(bundle.totalPaid),
                              totalScheduled: fmt.format(bundle.totalScheduled),
                            ),
                            if (account != null) ...[
                              const SizedBox(height: 16),
                              _ReceivingAccountCard(
                                account: account,
                                onTransfer: () => _openTransfer(bundle),
                              ),
                            ],
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _PaymentsTabBarDelegate(
                        TabBar(
                          controller: _tabController,
                          isScrollable: true,
                          tabAlignment: TabAlignment.start,
                          indicatorColor: AppColors.gold,
                          labelColor: AppColors.gold,
                          unselectedLabelColor: AppColors.slate400,
                          tabs: [
                            Tab(
                              text:
                                  'Pending (${outstanding.length})',
                            ),
                            Tab(
                              text:
                                  'History (${bundle.settledPayments.length})',
                            ),
                            Tab(
                              text:
                                  'Distributions (${paid.length + scheduled.length})',
                            ),
                            Tab(
                              text: 'Receipts (${bundle.receipts.length})',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  body: TabBarView(
                    controller: _tabController,
                    children: [
                      _IntentList(
                        items: outstanding.isNotEmpty
                            ? outstanding
                            : bundle.paymentIntents,
                        emptyTitle: 'No pending verifications',
                        emptyMessage:
                            'Submitted bank transfers awaiting Finance confirmation appear here.',
                      ),
                      _SettledList(items: bundle.settledPayments),
                      _DistributionList(
                        items: [...scheduled, ...paid],
                      ),
                      _ReceiptList(items: bundle.receipts),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PaymentsKpiRow extends StatelessWidget {
  const _PaymentsKpiRow({
    required this.isWide,
    required this.outstanding,
    required this.walletAvailable,
    required this.totalPaid,
    required this.totalScheduled,
  });

  final bool isWide;
  final String outstanding;
  final String walletAvailable;
  final String totalPaid;
  final String totalScheduled;

  @override
  Widget build(BuildContext context) {
    final cards = [
      InvestorKpiCard(
        label: 'Outstanding',
        value: outstanding,
        icon: LucideIcons.alertCircle,
        accent: AppColors.warning,
        subtitle: 'Awaiting finance',
      ),
      InvestorKpiCard(
        label: 'Wallet available',
        value: walletAvailable,
        icon: LucideIcons.wallet,
        accent: AppColors.info,
        subtitle: 'Ready balance',
      ),
      InvestorKpiCard(
        label: 'Distributions paid',
        value: totalPaid,
        icon: LucideIcons.checkCircle2,
        accent: AppColors.success,
        subtitle: 'All time',
      ),
      InvestorKpiCard(
        label: 'Scheduled payouts',
        value: totalScheduled,
        icon: LucideIcons.clock,
        accent: AppColors.warning,
        subtitle: 'Upcoming',
      ),
    ];

    if (isWide) {
      return Row(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: cards[i]),
          ],
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 12),
            Expanded(child: cards[1]),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: cards[2]),
            const SizedBox(width: 12),
            Expanded(child: cards[3]),
          ],
        ),
      ],
    );
  }
}

class _ReceivingAccountCard extends StatelessWidget {
  const _ReceivingAccountCard({
    required this.account,
    required this.onTransfer,
  });

  final InvestmentReceivingAccount account;
  final VoidCallback onTransfer;

  @override
  Widget build(BuildContext context) {
    return InvestorPortalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  LucideIcons.landmark,
                  color: AppColors.gold,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HD Homes receiving account',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${account.bankName} · ${account.accountName}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.slate400,
                          ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onTransfer,
                child: const Text('Pay now'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Acct ${account.accountNumber}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                ),
              ),
              IconButton(
                tooltip: 'Copy account number',
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: account.accountNumber),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Account number copied')),
                    );
                  }
                },
                icon: const Icon(LucideIcons.copy, size: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentsTabBarDelegate extends SliverPersistentHeaderDelegate {
  _PaymentsTabBarDelegate(this.tabBar);

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
    return ColoredBox(color: AppColors.deepBlack, child: tabBar);
  }

  @override
  bool shouldRebuild(covariant _PaymentsTabBarDelegate oldDelegate) =>
      tabBar != oldDelegate.tabBar;
}

class _IntentList extends StatelessWidget {
  const _IntentList({
    required this.items,
    this.emptyTitle = 'No transfers yet',
    this.emptyMessage =
        'Submit a bank transfer confirmation. Finance verifies settlement — you cannot mark payments completed.',
  });

  final List<InvestorPaymentIntent> items;
  final String emptyTitle;
  final String emptyMessage;

  Color _statusColor(InvestorPaymentIntent item) {
    if (item.isVerified) return AppColors.success;
    if (item.isAwaitingVerification) return AppColors.warning;
    if (item.isRejected) return AppColors.error;
    return AppColors.info;
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return InvestorEmptyState(
        title: emptyTitle,
        message: emptyMessage,
        icon: LucideIcons.landmark,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        final statusColor = _statusColor(item);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InvestorPortalCard(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    LucideIcons.landmark,
                    color: statusColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.formattedAmount,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AppColors.white,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          item.displayStatus,
                          if (item.holdingLabel != null) item.holdingLabel!,
                          if (item.providerReference != null)
                            item.providerReference!,
                        ].join(' · '),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.slate400,
                            ),
                      ),
                    ],
                  ),
                ),
                if (item.createdAt != null)
                  Text(
                    DateFormat.MMMd().format(item.createdAt!),
                    style: const TextStyle(
                      color: AppColors.slate500,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SettledList extends StatelessWidget {
  const _SettledList({required this.items});

  final List<InvestorSettledPayment> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const InvestorEmptyState(
        title: 'No verified payments yet',
        message:
            'Once Finance verifies a bank transfer, the settled payment appears here with its receipt.',
        icon: LucideIcons.badgeCheck,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InvestorPortalCard(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    LucideIcons.badgeCheck,
                    color: AppColors.success,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.formattedAmount,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AppColors.white,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          'Verified',
                          if (item.receiptNumber != null) item.receiptNumber!,
                          if (item.providerReference != null)
                            item.providerReference!,
                        ].join(' · '),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.slate400,
                            ),
                      ),
                    ],
                  ),
                ),
                if (item.paidAt != null)
                  Text(
                    DateFormat.MMMd().format(item.paidAt!),
                    style: const TextStyle(
                      color: AppColors.slate500,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ReceiptList extends StatelessWidget {
  const _ReceiptList({required this.items});

  final List<InvestorPaymentReceipt> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const InvestorEmptyState(
        title: 'No receipts yet',
        message:
            'Receipts are issued when Finance verifies your bank transfer.',
        icon: LucideIcons.receipt,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InvestorPortalCard(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    LucideIcons.receipt,
                    color: AppColors.info,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.receiptNumber,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AppColors.white,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          item.formattedAmount,
                          if (item.methodLabel != null) item.methodLabel!,
                        ].join(' · '),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.slate400,
                            ),
                      ),
                    ],
                  ),
                ),
                if (item.issuedAt != null)
                  Text(
                    DateFormat.MMMd().format(item.issuedAt!),
                    style: const TextStyle(
                      color: AppColors.slate500,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DistributionList extends StatelessWidget {
  const _DistributionList({required this.items});

  final List<InvestorDistribution> items;

  Color _statusColor(String status) {
    switch (status) {
      case 'paid':
        return AppColors.success;
      case 'processing':
        return AppColors.info;
      case 'scheduled':
        return AppColors.warning;
      default:
        return AppColors.slate400;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const InvestorEmptyState(
        title: 'No distributions',
        message: 'Scheduled and paid investor distributions appear here.',
        icon: LucideIcons.banknote,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        final color = _statusColor(item.status);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InvestorPortalCard(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(LucideIcons.banknote, color: color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.formattedAmount,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AppColors.white,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item.distributionType.replaceAll('_', ' ')} · ${item.status}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.slate400,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

