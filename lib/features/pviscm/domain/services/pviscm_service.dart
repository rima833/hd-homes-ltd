import 'package:hdhomesproject/features/pviscm/domain/entities/pviscm_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Loads Procurement Command Center snapshot from Supabase (falls back to demo).
class PviscmService {
  PviscmService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  Future<PviscmCommandCenterSnapshot> loadCommandCenter() async {
    final demo = PviscmDemo.snapshot();
    final client = _client;
    if (client == null) return demo;

    try {
      List<PviscmVendor> vendors = demo.vendors;
      try {
        final rows = await client
            .from('vendors')
            .select()
            .order('name')
            .limit(40);
        if (rows.isNotEmpty) {
          vendors = rows
              .map(
                (e) =>
                    PviscmVendor.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<PviscmRequisition> requisitions = demo.requisitions;
      try {
        final rows = await client
            .from('purchase_requisitions')
            .select()
            .order('created_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          requisitions = rows
              .map(
                (e) => PviscmRequisition.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<PviscmRfq> rfqs = demo.rfqs;
      try {
        final rows = await client
            .from('rfqs')
            .select()
            .order('created_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          rfqs = rows
              .map(
                (e) => PviscmRfq.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<PviscmPurchaseOrder> purchaseOrders = demo.purchaseOrders;
      try {
        final rows = await client
            .from('purchase_orders')
            .select()
            .order('created_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          purchaseOrders = rows
              .map(
                (e) => PviscmPurchaseOrder.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<PviscmGoodsReceipt> goodsReceipts = demo.goodsReceipts;
      try {
        final rows = await client
            .from('goods_receipts')
            .select()
            .order('created_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          goodsReceipts = rows
              .map(
                (e) => PviscmGoodsReceipt.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<PviscmInventoryItem> inventory = demo.inventory;
      try {
        final rows = await client
            .from('inventory_items')
            .select()
            .order('name')
            .limit(50);
        if (rows.isNotEmpty) {
          inventory = rows
              .map(
                (e) => PviscmInventoryItem.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<PviscmWarehouse> warehouses = demo.warehouses;
      try {
        final rows = await client.from('warehouses').select().limit(20);
        if (rows.isNotEmpty) {
          warehouses = rows
              .map(
                (e) => PviscmWarehouse.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<PviscmShipment> shipments = demo.shipments;
      try {
        final rows = await client
            .from('logistics_shipments')
            .select()
            .order('created_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          shipments = rows
              .map(
                (e) => PviscmShipment.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<PviscmApproval> approvals = demo.approvals;
      try {
        final rows = await client
            .from('procurement_approvals')
            .select()
            .order('created_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          approvals = rows
              .map(
                (e) => PviscmApproval.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<PviscmAiInsight> aiInsights = demo.aiInsights;
      try {
        final rows = await client
            .from('procurement_ai_insights')
            .select()
            .order('created_at', ascending: false)
            .limit(20);
        if (rows.isNotEmpty) {
          aiInsights = rows
              .map(
                (e) => PviscmAiInsight.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<PviscmActivity> activities = demo.activities;
      try {
        final rows = await client
            .from('procurement_activity_logs')
            .select()
            .order('occurred_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          activities = rows
              .map(
                (e) => PviscmActivity.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<PviscmReport> reports = demo.reports;
      try {
        final rows = await client
            .from('procurement_reports')
            .select()
            .order('created_at', ascending: false)
            .limit(20);
        if (rows.isNotEmpty) {
          reports = rows
              .map(
                (e) =>
                    PviscmReport.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      final kpis = _deriveKpis(
        vendors: vendors,
        requisitions: requisitions,
        purchaseOrders: purchaseOrders,
        inventory: inventory,
        shipments: shipments,
        approvals: approvals,
      );

      return PviscmCommandCenterSnapshot(
        kpis: kpis,
        vendors: vendors,
        requisitions: requisitions,
        rfqs: rfqs,
        purchaseOrders: purchaseOrders,
        goodsReceipts: goodsReceipts,
        inventory: inventory,
        warehouses: warehouses,
        shipments: shipments,
        approvals: approvals,
        aiInsights: aiInsights,
        activities: activities,
        reports: reports,
        fromRemote: true,
        loadedAt: DateTime.now(),
      );
    } catch (_) {
      return demo;
    }
  }

  List<PviscmKpi> _deriveKpis({
    required List<PviscmVendor> vendors,
    required List<PviscmRequisition> requisitions,
    required List<PviscmPurchaseOrder> purchaseOrders,
    required List<PviscmInventoryItem> inventory,
    required List<PviscmShipment> shipments,
    required List<PviscmApproval> approvals,
  }) {
    final openPrs = requisitions
        .where((r) => {'draft', 'submitted', 'approved'}.contains(r.status))
        .length
        .toDouble();
    final activeVendors = vendors
        .where((v) => {'active', 'preferred'}.contains(v.status))
        .length
        .toDouble();
    final openPos = purchaseOrders
        .where(
          (p) =>
              {'draft', 'issued', 'acknowledged', 'partial'}.contains(p.status),
        )
        .length
        .toDouble();
    final lowStock =
        inventory.where((i) => i.isLowStock).length.toDouble();
    final inTransit = shipments
        .where((s) => s.status == 'in_transit')
        .length
        .toDouble();
    final pendingAppr =
        approvals.where((a) => a.status == 'pending').length.toDouble();
    final openSpend = purchaseOrders
        .where(
          (p) =>
              {'draft', 'issued', 'acknowledged', 'partial'}.contains(p.status),
        )
        .fold<double>(0, (sum, p) => sum + p.totalAmount);

    return [
      PviscmKpi(
        label: 'Open PRs',
        value: openPrs,
        status: openPrs > 0 ? 'watch' : 'ok',
      ),
      PviscmKpi(label: 'Active Vendors', value: activeVendors),
      PviscmKpi(
        label: 'Open POs',
        value: openPos,
        status: openPos > 0 ? 'watch' : 'ok',
      ),
      PviscmKpi(
        label: 'Low Stock',
        value: lowStock,
        status: lowStock > 0 ? 'watch' : 'ok',
      ),
      PviscmKpi(label: 'In Transit', value: inTransit),
      PviscmKpi(
        label: 'Pending Approvals',
        value: pendingAppr,
        status: pendingAppr > 0 ? 'watch' : 'ok',
      ),
      PviscmKpi(label: 'Open Spend', value: openSpend, unit: 'currency'),
    ];
  }

  String generateIntelligenceBriefing(PviscmCommandCenterSnapshot snap) {
    final lowStock = snap.inventory.where((i) => i.isLowStock).length;
    final pending = snap.approvals.where((a) => a.status == 'pending').length;
    final inTransit =
        snap.shipments.where((s) => s.status == 'in_transit').length;
    return 'Smart Procurement Command Center™ advisory brief: '
        '$lowStock low-stock SKU(s), $pending pending approval(s), '
        '$inTransit shipment(s) in transit. Prioritize cement replenishment '
        'and vendor diversification. ${snap.aiDisclaimer}';
  }

  static List<String> detectProcurementSignals(
    PviscmCommandCenterSnapshot snap,
  ) {
    final signals = <String>[];
    if (snap.inventory.any((i) => i.isLowStock)) {
      signals.add('Low-stock inventory items need replenishment');
    }
    if (snap.approvals.any((a) => a.status == 'pending')) {
      signals.add('Procurement approvals waiting on decision');
    }
    if (snap.shipments.any((s) => s.status == 'in_transit')) {
      signals.add('Logistics shipments currently in transit');
    }
    if (snap.requisitions.any((r) => r.status == 'submitted')) {
      signals.add('Submitted requisitions awaiting conversion');
    }
    return signals;
  }
}
