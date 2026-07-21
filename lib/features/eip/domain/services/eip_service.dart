import 'package:hdhomesproject/features/eip/domain/entities/eip_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Loads Integration Command Center snapshot from Supabase (falls back to demo).
class EipService {
  EipService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  Future<EipCommandCenterSnapshot> loadCommandCenter() async {
    final demo = EipDemo.snapshot();
    final client = _client;
    if (client == null) return demo;

    try {
      List<EipApiService> apis = demo.apiServices;
      try {
        final rows = await client
            .from('api_services')
            .select()
            .order('name')
            .limit(40);
        if (rows.isNotEmpty) {
          apis = rows
              .map(
                (e) =>
                    EipApiService.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<EipApiConsumer> consumers = demo.apiConsumers;
      try {
        final rows = await client
            .from('api_consumers')
            .select()
            .order('name')
            .limit(40);
        if (rows.isNotEmpty) {
          consumers = rows
              .map(
                (e) => EipApiConsumer.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<EipWorkflowDef> workflows = demo.workflows;
      try {
        final rows = await client
            .from('workflow_definitions')
            .select()
            .order('name')
            .limit(40);
        if (rows.isNotEmpty) {
          workflows = rows
              .map(
                (e) =>
                    EipWorkflowDef.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<EipWorkflowTask> tasks = demo.workflowTasks;
      try {
        final rows = await client
            .from('workflow_tasks')
            .select()
            .order('created_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          tasks = rows
              .map(
                (e) => EipWorkflowTask.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<EipWorkflowApproval> approvals = demo.workflowApprovals;
      try {
        final rows = await client
            .from('workflow_approvals')
            .select()
            .order('created_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          approvals = rows
              .map(
                (e) => EipWorkflowApproval.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<EipDomainEvent> events = demo.domainEvents;
      try {
        final rows = await client
            .from('domain_events')
            .select()
            .order('occurred_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          events = rows
              .map(
                (e) => EipDomainEvent.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<EipMessageQueue> queues = demo.queues;
      try {
        final rows = await client
            .from('message_queues')
            .select()
            .order('name')
            .limit(40);
        if (rows.isNotEmpty) {
          queues = rows
              .map(
                (e) => EipMessageQueue.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<EipQueueItem> items = demo.queueItems;
      try {
        final rows = await client
            .from('message_queue_items')
            .select()
            .order('created_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          items = rows
              .map(
                (e) =>
                    EipQueueItem.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<EipWebhookEndpoint> webhooks = demo.webhooks;
      try {
        final rows = await client
            .from('webhook_endpoints')
            .select()
            .order('name')
            .limit(40);
        if (rows.isNotEmpty) {
          webhooks = rows
              .map(
                (e) => EipWebhookEndpoint.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<EipWebhookDelivery> deliveries = demo.webhookDeliveries;
      try {
        final rows = await client
            .from('webhook_deliveries')
            .select()
            .order('occurred_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          deliveries = rows
              .map(
                (e) => EipWebhookDelivery.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<EipConnector> connectors = demo.connectors;
      try {
        final rows = await client
            .from('integration_connectors')
            .select()
            .order('name')
            .limit(40);
        if (rows.isNotEmpty) {
          connectors = rows
              .map(
                (e) =>
                    EipConnector.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<EipSecurityPolicy> policies = demo.securityPolicies;
      try {
        final rows = await client
            .from('api_security_policies')
            .select()
            .order('name')
            .limit(40);
        if (rows.isNotEmpty) {
          policies = rows
              .map(
                (e) => EipSecurityPolicy.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<EipHealthCheck> health = demo.healthChecks;
      try {
        final rows = await client
            .from('integration_health_checks')
            .select()
            .order('observed_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          health = rows
              .map(
                (e) => EipHealthCheck.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<EipServiceRegistryEntry> registry = demo.serviceRegistry;
      try {
        final rows = await client
            .from('service_registry')
            .select()
            .order('name')
            .limit(40);
        if (rows.isNotEmpty) {
          registry = rows
              .map(
                (e) => EipServiceRegistryEntry.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<EipFeatureFlag> flags = demo.featureFlags;
      try {
        final rows = await client
            .from('feature_flags')
            .select()
            .order('name')
            .limit(40);
        if (rows.isNotEmpty) {
          flags = rows
              .map(
                (e) =>
                    EipFeatureFlag.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<EipConfigSetting> config = demo.configSettings;
      try {
        final rows = await client
            .from('configuration_settings')
            .select()
            .order('setting_key')
            .limit(40);
        if (rows.isNotEmpty) {
          config = rows
              .map(
                (e) => EipConfigSetting.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<EipReport> reports = demo.reports;
      try {
        final rows = await client
            .from('integration_reports')
            .select()
            .order('title')
            .limit(40);
        if (rows.isNotEmpty) {
          reports = rows
              .map(
                (e) => EipReport.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<EipAiInsight> insights = demo.aiInsights;
      try {
        final rows = await client
            .from('integration_ai_insights')
            .select()
            .order('created_at', ascending: false)
            .limit(20);
        if (rows.isNotEmpty) {
          insights = rows
              .map(
                (e) =>
                    EipAiInsight.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<EipActivity> activities = demo.activities;
      try {
        final rows = await client
            .from('integration_activity_logs')
            .select()
            .order('occurred_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          activities = rows
              .map(
                (e) =>
                    EipActivity.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      return EipCommandCenterSnapshot(
        kpis: demo.kpis,
        apiServices: apis,
        apiConsumers: consumers,
        workflows: workflows,
        workflowTasks: tasks,
        workflowApprovals: approvals,
        domainEvents: events,
        queues: queues,
        queueItems: items,
        webhooks: webhooks,
        webhookDeliveries: deliveries,
        connectors: connectors,
        securityPolicies: policies,
        healthChecks: health,
        serviceRegistry: registry,
        featureFlags: flags,
        configSettings: config,
        reports: reports,
        aiInsights: insights,
        activities: activities,
        fromRemote: true,
        loadedAt: DateTime.now(),
      );
    } catch (_) {
      return demo;
    }
  }

  String generateOpsBriefing(EipCommandCenterSnapshot snap) {
    final fails = snap.webhookDeliveries.where((d) => d.isFailed).length;
    final pending = snap.workflowApprovals.where((a) => a.isPending).length;
    final watch = snap.healthChecks.where((h) => h.isWatch).length;
    final depth = snap.queues.fold<int>(0, (s, q) => s + q.depth);
    return 'Digital Operations Control Tower™ advisory: '
        '$fails webhook failure(s), $pending workflow approval(s) pending, '
        '$watch health check(s) on watch, queue depth $depth. '
        'Prioritize partner webhook recovery and notify queue scale. '
        '${snap.aiDisclaimer}';
  }

  static List<String> detectIntegrationSignals(EipCommandCenterSnapshot snap) {
    final signals = <String>[];
    if (snap.webhookDeliveries.any((d) => d.isFailed)) {
      signals.add('Webhook delivery failures detected');
    }
    if (snap.queueItems.any((i) => i.isFailed)) {
      signals.add('Queue items failed or moved to dead-letter');
    }
    if (snap.workflowApprovals.any((a) => a.isPending)) {
      signals.add('Workflow approvals awaiting decision');
    }
    if (snap.healthChecks.any((h) => h.isWatch)) {
      signals.add('Connector health checks on watch or critical');
    }
    if (snap.connectors.any((c) => c.isDegraded)) {
      signals.add('Connectors reporting degraded status');
    }
    if (signals.isEmpty) {
      signals.add('Integration surfaces nominal — continue monitoring');
    }
    return signals;
  }
}
