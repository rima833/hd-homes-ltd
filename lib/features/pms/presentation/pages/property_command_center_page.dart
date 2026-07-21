import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/pms/domain/entities/pms_models.dart';
import 'package:hdhomesproject/features/pms/domain/services/pms_service.dart';
import 'package:hdhomesproject/features/pms/presentation/providers/pms_controller.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Volume 4 Part 2 — Property Command Center™ admin workspace.
class PropertyCommandCenterPage extends ConsumerWidget {
  const PropertyCommandCenterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSnap = ref.watch(pmsSnapshotProvider);
    final ui = ref.watch(pmsControllerProvider);
    final controller = ref.read(pmsControllerProvider.notifier);

    return Scaffold(
      body: asyncSnap.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('Failed to load Property Command Center: $e')),
        data: (snap) {
          final tickerKpis = snap.kpis;
          final ticker = tickerKpis.isEmpty
              ? 'Inventory live'
              : '${tickerKpis[ui.tickerIndex % tickerKpis.length].label}: '
                  '${tickerKpis[ui.tickerIndex % tickerKpis.length].displayValue}';

          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _PmsHeader(
                    ticker: ticker,
                    fromRemote: snap.fromRemote,
                    onCreate: () => controller.setTab(PmsCommandTab.wizard),
                    onRefresh: controller.refresh,
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
                SliverToBoxAdapter(
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
    PmsCommandCenterSnapshot snap,
    PmsUiState ui,
    PmsController controller,
  ) {
    switch (ui.selectedTab) {
      case PmsCommandTab.inventory:
        return [
          SliverToBoxAdapter(
            child: _InventoryPanel(
              properties: controller.filteredProperties(snap),
              ui: ui,
              controller: controller,
            ),
          ),
          SliverToBoxAdapter(
            child: _SectionCard(
              title: 'Property Lifecycle Timeline™',
              icon: LucideIcons.gitBranch,
              child: _LifecycleList(events: snap.lifecycle),
            ),
          ),
          SliverToBoxAdapter(
            child: _SectionCard(
              title: 'Upcoming Inspections',
              icon: LucideIcons.clipboardCheck,
              child: _InspectionList(inspections: snap.inspections),
            ),
          ),
        ];
      case PmsCommandTab.wizard:
        return [
          SliverToBoxAdapter(
            child: _SectionCard(
              title: 'Property Creation Wizard',
              icon: LucideIcons.sparkles,
              child: _PropertyWizard(
                draft: ui.wizardDraft,
                onChanged: controller.updateWizardStep,
                onSubmit: controller.submitWizardDraft,
              ),
            ),
          ),
        ];
      case PmsCommandTab.twin:
        return [
          SliverToBoxAdapter(
            child: _SectionCard(
              title: 'Estate Digital Twin™',
              icon: LucideIcons.box,
              child: _EstateTwinCard(twin: snap.estateTwin),
            ),
          ),
        ];
      case PmsCommandTab.analytics:
        return [
          SliverToBoxAdapter(
            child: _SectionCard(
              title: 'Smart Inventory Intelligence™',
              icon: LucideIcons.brain,
              child: _IntelligenceList(items: snap.inventoryIntelligence),
            ),
          ),
          SliverToBoxAdapter(
            child: _SectionCard(
              title: 'AI Property Assistant™',
              icon: LucideIcons.sparkles,
              child: _AiAssistantPanel(
                insights: snap.aiInsights,
                properties: snap.properties,
                service: ref.read(pmsServiceProvider),
              ),
            ),
          ),
        ];
      case PmsCommandTab.approvals:
        return [
          SliverToBoxAdapter(
            child: _SectionCard(
              title: 'Approval Workflow Queue',
              icon: LucideIcons.shieldCheck,
              child: _ApprovalList(steps: snap.approvalsPending),
            ),
          ),
        ];
    }
  }
}

class _PmsHeader extends StatelessWidget {
  const _PmsHeader({
    required this.ticker,
    required this.fromRemote,
    required this.onCreate,
    required this.onRefresh,
  });

  final String ticker;
  final bool fromRemote;
  final VoidCallback onCreate;
  final Future<void> Function() onRefresh;

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
                'Property Command Center™',
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
                    onPressed: onCreate,
                    icon: const Icon(LucideIcons.plus, size: 16),
                    label: const Text('Create Property'),
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
                      'Enterprise inventory · hierarchy · lifecycle',
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
                          'Enterprise inventory · hierarchy · lifecycle',
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

  final List<PmsInventoryKpi> kpis;

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

class _TabBar extends StatelessWidget {
  const _TabBar({required this.selected, required this.onSelect});

  final PmsCommandTab selected;
  final ValueChanged<PmsCommandTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: PmsCommandTab.values.map((tab) {
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
                      style: Theme.of(context).textTheme.titleMedium,
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

class _InventoryPanel extends StatelessWidget {
  const _InventoryPanel({
    required this.properties,
    required this.ui,
    required this.controller,
  });

  final List<PmsProperty> properties;
  final PmsUiState ui;
  final PmsController controller;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Inventory',
      icon: LucideIcons.building2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search title, code, city, tag…',
              prefixIcon: Icon(LucideIcons.search, size: 18),
              isDense: true,
            ),
            onChanged: controller.setSearch,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              FilterChip(
                label: const Text('All'),
                selected: ui.statusFilter == null,
                onSelected: (_) => controller.setFilter(null),
              ),
              ...[
                InventoryStatus.available,
                InventoryStatus.reserved,
                InventoryStatus.sold,
                InventoryStatus.underContract,
              ].map(
                (s) => FilterChip(
                  label: Text(s.label),
                  selected: ui.statusFilter == s,
                  onSelected: (_) => controller.setFilter(
                    ui.statusFilter == s ? null : s,
                  ),
                ),
              ),
            ],
          ),
          if (ui.selectedPropertyIds.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Text('${ui.selectedPropertyIds.length} selected'),
                ActionChip(
                  avatar: const Icon(LucideIcons.upload, size: 14),
                  label: const Text('Bulk Publish'),
                  onPressed: () {
                    controller.setMessage(
                      'Bulk Publish queued for ${ui.selectedPropertyIds.length} '
                      'properties (placeholder).',
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Bulk Publish — coming soon')),
                    );
                  },
                ),
                ActionChip(
                  avatar: const Icon(LucideIcons.archive, size: 14),
                  label: const Text('Archive'),
                  onPressed: () {
                    controller.setMessage(
                      'Archive queued for ${ui.selectedPropertyIds.length} '
                      'properties (placeholder).',
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Archive — coming soon')),
                    );
                  },
                ),
                TextButton(
                  onPressed: controller.clearSelection,
                  child: const Text('Clear'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          if (properties.isEmpty)
            const Text('No properties match the current filters.')
          else
            ...properties.map(
              (p) => _PropertyRow(
                property: p,
                selected: ui.selectedPropertyIds.contains(p.id),
                onToggle: () => controller.toggleSelect(p.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _PropertyRow extends StatelessWidget {
  const _PropertyRow({
    required this.property,
    required this.selected,
    required this.onToggle,
  });

  final PmsProperty property;
  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      child: ListTile(
        leading: Checkbox(value: selected, onChanged: (_) => onToggle()),
        title: Text(property.title),
        subtitle: Text(
          [
            property.propertyCode ?? property.slug,
            property.city,
            property.inventoryStatus.label,
            'Score ${property.performanceScore.toStringAsFixed(0)}',
          ].whereType<String>().join(' · '),
        ),
        trailing: Text(
          property.formatPrice(property.listingPrice),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        onTap: onToggle,
      ),
    );
  }
}

class _EstateTwinCard extends StatelessWidget {
  const _EstateTwinCard({required this.twin});

  final PmsEstateTwin twin;

  @override
  Widget build(BuildContext context) {
    final crumbs = twin.hierarchySample.isEmpty
        ? PmsDemo.hierarchySample
        : twin.hierarchySample;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          twin.estateName,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (var i = 0; i < crumbs.length; i++) ...[
              if (i > 0)
                const Icon(LucideIcons.chevronRight, size: 14),
              Chip(
                label: Text(crumbs[i]),
                visualDensity: VisualDensity.compact,
                backgroundColor: i == crumbs.length - 1
                    ? AppColors.gold.withValues(alpha: 0.25)
                    : null,
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 520;
            final tiles = [
              _twinStat('Available', twin.availableUnits, context),
              _twinStat('Reserved', twin.reservedUnits, context),
              _twinStat('Sold', twin.soldUnits, context),
            ];
            if (wide) {
              return Row(
                children: tiles
                    .map((t) => Expanded(child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: t,
                        )))
                    .toList(),
              );
            }
            return Column(
              children: tiles
                  .map((t) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: t,
                      ))
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          twin.constructionLabel,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _twinStat(String label, int value, BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: AppRadius.cardBorder,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            Text(
              '$value',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntelligenceList extends StatelessWidget {
  const _IntelligenceList({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (item) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.radar, color: AppColors.gold),
              title: Text(item),
              dense: true,
            ),
          )
          .toList(),
    );
  }
}

class _LifecycleList extends StatelessWidget {
  const _LifecycleList({required this.events});

  final List<PmsLifecycleEvent> events;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d · HH:mm');
    return Column(
      children: events.map((e) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(LucideIcons.circleDot, color: AppColors.gold),
          title: Text(e.title),
          subtitle: Text(
            [
              e.propertyTitle,
              e.description,
              if (e.occurredAt != null) fmt.format(e.occurredAt!),
            ].whereType<String>().join(' · '),
          ),
          dense: true,
        );
      }).toList(),
    );
  }
}

class _InspectionList extends StatelessWidget {
  const _InspectionList({required this.inspections});

  final List<PmsInspection> inspections;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('EEE d MMM · HH:mm');
    return Column(
      children: inspections.map((i) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(LucideIcons.calendarCheck, color: AppColors.gold),
          title: Text(i.propertyTitle ?? i.propertyId),
          subtitle: Text(
            '${i.inspectionType.label} · ${i.status.label} · '
            '${fmt.format(i.scheduledAt)}'
            '${i.visitorName != null ? ' · ${i.visitorName}' : ''}',
          ),
          dense: true,
        );
      }).toList(),
    );
  }
}

class _ApprovalList extends StatelessWidget {
  const _ApprovalList({required this.steps});

  final List<PmsApprovalStep> steps;

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) {
      return const Text('No pending approvals.');
    }
    return Column(
      children: steps.map((s) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading:
              const Icon(LucideIcons.shieldAlert, color: AppColors.gold),
          title: Text(s.propertyTitle ?? s.propertyId),
          subtitle: Text(
            '${s.step.label} · ${s.status}'
            '${s.comments != null ? ' · ${s.comments}' : ''}',
          ),
          trailing: Chip(
            label: Text('Step ${s.stepOrder}'),
            visualDensity: VisualDensity.compact,
          ),
          dense: true,
        );
      }).toList(),
    );
  }
}

class _AiAssistantPanel extends StatelessWidget {
  const _AiAssistantPanel({
    required this.insights,
    required this.properties,
    required this.service,
  });

  final List<PmsAiInsight> insights;
  final List<PmsProperty> properties;
  final PmsService service;

  @override
  Widget build(BuildContext context) {
    final sample = properties.isNotEmpty ? properties.first : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...insights.map(
          (i) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(LucideIcons.sparkles, color: AppColors.gold),
            title: Text(i.title),
            subtitle: Text('${i.body}\nAI-generated · ${i.category}'),
            isThreeLine: true,
            dense: true,
          ),
        ),
        if (sample != null) ...[
          const Divider(),
          Text(
            'Live stub summary',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Text(service.generateAiSummary(sample)),
        ],
      ],
    );
  }
}

class _PropertyWizard extends StatelessWidget {
  const _PropertyWizard({
    required this.draft,
    required this.onChanged,
    required this.onSubmit,
  });

  final PmsWizardDraft draft;
  final ValueChanged<PmsWizardDraft> onChanged;
  final VoidCallback onSubmit;

  static const _steps = [
    'Basic',
    'Location',
    'Specs',
    'Amenities',
    'Pricing',
    'Media',
    'Documents',
    'Publishing',
  ];

  @override
  Widget build(BuildContext context) {
    final step = draft.step.clamp(0, _steps.length - 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stepper(
          currentStep: step,
          onStepTapped: (i) => onChanged(draft.copyWith(step: i)),
          controlsBuilder: (context, details) {
            return Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Wrap(
                spacing: 8,
                children: [
                  if (step < _steps.length - 1)
                    FilledButton(
                      onPressed: () =>
                          onChanged(draft.copyWith(step: step + 1)),
                      child: const Text('Continue'),
                    )
                  else
                    FilledButton(
                      onPressed: onSubmit,
                      child: const Text('Finish'),
                    ),
                  if (step > 0)
                    TextButton(
                      onPressed: () =>
                          onChanged(draft.copyWith(step: step - 1)),
                      child: const Text('Back'),
                    ),
                ],
              ),
            );
          },
          steps: [
            for (var i = 0; i < _steps.length; i++)
              Step(
                title: Text(_steps[i]),
                isActive: i <= step,
                state: i < step
                    ? StepState.complete
                    : i == step
                        ? StepState.editing
                        : StepState.indexed,
                content: _stepContent(context, i),
              ),
          ],
        ),
      ],
    );
  }

  Widget _stepContent(BuildContext context, int i) {
    switch (i) {
      case 0:
        return Column(
          children: [
            TextFormField(
              initialValue: draft.title,
              decoration: const InputDecoration(labelText: 'Title'),
              onChanged: (v) => onChanged(draft.copyWith(title: v)),
            ),
            TextFormField(
              initialValue: draft.propertyCode,
              decoration: const InputDecoration(labelText: 'Property code'),
              onChanged: (v) => onChanged(draft.copyWith(propertyCode: v)),
            ),
            DropdownButtonFormField<String>(
              key: ValueKey('type-${draft.propertyType}'),
              initialValue: draft.propertyType,
              decoration: const InputDecoration(labelText: 'Type'),
              items: const [
                'apartment',
                'duplex',
                'penthouse',
                'maisonette',
                'studio',
                'land',
              ]
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(draft.copyWith(propertyType: v));
              },
            ),
          ],
        );
      case 1:
        return Column(
          children: [
            TextFormField(
              initialValue: draft.estateName,
              decoration: const InputDecoration(labelText: 'Estate'),
              onChanged: (v) => onChanged(draft.copyWith(estateName: v)),
            ),
            TextFormField(
              initialValue: draft.city,
              decoration: const InputDecoration(labelText: 'City'),
              onChanged: (v) => onChanged(draft.copyWith(city: v)),
            ),
            TextFormField(
              initialValue: draft.addressLine,
              decoration: const InputDecoration(labelText: 'Address'),
              onChanged: (v) => onChanged(draft.copyWith(addressLine: v)),
            ),
          ],
        );
      case 2:
        return Column(
          children: [
            _numField(
              label: 'Bedrooms',
              value: draft.bedrooms,
              onChanged: (v) => onChanged(draft.copyWith(bedrooms: v)),
            ),
            _numField(
              label: 'Bathrooms',
              value: draft.bathrooms,
              onChanged: (v) => onChanged(draft.copyWith(bathrooms: v)),
            ),
            _numField(
              label: 'Built-up area (sqm)',
              value: draft.builtUpAreaSqm ?? 0,
              onChanged: (v) => onChanged(draft.copyWith(builtUpAreaSqm: v)),
            ),
          ],
        );
      case 3:
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: PmsWizardDraft.amenityCatalog.map((a) {
            final selected = draft.amenities.contains(a);
            return FilterChip(
              label: Text(a),
              selected: selected,
              onSelected: (on) {
                final next = [...draft.amenities];
                if (on) {
                  next.add(a);
                } else {
                  next.remove(a);
                }
                onChanged(draft.copyWith(amenities: next));
              },
            );
          }).toList(),
        );
      case 4:
        return Column(
          children: [
            _numField(
              label: 'Listing price (NGN)',
              value: draft.listingPrice ?? 0,
              onChanged: (v) => onChanged(draft.copyWith(listingPrice: v)),
            ),
            _numField(
              label: 'Promo price',
              value: draft.promoPrice ?? 0,
              onChanged: (v) => onChanged(draft.copyWith(promoPrice: v)),
            ),
            _numField(
              label: 'Investor price',
              value: draft.investorPrice ?? 0,
              onChanged: (v) => onChanged(draft.copyWith(investorPrice: v)),
            ),
          ],
        );
      case 5:
        return TextFormField(
          initialValue: draft.mediaNote,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Media notes',
            helperText:
                'Upload adapters land after PMS SQL apply — note gallery / tour URLs here.',
          ),
          onChanged: (v) => onChanged(draft.copyWith(mediaNote: v)),
        );
      case 6:
        return TextFormField(
          initialValue: draft.documentsNote,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Documents',
            helperText: 'Title, survey, C of O refs (placeholder storage).',
          ),
          onChanged: (v) => onChanged(draft.copyWith(documentsNote: v)),
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<PublishWorkflowStatus>(
              key: ValueKey('publish-${draft.publishStatus}'),
              initialValue: draft.publishStatus,
              decoration: const InputDecoration(labelText: 'Publish status'),
              items: PublishWorkflowStatus.values
                  .map(
                    (s) => DropdownMenuItem(value: s, child: Text(s.label)),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(draft.copyWith(publishStatus: v));
              },
            ),
            DropdownButtonFormField<InventoryStatus>(
              key: ValueKey('inventory-${draft.inventoryStatus}'),
              initialValue: draft.inventoryStatus,
              decoration: const InputDecoration(labelText: 'Inventory status'),
              items: InventoryStatus.values
                  .map(
                    (s) => DropdownMenuItem(value: s, child: Text(s.label)),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(draft.copyWith(inventoryStatus: v));
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Finish queues the draft locally until PMS SQL is approved.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
    }
  }

  Widget _numField({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return TextFormField(
      initialValue: value == 0 ? '' : value.toString(),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
      onChanged: (v) => onChanged(double.tryParse(v) ?? 0),
    );
  }
}
