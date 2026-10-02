import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/offline_updates_note.dart';
import 'package:hdhomesproject/features/investor/domain/entities/investor_models.dart';
import 'package:hdhomesproject/features/investor/presentation/providers/investor_portal_realtime_provider.dart';
import 'package:hdhomesproject/features/investor/presentation/providers/investor_providers.dart';
import 'package:hdhomesproject/features/investor/presentation/widgets/investor_portal_widgets.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

class InvestorAnalyticsPage extends ConsumerWidget {
  const InvestorAnalyticsPage({super.key});

  EdgeInsets _padding(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return EdgeInsets.all(w >= AppBreakpoints.tablet ? 24 : 16);
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(investorAnalyticsSnapshotProvider);
    ref.invalidate(investorHoldingsProvider);
    ref.invalidate(investorPerformanceProvider);
    await Future.wait([
      ref.read(investorAnalyticsSnapshotProvider.future),
      ref.read(investorHoldingsProvider.future),
    ]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotAsync = ref.watch(investorAnalyticsSnapshotProvider);
    final holdingsAsync = ref.watch(investorHoldingsProvider);
    final months = ref.watch(investorAnalyticsMonthsProvider);
    final connection = ref.watch(investorRealtimeConnectionProvider);
    final live = connection == InvestorRealtimeConnection.live;
    final pad = _padding(context);
    final isWide = MediaQuery.sizeOf(context).width >= AppBreakpoints.tablet;
    final fmt = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

    return snapshotAsync.when(
      loading: () => const InvestorDashboardSkeleton(),
      error: (e, _) => InvestorErrorView(
        message: e,
        onRetry: () => _refresh(ref),
      ),
      data: (snap) {
        final holdings = holdingsAsync.valueOrNull ?? [];
        final latest = snap.latest;
        final chronological = snap.series;
        final totalValue = snap.portfolioValue;
        final unrealized = snap.unrealizedPnl;

        return RefreshIndicator(
          color: AppColors.gold,
          onRefresh: () => _refresh(ref),
          child: ListView(
            padding: pad,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Investment Analytics',
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
                          'Trusted NAV, ROI, and allocation — filtered by period.',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.slate400,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _LiveChip(live: live, connection: connection),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final opt in const [
                    (3, '3M'),
                    (6, '6M'),
                    (12, '1Y'),
                    (null, 'All'),
                  ])
                    _RangeChip(
                      label: opt.$2,
                      selected: months == opt.$1,
                      onTap: () {
                        ref.read(investorAnalyticsMonthsProvider.notifier).state =
                            opt.$1;
                      },
                    ),
                ],
              ),
              const SizedBox(height: 20),
              if (isWide)
                Row(
                  children: [
                    Expanded(
                      child: InvestorKpiCard(
                        label: 'Portfolio value',
                        value: fmt.format(totalValue),
                        icon: LucideIcons.wallet,
                        subtitle: 'Current book',
                        onTap: () => context.go(RoutePaths.investorPortfolio),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InvestorKpiCard(
                        label: 'ROI',
                        value:
                            '${snap.roiPct >= 0 ? '+' : ''}${snap.roiPct.toStringAsFixed(1)}%',
                        icon: LucideIcons.trendingUp,
                        accent: snap.roiPct >= 0
                            ? AppColors.success
                            : AppColors.error,
                        subtitle: 'vs cost basis',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InvestorKpiCard(
                        label: 'Total return',
                        value:
                            '${snap.totalReturnPct >= 0 ? '+' : ''}${snap.totalReturnPct.toStringAsFixed(1)}%',
                        icon: LucideIcons.percent,
                        accent: AppColors.info,
                        subtitle: 'Incl. distributions',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InvestorKpiCard(
                        label: 'Distributions',
                        value: fmt.format(snap.distributionsPaid),
                        icon: LucideIcons.coins,
                        accent: AppColors.warning,
                        subtitle: 'Paid in window',
                        onTap: () => context.go(RoutePaths.investorPayments),
                      ),
                    ),
                  ],
                )
              else ...[
                InvestorPortalCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: _MiniMetric(
                          label: 'Value',
                          value: fmt.format(totalValue),
                          color: AppColors.gold,
                        ),
                      ),
                      Expanded(
                        child: _MiniMetric(
                          label: 'ROI',
                          value:
                              '${snap.roiPct >= 0 ? '+' : ''}${snap.roiPct.toStringAsFixed(1)}%',
                          color: snap.roiPct >= 0
                              ? AppColors.success
                              : AppColors.error,
                        ),
                      ),
                      Expanded(
                        child: _MiniMetric(
                          label: 'Total rtn',
                          value:
                              '${snap.totalReturnPct >= 0 ? '+' : ''}${snap.totalReturnPct.toStringAsFixed(1)}%',
                          color: AppColors.info,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (latest != null) ...[
                _MetricsRow(latest: latest, isWide: isWide),
                const SizedBox(height: 16),
                InvestorPortalCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: _MiniMetric(
                          label: 'Invested',
                          value: fmt.format(snap.costBasis),
                          color: AppColors.slate400,
                        ),
                      ),
                      Expanded(
                        child: _MiniMetric(
                          label: 'Unrealized P&L',
                          value: fmt.format(unrealized),
                          color: unrealized >= 0
                              ? AppColors.success
                              : AppColors.error,
                        ),
                      ),
                      Expanded(
                        child: _MiniMetric(
                          label: 'Pending payouts',
                          value: fmt.format(snap.distributionsPending),
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                InvestorSectionHeader(
                  title: 'NAV history',
                  subtitle: latest.asOfDate != null
                      ? 'As of ${DateFormat.yMMMd().format(latest.asOfDate!)}'
                      : null,
                  action: TextButton(
                    onPressed: () => context.go(RoutePaths.investorReports),
                    child: const Text(
                      'Reports',
                      style: TextStyle(color: AppColors.gold),
                    ),
                  ),
                ),
                InvestorPortalCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (chronological.isEmpty)
                        const Text(
                          'No NAV points in this window yet.',
                          style: TextStyle(color: AppColors.slate400),
                        )
                      else ...[
                        InvestorSimpleBarChart(
                          values: chronological.map((p) => p.nav).toList(),
                          labels: chronological
                              .map(
                                (p) => p.asOfDate != null
                                    ? DateFormat.MMM().format(p.asOfDate!)
                                    : '—',
                              )
                              .toList(),
                        ),
                        if (chronological.length >= 2) ...[
                          const SizedBox(height: 12),
                          _NavDelta(
                            first: chronological.first.nav,
                            last: chronological.last.nav,
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ] else
                InvestorEmptyState(
                  title: 'No performance data yet',
                  message:
                      'NAV, TWR, IRR, and yield appear here once finance publishes investment performance for your account.',
                  icon: LucideIcons.lineChart,
                  action: FilledButton.icon(
                    onPressed: () => context.go(RoutePaths.investorSupport),
                    icon: const Icon(LucideIcons.headphones, size: 16),
                    label: const Text('Ask investor relations'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.charcoal,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _AllocationSection(
                        holdings: holdings,
                        totalValue: totalValue,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _HoldingsBreakdown(
                        holdings: holdings,
                        totalValue: totalValue,
                      ),
                    ),
                  ],
                )
              else ...[
                _AllocationSection(
                  holdings: holdings,
                  totalValue: totalValue,
                ),
                const SizedBox(height: 24),
                _HoldingsBreakdown(
                  holdings: holdings,
                  totalValue: totalValue,
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

class _LiveChip extends StatelessWidget {
  const _LiveChip({required this.live, required this.connection});

  final bool live;
  final InvestorRealtimeConnection connection;

  @override
  Widget build(BuildContext context) {
    if (live || connection == InvestorRealtimeConnection.connecting) {
      return const SizedBox.shrink();
    }
    return const OfflineUpdatesNote();
  }
}

class _RangeChip extends StatelessWidget {
  const _RangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.gold.withValues(alpha: 0.15)
              : AppColors.darkSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.gold.withValues(alpha: 0.55)
                : AppColors.neutral700.withValues(alpha: 0.5),
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected ? AppColors.gold : AppColors.slate400,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

class _MetricsRow extends StatelessWidget {
  const _MetricsRow({required this.latest, required this.isWide});

  final InvestorPerformance latest;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final cards = [
      InvestorKpiCard(
        label: 'NAV',
        value: latest.formattedNav,
        icon: LucideIcons.landmark,
        subtitle: 'Net asset value',
        onTap: () => context.go(RoutePaths.investorPortfolio),
      ),
      InvestorKpiCard(
        label: 'TWR',
        value: latest.twrPct != null
            ? '${latest.twrPct!.toStringAsFixed(2)}%'
            : '—',
        icon: LucideIcons.percent,
        accent: AppColors.success,
        subtitle: 'Time-weighted return',
      ),
      InvestorKpiCard(
        label: 'IRR',
        value: latest.irrPct != null
            ? '${latest.irrPct!.toStringAsFixed(2)}%'
            : '—',
        icon: LucideIcons.trendingUp,
        accent: AppColors.info,
        subtitle: 'Internal rate of return',
      ),
      InvestorKpiCard(
        label: 'Yield',
        value: latest.yieldPct != null
            ? '${latest.yieldPct!.toStringAsFixed(2)}%'
            : '—',
        icon: LucideIcons.coins,
        accent: AppColors.warning,
        subtitle: 'Distribution yield',
        onTap: () => context.go(RoutePaths.investorPayments),
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

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.slate400,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _NavDelta extends StatelessWidget {
  const _NavDelta({required this.first, required this.last});

  final double first;
  final double last;

  @override
  Widget build(BuildContext context) {
    final delta = last - first;
    final pct = first > 0 ? (delta / first) * 100 : 0.0;
    final up = delta >= 0;
    final fmt = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

    return Row(
      children: [
        Icon(
          up ? LucideIcons.trendingUp : LucideIcons.trendingDown,
          size: 16,
          color: up ? AppColors.success : AppColors.error,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${up ? '+' : ''}${fmt.format(delta)} (${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%) over selected period',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: up ? AppColors.success : AppColors.error,
                ),
          ),
        ),
      ],
    );
  }
}

class _AllocationSection extends StatelessWidget {
  const _AllocationSection({
    required this.holdings,
    required this.totalValue,
  });

  final List<InvestorHolding> holdings;
  final double totalValue;

  @override
  Widget build(BuildContext context) {
    final sorted = [...holdings]
      ..sort((a, b) => b.currentValue.compareTo(a.currentValue));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InvestorSectionHeader(
          title: 'Allocation by holding',
          action: TextButton(
            onPressed: () => context.go(RoutePaths.investorPortfolio),
            child: const Text(
              'Portfolio',
              style: TextStyle(color: AppColors.gold),
            ),
          ),
        ),
        if (sorted.isEmpty)
          const InvestorPortalCard(
            child: Text(
              'No holdings to allocate yet.',
              style: TextStyle(color: AppColors.slate400),
            ),
          )
        else
          InvestorPortalCard(
            child: Column(
              children: [
                InvestorSimpleBarChart(
                  values: sorted.map((h) => h.currentValue).toList(),
                  labels: sorted
                      .map(
                        (h) => h.label.length > 8
                            ? '${h.label.substring(0, 8)}…'
                            : h.label,
                      )
                      .toList(),
                  color: AppColors.info,
                ),
                const SizedBox(height: 8),
                Text(
                  'Total ${NumberFormat.currency(symbol: '₦', decimalDigits: 0).format(totalValue)}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.slate400,
                      ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _HoldingsBreakdown extends StatelessWidget {
  const _HoldingsBreakdown({
    required this.holdings,
    required this.totalValue,
  });

  final List<InvestorHolding> holdings;
  final double totalValue;

  @override
  Widget build(BuildContext context) {
    final sorted = [...holdings]
      ..sort((a, b) => b.currentValue.compareTo(a.currentValue));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const InvestorSectionHeader(title: 'Holdings breakdown'),
        if (sorted.isEmpty)
          const InvestorPortalCard(
            child: Text(
              'Allocate investments to see a live breakdown.',
              style: TextStyle(color: AppColors.slate400),
            ),
          )
        else
          InvestorPortalCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < sorted.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      color: AppColors.neutral700.withValues(alpha: 0.4),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: _AllocationRow(
                      holding: sorted[i],
                      total: totalValue,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _AllocationRow extends StatelessWidget {
  const _AllocationRow({required this.holding, required this.total});

  final InvestorHolding holding;
  final double total;

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (holding.currentValue / total) * 100 : 0.0;
    final isUp = holding.gainLossPct >= 0;

    return InkWell(
      onTap: () => context.go(RoutePaths.investorHoldingDetail(holding.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  holding.label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${pct.toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          InvestorProgressBar(
            label: holding.formattedCurrentValue,
            percent: pct,
          ),
          const SizedBox(height: 4),
          Text(
            '${isUp ? '+' : ''}${holding.gainLossPct.toStringAsFixed(1)}% vs cost',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isUp ? AppColors.success : AppColors.error,
                ),
          ),
        ],
      ),
    );
  }
}
