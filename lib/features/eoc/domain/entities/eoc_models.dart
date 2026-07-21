// Volume 4 Part 10 — Enterprise Operations Center (EOC) domain models.

const String kEocAiDisclaimer =
    'AI-generated — editable / advisory. Enterprise Brain outputs are drafts '
    'for human review, not guarantees of revenue, risk, or operational outcomes.';

class EocKpi {
  const EocKpi({
    required this.label,
    required this.value,
    this.unit = 'count',
    this.status = 'ok',
    this.changePct,
  });

  final String label;
  final double value;
  final String unit;
  final String status;
  final double? changePct;

  String get displayValue {
    if (unit == 'percent') {
      return value == value.roundToDouble()
          ? '${value.toStringAsFixed(0)}%'
          : '${value.toStringAsFixed(1)}%';
    }
    if (unit == 'currency') {
      if (value >= 1000000) {
        return '₦${(value / 1000000).toStringAsFixed(1)}M';
      }
      return '₦${value.toStringAsFixed(0)}';
    }
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }

  factory EocKpi.fromJson(Map<String, dynamic> json) {
    return EocKpi(
      label: json['label'] as String? ?? json['metric_key'] as String? ?? 'KPI',
      value: (json['value'] as num?)?.toDouble() ?? 0,
      unit: json['unit'] as String? ?? 'count',
      status: json['status'] as String? ?? 'ok',
      changePct: (json['change_pct'] as num?)?.toDouble(),
    );
  }
}

class EocModuleHealth {
  const EocModuleHealth({
    required this.id,
    required this.moduleSlug,
    required this.label,
    required this.healthPct,
    this.status = 'healthy',
    this.openAlerts = 0,
  });

  final String id;
  final String moduleSlug;
  final String label;
  final double healthPct;
  final String status;
  final int openAlerts;

  factory EocModuleHealth.fromJson(Map<String, dynamic> json) {
    return EocModuleHealth(
      id: json['id'] as String? ?? '',
      moduleSlug: json['module_slug'] as String? ?? '',
      label: json['label'] as String? ?? '',
      healthPct: (json['health_pct'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'healthy',
      openAlerts: (json['open_alerts'] as num?)?.toInt() ?? 0,
    );
  }
}

class EocAlert {
  const EocAlert({
    required this.id,
    required this.title,
    this.body,
    this.severity = 'info',
    this.category = 'ops',
    this.moduleSlug,
    this.status = 'open',
  });

  final String id;
  final String title;
  final String? body;
  final String severity;
  final String category;
  final String? moduleSlug;
  final String status;

  factory EocAlert.fromJson(Map<String, dynamic> json) {
    return EocAlert(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Alert',
      body: json['body'] as String?,
      severity: json['severity'] as String? ?? 'info',
      category: json['category'] as String? ?? 'ops',
      moduleSlug: json['module_slug'] as String?,
      status: json['status'] as String? ?? 'open',
    );
  }
}

class EocApproval {
  const EocApproval({
    required this.id,
    required this.title,
    this.summary,
    this.moduleSlug,
    this.status = 'pending',
    this.amount,
    this.currency = 'NGN',
  });

  final String id;
  final String title;
  final String? summary;
  final String? moduleSlug;
  final String status;
  final double? amount;
  final String currency;

  factory EocApproval.fromJson(Map<String, dynamic> json) {
    return EocApproval(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Approval',
      summary: json['summary'] as String?,
      moduleSlug: json['module_slug'] as String?,
      status: json['status'] as String? ?? 'pending',
      amount: (json['amount'] as num?)?.toDouble(),
      currency: json['currency'] as String? ?? 'NGN',
    );
  }
}

class EocWorkflowInstance {
  const EocWorkflowInstance({
    required this.id,
    required this.referenceLabel,
    this.status = 'running',
    this.currentStepKey,
    this.definitionName,
  });

  final String id;
  final String referenceLabel;
  final String status;
  final String? currentStepKey;
  final String? definitionName;

  factory EocWorkflowInstance.fromJson(Map<String, dynamic> json) {
    final def = json['workflow_definitions'];
    String? defName;
    if (def is Map) {
      defName = def['name'] as String?;
    }
    return EocWorkflowInstance(
      id: json['id'] as String? ?? '',
      referenceLabel: json['reference_label'] as String? ?? 'Workflow',
      status: json['status'] as String? ?? 'running',
      currentStepKey: json['current_step_key'] as String?,
      definitionName: defName ?? json['definition_name'] as String?,
    );
  }
}

class EocTask {
  const EocTask({
    required this.id,
    required this.title,
    this.description,
    this.status = 'open',
    this.priority = 'medium',
    this.moduleSlug,
    this.assigneeLabel,
    this.dueAt,
  });

  final String id;
  final String title;
  final String? description;
  final String status;
  final String priority;
  final String? moduleSlug;
  final String? assigneeLabel;
  final DateTime? dueAt;

  factory EocTask.fromJson(Map<String, dynamic> json) {
    return EocTask(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Task',
      description: json['description'] as String?,
      status: json['status'] as String? ?? 'open',
      priority: json['priority'] as String? ?? 'medium',
      moduleSlug: json['module_slug'] as String?,
      assigneeLabel: json['assignee_label'] as String?,
      dueAt: DateTime.tryParse(json['due_at'] as String? ?? ''),
    );
  }
}

class EocAiInsight {
  const EocAiInsight({
    required this.id,
    required this.title,
    required this.body,
    this.category = 'ops',
    this.confidencePct,
    this.editable = true,
    this.disclaimer = kEocAiDisclaimer,
  });

  final String id;
  final String title;
  final String body;
  final String category;
  final double? confidencePct;
  final bool editable;
  final String disclaimer;
}

class EocForecast {
  const EocForecast({
    required this.id,
    required this.label,
    required this.predictedValue,
    this.unit = 'count',
    this.horizon = '30d',
    this.confidencePct,
    this.scenario = 'base',
  });

  final String id;
  final String label;
  final double predictedValue;
  final String unit;
  final String horizon;
  final double? confidencePct;
  final String scenario;

  String get displayValue {
    if (unit == 'currency') {
      if (predictedValue >= 1000000) {
        return '₦${(predictedValue / 1000000).toStringAsFixed(1)}M';
      }
      return '₦${predictedValue.toStringAsFixed(0)}';
    }
    return predictedValue == predictedValue.roundToDouble()
        ? predictedValue.toStringAsFixed(0)
        : predictedValue.toStringAsFixed(1);
  }

  factory EocForecast.fromJson(Map<String, dynamic> json) {
    return EocForecast(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? 'Forecast',
      predictedValue: (json['predicted_value'] as num?)?.toDouble() ?? 0,
      unit: json['unit'] as String? ?? 'count',
      horizon: json['horizon'] as String? ?? '30d',
      confidencePct: (json['confidence_pct'] as num?)?.toDouble(),
      scenario: json['scenario'] as String? ?? 'base',
    );
  }
}

class EocScorecard {
  const EocScorecard({
    required this.id,
    required this.code,
    required this.name,
    this.period = 'q3_2026',
    this.overallScore,
    this.status = 'active',
    this.ownerLabel,
    this.metrics = const [],
  });

  final String id;
  final String code;
  final String name;
  final String period;
  final double? overallScore;
  final String status;
  final String? ownerLabel;
  final List<EocScorecardMetric> metrics;

  factory EocScorecard.fromJson(Map<String, dynamic> json) {
    return EocScorecard(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? 'Scorecard',
      period: json['period'] as String? ?? 'q3_2026',
      overallScore: (json['overall_score'] as num?)?.toDouble(),
      status: json['status'] as String? ?? 'active',
      ownerLabel: json['owner_label'] as String?,
    );
  }
}

class EocScorecardMetric {
  const EocScorecardMetric({
    required this.id,
    required this.metricKey,
    required this.label,
    required this.score,
    this.weight = 1,
    this.targetValue,
    this.actualValue,
    this.status = 'on_track',
  });

  final String id;
  final String metricKey;
  final String label;
  final double score;
  final double weight;
  final double? targetValue;
  final double? actualValue;
  final String status;

  factory EocScorecardMetric.fromJson(Map<String, dynamic> json) {
    return EocScorecardMetric(
      id: json['id'] as String? ?? '',
      metricKey: json['metric_key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 0,
      weight: (json['weight'] as num?)?.toDouble() ?? 1,
      targetValue: (json['target_value'] as num?)?.toDouble(),
      actualValue: (json['actual_value'] as num?)?.toDouble(),
      status: json['status'] as String? ?? 'on_track',
    );
  }
}

class EocMeeting {
  const EocMeeting({
    required this.id,
    required this.title,
    this.meetingType = 'ops',
    this.scheduledAt,
    this.locationLabel,
    this.status = 'scheduled',
    this.organizerLabel,
  });

  final String id;
  final String title;
  final String meetingType;
  final DateTime? scheduledAt;
  final String? locationLabel;
  final String status;
  final String? organizerLabel;

  factory EocMeeting.fromJson(Map<String, dynamic> json) {
    return EocMeeting(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Meeting',
      meetingType: json['meeting_type'] as String? ?? 'ops',
      scheduledAt: DateTime.tryParse(json['scheduled_at'] as String? ?? ''),
      locationLabel: json['location_label'] as String?,
      status: json['status'] as String? ?? 'scheduled',
      organizerLabel: json['organizer_label'] as String?,
    );
  }
}

class EocDecision {
  const EocDecision({
    required this.id,
    required this.title,
    required this.decision,
    this.rationale,
    this.owners = const [],
    this.impact,
    this.status = 'recorded',
    this.decidedAt,
  });

  final String id;
  final String title;
  final String decision;
  final String? rationale;
  final List<String> owners;
  final String? impact;
  final String status;
  final DateTime? decidedAt;

  factory EocDecision.fromJson(Map<String, dynamic> json) {
    final rawOwners = json['owners'];
    return EocDecision(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Decision',
      decision: json['decision'] as String? ?? '',
      rationale: json['rationale'] as String?,
      owners: rawOwners is List
          ? rawOwners.map((e) => e.toString()).toList()
          : const [],
      impact: json['impact'] as String?,
      status: json['status'] as String? ?? 'recorded',
      decidedAt: DateTime.tryParse(json['decided_at'] as String? ?? ''),
    );
  }
}

class EocActivity {
  const EocActivity({
    required this.id,
    required this.action,
    required this.summary,
    this.actorLabel,
    this.moduleSlug,
    this.occurredAt,
  });

  final String id;
  final String action;
  final String summary;
  final String? actorLabel;
  final String? moduleSlug;
  final DateTime? occurredAt;

  factory EocActivity.fromJson(Map<String, dynamic> json) {
    return EocActivity(
      id: json['id'] as String? ?? '',
      action: json['action'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      actorLabel: json['actor_label'] as String?,
      moduleSlug: json['module_slug'] as String?,
      occurredAt: DateTime.tryParse(json['occurred_at'] as String? ?? ''),
    );
  }
}

class EocAuditEvent {
  const EocAuditEvent({
    required this.id,
    required this.action,
    this.entityType,
    this.summary,
    this.actorLabel,
    this.severity = 'info',
    this.occurredAt,
  });

  final String id;
  final String action;
  final String? entityType;
  final String? summary;
  final String? actorLabel;
  final String severity;
  final DateTime? occurredAt;

  factory EocAuditEvent.fromJson(Map<String, dynamic> json) {
    return EocAuditEvent(
      id: json['id'] as String? ?? '',
      action: json['action'] as String? ?? '',
      entityType: json['entity_type'] as String?,
      summary: json['summary'] as String?,
      actorLabel: json['actor_label'] as String?,
      severity: json['severity'] as String? ?? 'info',
      occurredAt: DateTime.tryParse(json['occurred_at'] as String? ?? ''),
    );
  }
}

class EocKnowledgeArticle {
  const EocKnowledgeArticle({
    required this.id,
    required this.slug,
    required this.title,
    required this.body,
    this.category = 'ops',
    this.status = 'published',
    this.tags = const [],
  });

  final String id;
  final String slug;
  final String title;
  final String body;
  final String category;
  final String status;
  final List<String> tags;

  factory EocKnowledgeArticle.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'];
    return EocKnowledgeArticle(
      id: json['id'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      category: json['category'] as String? ?? 'ops',
      status: json['status'] as String? ?? 'published',
      tags: rawTags is List ? rawTags.map((e) => e.toString()).toList() : const [],
    );
  }
}

class EocSearchHit {
  const EocSearchHit({
    required this.id,
    required this.title,
    required this.module,
    this.subtitle,
  });

  final String id;
  final String title;
  final String module;
  final String? subtitle;
}

class EocMissionControlSnapshot {
  const EocMissionControlSnapshot({
    required this.kpis,
    required this.moduleHealth,
    required this.alerts,
    required this.approvals,
    required this.workflows,
    required this.tasks,
    required this.aiInsights,
    required this.forecasts,
    required this.scorecards,
    required this.scorecardMetrics,
    required this.meetings,
    required this.decisions,
    required this.activities,
    required this.auditEvents,
    required this.knowledge,
    required this.searchHits,
    this.fromRemote = false,
    this.loadedAt,
    this.aiDisclaimer = kEocAiDisclaimer,
  });

  final List<EocKpi> kpis;
  final List<EocModuleHealth> moduleHealth;
  final List<EocAlert> alerts;
  final List<EocApproval> approvals;
  final List<EocWorkflowInstance> workflows;
  final List<EocTask> tasks;
  final List<EocAiInsight> aiInsights;
  final List<EocForecast> forecasts;
  final List<EocScorecard> scorecards;
  final List<EocScorecardMetric> scorecardMetrics;
  final List<EocMeeting> meetings;
  final List<EocDecision> decisions;
  final List<EocActivity> activities;
  final List<EocAuditEvent> auditEvents;
  final List<EocKnowledgeArticle> knowledge;
  final List<EocSearchHit> searchHits;
  final bool fromRemote;
  final DateTime? loadedAt;
  final String aiDisclaimer;
}

abstract final class EocDemo {
  static EocMissionControlSnapshot snapshot() {
    final now = DateTime.now();
    final kpis = _kpis();
    final alerts = _alerts();
    final approvals = _approvals();
    final workflows = _workflows();
    final tasks = _tasks(now);
    return EocMissionControlSnapshot(
      kpis: kpis,
      moduleHealth: _moduleHealth(),
      alerts: alerts,
      approvals: approvals,
      workflows: workflows,
      tasks: tasks,
      aiInsights: _aiInsights(),
      forecasts: _forecasts(),
      scorecards: _scorecards(),
      scorecardMetrics: _scorecardMetrics(),
      meetings: _meetings(now),
      decisions: _decisions(now),
      activities: _activities(now),
      auditEvents: _audit(now),
      knowledge: _knowledge(),
      searchHits: _searchHits(),
      fromRemote: false,
      loadedAt: now,
    );
  }

  static List<EocKpi> _kpis() => const [
        EocKpi(
          label: 'Revenue MTD',
          value: 218500000,
          unit: 'currency',
          changePct: 8.6,
        ),
        EocKpi(
          label: 'Sales Pipeline',
          value: 412000000,
          unit: 'currency',
          changePct: 6.2,
        ),
        EocKpi(label: 'Open Alerts', value: 4, changePct: -33.3, status: 'watch'),
        EocKpi(
          label: 'Pending Approvals',
          value: 7,
          changePct: 40,
          status: 'watch',
        ),
        EocKpi(label: 'Active Workflows', value: 12, changePct: 33.3),
        EocKpi(
          label: 'Module Health',
          value: 88,
          unit: 'percent',
          changePct: 2.3,
        ),
        EocKpi(label: 'Open Tasks', value: 15, changePct: -16.7),
      ];

  static List<EocModuleHealth> _moduleHealth() => const [
        EocModuleHealth(
          id: 'e0100007-0000-4000-8000-000000000001',
          moduleSlug: 'sales',
          label: 'Sales',
          healthPct: 92,
        ),
        EocModuleHealth(
          id: 'e0100007-0000-4000-8000-000000000002',
          moduleSlug: 'finance',
          label: 'Finance',
          healthPct: 86,
          openAlerts: 1,
        ),
        EocModuleHealth(
          id: 'e0100007-0000-4000-8000-000000000003',
          moduleSlug: 'construction',
          label: 'Construction',
          healthPct: 78,
          status: 'degraded',
          openAlerts: 2,
        ),
        EocModuleHealth(
          id: 'e0100007-0000-4000-8000-000000000004',
          moduleSlug: 'crm',
          label: 'CRM',
          healthPct: 90,
        ),
        EocModuleHealth(
          id: 'e0100007-0000-4000-8000-000000000005',
          moduleSlug: 'hr',
          label: 'HR',
          healthPct: 84,
          openAlerts: 1,
        ),
        EocModuleHealth(
          id: 'e0100007-0000-4000-8000-000000000006',
          moduleSlug: 'marketing',
          label: 'Marketing',
          healthPct: 88,
        ),
      ];

  static List<EocAlert> _alerts() => const [
        EocAlert(
          id: 'e0100011-0000-4000-8000-000000000001',
          title: 'Construction schedule slip — Block C',
          body: 'Milestone concrete pour delayed 4 days.',
          severity: 'warning',
          category: 'schedule',
          moduleSlug: 'construction',
        ),
        EocAlert(
          id: 'e0100011-0000-4000-8000-000000000002',
          title: 'Collections aging — 3 accounts > 30d',
          body: 'Finance flagged overdue client installments.',
          severity: 'critical',
          category: 'collections',
          moduleSlug: 'finance',
        ),
        EocAlert(
          id: 'e0100011-0000-4000-8000-000000000004',
          title: 'HR leave backlog',
          body: '5 leave requests pending manager action.',
          severity: 'warning',
          category: 'workforce',
          moduleSlug: 'hr',
        ),
      ];

  static List<EocApproval> _approvals() => const [
        EocApproval(
          id: 'e010000f-0000-4000-8000-000000000001',
          title: 'CapEx — Generator bank for Ikeja site',
          summary: 'Backup power upgrade for Phase 2 plot',
          moduleSlug: 'finance',
          amount: 18500000,
        ),
        EocApproval(
          id: 'e010000f-0000-4000-8000-000000000002',
          title: '8% discount — Plot B14 Lekki',
          summary: 'VIP client discount request',
          moduleSlug: 'sales',
          amount: 3200000,
        ),
      ];

  static List<EocWorkflowInstance> _workflows() => const [
        EocWorkflowInstance(
          id: 'e010000d-0000-4000-8000-000000000001',
          referenceLabel: 'PO-2026-4481',
          status: 'waiting',
          currentStepKey: 'manager_approval',
          definitionName: 'Purchase Order Escalation',
        ),
        EocWorkflowInstance(
          id: 'e010000d-0000-4000-8000-000000000002',
          referenceLabel: 'CTR-2026-119',
          status: 'running',
          currentStepKey: 'legal_review',
          definitionName: 'Sales Contract Routing',
        ),
      ];

  static List<EocTask> _tasks(DateTime now) => [
        EocTask(
          id: 'e0100013-0000-4000-8000-000000000001',
          title: 'Clear CapEx dual approval',
          description: 'Route generator PO to CFO + COO',
          priority: 'urgent',
          moduleSlug: 'finance',
          assigneeLabel: 'CFO Desk',
          dueAt: now.add(const Duration(days: 1)),
        ),
        EocTask(
          id: 'e0100013-0000-4000-8000-000000000002',
          title: 'Site catch-up plan Block C',
          status: 'in_progress',
          priority: 'high',
          moduleSlug: 'construction',
          assigneeLabel: 'Site Ops',
          dueAt: now.add(const Duration(days: 2)),
        ),
        EocTask(
          id: 'e0100013-0000-4000-8000-000000000003',
          title: 'Collections call list',
          priority: 'high',
          moduleSlug: 'finance',
          assigneeLabel: 'AR Lead',
          dueAt: now.add(const Duration(days: 1)),
        ),
      ];

  static List<EocAiInsight> _aiInsights() => const [
        EocAiInsight(
          id: 'ai-eoc-collections',
          title: 'Collections pressure — top accounts',
          body:
              'Three aging accounts drive the critical finance alert. Prioritize same-day outbound and CapEx pause already logged.',
          category: 'finance',
          confidencePct: 74,
        ),
        EocAiInsight(
          id: 'ai-eoc-site',
          title: 'Site recovery window',
          body:
              'Block C slip is recoverable if pour resumes within 48h; otherwise Q3 scorecard site_delivery stays at risk.',
          category: 'construction',
          confidencePct: 68,
        ),
        EocAiInsight(
          id: 'ai-eoc-pipeline',
          title: 'Pipeline acceleration signal',
          body:
              'Lekki demand + discount request suggests pull-forward launch decision remains validated — advisory only.',
          category: 'sales',
          confidencePct: 61,
        ),
      ];

  static List<EocForecast> _forecasts() => const [
        EocForecast(
          id: 'e0100018-0000-4000-8000-000000000001',
          label: 'Revenue next 30d',
          predictedValue: 95000000,
          unit: 'currency',
          confidencePct: 72,
        ),
        EocForecast(
          id: 'e0100018-0000-4000-8000-000000000002',
          label: 'Revenue next 30d (upside)',
          predictedValue: 112000000,
          unit: 'currency',
          confidencePct: 58,
          scenario: 'upside',
        ),
        EocForecast(
          id: 'e0100018-0000-4000-8000-000000000003',
          label: 'Expected closes (units)',
          predictedValue: 14,
          confidencePct: 66,
        ),
      ];

  static List<EocScorecard> _scorecards() => const [
        EocScorecard(
          id: 'e010001c-0000-4000-8000-000000000001',
          code: 'SC-Q3-2026',
          name: 'Q3 2026 Executive Scorecard',
          overallScore: 84.5,
          ownerLabel: 'CEO Office',
        ),
      ];

  static List<EocScorecardMetric> _scorecardMetrics() => const [
        EocScorecardMetric(
          id: 'e010001d-0000-4000-8000-000000000001',
          metricKey: 'revenue',
          label: 'Revenue',
          score: 86,
          weight: 2,
          targetValue: 250000000,
          actualValue: 218500000,
          status: 'watch',
        ),
        EocScorecardMetric(
          id: 'e010001d-0000-4000-8000-000000000002',
          metricKey: 'sales_velocity',
          label: 'Sales Velocity',
          score: 90,
          weight: 1.5,
          targetValue: 20,
          actualValue: 18,
        ),
        EocScorecardMetric(
          id: 'e010001d-0000-4000-8000-000000000003',
          metricKey: 'site_delivery',
          label: 'Site Delivery',
          score: 74,
          weight: 2,
          targetValue: 95,
          actualValue: 78,
          status: 'at_risk',
        ),
      ];

  static List<EocMeeting> _meetings(DateTime now) => [
        EocMeeting(
          id: 'e0100014-0000-4000-8000-000000000001',
          title: 'Weekly Ops Sync',
          scheduledAt: now.add(const Duration(days: 1)),
          locationLabel: 'Lagos HQ Boardroom',
          organizerLabel: 'COO Office',
        ),
        EocMeeting(
          id: 'e0100014-0000-4000-8000-000000000002',
          title: 'Executive KPI Review',
          meetingType: 'executive',
          scheduledAt: now.add(const Duration(days: 3)),
          locationLabel: 'Virtual',
          organizerLabel: 'CEO Office',
        ),
      ];

  static List<EocDecision> _decisions(DateTime now) => [
        EocDecision(
          id: 'e0100016-0000-4000-8000-000000000001',
          title: 'Accelerate Lekki Phase 2 launch',
          decision: 'Pull forward launch window by 2 weeks',
          rationale: 'Pipeline demand + marketing readiness',
          owners: const ['CEO', 'CMO'],
          impact: 'Revenue pull-forward / delivery risk',
          status: 'reviewing',
          decidedAt: now.subtract(const Duration(days: 1)),
        ),
        EocDecision(
          id: 'e0100016-0000-4000-8000-000000000002',
          title: 'Pause non-critical CapEx',
          decision: 'Hold non-site CapEx under ₦2M for 30 days',
          owners: const ['CFO'],
          impact: 'Working capital preservation',
          status: 'implemented',
          decidedAt: now.subtract(const Duration(days: 2)),
        ),
      ];

  static List<EocActivity> _activities(DateTime now) => [
        EocActivity(
          id: 'e010001e-0000-4000-8000-000000000001',
          action: 'alert.opened',
          summary: 'Collections aging alert opened',
          actorLabel: 'System',
          moduleSlug: 'finance',
          occurredAt: now.subtract(const Duration(hours: 1)),
        ),
        EocActivity(
          id: 'e010001e-0000-4000-8000-000000000002',
          action: 'approval.submitted',
          summary: 'CapEx generator bank submitted for dual approval',
          actorLabel: 'Finance Ops',
          moduleSlug: 'finance',
          occurredAt: now.subtract(const Duration(hours: 3)),
        ),
        EocActivity(
          id: 'e010001e-0000-4000-8000-000000000003',
          action: 'workflow.waiting',
          summary: 'PO-2026-4481 waiting on manager approval',
          actorLabel: 'Automation',
          moduleSlug: 'finance',
          occurredAt: now.subtract(const Duration(hours: 5)),
        ),
      ];

  static List<EocAuditEvent> _audit(DateTime now) => [
        EocAuditEvent(
          id: 'e010001f-0000-4000-8000-000000000001',
          action: 'eoc.seed',
          entityType: 'eoc_dashboards',
          summary: 'Mission Control dashboard seeded',
          actorLabel: 'Migration',
          occurredAt: now.subtract(const Duration(days: 1)),
        ),
        EocAuditEvent(
          id: 'e010001f-0000-4000-8000-000000000002',
          action: 'approval.view',
          entityType: 'approval_requests',
          summary: 'Pending CapEx approval queued in EOC',
          actorLabel: 'System',
          occurredAt: now.subtract(const Duration(hours: 2)),
        ),
      ];

  static List<EocKnowledgeArticle> _knowledge() => const [
        EocKnowledgeArticle(
          id: 'e0100019-0000-4000-8000-000000000001',
          slug: 'eoc-playbook-alerts',
          title: 'EOC Alert Triage Playbook',
          body:
              'Severity critical → page owner within 15m; warning → same-day; info → backlog.',
          tags: ['alerts', 'playbook'],
        ),
        EocKnowledgeArticle(
          id: 'e0100019-0000-4000-8000-000000000002',
          slug: 'eoc-approval-sla',
          title: 'Approval SLA Guide',
          body:
              'CapEx dual approval SLA is 48h; discounts above 5% require sales lead + finance.',
          category: 'governance',
          tags: ['approvals', 'sla'],
        ),
      ];

  static List<EocSearchHit> _searchHits() => const [
        EocSearchHit(
          id: 'hit-capex',
          title: 'CapEx — Generator bank for Ikeja site',
          module: 'approvals',
          subtitle: 'Pending · ₦18.5M',
        ),
        EocSearchHit(
          id: 'hit-block-c',
          title: 'Construction schedule slip — Block C',
          module: 'alerts',
          subtitle: 'Warning · open',
        ),
        EocSearchHit(
          id: 'hit-po',
          title: 'PO-2026-4481',
          module: 'workflows',
          subtitle: 'Waiting · manager approval',
        ),
      ];
}
