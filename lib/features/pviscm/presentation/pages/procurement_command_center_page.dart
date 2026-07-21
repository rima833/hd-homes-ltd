import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/pviscm/domain/entities/pviscm_models.dart';
import 'package:hdhomesproject/features/pviscm/domain/services/pviscm_service.dart';
import 'package:hdhomesproject/features/pviscm/presentation/providers/pviscm_controller.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Volume 4 Part 13 — Procurement Command Center (PVISCM).
class ProcurementCommandCenterPage extends ConsumerWidget {
  const ProcurementCommandCenterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSnap = ref.watch(pviscmSnapshotProvider);
    final ui = ref.watch(pviscmControllerProvider);
    final controller = ref.read(pviscmControllerProvider.notifier);

    return Scaffold(
      body: asyncSnap.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Failed to load Procurement Command Center: $e'),
        ),
        data: (snap) {
          final tickerKpis = snap.kpis;
          final ticker = tickerKpis.isEmpty
              ? 'Procurement Command Center live'
              : '${tickerKpis[ui.tickerIndex % tickerKpis.length].label}: '
                  '${tickerKpis[ui.tickerIndex % tickerKpis.length].displayValue}';

          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: CustomScrollView(
              slivers: [
                ContainedPadding(
                  child: _PviscmHeader(
                    ticker: ticker,
                    fromRemote: snap.fromRemote,
                    onRefresh: controller.refresh,
                    onOpenAi: () => controller.setTab(PviscmCommandTab.ai),
                    onOpenVendors: () =>
                        controller.setTab(PviscmCommandTab.vendors),
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
                    onCategory: controller.setCategoryFilter,
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
    PviscmCommandCenterSnapshot snap,
    PviscmUiState ui,
    PviscmController controller,
  ) {
    switch (ui.selectedTab) {
      case PviscmCommandTab.overview:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Smart Procurement Command Center™',
              icon: LucideIcons.shoppingCart,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PR → RFQ → PO → GRN · vendors · inventory · logistics',
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
              title: 'Low-stock alerts',
              icon: LucideIcons.alertTriangle,
              child: _InventoryList(
                items: snap.inventory.where((i) => i.isLowStock).toList(),
              ),
            ),
          ),
          ContainedPadding(
            child: _SectionCard(
              title: 'In-transit shipments',
              icon: LucideIcons.truck,
              child: _ShipmentList(
                items: snap.shipments
                    .where((s) => s.status == 'in_transit')
                    .toList(),
              ),
            ),
          ),
        ];
      case PviscmCommandTab.vendors:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Intelligent Supplier Intelligence™',
              icon: LucideIcons.building2,
              child: _VendorList(vendors: controller.filteredVendors(snap)),
            ),
          ),
        ];
      case PviscmCommandTab.requisitions:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Purchase Requisitions',
              icon: LucideIcons.clipboardList,
              child: _RequisitionList(
                items: controller.filteredRequisitions(snap),
              ),
            ),
          ),
        ];
      case PviscmCommandTab.rfqs:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'RFQs & Quote Comparisons',
              icon: LucideIcons.fileQuestion,
              child: _RfqList(items: snap.rfqs),
            ),
          ),
        ];
      case PviscmCommandTab.purchaseOrders:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Enterprise Purchase Orders',
              icon: LucideIcons.fileText,
              child: _PoList(items: controller.filteredPurchaseOrders(snap)),
            ),
          ),
        ];
      case PviscmCommandTab.receiving:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Goods Receipts (GRN)',
              icon: LucideIcons.packageCheck,
              child: _GrnList(items: snap.goodsReceipts),
            ),
          ),
        ];
      case PviscmCommandTab.inventory:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Enterprise Inventory Intelligence™',
              icon: LucideIcons.boxes,
              child: _InventoryList(
                items: controller.filteredInventory(snap),
              ),
            ),
          ),
        ];
      case PviscmCommandTab.warehouses:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Construction Material Control™',
              icon: LucideIcons.warehouse,
              child: _WarehouseList(items: snap.warehouses),
            ),
          ),
        ];
      case PviscmCommandTab.logistics:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Logistics Shipments',
              icon: LucideIcons.truck,
              child: _ShipmentList(items: snap.shipments),
            ),
          ),
        ];
      case PviscmCommandTab.approvals:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Procurement Approvals',
              icon: LucideIcons.checkCircle,
              child: _ApprovalList(items: snap.approvals),
            ),
          ),
        ];
      case PviscmCommandTab.analytics:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Executive Procurement Intelligence Center™',
              icon: LucideIcons.barChart3,
              child: _ReportList(reports: snap.reports),
            ),
          ),
        ];
      case PviscmCommandTab.ai:
        final service = ref.read(pviscmServiceProvider);
        final briefing = service.generateIntelligenceBriefing(snap);
        final signals = PviscmService.detectProcurementSignals(snap);
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Smart Procurement Intelligence™',
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

class _PviscmHeader extends StatelessWidget {
  const _PviscmHeader({
    required this.ticker,
    required this.fromRemote,
    required this.onRefresh,
    required this.onOpenAi,
    required this.onOpenVendors,
  });

  final String ticker;
  final bool fromRemote;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpenAi;
  final VoidCallback onOpenVendors;

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
                    'Procurement Command Center',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'PVISCM · Vendors · Inventory · Supply Chain',
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
                    label: const Text('Procurement AI'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.deepBlack,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: onOpenVendors,
                    icon: const Icon(LucideIcons.building2, size: 16),
                    label: const Text('Vendors'),
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
            'Procurement, Vendor, Inventory & Supply Chain Management',
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

  final void Function(PviscmCommandTab) onSelect;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        PviscmCommandTab.overview,
        'Procurement Command™',
        LucideIcons.shoppingCart
      ),
      (PviscmCommandTab.vendors, 'Supplier Intel™', LucideIcons.building2),
      (PviscmCommandTab.inventory, 'Inventory Intel™', LucideIcons.boxes),
      (PviscmCommandTab.warehouses, 'Material Control™', LucideIcons.warehouse),
      (PviscmCommandTab.analytics, 'Exec Procurement™', LucideIcons.barChart3),
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

  final List<PviscmKpi> kpis;

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
    required this.onCategory,
  });

  final PviscmUiState ui;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onStatus;
  final ValueChanged<String?> onCategory;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Search vendors, PRs, POs, SKUs…',
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
                label: const Text('Preferred'),
                selected: ui.statusFilter == 'preferred',
                onSelected: (_) => onStatus('preferred'),
              ),
              FilterChip(
                label: const Text('Low stock'),
                selected: ui.statusFilter == 'low_stock',
                onSelected: (_) => onStatus('low_stock'),
              ),
              FilterChip(
                label: const Text('Issued'),
                selected: ui.statusFilter == 'issued',
                onSelected: (_) => onStatus('issued'),
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

  final PviscmCommandTab selected;
  final void Function(PviscmCommandTab) onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: PviscmCommandTab.values
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

  final List<PviscmActivity> activities;

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

class _VendorList extends StatelessWidget {
  const _VendorList({required this.vendors});

  final List<PviscmVendor> vendors;

  @override
  Widget build(BuildContext context) {
    if (vendors.isEmpty) return const Text('No vendors');
    return Column(
      children: vendors
          .map(
            (v) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(LucideIcons.building2, size: 18),
              title: Text(v.name),
              subtitle: Text(
                '${v.code ?? ''} · ${v.tier} · ${v.city ?? ''} · ★${v.ratingAvg.toStringAsFixed(1)}',
              ),
              trailing: Text(v.status),
            ),
          )
          .toList(),
    );
  }
}

class _RequisitionList extends StatelessWidget {
  const _RequisitionList({required this.items});

  final List<PviscmRequisition> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('No requisitions');
    return Column(
      children: items
          .map(
            (r) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(LucideIcons.clipboardList, size: 18),
              title: Text(r.title),
              subtitle: Text(
                '${r.code ?? ''} · ${r.requesterLabel ?? ''} · ${r.priority}',
              ),
              trailing: Text(r.status),
            ),
          )
          .toList(),
    );
  }
}

class _RfqList extends StatelessWidget {
  const _RfqList({required this.items});

  final List<PviscmRfq> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('No RFQs');
    return Column(
      children: items
          .map(
            (r) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(LucideIcons.fileQuestion, size: 18),
              title: Text(r.title),
              subtitle: Text(r.code ?? ''),
              trailing: Text(r.status),
            ),
          )
          .toList(),
    );
  }
}

class _PoList extends StatelessWidget {
  const _PoList({required this.items});

  final List<PviscmPurchaseOrder> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('No purchase orders');
    return Column(
      children: items
          .map(
            (p) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(LucideIcons.fileText, size: 18),
              title: Text(p.title),
              subtitle: Text(
                '${p.code ?? ''} · ${p.vendorName ?? ''} · ₦${p.totalAmount.toStringAsFixed(0)}',
              ),
              trailing: Text(p.status),
            ),
          )
          .toList(),
    );
  }
}

class _GrnList extends StatelessWidget {
  const _GrnList({required this.items});

  final List<PviscmGoodsReceipt> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('No goods receipts');
    return Column(
      children: items
          .map(
            (g) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(LucideIcons.packageCheck, size: 18),
              title: Text(g.title),
              subtitle: Text('${g.code ?? ''} · ${g.warehouseLabel ?? ''}'),
              trailing: Text(g.status),
            ),
          )
          .toList(),
    );
  }
}

class _InventoryList extends StatelessWidget {
  const _InventoryList({required this.items});

  final List<PviscmInventoryItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('No inventory items');
    return Column(
      children: items
          .map(
            (i) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(
                LucideIcons.boxes,
                size: 18,
                color: i.isLowStock ? AppColors.gold : null,
              ),
              title: Text(i.name),
              subtitle: Text(
                '${i.sku ?? ''} · ${i.onHand} ${i.uom} · reorder ${i.reorderPoint}',
              ),
              trailing: Text(i.status),
            ),
          )
          .toList(),
    );
  }
}

class _WarehouseList extends StatelessWidget {
  const _WarehouseList({required this.items});

  final List<PviscmWarehouse> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('No warehouses');
    return Column(
      children: items
          .map(
            (w) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(LucideIcons.warehouse, size: 18),
              title: Text(w.name),
              subtitle: Text('${w.code ?? ''} · ${w.locationLabel ?? ''}'),
              trailing: Text(w.isDefault ? 'default' : w.status),
            ),
          )
          .toList(),
    );
  }
}

class _ShipmentList extends StatelessWidget {
  const _ShipmentList({required this.items});

  final List<PviscmShipment> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('No shipments');
    return Column(
      children: items
          .map(
            (s) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(LucideIcons.truck, size: 18),
              title: Text(s.code),
              subtitle: Text(
                '${s.carrier ?? ''} · ${s.trackingNumber ?? ''} · ${s.destinationLabel ?? ''}',
              ),
              trailing: Text(s.status),
            ),
          )
          .toList(),
    );
  }
}

class _ApprovalList extends StatelessWidget {
  const _ApprovalList({required this.items});

  final List<PviscmApproval> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('No approvals');
    return Column(
      children: items
          .map(
            (a) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(LucideIcons.checkCircle, size: 18),
              title: Text(a.title),
              subtitle: Text(
                '${a.entityType} · ${a.requesterLabel ?? ''}',
              ),
              trailing: Text(a.status),
            ),
          )
          .toList(),
    );
  }
}

class _ReportList extends StatelessWidget {
  const _ReportList({required this.reports});

  final List<PviscmReport> reports;

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

  final List<PviscmAiInsight> insights;

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
