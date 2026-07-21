import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/biadw/domain/entities/biadw_models.dart';
import 'package:hdhomesproject/features/biadw/domain/services/biadw_service.dart';
import 'package:hdhomesproject/features/biadw/presentation/providers/biadw_controller.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Volume 4 Part 16 — BI Command Center (BIADW).
class BiCommandCenterPage extends ConsumerWidget {
  const BiCommandCenterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSnap = ref.watch(biadwSnapshotProvider);
    final ui = ref.watch(biadwControllerProvider);
    final controller = ref.read(biadwControllerProvider.notifier);

    return Scaffold(
      body: asyncSnap.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Failed to load BI Command Center: $e'),
        ),
        data: (snap) {
          final tickerKpis = snap.kpis;
          final ticker = tickerKpis.isEmpty
              ? 'BI Command Center live'
              : '${tickerKpis[ui.tickerIndex % tickerKpis.length].label}: '
                  '${tickerKpis[ui.tickerIndex % tickerKpis.length].displayValue}';

          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: CustomScrollView(
              slivers: [
                ContainedPadding(
                  child: _BiadwHeader(
                    ticker: ticker,
                    fromRemote: snap.fromRemote,
                    onRefresh: controller.refresh,
                    onOpenAi: () => controller.setTab(BiadwCommandTab.ai),
                    onOpenEtl: () => controller.setTab(BiadwCommandTab.etl),
                  ),
                ),
                if (ui.lastMessage != null)
                  ContainedPadding(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Material(
                        color: AppColors.gold.withValues(alpha: 0.15),
                        borderRadius: AppRadius.cardBorder,
                        child: ListTile(
                          leading: const Icon(
                            LucideIcons.info,
                            color: AppColors.gold,
                          ),
                          title: Text(ui.lastMessage!),
                          dense: true,
                          trailing: IconButton(
                            icon: const Icon(LucideIcons.x, size: 16),
                            onPressed: controller.clearMessage,
                          ),
                        ),
                      ),
                    ),
                  ),
                ContainedPadding(child: _KpiStrip(kpis: snap.kpis)),
                ContainedPadding(
                  child: _EnterpriseFeatureStrip(onSelect: controller.setTab),
                ),
                ContainedPadding(
                  child: _SearchAndFilters(
                    ui: ui,
                    onSearch: controller.setSearch,
                    onStatus: controller.setStatusFilter,
                  ),
                ),
                ContainedPadding(
                  child: _TabBar(
                    selected: ui.selectedTab,
                    onSelect: controller.setTab,
                  ),
                ),
                ..._tabSlivers(context, ref, snap, ui, controller),
                const ContainedPadding(child: SizedBox(height: 32)),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _tabSlivers(
    BuildContext context,
    WidgetRef ref,
    BiadwCommandCenterSnapshot snap,
    BiadwUiState ui,
    BiadwController controller,
  ) {
    switch (ui.selectedTab) {
      case BiadwCommandTab.overview:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Enterprise Intelligence Hub™',
              icon: LucideIcons.layoutDashboard,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Warehouse · ETL · KPIs · Dashboards · Forecasts · Quality',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Divider(height: 24),
                  _ActivityList(activities: snap.activities),
                ],
              ),
            ),
          ),
          ContainedPadding(
            child: _SectionCard(
              title: 'Watch items',
              icon: LucideIcons.alertTriangle,
              child: _QualityList(
                items: snap.qualityIssues.where((q) => q.isOpen).toList(),
              ),
            ),
          ),
          ContainedPadding(
            child: _SectionCard(
              title: 'Recent ETL',
              icon: LucideIcons.workflow,
              child: _EtlList(items: snap.etlJobs),
            ),
          ),
        ];
      case BiadwCommandTab.warehouse:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Data sources',
              icon: LucideIcons.database,
              child: _SourceList(items: snap.dataSources),
            ),
          ),
          ContainedPadding(
            child: _SectionCard(
              title: 'Datasets & marts',
              icon: LucideIcons.table,
              child: _DatasetList(items: snap.datasets),
            ),
          ),
        ];
      case BiadwCommandTab.etl:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'ETL pipelines',
              icon: LucideIcons.workflow,
              child: _EtlList(items: controller.filteredEtlJobs(snap)),
            ),
          ),
        ];
      case BiadwCommandTab.kpis:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Analytics KPIs',
              icon: LucideIcons.gauge,
              child: _KpiDetailList(items: snap.kpis),
            ),
          ),
        ];
      case BiadwCommandTab.dashboards:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Analytics dashboards',
              icon: LucideIcons.barChart3,
              child: _DashboardList(
                items: controller.filteredDashboards(snap),
              ),
            ),
          ),
        ];
      case BiadwCommandTab.reports:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Analytics reports',
              icon: LucideIcons.fileText,
              child: _ReportList(items: controller.filteredReports(snap)),
            ),
          ),
        ];
      case BiadwCommandTab.forecasts:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Enterprise Forecast Engine™',
              icon: LucideIcons.trendingUp,
              child: _ForecastList(items: snap.forecasts),
            ),
          ),
        ];
      case BiadwCommandTab.scorecards:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Board & Executive Intelligence Center™',
              icon: LucideIcons.award,
              child: _ScorecardList(items: snap.scorecards),
            ),
          ),
        ];
      case BiadwCommandTab.quality:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Data Quality & Governance Center™',
              icon: LucideIcons.shieldCheck,
              child: _QualityList(items: controller.filteredQuality(snap)),
            ),
          ),
        ];
      case BiadwCommandTab.governance:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Data catalog',
              icon: LucideIcons.bookOpen,
              child: _CatalogList(items: snap.catalog),
            ),
          ),
          ContainedPadding(
            child: _SectionCard(
              title: 'Lineage',
              icon: LucideIcons.gitBranch,
              child: _LineageList(items: snap.lineage),
            ),
          ),
        ];
      case BiadwCommandTab.analytics:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Live BI signals',
              icon: LucideIcons.radar,
              child: _SignalList(signals: BiadwService.detectBiSignals(snap)),
            ),
          ),
          ContainedPadding(
            child: _SectionCard(
              title: 'Published reports',
              icon: LucideIcons.fileBarChart,
              child: _ReportList(items: snap.reports),
            ),
          ),
        ];
      case BiadwCommandTab.ai:
        final service = ref.read(biadwServiceProvider);
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'AI Executive Briefing™',
              icon: LucideIcons.sparkles,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.generateExecutiveBriefing(snap),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snap.aiDisclaimer,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.gold,
                        ),
                  ),
                  const Divider(height: 24),
                  _AiList(items: snap.aiInsights),
                ],
              ),
            ),
          ),
        ];
    }
  }
}

class ContainedPadding extends StatelessWidget {
  const ContainedPadding({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(child: child);
}

class _BiadwHeader extends StatelessWidget {
  const _BiadwHeader({
    required this.ticker,
    required this.fromRemote,
    required this.onRefresh,
    required this.onOpenAi,
    required this.onOpenEtl,
  });

  final String ticker;
  final bool fromRemote;
  final VoidCallback onRefresh;
  final VoidCallback onOpenAi;
  final VoidCallback onOpenEtl;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.deepBlack,
            AppColors.charcoal.withValues(alpha: 0.95),
          ],
        ),
        borderRadius: AppRadius.cardBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 640;
              final title = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BI Command Center',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fromRemote ? 'Live · Supabase' : 'Demo dataset',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.gold,
                        ),
                  ),
                ],
              );
              final actions = Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: onOpenAi,
                    icon: const Icon(LucideIcons.sparkles, size: 16),
                    label: const Text('BI AI'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.deepBlack,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: onOpenEtl,
                    icon: const Icon(LucideIcons.workflow, size: 16),
                    label: const Text('ETL'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.white,
                      side: BorderSide(
                        color: AppColors.gold.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onRefresh,
                    icon: const Icon(
                      LucideIcons.refreshCw,
                      color: AppColors.white,
                    ),
                    tooltip: 'Refresh',
                  ),
                ],
              );
              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [title, const SizedBox(height: 12), actions],
                );
              }
              return Row(
                children: [
                  Expanded(child: title),
                  actions,
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Business Intelligence · Analytics · Data Warehouse',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.white.withValues(alpha: 0.7),
                ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(LucideIcons.activity, size: 14, color: AppColors.gold),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  ticker,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.gold,
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EnterpriseFeatureStrip extends StatelessWidget {
  const _EnterpriseFeatureStrip({required this.onSelect});

  final void Function(BiadwCommandTab) onSelect;

  @override
  Widget build(BuildContext context) {
    final items = [
      (BiadwCommandTab.overview, 'Intelligence Hub™', LucideIcons.layoutDashboard),
      (BiadwCommandTab.ai, 'AI Briefing™', LucideIcons.sparkles),
      (BiadwCommandTab.forecasts, 'Forecast Engine™', LucideIcons.trendingUp),
      (BiadwCommandTab.quality, 'Quality Center™', LucideIcons.shieldCheck),
      (BiadwCommandTab.scorecards, 'Board Intelligence™', LucideIcons.award),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items
            .map(
              (e) => ActionChip(
                avatar: Icon(e.$3, size: 16),
                label: Text(e.$2),
                onPressed: () => onSelect(e.$1),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _KpiStrip extends StatelessWidget {
  const _KpiStrip({required this.kpis});

  final List<BiadwKpi> kpis;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SizedBox(
        height: 96,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: kpis.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (context, i) {
            final k = kpis[i];
            return Container(
              width: 148,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: AppRadius.cardBorder,
                border: Border.all(
                  color: AppColors.charcoal.withValues(alpha: 0.08),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    k.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const Spacer(),
                  Text(
                    k.displayValue,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: k.status == 'watch' || k.status == 'critical'
                              ? AppColors.gold
                              : AppColors.charcoal,
                        ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SearchAndFilters extends StatelessWidget {
  const _SearchAndFilters({
    required this.ui,
    required this.onSearch,
    required this.onStatus,
  });

  final BiadwUiState ui;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onStatus;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Search ETL, dashboards, reports, quality…',
              prefixIcon: const Icon(LucideIcons.search, size: 18),
              border: OutlineInputBorder(borderRadius: AppRadius.cardBorder),
              isDense: true,
            ),
            onChanged: onSearch,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: ui.statusFilter == null,
                  onSelected: (_) => onStatus(null),
                ),
                FilterChip(
                  label: const Text('Failed'),
                  selected: ui.statusFilter == 'failed',
                  onSelected: (_) => onStatus('failed'),
                ),
                FilterChip(
                  label: const Text('Open'),
                  selected: ui.statusFilter == 'open',
                  onSelected: (_) => onStatus('open'),
                ),
                FilterChip(
                  label: const Text('Published'),
                  selected: ui.statusFilter == 'published',
                  onSelected: (_) => onStatus('published'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.selected, required this.onSelect});

  final BiadwCommandTab selected;
  final void Function(BiadwCommandTab) onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: BiadwCommandTab.values
              .map(
                (t) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(t.label),
                    selected: selected == t,
                    onSelected: (_) => onSelect(t),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: AppRadius.cardBorder,
          border: Border.all(color: AppColors.charcoal.withValues(alpha: 0.08)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: AppColors.gold),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityList extends StatelessWidget {
  const _ActivityList({required this.activities});

  final List<BiadwActivity> activities;

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return const Text('No recent activity');
    }
    return Column(
      children: activities
          .map(
            (a) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(LucideIcons.activity, size: 16),
              title: Text(a.summary),
              subtitle: Text(a.actorLabel ?? a.action),
            ),
          )
          .toList(),
    );
  }
}

class _SourceList extends StatelessWidget {
  const _SourceList({required this.items});

  final List<BiadwDataSource> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (s) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(s.name),
              subtitle: Text(
                '${s.code ?? ''} · ${s.sourceModule} · ${s.status}',
              ),
            ),
          )
          .toList(),
    );
  }
}

class _DatasetList extends StatelessWidget {
  const _DatasetList({required this.items});

  final List<BiadwDataset> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (d) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(d.name),
              subtitle: Text(
                '${d.code ?? ''} · ${d.grainLabel ?? d.datasetType} · ~${d.rowEstimate} rows',
              ),
            ),
          )
          .toList(),
    );
  }
}

class _EtlList extends StatelessWidget {
  const _EtlList({required this.items});

  final List<BiadwEtlJob> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('No ETL jobs');
    return Column(
      children: items
          .map(
            (j) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(
                j.isFailed ? LucideIcons.xCircle : LucideIcons.checkCircle,
                size: 16,
                color: j.isFailed ? AppColors.gold : AppColors.charcoal,
              ),
              title: Text(j.name),
              subtitle: Text('${j.code ?? ''} · ${j.status} · ${j.summary ?? ''}'),
            ),
          )
          .toList(),
    );
  }
}

class _KpiDetailList extends StatelessWidget {
  const _KpiDetailList({required this.items});

  final List<BiadwKpi> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (k) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text('${k.label}: ${k.displayValue}'),
              subtitle: Text(
                '${k.code ?? ''} · ${k.status}'
                '${k.changePct != null ? ' · Δ ${k.changePct!.toStringAsFixed(1)}%' : ''}',
              ),
            ),
          )
          .toList(),
    );
  }
}

class _DashboardList extends StatelessWidget {
  const _DashboardList({required this.items});

  final List<BiadwDashboard> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('No dashboards');
    return Column(
      children: items
          .map(
            (d) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(d.title),
              subtitle: Text(
                '${d.code ?? ''} · ${d.audience} · ${d.status}',
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ReportList extends StatelessWidget {
  const _ReportList({required this.items});

  final List<BiadwReport> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('No reports');
    return Column(
      children: items
          .map(
            (r) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(r.title),
              subtitle: Text(
                '${r.periodLabel ?? ''} · ${r.status} · ${r.summary ?? ''}',
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ForecastList extends StatelessWidget {
  const _ForecastList({required this.items});

  final List<BiadwForecast> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (f) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text('${f.title}: ${f.displayValue}'),
              subtitle: Text(
                '${f.horizonLabel ?? ''} · confidence ${f.confidencePct.toStringAsFixed(0)}% · ${f.summary ?? ''}',
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ScorecardList extends StatelessWidget {
  const _ScorecardList({required this.items});

  final List<BiadwScorecard> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (s) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                '${s.title} — ${s.overallScore.toStringAsFixed(1)}',
              ),
              subtitle: Text(
                '${s.audience.toUpperCase()} · ${s.periodLabel ?? ''} · ${s.summary ?? ''}',
              ),
            ),
          )
          .toList(),
    );
  }
}

class _QualityList extends StatelessWidget {
  const _QualityList({required this.items});

  final List<BiadwQualityIssue> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('No quality issues');
    return Column(
      children: items
          .map(
            (q) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(
                LucideIcons.alertCircle,
                size: 16,
                color: q.severity == 'critical' ? AppColors.gold : null,
              ),
              title: Text(q.title),
              subtitle: Text(
                '${q.code ?? ''} · ${q.severity}/${q.status} · ${q.datasetLabel ?? ''}',
              ),
            ),
          )
          .toList(),
    );
  }
}

class _CatalogList extends StatelessWidget {
  const _CatalogList({required this.items});

  final List<BiadwCatalogEntry> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (c) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(c.title),
              subtitle: Text('${c.catalogType} · ${c.ownerLabel ?? ''}'),
            ),
          )
          .toList(),
    );
  }
}

class _LineageList extends StatelessWidget {
  const _LineageList({required this.items});

  final List<BiadwLineageEdge> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (l) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text('${l.sourceLabel} → ${l.targetLabel}'),
              subtitle: Text('${l.lineageType} · ${l.summary ?? ''}'),
            ),
          )
          .toList(),
    );
  }
}

class _SignalList extends StatelessWidget {
  const _SignalList({required this.signals});

  final List<String> signals;

  @override
  Widget build(BuildContext context) {
    if (signals.isEmpty) return const Text('No active signals');
    return Column(
      children: signals
          .map(
            (s) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(LucideIcons.radio, size: 16),
              title: Text(s),
            ),
          )
          .toList(),
    );
  }
}

class _AiList extends StatelessWidget {
  const _AiList({required this.items});

  final List<BiadwAiInsight> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (a) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(a.title),
              subtitle: Text(
                '${a.body}\n${a.disclaimer}'
                '${a.confidencePct != null ? ' · ${a.confidencePct!.toStringAsFixed(0)}%' : ''}',
              ),
              isThreeLine: true,
            ),
          )
          .toList(),
    );
  }
}
