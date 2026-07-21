import 'package:hdhomesproject/features/cpms/domain/entities/cpms_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Loads Construction Command Center snapshot from Supabase (falls back to demo).
class CpmsService {
  CpmsService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  Future<CpmsCommandCenterSnapshot> loadCommandCenter() async {
    final demo = CpmsDemo.snapshot();
    final client = _client;
    if (client == null) return demo;

    try {
      final projectRows = await client
          .from('construction_projects')
          .select('*, estates(name, slug)')
          .order('updated_at', ascending: false)
          .limit(100);

      final projects = <CpmsProject>[];
      for (final row in projectRows) {
        final map = Map<String, dynamic>.from(row as Map);
        if ((map['name'] as String?)?.isNotEmpty != true) continue;
        projects.add(CpmsProject.fromJson(map));
      }

      if (projects.isEmpty) return demo;

      List<CpmsMilestone> milestones = demo.milestones;
      try {
        final rows = await client
            .from('project_milestones')
            .select('*, construction_projects(name)')
            .order('due_date', ascending: true)
            .limit(100);
        if (rows.isNotEmpty) {
          milestones = rows
              .map(
                (e) => CpmsMilestone.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<CpmsTask> tasks = demo.tasks;
      try {
        final rows = await client
            .from('project_tasks')
            .select('*, construction_projects(name)')
            .order('due_date', ascending: true)
            .limit(100);
        if (rows.isNotEmpty) {
          tasks = rows
              .map(
                (e) => CpmsTask.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<CpmsContractor> contractors = demo.contractors;
      try {
        final rows = await client
            .from('project_contractors')
            .select('*, construction_projects(name)')
            .order('updated_at', ascending: false)
            .limit(50);
        if (rows.isNotEmpty) {
          contractors = rows
              .map(
                (e) => CpmsContractor.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<CpmsProcurementRequest> procurement = demo.procurementRequests;
      try {
        final rows = await client
            .from('project_procurement_requests')
            .select()
            .order('updated_at', ascending: false)
            .limit(50);
        if (rows.isNotEmpty) {
          procurement = rows
              .map(
                (e) => CpmsProcurementRequest.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<CpmsChangeOrder> changeOrders = demo.changeOrders;
      try {
        final rows = await client
            .from('project_change_orders')
            .select('*, construction_projects(name)')
            .order('updated_at', ascending: false)
            .limit(50);
        if (rows.isNotEmpty) {
          changeOrders = rows
              .map(
                (e) => CpmsChangeOrder.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<CpmsBudgetLine> budgetLines = demo.budgetLines;
      try {
        final rows = await client
            .from('project_budget_lines')
            .select()
            .order('category', ascending: true)
            .limit(100);
        if (rows.isNotEmpty) {
          budgetLines = rows
              .map(
                (e) => CpmsBudgetLine.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<CpmsQualityCheck> qualityChecks = demo.qualityChecks;
      try {
        final rows = await client
            .from('project_quality_checks')
            .select()
            .order('updated_at', ascending: false)
            .limit(50);
        if (rows.isNotEmpty) {
          qualityChecks = rows
              .map(
                (e) => CpmsQualityCheck.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<CpmsDefect> defects = demo.defects;
      try {
        final rows = await client
            .from('project_defects')
            .select('*, construction_projects(name)')
            .order('updated_at', ascending: false)
            .limit(50);
        if (rows.isNotEmpty) {
          defects = rows
              .map(
                (e) =>
                    CpmsDefect.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<CpmsSafetyIncident> safety = demo.safetyIncidents;
      try {
        final rows = await client
            .from('project_safety_incidents')
            .select('*, construction_projects(name)')
            .order('occurred_at', ascending: false)
            .limit(50);
        if (rows.isNotEmpty) {
          safety = rows
              .map(
                (e) => CpmsSafetyIncident.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<CpmsSiteDiary> diaries = demo.siteDiaries;
      try {
        final rows = await client
            .from('project_site_diaries')
            .select('*, construction_projects(name)')
            .order('entry_date', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          diaries = rows
              .map(
                (e) => CpmsSiteDiary.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<CpmsInspection> inspections = demo.inspections;
      try {
        final rows = await client
            .from('project_inspections')
            .select()
            .order('scheduled_at', ascending: true)
            .limit(40);
        if (rows.isNotEmpty) {
          inspections = rows
              .map(
                (e) => CpmsInspection.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<CpmsRisk> risks = demo.risks;
      try {
        final rows = await client
            .from('project_risk_register')
            .select()
            .order('updated_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          risks = rows
              .map(
                (e) => CpmsRisk.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<CpmsActivity> activities = demo.activities;
      try {
        final rows = await client
            .from('project_activity_logs')
            .select()
            .order('occurred_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          activities = rows
              .map(
                (e) =>
                    CpmsActivity.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<CpmsAlert> alerts = demo.alerts;
      try {
        final rows = await client
            .from('project_notifications')
            .select()
            .order('created_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          alerts = rows
              .map(
                (e) => CpmsAlert.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      return CpmsCommandCenterSnapshot(
        kpis: CpmsDemo.aggregateKpis(
          projects: projects,
          milestones: milestones,
          tasks: tasks,
          changeOrders: changeOrders,
          defects: defects,
          safetyIncidents: safety,
        ),
        projects: projects,
        milestones: milestones,
        tasks: tasks,
        contractors: contractors,
        procurementRequests: procurement,
        changeOrders: changeOrders,
        budgetLines: budgetLines,
        qualityChecks: qualityChecks,
        defects: defects,
        safetyIncidents: safety,
        siteDiaries: diaries,
        inspections: inspections,
        risks: risks,
        activities: activities,
        alerts: alerts,
        aiInsights: demo.aiInsights,
        progressIntelligence: demo.progressIntelligence,
        fromRemote: true,
        loadedAt: DateTime.now(),
      );
    } catch (_) {
      return demo;
    }
  }

  /// Stub AI progress summary for a selected project.
  String generateProgressSummary(CpmsProject project) {
    final conf = project.forecastConfidencePct;
    final confLabel =
        conf == null ? 'n/a' : '${conf.toStringAsFixed(0)}% confidence';
    return 'AI progress summary: ${project.name} · ${project.status.label} · '
        '${project.progressPct.toStringAsFixed(0)}% complete · '
        'delay ${project.delayDays}d · forecast $confLabel. '
        '${project.aiSummary ?? 'Review milestones, blockers, and change orders this week.'} '
        '(${project.forecastDisclaimer})';
  }

  /// Delay detection helper — projects with slip or on_hold.
  static List<CpmsProject> detectDelayedProjects(List<CpmsProject> projects) =>
      CpmsDemo.detectDelayedProjects(projects);
}
