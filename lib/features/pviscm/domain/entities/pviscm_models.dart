// Volume 4 Part 13 — PVISCM domain models + demo command-center snapshot.

const String kPviscmAiDisclaimer = 'AI-generated — editable / advisory';

enum VendorStatus {
  prospect,
  active,
  preferred,
  suspended,
  blacklisted;

  String get dbValue => name;

  static VendorStatus fromDb(String? raw) => switch (raw) {
        'preferred' => VendorStatus.preferred,
        'suspended' => VendorStatus.suspended,
        'blacklisted' => VendorStatus.blacklisted,
        'prospect' => VendorStatus.prospect,
        _ => VendorStatus.active,
      };
}

enum RequisitionStatus {
  draft,
  submitted,
  approved,
  rejected,
  converted,
  cancelled;

  String get dbValue => name;

  static RequisitionStatus fromDb(String? raw) => switch (raw) {
        'submitted' => RequisitionStatus.submitted,
        'approved' => RequisitionStatus.approved,
        'rejected' => RequisitionStatus.rejected,
        'converted' => RequisitionStatus.converted,
        'cancelled' => RequisitionStatus.cancelled,
        _ => RequisitionStatus.draft,
      };
}

enum PurchaseOrderStatus {
  draft,
  issued,
  acknowledged,
  partial,
  received,
  closed,
  cancelled;

  String get dbValue => name;

  static PurchaseOrderStatus fromDb(String? raw) => switch (raw) {
        'issued' => PurchaseOrderStatus.issued,
        'acknowledged' => PurchaseOrderStatus.acknowledged,
        'partial' => PurchaseOrderStatus.partial,
        'received' => PurchaseOrderStatus.received,
        'closed' => PurchaseOrderStatus.closed,
        'cancelled' => PurchaseOrderStatus.cancelled,
        _ => PurchaseOrderStatus.draft,
      };
}

class PviscmKpi {
  const PviscmKpi({
    required this.label,
    required this.value,
    this.unit = 'count',
    this.changePct,
    this.status = 'ok',
  });

  final String label;
  final double value;
  final String unit;
  final double? changePct;
  final String status;

  String get displayValue {
    if (unit == 'currency') {
      if (value >= 1000000) {
        return '₦${(value / 1000000).toStringAsFixed(1)}M';
      }
      if (value >= 1000) {
        return '₦${(value / 1000).toStringAsFixed(0)}K';
      }
      return '₦${value.toStringAsFixed(0)}';
    }
    return value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  }
}

class PviscmVendor {
  const PviscmVendor({
    required this.id,
    required this.name,
    this.code,
    this.status = 'active',
    this.tier = 'standard',
    this.category,
    this.city,
    this.ratingAvg = 0,
    this.leadTimeDays = 7,
    this.contactEmail,
  });

  final String id;
  final String name;
  final String? code;
  final String status;
  final String tier;
  final String? category;
  final String? city;
  final double ratingAvg;
  final int leadTimeDays;
  final String? contactEmail;

  factory PviscmVendor.fromJson(Map<String, dynamic> json) {
    return PviscmVendor(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      code: json['code'] as String?,
      status: json['status'] as String? ?? 'active',
      tier: json['tier'] as String? ?? 'standard',
      category: json['category'] as String? ??
          (json['category_id'] != null ? 'linked' : null),
      city: json['city'] as String?,
      ratingAvg: (json['rating_avg'] as num?)?.toDouble() ?? 0,
      leadTimeDays: (json['lead_time_days'] as num?)?.toInt() ?? 7,
      contactEmail: json['contact_email'] as String?,
    );
  }
}

class PviscmRequisition {
  const PviscmRequisition({
    required this.id,
    required this.title,
    this.code,
    this.status = 'draft',
    this.requesterLabel,
    this.department,
    this.priority = 'normal',
    this.estimatedTotal = 0,
    this.neededBy,
  });

  final String id;
  final String title;
  final String? code;
  final String status;
  final String? requesterLabel;
  final String? department;
  final String priority;
  final double estimatedTotal;
  final DateTime? neededBy;

  factory PviscmRequisition.fromJson(Map<String, dynamic> json) {
    return PviscmRequisition(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      code: json['code'] as String?,
      status: json['status'] as String? ?? 'draft',
      requesterLabel: json['requester_label'] as String?,
      department: json['department'] as String?,
      priority: json['priority'] as String? ?? 'normal',
      estimatedTotal: (json['estimated_total'] as num?)?.toDouble() ?? 0,
      neededBy: DateTime.tryParse(json['needed_by'] as String? ?? ''),
    );
  }
}

class PviscmRfq {
  const PviscmRfq({
    required this.id,
    required this.title,
    this.code,
    this.status = 'draft',
    this.dueAt,
    this.notes,
  });

  final String id;
  final String title;
  final String? code;
  final String status;
  final DateTime? dueAt;
  final String? notes;

  factory PviscmRfq.fromJson(Map<String, dynamic> json) {
    return PviscmRfq(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      code: json['code'] as String?,
      status: json['status'] as String? ?? 'draft',
      dueAt: DateTime.tryParse(json['due_at'] as String? ?? ''),
      notes: json['notes'] as String?,
    );
  }
}

class PviscmPurchaseOrder {
  const PviscmPurchaseOrder({
    required this.id,
    required this.title,
    this.code,
    this.status = 'draft',
    this.vendorName,
    this.totalAmount = 0,
    this.expectedDate,
    this.orderDate,
  });

  final String id;
  final String title;
  final String? code;
  final String status;
  final String? vendorName;
  final double totalAmount;
  final DateTime? expectedDate;
  final DateTime? orderDate;

  factory PviscmPurchaseOrder.fromJson(Map<String, dynamic> json) {
    return PviscmPurchaseOrder(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      code: json['code'] as String?,
      status: json['status'] as String? ?? 'draft',
      vendorName: json['vendor_name'] as String?,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
      expectedDate: DateTime.tryParse(json['expected_date'] as String? ?? ''),
      orderDate: DateTime.tryParse(json['order_date'] as String? ?? ''),
    );
  }
}

class PviscmGoodsReceipt {
  const PviscmGoodsReceipt({
    required this.id,
    required this.title,
    this.code,
    this.status = 'draft',
    this.warehouseLabel,
    this.receivedBy,
    this.receivedAt,
  });

  final String id;
  final String title;
  final String? code;
  final String status;
  final String? warehouseLabel;
  final String? receivedBy;
  final DateTime? receivedAt;

  factory PviscmGoodsReceipt.fromJson(Map<String, dynamic> json) {
    return PviscmGoodsReceipt(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      code: json['code'] as String?,
      status: json['status'] as String? ?? 'draft',
      warehouseLabel: json['warehouse_label'] as String?,
      receivedBy: json['received_by'] as String?,
      receivedAt: DateTime.tryParse(json['received_at'] as String? ?? ''),
    );
  }
}

class PviscmInventoryItem {
  const PviscmInventoryItem({
    required this.id,
    required this.name,
    this.sku,
    this.category,
    this.uom = 'ea',
    this.onHand = 0,
    this.reorderPoint = 0,
    this.status = 'active',
    this.unitCost = 0,
    this.warehouseName,
  });

  final String id;
  final String name;
  final String? sku;
  final String? category;
  final String uom;
  final double onHand;
  final double reorderPoint;
  final String status;
  final double unitCost;
  final String? warehouseName;

  bool get isLowStock =>
      status == 'low_stock' || (reorderPoint > 0 && onHand <= reorderPoint);

  factory PviscmInventoryItem.fromJson(Map<String, dynamic> json) {
    return PviscmInventoryItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      sku: json['sku'] as String?,
      category: json['category'] as String?,
      uom: json['uom'] as String? ?? 'ea',
      onHand: (json['on_hand'] as num?)?.toDouble() ?? 0,
      reorderPoint: (json['reorder_point'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'active',
      unitCost: (json['unit_cost'] as num?)?.toDouble() ?? 0,
      warehouseName: json['warehouse_name'] as String?,
    );
  }
}

class PviscmWarehouse {
  const PviscmWarehouse({
    required this.id,
    required this.name,
    this.code,
    this.locationLabel,
    this.status = 'active',
    this.isDefault = false,
  });

  final String id;
  final String name;
  final String? code;
  final String? locationLabel;
  final String status;
  final bool isDefault;

  factory PviscmWarehouse.fromJson(Map<String, dynamic> json) {
    return PviscmWarehouse(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      code: json['code'] as String?,
      locationLabel: json['location_label'] as String?,
      status: json['status'] as String? ?? 'active',
      isDefault: json['is_default'] as bool? ?? false,
    );
  }
}

class PviscmShipment {
  const PviscmShipment({
    required this.id,
    required this.code,
    this.carrier,
    this.trackingNumber,
    this.status = 'pending',
    this.originLabel,
    this.destinationLabel,
    this.etaAt,
  });

  final String id;
  final String code;
  final String? carrier;
  final String? trackingNumber;
  final String status;
  final String? originLabel;
  final String? destinationLabel;
  final DateTime? etaAt;

  factory PviscmShipment.fromJson(Map<String, dynamic> json) {
    return PviscmShipment(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      carrier: json['carrier'] as String?,
      trackingNumber: json['tracking_number'] as String?,
      status: json['status'] as String? ?? 'pending',
      originLabel: json['origin_label'] as String?,
      destinationLabel: json['destination_label'] as String?,
      etaAt: DateTime.tryParse(json['eta_at'] as String? ?? ''),
    );
  }
}

class PviscmApproval {
  const PviscmApproval({
    required this.id,
    required this.title,
    this.status = 'pending',
    this.entityType = 'requisition',
    this.requesterLabel,
    this.approverLabel,
    this.amount,
    this.decidedAt,
  });

  final String id;
  final String title;
  final String status;
  final String entityType;
  final String? requesterLabel;
  final String? approverLabel;
  final double? amount;
  final DateTime? decidedAt;

  factory PviscmApproval.fromJson(Map<String, dynamic> json) {
    return PviscmApproval(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      entityType: json['entity_type'] as String? ?? 'requisition',
      requesterLabel: json['requester_label'] as String?,
      approverLabel: json['approver_label'] as String?,
      amount: (json['amount'] as num?)?.toDouble(),
      decidedAt: DateTime.tryParse(json['decided_at'] as String? ?? ''),
    );
  }
}

class PviscmAiInsight {
  const PviscmAiInsight({
    required this.id,
    required this.title,
    required this.body,
    this.insightType = 'advisory',
    this.confidencePct,
    this.editable = true,
    this.disclaimer = kPviscmAiDisclaimer,
  });

  final String id;
  final String title;
  final String body;
  final String insightType;
  final double? confidencePct;
  final bool editable;
  final String disclaimer;

  factory PviscmAiInsight.fromJson(Map<String, dynamic> json) {
    return PviscmAiInsight(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      insightType: json['insight_type'] as String? ?? 'advisory',
      confidencePct: (json['confidence_pct'] as num?)?.toDouble(),
      editable: json['editable'] as bool? ?? true,
      disclaimer: json['disclaimer'] as String? ?? kPviscmAiDisclaimer,
    );
  }
}

class PviscmActivity {
  const PviscmActivity({
    required this.id,
    required this.action,
    required this.summary,
    this.actorLabel,
    this.occurredAt,
  });

  final String id;
  final String action;
  final String summary;
  final String? actorLabel;
  final DateTime? occurredAt;

  factory PviscmActivity.fromJson(Map<String, dynamic> json) {
    return PviscmActivity(
      id: json['id'] as String? ?? '',
      action: json['action'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      actorLabel: json['actor_label'] as String?,
      occurredAt: DateTime.tryParse(json['occurred_at'] as String? ?? ''),
    );
  }
}

class PviscmReport {
  const PviscmReport({
    required this.id,
    required this.title,
    this.reportType = 'spend',
    this.periodLabel,
    this.summary,
  });

  final String id;
  final String title;
  final String reportType;
  final String? periodLabel;
  final String? summary;

  factory PviscmReport.fromJson(Map<String, dynamic> json) {
    return PviscmReport(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      reportType: json['report_type'] as String? ?? 'spend',
      periodLabel: json['period_label'] as String?,
      summary: json['summary'] as String?,
    );
  }
}

class PviscmCommandCenterSnapshot {
  const PviscmCommandCenterSnapshot({
    required this.kpis,
    required this.vendors,
    required this.requisitions,
    required this.rfqs,
    required this.purchaseOrders,
    required this.goodsReceipts,
    required this.inventory,
    required this.warehouses,
    required this.shipments,
    required this.approvals,
    required this.aiInsights,
    required this.activities,
    required this.reports,
    this.fromRemote = false,
    this.loadedAt,
    this.aiDisclaimer = kPviscmAiDisclaimer,
  });

  final List<PviscmKpi> kpis;
  final List<PviscmVendor> vendors;
  final List<PviscmRequisition> requisitions;
  final List<PviscmRfq> rfqs;
  final List<PviscmPurchaseOrder> purchaseOrders;
  final List<PviscmGoodsReceipt> goodsReceipts;
  final List<PviscmInventoryItem> inventory;
  final List<PviscmWarehouse> warehouses;
  final List<PviscmShipment> shipments;
  final List<PviscmApproval> approvals;
  final List<PviscmAiInsight> aiInsights;
  final List<PviscmActivity> activities;
  final List<PviscmReport> reports;
  final bool fromRemote;
  final DateTime? loadedAt;
  final String aiDisclaimer;
}

abstract final class PviscmDemo {
  static PviscmCommandCenterSnapshot snapshot() {
    final now = DateTime.now();
    return PviscmCommandCenterSnapshot(
      kpis: _kpis(),
      vendors: _vendors(),
      requisitions: _requisitions(now),
      rfqs: _rfqs(now),
      purchaseOrders: _purchaseOrders(now),
      goodsReceipts: _goodsReceipts(now),
      inventory: _inventory(),
      warehouses: _warehouses(),
      shipments: _shipments(now),
      approvals: _approvals(now),
      aiInsights: _aiInsights(),
      activities: _activities(now),
      reports: _reports(),
      fromRemote: false,
      loadedAt: now,
    );
  }

  static List<PviscmKpi> _kpis() => const [
        PviscmKpi(label: 'Open PRs', value: 2, status: 'watch'),
        PviscmKpi(label: 'Active Vendors', value: 3),
        PviscmKpi(label: 'Open POs', value: 1, status: 'watch'),
        PviscmKpi(label: 'Low Stock', value: 1, status: 'watch'),
        PviscmKpi(label: 'In Transit', value: 1),
        PviscmKpi(label: 'Pending Approvals', value: 1, status: 'watch'),
        PviscmKpi(label: 'Open Spend', value: 3250000, unit: 'currency'),
      ];

  static List<PviscmVendor> _vendors() => const [
        PviscmVendor(
          id: 'b1300001-0000-4000-8000-000000000001',
          code: 'VEN-001',
          name: 'Apex Cement Ltd',
          status: 'preferred',
          tier: 'strategic',
          category: 'building-materials',
          city: 'Lagos',
          ratingAvg: 4.6,
          leadTimeDays: 5,
          contactEmail: 'orders@apexcavement.ng',
        ),
        PviscmVendor(
          id: 'b1300001-0000-4000-8000-000000000002',
          code: 'VEN-002',
          name: 'Voltline Electricals',
          status: 'active',
          tier: 'preferred',
          category: 'mep-supplies',
          city: 'Abuja',
          ratingAvg: 4.2,
          leadTimeDays: 7,
          contactEmail: 'sales@voltline.ng',
        ),
        PviscmVendor(
          id: 'b1300001-0000-4000-8000-000000000003',
          code: 'VEN-003',
          name: 'TileCraft Nigeria',
          status: 'active',
          tier: 'standard',
          category: 'finishing',
          city: 'Lagos',
          ratingAvg: 3.9,
          leadTimeDays: 10,
          contactEmail: 'hello@tilecraft.ng',
        ),
      ];

  static List<PviscmRequisition> _requisitions(DateTime now) => [
        PviscmRequisition(
          id: 'b1300007-0000-4000-8000-000000000001',
          code: 'PR-2026-1301',
          title: 'Cement restock — Oceanview Phase 2',
          status: 'approved',
          requesterLabel: 'Site Office',
          department: 'Construction',
          priority: 'high',
          estimatedTotal: 3250000,
          neededBy: now.add(const Duration(days: 14)),
        ),
        PviscmRequisition(
          id: 'b1300007-0000-4000-8000-000000000002',
          code: 'PR-2026-1302',
          title: 'MEP cabling for Block C',
          status: 'submitted',
          requesterLabel: 'MEP Lead',
          department: 'Construction',
          priority: 'normal',
          estimatedTotal: 1850000,
          neededBy: now.add(const Duration(days: 21)),
        ),
      ];

  static List<PviscmRfq> _rfqs(DateTime now) => [
        PviscmRfq(
          id: 'b130000a-0000-4000-8000-000000000001',
          code: 'RFQ-2026-1301',
          title: 'RFQ — Cement restock Q3',
          status: 'awarded',
          dueAt: now.add(const Duration(days: 5)),
          notes: 'Awarded to Apex Cement',
        ),
      ];

  static List<PviscmPurchaseOrder> _purchaseOrders(DateTime now) => [
        PviscmPurchaseOrder(
          id: 'b1300010-0000-4000-8000-000000000001',
          code: 'PO-2026-1301',
          title: 'PO — Apex Cement restock',
          status: 'issued',
          vendorName: 'Apex Cement Ltd',
          totalAmount: 3250000,
          orderDate: now,
          expectedDate: now.add(const Duration(days: 7)),
        ),
      ];

  static List<PviscmGoodsReceipt> _goodsReceipts(DateTime now) => [
        PviscmGoodsReceipt(
          id: 'b1300012-0000-4000-8000-000000000001',
          code: 'GRN-2026-1301',
          title: 'Partial receive — Apex cement (awaiting delivery)',
          status: 'draft',
          warehouseLabel: 'Lagos Central Yard',
          receivedBy: 'Warehouse Lead',
          receivedAt: now,
        ),
      ];

  static List<PviscmInventoryItem> _inventory() => const [
        PviscmInventoryItem(
          id: 'b1300016-0000-4000-8000-000000000001',
          sku: 'CEM-42.5-50',
          name: 'Portland Cement 42.5 (50kg)',
          category: 'building-materials',
          uom: 'bag',
          onHand: 85,
          reorderPoint: 200,
          status: 'low_stock',
          unitCost: 6500,
          warehouseName: 'Lagos Central Yard',
        ),
        PviscmInventoryItem(
          id: 'b1300016-0000-4000-8000-000000000002',
          sku: 'CAB-16MM-CU',
          name: '16mm Copper Cable',
          category: 'mep-supplies',
          uom: 'm',
          onHand: 1200,
          reorderPoint: 500,
          status: 'active',
          unitCost: 1850,
          warehouseName: 'Lagos Central Yard',
        ),
        PviscmInventoryItem(
          id: 'b1300016-0000-4000-8000-000000000003',
          sku: 'TILE-60X60-W',
          name: '60x60 Porcelain Tile White',
          category: 'finishing',
          uom: 'box',
          onHand: 55,
          reorderPoint: 40,
          status: 'active',
          unitCost: 28000,
          warehouseName: 'Abuja Site Store',
        ),
      ];

  static List<PviscmWarehouse> _warehouses() => const [
        PviscmWarehouse(
          id: 'b1300014-0000-4000-8000-000000000001',
          code: 'WH-LG-01',
          name: 'Lagos Central Yard',
          locationLabel: 'Ikeja Industrial Estate',
          status: 'active',
          isDefault: true,
        ),
        PviscmWarehouse(
          id: 'b1300014-0000-4000-8000-000000000002',
          code: 'WH-AB-01',
          name: 'Abuja Site Store',
          locationLabel: 'Gwarinpa Site Camp',
          status: 'active',
        ),
      ];

  static List<PviscmShipment> _shipments(DateTime now) => [
        PviscmShipment(
          id: 'b1300019-0000-4000-8000-000000000001',
          code: 'SHIP-2026-1301',
          carrier: 'SwiftHaul Logistics',
          trackingNumber: 'SH-778210',
          status: 'in_transit',
          originLabel: 'Apex Plant — Ewekoro',
          destinationLabel: 'Lagos Central Yard',
          etaAt: now.add(const Duration(days: 2)),
        ),
      ];

  static List<PviscmApproval> _approvals(DateTime now) => [
        PviscmApproval(
          id: 'b1300009-0000-4000-8000-000000000001',
          title: 'Approve PR-2026-1301 Cement restock',
          status: 'approved',
          entityType: 'requisition',
          requesterLabel: 'Site Office',
          approverLabel: 'Construction Manager',
          amount: 3250000,
          decidedAt: now.subtract(const Duration(days: 2)),
        ),
        const PviscmApproval(
          id: 'b1300009-0000-4000-8000-000000000002',
          title: 'Approve PO-2026-1301 Apex Cement',
          status: 'pending',
          entityType: 'purchase_order',
          requesterLabel: 'Procurement',
          amount: 3250000,
        ),
      ];

  static List<PviscmAiInsight> _aiInsights() => const [
        PviscmAiInsight(
          id: 'b130001c-0000-4000-8000-000000000001',
          title: 'Low-stock — cement replenishment critical',
          body:
              'Portland Cement on-hand is below reorder point. Expedite PO-2026-1301 delivery and consider buffer from secondary vendor.',
          insightType: 'inventory_risk',
          confidencePct: 88,
        ),
        PviscmAiInsight(
          id: 'b130001c-0000-4000-8000-000000000002',
          title: 'Vendor scorecard — Apex preferred',
          body:
              'Apex Cement shows strongest delivery reliability on cement RFQs this quarter. Prefer for time-critical pours.',
          insightType: 'supplier_intel',
          confidencePct: 81,
        ),
        PviscmAiInsight(
          id: 'b130001c-0000-4000-8000-000000000003',
          title: 'Spend concentration watch',
          body:
              'Single-vendor concentration on cement exceeds 70% of category spend. Diversify quotes for resilience.',
          insightType: 'spend',
          confidencePct: 76,
        ),
      ];

  static List<PviscmActivity> _activities(DateTime now) => [
        PviscmActivity(
          id: 'b130001b-0000-4000-8000-000000000001',
          action: 'requisition_approved',
          summary: 'PR-2026-1301 Cement restock approved',
          actorLabel: 'Construction Manager',
          occurredAt: now.subtract(const Duration(days: 2)),
        ),
        PviscmActivity(
          id: 'b130001b-0000-4000-8000-000000000002',
          action: 'rfq_awarded',
          summary: 'RFQ-2026-1301 awarded to Apex Cement',
          actorLabel: 'Procurement',
          occurredAt: now.subtract(const Duration(days: 1)),
        ),
        PviscmActivity(
          id: 'b130001b-0000-4000-8000-000000000003',
          action: 'po_issued',
          summary: 'PO-2026-1301 issued to Apex Cement',
          actorLabel: 'Procurement',
          occurredAt: now.subtract(const Duration(hours: 12)),
        ),
        PviscmActivity(
          id: 'b130001b-0000-4000-8000-000000000004',
          action: 'shipment_in_transit',
          summary: 'SHIP-2026-1301 cement load in transit',
          actorLabel: 'SwiftHaul',
          occurredAt: now.subtract(const Duration(hours: 4)),
        ),
      ];

  static List<PviscmReport> _reports() => const [
        PviscmReport(
          id: 'b130001e-0000-4000-8000-000000000001',
          title: 'Procurement Spend Weekly',
          reportType: 'spend',
          periodLabel: 'W28 2026',
          summary:
              'Open PO spend ₦3.25M; low-stock cement driving expedite flags.',
        ),
        PviscmReport(
          id: 'b130001e-0000-4000-8000-000000000002',
          title: 'Vendor Performance Snapshot',
          reportType: 'vendor',
          periodLabel: 'Jul 2026',
          summary:
              'Apex preferred; Voltline active; TileCraft standard tier.',
        ),
      ];
}
