import 'package:hdhomesproject/features/eafms/domain/entities/eafms_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Loads Asset Command Center snapshot from Supabase (falls back to demo).
class EafmsService {
  EafmsService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  Future<EafmsCommandCenterSnapshot> loadCommandCenter() async {
    final demo = EafmsDemo.snapshot();
    final client = _client;
    if (client == null) return demo;

    try {
      List<EafmsAsset> assets = demo.assets;
      try {
        final rows =
            await client.from('assets').select().order('name').limit(50);
        if (rows.isNotEmpty) {
          assets = rows
              .map(
                (e) =>
                    EafmsAsset.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<EafmsFacility> facilities = demo.facilities;
      try {
        final rows =
            await client.from('facilities').select().order('name').limit(20);
        if (rows.isNotEmpty) {
          facilities = rows
              .map(
                (e) => EafmsFacility.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<EafmsWorkOrder> workOrders = demo.workOrders;
      try {
        final rows = await client
            .from('work_orders')
            .select()
            .order('created_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          workOrders = rows
              .map(
                (e) => EafmsWorkOrder.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<EafmsMaintenanceItem> maintenance = demo.maintenance;
      try {
        final rows = await client
            .from('maintenance_schedules')
            .select()
            .order('due_at')
            .limit(40);
        if (rows.isNotEmpty) {
          maintenance = rows
              .map(
                (e) => EafmsMaintenanceItem.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<EafmsInspection> inspections = demo.inspections;
      try {
        final rows = await client
            .from('inspections')
            .select()
            .order('created_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          inspections = rows
              .map(
                (e) => EafmsInspection.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<EafmsFleetVehicle> fleet = demo.fleet;
      try {
        final rows = await client.from('fleet_vehicles').select().limit(20);
        if (rows.isNotEmpty) {
          fleet = rows
              .map(
                (e) => EafmsFleetVehicle.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<EafmsFuelLog> fuelLogs = demo.fuelLogs;
      try {
        final rows = await client
            .from('fuel_logs')
            .select()
            .order('logged_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          fuelLogs = rows
              .map(
                (e) =>
                    EafmsFuelLog.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<EafmsUtilityReading> utilities = demo.utilities;
      try {
        final rows = await client
            .from('utility_readings')
            .select()
            .order('read_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          utilities = rows
              .map(
                (e) => EafmsUtilityReading.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<EafmsWarranty> warranties = demo.warranties;
      try {
        final rows = await client
            .from('asset_warranties')
            .select()
            .order('ends_on')
            .limit(40);
        if (rows.isNotEmpty) {
          warranties = rows
              .map(
                (e) => EafmsWarranty.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<EafmsDepreciation> depreciation = demo.depreciation;
      try {
        final rows = await client.from('asset_depreciation').select().limit(40);
        if (rows.isNotEmpty) {
          depreciation = rows
              .map(
                (e) => EafmsDepreciation.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<EafmsAiInsight> aiInsights = demo.aiInsights;
      try {
        final rows = await client
            .from('asset_ai_insights')
            .select()
            .order('created_at', ascending: false)
            .limit(20);
        if (rows.isNotEmpty) {
          aiInsights = rows
              .map(
                (e) => EafmsAiInsight.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<EafmsActivity> activities = demo.activities;
      try {
        final rows = await client
            .from('asset_activity_logs')
            .select()
            .order('occurred_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          activities = rows
              .map(
                (e) => EafmsActivity.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<EafmsReport> reports = demo.reports;
      try {
        final rows = await client
            .from('asset_reports')
            .select()
            .order('created_at', ascending: false)
            .limit(20);
        if (rows.isNotEmpty) {
          reports = rows
              .map(
                (e) =>
                    EafmsReport.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      final kpis = _deriveKpis(
        assets: assets,
        facilities: facilities,
        workOrders: workOrders,
        maintenance: maintenance,
        fleet: fleet,
        warranties: warranties,
        depreciation: depreciation,
      );

      return EafmsCommandCenterSnapshot(
        kpis: kpis,
        assets: assets,
        facilities: facilities,
        workOrders: workOrders,
        maintenance: maintenance,
        inspections: inspections,
        fleet: fleet,
        fuelLogs: fuelLogs,
        utilities: utilities,
        warranties: warranties,
        depreciation: depreciation,
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

  List<EafmsKpi> _deriveKpis({
    required List<EafmsAsset> assets,
    required List<EafmsFacility> facilities,
    required List<EafmsWorkOrder> workOrders,
    required List<EafmsMaintenanceItem> maintenance,
    required List<EafmsFleetVehicle> fleet,
    required List<EafmsWarranty> warranties,
    required List<EafmsDepreciation> depreciation,
  }) {
    final activeAssets = assets
        .where((a) => {'active', 'assigned', 'in_maintenance'}.contains(a.status))
        .length
        .toDouble();
    final openWos = workOrders
        .where(
          (w) =>
              {'draft', 'open', 'assigned', 'in_progress', 'on_hold'}
                  .contains(w.status),
        )
        .length
        .toDouble();
    final maintDue =
        maintenance.where((m) => m.isDue).length.toDouble();
    final warrantyRisk =
        warranties.where((w) => w.isExpiringSoon).length.toDouble();
    final bookValue =
        depreciation.fold<double>(0, (sum, d) => sum + d.bookValue);

    return [
      EafmsKpi(label: 'Active Assets', value: activeAssets),
      EafmsKpi(
        label: 'Open WOs',
        value: openWos,
        status: openWos > 0 ? 'watch' : 'ok',
      ),
      EafmsKpi(
        label: 'Maint Due',
        value: maintDue,
        status: maintDue > 0 ? 'watch' : 'ok',
      ),
      EafmsKpi(label: 'Facilities', value: facilities.length.toDouble()),
      EafmsKpi(label: 'Fleet Units', value: fleet.length.toDouble()),
      EafmsKpi(
        label: 'Warranty Risk',
        value: warrantyRisk,
        status: warrantyRisk > 0 ? 'watch' : 'ok',
      ),
      EafmsKpi(label: 'Book Value', value: bookValue, unit: 'currency'),
    ];
  }

  String generateIntelligenceBriefing(EafmsCommandCenterSnapshot snap) {
    final due = snap.maintenance.where((m) => m.isDue).length;
    final openWos = snap.workOrders
        .where((w) => {'open', 'assigned', 'in_progress'}.contains(w.status))
        .length;
    final warrantyRisk = snap.warranties.where((w) => w.isExpiringSoon).length;
    return 'Enterprise Asset Command Center™ advisory brief: '
        '$due maintenance item(s) due, $openWos open work order(s), '
        '$warrantyRisk warranty risk(s). Prioritize boom-lift PMI and '
        'warranty renewals. ${snap.aiDisclaimer}';
  }

  static List<String> detectAssetSignals(EafmsCommandCenterSnapshot snap) {
    final signals = <String>[];
    if (snap.maintenance.any((m) => m.isDue)) {
      signals.add('Maintenance schedules due or overdue');
    }
    if (snap.workOrders.any((w) => w.status == 'open')) {
      signals.add('Open work orders awaiting assignment or progress');
    }
    if (snap.warranties.any((w) => w.isExpiringSoon)) {
      signals.add('Asset warranties expiring within 60 days');
    }
    if (snap.assets.any((a) => a.isInMaintenance)) {
      signals.add('Construction or critical assets currently in maintenance');
    }
    return signals;
  }
}
