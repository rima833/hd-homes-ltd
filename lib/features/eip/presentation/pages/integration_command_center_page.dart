import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/eip/domain/entities/eip_models.dart';
import 'package:hdhomesproject/features/eip/domain/services/eip_service.dart';
import 'package:hdhomesproject/features/eip/presentation/providers/eip_controller.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Volume 4 Part 18 — Integration Command Center (EIP).
class IntegrationCommandCenterPage extends ConsumerWidget {
  const IntegrationCommandCenterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSnap = ref.watch(eipSnapshotProvider);
    final ui = ref.watch(eipControllerProvider);
    final controller = ref.read(eipControllerProvider.notifier);

    return Scaffold(
      body: asyncSnap.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Failed to load Integration Command Center: $e'),
        ),
        data: (snap) {
          final tickerKpis = snap.kpis;
          final ticker = tickerKpis.isEmpty
              ? 'Integration Command Center live'
              : '${tickerKpis[ui.tickerIndex % tickerKpis.length].label}: '
                  '${tickerKpis[ui.tickerIndex % tickerKpis.length].displayValue}';

          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: CustomScrollView(
              slivers: [
                ContainedPadding(
                  child: _EipHeader(
                    ticker: ticker,
                    fromRemote: snap.fromRemote,
                    onRefresh: controller.refresh,
                    onOpenWorkflows: () =>
                        controller.setTab(EipCommandTab.workflows),
                    onOpenMonitoring: () =>
                        controller.setTab(EipCommandTab.monitoring),
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
    EipCommandCenterSnapshot snap,
    EipUiState ui,
    EipController controller,
  ) {
    switch (ui.selectedTab) {
      case EipCommandTab.overview:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Enterprise Integration Command Center™',
              icon: LucideIcons.cable,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'APIs · Workflows · Events · Queues · Webhooks · Connectors',
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
              child: _HealthList(
                items: snap.healthChecks.where((h) => h.isWatch).toList(),
              ),
            ),
          ),
          ContainedPadding(
            child: _SectionCard(
              title: 'Recent events',
              icon: LucideIcons.zap,
              child: _EventList(items: snap.domainEvents.take(4).toList()),
            ),
          ),
        ];
      case EipCommandTab.apis:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'API services',
              icon: LucideIcons.server,
              child: _ApiList(items: controller.filteredApis(snap)),
            ),
          ),
          ContainedPadding(
            child: _SectionCard(
              title: 'API consumers',
              icon: LucideIcons.users,
              child: _ConsumerList(items: snap.apiConsumers),
            ),
          ),
        ];
      case EipCommandTab.workflows:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Intelligent Workflow Automation™',
              icon: LucideIcons.workflow,
              child: _WorkflowList(items: controller.filteredWorkflows(snap)),
            ),
          ),
          ContainedPadding(
            child: _SectionCard(
              title: 'Tasks & approvals',
              icon: LucideIcons.checkSquare,
              child: Column(
                children: [
                  _TaskList(items: snap.workflowTasks),
                  const Divider(height: 24),
                  _ApprovalList(items: snap.workflowApprovals),
                ],
              ),
            ),
          ),
        ];
      case EipCommandTab.events:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Enterprise Event Intelligence™',
              icon: LucideIcons.zap,
              child: _EventList(items: controller.filteredEvents(snap)),
            ),
          ),
        ];
      case EipCommandTab.queues:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Message queues',
              icon: LucideIcons.listOrdered,
              child: _QueueList(items: snap.queues),
            ),
          ),
          ContainedPadding(
            child: _SectionCard(
              title: 'Queue items',
              icon: LucideIcons.mail,
              child: _QueueItemList(items: snap.queueItems),
            ),
          ),
        ];
      case EipCommandTab.webhooks:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Webhook endpoints',
              icon: LucideIcons.webhook,
              child: _WebhookList(items: controller.filteredWebhooks(snap)),
            ),
          ),
          ContainedPadding(
            child: _SectionCard(
              title: 'Deliveries',
              icon: LucideIcons.send,
              child: _DeliveryList(items: snap.webhookDeliveries),
            ),
          ),
        ];
      case EipCommandTab.connectors:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Universal Connector Framework™',
              icon: LucideIcons.plug,
              child: _ConnectorList(items: controller.filteredConnectors(snap)),
            ),
          ),
        ];
      case EipCommandTab.security:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'API security policies',
              icon: LucideIcons.shieldCheck,
              child: _PolicyList(items: snap.securityPolicies),
            ),
          ),
        ];
      case EipCommandTab.monitoring:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Digital Operations Control Tower™',
              icon: LucideIcons.activity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ref.read(eipServiceProvider).generateOpsBriefing(snap),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Divider(height: 24),
                  _HealthList(items: snap.healthChecks),
                  const Divider(height: 24),
                  _RegistryList(items: snap.serviceRegistry),
                ],
              ),
            ),
          ),
        ];
      case EipCommandTab.config:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Feature flags',
              icon: LucideIcons.toggleLeft,
              child: _FlagList(items: snap.featureFlags),
            ),
          ),
          ContainedPadding(
            child: _SectionCard(
              title: 'Configuration',
              icon: LucideIcons.settings,
              child: _ConfigList(items: snap.configSettings),
            ),
          ),
        ];
      case EipCommandTab.analytics:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Integration reports',
              icon: LucideIcons.barChart3,
              child: _ReportList(items: snap.reports),
            ),
          ),
        ];
      case EipCommandTab.ai:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Integration AI insights',
              icon: LucideIcons.sparkles,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    snap.aiDisclaimer,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.gold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  _InsightList(items: snap.aiInsights),
                  const Divider(height: 24),
                  Text(
                    'Signals',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  ...EipService.detectIntegrationSignals(snap).map(
                    (s) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.radio, size: 14),
                          const SizedBox(width: 8),
                          Expanded(child: Text(s)),
                        ],
                      ),
                    ),
                  ),
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

class _EipHeader extends StatelessWidget {
  const _EipHeader({
    required this.ticker,
    required this.fromRemote,
    required this.onRefresh,
    required this.onOpenWorkflows,
    required this.onOpenMonitoring,
  });

  final String ticker;
  final bool fromRemote;
  final VoidCallback onRefresh;
  final VoidCallback onOpenWorkflows;
  final VoidCallback onOpenMonitoring;

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
              final narrow = constraints.maxWidth < 720;
              final title = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Integration Command Center',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w700,
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
              final actions = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(
                    onPressed: onOpenWorkflows,
                    icon: const Icon(LucideIcons.workflow, size: 16),
                    label: const Text('Workflows'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.white,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onOpenMonitoring,
                    icon: const Icon(LucideIcons.activity, size: 16),
                    label: const Text('Ops Tower'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.white,
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
            'API Gateway · Workflows · Events · Connectors',
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

  final void Function(EipCommandTab) onSelect;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        EipCommandTab.overview,
        'Integration Command Center™',
        LucideIcons.cable,
      ),
      (
        EipCommandTab.workflows,
        'Workflow Automation™',
        LucideIcons.workflow,
      ),
      (
        EipCommandTab.events,
        'Event Intelligence™',
        LucideIcons.zap,
      ),
      (
        EipCommandTab.connectors,
        'Connector Framework™',
        LucideIcons.plug,
      ),
      (
        EipCommandTab.monitoring,
        'Ops Control Tower™',
        LucideIcons.radar,
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

  final List<EipKpi> kpis;

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

  final EipUiState ui;
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
              hintText: 'Search APIs, workflows, events, connectors…',
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
                  label: const Text('Active'),
                  selected: ui.statusFilter == 'active',
                  onSelected: (_) => onStatus('active'),
                ),
                FilterChip(
                  label: const Text('Degraded'),
                  selected: ui.statusFilter == 'degraded',
                  onSelected: (_) => onStatus('degraded'),
                ),
                FilterChip(
                  label: const Text('Failed'),
                  selected: ui.statusFilter == 'failed',
                  onSelected: (_) => onStatus('failed'),
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

  final EipCommandTab selected;
  final void Function(EipCommandTab) onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: EipCommandTab.values
              .map(
                (t) => Padding(
                  padding: const EdgeInsets.only(right: 8),
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
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
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
            Row(
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
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
    );
  }
}

class _ActivityList extends StatelessWidget {
  const _ActivityList({required this.activities});

  final List<EipActivity> activities;

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return const Text('No recent activity.');
    }
    return Column(
      children: activities
          .map(
            (a) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(LucideIcons.history, size: 18),
              title: Text(a.summary),
              subtitle: Text(
                [
                  a.action,
                  if (a.actorLabel != null) a.actorLabel!,
                ].join(' · '),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ApiList extends StatelessWidget {
  const _ApiList({required this.items});

  final List<EipApiService> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (a) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(a.name),
              subtitle: Text('${a.code ?? ''} · ${a.basePath} · ${a.status}'),
              trailing: Text(a.ownerLabel ?? ''),
            ),
          )
          .toList(),
    );
  }
}

class _ConsumerList extends StatelessWidget {
  const _ConsumerList({required this.items});

  final List<EipApiConsumer> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (c) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(c.name),
              subtitle: Text('${c.code ?? ''} · ${c.consumerType}'),
              trailing: Text(c.status),
            ),
          )
          .toList(),
    );
  }
}

class _WorkflowList extends StatelessWidget {
  const _WorkflowList({required this.items});

  final List<EipWorkflowDef> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (w) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(w.name),
              subtitle: Text(
                '${w.code ?? ''} · ${w.triggerEvent ?? '—'} · '
                '${w.orchestrationEngine}',
              ),
              trailing: Text(w.eipEnabled ? 'EIP' : 'EOC'),
            ),
          )
          .toList(),
    );
  }
}

class _TaskList extends StatelessWidget {
  const _TaskList({required this.items});

  final List<EipWorkflowTask> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (t) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(t.name),
              subtitle: Text('${t.code ?? ''} · ${t.assigneeLabel ?? ''}'),
              trailing: Text(t.status),
            ),
          )
          .toList(),
    );
  }
}

class _ApprovalList extends StatelessWidget {
  const _ApprovalList({required this.items});

  final List<EipWorkflowApproval> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (a) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(
                a.isPending ? LucideIcons.clock : LucideIcons.check,
                size: 18,
              ),
              title: Text(a.title),
              subtitle: Text(a.summary ?? a.approverLabel ?? ''),
              trailing: Text(a.status),
            ),
          )
          .toList(),
    );
  }
}

class _EventList extends StatelessWidget {
  const _EventList({required this.items});

  final List<EipDomainEvent> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (e) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(LucideIcons.zap, size: 18),
              title: Text(e.eventType),
              subtitle: Text('${e.code ?? ''} · ${e.aggregateType ?? ''}'),
              trailing: Text(e.status),
            ),
          )
          .toList(),
    );
  }
}

class _QueueList extends StatelessWidget {
  const _QueueList({required this.items});

  final List<EipMessageQueue> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (q) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(q.name),
              subtitle: Text('${q.code ?? ''} · ${q.queueType}'),
              trailing: Text('depth ${q.depth}'),
            ),
          )
          .toList(),
    );
  }
}

class _QueueItemList extends StatelessWidget {
  const _QueueItemList({required this.items});

  final List<EipQueueItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (i) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(i.subject),
              subtitle: Text(i.code ?? ''),
              trailing: Text(i.status),
            ),
          )
          .toList(),
    );
  }
}

class _WebhookList extends StatelessWidget {
  const _WebhookList({required this.items});

  final List<EipWebhookEndpoint> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (w) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(w.name),
              subtitle: Text(
                '${w.code ?? ''} · ${w.eventTypes.join(', ')}',
              ),
              trailing: Text(w.status),
            ),
          )
          .toList(),
    );
  }
}

class _DeliveryList extends StatelessWidget {
  const _DeliveryList({required this.items});

  final List<EipWebhookDelivery> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (d) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(
                d.isFailed ? LucideIcons.xCircle : LucideIcons.checkCircle,
                size: 18,
                color: d.isFailed ? AppColors.gold : null,
              ),
              title: Text(d.eventType ?? d.code ?? d.id),
              subtitle: Text(
                '${d.statusCode ?? '—'} · ${d.latencyMs ?? '—'}ms',
              ),
              trailing: Text(d.status),
            ),
          )
          .toList(),
    );
  }
}

class _ConnectorList extends StatelessWidget {
  const _ConnectorList({required this.items});

  final List<EipConnector> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (c) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(c.name),
              subtitle: Text(
                '${c.code ?? ''} · ${c.providerSlug ?? c.connectorType}',
              ),
              trailing: Text(c.status),
            ),
          )
          .toList(),
    );
  }
}

class _PolicyList extends StatelessWidget {
  const _PolicyList({required this.items});

  final List<EipSecurityPolicy> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (p) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(p.name),
              subtitle: Text('${p.code ?? ''} · ${p.policyType}'),
              trailing: Text(p.status),
            ),
          )
          .toList(),
    );
  }
}

class _HealthList extends StatelessWidget {
  const _HealthList({required this.items});

  final List<EipHealthCheck> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Text('No watch items.');
    }
    return Column(
      children: items
          .map(
            (h) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(
                h.isWatch ? LucideIcons.alertTriangle : LucideIcons.heartPulse,
                size: 18,
                color: h.isWatch ? AppColors.gold : null,
              ),
              title: Text(h.checkName),
              subtitle: Text(h.summary ?? '${h.latencyMs ?? '—'}ms'),
              trailing: Text(h.status),
            ),
          )
          .toList(),
    );
  }
}

class _RegistryList extends StatelessWidget {
  const _RegistryList({required this.items});

  final List<EipServiceRegistryEntry> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (s) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(s.name),
              subtitle: Text(s.serviceUrl ?? s.code ?? ''),
              trailing: Text(s.status),
            ),
          )
          .toList(),
    );
  }
}

class _FlagList extends StatelessWidget {
  const _FlagList({required this.items});

  final List<EipFeatureFlag> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (f) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(f.name),
              subtitle: Text('${f.flagKey} · ${f.rolloutPct.toStringAsFixed(0)}%'),
              trailing: Text(f.isEnabled ? 'on' : 'off'),
            ),
          )
          .toList(),
    );
  }
}

class _ConfigList extends StatelessWidget {
  const _ConfigList({required this.items});

  final List<EipConfigSetting> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (c) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(c.settingKey),
              subtitle: Text(c.summary ?? c.scope),
              trailing: Text(c.scope),
            ),
          )
          .toList(),
    );
  }
}

class _ReportList extends StatelessWidget {
  const _ReportList({required this.items});

  final List<EipReport> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (r) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(r.title),
              subtitle: Text('${r.code ?? ''} · ${r.reportType}'),
              trailing: Text(r.status),
            ),
          )
          .toList(),
    );
  }
}

class _InsightList extends StatelessWidget {
  const _InsightList({required this.items});

  final List<EipAiInsight> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (i) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(LucideIcons.sparkles, size: 18),
              title: Text(i.title),
              subtitle: Text(
                '${i.body}\n${i.disclaimer}'
                '${i.confidencePct != null ? ' · ${i.confidencePct!.toStringAsFixed(0)}%' : ''}',
              ),
              isThreeLine: true,
            ),
          )
          .toList(),
    );
  }
}
