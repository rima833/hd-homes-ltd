import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/eafms/domain/entities/eafms_models.dart';
import 'package:hdhomesproject/features/eafms/domain/services/eafms_service.dart';
import 'package:hdhomesproject/features/eafms/presentation/providers/eafms_controller.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Volume 4 Part 14 — Asset Command Center (EAFMS).
class AssetCommandCenterPage extends ConsumerWidget {
  const AssetCommandCenterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSnap = ref.watch(eafmsSnapshotProvider);
    final ui = ref.watch(eafmsControllerProvider);
    final controller = ref.read(eafmsControllerProvider.notifier);

    return Scaffold(
      body: asyncSnap.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Failed to load Asset Command Center: $e'),
        ),
        data: (snap) {
          final tickerKpis = snap.kpis;
          final ticker = tickerKpis.isEmpty
              ? 'Asset Command Center live'
              : '${tickerKpis[ui.tickerIndex % tickerKpis.length].label}: '
                  '${tickerKpis[ui.tickerIndex % tickerKpis.length].displayValue}';

          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: CustomScrollView(
              slivers: [
                ContainedPadding(
                  child: _EafmsHeader(
                    ticker: ticker,
                    fromRemote: snap.fromRemote,
                    onRefresh: controller.refresh,
                    onOpenAi: () => controller.setTab(EafmsCommandTab.ai),
                    onOpenRegister: () =>
                        controller.setTab(EafmsCommandTab.register),
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
                    onClass: controller.setClassFilter,
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
    EafmsCommandCenterSnapshot snap,
    EafmsUiState ui,
    EafmsController controller,
  ) {
    switch (ui.selectedTab) {
      case EafmsCommandTab.overview:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Enterprise Asset Command Center™',
              icon: LucideIcons.package,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Register · facilities · maintenance · fleet · utilities',
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
              title: 'Maintenance due',
              icon: LucideIcons.wrench,
              child: _MaintenanceList(
                items: snap.maintenance.where((m) => m.isDue).toList(),
              ),
            ),
          ),
          ContainedPadding(
            child: _SectionCard(
              title: 'Open work orders',
              icon: LucideIcons.clipboardList,
              child: _WorkOrderList(
                items: snap.workOrders
                    .where((w) => {'open', 'assigned'}.contains(w.status))
                    .toList(),
              ),
            ),
          ),
        ];
      case EafmsCommandTab.register:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Enterprise Asset Register',
              icon: LucideIcons.tags,
              child: _AssetList(assets: controller.filteredAssets(snap)),
            ),
          ),
        ];
      case EafmsCommandTab.facilities:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Smart Facility Operations™',
              icon: LucideIcons.building2,
              child: _FacilityList(
                items: controller.filteredFacilities(snap),
              ),
            ),
          ),
        ];
      case EafmsCommandTab.maintenance:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Intelligent Predictive Maintenance™',
              icon: LucideIcons.wrench,
              child: _MaintenanceList(items: snap.maintenance),
            ),
          ),
        ];
      case EafmsCommandTab.workOrders:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Work Orders',
              icon: LucideIcons.clipboardList,
              child: _WorkOrderList(
                items: controller.filteredWorkOrders(snap),
              ),
            ),
          ),
        ];
      case EafmsCommandTab.inspections:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Inspections',
              icon: LucideIcons.clipboardCheck,
              child: _InspectionList(items: snap.inspections),
            ),
          ),
        ];
      case EafmsCommandTab.fleet:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Fleet Vehicles',
              icon: LucideIcons.truck,
              child: _FleetList(items: snap.fleet),
            ),
          ),
          ContainedPadding(
            child: _SectionCard(
              title: 'Fuel logs',
              icon: LucideIcons.fuel,
              child: _FuelLogList(items: snap.fuelLogs),
            ),
          ),
        ];
      case EafmsCommandTab.utilities:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Utility Meters & Readings',
              icon: LucideIcons.zap,
              child: _UtilityList(items: snap.utilities),
            ),
          ),
        ];
      case EafmsCommandTab.warranties:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Warranties',
              icon: LucideIcons.shield,
              child: _WarrantyList(items: snap.warranties),
            ),
          ),
        ];
      case EafmsCommandTab.depreciation:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Asset Depreciation',
              icon: LucideIcons.trendingDown,
              child: _DepreciationList(items: snap.depreciation),
            ),
          ),
        ];
      case EafmsCommandTab.analytics:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Executive Asset Intelligence Center™',
              icon: LucideIcons.barChart3,
              child: _ReportList(reports: snap.reports),
            ),
          ),
          ContainedPadding(
            child: _SectionCard(
              title: 'Construction Equipment Intelligence™',
              icon: LucideIcons.hardHat,
              child: _AssetList(
                assets: snap.assets
                    .where((a) => a.assetClass == 'construction')
                    .toList(),
              ),
            ),
          ),
        ];
      case EafmsCommandTab.ai:
        final service = ref.read(eafmsServiceProvider);
        final briefing = service.generateIntelligenceBriefing(snap);
        final signals = EafmsService.detectAssetSignals(snap);
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Asset Intelligence™',
              icon: LucideIcons.sparkles,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(briefing),
                  const SizedBox(height: 8),
                  Text(
                    snap.aiDisclaimer,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.gold,
                          fontStyle: FontStyle.italic,
                        ),
                  ),
                  const Divider(height: 24),
                  ...signals.map(
                    (s) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const Icon(
                        LucideIcons.alertTriangle,
                        size: 16,
                        color: AppColors.gold,
                      ),
                      title: Text(s),
                    ),
                  ),
                  const Divider(height: 24),
                  _AiInsightList(insights: snap.aiInsights),
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
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(child: child);
  }
}

class _EafmsHeader extends StatelessWidget {
  const _EafmsHeader({
    required this.ticker,
    required this.fromRemote,
    required this.onRefresh,
    required this.onOpenAi,
    required this.onOpenRegister,
  });

  final String ticker;
  final bool fromRemote;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpenAi;
  final VoidCallback onOpenRegister;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
                    'Asset Command Center',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'EAFMS · Facilities · Maintenance · Fleet',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.white.withValues(alpha: 0.7),
                        ),
                  ),
                ],
              );
              final actions = Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (fromRemote ? Colors.green : AppColors.gold)
                          .withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: fromRemote ? Colors.greenAccent : AppColors.gold,
                      ),
                    ),
                    child: Text(
                      fromRemote ? 'Live' : 'Demo',
                      style: TextStyle(
                        color: fromRemote ? Colors.greenAccent : AppColors.gold,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: onOpenAi,
                    icon: const Icon(LucideIcons.sparkles, size: 16),
                    label: const Text('Asset AI'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.deepBlack,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: onOpenRegister,
                    icon: const Icon(LucideIcons.tags, size: 16),
                    label: const Text('Register'),
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
            'Enterprise Asset, Facilities & Maintenance Management',
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

  final void Function(EafmsCommandTab) onSelect;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        EafmsCommandTab.overview,
        'Asset Command™',
        LucideIcons.package
      ),
      (
        EafmsCommandTab.maintenance,
        'Predictive Maint™',
        LucideIcons.wrench
      ),
      (
        EafmsCommandTab.facilities,
        'Facility Ops™',
        LucideIcons.building2
      ),
      (
        EafmsCommandTab.analytics,
        'Equip Intel™',
        LucideIcons.hardHat
      ),
      (
        EafmsCommandTab.analytics,
        'Exec Assets™',
        LucideIcons.barChart3
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

  final List<EafmsKpi> kpis;

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
                          color: k.status == 'watch'
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
    required this.onClass,
  });

  final EafmsUiState ui;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onStatus;
  final ValueChanged<String?> onClass;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Search assets, WOs, facilities…',
              prefixIcon: const Icon(LucideIcons.search, size: 18),
              border: OutlineInputBorder(
                borderRadius: AppRadius.cardBorder,
              ),
              isDense: true,
            ),
            onChanged: onSearch,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: const Text('All status'),
                selected: ui.statusFilter == null,
                onSelected: (_) => onStatus(null),
              ),
              FilterChip(
                label: const Text('Active'),
                selected: ui.statusFilter == 'active',
                onSelected: (_) => onStatus('active'),
              ),
              FilterChip(
                label: const Text('In maintenance'),
                selected: ui.statusFilter == 'in_maintenance',
                onSelected: (_) => onStatus('in_maintenance'),
              ),
              FilterChip(
                label: const Text('Open'),
                selected: ui.statusFilter == 'open',
                onSelected: (_) => onStatus('open'),
              ),
              FilterChip(
                label: const Text('Construction'),
                selected: ui.classFilter == 'construction',
                onSelected: (_) => onClass(
                  ui.classFilter == 'construction' ? null : 'construction',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.selected, required this.onSelect});

  final EafmsCommandTab selected;
  final void Function(EafmsCommandTab) onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: EafmsCommandTab.values
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
    );
  }
}

class _ActivityList extends StatelessWidget {
  const _ActivityList({required this.activities});

  final List<EafmsActivity> activities;

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

class _AssetList extends StatelessWidget {
  const _AssetList({required this.assets});

  final List<EafmsAsset> assets;

  @override
  Widget build(BuildContext context) {
    if (assets.isEmpty) return const Text('No assets');
    return Column(
      children: assets
          .map(
            (a) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(
                LucideIcons.package,
                size: 18,
                color: a.isInMaintenance ? AppColors.gold : null,
              ),
              title: Text(a.name),
              subtitle: Text(
                '${a.assetTag ?? ''} · ${a.assetClass} · ${a.facilityName ?? ''}',
              ),
              trailing: Text(a.status),
            ),
          )
          .toList(),
    );
  }
}

class _FacilityList extends StatelessWidget {
  const _FacilityList({required this.items});

  final List<EafmsFacility> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('No facilities');
    return Column(
      children: items
          .map(
            (f) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(LucideIcons.building2, size: 18),
              title: Text(f.name),
              subtitle: Text(
                '${f.code ?? ''} · ${f.facilityType} · ${f.city ?? ''}',
              ),
              trailing: Text(f.status),
            ),
          )
          .toList(),
    );
  }
}

class _WorkOrderList extends StatelessWidget {
  const _WorkOrderList({required this.items});

  final List<EafmsWorkOrder> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('No work orders');
    return Column(
      children: items
          .map(
            (w) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(LucideIcons.clipboardList, size: 18),
              title: Text(w.title),
              subtitle: Text(
                '${w.code ?? ''} · ${w.priority} · ${w.assigneeLabel ?? ''}',
              ),
              trailing: Text(w.status),
            ),
          )
          .toList(),
    );
  }
}

class _MaintenanceList extends StatelessWidget {
  const _MaintenanceList({required this.items});

  final List<EafmsMaintenanceItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('No maintenance items');
    return Column(
      children: items
          .map(
            (m) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(
                LucideIcons.wrench,
                size: 18,
                color: m.isDue ? AppColors.gold : null,
              ),
              title: Text(m.title),
              subtitle: Text(
                '${m.code ?? ''} · ${m.planType} · ${m.assetName ?? ''}',
              ),
              trailing: Text(m.status),
            ),
          )
          .toList(),
    );
  }
}

class _InspectionList extends StatelessWidget {
  const _InspectionList({required this.items});

  final List<EafmsInspection> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('No inspections');
    return Column(
      children: items
          .map(
            (i) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(LucideIcons.clipboardCheck, size: 18),
              title: Text(i.title),
              subtitle: Text(
                '${i.code ?? ''} · ${i.inspectionType} · ${i.inspectorLabel ?? ''}',
              ),
              trailing: Text(i.status),
            ),
          )
          .toList(),
    );
  }
}

class _FleetList extends StatelessWidget {
  const _FleetList({required this.items});

  final List<EafmsFleetVehicle> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('No fleet vehicles');
    return Column(
      children: items
          .map(
            (v) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(LucideIcons.truck, size: 18),
              title: Text(v.plateNumber),
              subtitle: Text(
                '${v.makeLabel ?? ''} ${v.modelLabel ?? ''} · ${v.fuelType} · ${v.odometerKm.toStringAsFixed(0)} km',
              ),
              trailing: Text(v.status),
            ),
          )
          .toList(),
    );
  }
}

class _FuelLogList extends StatelessWidget {
  const _FuelLogList({required this.items});

  final List<EafmsFuelLog> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('No fuel logs');
    return Column(
      children: items
          .map(
            (f) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(LucideIcons.fuel, size: 18),
              title: Text('${f.plateNumber ?? f.vehicleId} · ${f.liters}L'),
              subtitle: Text(
                '${f.stationLabel ?? ''} · ₦${f.costAmount.toStringAsFixed(0)}',
              ),
            ),
          )
          .toList(),
    );
  }
}

class _UtilityList extends StatelessWidget {
  const _UtilityList({required this.items});

  final List<EafmsUtilityReading> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('No utility readings');
    return Column(
      children: items
          .map(
            (u) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(LucideIcons.zap, size: 18),
              title: Text(u.meterCode),
              subtitle: Text(
                '${u.meterType} · ${u.readingValue} ${u.unitLabel} · ${u.facilityName ?? ''}',
              ),
            ),
          )
          .toList(),
    );
  }
}

class _WarrantyList extends StatelessWidget {
  const _WarrantyList({required this.items});

  final List<EafmsWarranty> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('No warranties');
    return Column(
      children: items
          .map(
            (w) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(
                LucideIcons.shield,
                size: 18,
                color: w.isExpiringSoon ? AppColors.gold : null,
              ),
              title: Text(w.assetName ?? w.providerLabel ?? 'Warranty'),
              subtitle: Text(
                '${w.providerLabel ?? ''} · ${w.warrantyType}'
                '${w.isExpiringSoon ? ' · expiring soon' : ''}',
              ),
              trailing: Text(w.status),
            ),
          )
          .toList(),
    );
  }
}

class _DepreciationList extends StatelessWidget {
  const _DepreciationList({required this.items});

  final List<EafmsDepreciation> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('No depreciation records');
    return Column(
      children: items
          .map(
            (d) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(LucideIcons.trendingDown, size: 18),
              title: Text(d.assetName ?? d.assetId),
              subtitle: Text(
                '${d.method} · book ₦${d.bookValue.toStringAsFixed(0)} · '
                '₦${d.monthlyAmount.toStringAsFixed(0)}/mo',
              ),
              trailing: Text(d.status),
            ),
          )
          .toList(),
    );
  }
}

class _ReportList extends StatelessWidget {
  const _ReportList({required this.reports});

  final List<EafmsReport> reports;

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) return const Text('No reports');
    return Column(
      children: reports
          .map(
            (r) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(LucideIcons.barChart3, size: 18),
              title: Text(r.title),
              subtitle: Text('${r.periodLabel ?? ''} · ${r.summary ?? ''}'),
            ),
          )
          .toList(),
    );
  }
}

class _AiInsightList extends StatelessWidget {
  const _AiInsightList({required this.insights});

  final List<EafmsAiInsight> insights;

  @override
  Widget build(BuildContext context) {
    if (insights.isEmpty) return const Text('No AI insights');
    return Column(
      children: insights
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
