import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/media/widgets/delivery_image.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/investor/domain/entities/investor_models.dart';
import 'package:hdhomesproject/features/investor/presentation/providers/investor_providers.dart';
import 'package:hdhomesproject/features/investor/presentation/widgets/investor_portal_widgets.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

enum _HoldingSort { labelAsc, valueDesc, gainDesc, valueAsc }

class InvestorPortfolioPage extends ConsumerStatefulWidget {
  const InvestorPortfolioPage({super.key});

  @override
  ConsumerState<InvestorPortfolioPage> createState() =>
      _InvestorPortfolioPageState();
}

class _InvestorPortfolioPageState extends ConsumerState<InvestorPortfolioPage> {
  final _searchController = TextEditingController();
  String _query = '';
  _HoldingSort _sort = _HoldingSort.valueDesc;
  bool _isGrid = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  EdgeInsets _padding(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return EdgeInsets.all(w >= AppBreakpoints.tablet ? 24 : 16);
  }

  List<InvestorHolding> _filterAndSort(List<InvestorHolding> items) {
    var result = items.where((h) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return h.label.toLowerCase().contains(q) ||
          (h.location?.toLowerCase().contains(q) ?? false);
    }).toList();

    switch (_sort) {
      case _HoldingSort.labelAsc:
        result.sort((a, b) => a.label.compareTo(b.label));
      case _HoldingSort.valueDesc:
        result.sort((a, b) => b.currentValue.compareTo(a.currentValue));
      case _HoldingSort.valueAsc:
        result.sort((a, b) => a.currentValue.compareTo(b.currentValue));
      case _HoldingSort.gainDesc:
        result.sort((a, b) => b.gainLossPct.compareTo(a.gainLossPct));
    }
    return result;
  }

  void _openDetail(InvestorHolding holding) {
    context.push(RoutePaths.investorHoldingDetail(holding.id));
  }

  Future<void> _refresh() async {
    ref.invalidate(investorHoldingsProvider);
    ref.invalidate(investorDashboardProvider);
    ref.invalidate(investorCommitmentsProvider);
    await ref.read(investorHoldingsProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final holdingsAsync = ref.watch(investorHoldingsProvider);
    final pad = _padding(context);
    final isWide = MediaQuery.sizeOf(context).width >= AppBreakpoints.tablet;

    return holdingsAsync.when(
      loading: () => const InvestorDashboardSkeleton(),
      error: (e, _) => InvestorErrorView(
        message: e,
        onRetry: _refresh,
      ),
      data: (holdings) {
        final filtered = _filterAndSort(holdings);
        final totalValue = holdings.fold<double>(
          0,
          (s, h) => s + h.currentValue,
        );
        final totalCost = holdings.fold<double>(
          0,
          (s, h) => s + h.costBasis,
        );
        final gain = totalValue - totalCost;
        final gainPct = totalCost > 0 ? (gain / totalCost) * 100 : 0.0;
        final fmt = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
        final openCommitments = ref
                .watch(investorCommitmentsProvider)
                .valueOrNull
                ?.where((c) => c.isOpen)
                .length ??
            0;

        return RefreshIndicator(
          color: AppColors.gold,
          onRefresh: _refresh,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: pad,
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Portfolio',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Holdings, valuations, and performance across your investments.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.slate400,
                            ),
                      ),
                      const SizedBox(height: 20),
                      _PortfolioSummaryRow(
                        isWide: isWide,
                        holdingsCount: holdings.length,
                        totalValue: fmt.format(totalValue),
                        totalGain: fmt.format(gain),
                        gainPct: gainPct,
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _searchController,
                        style: const TextStyle(color: AppColors.white),
                        decoration: InputDecoration(
                          hintText: 'Search by name or location',
                          hintStyle: TextStyle(
                            color: AppColors.slate400.withValues(alpha: 0.9),
                          ),
                          prefixIcon: const Icon(
                            LucideIcons.search,
                            color: AppColors.slate400,
                            size: 18,
                          ),
                          suffixIcon: _query.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(LucideIcons.x, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _query = '');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: AppColors.darkSurface,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppColors.neutral700.withValues(alpha: 0.5),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppColors.neutral700.withValues(alpha: 0.5),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.gold),
                          ),
                        ),
                        onChanged: (v) => setState(() => _query = v),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppColors.darkSurface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color:
                                    AppColors.neutral700.withValues(alpha: 0.5),
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<_HoldingSort>(
                                value: _sort,
                                dropdownColor: AppColors.charcoal,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: AppColors.white),
                                items: const [
                                  DropdownMenuItem(
                                    value: _HoldingSort.valueDesc,
                                    child: Text('Value high–low'),
                                  ),
                                  DropdownMenuItem(
                                    value: _HoldingSort.valueAsc,
                                    child: Text('Value low–high'),
                                  ),
                                  DropdownMenuItem(
                                    value: _HoldingSort.gainDesc,
                                    child: Text('Best gain %'),
                                  ),
                                  DropdownMenuItem(
                                    value: _HoldingSort.labelAsc,
                                    child: Text('Name A–Z'),
                                  ),
                                ],
                                onChanged: (v) {
                                  if (v != null) setState(() => _sort = v);
                                },
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${filtered.length} holding${filtered.length == 1 ? '' : 's'}',
                            style:
                                Theme.of(context).textTheme.labelMedium?.copyWith(
                                      color: AppColors.slate400,
                                    ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: _isGrid ? 'List view' : 'Grid view',
                            onPressed: () =>
                                setState(() => _isGrid = !_isGrid),
                            icon: Icon(
                              _isGrid
                                  ? LucideIcons.list
                                  : LucideIcons.layoutGrid,
                              color: AppColors.gold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: InvestorEmptyState(
                    title: holdings.isEmpty
                        ? 'No holdings yet'
                        : 'No matches found',
                    message: holdings.isEmpty
                        ? (openCommitments > 0
                            ? '$openCommitments capital commitment${openCommitments == 1 ? '' : 's'} from HD Homes ${openCommitments == 1 ? 'is' : 'are'} waiting. A holding appears here once staff assign it.'
                            : 'Model returns with investment tools, browse opportunities, then request allocation. Holdings appear here in real time once assigned.')
                        : 'Try a different search or clear filters.',
                    icon: LucideIcons.briefcase,
                    action: holdings.isEmpty
                        ? Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              FilledButton.icon(
                                onPressed: () =>
                                    context.go(RoutePaths.investorTools),
                                icon: const Icon(
                                  LucideIcons.calculator,
                                  size: 16,
                                ),
                                label: const Text('Investment tools'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.gold,
                                  foregroundColor: AppColors.charcoal,
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: () =>
                                    context.go(RoutePaths.investment),
                                icon: const Icon(
                                  LucideIcons.building2,
                                  size: 16,
                                ),
                                label: const Text('Opportunities'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.gold,
                                  side: BorderSide(
                                    color:
                                        AppColors.gold.withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : TextButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            child: const Text('Clear search'),
                          ),
                  ),
                )
              else if (_isGrid)
                SliverPadding(
                  padding: pad.copyWith(top: 0, bottom: 32),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isWide ? 3 : 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: isWide ? 0.78 : 0.72,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _HoldingCard(
                        holding: filtered[i],
                        onTap: () => _openDetail(filtered[i]),
                      ),
                      childCount: filtered.length,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: pad.copyWith(top: 0, bottom: 32),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _HoldingListTile(
                          holding: filtered[i],
                          onTap: () => _openDetail(filtered[i]),
                        ),
                      ),
                      childCount: filtered.length,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PortfolioSummaryRow extends StatelessWidget {
  const _PortfolioSummaryRow({
    required this.isWide,
    required this.holdingsCount,
    required this.totalValue,
    required this.totalGain,
    required this.gainPct,
  });

  final bool isWide;
  final int holdingsCount;
  final String totalValue;
  final String totalGain;
  final double gainPct;

  @override
  Widget build(BuildContext context) {
    final cards = [
      InvestorKpiCard(
        label: 'Total value',
        value: totalValue,
        icon: LucideIcons.pieChart,
        subtitle: 'Current AUM',
      ),
      InvestorKpiCard(
        label: 'Holdings',
        value: '$holdingsCount',
        icon: LucideIcons.building2,
        accent: AppColors.info,
        subtitle: 'Active positions',
      ),
      InvestorKpiCard(
        label: 'Unrealized P&L',
        value: totalGain,
        icon: LucideIcons.trendingUp,
        accent: gainPct >= 0 ? AppColors.success : AppColors.error,
        subtitle:
            '${gainPct >= 0 ? '+' : ''}${gainPct.toStringAsFixed(1)}% vs cost',
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
        cards[0],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: cards[1]),
            const SizedBox(width: 12),
            Expanded(child: cards[2]),
          ],
        ),
      ],
    );
  }
}

class _HoldingCard extends StatelessWidget {
  const _HoldingCard({required this.holding, required this.onTap});

  final InvestorHolding holding;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isUp = holding.gainLossPct >= 0;

    return Material(
      color: AppColors.darkSurface,
      borderRadius: AppRadius.cardBorder,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardBorder,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardBorder,
            border: Border.all(
              color: AppColors.neutral700.withValues(alpha: 0.45),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    holding.imageUrl != null
                        ? MediaDeliveryImage(
                            url: holding.imageUrl!,
                            fit: BoxFit.cover,
                            errorWidget: _placeholder(),
                          )
                        : _placeholder(),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: (isUp ? AppColors.success : AppColors.error)
                              .withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${isUp ? '+' : ''}${holding.gainLossPct.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        holding.developmentName ?? holding.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AppColors.white,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            LucideIcons.mapPin,
                            size: 12,
                            color: AppColors.slate400,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              holding.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.slate400),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        holding.formattedCurrentValue,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AppColors.gold,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Invested ${holding.formattedCostBasis}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.slate500,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Cost ${holding.formattedCostBasis}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.slate500,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: AppColors.neutral800,
        child: const Center(
          child: Icon(LucideIcons.building2, color: AppColors.slate500),
        ),
      );
}

class _HoldingListTile extends StatelessWidget {
  const _HoldingListTile({required this.holding, required this.onTap});

  final InvestorHolding holding;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isUp = holding.gainLossPct >= 0;

    return InvestorPortalCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 64,
                height: 64,
                child: holding.imageUrl != null
                    ? MediaDeliveryImage(
                        url: holding.imageUrl!,
                        fit: BoxFit.cover,
                        thumbnail: true,
                        errorWidget: Container(
                          color: AppColors.gold.withValues(alpha: 0.12),
                          child: const Icon(
                            LucideIcons.building2,
                            color: AppColors.gold,
                          ),
                        ),
                      )
                    : Container(
                          color: AppColors.gold.withValues(alpha: 0.12),
                          child: const Icon(
                            LucideIcons.building2,
                            color: AppColors.gold,
                          ),
                        ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    holding.developmentName ?? holding.label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    holding.subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.slate400,
                        ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  holding.formattedCurrentValue,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${isUp ? '+' : ''}${holding.gainLossPct.toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: isUp ? AppColors.success : AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(width: 6),
            const Icon(
              LucideIcons.chevronRight,
              size: 16,
              color: AppColors.slate500,
            ),
          ],
        ),
      ),
    );
  }
}
