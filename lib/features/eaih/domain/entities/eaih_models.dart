// Volume 4 Part 17 — EAIH domain models + demo command-center snapshot.

const String kEaihAiDisclaimer = 'AI-generated — editable / advisory';

class EaihKpi {
  const EaihKpi({
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

  factory EaihKpi.fromJson(Map<String, dynamic> json) {
    return EaihKpi(
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

class EaihServiceRecord {
  const EaihServiceRecord({
    required this.id,
    required this.name,
    this.code,
    this.serviceType = 'inference',
    this.status = 'active',
    this.ownerLabel,
    this.summary,
  });

  final String id;
  final String name;
  final String? code;
  final String serviceType;
  final String status;
  final String? ownerLabel;
  final String? summary;

  factory EaihServiceRecord.fromJson(Map<String, dynamic> json) {
    return EaihServiceRecord(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      code: json['code'] as String?,
      serviceType: json['service_type'] as String? ?? 'inference',
      status: json['status'] as String? ?? 'active',
      ownerLabel: json['owner_label'] as String?,
      summary: json['summary'] as String?,
    );
  }
}

class EaihCopilot {
  const EaihCopilot({
    required this.id,
    required this.slug,
    required this.name,
    this.department = 'general',
    this.status = 'active',
    this.ownerLabel,
    this.summary,
    this.capabilities = const [],
  });

  final String id;
  final String slug;
  final String name;
  final String department;
  final String status;
  final String? ownerLabel;
  final String? summary;
  final List<String> capabilities;

  factory EaihCopilot.fromJson(Map<String, dynamic> json) {
    final caps = json['capabilities'];
    return EaihCopilot(
      id: json['id'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      name: json['name'] as String? ?? '',
      department: json['department'] as String? ?? 'general',
      status: json['status'] as String? ?? 'active',
      ownerLabel: json['owner_label'] as String?,
      summary: json['summary'] as String?,
      capabilities: caps is List
          ? caps.map((e) => e.toString()).toList()
          : const [],
    );
  }
}

class EaihModel {
  const EaihModel({
    required this.id,
    required this.name,
    this.code,
    this.modelFamily = 'llm',
    this.status = 'active',
    this.providerLabel,
    this.ownerLabel,
    this.summary,
  });

  final String id;
  final String name;
  final String? code;
  final String modelFamily;
  final String status;
  final String? providerLabel;
  final String? ownerLabel;
  final String? summary;

  factory EaihModel.fromJson(Map<String, dynamic> json) {
    return EaihModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      code: json['code'] as String?,
      modelFamily: json['model_family'] as String? ?? 'llm',
      status: json['status'] as String? ?? 'active',
      providerLabel: json['provider_label'] as String?,
      ownerLabel: json['owner_label'] as String?,
      summary: json['summary'] as String?,
    );
  }
}

class EaihModelVersion {
  const EaihModelVersion({
    required this.id,
    required this.versionLabel,
    this.code,
    this.status = 'candidate',
    this.accuracyPct,
    this.latencyMs,
    this.summary,
    this.modelId,
  });

  final String id;
  final String versionLabel;
  final String? code;
  final String status;
  final double? accuracyPct;
  final int? latencyMs;
  final String? summary;
  final String? modelId;

  factory EaihModelVersion.fromJson(Map<String, dynamic> json) {
    return EaihModelVersion(
      id: json['id'] as String? ?? '',
      versionLabel: json['version_label'] as String? ?? '',
      code: json['code'] as String?,
      status: json['status'] as String? ?? 'candidate',
      accuracyPct: (json['accuracy_pct'] as num?)?.toDouble(),
      latencyMs: (json['latency_ms'] as num?)?.toInt(),
      summary: json['summary'] as String?,
      modelId: json['model_id'] as String?,
    );
  }
}

class EaihPrediction {
  const EaihPrediction({
    required this.id,
    required this.title,
    this.code,
    this.predictionType = 'forecast',
    this.predictedValue = 0,
    this.confidencePct = 0,
    this.unit = 'count',
    this.status = 'active',
    this.targetModule,
    this.ownerLabel,
    this.summary,
  });

  final String id;
  final String title;
  final String? code;
  final String predictionType;
  final double predictedValue;
  final double confidencePct;
  final String unit;
  final String status;
  final String? targetModule;
  final String? ownerLabel;
  final String? summary;

  String get displayValue {
    if (unit == 'pct') {
      return '${predictedValue.toStringAsFixed(1)}%';
    }
    if (unit == 'currency') {
      if (predictedValue >= 1000000) {
        return '₦${(predictedValue / 1000000).toStringAsFixed(1)}M';
      }
      return '₦${predictedValue.toStringAsFixed(0)}';
    }
    return predictedValue.toStringAsFixed(1);
  }

  factory EaihPrediction.fromJson(Map<String, dynamic> json) {
    return EaihPrediction(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      code: json['code'] as String?,
      predictionType: json['prediction_type'] as String? ?? 'forecast',
      predictedValue: (json['predicted_value'] as num?)?.toDouble() ?? 0,
      confidencePct: (json['confidence_pct'] as num?)?.toDouble() ?? 0,
      unit: json['unit'] as String? ?? 'count',
      status: json['status'] as String? ?? 'active',
      targetModule: json['target_module'] as String?,
      ownerLabel: json['owner_label'] as String?,
      summary: json['summary'] as String?,
    );
  }
}

class EaihRecommendation {
  const EaihRecommendation({
    required this.id,
    required this.title,
    required this.body,
    this.code,
    this.kind = 'next_best_action',
    this.status = 'pending_review',
    this.confidencePct,
    this.copilotSlug,
    this.targetModule,
  });

  final String id;
  final String title;
  final String body;
  final String? code;
  final String kind;
  final String status;
  final double? confidencePct;
  final String? copilotSlug;
  final String? targetModule;

  bool get needsReview =>
      status == 'pending_review' || status == 'awaiting_approval';

  factory EaihRecommendation.fromJson(Map<String, dynamic> json) {
    return EaihRecommendation(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      code: json['code'] as String?,
      kind: json['kind'] as String? ?? 'next_best_action',
      status: json['status'] as String? ?? 'pending_review',
      confidencePct: (json['confidence_pct'] as num?)?.toDouble(),
      copilotSlug: json['copilot_slug'] as String?,
      targetModule: json['target_module'] as String?,
    );
  }
}

class EaihSearchQuery {
  const EaihSearchQuery({
    required this.id,
    required this.queryText,
    this.code,
    this.actorLabel,
    this.queryMode = 'hybrid',
    this.resultCount = 0,
    this.latencyMs,
    this.copilotSlug,
    this.queriedAt,
  });

  final String id;
  final String queryText;
  final String? code;
  final String? actorLabel;
  final String queryMode;
  final int resultCount;
  final int? latencyMs;
  final String? copilotSlug;
  final DateTime? queriedAt;

  factory EaihSearchQuery.fromJson(Map<String, dynamic> json) {
    return EaihSearchQuery(
      id: json['id'] as String? ?? '',
      queryText: json['query_text'] as String? ?? '',
      code: json['code'] as String?,
      actorLabel: json['actor_label'] as String?,
      queryMode: json['query_mode'] as String? ?? 'hybrid',
      resultCount: (json['result_count'] as num?)?.toInt() ?? 0,
      latencyMs: (json['latency_ms'] as num?)?.toInt(),
      copilotSlug: json['copilot_slug'] as String?,
      queriedAt: DateTime.tryParse(json['queried_at'] as String? ?? ''),
    );
  }
}

class EaihKnowledgeNode {
  const EaihKnowledgeNode({
    required this.id,
    required this.label,
    this.code,
    this.nodeType = 'entity',
    this.status = 'active',
    this.summary,
  });

  final String id;
  final String label;
  final String? code;
  final String nodeType;
  final String status;
  final String? summary;

  factory EaihKnowledgeNode.fromJson(Map<String, dynamic> json) {
    return EaihKnowledgeNode(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      code: json['code'] as String?,
      nodeType: json['node_type'] as String? ?? 'entity',
      status: json['status'] as String? ?? 'active',
      summary: json['summary'] as String?,
    );
  }
}

class EaihKnowledgeEdge {
  const EaihKnowledgeEdge({
    required this.id,
    required this.sourceLabel,
    required this.targetLabel,
    this.code,
    this.relationType = 'related',
    this.summary,
  });

  final String id;
  final String sourceLabel;
  final String targetLabel;
  final String? code;
  final String relationType;
  final String? summary;

  factory EaihKnowledgeEdge.fromJson(Map<String, dynamic> json) {
    return EaihKnowledgeEdge(
      id: json['id'] as String? ?? '',
      sourceLabel: json['source_label'] as String? ??
          json['source_node_id'] as String? ??
          '',
      targetLabel: json['target_label'] as String? ??
          json['target_node_id'] as String? ??
          '',
      code: json['code'] as String?,
      relationType: json['relation_type'] as String? ?? 'related',
      summary: json['summary'] as String?,
    );
  }
}

class EaihAutomationJob {
  const EaihAutomationJob({
    required this.id,
    required this.name,
    this.code,
    this.status = 'queued',
    this.ownerLabel,
    this.summary,
    this.startedAt,
  });

  final String id;
  final String name;
  final String? code;
  final String status;
  final String? ownerLabel;
  final String? summary;
  final DateTime? startedAt;

  bool get isFailed => status == 'failed';
  bool get isSuccess => status == 'success';
  bool get awaitsApproval => status == 'awaiting_approval';

  factory EaihAutomationJob.fromJson(Map<String, dynamic> json) {
    return EaihAutomationJob(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      code: json['code'] as String?,
      status: json['status'] as String? ?? 'queued',
      ownerLabel: json['owner_label'] as String?,
      summary: json['summary'] as String?,
      startedAt: DateTime.tryParse(json['started_at'] as String? ?? ''),
    );
  }
}

class EaihWorkflowRule {
  const EaihWorkflowRule({
    required this.id,
    required this.name,
    required this.triggerEvent,
    this.code,
    this.status = 'active',
    this.actionLabel,
    this.requiresApproval = true,
    this.ownerLabel,
    this.summary,
  });

  final String id;
  final String name;
  final String triggerEvent;
  final String? code;
  final String status;
  final String? actionLabel;
  final bool requiresApproval;
  final String? ownerLabel;
  final String? summary;

  factory EaihWorkflowRule.fromJson(Map<String, dynamic> json) {
    return EaihWorkflowRule(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      triggerEvent: json['trigger_event'] as String? ?? '',
      code: json['code'] as String?,
      status: json['status'] as String? ?? 'active',
      actionLabel: json['action_label'] as String?,
      requiresApproval: json['requires_approval'] as bool? ?? true,
      ownerLabel: json['owner_label'] as String?,
      summary: json['summary'] as String?,
    );
  }
}

class EaihGovernancePolicy {
  const EaihGovernancePolicy({
    required this.id,
    required this.title,
    this.code,
    this.policyArea = 'responsible_ai',
    this.status = 'active',
    this.ownerLabel,
    this.summary,
  });

  final String id;
  final String title;
  final String? code;
  final String policyArea;
  final String status;
  final String? ownerLabel;
  final String? summary;

  factory EaihGovernancePolicy.fromJson(Map<String, dynamic> json) {
    return EaihGovernancePolicy(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      code: json['code'] as String?,
      policyArea: json['policy_area'] as String? ?? 'responsible_ai',
      status: json['status'] as String? ?? 'active',
      ownerLabel: json['owner_label'] as String?,
      summary: json['summary'] as String?,
    );
  }
}

class EaihMonitoringMetric {
  const EaihMonitoringMetric({
    required this.id,
    required this.metricName,
    this.code,
    this.metricValue = 0,
    this.status = 'ok',
    this.summary,
    this.observedAt,
  });

  final String id;
  final String metricName;
  final String? code;
  final double metricValue;
  final String status;
  final String? summary;
  final DateTime? observedAt;

  factory EaihMonitoringMetric.fromJson(Map<String, dynamic> json) {
    return EaihMonitoringMetric(
      id: json['id'] as String? ?? '',
      metricName: json['metric_name'] as String? ?? '',
      code: json['code'] as String?,
      metricValue: (json['metric_value'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'ok',
      summary: json['summary'] as String?,
      observedAt: DateTime.tryParse(json['observed_at'] as String? ?? ''),
    );
  }
}

class EaihDriftReport {
  const EaihDriftReport({
    required this.id,
    required this.title,
    this.code,
    this.severity = 'medium',
    this.status = 'open',
    this.driftScore,
    this.ownerLabel,
    this.summary,
  });

  final String id;
  final String title;
  final String? code;
  final String severity;
  final String status;
  final double? driftScore;
  final String? ownerLabel;
  final String? summary;

  bool get isOpen => {'open', 'investigating'}.contains(status);

  factory EaihDriftReport.fromJson(Map<String, dynamic> json) {
    return EaihDriftReport(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      code: json['code'] as String?,
      severity: json['severity'] as String? ?? 'medium',
      status: json['status'] as String? ?? 'open',
      driftScore: (json['drift_score'] as num?)?.toDouble(),
      ownerLabel: json['owner_label'] as String?,
      summary: json['summary'] as String?,
    );
  }
}

class EaihHubInsight {
  const EaihHubInsight({
    required this.id,
    required this.title,
    required this.body,
    this.insightType = 'briefing',
    this.confidencePct,
    this.editable = true,
    this.disclaimer = kEaihAiDisclaimer,
  });

  final String id;
  final String title;
  final String body;
  final String insightType;
  final double? confidencePct;
  final bool editable;
  final String disclaimer;

  factory EaihHubInsight.fromJson(Map<String, dynamic> json) {
    return EaihHubInsight(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      insightType: json['insight_type'] as String? ?? 'briefing',
      confidencePct: (json['confidence_pct'] as num?)?.toDouble(),
      editable: json['editable'] as bool? ?? true,
      disclaimer: json['disclaimer'] as String? ?? kEaihAiDisclaimer,
    );
  }
}

class EaihActivity {
  const EaihActivity({
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

  factory EaihActivity.fromJson(Map<String, dynamic> json) {
    return EaihActivity(
      id: json['id'] as String? ?? '',
      action: json['action'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      actorLabel: json['actor_label'] as String?,
      occurredAt: DateTime.tryParse(json['occurred_at'] as String? ?? ''),
    );
  }
}

class EaihCommandCenterSnapshot {
  const EaihCommandCenterSnapshot({
    required this.kpis,
    required this.services,
    required this.copilots,
    required this.models,
    required this.modelVersions,
    required this.predictions,
    required this.recommendations,
    required this.searchQueries,
    required this.knowledgeNodes,
    required this.knowledgeEdges,
    required this.automationJobs,
    required this.workflowRules,
    required this.governancePolicies,
    required this.monitoring,
    required this.driftReports,
    required this.hubInsights,
    required this.activities,
    this.fromRemote = false,
    this.loadedAt,
    this.aiDisclaimer = kEaihAiDisclaimer,
  });

  final List<EaihKpi> kpis;
  final List<EaihServiceRecord> services;
  final List<EaihCopilot> copilots;
  final List<EaihModel> models;
  final List<EaihModelVersion> modelVersions;
  final List<EaihPrediction> predictions;
  final List<EaihRecommendation> recommendations;
  final List<EaihSearchQuery> searchQueries;
  final List<EaihKnowledgeNode> knowledgeNodes;
  final List<EaihKnowledgeEdge> knowledgeEdges;
  final List<EaihAutomationJob> automationJobs;
  final List<EaihWorkflowRule> workflowRules;
  final List<EaihGovernancePolicy> governancePolicies;
  final List<EaihMonitoringMetric> monitoring;
  final List<EaihDriftReport> driftReports;
  final List<EaihHubInsight> hubInsights;
  final List<EaihActivity> activities;
  final bool fromRemote;
  final DateTime? loadedAt;
  final String aiDisclaimer;
}

abstract final class EaihDemo {
  static EaihCommandCenterSnapshot snapshot() {
    final now = DateTime.now();
    return EaihCommandCenterSnapshot(
      kpis: _kpis(),
      services: _services(),
      copilots: _copilots(),
      models: _models(),
      modelVersions: _versions(),
      predictions: _predictions(),
      recommendations: _recommendations(),
      searchQueries: _search(now),
      knowledgeNodes: _nodes(),
      knowledgeEdges: _edges(),
      automationJobs: _automation(now),
      workflowRules: _rules(),
      governancePolicies: _policies(),
      monitoring: _monitoring(now),
      driftReports: _drift(),
      hubInsights: _insights(),
      activities: _activities(now),
      fromRemote: false,
      loadedAt: now,
    );
  }

  static List<EaihKpi> _kpis() => const [
        EaihKpi(
          label: 'Active Copilots',
          value: 7,
          code: 'KPI-COP-ACTIVE',
        ),
        EaihKpi(
          label: 'Predictions 7d',
          value: 128,
          changePct: 12.4,
          code: 'KPI-PRED-7D',
        ),
        EaihKpi(
          label: 'Avg Confidence',
          value: 79.5,
          unit: 'pct',
          status: 'watch',
          code: 'KPI-CONF',
        ),
        EaihKpi(
          label: 'Open Drift',
          value: 2,
          status: 'critical',
          code: 'KPI-DRIFT-OPEN',
        ),
        EaihKpi(
          label: 'Awaiting Approval',
          value: 1,
          status: 'watch',
          code: 'KPI-APPR',
        ),
        EaihKpi(label: 'Search Queries 24h', value: 46),
        EaihKpi(label: 'Models in Prod', value: 3),
      ];

  static List<EaihServiceRecord> _services() => const [
        EaihServiceRecord(
          id: 'f1700001-0000-4000-8000-000000000001',
          code: 'SVC-INFER-01',
          name: 'Enterprise Inference Gateway',
          serviceType: 'inference',
          ownerLabel: 'AI Platform',
          summary: 'Primary inference gateway for copilots and predictions.',
        ),
        EaihServiceRecord(
          id: 'f1700001-0000-4000-8000-000000000002',
          code: 'SVC-EMBED-01',
          name: 'Embedding & RAG Service',
          serviceType: 'embedding',
          ownerLabel: 'AI Platform',
        ),
        EaihServiceRecord(
          id: 'f1700001-0000-4000-8000-000000000003',
          code: 'SVC-AUTO-01',
          name: 'Automation Orchestrator',
          serviceType: 'automation',
          ownerLabel: 'Ops Automation',
        ),
        EaihServiceRecord(
          id: 'f1700001-0000-4000-8000-000000000004',
          code: 'SVC-COP-01',
          name: 'Copilot Runtime',
          serviceType: 'copilot',
          ownerLabel: 'AI Platform',
        ),
      ];

  static List<EaihCopilot> _copilots() => const [
        EaihCopilot(
          id: 'f1700005-0000-4000-8000-000000000001',
          slug: 'executive',
          name: 'Executive Copilot',
          department: 'executive',
          ownerLabel: 'CEO Office',
          summary: 'Board briefs, KPI narrative, decision packets.',
          capabilities: ['briefing', 'decision', 'scorecard'],
        ),
        EaihCopilot(
          id: 'f1700005-0000-4000-8000-000000000002',
          slug: 'sales',
          name: 'Sales Copilot',
          department: 'sales',
          ownerLabel: 'Sales Ops',
          summary: 'Lead prioritization and conversion tips.',
          capabilities: ['leads', 'followup', 'conversion'],
        ),
        EaihCopilot(
          id: 'f1700005-0000-4000-8000-000000000003',
          slug: 'support',
          name: 'Support Copilot',
          department: 'support',
          ownerLabel: 'CX Lead',
          capabilities: ['triage', 'draft', 'escalation'],
        ),
        EaihCopilot(
          id: 'f1700005-0000-4000-8000-000000000004',
          slug: 'construction',
          name: 'Construction Copilot',
          department: 'construction',
          ownerLabel: 'PMO',
          capabilities: ['delay', 'milestones', 'risk'],
        ),
        EaihCopilot(
          id: 'f1700005-0000-4000-8000-000000000005',
          slug: 'finance',
          name: 'Finance Copilot',
          department: 'finance',
          ownerLabel: 'CFO Office',
          capabilities: ['collections', 'cash', 'budget'],
        ),
        EaihCopilot(
          id: 'f1700005-0000-4000-8000-000000000006',
          slug: 'hr',
          name: 'HR Copilot',
          department: 'hr',
          ownerLabel: 'People Ops',
          capabilities: ['policy', 'workforce'],
        ),
        EaihCopilot(
          id: 'f1700005-0000-4000-8000-000000000007',
          slug: 'legal',
          name: 'Legal Copilot',
          department: 'legal',
          ownerLabel: 'Legal Counsel',
          capabilities: ['contracts', 'disclaimer', 'review'],
        ),
      ];

  static List<EaihModel> _models() => const [
        EaihModel(
          id: 'f1700002-0000-4000-8000-000000000001',
          code: 'MDL-LLM-EXEC',
          name: 'Executive Decision LLM',
          modelFamily: 'llm',
          providerLabel: 'localFoundation',
          ownerLabel: 'CEO Office',
        ),
        EaihModel(
          id: 'f1700002-0000-4000-8000-000000000002',
          code: 'MDL-FC-SALES',
          name: 'Sales Conversion Forecaster',
          modelFamily: 'forecast',
          providerLabel: 'localFoundation',
          ownerLabel: 'Sales Ops',
        ),
        EaihModel(
          id: 'f1700002-0000-4000-8000-000000000003',
          code: 'MDL-EMB-01',
          name: 'Knowledge Embedding v1',
          modelFamily: 'embedding',
          providerLabel: 'localFoundation',
          ownerLabel: 'AI Platform',
        ),
        EaihModel(
          id: 'f1700002-0000-4000-8000-000000000004',
          code: 'MDL-REC-01',
          name: 'Next-Best-Action Recommender',
          modelFamily: 'recommendation',
          providerLabel: 'localFoundation',
          ownerLabel: 'CRM Lead',
        ),
      ];

  static List<EaihModelVersion> _versions() => const [
        EaihModelVersion(
          id: 'f1700003-0000-4000-8000-000000000001',
          code: 'MDL-LLM-EXEC-v1',
          versionLabel: '1.0.0',
          status: 'production',
          accuracyPct: 88.5,
          latencyMs: 420,
        ),
        EaihModelVersion(
          id: 'f1700003-0000-4000-8000-000000000002',
          code: 'MDL-FC-SALES-v2',
          versionLabel: '2.1.0',
          status: 'production',
          accuracyPct: 81.2,
          latencyMs: 180,
        ),
        EaihModelVersion(
          id: 'f1700003-0000-4000-8000-000000000003',
          code: 'MDL-FC-SALES-v3',
          versionLabel: '3.0.0-rc',
          status: 'staging',
          accuracyPct: 84.0,
          latencyMs: 195,
        ),
      ];

  static List<EaihPrediction> _predictions() => const [
        EaihPrediction(
          id: 'f1700006-0000-4000-8000-000000000001',
          code: 'PRED-CONV-30',
          title: 'Conversion next 30 days',
          predictionType: 'conversion',
          predictedValue: 19.4,
          confidencePct: 82,
          unit: 'pct',
          targetModule: 'sales',
          ownerLabel: 'Sales Ops',
          summary: 'Enterprise prediction stub — conversion outlook.',
        ),
        EaihPrediction(
          id: 'f1700006-0000-4000-8000-000000000002',
          code: 'PRED-DELAY-HG',
          title: 'Horizon Gardens delay risk',
          predictionType: 'delay',
          predictedValue: 0.34,
          confidencePct: 76.5,
          unit: 'ratio',
          targetModule: 'construction',
          ownerLabel: 'PMO',
        ),
        EaihPrediction(
          id: 'f1700006-0000-4000-8000-000000000003',
          code: 'PRED-CHURN-CRM',
          title: 'Warm lead churn risk (top 20)',
          predictionType: 'churn',
          predictedValue: 11,
          confidencePct: 71,
          targetModule: 'crm',
          ownerLabel: 'CRM Lead',
        ),
      ];

  static List<EaihRecommendation> _recommendations() => const [
        EaihRecommendation(
          id: 'f1700007-0000-4000-8000-000000000001',
          code: 'REC-SALES-01',
          title: 'Call top warm leads today',
          body: 'Prioritize 8 warm leads with >70% conversion assist score.',
          kind: 'next_best_action',
          confidencePct: 86,
          copilotSlug: 'sales',
          targetModule: 'sales',
        ),
        EaihRecommendation(
          id: 'f1700007-0000-4000-8000-000000000002',
          code: 'REC-EXEC-01',
          title: 'Escalate construction watch to board pack',
          body: 'Include Block C delay risk in weekly executive packet.',
          kind: 'executive_brief',
          confidencePct: 79.5,
          copilotSlug: 'executive',
          targetModule: 'construction',
        ),
        EaihRecommendation(
          id: 'f1700007-0000-4000-8000-000000000003',
          code: 'REC-FIN-01',
          title: 'Collections follow-up batch',
          body: 'Queue advisory collections drafts for 5 overdue invoices.',
          kind: 'collections',
          confidencePct: 74,
          copilotSlug: 'finance',
          targetModule: 'finance',
        ),
      ];

  static List<EaihSearchQuery> _search(DateTime now) => [
        EaihSearchQuery(
          id: 'f170000b-0000-4000-8000-000000000001',
          code: 'QRY-DELAY-01',
          queryText: 'construction delay risk horizon gardens',
          actorLabel: 'PMO',
          queryMode: 'hybrid',
          resultCount: 3,
          latencyMs: 95,
          copilotSlug: 'construction',
          queriedAt: now.subtract(const Duration(hours: 2)),
        ),
        EaihSearchQuery(
          id: 'f170000b-0000-4000-8000-000000000002',
          code: 'QRY-CONV-01',
          queryText: 'sales conversion next best actions',
          actorLabel: 'Sales Ops',
          queryMode: 'rag',
          resultCount: 4,
          latencyMs: 120,
          copilotSlug: 'sales',
          queriedAt: now.subtract(const Duration(hours: 5)),
        ),
      ];

  static List<EaihKnowledgeNode> _nodes() => const [
        EaihKnowledgeNode(
          id: 'f170000d-0000-4000-8000-000000000001',
          code: 'KG-EST-HG',
          label: 'Horizon Gardens',
          nodeType: 'property',
          summary: 'Flagship estate entity in knowledge graph.',
        ),
        EaihKnowledgeNode(
          id: 'f170000d-0000-4000-8000-000000000002',
          code: 'KG-PROC-BUY',
          label: 'Buying Process',
          nodeType: 'process',
        ),
        EaihKnowledgeNode(
          id: 'f170000d-0000-4000-8000-000000000003',
          code: 'KG-DOC-SOP',
          label: 'Sales Follow-up SOP',
          nodeType: 'document',
        ),
      ];

  static List<EaihKnowledgeEdge> _edges() => const [
        EaihKnowledgeEdge(
          id: 'f170000e-0000-4000-8000-000000000001',
          code: 'KGE-BUY-HG',
          sourceLabel: 'Buying Process',
          targetLabel: 'Horizon Gardens',
          relationType: 'related',
        ),
        EaihKnowledgeEdge(
          id: 'f170000e-0000-4000-8000-000000000002',
          code: 'KGE-SOP-BUY',
          sourceLabel: 'Sales Follow-up SOP',
          targetLabel: 'Buying Process',
          relationType: 'depends',
        ),
      ];

  static List<EaihAutomationJob> _automation(DateTime now) => [
        EaihAutomationJob(
          id: 'f1700010-0000-4000-8000-000000000001',
          code: 'AUTO-DELAY-01',
          name: 'Delay alert — Horizon Gardens',
          status: 'awaiting_approval',
          ownerLabel: 'PMO',
          summary: 'Draft alert ready for human approval.',
          startedAt: now.subtract(const Duration(hours: 4)),
        ),
        EaihAutomationJob(
          id: 'f1700010-0000-4000-8000-000000000002',
          code: 'AUTO-LEAD-01',
          name: 'Warm lead draft batch',
          status: 'success',
          ownerLabel: 'Sales Ops',
          startedAt: now.subtract(const Duration(days: 1)),
        ),
        EaihAutomationJob(
          id: 'f1700010-0000-4000-8000-000000000003',
          code: 'AUTO-DRIFT-01',
          name: 'Drift scan — sales forecaster',
          status: 'failed',
          ownerLabel: 'ML Ops',
          summary: 'Monitoring job failed on missing feature snapshot.',
          startedAt: now.subtract(const Duration(days: 3)),
        ),
      ];

  static List<EaihWorkflowRule> _rules() => const [
        EaihWorkflowRule(
          id: 'f170000f-0000-4000-8000-000000000001',
          code: 'RULE-DELAY-ALERT',
          name: 'Construction delay alert',
          triggerEvent: 'prediction.delay_high',
          actionLabel: 'Notify PMO + create draft brief',
          ownerLabel: 'PMO',
        ),
        EaihWorkflowRule(
          id: 'f170000f-0000-4000-8000-000000000002',
          code: 'RULE-LEAD-BATCH',
          name: 'Warm lead batch draft',
          triggerEvent: 'recommendation.sales_batch',
          actionLabel: 'Draft CRM follow-ups',
          ownerLabel: 'Sales Ops',
        ),
      ];

  static List<EaihGovernancePolicy> _policies() => const [
        EaihGovernancePolicy(
          id: 'f1700013-0000-4000-8000-000000000001',
          code: 'POL-RAI-01',
          title: 'Responsible AI labeling',
          policyArea: 'responsible_ai',
          ownerLabel: 'AI Governance',
          summary:
              'All AI outputs must carry editable / advisory disclaimer.',
        ),
        EaihGovernancePolicy(
          id: 'f1700013-0000-4000-8000-000000000002',
          code: 'POL-APPR-01',
          title: 'Human-in-the-loop approvals',
          policyArea: 'approvals',
          ownerLabel: 'AI Governance',
        ),
        EaihGovernancePolicy(
          id: 'f1700013-0000-4000-8000-000000000003',
          code: 'POL-PRIV-01',
          title: 'PII minimization in prompts',
          policyArea: 'privacy',
          ownerLabel: 'Legal Counsel',
        ),
      ];

  static List<EaihMonitoringMetric> _monitoring(DateTime now) => [
        EaihMonitoringMetric(
          id: 'f1700011-0000-4000-8000-000000000001',
          code: 'MON-FC-ACC',
          metricName: 'accuracy_pct',
          metricValue: 81.2,
          status: 'ok',
          observedAt: now.subtract(const Duration(hours: 6)),
        ),
        EaihMonitoringMetric(
          id: 'f1700011-0000-4000-8000-000000000002',
          code: 'MON-FC-LAT',
          metricName: 'p95_latency_ms',
          metricValue: 240,
          status: 'watch',
          observedAt: now.subtract(const Duration(hours: 2)),
        ),
        EaihMonitoringMetric(
          id: 'f1700011-0000-4000-8000-000000000003',
          code: 'MON-LLM-ERR',
          metricName: 'error_rate_pct',
          metricValue: 2.4,
          status: 'ok',
          observedAt: now.subtract(const Duration(hours: 1)),
        ),
      ];

  static List<EaihDriftReport> _drift() => const [
        EaihDriftReport(
          id: 'f1700012-0000-4000-8000-000000000001',
          code: 'DRIFT-FC-01',
          title: 'Feature drift — booking_stage',
          severity: 'high',
          status: 'open',
          driftScore: 0.42,
          ownerLabel: 'ML Ops',
          summary:
              'Stage distribution shifted after schema change; linked to BI ETL watch.',
        ),
        EaihDriftReport(
          id: 'f1700012-0000-4000-8000-000000000002',
          code: 'DRIFT-REC-01',
          title: 'Label drift — next-best-action',
          severity: 'medium',
          status: 'investigating',
          driftScore: 0.28,
          ownerLabel: 'CRM Lead',
        ),
      ];

  static List<EaihHubInsight> _insights() => const [
        EaihHubInsight(
          id: 'f1700014-0000-4000-8000-000000000001',
          title: 'Executive decision packet focus',
          body:
              'Prioritize construction delay watch and conversion mart recovery in this week\'s decision pack.',
          insightType: 'decision',
          confidencePct: 84,
        ),
        EaihHubInsight(
          id: 'f1700014-0000-4000-8000-000000000002',
          title: 'Automation awaiting approval',
          body:
              'AUTO-DELAY-01 holds on approval — PMO should clear or amend before notify blast.',
          insightType: 'ops',
          confidencePct: 91,
        ),
        EaihHubInsight(
          id: 'f1700014-0000-4000-8000-000000000003',
          title: 'Model drift linked to BI quality',
          body:
              'DRIFT-FC-01 correlates with analytics ETL schema drift — treat forecasts as advisory.',
          insightType: 'risk',
          confidencePct: 88.5,
        ),
      ];

  static List<EaihActivity> _activities(DateTime now) => [
        EaihActivity(
          id: 'f1700015-0000-4000-8000-000000000001',
          action: 'prediction_created',
          summary: 'PRED-CONV-30 conversion outlook published',
          actorLabel: 'Sales Ops',
          occurredAt: now.subtract(const Duration(hours: 3)),
        ),
        EaihActivity(
          id: 'f1700015-0000-4000-8000-000000000002',
          action: 'automation_awaiting_approval',
          summary: 'AUTO-DELAY-01 awaiting PMO approval',
          actorLabel: 'Automation',
          occurredAt: now.subtract(const Duration(hours: 4)),
        ),
        EaihActivity(
          id: 'f1700015-0000-4000-8000-000000000003',
          action: 'drift_opened',
          summary: 'DRIFT-FC-01 opened as high severity',
          actorLabel: 'ML Ops',
          occurredAt: now.subtract(const Duration(days: 2)),
        ),
        EaihActivity(
          id: 'f1700015-0000-4000-8000-000000000004',
          action: 'copilot_activated',
          summary: 'Executive Copilot marked active in AI Hub',
          actorLabel: 'AI Platform',
          occurredAt: now.subtract(const Duration(days: 7)),
        ),
      ];
}
