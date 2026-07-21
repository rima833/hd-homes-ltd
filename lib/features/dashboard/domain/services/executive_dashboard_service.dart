import 'package:hdhomesproject/features/dashboard/domain/entities/executive_dashboard_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Loads Mission Control snapshot from Supabase (falls back to demo data).
class ExecutiveDashboardService {
  ExecutiveDashboardService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  Future<ExecutiveDashboardSnapshot> loadSnapshot() async {
    final demo = ExecutiveDashboardDemo.snapshot();
    final client = _client;
    if (client == null) return demo;

    try {
      final kpiRows = await client
          .from('kpi_snapshots')
          .select()
          .order('captured_at', ascending: false)
          .limit(40);

      final kpis = <String, KpiCard>{};
      for (final row in kpiRows) {
        final card = KpiCard.fromJson(Map<String, dynamic>.from(row as Map));
        kpis.putIfAbsent(card.metricKey, () => card);
      }

      final healthRows = await client
          .from('business_health_scores')
          .select()
          .order('captured_at', ascending: false)
          .limit(1);
      var health = demo.health;
      if (healthRows.isNotEmpty) {
        health = BusinessHealthScore.fromJson(
          Map<String, dynamic>.from(healthRows.first as Map),
        );
      }

      final insightRows = await client
          .from('ai_executive_insights')
          .select()
          .order('created_at', ascending: false)
          .limit(12);
      final insights = insightRows.isEmpty
          ? demo.insights
          : insightRows
              .map((e) =>
                  AiExecutiveInsight.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();

      final activityRows = await client
          .from('executive_activity_feed')
          .select()
          .order('created_at', ascending: false)
          .limit(20);
      final activity = activityRows.isEmpty
          ? demo.activity
          : activityRows
              .map((e) =>
                  ActivityFeedItem.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();

      final notifRows = await client
          .from('executive_notifications')
          .select()
          .order('created_at', ascending: false)
          .limit(20);
      final notifications = notifRows.isEmpty
          ? demo.notifications
          : notifRows
              .map((e) => ExecutiveNotificationItem.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ))
              .toList();

      final actionRows = await client
          .from('executive_quick_actions')
          .select()
          .eq('is_active', true)
          .order('sort_order');
      final quickActions = actionRows.isEmpty
          ? demo.quickActions
          : actionRows
              .map((e) =>
                  QuickActionItem.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();

      return ExecutiveDashboardSnapshot(
        kpis: kpis.isEmpty ? demo.kpis : kpis.values.toList(),
        health: health,
        insights: insights,
        activity: activity,
        notifications: notifications,
        quickActions: quickActions,
        schedule: demo.schedule,
        risks: demo.risks,
        sales: demo.sales,
        properties: demo.properties,
        investors: demo.investors,
        crm: demo.crm,
        construction: demo.construction,
        finance: demo.finance,
        marketing: demo.marketing,
        support: demo.support,
        reportTypes: demo.reportTypes,
        forecasts: demo.forecasts,
        initiatives: demo.initiatives,
        briefingSummary: demo.briefingSummary,
        fromRemote: kpis.isNotEmpty || insights != demo.insights,
        loadedAt: DateTime.now(),
      );
    } catch (_) {
      return demo;
    }
  }

  Future<void> markNotificationRead(String id) async {
    final client = _client;
    if (client == null) return;
    try {
      await client
          .from('executive_notifications')
          .update({'is_read': true}).eq('id', id);
    } catch (_) {}
  }

  Future<Map<String, dynamic>> queueReport({
    required String reportType,
    required String format,
    required String userId,
  }) async {
    final client = _client;
    final title = reportType.replaceAll('_', ' ');
    if (client == null) {
      return {
        'id': 'local',
        'status': 'ready',
        'title': title,
        'format': format,
        'summary': {
          'note': 'Queued locally — apply SQL migration for persistence',
        },
      };
    }
    try {
      final row = await client.from('executive_reports').insert({
        'report_type': reportType,
        'title': '${title[0].toUpperCase()}${title.substring(1)} Report',
        'requested_by': userId,
        'status': 'ready',
        'format': format,
        'summary': {
          'generated_at': DateTime.now().toUtc().toIso8601String(),
          'note':
              'Export adapters (PDF/Excel/CSV) land with finance/ops modules',
        },
        'completed_at': DateTime.now().toUtc().toIso8601String(),
      }).select().maybeSingle();
      return row != null
          ? Map<String, dynamic>.from(row)
          : {'status': 'ready', 'title': title};
    } catch (_) {
      return {
        'status': 'ready',
        'title': title,
        'format': format,
      };
    }
  }

  String buildBriefing(ExecutiveDashboardSnapshot snap) {
    final kpiBits =
        snap.kpis.take(4).map((k) => '${k.label}: ${k.displayValue}').join('; ');
    return '''
HD Homes Executive Briefing
${snap.loadedAt ?? DateTime.now()}

Health: ${snap.health.status.label} (${snap.health.overallScore}/100)

KPI highlight — $kpiBits

AI priorities:
${snap.insights.take(3).map((i) => '• ${i.title}').join('\n')}

Risks:
${snap.risks.take(3).map((r) => '• [${r.severity.name}] ${r.title} → ${r.nextAction}').join('\n')}

${snap.briefingSummary ?? ''}
'''.trim();
  }
}
