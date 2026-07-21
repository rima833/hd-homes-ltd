import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/crm/domain/entities/crm_models.dart';
import 'package:hdhomesproject/features/crm/domain/services/crm_service.dart';
import 'package:hdhomesproject/features/crm/presentation/providers/crm_controller.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Volume 4 Part 3 — CRM Command Center™ admin workspace.
class CrmCommandCenterPage extends ConsumerWidget {
  const CrmCommandCenterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSnap = ref.watch(crmSnapshotProvider);
    final ui = ref.watch(crmControllerProvider);
    final controller = ref.read(crmControllerProvider.notifier);

    return Scaffold(
      body: asyncSnap.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('Failed to load CRM Command Center: $e')),
        data: (snap) {
          final tickerKpis = snap.kpis;
          final ticker = tickerKpis.isEmpty
              ? 'CRM live'
              : '${tickerKpis[ui.tickerIndex % tickerKpis.length].label}: '
                  '${tickerKpis[ui.tickerIndex % tickerKpis.length].displayValue}';

          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _CrmHeader(
                    ticker: ticker,
                    fromRemote: snap.fromRemote,
                    onRefresh: controller.refresh,
                    onOpen360: () =>
                        controller.setTab(CrmCommandTab.client360),
                  ),
                ),
                if (ui.lastMessage != null)
                  SliverToBoxAdapter(
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
                SliverToBoxAdapter(child: _KpiStrip(kpis: snap.kpis)),
                ContainedPadding(
                  child: _SearchAndFilters(
                    ui: ui,
                    stages: snap.stages,
                    onSearch: controller.setSearch,
                    onStage: controller.setStageFilter,
                  ),
                ),
                ContainedPadding(
                  child: _TabBar(
                    selected: ui.selectedTab,
                    onSelect: controller.setTab,
                  ),
                ),
                ..._tabSlivers(context, ref, snap, ui, controller),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
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
    CrmCommandCenterSnapshot snap,
    CrmUiState ui,
    CrmController controller,
  ) {
    switch (ui.selectedTab) {
      case CrmCommandTab.pipeline:
        return [
          SliverToBoxAdapter(
            child: _SectionCard(
              title: 'Pipeline Board',
              icon: LucideIcons.layoutGrid,
              child: _PipelineKanban(
                stages: snap.stages,
                counts: snap.stageCounts(),
                onSelectStage: controller.setStageFilter,
                selected: ui.stageFilter,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _SectionCard(
              title: 'Lead Intelligence™',
              icon: LucideIcons.radar,
              child: _BulletList(items: snap.leadIntelligence),
            ),
          ),
        ];
      case CrmCommandTab.leads:
        return [
          ContainedPadding(
            child: _LeadList(
              leads: controller.filteredLeads(snap),
              onOpenClient: controller.selectClient,
            ),
          ),
        ];
      case CrmCommandTab.tasks:
        return [
          SliverToBoxAdapter(
            child: _SectionCard(
              title: 'Tasks Due',
              icon: LucideIcons.checkSquare,
              child: _TaskList(tasks: snap.tasks),
            ),
          ),
        ];
      case CrmCommandTab.appointments:
        return [
          SliverToBoxAdapter(
            child: _SectionCard(
              title: 'Appointments',
              icon: LucideIcons.calendar,
              child: _AppointmentList(appointments: snap.appointments),
            ),
          ),
        ];
      case CrmCommandTab.timeline:
        return [
          SliverToBoxAdapter(
            child: _SectionCard(
              title: 'Relationship Timeline',
              icon: LucideIcons.gitBranch,
              child: _TimelineList(events: snap.timeline),
            ),
          ),
        ];
      case CrmCommandTab.ai:
        return [
          SliverToBoxAdapter(
            child: _SectionCard(
              title: 'AI CRM Assistant™',
              icon: LucideIcons.sparkles,
              child: _AiAssistantPanel(
                insights: snap.aiInsights,
                clients: snap.clients,
                service: ref.read(crmServiceProvider),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _SectionCard(
              title: 'Lead Intelligence™',
              icon: LucideIcons.brain,
              child: _BulletList(items: snap.leadIntelligence),
            ),
          ),
        ];
      case CrmCommandTab.graph:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Relationship Graph',
              icon: LucideIcons.share2,
              child: _RelationshipGraph(nodes: snap.relationshipGraph),
            ),
          ),
        ];
      case CrmCommandTab.client360:
        final client = controller.selectedClient(snap);
        return [
          SliverToBoxAdapter(
            child: _SectionCard(
              title: '360° Customer View',
              icon: LucideIcons.userCircle,
              child: client == null
                  ? const Text('No client selected')
                  : _Client360Panel(
                      client: client,
                      clients: snap.clients,
                      timeline: snap.timeline
                          .where((e) => e.clientId == client.id)
                          .toList(),
                      onSelectClient: controller.selectClient,
                      service: ref.read(crmServiceProvider),
                    ),
            ),
          ),
        ];
    }
  }
}

/// Thin helper so private widgets can pad without repeating SliverToBoxAdapter.
class ContainedPadding extends StatelessWidget {
  const ContainedPadding({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(child: child);
  }
}

class _CrmHeader extends StatelessWidget {
  const _CrmHeader({
    required this.ticker,
    required this.fromRemote,
    required this.onRefresh,
    required this.onOpen360,
  });

  final String ticker;
  final bool fromRemote;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpen360;

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
                'CRM Command Center™',
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
                    onPressed: onOpen360,
                    icon: const Icon(LucideIcons.scan, size: 16),
                    label: const Text('360° Customer View'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.deepBlack,
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
                      'Leads · pipeline · relationships · AI CRM',
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
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        title,
                        Text(
                          'Leads · pipeline · relationships · AI CRM',
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.12),
              borderRadius: AppRadius.cardBorder,
            ),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.activity,
                  size: 16,
                  color: AppColors.gold,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ticker,
                    style: const TextStyle(color: AppColors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiStrip extends StatelessWidget {
  const _KpiStrip({required this.kpis});

  final List<CrmKpi> kpis;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final cross = width >= 1100
              ? 6
              : width >= 720
                  ? 3
                  : 2;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kpis.map((kpi) {
              final tileWidth = (width - (8 * (cross - 1))) / cross;
              return SizedBox(
                width: tileWidth,
                child: Material(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: AppRadius.cardBorder,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          kpi.label,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          kpi.displayValue,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _SearchAndFilters extends StatelessWidget {
  const _SearchAndFilters({
    required this.ui,
    required this.stages,
    required this.onSearch,
    required this.onStage,
  });

  final CrmUiState ui;
  final List<CrmPipelineStage> stages;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onStage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Search leads, clients, codes…',
              prefixIcon: const Icon(LucideIcons.search, size: 18),
              isDense: true,
              border: OutlineInputBorder(borderRadius: AppRadius.cardBorder),
            ),
            onChanged: onSearch,
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All stages'),
                  selected: ui.stageFilter == null,
                  onSelected: (_) => onStage(null),
                ),
                ...stages.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: FilterChip(
                      label: Text(s.name),
                      selected: ui.stageFilter == s.slug,
                      onSelected: (_) => onStage(s.slug),
                    ),
                  ),
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

  final CrmCommandTab selected;
  final ValueChanged<CrmCommandTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: CrmCommandTab.values.map((tab) {
            final active = tab == selected;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(tab.label),
                selected: active,
                onSelected: (_) => onSelect(tab),
                selectedColor: AppColors.gold.withValues(alpha: 0.35),
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
    required this.child,
    this.icon,
  });

  final String title;
  final Widget child;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: AppRadius.cardBorder,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: AppColors.gold),
                    const SizedBox(width: 8),
                  ],
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

class _PipelineKanban extends StatelessWidget {
  const _PipelineKanban({
    required this.stages,
    required this.counts,
    required this.onSelectStage,
    this.selected,
  });

  final List<CrmPipelineStage> stages;
  final Map<String, int> counts;
  final ValueChanged<String?> onSelectStage;
  final String? selected;

  @override
  Widget build(BuildContext context) {
    final active = stages.where((s) => s.isActive).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 720;
        final children = active.map((stage) {
          final count = counts[stage.slug] ?? 0;
          final isSelected = selected == stage.slug;
          return SizedBox(
            width: narrow ? double.infinity : 140,
            child: Material(
              color: isSelected
                  ? AppColors.gold.withValues(alpha: 0.2)
                  : Theme.of(context).colorScheme.surface,
              borderRadius: AppRadius.cardBorder,
              child: InkWell(
                borderRadius: AppRadius.cardBorder,
                onTap: () => onSelectStage(stage.slug),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stage.name,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$count',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${stage.probabilityPct.toStringAsFixed(0)}% prob',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList();

        if (narrow) {
          return Wrap(spacing: 8, runSpacing: 8, children: children);
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                children[i],
              ],
            ],
          ),
        );
      },
    );
  }
}

class _LeadList extends StatelessWidget {
  const _LeadList({required this.leads, required this.onOpenClient});

  final List<CrmLead> leads;
  final ValueChanged<String> onOpenClient;

  @override
  Widget build(BuildContext context) {
    if (leads.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No leads match your filters.'),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: leads.map((lead) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: AppRadius.cardBorder,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.gold.withValues(alpha: 0.2),
                  child: Text(
                    lead.priority.label[0],
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                title: Text(lead.title),
                subtitle: Text(
                  [
                    lead.clientName ?? '—',
                    lead.stageName ?? lead.stageSlug ?? '—',
                    lead.valueDisplay,
                    '${lead.conversionProbability.toStringAsFixed(0)}%',
                  ].join(' · '),
                ),
                trailing: IconButton(
                  tooltip: 'Open 360°',
                  icon: const Icon(LucideIcons.userCircle, size: 18),
                  onPressed: () => onOpenClient(lead.clientId),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TaskList extends StatelessWidget {
  const _TaskList({required this.tasks});

  final List<CrmTask> tasks;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d · HH:mm');
    return Column(
      children: tasks.map((task) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            task.isDueSoon ? LucideIcons.alertCircle : LucideIcons.checkSquare,
            color: task.isDueSoon ? Colors.orange : AppColors.gold,
            size: 18,
          ),
          title: Text(task.title),
          subtitle: Text(
            [
              task.clientName ?? '—',
              task.taskType.label,
              task.priority.label,
              if (task.dueAt != null) fmt.format(task.dueAt!.toLocal()),
            ].join(' · '),
          ),
          trailing: Text(task.status.label),
        );
      }).toList(),
    );
  }
}

class _AppointmentList extends StatelessWidget {
  const _AppointmentList({required this.appointments});

  final List<CrmAppointment> appointments;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('EEE, MMM d · HH:mm');
    return Column(
      children: appointments.map((appt) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(LucideIcons.calendar, color: AppColors.gold, size: 18),
          title: Text(appt.title),
          subtitle: Text(
            [
              appt.clientName ?? '—',
              fmt.format(appt.scheduledAt.toLocal()),
              appt.location ?? appt.meetingUrl ?? '—',
            ].join(' · '),
          ),
          trailing: Text(appt.status.label),
        );
      }).toList(),
    );
  }
}

class _TimelineList extends StatelessWidget {
  const _TimelineList({required this.events});

  final List<CrmTimelineEvent> events;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d · HH:mm');
    return Column(
      children: events.map((e) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(LucideIcons.gitCommit, color: AppColors.gold, size: 18),
          title: Text(e.title),
          subtitle: Text(
            [
              e.clientName ?? '—',
              e.eventType,
              if (e.description != null) e.description!,
              if (e.occurredAt != null) fmt.format(e.occurredAt!.toLocal()),
            ].join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
    );
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(LucideIcons.zap, size: 14, color: AppColors.gold),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _AiAssistantPanel extends StatelessWidget {
  const _AiAssistantPanel({
    required this.insights,
    required this.clients,
    required this.service,
  });

  final List<CrmAiInsight> insights;
  final List<CrmClient> clients;
  final CrmService service;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...insights.map(
          (insight) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.sparkles, size: 14, color: AppColors.gold),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        insight.title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (insight.isAiGenerated)
                      Text(
                        'AI',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.gold,
                            ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(insight.body),
              ],
            ),
          ),
        ),
        if (clients.isNotEmpty) ...[
          const Divider(),
          Text(
            'Stub summary',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Text(service.generateClientSummary(clients.first)),
        ],
      ],
    );
  }
}

class _RelationshipGraph extends StatelessWidget {
  const _RelationshipGraph({required this.nodes});

  final List<CrmRelationshipNode> nodes;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: nodes.map((node) {
        final color = switch (node.kind) {
          'staff' => Colors.blueGrey,
          'property' => Colors.teal,
          'investor' => Colors.indigo,
          _ => AppColors.gold,
        };
        return Chip(
          avatar: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.2),
            child: Icon(LucideIcons.circle, size: 10, color: color),
          ),
          label: Text(
            '${node.label} → ${node.connectedTo.length} links',
          ),
        );
      }).toList(),
    );
  }
}

class _Client360Panel extends StatelessWidget {
  const _Client360Panel({
    required this.client,
    required this.clients,
    required this.timeline,
    required this.onSelectClient,
    required this.service,
  });

  final CrmClient client;
  final List<CrmClient> clients;
  final List<CrmTimelineEvent> timeline;
  final ValueChanged<String> onSelectClient;
  final CrmService service;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: clients.map((c) {
              final selected = c.id == client.id;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(c.fullName),
                  selected: selected,
                  onSelected: (_) => onSelectClient(c.id),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          client.fullName,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        Text(
          '${client.clientCode} · ${client.relationshipStatus.label} · '
          '${client.customerType.label}',
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _MetaChip('Health', '${client.healthScore.toStringAsFixed(0)} · ${client.healthLabel.label}'),
            _MetaChip('Lead score', client.leadScore.toStringAsFixed(0)),
            _MetaChip('Budget', client.budgetRange),
            if (client.company != null) _MetaChip('Company', client.company!),
            ...client.tags.map((t) => _MetaChip('Tag', t)),
          ],
        ),
        const SizedBox(height: 12),
        Text('Preferences', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          [
            if (client.preferences.preferredPropertyTypes.isNotEmpty)
              client.preferences.preferredPropertyTypes.join(', '),
            if (client.preferences.bedrooms != null)
              '${client.preferences.bedrooms} bed',
            if (client.preferences.paymentPlanPref != null)
              client.preferences.paymentPlanPref!,
            if (client.preferredLocations.isNotEmpty)
              client.preferredLocations.join(', '),
          ].join(' · '),
        ),
        if (client.preferences.amenities.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('Amenities: ${client.preferences.amenities.join(', ')}'),
        ],
        const SizedBox(height: 12),
        Text('AI summary', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(service.generateClientSummary(client)),
        const SizedBox(height: 12),
        Text('Recent timeline', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        if (timeline.isEmpty)
          const Text('No recent events for this client.')
        else
          _TimelineList(events: timeline.take(5).toList()),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: $value'),
      visualDensity: VisualDensity.compact,
    );
  }
}
