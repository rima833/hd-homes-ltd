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

/// Investment detail workspace — sections backed by Supabase holding + related rows.
class InvestorPortfolioDetailPage extends ConsumerStatefulWidget {
  const InvestorPortfolioDetailPage({super.key, required this.detail});

  final InvestorHoldingDetail detail;

  @override
  ConsumerState<InvestorPortfolioDetailPage> createState() =>
      _InvestorPortfolioDetailPageState();
}

class _InvestorPortfolioDetailPageState
    extends ConsumerState<InvestorPortfolioDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  static const _tabLabels = [
    'Overview',
    'Financials',
    'Payments',
    'Construction',
    'Documents',
    'Distributions',
    'Activity',
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _tabLabels.length, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  EdgeInsets _padding(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return EdgeInsets.all(w >= AppBreakpoints.tablet ? 24 : 16);
  }

  Future<void> _refresh() async {
    final id = widget.detail.holding.id;
    ref.invalidate(investorHoldingDetailProvider(id));
    ref.invalidate(investorHoldingsProvider);
    await ref.read(investorHoldingDetailProvider(id).future);
  }

  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;
    final holding = detail.holding;
    final isUp = holding.gainLossPct >= 0;
    final pad = _padding(context);
    final isWide = MediaQuery.sizeOf(context).width >= AppBreakpoints.tablet;
    final fmt = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: _refresh,
      child: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: pad.copyWith(bottom: 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Back to portfolio',
                        onPressed: () =>
                            context.go(RoutePaths.investorPortfolio),
                        icon: const Icon(LucideIcons.arrowLeft),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Investment detail',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: AppColors.slate400,
                                  ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () =>
                            context.go(RoutePaths.investorMessages),
                        icon: const Icon(LucideIcons.messageSquare, size: 16),
                        label: const Text('Message'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.gold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: AppRadius.cardBorder,
                    child: AspectRatio(
                      aspectRatio: isWide ? 21 / 9 : 16 / 9,
                      child: holding.imageUrl != null
                          ? MediaDeliveryImage(
                              url: holding.imageUrl!,
                              fit: BoxFit.cover,
                              errorWidget: _galleryFallback(),
                            )
                          : _galleryFallback(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    holding.developmentName ?? holding.label,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      if (holding.buildingLabel != null)
                        _MetaChip(label: holding.buildingLabel!),
                      if (holding.unitLabel != null)
                        _MetaChip(label: holding.unitLabel!),
                      if (holding.location != null)
                        _MetaChip(
                          label: holding.location!,
                          icon: LucideIcons.mapPin,
                        ),
                      if (holding.ownershipPct != null)
                        _MetaChip(
                          label:
                              '${holding.ownershipPct!.toStringAsFixed(holding.ownershipPct! == holding.ownershipPct!.roundToDouble() ? 0 : 1)}% ownership',
                          emphasized: true,
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text(
                        holding.formattedCurrentValue,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: AppColors.gold,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: (isUp ? AppColors.success : AppColors.error)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${isUp ? '+' : ''}${holding.gainLossPct.toStringAsFixed(1)}% ROI',
                          style: TextStyle(
                            color: isUp ? AppColors.success : AppColors.error,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              context.go(RoutePaths.investorPayments),
                          icon: const Icon(LucideIcons.creditCard, size: 18),
                          label: const Text('Make payment'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.gold,
                            side: const BorderSide(color: AppColors.gold),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () =>
                              context.go(RoutePaths.investorConstruction),
                          icon: const Icon(LucideIcons.hardHat, size: 18),
                          label: const Text('Site progress'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: AppColors.charcoal,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabs,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: AppColors.gold,
                labelColor: AppColors.gold,
                unselectedLabelColor: AppColors.slate400,
                tabs: [for (final t in _tabLabels) Tab(text: t)],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabs,
          children: [
            _OverviewTab(detail: detail, fmt: fmt),
            _FinancialsTab(detail: detail, fmt: fmt),
            _PaymentsTab(detail: detail, fmt: fmt),
            _ConstructionTab(detail: detail),
            _DocumentsTab(detail: detail, ref: ref),
            _DistributionsTab(detail: detail),
            _ActivityTab(detail: detail),
          ],
        ),
      ),
    );
  }

  Widget _galleryFallback() => Container(
        color: AppColors.neutral800,
        alignment: Alignment.center,
        child: const Icon(
          LucideIcons.building2,
          color: AppColors.slate500,
          size: 40,
        ),
      );
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate(this.tabBar);

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
    return ColoredBox(
      color: AppColors.deepBlack,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => false;
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.label,
    this.icon,
    this.emphasized = false,
  });

  final String label;
  final IconData? icon;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final color = emphasized ? AppColors.gold : AppColors.slate400;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: emphasized
            ? AppColors.gold.withValues(alpha: 0.12)
            : AppColors.darkSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.detail, required this.fmt});

  final InvestorHoldingDetail detail;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    final h = detail.holding;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        InvestorPortalCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Overview',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              _SpecRow(
                label: 'Development',
                value: h.developmentName ?? h.label,
              ),
              if (h.buildingLabel != null)
                _SpecRow(label: 'Building', value: h.buildingLabel!),
              if (h.unitLabel != null)
                _SpecRow(label: 'Unit', value: h.unitLabel!),
              _SpecRow(
                label: 'Units / shares',
                value: h.units.toStringAsFixed(
                  h.units == h.units.roundToDouble() ? 0 : 2,
                ),
              ),
              if (h.ownershipPct != null)
                _SpecRow(
                  label: 'Ownership',
                  value: '${h.ownershipPct!.toStringAsFixed(2)}%',
                ),
              _SpecRow(
                label: 'Purchase date',
                value: h.acquiredAt != null
                    ? DateFormat.yMMMd().format(h.acquiredAt!)
                    : '—',
              ),
              _SpecRow(
                label: 'Payment status',
                value: h.paymentStatus?.replaceAll('_', ' ') ??
                    (detail.amountOutstanding > 0
                        ? 'Attention'
                        : 'Current'),
              ),
              _SpecRow(
                label: 'Construction',
                value: h.constructionStatus?.replaceAll('_', ' ') ??
                    (detail.construction != null &&
                            detail.construction!.overallPercent > 0
                        ? '${detail.construction!.overallPercent.toStringAsFixed(0)}% complete'
                        : 'See Construction tab'),
              ),
              if (h.expectedCompletion != null)
                _SpecRow(
                  label: 'Expected completion',
                  value: DateFormat.yMMMd().format(h.expectedCompletion!),
                ),
              _SpecRow(label: 'Currency', value: h.currency),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: InvestorKpiCard(
                label: 'Invested',
                value: fmt.format(detail.amountInvested),
                icon: LucideIcons.landmark,
                accent: AppColors.info,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InvestorKpiCard(
                label: 'Current value',
                value: h.formattedCurrentValue,
                icon: LucideIcons.pieChart,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FinancialsTab extends StatelessWidget {
  const _FinancialsTab({required this.detail, required this.fmt});

  final InvestorHoldingDetail detail;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    final h = detail.holding;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        InvestorPortalCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Financials',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Values from Admin-maintained holding and distribution records.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.slate400,
                    ),
              ),
              const SizedBox(height: 12),
              _SpecRow(
                label: 'Original investment',
                value: fmt.format(detail.amountInvested),
              ),
              _SpecRow(
                label: 'Amount paid (book)',
                value: fmt.format(detail.amountInvested),
              ),
              _SpecRow(
                label: 'Outstanding intents',
                value: detail.amountOutstanding > 0
                    ? fmt.format(detail.amountOutstanding)
                    : '₦0',
              ),
              _SpecRow(
                label: 'Current valuation',
                value: h.formattedCurrentValue,
              ),
              _SpecRow(
                label: 'Appreciation',
                value:
                    '${h.gainLoss >= 0 ? '+' : ''}${fmt.format(h.gainLoss)}',
              ),
              _SpecRow(
                label: 'ROI',
                value: '${h.gainLossPct.toStringAsFixed(1)}%',
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => context.go(
                    '${RoutePaths.investorTools}?amount=${h.costBasis.toStringAsFixed(0)}',
                  ),
                  icon: const Icon(LucideIcons.calculator, size: 16),
                  label: const Text('Project future returns'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.gold),
                ),
              ),
              _SpecRow(
                label: 'Distributions paid',
                value: fmt.format(detail.distributionsPaid),
              ),
              _SpecRow(
                label: 'Distributions pending',
                value: fmt.format(detail.distributionsPending),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PaymentsTab extends StatelessWidget {
  const _PaymentsTab({required this.detail, required this.fmt});

  final InvestorHoldingDetail detail;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    final intents = detail.paymentIntents;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        InvestorPortalCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Payment activity',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Bank-transfer confirmations linked to this investment. Settlement is confirmed by Finance Admin only.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.slate400,
                    ),
              ),
              const SizedBox(height: 12),
              _SpecRow(
                label: 'Open outstanding',
                value: fmt.format(detail.amountOutstanding),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (intents.isEmpty)
          const InvestorEmptyState(
            title: 'No payment records yet',
            message:
                'Submitted bank transfers for this investment will appear here.',
            icon: LucideIcons.creditCard,
          )
        else
          InvestorPortalCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < intents.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      color: AppColors.neutral700.withValues(alpha: 0.4),
                    ),
                  ListTile(
                    title: Text(
                      intents[i].formattedAmount,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      '${intents[i].status.replaceAll('_', ' ')}'
                      '${intents[i].providerReference != null ? ' · ${intents[i].providerReference}' : ''}',
                      style: const TextStyle(color: AppColors.slate400),
                    ),
                    trailing: Text(
                      intents[i].createdAt != null
                          ? DateFormat.yMMMd().format(intents[i].createdAt!)
                          : '',
                      style: const TextStyle(
                        color: AppColors.slate500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => context.go(RoutePaths.investorPayments),
          icon: const Icon(LucideIcons.creditCard, size: 18),
          label: const Text('Go to payments'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.gold,
            foregroundColor: AppColors.charcoal,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }
}

class _ConstructionTab extends StatelessWidget {
  const _ConstructionTab({required this.detail});

  final InvestorHoldingDetail detail;

  @override
  Widget build(BuildContext context) {
    final c = detail.construction;
    final updates = c?.updates ?? const <InvestorConstructionUpdate>[];
    final milestones = c?.milestones ?? const <InvestorMilestone>[];
    final phases = c?.phases ?? const <InvestorConstructionPhase>[];
    final project = c?.primaryProject;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        InvestorPortalCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                project?.name ?? 'Construction progress',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              if (project?.currentPhase?.name != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Stage: ${project!.currentPhase!.name}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.gold,
                      ),
                ),
              ],
              const SizedBox(height: 12),
              InvestorProgressBar(
                label: 'Overall',
                percent: c?.overallPercent ?? 0,
              ),
              if (project?.targetEndDate != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Expected ${DateFormat.yMMM().format(project!.targetEndDate!)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.slate400,
                      ),
                ),
              ],
            ],
          ),
        ),
        if (phases.isNotEmpty) ...[
          const SizedBox(height: 16),
          const InvestorSectionHeader(title: 'Stages'),
          InvestorPortalCard(
            child: Column(
              children: [
                for (final p in phases)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InvestorProgressBar(
                      label: p.name,
                      percent: p.progressPct,
                      color: p.isComplete
                          ? AppColors.success
                          : p.isActive
                              ? AppColors.gold
                              : AppColors.slate500,
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (milestones.isNotEmpty) ...[
          const InvestorSectionHeader(title: 'Milestones'),
          InvestorPortalCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final m in milestones.take(8))
                  ListTile(
                    leading: Icon(
                      m.status == 'completed' || m.completedAt != null
                          ? LucideIcons.checkCircle2
                          : LucideIcons.circle,
                      color: m.status == 'completed' || m.completedAt != null
                          ? AppColors.success
                          : AppColors.slate500,
                      size: 20,
                    ),
                    title: Text(
                      m.name,
                      style: const TextStyle(color: AppColors.white),
                    ),
                    subtitle: Text(
                      m.status.replaceAll('_', ' '),
                      style: const TextStyle(color: AppColors.slate400),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        const InvestorSectionHeader(title: 'Latest updates'),
        if (updates.isEmpty)
          const InvestorEmptyState(
            title: 'No construction updates',
            message:
                'Published site updates for this property will appear here in real time.',
            icon: LucideIcons.hardHat,
          )
        else
          ...updates.take(5).map(
                (u) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InvestorPortalCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          u.title,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: AppColors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        if (u.phaseName != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            u.phaseName!,
                            style: const TextStyle(
                              color: AppColors.gold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        if (u.photos.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 72,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: u.photos.length.clamp(0, 6),
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (_, i) => ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: MediaDeliveryImage(
                                  url: u.photos[i],
                                  width: 96,
                                  height: 72,
                                  fit: BoxFit.cover,
                                  thumbnail: true,
                                ),
                              ),
                            ),
                          ),
                        ],
                        if (u.videos.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            '${u.videos.length} video${u.videos.length == 1 ? '' : 's'}',
                            style: const TextStyle(
                              color: AppColors.slate400,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => context.go(RoutePaths.investorConstruction),
          icon: const Icon(LucideIcons.hardHat, size: 16),
          label: const Text('Open construction hub'),
        ),
      ],
    );
  }
}

class _DocumentsTab extends StatelessWidget {
  const _DocumentsTab({required this.detail, required this.ref});

  final InvestorHoldingDetail detail;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final docs = detail.documents;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (docs.isEmpty)
          InvestorEmptyState(
            title: 'No documents for this investment',
            message:
                'Contracts, receipts, and statements uploaded by Admin will appear here.',
            icon: LucideIcons.fileText,
            action: TextButton(
              onPressed: () => context.go(RoutePaths.investorDocuments),
              child: const Text(
                'Open document vault',
                style: TextStyle(color: AppColors.gold),
              ),
            ),
          )
        else
          InvestorPortalCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < docs.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      color: AppColors.neutral700.withValues(alpha: 0.4),
                    ),
                  ListTile(
                    leading: const Icon(
                      LucideIcons.fileText,
                      color: AppColors.gold,
                    ),
                    title: Text(
                      docs[i].title,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      [
                        docs[i].documentType ?? 'document',
                        'v${docs[i].version}',
                        if (docs[i].createdAt != null)
                          DateFormat.yMMMd().format(docs[i].createdAt!),
                      ].join(' · '),
                      style: const TextStyle(color: AppColors.slate400),
                    ),
                    trailing: const Icon(
                      LucideIcons.chevronRight,
                      color: AppColors.slate500,
                      size: 18,
                    ),
                    onTap: () => context.go(RoutePaths.investorDocuments),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _DistributionsTab extends StatelessWidget {
  const _DistributionsTab({required this.detail});

  final InvestorHoldingDetail detail;

  @override
  Widget build(BuildContext context) {
    final items = detail.distributions;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (items.isEmpty)
          const InvestorEmptyState(
            title: 'No distributions yet',
            message:
                'When Admin schedules or pays distributions for this investment, they will show here.',
            icon: LucideIcons.banknote,
          )
        else
          InvestorPortalCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      color: AppColors.neutral700.withValues(alpha: 0.4),
                    ),
                  ListTile(
                    title: Text(
                      items[i].formattedAmount,
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      '${items[i].distributionType.replaceAll('_', ' ')} · ${items[i].status}',
                      style: const TextStyle(color: AppColors.slate400),
                    ),
                    trailing: Text(
                      items[i].paidAt != null
                          ? DateFormat.yMMMd().format(items[i].paidAt!)
                          : items[i].scheduledAt != null
                              ? DateFormat.yMMMd().format(items[i].scheduledAt!)
                              : '',
                      style: const TextStyle(
                        color: AppColors.slate500,
                        fontSize: 12,
                      ),
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

class _ActivityTab extends StatelessWidget {
  const _ActivityTab({required this.detail});

  final InvestorHoldingDetail detail;

  @override
  Widget build(BuildContext context) {
    final events = detail.activity;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (events.isEmpty)
          const InvestorEmptyState(
            title: 'No activity yet',
            message: 'Investment events will stream here as they happen.',
            icon: LucideIcons.activity,
          )
        else
          InvestorPortalCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < events.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      color: AppColors.neutral700.withValues(alpha: 0.4),
                    ),
                  ListTile(
                    title: Text(
                      events[i].title,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      [
                        if (events[i].description != null) events[i].description!,
                        DateFormat.yMMMd().add_jm().format(events[i].occurredAt),
                      ].join('\n'),
                      style: const TextStyle(color: AppColors.slate400),
                    ),
                    isThreeLine: events[i].description != null,
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _SpecRow extends StatelessWidget {
  const _SpecRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.slate400,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class InvestorPortfolioDetailLoader extends ConsumerWidget {
  const InvestorPortfolioDetailLoader({super.key, required this.holdingId});

  final String holdingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(investorHoldingDetailProvider(holdingId));
    return detailAsync.when(
      loading: () => const InvestorPageSkeleton(showKpis: false, rows: 4),
      error: (e, _) => InvestorErrorView(
        message: e,
        onRetry: () =>
            ref.invalidate(investorHoldingDetailProvider(holdingId)),
      ),
      data: (detail) {
        if (detail == null) {
          return InvestorEmptyState(
            title: 'Holding not found',
            message: 'This position may have been removed or is unavailable.',
            icon: LucideIcons.briefcase,
            action: FilledButton(
              onPressed: () => context.go(RoutePaths.investorPortfolio),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.charcoal,
              ),
              child: const Text('Back to portfolio'),
            ),
          );
        }
        return InvestorPortfolioDetailPage(detail: detail);
      },
    );
  }
}
