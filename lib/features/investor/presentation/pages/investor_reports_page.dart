import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/export/export_engine.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/offline_updates_note.dart';
import 'package:hdhomesproject/features/investor/domain/entities/investor_models.dart';
import 'package:hdhomesproject/features/investor/presentation/providers/investor_portal_realtime_provider.dart';
import 'package:hdhomesproject/features/investor/presentation/providers/investor_providers.dart';
import 'package:hdhomesproject/features/investor/presentation/widgets/investor_portal_widgets.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

class InvestorReportsPage extends ConsumerStatefulWidget {
  const InvestorReportsPage({super.key});

  @override
  ConsumerState<InvestorReportsPage> createState() =>
      _InvestorReportsPageState();
}

class _InvestorReportsPageState extends ConsumerState<InvestorReportsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
    ref.invalidate(investorReportsProvider);
    ref.invalidate(investorHoldingsProvider);
    ref.invalidate(investorPaymentsProvider);
    await ref.read(investorReportsProvider.future);
  }

  Future<void> _openUrl(String? url) async {
    if (url == null || url.isEmpty) {
      if (!mounted) return;
      showFriendlyError(
        context,
        null,
        fallback: 'This file is not available yet.',
      );
      return;
    }
    try {
      final safeUrl =
          await ref.read(investorServiceProvider).resolveDocumentUrl(url);
      final uri = Uri.tryParse(safeUrl);
      if (uri == null) {
        throw const NetworkException('This file link is invalid.');
      }
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (mounted) {
        showFriendlyError(
          context,
          null,
          fallback: 'Unable to open this file right now.',
        );
      }
    } catch (e) {
      if (mounted) {
        showFriendlyError(
          context,
          e,
          fallback: 'Unable to open this file right now.',
        );
      }
    }
  }

  Future<void> _export(String format) async {
    setState(() => _exporting = true);
    try {
      final record = await ref.read(investorRecordProvider.future);
      final holdings = await ref.read(investorHoldingsProvider.future);
      final payments = await ref.read(investorPaymentsProvider.future);
      if (record == null) {
        throw StateError('Investor account not found');
      }

      final holdingRows = holdings
          .map(
            (h) => ExportHoldingRow(
              label: h.label,
              costBasis: h.costBasis,
              currentValue: h.currentValue,
              roiPct: h.gainLossPct,
              units: h.units,
            ),
          )
          .toList();
      final distRows = payments.distributions
          .take(20)
          .map(
            (d) => ExportDistributionRow(
              type: d.distributionType,
              status: d.status,
              amount: d.amount,
              date: d.paidAt ?? d.scheduledAt,
            ),
          )
          .toList();

      final portfolioValue =
          holdings.fold<double>(0, (s, h) => s + h.currentValue);
      final totalCost = holdings.fold<double>(0, (s, h) => s + h.costBasis);

      switch (format) {
        case 'pdf':
          final bytes = await ExportEngine.buildPortfolioPdf(
            investorName: record.fullName ?? 'Investor',
            investorCode: record.investorCode ?? record.id,
            portfolioValue: portfolioValue,
            totalCost: totalCost,
            unrealizedGain: portfolioValue - totalCost,
            holdings: holdingRows,
            distributions: distRows,
          );
          await ExportEngine.sharePdf(
            filename: 'hdhomes-portfolio-report',
            bytes: bytes,
          );
        case 'excel':
          final bytes = ExportEngine.buildPortfolioExcel(
            investorName: record.fullName ?? 'Investor',
            investorCode: record.investorCode ?? record.id,
            holdings: holdingRows,
            distributions: distRows,
          );
          await ExportEngine.shareExcel(
            filename: 'hdhomes-portfolio-report',
            bytes: bytes,
          );
        case 'csv':
          await ExportEngine.shareCsv(
            filename: 'hdhomes-holdings',
            csv: ExportEngine.buildPortfolioCsv(holdings: holdingRows),
          );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${format.toUpperCase()} export ready to share'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showFriendlyError(
          context,
          e,
          fallback: 'Export failed. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportsAsync = ref.watch(investorReportsProvider);
    final connection = ref.watch(investorRealtimeConnectionProvider);
    final live = connection == InvestorRealtimeConnection.live;
    final pad = _padding(context);

    return reportsAsync.when(
      loading: () => const InvestorDashboardSkeleton(),
      error: (e, _) => InvestorErrorView(
        message: e,
        onRetry: _refresh,
      ),
      data: (bundle) {
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
                                        'Reports & Statements',
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
                                        'Generate live portfolio exports or open filed reports and statements.',
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
                                _ReportsLiveChip(
                                  live: live,
                                  connection: connection,
                                ),
                                const SizedBox(width: 8),
                                if (_exporting)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 8),
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.gold,
                                      ),
                                    ),
                                  )
                                else
                                  PopupMenuButton<String>(
                                    tooltip: 'Generate export',
                                    onSelected: _export,
                                    color: AppColors.charcoal,
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(
                                        value: 'pdf',
                                        child: Text('Generate PDF'),
                                      ),
                                      PopupMenuItem(
                                        value: 'excel',
                                        child: Text('Generate Excel'),
                                      ),
                                      PopupMenuItem(
                                        value: 'csv',
                                        child: Text('Generate CSV'),
                                      ),
                                    ],
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.gold,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            LucideIcons.download,
                                            size: 16,
                                            color: AppColors.charcoal,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Export',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelLarge
                                                ?.copyWith(
                                                  color: AppColors.charcoal,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _ExportQuickActions(
                              exporting: _exporting,
                              onExport: _export,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: InvestorKpiCard(
                                    label: 'Filed reports',
                                    value: '${bundle.reports.length}',
                                    icon: LucideIcons.fileBarChart,
                                    subtitle: 'Published',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: InvestorKpiCard(
                                    label: 'Statements',
                                    value: '${bundle.statements.length}',
                                    icon: LucideIcons.receipt,
                                    accent: AppColors.info,
                                    subtitle: 'On file',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _ReportsTabBarDelegate(
                        TabBar(
                          controller: _tabController,
                          indicatorColor: AppColors.gold,
                          labelColor: AppColors.gold,
                          unselectedLabelColor: AppColors.slate400,
                          tabs: [
                            Tab(
                              text: 'Reports (${bundle.reports.length})',
                            ),
                            Tab(
                              text: 'Statements (${bundle.statements.length})',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  body: TabBarView(
                    controller: _tabController,
                    children: [
                      _ReportsList(
                        reports: bundle.reports,
                        onOpen: _openUrl,
                        onGeneratePdf: () => _export('pdf'),
                        exporting: _exporting,
                      ),
                      _StatementsList(
                        statements: bundle.statements,
                        onOpen: _openUrl,
                      ),
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

class _ExportQuickActions extends StatelessWidget {
  const _ExportQuickActions({
    required this.exporting,
    required this.onExport,
  });

  final bool exporting;
  final Future<void> Function(String format) onExport;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ExportChip(
            label: 'PDF',
            icon: LucideIcons.fileText,
            enabled: !exporting,
            onTap: () => onExport('pdf'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ExportChip(
            label: 'Excel',
            icon: LucideIcons.fileSpreadsheet,
            enabled: !exporting,
            onTap: () => onExport('excel'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ExportChip(
            label: 'CSV',
            icon: LucideIcons.table,
            enabled: !exporting,
            onTap: () => onExport('csv'),
          ),
        ),
      ],
    );
  }
}

class _ExportChip extends StatelessWidget {
  const _ExportChip({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.darkSurface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.gold.withValues(alpha: 0.28),
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: AppColors.gold, size: 18),
              const SizedBox(height: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportsTabBarDelegate extends SliverPersistentHeaderDelegate {
  _ReportsTabBarDelegate(this.tabBar);

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
  bool shouldRebuild(covariant _ReportsTabBarDelegate oldDelegate) =>
      tabBar != oldDelegate.tabBar;
}

class _ReportsList extends StatelessWidget {
  const _ReportsList({
    required this.reports,
    required this.onOpen,
    required this.onGeneratePdf,
    required this.exporting,
  });

  final List<InvestorReport> reports;
  final Future<void> Function(String?) onOpen;
  final VoidCallback onGeneratePdf;
  final bool exporting;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        InvestorPortalCard(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  LucideIcons.filePlus,
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
                      'Generate live portfolio report',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'PDF · Excel · CSV from your current holdings & distributions',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.slate400,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: exporting ? null : onGeneratePdf,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.charcoal,
                ),
                child: const Text('PDF'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (reports.isEmpty)
          const InvestorEmptyState(
            title: 'No filed reports yet',
            message:
                'Use Export above to generate a live report anytime. Staff-published reports will also appear here.',
            icon: LucideIcons.fileBarChart,
          )
        else
          ...reports.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InvestorPortalCard(
                onTap: r.fileUrl != null ? () => onOpen(r.fileUrl) : null,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        LucideIcons.fileBarChart,
                        color: AppColors.gold,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            [
                              if (r.reportType != null) r.reportType!,
                              if (r.periodLabel != null) r.periodLabel!,
                              if (r.generatedAt != null)
                                DateFormat.yMMMd().format(r.generatedAt!),
                            ].join(' · '),
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.slate400,
                                    ),
                          ),
                        ],
                      ),
                    ),
                    if (r.fileUrl != null)
                      IconButton(
                        tooltip: 'Open report',
                        icon: const Icon(
                          LucideIcons.externalLink,
                          size: 18,
                          color: AppColors.gold,
                        ),
                        onPressed: () => onOpen(r.fileUrl),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _StatementsList extends StatelessWidget {
  const _StatementsList({
    required this.statements,
    required this.onOpen,
  });

  final List<InvestorStatement> statements;
  final Future<void> Function(String?) onOpen;

  @override
  Widget build(BuildContext context) {
    if (statements.isEmpty) {
      return const InvestorEmptyState(
        title: 'No statements yet',
        message:
            'Period statements published by finance will appear here in real time.',
        icon: LucideIcons.receipt,
      );
    }

    final fmt = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: statements.length,
      itemBuilder: (context, i) {
        final s = statements[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InvestorPortalCard(
            onTap: s.fileUrl != null ? () => onOpen(s.fileUrl) : null,
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
                        s.periodLabel,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AppColors.white,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s.closingBalance != null
                            ? 'Closing ${fmt.format(s.closingBalance)}'
                            : 'Statement on file',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.slate400,
                            ),
                      ),
                    ],
                  ),
                ),
                if (s.fileUrl != null)
                  IconButton(
                    tooltip: 'Open statement',
                    icon: const Icon(
                      LucideIcons.externalLink,
                      size: 18,
                      color: AppColors.gold,
                    ),
                    onPressed: () => onOpen(s.fileUrl),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ReportsLiveChip extends StatelessWidget {
  const _ReportsLiveChip({required this.live, required this.connection});

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
