import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/eoc/domain/entities/eoc_models.dart';
import 'package:hdhomesproject/features/eoc/domain/services/eoc_service.dart';
import 'package:hdhomesproject/features/eoc/presentation/providers/eoc_controller.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Volume 4 Part 10 — Enterprise Mission Control™ / EOC Command Center.
class EocMissionControlPage extends ConsumerWidget {
  const EocMissionControlPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSnap = ref.watch(eocSnapshotProvider);
    final ui = ref.watch(eocControllerProvider);
    final controller = ref.read(eocControllerProvider.notifier);

    return Scaffold(
      body: asyncSnap.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Failed to load Enterprise Operations Center: $e'),
        ),
        data: (snap) {
          final tickerKpis = snap.kpis;
          final ticker = tickerKpis.isEmpty
              ? 'Mission Control live'
              : '${tickerKpis[ui.tickerIndex % tickerKpis.length].label}: '
                  '${tickerKpis[ui.tickerIndex % tickerKpis.length].displayValue}';

          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: CustomScrollView(
              slivers: [
                ContainedPadding(
                  child: _EocHeader(
                    ticker: ticker,
                    fromRemote: snap.fromRemote,
                    onRefresh: controller.refresh,
                    onOpenAi: () => controller.setTab(EocCommandTab.ai),
                    onOpenWorkflows: () =>
                        controller.setTab(EocCommandTab.workflows),
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
                  child: _EnterpriseFeatureStrip(
                    onSelect: controller.setTab,
                  ),
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
    EocMissionControlSnapshot snap,
    EocUiState ui,
    EocController controller,
  ) {
    switch (ui.selectedTab) {
      case EocCommandTab.overview:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Enterprise Mission Control™',
              icon: LucideIcons.radar,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cross-module command · alerts · approvals · automation',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Divider(height: 24),
                  _ModuleHealthGrid(modules: snap.moduleHealth),
                  const Divider(height: 24),
                  _ActivityList(activities: snap.activities),
                ],
              ),
            ),
          ),
          ContainedPadding(
            child: _SectionCard(
              title: 'Live Alerts',
              icon: LucideIcons.bell,
              child: _AlertList(alerts: snap.alerts.take(4).toList()),
            ),
          ),
          ContainedPadding(
            child: _SectionCard(
              title: 'Decision Intelligence stubs',
              icon: LucideIcons.scale,
              child: _DecisionList(items: snap.decisions),
            ),
          ),
        ];
      case EocCommandTab.kpis:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Enterprise KPIs',
              icon: LucideIcons.gauge,
              child: _KpiDetailList(kpis: snap.kpis),
            ),
          ),
          ContainedPadding(
            child: _SectionCard(
              title: 'Module Health',
              icon: LucideIcons.activity,
              child: _ModuleHealthGrid(modules: snap.moduleHealth),
            ),
          ),
        ];
      case EocCommandTab.search:
        final service = ref.read(eocServiceProvider);
        final hits = service.search(snap, ui.searchQuery);
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Universal Enterprise Search',
              icon: LucideIcons.search,
              child: _SearchHitList(hits: hits),
            ),
          ),
        ];
      case EocCommandTab.ai:
        final service = ref.read(eocServiceProvider);
        final briefing = service.generateEnterpriseBriefing(snap);
        final signals = EocService.detectOpsSignals(snap);
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'AI Enterprise Brain™',
              icon: LucideIcons.sparkles,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(briefing),
                  const SizedBox(height: 12),
                  Text(
                    snap.aiDisclaimer,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                  ),
                ],
              ),
            ),
          ),
          ContainedPadding(
            child: _SectionCard(
              title: 'Ops signals · advisory',
              icon: LucideIcons.brain,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...signals.map(
                    (s) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const Icon(LucideIcons.radar, size: 16),
                      title: Text(s),
                    ),
                  ),
                  const Divider(height: 24),
                  ...snap.aiInsights.map(
                    (i) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(i.title),
                      subtitle: Text(
                        '${i.body}\n'
                        '${i.editable ? 'Editable / advisory' : 'Factual'}'
                        '${i.confidencePct != null ? ' · ${i.confidencePct!.toStringAsFixed(0)}% conf.' : ''}',
                      ),
                      isThreeLine: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ];
      case EocCommandTab.workflows:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Business Process Automation Studio™',
              icon: LucideIcons.gitBranch,
              child: _WorkflowList(items: snap.workflows),
            ),
          ),
        ];
      case EocCommandTab.approvals:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Approval Queue',
              icon: LucideIcons.checkCircle,
              child: _ApprovalList(
                items: controller.filteredApprovals(snap),
              ),
            ),
          ),
        ];
      case EocCommandTab.alerts:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Enterprise Alerts',
              icon: LucideIcons.alertTriangle,
              child: _AlertList(alerts: controller.filteredAlerts(snap)),
            ),
          ),
        ];
      case EocCommandTab.tasks:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Enterprise Tasks',
              icon: LucideIcons.listChecks,
              child: _TaskList(items: controller.filteredTasks(snap)),
            ),
          ),
          ContainedPadding(
            child: _SectionCard(
              title: 'Upcoming Meetings',
              icon: LucideIcons.calendar,
              child: _MeetingList(items: snap.meetings),
            ),
          ),
        ];
      case EocCommandTab.forecasts:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Predictive Intelligence Engine™',
              icon: LucideIcons.lineChart,
              child: _ForecastList(items: snap.forecasts),
            ),
          ),
        ];
      case EocCommandTab.scorecards:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Executive Decision Intelligence™',
              icon: LucideIcons.clipboardCheck,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...snap.scorecards.map(
                    (s) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(s.name),
                      subtitle: Text(
                        '${s.code} · ${s.period} · '
                        'score ${s.overallScore?.toStringAsFixed(1) ?? '—'} · '
                        '${s.ownerLabel ?? ''}',
                      ),
                    ),
                  ),
                  const Divider(height: 24),
                  _ScorecardMetricList(items: snap.scorecardMetrics),
                  const Divider(height: 24),
                  _DecisionList(items: snap.decisions),
                ],
              ),
            ),
          ),
        ];
      case EocCommandTab.knowledge:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Knowledge Base',
              icon: LucideIcons.bookOpen,
              child: _KnowledgeList(items: snap.knowledge),
            ),
          ),
        ];
      case EocCommandTab.audit:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'EOC Audit Trail',
              icon: LucideIcons.shield,
              child: _AuditList(items: snap.auditEvents),
            ),
          ),
          ContainedPadding(
            child: _SectionCard(
              title: 'Activity Feed',
              icon: LucideIcons.history,
              child: _ActivityList(activities: snap.activities),
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
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(child: child);
  }
}

class _EocHeader extends StatelessWidget {
  const _EocHeader({
    required this.ticker,
    required this.fromRemote,
    required this.onRefresh,
    required this.onOpenAi,
    required this.onOpenWorkflows,
  });

  final String ticker;
  final bool fromRemote;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpenAi;
  final VoidCallback onOpenWorkflows;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.charcoal,
            AppColors.deepBlack.withValues(alpha: 0.9),
          ],
        ),
        border: Border(
          bottom: BorderSide(color: AppColors.gold.withValues(alpha: 0.25)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 640;
              final title = Text(
                'Enterprise Mission Control™',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
              );
              final actions = Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: onOpenAi,
                    icon: const Icon(LucideIcons.sparkles, size: 16),
                    label: const Text('AI Enterprise Brain'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.deepBlack,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: onOpenWorkflows,
                    icon: const Icon(LucideIcons.gitBranch, size: 16),
                    label: const Text('Automation Studio'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.white,
                      side: BorderSide(
                        color: AppColors.gold.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: () => onRefresh(),
                    icon: const Icon(
                      LucideIcons.rotateCcw,
                      color: AppColors.white,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.15),
                      borderRadius: AppRadius.cardBorder,
                    ),
                    child: Text(
                      fromRemote ? 'LIVE' : 'DEMO',
                      style: TextStyle(
                        color:
                            fromRemote ? Colors.greenAccent : AppColors.gold,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              );
              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    const SizedBox(height: 8),
                    Text(
                      'EOC · KPIs · workflows · approvals · forecasts',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondaryDark,
                          ),
                    ),
                    const SizedBox(height: 12),
                    actions,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        title,
                        const SizedBox(height: 4),
                        Text(
                          'Ops Center · predictive intelligence · decision logs · audit',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondaryDark,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  actions,
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(LucideIcons.activity, size: 14, color: AppColors.gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ticker,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.white.withValues(alpha: 0.85),
                      ),
                  overflow: TextOverflow.ellipsis,
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

  final ValueChanged<EocCommandTab> onSelect;

  @override
  Widget build(BuildContext context) {
    const items = [
      (EocCommandTab.overview, 'Mission Control™', LucideIcons.radar),
      (EocCommandTab.ai, 'AI Enterprise Brain™', LucideIcons.sparkles),
      (EocCommandTab.workflows, 'Automation Studio™', LucideIcons.gitBranch),
      (EocCommandTab.forecasts, 'Predictive Engine™', LucideIcons.lineChart),
      (EocCommandTab.scorecards, 'Decision Intelligence™', LucideIcons.scale),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: items
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    avatar: Icon(item.$3, size: 14, color: AppColors.gold),
                    label: Text(item.$2),
                    onPressed: () => onSelect(item.$1),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _KpiStrip extends StatelessWidget {
  const _KpiStrip({required this.kpis});

  final List<EocKpi> kpis;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
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
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: AppRadius.cardBorder,
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    k.label,
                    style: Theme.of(context).textTheme.labelSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  Text(
                    k.displayValue,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
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

  final EocUiState ui;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onStatus;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search alerts, approvals, workflows…',
                prefixIcon: Icon(LucideIcons.search, size: 18),
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: onSearch,
            ),
          ),
          const SizedBox(width: 8),
          DropdownButton<String?>(
            value: ui.statusFilter,
            hint: const Text('Status'),
            items: const [
              DropdownMenuItem(value: null, child: Text('All')),
              DropdownMenuItem(value: 'open', child: Text('Open')),
              DropdownMenuItem(value: 'pending', child: Text('Pending')),
              DropdownMenuItem(value: 'waiting', child: Text('Waiting')),
              DropdownMenuItem(value: 'in_progress', child: Text('In progress')),
              DropdownMenuItem(value: 'critical', child: Text('Critical')),
            ],
            onChanged: onStatus,
          ),
        ],
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.selected, required this.onSelect});

  final EocCommandTab selected;
  final ValueChanged<EocCommandTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: EocCommandTab.values.map((tab) {
            final active = tab == selected;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(tab.label),
                selected: active,
                onSelected: (_) => onSelect(tab),
              ),
            );
          }).toList(),
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.cardBorder,
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

class _ModuleHealthGrid extends StatelessWidget {
  const _ModuleHealthGrid({required this.modules});

  final List<EocModuleHealth> modules;

  @override
  Widget build(BuildContext context) {
    if (modules.isEmpty) return const Text('No module health data.');
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: modules
          .map(
            (m) => Container(
              width: 140,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: AppRadius.cardBorder,
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.label, style: Theme.of(context).textTheme.labelMedium),
                  Text(
                    '${m.healthPct.toStringAsFixed(0)}%',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  Text(
                    '${m.status}${m.openAlerts > 0 ? ' · ${m.openAlerts} alerts' : ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _KpiDetailList extends StatelessWidget {
  const _KpiDetailList({required this.kpis});

  final List<EocKpi> kpis;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: kpis
          .map(
            (k) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(k.label),
              subtitle: Text(
                'status ${k.status}'
                '${k.changePct != null ? ' · Δ ${k.changePct!.toStringAsFixed(1)}%' : ''}',
              ),
              trailing: Text(
                k.displayValue,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _AlertList extends StatelessWidget {
  const _AlertList({required this.alerts});

  final List<EocAlert> alerts;

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) return const Text('No alerts.');
    return Column(
      children: alerts
          .map(
            (a) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(
                a.severity == 'critical'
                    ? LucideIcons.siren
                    : LucideIcons.bell,
                size: 16,
                color: a.severity == 'critical'
                    ? Colors.redAccent
                    : AppColors.gold,
              ),
              title: Text(a.title),
              subtitle: Text(
                '${a.severity} · ${a.status} · ${a.moduleSlug ?? a.category}'
                '${a.body != null ? '\n${a.body}' : ''}',
              ),
              isThreeLine: a.body != null,
            ),
          )
          .toList(),
    );
  }
}

class _ApprovalList extends StatelessWidget {
  const _ApprovalList({required this.items});

  final List<EocApproval> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('No approvals.');
    final fmt = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
    return Column(
      children: items
          .map(
            (a) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(a.title),
              subtitle: Text(
                '${a.status} · ${a.moduleSlug ?? '—'}'
                '${a.summary != null ? '\n${a.summary}' : ''}',
              ),
              trailing: a.amount != null ? Text(fmt.format(a.amount)) : null,
              isThreeLine: a.summary != null,
            ),
          )
          .toList(),
    );
  }
}

class _WorkflowList extends StatelessWidget {
  const _WorkflowList({required this.items});

  final List<EocWorkflowInstance> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('No workflow instances.');
    return Column(
      children: items
          .map(
            (w) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(w.referenceLabel),
              subtitle: Text(
                '${w.definitionName ?? 'Workflow'} · ${w.status}'
                '${w.currentStepKey != null ? ' · step ${w.currentStepKey}' : ''}',
              ),
            ),
          )
          .toList(),
    );
  }
}

class _TaskList extends StatelessWidget {
  const _TaskList({required this.items});

  final List<EocTask> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('No tasks.');
    return Column(
      children: items
          .map(
            (t) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(t.title),
              subtitle: Text(
                '${t.status} · ${t.priority} · ${t.assigneeLabel ?? '—'}'
                '${t.moduleSlug != null ? ' · ${t.moduleSlug}' : ''}',
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ForecastList extends StatelessWidget {
  const _ForecastList({required this.items});

  final List<EocForecast> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('No forecasts.');
    return Column(
      children: items
          .map(
            (f) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(f.label),
              subtitle: Text(
                '${f.horizon} · ${f.scenario}'
                '${f.confidencePct != null ? ' · ${f.confidencePct!.toStringAsFixed(0)}% conf.' : ''}',
              ),
              trailing: Text(
                f.displayValue,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ScorecardMetricList extends StatelessWidget {
  const _ScorecardMetricList({required this.items});

  final List<EocScorecardMetric> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('No scorecard metrics.');
    return Column(
      children: items
          .map(
            (m) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(m.label),
              subtitle: Text('score ${m.score.toStringAsFixed(0)} · ${m.status}'),
              trailing: Text('w${m.weight}'),
            ),
          )
          .toList(),
    );
  }
}

class _MeetingList extends StatelessWidget {
  const _MeetingList({required this.items});

  final List<EocMeeting> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('No meetings.');
    final fmt = DateFormat('EEE d MMM · HH:mm');
    return Column(
      children: items
          .map(
            (m) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(m.title),
              subtitle: Text(
                '${m.meetingType} · ${m.locationLabel ?? '—'} · '
                '${m.scheduledAt != null ? fmt.format(m.scheduledAt!) : 'TBD'}',
              ),
            ),
          )
          .toList(),
    );
  }
}

class _DecisionList extends StatelessWidget {
  const _DecisionList({required this.items});

  final List<EocDecision> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('No decisions logged.');
    return Column(
      children: items
          .map(
            (d) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(d.title),
              subtitle: Text('${d.decision}\n${d.status} · ${d.owners.join(', ')}'),
              isThreeLine: true,
            ),
          )
          .toList(),
    );
  }
}

class _ActivityList extends StatelessWidget {
  const _ActivityList({required this.activities});

  final List<EocActivity> activities;

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) return const Text('No recent activity.');
    return Column(
      children: activities
          .map(
            (a) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(LucideIcons.activity, size: 16),
              title: Text(a.summary),
              subtitle: Text('${a.actorLabel ?? 'System'} · ${a.action}'),
            ),
          )
          .toList(),
    );
  }
}

class _AuditList extends StatelessWidget {
  const _AuditList({required this.items});

  final List<EocAuditEvent> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('No audit events.');
    return Column(
      children: items
          .map(
            (e) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(e.summary ?? e.action),
              subtitle: Text(
                '${e.action} · ${e.entityType ?? '—'} · ${e.actorLabel ?? ''}',
              ),
            ),
          )
          .toList(),
    );
  }
}

class _KnowledgeList extends StatelessWidget {
  const _KnowledgeList({required this.items});

  final List<EocKnowledgeArticle> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('No knowledge articles.');
    return Column(
      children: items
          .map(
            (k) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(k.title),
              subtitle: Text('${k.category} · ${k.body}'),
              isThreeLine: true,
            ),
          )
          .toList(),
    );
  }
}

class _SearchHitList extends StatelessWidget {
  const _SearchHitList({required this.hits});

  final List<EocSearchHit> hits;

  @override
  Widget build(BuildContext context) {
    if (hits.isEmpty) return const Text('No search results.');
    return Column(
      children: hits
          .map(
            (h) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(LucideIcons.search, size: 16),
              title: Text(h.title),
              subtitle: Text('${h.module}${h.subtitle != null ? ' · ${h.subtitle}' : ''}'),
            ),
          )
          .toList(),
    );
  }
}
