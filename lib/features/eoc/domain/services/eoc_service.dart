import 'package:hdhomesproject/features/eoc/domain/entities/eoc_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Loads EOC Mission Control snapshot from Supabase (falls back to demo).
class EocService {
  EocService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  Future<EocMissionControlSnapshot> loadMissionControl() async {
    final demo = EocDemo.snapshot();
    final client = _client;
    if (client == null) return demo;

    try {
      List<EocKpi> kpis = demo.kpis;
      try {
        final rows = await client
            .from('enterprise_kpis')
            .select()
            .order('captured_at', ascending: false)
            .limit(20);
        if (rows.isNotEmpty) {
          kpis = rows
              .map((e) => EocKpi.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        }
      } catch (_) {}

      List<EocModuleHealth> modules = demo.moduleHealth;
      try {
        final rows = await client
            .from('eoc_module_health')
            .select()
            .order('label');
        if (rows.isNotEmpty) {
          modules = rows
              .map(
                (e) => EocModuleHealth.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<EocAlert> alerts = demo.alerts;
      try {
        final rows = await client
            .from('enterprise_alerts')
            .select()
            .order('created_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          alerts = rows
              .map(
                (e) => EocAlert.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<EocApproval> approvals = demo.approvals;
      try {
        final rows = await client
            .from('approval_requests')
            .select()
            .order('created_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          approvals = rows
              .map(
                (e) =>
                    EocApproval.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<EocWorkflowInstance> workflows = demo.workflows;
      try {
        final rows = await client.from('workflow_instances').select('''
              id, reference_label, status, current_step_key,
              workflow_definitions(name)
            ''').order('started_at', ascending: false).limit(40);
        if (rows.isNotEmpty) {
          workflows = rows
              .map(
                (e) => EocWorkflowInstance.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<EocTask> tasks = demo.tasks;
      try {
        final rows = await client
            .from('enterprise_tasks')
            .select()
            .order('updated_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          tasks = rows
              .map((e) => EocTask.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        }
      } catch (_) {}

      List<EocForecast> forecasts = demo.forecasts;
      try {
        final rows = await client
            .from('predictive_forecasts')
            .select()
            .order('captured_at', ascending: false)
            .limit(20);
        if (rows.isNotEmpty) {
          forecasts = rows
              .map(
                (e) =>
                    EocForecast.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<EocScorecard> scorecards = demo.scorecards;
      try {
        final rows = await client
            .from('executive_scorecards')
            .select()
            .order('updated_at', ascending: false)
            .limit(10);
        if (rows.isNotEmpty) {
          scorecards = rows
              .map(
                (e) =>
                    EocScorecard.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<EocScorecardMetric> metrics = demo.scorecardMetrics;
      try {
        final rows = await client
            .from('executive_scorecard_metrics')
            .select()
            .limit(40);
        if (rows.isNotEmpty) {
          metrics = rows
              .map(
                (e) => EocScorecardMetric.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<EocMeeting> meetings = demo.meetings;
      try {
        final rows = await client
            .from('meeting_records')
            .select()
            .order('scheduled_at', ascending: true)
            .limit(20);
        if (rows.isNotEmpty) {
          meetings = rows
              .map(
                (e) =>
                    EocMeeting.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<EocDecision> decisions = demo.decisions;
      try {
        final rows = await client
            .from('decision_logs')
            .select()
            .order('decided_at', ascending: false)
            .limit(20);
        if (rows.isNotEmpty) {
          decisions = rows
              .map(
                (e) =>
                    EocDecision.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<EocActivity> activities = demo.activities;
      try {
        final rows = await client
            .from('eoc_activity_logs')
            .select()
            .order('occurred_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          activities = rows
              .map(
                (e) =>
                    EocActivity.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<EocAuditEvent> audit = demo.auditEvents;
      try {
        final rows = await client
            .from('eoc_audit_events')
            .select()
            .order('occurred_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          audit = rows
              .map(
                (e) => EocAuditEvent.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<EocKnowledgeArticle> knowledge = demo.knowledge;
      try {
        final rows = await client
            .from('knowledge_articles')
            .select()
            .order('updated_at', ascending: false)
            .limit(20);
        if (rows.isNotEmpty) {
          knowledge = rows
              .map(
                (e) => EocKnowledgeArticle.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      return EocMissionControlSnapshot(
        kpis: kpis,
        moduleHealth: modules,
        alerts: alerts,
        approvals: approvals,
        workflows: workflows,
        tasks: tasks,
        aiInsights: demo.aiInsights,
        forecasts: forecasts,
        scorecards: scorecards,
        scorecardMetrics: metrics,
        meetings: meetings,
        decisions: decisions,
        activities: activities,
        auditEvents: audit,
        knowledge: knowledge,
        searchHits: demo.searchHits,
        fromRemote: true,
        loadedAt: DateTime.now(),
      );
    } catch (_) {
      return demo;
    }
  }

  String generateEnterpriseBriefing(EocMissionControlSnapshot snap) {
    final openAlerts =
        snap.alerts.where((a) => a.status == 'open').length;
    final pending =
        snap.approvals.where((a) => a.status == 'pending').length;
    final waiting =
        snap.workflows.where((w) => w.status == 'waiting').length;
    return 'AI Enterprise Brain™ briefing (editable / advisory)\n'
        '• Open alerts $openAlerts · Pending approvals $pending · '
        'Workflows waiting $waiting\n'
        '• Module health avg '
        '${snap.moduleHealth.isEmpty ? '—' : (snap.moduleHealth.map((m) => m.healthPct).reduce((a, b) => a + b) / snap.moduleHealth.length).toStringAsFixed(0)}%\n'
        '• ${snap.aiDisclaimer}';
  }

  static List<String> detectOpsSignals(EocMissionControlSnapshot snap) {
    final signals = <String>[];
    final critical = snap.alerts
        .where((a) => a.severity == 'critical' && a.status == 'open')
        .length;
    if (critical > 0) {
      signals.add('$critical critical alert(s) require executive attention.');
    }
    final pending =
        snap.approvals.where((a) => a.status == 'pending').length;
    if (pending > 0) {
      signals.add('$pending approval(s) in queue — clear SLA blockers.');
    }
    final degraded = snap.moduleHealth
        .where((m) => m.status == 'degraded' || m.healthPct < 80)
        .length;
    if (degraded > 0) {
      signals.add('$degraded module(s) below health threshold.');
    }
    final urgent = snap.tasks.where((t) => t.priority == 'urgent').length;
    if (urgent > 0) {
      signals.add('$urgent urgent task(s) outstanding.');
    }
    if (signals.isEmpty) {
      signals.add('Ops signals stable — no urgent Mission Control actions.');
    }
    return signals;
  }

  List<EocSearchHit> search(
    EocMissionControlSnapshot snap,
    String query,
  ) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return snap.searchHits;
    final hits = <EocSearchHit>[];
    for (final a in snap.alerts) {
      if (a.title.toLowerCase().contains(q) ||
          (a.body?.toLowerCase().contains(q) ?? false)) {
        hits.add(EocSearchHit(
          id: a.id,
          title: a.title,
          module: 'alerts',
          subtitle: '${a.severity} · ${a.status}',
        ));
      }
    }
    for (final a in snap.approvals) {
      if (a.title.toLowerCase().contains(q) ||
          (a.summary?.toLowerCase().contains(q) ?? false)) {
        hits.add(EocSearchHit(
          id: a.id,
          title: a.title,
          module: 'approvals',
          subtitle: a.status,
        ));
      }
    }
    for (final w in snap.workflows) {
      if (w.referenceLabel.toLowerCase().contains(q) ||
          (w.definitionName?.toLowerCase().contains(q) ?? false)) {
        hits.add(EocSearchHit(
          id: w.id,
          title: w.referenceLabel,
          module: 'workflows',
          subtitle: w.status,
        ));
      }
    }
    for (final t in snap.tasks) {
      if (t.title.toLowerCase().contains(q)) {
        hits.add(EocSearchHit(
          id: t.id,
          title: t.title,
          module: 'tasks',
          subtitle: t.priority,
        ));
      }
    }
    return hits.isEmpty ? snap.searchHits : hits;
  }
}
