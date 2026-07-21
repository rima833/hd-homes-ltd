// Volume 4 Part 14 — EAFMS domain models + demo command-center snapshot.

const String kEafmsAiDisclaimer = 'AI-generated — editable / advisory';

enum AssetStatus {
  draft,
  active,
  assigned,
  inMaintenance,
  retired,
  disposed,
  lost;

  String get dbValue => switch (this) {
        AssetStatus.inMaintenance => 'in_maintenance',
        _ => name,
      };

  static AssetStatus fromDb(String? raw) => switch (raw) {
        'draft' => AssetStatus.draft,
        'assigned' => AssetStatus.assigned,
        'in_maintenance' => AssetStatus.inMaintenance,
        'retired' => AssetStatus.retired,
        'disposed' => AssetStatus.disposed,
        'lost' => AssetStatus.lost,
        _ => AssetStatus.active,
      };
}

enum WorkOrderStatus {
  draft,
  open,
  assigned,
  inProgress,
  onHold,
  completed,
  cancelled;

  String get dbValue => switch (this) {
        WorkOrderStatus.inProgress => 'in_progress',
        WorkOrderStatus.onHold => 'on_hold',
        _ => name,
      };

  static WorkOrderStatus fromDb(String? raw) => switch (raw) {
        'draft' => WorkOrderStatus.draft,
        'assigned' => WorkOrderStatus.assigned,
        'in_progress' => WorkOrderStatus.inProgress,
        'on_hold' => WorkOrderStatus.onHold,
        'completed' => WorkOrderStatus.completed,
        'cancelled' => WorkOrderStatus.cancelled,
        _ => WorkOrderStatus.open,
      };
}

class EafmsKpi {
  const EafmsKpi({
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

class EafmsAsset {
  const EafmsAsset({
    required this.id,
    required this.name,
    this.assetTag,
    this.assetClass = 'equipment',
    this.status = 'active',
    this.categoryLabel,
    this.facilityName,
    this.serialNumber,
    this.criticality = 'medium',
    this.purchaseCost = 0,
    this.conditionLabel,
  });

  final String id;
  final String name;
  final String? assetTag;
  final String assetClass;
  final String status;
  final String? categoryLabel;
  final String? facilityName;
  final String? serialNumber;
  final String criticality;
  final double purchaseCost;
  final String? conditionLabel;

  bool get isInMaintenance => status == 'in_maintenance';

  factory EafmsAsset.fromJson(Map<String, dynamic> json) {
    return EafmsAsset(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      assetTag: json['asset_tag'] as String?,
      assetClass: json['asset_class'] as String? ?? 'equipment',
      status: json['status'] as String? ?? 'active',
      categoryLabel: json['category_label'] as String?,
      facilityName: json['facility_name'] as String?,
      serialNumber: json['serial_number'] as String?,
      criticality: json['criticality'] as String? ?? 'medium',
      purchaseCost: (json['purchase_cost'] as num?)?.toDouble() ?? 0,
      conditionLabel: json['condition_label'] as String?,
    );
  }
}

class EafmsFacility {
  const EafmsFacility({
    required this.id,
    required this.name,
    this.code,
    this.facilityType = 'office',
    this.status = 'active',
    this.city,
    this.addressLabel,
  });

  final String id;
  final String name;
  final String? code;
  final String facilityType;
  final String status;
  final String? city;
  final String? addressLabel;

  factory EafmsFacility.fromJson(Map<String, dynamic> json) {
    return EafmsFacility(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      code: json['code'] as String?,
      facilityType: json['facility_type'] as String? ?? 'office',
      status: json['status'] as String? ?? 'active',
      city: json['city'] as String?,
      addressLabel: json['address_label'] as String?,
    );
  }
}

class EafmsWorkOrder {
  const EafmsWorkOrder({
    required this.id,
    required this.title,
    this.code,
    this.status = 'open',
    this.priority = 'normal',
    this.assigneeLabel,
    this.assetName,
    this.dueAt,
    this.estimatedCost = 0,
  });

  final String id;
  final String title;
  final String? code;
  final String status;
  final String priority;
  final String? assigneeLabel;
  final String? assetName;
  final DateTime? dueAt;
  final double estimatedCost;

  factory EafmsWorkOrder.fromJson(Map<String, dynamic> json) {
    return EafmsWorkOrder(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      code: json['code'] as String?,
      status: json['status'] as String? ?? 'open',
      priority: json['priority'] as String? ?? 'normal',
      assigneeLabel: json['assignee_label'] as String?,
      assetName: json['asset_name'] as String?,
      dueAt: DateTime.tryParse(json['due_at'] as String? ?? ''),
      estimatedCost: (json['estimated_cost'] as num?)?.toDouble() ?? 0,
    );
  }
}

class EafmsMaintenanceItem {
  const EafmsMaintenanceItem({
    required this.id,
    required this.title,
    this.code,
    this.status = 'scheduled',
    this.planType = 'preventive',
    this.dueAt,
    this.assigneeLabel,
    this.assetName,
  });

  final String id;
  final String title;
  final String? code;
  final String status;
  final String planType;
  final DateTime? dueAt;
  final String? assigneeLabel;
  final String? assetName;

  bool get isDue => status == 'due' || status == 'overdue';

  factory EafmsMaintenanceItem.fromJson(Map<String, dynamic> json) {
    return EafmsMaintenanceItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      code: json['code'] as String?,
      status: json['status'] as String? ?? 'scheduled',
      planType: json['plan_type'] as String? ?? 'preventive',
      dueAt: DateTime.tryParse(
        (json['due_at'] ?? json['performed_at'] ?? '') as String? ?? '',
      ),
      assigneeLabel: json['assignee_label'] as String? ??
          json['performed_by'] as String?,
      assetName: json['asset_name'] as String?,
    );
  }
}

class EafmsInspection {
  const EafmsInspection({
    required this.id,
    required this.title,
    this.code,
    this.status = 'scheduled',
    this.inspectionType = 'routine',
    this.inspectorLabel,
    this.scheduledAt,
    this.scorePct,
  });

  final String id;
  final String title;
  final String? code;
  final String status;
  final String inspectionType;
  final String? inspectorLabel;
  final DateTime? scheduledAt;
  final double? scorePct;

  factory EafmsInspection.fromJson(Map<String, dynamic> json) {
    return EafmsInspection(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      code: json['code'] as String?,
      status: json['status'] as String? ?? 'scheduled',
      inspectionType: json['inspection_type'] as String? ?? 'routine',
      inspectorLabel: json['inspector_label'] as String?,
      scheduledAt: DateTime.tryParse(json['scheduled_at'] as String? ?? ''),
      scorePct: (json['score_pct'] as num?)?.toDouble(),
    );
  }
}

class EafmsFleetVehicle {
  const EafmsFleetVehicle({
    required this.id,
    required this.plateNumber,
    this.makeLabel,
    this.modelLabel,
    this.status = 'active',
    this.fuelType = 'petrol',
    this.odometerKm = 0,
    this.driverLabel,
  });

  final String id;
  final String plateNumber;
  final String? makeLabel;
  final String? modelLabel;
  final String status;
  final String fuelType;
  final double odometerKm;
  final String? driverLabel;

  factory EafmsFleetVehicle.fromJson(Map<String, dynamic> json) {
    return EafmsFleetVehicle(
      id: json['id'] as String? ?? '',
      plateNumber: json['plate_number'] as String? ?? '',
      makeLabel: json['make_label'] as String?,
      modelLabel: json['model_label'] as String?,
      status: json['status'] as String? ?? 'active',
      fuelType: json['fuel_type'] as String? ?? 'petrol',
      odometerKm: (json['odometer_km'] as num?)?.toDouble() ?? 0,
      driverLabel: json['driver_label'] as String?,
    );
  }
}

class EafmsFuelLog {
  const EafmsFuelLog({
    required this.id,
    required this.vehicleId,
    this.liters = 0,
    this.costAmount = 0,
    this.stationLabel,
    this.loggedAt,
    this.plateNumber,
  });

  final String id;
  final String vehicleId;
  final double liters;
  final double costAmount;
  final String? stationLabel;
  final DateTime? loggedAt;
  final String? plateNumber;

  factory EafmsFuelLog.fromJson(Map<String, dynamic> json) {
    return EafmsFuelLog(
      id: json['id'] as String? ?? '',
      vehicleId: json['vehicle_id'] as String? ?? '',
      liters: (json['liters'] as num?)?.toDouble() ?? 0,
      costAmount: (json['cost_amount'] as num?)?.toDouble() ?? 0,
      stationLabel: json['station_label'] as String?,
      loggedAt: DateTime.tryParse(json['logged_at'] as String? ?? ''),
      plateNumber: json['plate_number'] as String?,
    );
  }
}

class EafmsUtilityReading {
  const EafmsUtilityReading({
    required this.id,
    required this.meterCode,
    this.meterType = 'electricity',
    this.readingValue = 0,
    this.unitLabel = 'kWh',
    this.facilityName,
    this.readAt,
  });

  final String id;
  final String meterCode;
  final String meterType;
  final double readingValue;
  final String unitLabel;
  final String? facilityName;
  final DateTime? readAt;

  factory EafmsUtilityReading.fromJson(Map<String, dynamic> json) {
    return EafmsUtilityReading(
      id: json['id'] as String? ?? '',
      meterCode: json['meter_code'] as String? ??
          json['code'] as String? ??
          '',
      meterType: json['meter_type'] as String? ?? 'electricity',
      readingValue: (json['reading_value'] as num?)?.toDouble() ?? 0,
      unitLabel: json['unit_label'] as String? ?? 'kWh',
      facilityName: json['facility_name'] as String?,
      readAt: DateTime.tryParse(json['read_at'] as String? ?? ''),
    );
  }
}

class EafmsWarranty {
  const EafmsWarranty({
    required this.id,
    required this.assetId,
    this.providerLabel,
    this.warrantyType = 'manufacturer',
    this.status = 'active',
    this.endsOn,
    this.assetName,
    this.coverageNotes,
  });

  final String id;
  final String assetId;
  final String? providerLabel;
  final String warrantyType;
  final String status;
  final DateTime? endsOn;
  final String? assetName;
  final String? coverageNotes;

  bool get isExpiringSoon {
    final end = endsOn;
    if (end == null || status != 'active') return false;
    return end.difference(DateTime.now()).inDays <= 60;
  }

  factory EafmsWarranty.fromJson(Map<String, dynamic> json) {
    return EafmsWarranty(
      id: json['id'] as String? ?? '',
      assetId: json['asset_id'] as String? ?? '',
      providerLabel: json['provider_label'] as String?,
      warrantyType: json['warranty_type'] as String? ?? 'manufacturer',
      status: json['status'] as String? ?? 'active',
      endsOn: DateTime.tryParse(json['ends_on'] as String? ?? ''),
      assetName: json['asset_name'] as String?,
      coverageNotes: json['coverage_notes'] as String?,
    );
  }
}

class EafmsDepreciation {
  const EafmsDepreciation({
    required this.id,
    required this.assetId,
    this.method = 'straight_line',
    this.bookValue = 0,
    this.monthlyAmount = 0,
    this.status = 'active',
    this.assetName,
    this.usefulLifeMonths = 60,
  });

  final String id;
  final String assetId;
  final String method;
  final double bookValue;
  final double monthlyAmount;
  final String status;
  final String? assetName;
  final int usefulLifeMonths;

  factory EafmsDepreciation.fromJson(Map<String, dynamic> json) {
    return EafmsDepreciation(
      id: json['id'] as String? ?? '',
      assetId: json['asset_id'] as String? ?? '',
      method: json['method'] as String? ?? 'straight_line',
      bookValue: (json['book_value'] as num?)?.toDouble() ?? 0,
      monthlyAmount: (json['monthly_amount'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'active',
      assetName: json['asset_name'] as String?,
      usefulLifeMonths: (json['useful_life_months'] as num?)?.toInt() ?? 60,
    );
  }
}

class EafmsAiInsight {
  const EafmsAiInsight({
    required this.id,
    required this.title,
    required this.body,
    this.insightType = 'advisory',
    this.confidencePct,
    this.editable = true,
    this.disclaimer = kEafmsAiDisclaimer,
  });

  final String id;
  final String title;
  final String body;
  final String insightType;
  final double? confidencePct;
  final bool editable;
  final String disclaimer;

  factory EafmsAiInsight.fromJson(Map<String, dynamic> json) {
    return EafmsAiInsight(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      insightType: json['insight_type'] as String? ?? 'advisory',
      confidencePct: (json['confidence_pct'] as num?)?.toDouble(),
      editable: json['editable'] as bool? ?? true,
      disclaimer: json['disclaimer'] as String? ?? kEafmsAiDisclaimer,
    );
  }
}

class EafmsActivity {
  const EafmsActivity({
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

  factory EafmsActivity.fromJson(Map<String, dynamic> json) {
    return EafmsActivity(
      id: json['id'] as String? ?? '',
      action: json['action'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      actorLabel: json['actor_label'] as String?,
      occurredAt: DateTime.tryParse(json['occurred_at'] as String? ?? ''),
    );
  }
}

class EafmsReport {
  const EafmsReport({
    required this.id,
    required this.title,
    this.reportType = 'register',
    this.periodLabel,
    this.summary,
  });

  final String id;
  final String title;
  final String reportType;
  final String? periodLabel;
  final String? summary;

  factory EafmsReport.fromJson(Map<String, dynamic> json) {
    return EafmsReport(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      reportType: json['report_type'] as String? ?? 'register',
      periodLabel: json['period_label'] as String?,
      summary: json['summary'] as String?,
    );
  }
}

class EafmsCommandCenterSnapshot {
  const EafmsCommandCenterSnapshot({
    required this.kpis,
    required this.assets,
    required this.facilities,
    required this.workOrders,
    required this.maintenance,
    required this.inspections,
    required this.fleet,
    required this.fuelLogs,
    required this.utilities,
    required this.warranties,
    required this.depreciation,
    required this.aiInsights,
    required this.activities,
    required this.reports,
    this.fromRemote = false,
    this.loadedAt,
    this.aiDisclaimer = kEafmsAiDisclaimer,
  });

  final List<EafmsKpi> kpis;
  final List<EafmsAsset> assets;
  final List<EafmsFacility> facilities;
  final List<EafmsWorkOrder> workOrders;
  final List<EafmsMaintenanceItem> maintenance;
  final List<EafmsInspection> inspections;
  final List<EafmsFleetVehicle> fleet;
  final List<EafmsFuelLog> fuelLogs;
  final List<EafmsUtilityReading> utilities;
  final List<EafmsWarranty> warranties;
  final List<EafmsDepreciation> depreciation;
  final List<EafmsAiInsight> aiInsights;
  final List<EafmsActivity> activities;
  final List<EafmsReport> reports;
  final bool fromRemote;
  final DateTime? loadedAt;
  final String aiDisclaimer;
}

abstract final class EafmsDemo {
  static EafmsCommandCenterSnapshot snapshot() {
    final now = DateTime.now();
    return EafmsCommandCenterSnapshot(
      kpis: _kpis(),
      assets: _assets(),
      facilities: _facilities(),
      workOrders: _workOrders(now),
      maintenance: _maintenance(now),
      inspections: _inspections(now),
      fleet: _fleet(),
      fuelLogs: _fuelLogs(now),
      utilities: _utilities(now),
      warranties: _warranties(now),
      depreciation: _depreciation(),
      aiInsights: _aiInsights(),
      activities: _activities(now),
      reports: _reports(),
      fromRemote: false,
      loadedAt: now,
    );
  }

  static List<EafmsKpi> _kpis() => const [
        EafmsKpi(label: 'Active Assets', value: 4),
        EafmsKpi(label: 'Open WOs', value: 2, status: 'watch'),
        EafmsKpi(label: 'Maint Due', value: 1, status: 'watch'),
        EafmsKpi(label: 'Facilities', value: 2),
        EafmsKpi(label: 'Fleet Units', value: 1),
        EafmsKpi(label: 'Warranty Risk', value: 1, status: 'watch'),
        EafmsKpi(label: 'Book Value', value: 31875000, unit: 'currency'),
      ];

  static List<EafmsAsset> _assets() => const [
        EafmsAsset(
          id: 'c1400005-0000-4000-8000-000000000001',
          assetTag: 'AST-IT-1401',
          name: 'Dell Latitude 5540 — Ops Lead',
          assetClass: 'it',
          status: 'assigned',
          categoryLabel: 'IT Equipment',
          facilityName: 'HD Homes HQ',
          serialNumber: 'DL5540-NG-88421',
          criticality: 'medium',
          purchaseCost: 1250000,
          conditionLabel: 'good',
        ),
        EafmsAsset(
          id: 'c1400005-0000-4000-8000-000000000002',
          assetTag: 'AST-FLT-1401',
          name: 'Toyota Hilux — Site Runner',
          assetClass: 'fleet',
          status: 'active',
          categoryLabel: 'Fleet Vehicles',
          facilityName: 'Oceanview Phase 2 Site',
          serialNumber: 'TH-HIL-2024-091',
          criticality: 'high',
          purchaseCost: 28500000,
          conditionLabel: 'good',
        ),
        EafmsAsset(
          id: 'c1400005-0000-4000-8000-000000000003',
          assetTag: 'AST-CEQ-1401',
          name: 'Boom Lift — Genie S-65',
          assetClass: 'construction',
          status: 'in_maintenance',
          categoryLabel: 'Construction Equipment',
          facilityName: 'Oceanview Phase 2 Site',
          serialNumber: 'GN-S65-77812',
          criticality: 'critical',
          purchaseCost: 42000000,
          conditionLabel: 'fair',
        ),
        EafmsAsset(
          id: 'c1400005-0000-4000-8000-000000000004',
          assetTag: 'AST-FAC-1401',
          name: 'HQ Generator 250kVA',
          assetClass: 'facility',
          status: 'active',
          categoryLabel: 'Facility Systems',
          facilityName: 'HD Homes HQ',
          serialNumber: 'GEN-250-HQ-01',
          criticality: 'critical',
          purchaseCost: 18500000,
          conditionLabel: 'good',
        ),
      ];

  static List<EafmsFacility> _facilities() => const [
        EafmsFacility(
          id: 'c1400002-0000-4000-8000-000000000001',
          code: 'FAC-HQ-01',
          name: 'HD Homes HQ',
          facilityType: 'hq',
          status: 'active',
          city: 'Lagos',
          addressLabel: 'Victoria Island Corporate Tower',
        ),
        EafmsFacility(
          id: 'c1400002-0000-4000-8000-000000000002',
          code: 'FAC-SITE-01',
          name: 'Oceanview Phase 2 Site',
          facilityType: 'site',
          status: 'active',
          city: 'Lagos',
          addressLabel: 'Lekki Free Trade Zone Access',
        ),
      ];

  static List<EafmsWorkOrder> _workOrders(DateTime now) => [
        EafmsWorkOrder(
          id: 'c140000c-0000-4000-8000-000000000001',
          code: 'WO-2026-1401',
          title: 'Replace boom lift hydraulic hose kit',
          status: 'open',
          priority: 'high',
          assigneeLabel: 'Plant Technician',
          assetName: 'Boom Lift — Genie S-65',
          dueAt: now.add(const Duration(days: 5)),
          estimatedCost: 420000,
        ),
        EafmsWorkOrder(
          id: 'c140000c-0000-4000-8000-000000000002',
          code: 'WO-2026-1402',
          title: 'HQ generator battery bank check',
          status: 'assigned',
          priority: 'normal',
          assigneeLabel: 'Facilities Lead',
          assetName: 'HQ Generator 250kVA',
          dueAt: now.add(const Duration(days: 14)),
          estimatedCost: 95000,
        ),
      ];

  static List<EafmsMaintenanceItem> _maintenance(DateTime now) => [
        EafmsMaintenanceItem(
          id: 'c140000a-0000-4000-8000-000000000001',
          code: 'MP-1401',
          title: 'Boom Lift hydraulic PMI',
          status: 'due',
          planType: 'preventive',
          dueAt: now.add(const Duration(days: 3)),
          assigneeLabel: 'Plant Technician',
          assetName: 'Boom Lift — Genie S-65',
        ),
        EafmsMaintenanceItem(
          id: 'c140000a-0000-4000-8000-000000000002',
          code: 'MP-1402',
          title: 'HQ Generator service',
          status: 'scheduled',
          planType: 'preventive',
          dueAt: now.add(const Duration(days: 21)),
          assigneeLabel: 'Facilities Lead',
          assetName: 'HQ Generator 250kVA',
        ),
      ];

  static List<EafmsInspection> _inspections(DateTime now) => [
        EafmsInspection(
          id: 'c140000f-0000-4000-8000-000000000001',
          code: 'INS-2026-1401',
          title: 'Boom Lift safety inspection',
          status: 'scheduled',
          inspectionType: 'safety',
          inspectorLabel: 'HSE Officer',
          scheduledAt: now.add(const Duration(days: 2)),
        ),
        EafmsInspection(
          id: 'c140000f-0000-4000-8000-000000000002',
          code: 'INS-2026-1402',
          title: 'HQ facility walkthrough',
          status: 'passed',
          inspectionType: 'routine',
          inspectorLabel: 'Facilities Lead',
          scheduledAt: now.subtract(const Duration(days: 7)),
          scorePct: 92,
        ),
      ];

  static List<EafmsFleetVehicle> _fleet() => const [
        EafmsFleetVehicle(
          id: 'c1400012-0000-4000-8000-000000000001',
          plateNumber: 'KJA-482-AB',
          makeLabel: 'Toyota',
          modelLabel: 'Hilux 2.8',
          status: 'active',
          fuelType: 'diesel',
          odometerKm: 18450,
          driverLabel: 'Site Driver — Chinedu',
        ),
      ];

  static List<EafmsFuelLog> _fuelLogs(DateTime now) => [
        EafmsFuelLog(
          id: 'c1400014-0000-4000-8000-000000000001',
          vehicleId: 'c1400012-0000-4000-8000-000000000001',
          liters: 55,
          costAmount: 71500,
          stationLabel: 'Total Lekki Express',
          loggedAt: now.subtract(const Duration(days: 2)),
          plateNumber: 'KJA-482-AB',
        ),
      ];

  static List<EafmsUtilityReading> _utilities(DateTime now) => [
        EafmsUtilityReading(
          id: 'c1400016-0000-4000-8000-000000000001',
          meterCode: 'UM-HQ-ELE-01',
          meterType: 'electricity',
          readingValue: 128450.5,
          unitLabel: 'kWh',
          facilityName: 'HD Homes HQ',
          readAt: now.subtract(const Duration(days: 1)),
        ),
      ];

  static List<EafmsWarranty> _warranties(DateTime now) => [
        EafmsWarranty(
          id: 'c1400007-0000-4000-8000-000000000001',
          assetId: 'c1400005-0000-4000-8000-000000000001',
          providerLabel: 'Dell ProSupport',
          warrantyType: 'manufacturer',
          status: 'active',
          endsOn: now.add(const Duration(days: 45)),
          assetName: 'Dell Latitude 5540 — Ops Lead',
          coverageNotes: 'Parts + onsite — expiry approaching',
        ),
        EafmsWarranty(
          id: 'c1400007-0000-4000-8000-000000000002',
          assetId: 'c1400005-0000-4000-8000-000000000003',
          providerLabel: 'Genie Extended Care',
          warrantyType: 'extended',
          status: 'active',
          endsOn: DateTime(2026, 7, 1),
          assetName: 'Boom Lift — Genie S-65',
          coverageNotes: 'Hydraulics and boom structural coverage',
        ),
      ];

  static List<EafmsDepreciation> _depreciation() => const [
        EafmsDepreciation(
          id: 'c1400008-0000-4000-8000-000000000001',
          assetId: 'c1400005-0000-4000-8000-000000000001',
          method: 'straight_line',
          bookValue: 875000,
          monthlyAmount: 33333.33,
          status: 'active',
          assetName: 'Dell Latitude 5540 — Ops Lead',
          usefulLifeMonths: 36,
        ),
        EafmsDepreciation(
          id: 'c1400008-0000-4000-8000-000000000002',
          assetId: 'c1400005-0000-4000-8000-000000000003',
          method: 'straight_line',
          bookValue: 31000000,
          monthlyAmount: 47619.05,
          status: 'active',
          assetName: 'Boom Lift — Genie S-65',
          usefulLifeMonths: 84,
        ),
      ];

  static List<EafmsAiInsight> _aiInsights() => const [
        EafmsAiInsight(
          id: 'c1400018-0000-4000-8000-000000000001',
          title: 'Predictive maintenance — boom lift hose risk',
          body:
              'Genie S-65 shows elevated hydraulic PMI urgency. Complete WO-2026-1401 before next lift cycle.',
          insightType: 'predictive_maintenance',
          confidencePct: 87,
        ),
        EafmsAiInsight(
          id: 'c1400018-0000-4000-8000-000000000002',
          title: 'Warranty expiry — Dell fleet laptop',
          body:
              'AST-IT-1401 manufacturer warranty expires within 45 days. Decide renew vs replace.',
          insightType: 'warranty_risk',
          confidencePct: 91,
        ),
        EafmsAiInsight(
          id: 'c1400018-0000-4000-8000-000000000003',
          title: 'Facility energy watch — HQ meter drift',
          body:
              'HQ electricity readings trending above prior 30-day baseline. Validate after-hours loads.',
          insightType: 'utilities',
          confidencePct: 74,
        ),
      ];

  static List<EafmsActivity> _activities(DateTime now) => [
        EafmsActivity(
          id: 'c1400019-0000-4000-8000-000000000001',
          action: 'asset_registered',
          summary: 'AST-CEQ-1401 Boom Lift registered in enterprise register',
          actorLabel: 'Construction Manager',
          occurredAt: now.subtract(const Duration(days: 30)),
        ),
        EafmsActivity(
          id: 'c1400019-0000-4000-8000-000000000002',
          action: 'work_order_opened',
          summary: 'WO-2026-1401 opened for boom lift hose kit',
          actorLabel: 'Site Manager',
          occurredAt: now.subtract(const Duration(days: 1)),
        ),
        EafmsActivity(
          id: 'c1400019-0000-4000-8000-000000000003',
          action: 'maintenance_due',
          summary: 'MP-1401 boom lift PMI marked due',
          actorLabel: 'EAFMS Scheduler',
          occurredAt: now.subtract(const Duration(hours: 6)),
        ),
        EafmsActivity(
          id: 'c1400019-0000-4000-8000-000000000004',
          action: 'fuel_logged',
          summary: 'Fuel log for KJA-482-AB (55L)',
          actorLabel: 'Site Driver',
          occurredAt: now.subtract(const Duration(days: 2)),
        ),
      ];

  static List<EafmsReport> _reports() => const [
        EafmsReport(
          id: 'c140001b-0000-4000-8000-000000000001',
          title: 'Enterprise Asset Register Snapshot',
          reportType: 'register',
          periodLabel: 'Jul 2026',
          summary:
              '4 seeded assets spanning IT, fleet, construction, facility systems.',
        ),
        EafmsReport(
          id: 'c140001b-0000-4000-8000-000000000002',
          title: 'Maintenance & Work Order Weekly',
          reportType: 'maintenance',
          periodLabel: 'W28 2026',
          summary:
              '1 open WO high-priority; boom lift PMI due; warranty expiry watch.',
        ),
      ];
}
