import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/eaih/domain/entities/eaih_models.dart';
import 'package:hdhomesproject/features/eaih/domain/services/eaih_service.dart';
import 'package:hdhomesproject/features/eaih/presentation/providers/eaih_controller.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Volume 4 Part 17 — AI Command Center (EAIH).
/// Governance from Volume 3 is a tab here; `/account/ai` personal workspace unchanged.
class AiCommandCenterPage extends ConsumerWidget {
  const AiCommandCenterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSnap = ref.watch(eaihSnapshotProvider);
    final ui = ref.watch(eaihControllerProvider);
    final controller = ref.read(eaihControllerProvider.notifier);

    return Scaffold(
      body: asyncSnap.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Failed to load AI Command Center: $e'),
        ),
        data: (snap) {
          final tickerKpis = snap.kpis;
          final ticker = tickerKpis.isEmpty
              ? 'AI Command Center live'
              : '${tickerKpis[ui.tickerIndex % tickerKpis.length].label}: '
                  '${tickerKpis[ui.tickerIndex % tickerKpis.length].displayValue}';

          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: CustomScrollView(
              slivers: [
                ContainedPadding(
                  child: _EaihHeader(
                    ticker: ticker,
                    fromRemote: snap.fromRemote,
                    onRefresh: controller.refresh,
                    onOpenDecision: () =>
                        controller.setTab(EaihCommandTab.decision),
                    onOpenGovernance: () =>
                        controller.setTab(EaihCommandTab.governance),
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
    EaihCommandCenterSnapshot snap,
    EaihUiState ui,
    EaihController controller,
  ) {
    switch (ui.selectedTab) {
      case EaihCommandTab.overview:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Enterprise AI Operating System™',
              icon: LucideIcons.bot,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Copilots · Models · Predictions · Automation · Governance',
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
              child: _DriftList(
                items: snap.driftReports.where((d) => d.isOpen).toList(),
              ),
            ),
          ),
          ContainedPadding(
            child: _SectionCard(
              title: 'Recent automation',
              icon: LucideIcons.workflow,
              child: _AutomationList(items: snap.automationJobs),
            ),
          ),
        ];
      case EaihCommandTab.copilots:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Enterprise copilots',
              icon: LucideIcons.messageSquare,
              child: _CopilotList(items: controller.filteredCopilots(snap)),
            ),
          ),
        ];
      case EaihCommandTab.models:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'AI services',
              icon: LucideIcons.server,
              child: _ServiceList(items: snap.services),
            ),
          ),
          ContainedPadding(
            child: _SectionCard(
              title: 'Models & versions',
              icon: LucideIcons.box,
              child: Column(
                children: [
                  _ModelList(items: snap.models),
                  const Divider(height: 24),
                  _VersionList(items: snap.modelVersions),
                ],
              ),
            ),
          ),
        ];
      case EaihCommandTab.predictions:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Predictions',
              icon: LucideIcons.trendingUp,
              child: _PredictionList(
                items: controller.filteredPredictions(snap),
              ),
            ),
          ),
        ];
      case EaihCommandTab.recommendations:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Recommendations',
              icon: LucideIcons.lightbulb,
              child: _RecommendationList(
                items: controller.filteredRecommendations(snap),
              ),
            ),
          ),
        ];
      case EaihCommandTab.search:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'AI search & RAG queries',
              icon: LucideIcons.search,
              child: _SearchList(items: snap.searchQueries),
            ),
          ),
        ];
      case EaihCommandTab.knowledge:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'HD Homes Knowledge Intelligence™',
              icon: LucideIcons.network,
              child: Column(
                children: [
                  _NodeList(items: snap.knowledgeNodes),
                  const Divider(height: 24),
                  _EdgeList(items: snap.knowledgeEdges),
                ],
              ),
            ),
          ),
        ];
      case EaihCommandTab.automation:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Intelligent Enterprise Automation™',
              icon: LucideIcons.workflow,
              child: Column(
                children: [
                  _AutomationList(items: controller.filteredAutomation(snap)),
                  const Divider(height: 24),
                  _RuleList(items: snap.workflowRules),
                ],
              ),
            ),
          ),
        ];
      case EaihCommandTab.decision:
        final service = ref.read(eaihServiceProvider);
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Executive Decision Intelligence™',
              icon: LucideIcons.sparkles,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.generateDecisionBriefing(snap),
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
                  _InsightList(items: snap.hubInsights),
                ],
              ),
            ),
          ),
        ];
      case EaihCommandTab.governance:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Responsible AI & Trust Center™',
              icon: LucideIcons.shieldCheck,
              child: _PolicyList(items: snap.governancePolicies),
            ),
          ),
        ];
      case EaihCommandTab.observability:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Model monitoring',
              icon: LucideIcons.activity,
              child: _MonitoringList(items: snap.monitoring),
            ),
          ),
          ContainedPadding(
            child: _SectionCard(
              title: 'Drift reports',
              icon: LucideIcons.gitCommit,
              child: _DriftList(items: controller.filteredDrift(snap)),
            ),
          ),
        ];
      case EaihCommandTab.analytics:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Live AI signals',
              icon: LucideIcons.radar,
              child: _SignalList(signals: EaihService.detectAiSignals(snap)),
            ),
          ),
          ContainedPadding(
            child: _SectionCard(
              title: 'Hub insights',
              icon: LucideIcons.sparkles,
              child: _InsightList(items: snap.hubInsights),
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

class _EaihHeader extends StatelessWidget {
  const _EaihHeader({
    required this.ticker,
    required this.fromRemote,
    required this.onRefresh,
    required this.onOpenDecision,
    required this.onOpenGovernance,
  });

  final String ticker;
  final bool fromRemote;
  final VoidCallback onRefresh;
  final VoidCallback onOpenDecision;
  final VoidCallback onOpenGovernance;

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
                    'AI Command Center',
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
                    onPressed: onOpenDecision,
                    icon: const Icon(LucideIcons.sparkles, size: 16),
                    label: const Text('Decision'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.deepBlack,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: onOpenGovernance,
                    icon: const Icon(LucideIcons.shieldCheck, size: 16),
                    label: const Text('Governance'),
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
            'Enterprise AI · ML · Decision Support',
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

  final void Function(EaihCommandTab) onSelect;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        EaihCommandTab.overview,
        'AI Operating System™',
        LucideIcons.bot,
      ),
      (
        EaihCommandTab.knowledge,
        'Knowledge Intelligence™',
        LucideIcons.network,
      ),
      (
        EaihCommandTab.decision,
        'Decision Intelligence™',
        LucideIcons.sparkles,
      ),
      (
        EaihCommandTab.automation,
        'Enterprise Automation™',
        LucideIcons.workflow,
      ),
      (
        EaihCommandTab.governance,
        'Responsible AI & Trust™',
        LucideIcons.shieldCheck,
      ),
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

  final List<EaihKpi> kpis;

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

  final EaihUiState ui;
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
              hintText: 'Search copilots, predictions, automation, drift…',
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
                  label: const Text('Awaiting'),
                  selected: ui.statusFilter == 'awaiting_approval',
                  onSelected: (_) => onStatus('awaiting_approval'),
                ),
                FilterChip(
                  label: const Text('Active'),
                  selected: ui.statusFilter == 'active',
                  onSelected: (_) => onStatus('active'),
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

  final EaihCommandTab selected;
  final void Function(EaihCommandTab) onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: EaihCommandTab.values
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

  final List<EaihActivity> activities;

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
              leading: const Icon(LucideIcons.history, size: 18),
              title: Text(a.summary),
              subtitle: Text(
                [
                  a.action,
                  if (a.actorLabel != null) a.actorLabel!,
                ].join(' · '),
              ),
              dense: true,
            ),
          )
          .toList(),
    );
  }
}

class _ServiceList extends StatelessWidget {
  const _ServiceList({required this.items});

  final List<EaihServiceRecord> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (s) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.server, size: 18),
              title: Text(s.name),
              subtitle: Text(
                [
                  if (s.code != null) s.code!,
                  s.serviceType,
                  s.status,
                ].join(' · '),
              ),
              dense: true,
            ),
          )
          .toList(),
    );
  }
}

class _CopilotList extends StatelessWidget {
  const _CopilotList({required this.items});

  final List<EaihCopilot> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (c) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.bot, size: 18),
              title: Text(c.name),
              subtitle: Text(
                [
                  c.department,
                  c.status,
                  if (c.capabilities.isNotEmpty)
                    c.capabilities.take(3).join(', '),
                ].join(' · '),
              ),
              dense: true,
            ),
          )
          .toList(),
    );
  }
}

class _ModelList extends StatelessWidget {
  const _ModelList({required this.items});

  final List<EaihModel> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (m) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.box, size: 18),
              title: Text(m.name),
              subtitle: Text(
                [
                  if (m.code != null) m.code!,
                  m.modelFamily,
                  m.status,
                ].join(' · '),
              ),
              dense: true,
            ),
          )
          .toList(),
    );
  }
}

class _VersionList extends StatelessWidget {
  const _VersionList({required this.items});

  final List<EaihModelVersion> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (v) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.gitBranch, size: 18),
              title: Text(v.versionLabel),
              subtitle: Text(
                [
                  if (v.code != null) v.code!,
                  v.status,
                  if (v.accuracyPct != null)
                    '${v.accuracyPct!.toStringAsFixed(1)}% acc',
                ].join(' · '),
              ),
              dense: true,
            ),
          )
          .toList(),
    );
  }
}

class _PredictionList extends StatelessWidget {
  const _PredictionList({required this.items});

  final List<EaihPrediction> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (p) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.trendingUp, size: 18),
              title: Text(p.title),
              subtitle: Text(
                [
                  if (p.code != null) p.code!,
                  p.displayValue,
                  '${p.confidencePct.toStringAsFixed(0)}% conf',
                ].join(' · '),
              ),
              dense: true,
            ),
          )
          .toList(),
    );
  }
}

class _RecommendationList extends StatelessWidget {
  const _RecommendationList({required this.items});

  final List<EaihRecommendation> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (r) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                LucideIcons.lightbulb,
                size: 18,
                color: r.needsReview ? AppColors.gold : null,
              ),
              title: Text(r.title),
              subtitle: Text(
                [
                  if (r.code != null) r.code!,
                  r.status,
                  if (r.confidencePct != null)
                    '${r.confidencePct!.toStringAsFixed(0)}%',
                ].join(' · '),
              ),
              dense: true,
            ),
          )
          .toList(),
    );
  }
}

class _SearchList extends StatelessWidget {
  const _SearchList({required this.items});

  final List<EaihSearchQuery> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (q) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.search, size: 18),
              title: Text(q.queryText),
              subtitle: Text(
                [
                  q.queryMode,
                  '${q.resultCount} hits',
                  if (q.latencyMs != null) '${q.latencyMs}ms',
                ].join(' · '),
              ),
              dense: true,
            ),
          )
          .toList(),
    );
  }
}

class _NodeList extends StatelessWidget {
  const _NodeList({required this.items});

  final List<EaihKnowledgeNode> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (n) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.circle, size: 18),
              title: Text(n.label),
              subtitle: Text(
                [
                  if (n.code != null) n.code!,
                  n.nodeType,
                ].join(' · '),
              ),
              dense: true,
            ),
          )
          .toList(),
    );
  }
}

class _EdgeList extends StatelessWidget {
  const _EdgeList({required this.items});

  final List<EaihKnowledgeEdge> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (e) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.gitBranch, size: 18),
              title: Text('${e.sourceLabel} → ${e.targetLabel}'),
              subtitle: Text(e.relationType),
              dense: true,
            ),
          )
          .toList(),
    );
  }
}

class _AutomationList extends StatelessWidget {
  const _AutomationList({required this.items});

  final List<EaihAutomationJob> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (j) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                LucideIcons.workflow,
                size: 18,
                color: j.isFailed || j.awaitsApproval ? AppColors.gold : null,
              ),
              title: Text(j.name),
              subtitle: Text(
                [
                  if (j.code != null) j.code!,
                  j.status,
                  if (j.ownerLabel != null) j.ownerLabel!,
                ].join(' · '),
              ),
              dense: true,
            ),
          )
          .toList(),
    );
  }
}

class _RuleList extends StatelessWidget {
  const _RuleList({required this.items});

  final List<EaihWorkflowRule> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (r) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.listChecks, size: 18),
              title: Text(r.name),
              subtitle: Text(
                [
                  r.triggerEvent,
                  if (r.requiresApproval) 'approval required',
                ].join(' · '),
              ),
              dense: true,
            ),
          )
          .toList(),
    );
  }
}

class _PolicyList extends StatelessWidget {
  const _PolicyList({required this.items});

  final List<EaihGovernancePolicy> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (p) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.shield, size: 18),
              title: Text(p.title),
              subtitle: Text(
                [
                  if (p.code != null) p.code!,
                  p.policyArea,
                  p.status,
                ].join(' · '),
              ),
              dense: true,
            ),
          )
          .toList(),
    );
  }
}

class _MonitoringList extends StatelessWidget {
  const _MonitoringList({required this.items});

  final List<EaihMonitoringMetric> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (m) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                LucideIcons.activity,
                size: 18,
                color: m.status == 'watch' || m.status == 'critical'
                    ? AppColors.gold
                    : null,
              ),
              title: Text(m.metricName),
              subtitle: Text(
                [
                  if (m.code != null) m.code!,
                  m.metricValue.toStringAsFixed(1),
                  m.status,
                ].join(' · '),
              ),
              dense: true,
            ),
          )
          .toList(),
    );
  }
}

class _DriftList extends StatelessWidget {
  const _DriftList({required this.items});

  final List<EaihDriftReport> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Text('No open drift reports');
    }
    return Column(
      children: items
          .map(
            (d) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                LucideIcons.alertTriangle,
                size: 18,
                color: d.severity == 'high' || d.severity == 'critical'
                    ? AppColors.gold
                    : null,
              ),
              title: Text(d.title),
              subtitle: Text(
                [
                  if (d.code != null) d.code!,
                  d.severity,
                  d.status,
                ].join(' · '),
              ),
              dense: true,
            ),
          )
          .toList(),
    );
  }
}

class _InsightList extends StatelessWidget {
  const _InsightList({required this.items});

  final List<EaihHubInsight> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (i) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.sparkles, size: 18),
              title: Text(i.title),
              subtitle: Text(
                [
                  i.body,
                  i.disclaimer,
                  if (i.confidencePct != null)
                    '${i.confidencePct!.toStringAsFixed(0)}% conf',
                ].join('\n'),
              ),
              isThreeLine: true,
              dense: true,
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
    if (signals.isEmpty) {
      return const Text('No elevated AI signals');
    }
    return Column(
      children: signals
          .map(
            (s) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.radar, size: 18),
              title: Text(s),
              dense: true,
            ),
          )
          .toList(),
    );
  }
}
