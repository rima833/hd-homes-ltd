// Volume 4 Part 18 — EIP domain models + demo command-center snapshot.

const String kEipAiDisclaimer = 'AI-generated — editable / advisory';

class EipKpi {
  const EipKpi({
    required this.label,
    required this.value,
    this.unit = 'count',
    this.changePct,
    this.status = 'ok',
    this.code,
  });

  final String label;
  final double value;
  final String unit;
  final double? changePct;
  final String status;
  final String? code;

  String get displayValue {
    if (unit == 'pct') {
      return '${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)}%';
    }
    return value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  }

  factory EipKpi.fromJson(Map<String, dynamic> json) {
    return EipKpi(
      label: json['name'] as String? ?? json['label'] as String? ?? '',
      value: (json['current_value'] as num?)?.toDouble() ??
          (json['value'] as num?)?.toDouble() ??
          0,
      unit: json['unit'] as String? ?? 'count',
      changePct: (json['change_pct'] as num?)?.toDouble(),
      status: json['status'] as String? ?? 'ok',
      code: json['code'] as String?,
    );
  }
}

class EipApiService {
  const EipApiService({
    required this.id,
    required this.name,
    this.code,
    this.basePath = '/api/v1',
    this.status = 'active',
    this.ownerLabel,
    this.summary,
  });

  final String id;
  final String name;
  final String? code;
  final String basePath;
  final String status;
  final String? ownerLabel;
  final String? summary;

  factory EipApiService.fromJson(Map<String, dynamic> json) {
    return EipApiService(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      code: json['code'] as String?,
      basePath: json['base_path'] as String? ?? '/api/v1',
      status: json['status'] as String? ?? 'active',
      ownerLabel: json['owner_label'] as String?,
      summary: json['summary'] as String?,
    );
  }
}

class EipApiConsumer {
  const EipApiConsumer({
    required this.id,
    required this.name,
    this.code,
    this.consumerType = 'internal',
    this.status = 'active',
    this.ownerLabel,
    this.summary,
  });

  final String id;
  final String name;
  final String? code;
  final String consumerType;
  final String status;
  final String? ownerLabel;
  final String? summary;

  factory EipApiConsumer.fromJson(Map<String, dynamic> json) {
    return EipApiConsumer(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      code: json['code'] as String?,
      consumerType: json['consumer_type'] as String? ?? 'internal',
      status: json['status'] as String? ?? 'active',
      ownerLabel: json['owner_label'] as String?,
      summary: json['summary'] as String?,
    );
  }
}

class EipWorkflowDef {
  const EipWorkflowDef({
    required this.id,
    required this.name,
    this.code,
    this.status = 'active',
    this.triggerEvent,
    this.orchestrationEngine = 'eoc',
    this.eipEnabled = false,
    this.moduleSlug,
    this.summary,
  });

  final String id;
  final String name;
  final String? code;
  final String status;
  final String? triggerEvent;
  final String orchestrationEngine;
  final bool eipEnabled;
  final String? moduleSlug;
  final String? summary;

  factory EipWorkflowDef.fromJson(Map<String, dynamic> json) {
    return EipWorkflowDef(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      code: json['code'] as String?,
      status: json['status'] as String? ?? 'active',
      triggerEvent: json['trigger_event'] as String?,
      orchestrationEngine:
          json['orchestration_engine'] as String? ?? 'eoc',
      eipEnabled: json['eip_enabled'] as bool? ?? false,
      moduleSlug: json['module_slug'] as String?,
      summary: json['description'] as String? ?? json['summary'] as String?,
    );
  }
}

class EipWorkflowTask {
  const EipWorkflowTask({
    required this.id,
    required this.name,
    this.code,
    this.taskKey = '',
    this.status = 'pending',
    this.assigneeLabel,
    this.summary,
  });

  final String id;
  final String name;
  final String? code;
  final String taskKey;
  final String status;
  final String? assigneeLabel;
  final String? summary;

  bool get isWaiting => status == 'waiting' || status == 'pending';
  bool get isFailed => status == 'failed';

  factory EipWorkflowTask.fromJson(Map<String, dynamic> json) {
    return EipWorkflowTask(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      code: json['code'] as String?,
      taskKey: json['task_key'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      assigneeLabel: json['assignee_label'] as String?,
      summary: json['summary'] as String?,
    );
  }
}

class EipWorkflowApproval {
  const EipWorkflowApproval({
    required this.id,
    required this.title,
    this.code,
    this.status = 'pending',
    this.approverLabel,
    this.summary,
  });

  final String id;
  final String title;
  final String? code;
  final String status;
  final String? approverLabel;
  final String? summary;

  bool get isPending => status == 'pending';

  factory EipWorkflowApproval.fromJson(Map<String, dynamic> json) {
    return EipWorkflowApproval(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      code: json['code'] as String?,
      status: json['status'] as String? ?? 'pending',
      approverLabel: json['approver_label'] as String?,
      summary: json['summary'] as String?,
    );
  }
}

class EipDomainEvent {
  const EipDomainEvent({
    required this.id,
    required this.eventType,
    this.code,
    this.aggregateType,
    this.status = 'published',
    this.correlationId,
    this.occurredAt,
  });

  final String id;
  final String eventType;
  final String? code;
  final String? aggregateType;
  final String status;
  final String? correlationId;
  final DateTime? occurredAt;

  factory EipDomainEvent.fromJson(Map<String, dynamic> json) {
    return EipDomainEvent(
      id: json['id'] as String? ?? '',
      eventType: json['event_type'] as String? ?? '',
      code: json['code'] as String?,
      aggregateType: json['aggregate_type'] as String?,
      status: json['status'] as String? ?? 'published',
      correlationId: json['correlation_id'] as String?,
      occurredAt: json['occurred_at'] != null
          ? DateTime.tryParse(json['occurred_at'] as String)
          : null,
    );
  }
}

class EipMessageQueue {
  const EipMessageQueue({
    required this.id,
    required this.name,
    this.code,
    this.queueType = 'standard',
    this.status = 'active',
    this.depth = 0,
    this.ownerLabel,
    this.summary,
  });

  final String id;
  final String name;
  final String? code;
  final String queueType;
  final String status;
  final int depth;
  final String? ownerLabel;
  final String? summary;

  factory EipMessageQueue.fromJson(Map<String, dynamic> json) {
    return EipMessageQueue(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      code: json['code'] as String?,
      queueType: json['queue_type'] as String? ?? 'standard',
      status: json['status'] as String? ?? 'active',
      depth: (json['depth'] as num?)?.toInt() ?? 0,
      ownerLabel: json['owner_label'] as String?,
      summary: json['summary'] as String?,
    );
  }
}

class EipQueueItem {
  const EipQueueItem({
    required this.id,
    required this.subject,
    this.code,
    this.status = 'queued',
    this.priority = 5,
  });

  final String id;
  final String subject;
  final String? code;
  final String status;
  final int priority;

  bool get isFailed => status == 'failed' || status == 'dead_letter';

  factory EipQueueItem.fromJson(Map<String, dynamic> json) {
    return EipQueueItem(
      id: json['id'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      code: json['code'] as String?,
      status: json['status'] as String? ?? 'queued',
      priority: (json['priority'] as num?)?.toInt() ?? 5,
    );
  }
}

class EipWebhookEndpoint {
  const EipWebhookEndpoint({
    required this.id,
    required this.name,
    this.code,
    this.url = '',
    this.status = 'active',
    this.ownerLabel,
    this.eventTypes = const [],
    this.summary,
  });

  final String id;
  final String name;
  final String? code;
  final String url;
  final String status;
  final String? ownerLabel;
  final List<String> eventTypes;
  final String? summary;

  factory EipWebhookEndpoint.fromJson(Map<String, dynamic> json) {
    final types = json['event_types'];
    return EipWebhookEndpoint(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      code: json['code'] as String?,
      url: json['url'] as String? ?? '',
      status: json['status'] as String? ?? 'active',
      ownerLabel: json['owner_label'] as String?,
      eventTypes: types is List
          ? types.map((e) => e.toString()).toList()
          : const [],
      summary: json['summary'] as String?,
    );
  }
}

class EipWebhookDelivery {
  const EipWebhookDelivery({
    required this.id,
    this.code,
    this.eventType,
    this.status = 'delivered',
    this.statusCode,
    this.latencyMs,
    this.occurredAt,
  });

  final String id;
  final String? code;
  final String? eventType;
  final String status;
  final int? statusCode;
  final int? latencyMs;
  final DateTime? occurredAt;

  bool get isFailed => status == 'failed';

  factory EipWebhookDelivery.fromJson(Map<String, dynamic> json) {
    return EipWebhookDelivery(
      id: json['id'] as String? ?? '',
      code: json['code'] as String?,
      eventType: json['event_type'] as String?,
      status: json['status'] as String? ?? 'delivered',
      statusCode: (json['status_code'] as num?)?.toInt(),
      latencyMs: (json['latency_ms'] as num?)?.toInt(),
      occurredAt: json['occurred_at'] != null
          ? DateTime.tryParse(json['occurred_at'] as String)
          : null,
    );
  }
}

class EipConnector {
  const EipConnector({
    required this.id,
    required this.name,
    this.code,
    this.connectorType = 'other',
    this.providerSlug,
    this.status = 'active',
    this.ownerLabel,
    this.summary,
  });

  final String id;
  final String name;
  final String? code;
  final String connectorType;
  final String? providerSlug;
  final String status;
  final String? ownerLabel;
  final String? summary;

  bool get isDegraded => status == 'degraded' || status == 'watch';

  factory EipConnector.fromJson(Map<String, dynamic> json) {
    return EipConnector(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      code: json['code'] as String?,
      connectorType: json['connector_type'] as String? ?? 'other',
      providerSlug: json['provider_slug'] as String?,
      status: json['status'] as String? ?? 'active',
      ownerLabel: json['owner_label'] as String?,
      summary: json['summary'] as String?,
    );
  }
}

class EipSecurityPolicy {
  const EipSecurityPolicy({
    required this.id,
    required this.name,
    this.code,
    this.policyType = 'auth',
    this.status = 'active',
    this.summary,
  });

  final String id;
  final String name;
  final String? code;
  final String policyType;
  final String status;
  final String? summary;

  factory EipSecurityPolicy.fromJson(Map<String, dynamic> json) {
    return EipSecurityPolicy(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      code: json['code'] as String?,
      policyType: json['policy_type'] as String? ?? 'auth',
      status: json['status'] as String? ?? 'active',
      summary: json['summary'] as String?,
    );
  }
}

class EipHealthCheck {
  const EipHealthCheck({
    required this.id,
    required this.checkName,
    this.code,
    this.status = 'ok',
    this.latencyMs,
    this.summary,
    this.observedAt,
  });

  final String id;
  final String checkName;
  final String? code;
  final String status;
  final int? latencyMs;
  final String? summary;
  final DateTime? observedAt;

  bool get isWatch => status == 'watch' || status == 'critical';

  factory EipHealthCheck.fromJson(Map<String, dynamic> json) {
    return EipHealthCheck(
      id: json['id'] as String? ?? '',
      checkName: json['check_name'] as String? ?? '',
      code: json['code'] as String?,
      status: json['status'] as String? ?? 'ok',
      latencyMs: (json['latency_ms'] as num?)?.toInt(),
      summary: json['summary'] as String?,
      observedAt: json['observed_at'] != null
          ? DateTime.tryParse(json['observed_at'] as String)
          : null,
    );
  }
}

class EipServiceRegistryEntry {
  const EipServiceRegistryEntry({
    required this.id,
    required this.name,
    this.code,
    this.status = 'healthy',
    this.environment = 'production',
    this.serviceUrl,
    this.ownerLabel,
  });

  final String id;
  final String name;
  final String? code;
  final String status;
  final String environment;
  final String? serviceUrl;
  final String? ownerLabel;

  factory EipServiceRegistryEntry.fromJson(Map<String, dynamic> json) {
    return EipServiceRegistryEntry(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      code: json['code'] as String?,
      status: json['status'] as String? ?? 'healthy',
      environment: json['environment'] as String? ?? 'production',
      serviceUrl: json['service_url'] as String?,
      ownerLabel: json['owner_label'] as String?,
    );
  }
}

class EipFeatureFlag {
  const EipFeatureFlag({
    required this.id,
    required this.name,
    required this.flagKey,
    this.code,
    this.isEnabled = false,
    this.rolloutPct = 0,
    this.summary,
  });

  final String id;
  final String name;
  final String flagKey;
  final String? code;
  final bool isEnabled;
  final double rolloutPct;
  final String? summary;

  factory EipFeatureFlag.fromJson(Map<String, dynamic> json) {
    return EipFeatureFlag(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      flagKey: json['flag_key'] as String? ?? '',
      code: json['code'] as String?,
      isEnabled: json['is_enabled'] as bool? ?? false,
      rolloutPct: (json['rollout_pct'] as num?)?.toDouble() ?? 0,
      summary: json['summary'] as String?,
    );
  }
}

class EipConfigSetting {
  const EipConfigSetting({
    required this.id,
    required this.settingKey,
    this.code,
    this.scope = 'global',
    this.summary,
  });

  final String id;
  final String settingKey;
  final String? code;
  final String scope;
  final String? summary;

  factory EipConfigSetting.fromJson(Map<String, dynamic> json) {
    return EipConfigSetting(
      id: json['id'] as String? ?? '',
      settingKey: json['setting_key'] as String? ?? '',
      code: json['code'] as String?,
      scope: json['scope'] as String? ?? 'global',
      summary: json['summary'] as String?,
    );
  }
}

class EipReport {
  const EipReport({
    required this.id,
    required this.title,
    this.code,
    this.reportType = 'ops',
    this.status = 'ready',
    this.summary,
  });

  final String id;
  final String title;
  final String? code;
  final String reportType;
  final String status;
  final String? summary;

  factory EipReport.fromJson(Map<String, dynamic> json) {
    return EipReport(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      code: json['code'] as String?,
      reportType: json['report_type'] as String? ?? 'ops',
      status: json['status'] as String? ?? 'ready',
      summary: json['summary'] as String?,
    );
  }
}

class EipAiInsight {
  const EipAiInsight({
    required this.id,
    required this.title,
    required this.body,
    this.code,
    this.insightType = 'ops',
    this.confidencePct,
    this.editable = true,
    this.disclaimer = kEipAiDisclaimer,
  });

  final String id;
  final String title;
  final String body;
  final String? code;
  final String insightType;
  final double? confidencePct;
  final bool editable;
  final String disclaimer;

  factory EipAiInsight.fromJson(Map<String, dynamic> json) {
    return EipAiInsight(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      code: json['code'] as String?,
      insightType: json['insight_type'] as String? ?? 'ops',
      confidencePct: (json['confidence_pct'] as num?)?.toDouble(),
      editable: json['editable'] as bool? ?? true,
      disclaimer: json['disclaimer'] as String? ?? kEipAiDisclaimer,
    );
  }
}

class EipActivity {
  const EipActivity({
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

  factory EipActivity.fromJson(Map<String, dynamic> json) {
    return EipActivity(
      id: json['id'] as String? ?? '',
      action: json['action'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      actorLabel: json['actor_label'] as String?,
      occurredAt: json['occurred_at'] != null
          ? DateTime.tryParse(json['occurred_at'] as String)
          : null,
    );
  }
}

class EipCommandCenterSnapshot {
  const EipCommandCenterSnapshot({
    required this.kpis,
    required this.apiServices,
    required this.apiConsumers,
    required this.workflows,
    required this.workflowTasks,
    required this.workflowApprovals,
    required this.domainEvents,
    required this.queues,
    required this.queueItems,
    required this.webhooks,
    required this.webhookDeliveries,
    required this.connectors,
    required this.securityPolicies,
    required this.healthChecks,
    required this.serviceRegistry,
    required this.featureFlags,
    required this.configSettings,
    required this.reports,
    required this.aiInsights,
    required this.activities,
    this.fromRemote = false,
    this.loadedAt,
    this.aiDisclaimer = kEipAiDisclaimer,
  });

  final List<EipKpi> kpis;
  final List<EipApiService> apiServices;
  final List<EipApiConsumer> apiConsumers;
  final List<EipWorkflowDef> workflows;
  final List<EipWorkflowTask> workflowTasks;
  final List<EipWorkflowApproval> workflowApprovals;
  final List<EipDomainEvent> domainEvents;
  final List<EipMessageQueue> queues;
  final List<EipQueueItem> queueItems;
  final List<EipWebhookEndpoint> webhooks;
  final List<EipWebhookDelivery> webhookDeliveries;
  final List<EipConnector> connectors;
  final List<EipSecurityPolicy> securityPolicies;
  final List<EipHealthCheck> healthChecks;
  final List<EipServiceRegistryEntry> serviceRegistry;
  final List<EipFeatureFlag> featureFlags;
  final List<EipConfigSetting> configSettings;
  final List<EipReport> reports;
  final List<EipAiInsight> aiInsights;
  final List<EipActivity> activities;
  final bool fromRemote;
  final DateTime? loadedAt;
  final String aiDisclaimer;
}

class EipDemo {
  static EipCommandCenterSnapshot snapshot() {
    final now = DateTime.now();
    return EipCommandCenterSnapshot(
      kpis: _kpis(),
      apiServices: _apis(),
      apiConsumers: _consumers(),
      workflows: _workflows(),
      workflowTasks: _tasks(),
      workflowApprovals: _approvals(),
      domainEvents: _events(now),
      queues: _queues(),
      queueItems: _queueItems(),
      webhooks: _webhooks(),
      webhookDeliveries: _deliveries(now),
      connectors: _connectors(),
      securityPolicies: _policies(),
      healthChecks: _health(now),
      serviceRegistry: _registry(),
      featureFlags: _flags(),
      configSettings: _config(),
      reports: _reports(),
      aiInsights: _insights(),
      activities: _activities(now),
      fromRemote: false,
      loadedAt: now,
    );
  }

  static List<EipKpi> _kpis() => const [
        EipKpi(label: 'API Services', value: 3, code: 'KPI-API'),
        EipKpi(label: 'Active Workflows', value: 4, code: 'KPI-WF'),
        EipKpi(label: 'Events 24h', value: 4, changePct: 8.2, code: 'KPI-EVT'),
        EipKpi(
          label: 'Queue Depth',
          value: 12,
          status: 'watch',
          code: 'KPI-Q',
        ),
        EipKpi(
          label: 'Webhook Failures',
          value: 1,
          status: 'critical',
          code: 'KPI-WH-FAIL',
        ),
        EipKpi(label: 'Connectors OK', value: 2, unit: 'count'),
        EipKpi(
          label: 'Health Watch',
          value: 1,
          status: 'watch',
          code: 'KPI-HC',
        ),
      ];

  static List<EipApiService> _apis() => const [
        EipApiService(
          id: 'a1800001-0000-4000-8000-000000000001',
          code: 'API-CORE-01',
          name: 'HD Homes Core API',
          ownerLabel: 'Platform',
          summary: 'Primary REST gateway for portal and partners.',
        ),
        EipApiService(
          id: 'a1800001-0000-4000-8000-000000000002',
          code: 'API-PAY-01',
          name: 'Payments API',
          basePath: '/api/v1/payments',
          ownerLabel: 'Finance Ops',
        ),
        EipApiService(
          id: 'a1800001-0000-4000-8000-000000000003',
          code: 'API-EVT-01',
          name: 'Events Ingress API',
          basePath: '/api/v1/events',
          ownerLabel: 'Integration',
        ),
      ];

  static List<EipApiConsumer> _consumers() => const [
        EipApiConsumer(
          id: 'a1800003-0000-4000-8000-000000000001',
          code: 'CON-PORTAL',
          name: 'Admin Portal',
          consumerType: 'internal',
          ownerLabel: 'Platform',
        ),
        EipApiConsumer(
          id: 'a1800003-0000-4000-8000-000000000002',
          code: 'CON-PARTNER',
          name: 'Channel Partner Hub',
          consumerType: 'partner',
          ownerLabel: 'Sales Ops',
        ),
        EipApiConsumer(
          id: 'a1800003-0000-4000-8000-000000000003',
          code: 'CON-SYSTEM',
          name: 'Background Workers',
          consumerType: 'system',
          ownerLabel: 'Integration',
        ),
      ];

  static List<EipWorkflowDef> _workflows() => const [
        EipWorkflowDef(
          id: 'a1800009-0000-4000-8000-000000000001',
          code: 'WF-EIP-PAYMENT-RECON',
          name: 'Payment Reconciliation Orchestration',
          triggerEvent: 'PaymentCompleted',
          orchestrationEngine: 'eip',
          eipEnabled: true,
          moduleSlug: 'finance',
          summary: 'Payment completion → ledger reconcile → notify finance',
        ),
        EipWorkflowDef(
          id: 'e0100009-0000-4000-8000-000000000001',
          code: 'WF-PO-ESCALATION',
          name: 'Purchase Order Escalation',
          triggerEvent: 'PurchaseOrderSubmitted',
          orchestrationEngine: 'eip',
          eipEnabled: true,
          moduleSlug: 'finance',
        ),
        EipWorkflowDef(
          id: 'e0100009-0000-4000-8000-000000000002',
          code: 'WF-SALES-CONTRACT',
          name: 'Sales Contract Routing',
          triggerEvent: 'ContractSigned',
          orchestrationEngine: 'eip',
          eipEnabled: true,
          moduleSlug: 'sales',
        ),
        EipWorkflowDef(
          id: 'e0100009-0000-4000-8000-000000000003',
          code: 'WF-SITE-INCIDENT',
          name: 'Site Incident Response',
          triggerEvent: 'SiteIncidentReported',
          orchestrationEngine: 'eip',
          eipEnabled: true,
          moduleSlug: 'construction',
        ),
      ];

  static List<EipWorkflowTask> _tasks() => const [
        EipWorkflowTask(
          id: 'a180000c-0000-4000-8000-000000000001',
          code: 'WFT-RECON-01',
          taskKey: 'reconcile',
          name: 'Reconcile ledger entry',
          status: 'in_progress',
          assigneeLabel: 'Finance Ops',
        ),
        EipWorkflowTask(
          id: 'a180000c-0000-4000-8000-000000000002',
          code: 'WFT-PO-APPR-01',
          taskKey: 'manager_approval',
          name: 'Manager approval',
          status: 'waiting',
          assigneeLabel: 'Admin',
        ),
      ];

  static List<EipWorkflowApproval> _approvals() => const [
        EipWorkflowApproval(
          id: 'a180000d-0000-4000-8000-000000000001',
          code: 'WFA-PO-01',
          title: 'Approve PO-4421 escalation',
          status: 'pending',
          approverLabel: 'Admin',
          summary: 'Pending finance dual control.',
        ),
      ];

  static List<EipDomainEvent> _events(DateTime now) => [
        EipDomainEvent(
          id: 'a1800010-0000-4000-8000-000000000001',
          code: 'EVT-PAY-01',
          eventType: 'PaymentCompleted',
          aggregateType: 'payment',
          correlationId: 'corr-pay-7781',
          occurredAt: now.subtract(const Duration(hours: 2)),
        ),
        EipDomainEvent(
          id: 'a1800010-0000-4000-8000-000000000002',
          code: 'EVT-BOOK-01',
          eventType: 'BookingConfirmed',
          aggregateType: 'booking',
          occurredAt: now.subtract(const Duration(hours: 5)),
        ),
        EipDomainEvent(
          id: 'a1800010-0000-4000-8000-000000000003',
          code: 'EVT-LEAD-01',
          eventType: 'LeadCreated',
          aggregateType: 'lead',
          occurredAt: now.subtract(const Duration(days: 1)),
        ),
        EipDomainEvent(
          id: 'a1800010-0000-4000-8000-000000000004',
          code: 'EVT-PO-01',
          eventType: 'PurchaseOrderSubmitted',
          aggregateType: 'purchase_order',
          occurredAt: now.subtract(const Duration(days: 1)),
        ),
      ];

  static List<EipMessageQueue> _queues() => const [
        EipMessageQueue(
          id: 'a1800013-0000-4000-8000-000000000001',
          code: 'Q-CRM-LEADS',
          name: 'CRM Lead Intake',
          depth: 3,
          ownerLabel: 'CRM Lead',
        ),
        EipMessageQueue(
          id: 'a1800013-0000-4000-8000-000000000002',
          code: 'Q-PAY-SETTLE',
          name: 'Payment Settlements',
          queueType: 'fifo',
          depth: 1,
          ownerLabel: 'Finance Ops',
        ),
        EipMessageQueue(
          id: 'a1800013-0000-4000-8000-000000000003',
          code: 'Q-NOTIFY',
          name: 'Notification Dispatch',
          queueType: 'priority',
          depth: 8,
          ownerLabel: 'Platform',
        ),
      ];

  static List<EipQueueItem> _queueItems() => const [
        EipQueueItem(
          id: 'a1800014-0000-4000-8000-000000000001',
          code: 'QI-LEAD-01',
          subject: 'LeadCreated lead_441',
          status: 'queued',
        ),
        EipQueueItem(
          id: 'a1800014-0000-4000-8000-000000000002',
          code: 'QI-PAY-01',
          subject: 'Settle pay_7781',
          status: 'processing',
          priority: 2,
        ),
        EipQueueItem(
          id: 'a1800014-0000-4000-8000-000000000003',
          code: 'QI-NTF-FAIL',
          subject: 'Email bounce retry',
          status: 'failed',
          priority: 7,
        ),
      ];

  static List<EipWebhookEndpoint> _webhooks() => const [
        EipWebhookEndpoint(
          id: 'a1800016-0000-4000-8000-000000000001',
          code: 'WH-PARTNER-01',
          name: 'Partner booking webhook',
          url: 'https://partners.example.local/hooks/bookings',
          eventTypes: ['BookingConfirmed'],
          ownerLabel: 'Sales Ops',
        ),
        EipWebhookEndpoint(
          id: 'a1800016-0000-4000-8000-000000000002',
          code: 'WH-PAYSTACK-IN',
          name: 'Paystack inbound callback',
          url: 'https://api.hdhomes.local/webhooks/paystack',
          eventTypes: ['PaymentCompleted'],
          ownerLabel: 'Finance Ops',
        ),
      ];

  static List<EipWebhookDelivery> _deliveries(DateTime now) => [
        EipWebhookDelivery(
          id: 'a1800017-0000-4000-8000-000000000001',
          code: 'WHD-BOOK-01',
          eventType: 'BookingConfirmed',
          status: 'delivered',
          statusCode: 200,
          latencyMs: 95,
          occurredAt: now.subtract(const Duration(hours: 5)),
        ),
        EipWebhookDelivery(
          id: 'a1800017-0000-4000-8000-000000000002',
          code: 'WHD-BOOK-02',
          eventType: 'BookingConfirmed',
          status: 'failed',
          statusCode: 503,
          latencyMs: 1200,
          occurredAt: now.subtract(const Duration(hours: 4)),
        ),
      ];

  static List<EipConnector> _connectors() => const [
        EipConnector(
          id: 'a1800018-0000-4000-8000-000000000001',
          code: 'CONN-PAYSTACK',
          name: 'Paystack Payments',
          connectorType: 'payment',
          providerSlug: 'paystack',
          ownerLabel: 'Finance Ops',
        ),
        EipConnector(
          id: 'a1800018-0000-4000-8000-000000000002',
          code: 'CONN-EMAIL',
          name: 'Transactional Email',
          connectorType: 'email',
          providerSlug: 'resend',
          ownerLabel: 'Platform',
        ),
        EipConnector(
          id: 'a1800018-0000-4000-8000-000000000003',
          code: 'CONN-MAPS',
          name: 'Maps & Geocoding',
          connectorType: 'maps',
          providerSlug: 'google_maps',
          status: 'degraded',
          ownerLabel: 'Platform',
        ),
      ];

  static List<EipSecurityPolicy> _policies() => const [
        EipSecurityPolicy(
          id: 'a1800007-0000-4000-8000-000000000001',
          code: 'SEC-JWT-01',
          name: 'JWT required for admin APIs',
          policyType: 'jwt',
          summary: 'Require signed JWT for /api/v1 admin surfaces.',
        ),
        EipSecurityPolicy(
          id: 'a1800007-0000-4000-8000-000000000002',
          code: 'SEC-IP-01',
          name: 'Partner IP allowlist',
          policyType: 'ip_allow',
        ),
      ];

  static List<EipHealthCheck> _health(DateTime now) => [
        EipHealthCheck(
          id: 'a180001a-0000-4000-8000-000000000001',
          code: 'HC-PAYSTACK',
          checkName: 'Paystack ping',
          status: 'ok',
          latencyMs: 110,
          observedAt: now.subtract(const Duration(minutes: 10)),
        ),
        EipHealthCheck(
          id: 'a180001a-0000-4000-8000-000000000002',
          code: 'HC-EMAIL',
          checkName: 'Email provider ping',
          status: 'ok',
          latencyMs: 85,
          observedAt: now.subtract(const Duration(minutes: 12)),
        ),
        EipHealthCheck(
          id: 'a180001a-0000-4000-8000-000000000003',
          code: 'HC-MAPS',
          checkName: 'Maps provider ping',
          status: 'watch',
          latencyMs: 620,
          summary: 'Elevated latency on geocode.',
          observedAt: now.subtract(const Duration(minutes: 8)),
        ),
      ];

  static List<EipServiceRegistryEntry> _registry() => const [
        EipServiceRegistryEntry(
          id: 'a180001b-0000-4000-8000-000000000001',
          code: 'SVC-REG-API',
          name: 'API Gateway',
          serviceUrl: 'https://api.hdhomes.local',
          ownerLabel: 'Platform',
        ),
        EipServiceRegistryEntry(
          id: 'a180001b-0000-4000-8000-000000000002',
          code: 'SVC-REG-WF',
          name: 'Workflow Runner',
          serviceUrl: 'https://wf.hdhomes.local',
          ownerLabel: 'Integration',
        ),
        EipServiceRegistryEntry(
          id: 'a180001b-0000-4000-8000-000000000003',
          code: 'SVC-REG-Q',
          name: 'Queue Workers',
          status: 'degraded',
          serviceUrl: 'https://q.hdhomes.local',
          ownerLabel: 'Integration',
        ),
      ];

  static List<EipFeatureFlag> _flags() => const [
        EipFeatureFlag(
          id: 'a180001c-0000-4000-8000-000000000001',
          code: 'FF-EIP-EVENTS',
          name: 'Enable domain event bus',
          flagKey: 'eip.events.enabled',
          isEnabled: true,
          rolloutPct: 100,
        ),
        EipFeatureFlag(
          id: 'a180001c-0000-4000-8000-000000000002',
          code: 'FF-EIP-WF-V2',
          name: 'EIP workflow engine v2',
          flagKey: 'eip.workflows.v2',
          isEnabled: false,
          rolloutPct: 25,
        ),
      ];

  static List<EipConfigSetting> _config() => const [
        EipConfigSetting(
          id: 'a180001d-0000-4000-8000-000000000001',
          code: 'CFG-RETRY',
          settingKey: 'eip.webhook.max_retries',
          summary: 'Default webhook retry policy.',
        ),
        EipConfigSetting(
          id: 'a180001d-0000-4000-8000-000000000002',
          code: 'CFG-QUEUE',
          settingKey: 'eip.queue.visibility_timeout_sec',
          scope: 'service',
        ),
      ];

  static List<EipReport> _reports() => const [
        EipReport(
          id: 'a180001e-0000-4000-8000-000000000001',
          code: 'RPT-SLA-7D',
          title: 'Integration SLA — 7 days',
          reportType: 'sla',
          summary: 'Gateway and webhook delivery SLA snapshot.',
        ),
        EipReport(
          id: 'a180001e-0000-4000-8000-000000000002',
          code: 'RPT-USAGE-24H',
          title: 'API usage — 24h',
          reportType: 'usage',
        ),
      ];

  static List<EipAiInsight> _insights() => const [
        EipAiInsight(
          id: 'a1800021-0000-4000-8000-000000000001',
          code: 'AI-EIP-01',
          title: 'Retry partner webhook with backoff',
          body:
              'WHD-BOOK-02 shows 503 pattern — recommend exponential backoff and partner status page check.',
          insightType: 'ops',
          confidencePct: 86.5,
        ),
        EipAiInsight(
          id: 'a1800021-0000-4000-8000-000000000002',
          code: 'AI-EIP-02',
          title: 'Scale queue workers for notify fan-out',
          body:
              'Q-NOTIFY depth trending up; temporary worker scale may clear backlog before peak hours.',
          insightType: 'optimization',
          confidencePct: 78,
        ),
        EipAiInsight(
          id: 'a1800021-0000-4000-8000-000000000003',
          code: 'AI-EIP-03',
          title: 'Tighten partner API rate limit',
          body:
              'Partner consumer nearing RL-PARTNER-60; consider 45/min during campaign spikes.',
          insightType: 'security',
          confidencePct: 81,
        ),
      ];

  static List<EipActivity> _activities(DateTime now) => [
        EipActivity(
          id: 'a180001f-0000-4000-8000-000000000001',
          action: 'event_published',
          summary: 'PaymentCompleted published for pay_7781',
          actorLabel: 'Payments API',
          occurredAt: now.subtract(const Duration(hours: 2)),
        ),
        EipActivity(
          id: 'a180001f-0000-4000-8000-000000000002',
          action: 'workflow_started',
          summary: 'Payment reconciliation workflow started',
          actorLabel: 'Workflow Runner',
          occurredAt: now.subtract(const Duration(hours: 2)),
        ),
        EipActivity(
          id: 'a180001f-0000-4000-8000-000000000003',
          action: 'webhook_failed',
          summary: 'Partner booking webhook failed (503)',
          actorLabel: 'Webhook Dispatcher',
          occurredAt: now.subtract(const Duration(hours: 4)),
        ),
        EipActivity(
          id: 'a180001f-0000-4000-8000-000000000004',
          action: 'health_watch',
          summary: 'Maps connector elevated latency',
          actorLabel: 'Health Monitor',
          occurredAt: now.subtract(const Duration(minutes: 8)),
        ),
      ];
}
