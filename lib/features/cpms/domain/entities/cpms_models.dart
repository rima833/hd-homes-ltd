// Volume 4 Part 6 — Enterprise Construction & Project Management System domain models.

const String kConstructionForecastDisclaimer =
    'Forecasts are estimates only and are not guarantees of delivery dates or costs.';

String formatCpmsMoney(double? value) {
  if (value == null) return '—';
  final n = value;
  if (n >= 1e9) return '₦${(n / 1e9).toStringAsFixed(1)}B';
  if (n >= 1e6) return '₦${(n / 1e6).toStringAsFixed(1)}M';
  if (n >= 1e3) return '₦${(n / 1e3).toStringAsFixed(0)}K';
  return '₦${n.toStringAsFixed(0)}';
}

enum ConstructionProjectStatus {
  draft,
  planning,
  approved,
  active,
  onHold,
  completed,
  archived;

  String get label => switch (this) {
        ConstructionProjectStatus.draft => 'Draft',
        ConstructionProjectStatus.planning => 'Planning',
        ConstructionProjectStatus.approved => 'Approved',
        ConstructionProjectStatus.active => 'Active',
        ConstructionProjectStatus.onHold => 'On Hold',
        ConstructionProjectStatus.completed => 'Completed',
        ConstructionProjectStatus.archived => 'Archived',
      };

  String get slug => switch (this) {
        ConstructionProjectStatus.onHold => 'on_hold',
        _ => name,
      };

  static ConstructionProjectStatus fromSlug(String? raw) {
    return switch ((raw ?? 'draft').toLowerCase()) {
      'planning' => ConstructionProjectStatus.planning,
      'approved' => ConstructionProjectStatus.approved,
      'active' => ConstructionProjectStatus.active,
      'on_hold' || 'onhold' => ConstructionProjectStatus.onHold,
      'completed' => ConstructionProjectStatus.completed,
      'archived' => ConstructionProjectStatus.archived,
      _ => ConstructionProjectStatus.draft,
    };
  }
}

enum MilestoneStatus {
  planned,
  inProgress,
  completed,
  delayed,
  cancelled;

  String get label => switch (this) {
        MilestoneStatus.planned => 'Planned',
        MilestoneStatus.inProgress => 'In Progress',
        MilestoneStatus.completed => 'Completed',
        MilestoneStatus.delayed => 'Delayed',
        MilestoneStatus.cancelled => 'Cancelled',
      };

  String get slug => switch (this) {
        MilestoneStatus.inProgress => 'in_progress',
        _ => name,
      };

  static MilestoneStatus fromSlug(String? raw) {
    return switch ((raw ?? 'planned').toLowerCase()) {
      'in_progress' || 'inprogress' => MilestoneStatus.inProgress,
      'completed' => MilestoneStatus.completed,
      'delayed' => MilestoneStatus.delayed,
      'cancelled' => MilestoneStatus.cancelled,
      _ => MilestoneStatus.planned,
    };
  }
}

enum TaskStatus {
  todo,
  inProgress,
  blocked,
  done,
  cancelled;

  String get label => switch (this) {
        TaskStatus.todo => 'To Do',
        TaskStatus.inProgress => 'In Progress',
        TaskStatus.blocked => 'Blocked',
        TaskStatus.done => 'Done',
        TaskStatus.cancelled => 'Cancelled',
      };

  String get slug => switch (this) {
        TaskStatus.inProgress => 'in_progress',
        _ => name,
      };

  static TaskStatus fromSlug(String? raw) {
    return switch ((raw ?? 'todo').toLowerCase()) {
      'in_progress' || 'inprogress' => TaskStatus.inProgress,
      'blocked' => TaskStatus.blocked,
      'done' => TaskStatus.done,
      'cancelled' => TaskStatus.cancelled,
      _ => TaskStatus.todo,
    };
  }
}

enum RiskSeverity {
  low,
  medium,
  high,
  critical;

  String get label => switch (this) {
        RiskSeverity.low => 'Low',
        RiskSeverity.medium => 'Medium',
        RiskSeverity.high => 'High',
        RiskSeverity.critical => 'Critical',
      };

  String get slug => name;

  static RiskSeverity fromSlug(String? raw) {
    return switch ((raw ?? 'medium').toLowerCase()) {
      'low' => RiskSeverity.low,
      'high' => RiskSeverity.high,
      'critical' => RiskSeverity.critical,
      _ => RiskSeverity.medium,
    };
  }
}

enum ChangeOrderStatus {
  draft,
  pending,
  approved,
  rejected,
  implemented,
  cancelled;

  String get label => switch (this) {
        ChangeOrderStatus.draft => 'Draft',
        ChangeOrderStatus.pending => 'Pending',
        ChangeOrderStatus.approved => 'Approved',
        ChangeOrderStatus.rejected => 'Rejected',
        ChangeOrderStatus.implemented => 'Implemented',
        ChangeOrderStatus.cancelled => 'Cancelled',
      };

  String get slug => name;

  static ChangeOrderStatus fromSlug(String? raw) {
    return switch ((raw ?? 'draft').toLowerCase()) {
      'pending' => ChangeOrderStatus.pending,
      'approved' => ChangeOrderStatus.approved,
      'rejected' => ChangeOrderStatus.rejected,
      'implemented' => ChangeOrderStatus.implemented,
      'cancelled' => ChangeOrderStatus.cancelled,
      _ => ChangeOrderStatus.draft,
    };
  }
}

class CpmsProject {
  const CpmsProject({
    required this.id,
    required this.projectCode,
    required this.name,
    this.description,
    this.status = ConstructionProjectStatus.draft,
    this.locationLabel,
    this.managerLabel,
    this.progressPct = 0,
    this.budgetTotal = 0,
    this.budgetSpent = 0,
    this.riskLevel = RiskSeverity.medium,
    this.delayDays = 0,
    this.aiSummary,
    this.forecastCompletionAt,
    this.forecastConfidencePct,
    this.forecastDisclaimer = kConstructionForecastDisclaimer,
    this.targetEndDate,
    this.startDate,
    this.estateLabel,
  });

  final String id;
  final String projectCode;
  final String name;
  final String? description;
  final ConstructionProjectStatus status;
  final String? locationLabel;
  final String? managerLabel;
  final double progressPct;
  final double budgetTotal;
  final double budgetSpent;
  final RiskSeverity riskLevel;
  final int delayDays;
  final String? aiSummary;
  final DateTime? forecastCompletionAt;
  final double? forecastConfidencePct;
  final String forecastDisclaimer;
  final DateTime? targetEndDate;
  final DateTime? startDate;
  final String? estateLabel;

  bool get isDelayed =>
      delayDays > 0 || status == ConstructionProjectStatus.onHold;

  double get budgetVariancePct =>
      budgetTotal <= 0 ? 0 : (budgetSpent / budgetTotal) * 100;

  String get budgetDisplay => formatCpmsMoney(budgetTotal);
  String get spentDisplay => formatCpmsMoney(budgetSpent);

  factory CpmsProject.fromJson(Map<String, dynamic> json) {
    String? estateLabel;
    final estate = json['estates'];
    if (estate is Map) {
      estateLabel = estate['name'] as String? ?? estate['slug'] as String?;
    }
    return CpmsProject(
      id: json['id'] as String,
      projectCode: json['project_code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      status: ConstructionProjectStatus.fromSlug(json['status'] as String?),
      locationLabel: json['location_label'] as String?,
      managerLabel: json['manager_label'] as String?,
      progressPct: (json['progress_pct'] as num?)?.toDouble() ?? 0,
      budgetTotal: (json['budget_total'] as num?)?.toDouble() ?? 0,
      budgetSpent: (json['budget_spent'] as num?)?.toDouble() ?? 0,
      riskLevel: RiskSeverity.fromSlug(json['risk_level'] as String?),
      delayDays: (json['delay_days'] as num?)?.toInt() ?? 0,
      aiSummary: json['ai_summary'] as String?,
      forecastCompletionAt:
          DateTime.tryParse(json['forecast_completion_at'] as String? ?? ''),
      forecastConfidencePct:
          (json['forecast_confidence_pct'] as num?)?.toDouble(),
      forecastDisclaimer: json['forecast_disclaimer'] as String? ??
          kConstructionForecastDisclaimer,
      targetEndDate: DateTime.tryParse(json['target_end_date'] as String? ?? ''),
      startDate: DateTime.tryParse(json['start_date'] as String? ?? ''),
      estateLabel: estateLabel,
    );
  }
}

class CpmsMilestone {
  const CpmsMilestone({
    required this.id,
    required this.projectId,
    required this.name,
    this.status = MilestoneStatus.planned,
    this.dueDate,
    this.progressPct = 0,
    this.isCritical = false,
    this.notes,
    this.projectName,
  });

  final String id;
  final String projectId;
  final String name;
  final MilestoneStatus status;
  final DateTime? dueDate;
  final double progressPct;
  final bool isCritical;
  final String? notes;
  final String? projectName;

  bool get isOverdue {
    if (dueDate == null) return false;
    if (status == MilestoneStatus.completed ||
        status == MilestoneStatus.cancelled) {
      return false;
    }
    return dueDate!.isBefore(DateTime.now());
  }

  factory CpmsMilestone.fromJson(Map<String, dynamic> json) {
    String? projectName;
    final project = json['construction_projects'];
    if (project is Map) {
      projectName = project['name'] as String?;
    }
    return CpmsMilestone(
      id: json['id'] as String,
      projectId: json['project_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      status: MilestoneStatus.fromSlug(json['status'] as String?),
      dueDate: DateTime.tryParse(json['due_date'] as String? ?? ''),
      progressPct: (json['progress_pct'] as num?)?.toDouble() ?? 0,
      isCritical: json['is_critical'] as bool? ?? false,
      notes: json['notes'] as String?,
      projectName: projectName,
    );
  }
}

class CpmsTask {
  const CpmsTask({
    required this.id,
    required this.projectId,
    required this.title,
    this.status = TaskStatus.todo,
    this.priority = 'medium',
    this.assigneeLabel,
    this.dueDate,
    this.progressPct = 0,
    this.notes,
    this.projectName,
  });

  final String id;
  final String projectId;
  final String title;
  final TaskStatus status;
  final String priority;
  final String? assigneeLabel;
  final DateTime? dueDate;
  final double progressPct;
  final String? notes;
  final String? projectName;

  factory CpmsTask.fromJson(Map<String, dynamic> json) {
    String? projectName;
    final project = json['construction_projects'];
    if (project is Map) {
      projectName = project['name'] as String?;
    }
    return CpmsTask(
      id: json['id'] as String,
      projectId: json['project_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      status: TaskStatus.fromSlug(json['status'] as String?),
      priority: json['priority'] as String? ?? 'medium',
      assigneeLabel: json['assignee_label'] as String?,
      dueDate: DateTime.tryParse(json['due_date'] as String? ?? ''),
      progressPct: (json['progress_pct'] as num?)?.toDouble() ?? 0,
      notes: json['notes'] as String?,
      projectName: projectName,
    );
  }
}

class CpmsContractor {
  const CpmsContractor({
    required this.id,
    required this.projectId,
    required this.companyName,
    this.contactName,
    this.specialty,
    this.status = 'active',
    this.contractValue = 0,
    this.performanceScore,
    this.projectName,
  });

  final String id;
  final String projectId;
  final String companyName;
  final String? contactName;
  final String? specialty;
  final String status;
  final double contractValue;
  final double? performanceScore;
  final String? projectName;

  String get valueDisplay => formatCpmsMoney(contractValue);

  factory CpmsContractor.fromJson(Map<String, dynamic> json) {
    String? projectName;
    final project = json['construction_projects'];
    if (project is Map) {
      projectName = project['name'] as String?;
    }
    return CpmsContractor(
      id: json['id'] as String,
      projectId: json['project_id'] as String? ?? '',
      companyName: json['company_name'] as String? ?? '',
      contactName: json['contact_name'] as String?,
      specialty: json['specialty'] as String?,
      status: json['status'] as String? ?? 'active',
      contractValue: (json['contract_value'] as num?)?.toDouble() ?? 0,
      performanceScore: (json['performance_score'] as num?)?.toDouble(),
      projectName: projectName,
    );
  }
}

class CpmsBudgetLine {
  const CpmsBudgetLine({
    required this.id,
    required this.projectId,
    required this.category,
    this.description,
    this.budgetedAmount = 0,
    this.committedAmount = 0,
    this.spentAmount = 0,
  });

  final String id;
  final String projectId;
  final String category;
  final String? description;
  final double budgetedAmount;
  final double committedAmount;
  final double spentAmount;

  factory CpmsBudgetLine.fromJson(Map<String, dynamic> json) {
    return CpmsBudgetLine(
      id: json['id'] as String,
      projectId: json['project_id'] as String? ?? '',
      category: json['category'] as String? ?? '',
      description: json['description'] as String?,
      budgetedAmount: (json['budgeted_amount'] as num?)?.toDouble() ?? 0,
      committedAmount: (json['committed_amount'] as num?)?.toDouble() ?? 0,
      spentAmount: (json['spent_amount'] as num?)?.toDouble() ?? 0,
    );
  }
}

class CpmsBudgetSummary {
  const CpmsBudgetSummary({
    required this.projectId,
    required this.projectName,
    required this.lines,
    this.pendingChangeOrderImpact = 0,
  });

  final String projectId;
  final String projectName;
  final List<CpmsBudgetLine> lines;
  final double pendingChangeOrderImpact;

  double get budgeted =>
      lines.fold<double>(0, (s, l) => s + l.budgetedAmount);
  double get spent => lines.fold<double>(0, (s, l) => s + l.spentAmount);
  double get committed =>
      lines.fold<double>(0, (s, l) => s + l.committedAmount);
}

class CpmsProcurementRequest {
  const CpmsProcurementRequest({
    required this.id,
    required this.projectId,
    required this.requestCode,
    required this.title,
    this.status = 'draft',
    this.estimatedCost = 0,
    this.neededBy,
    this.requestedByLabel,
  });

  final String id;
  final String projectId;
  final String requestCode;
  final String title;
  final String status;
  final double estimatedCost;
  final DateTime? neededBy;
  final String? requestedByLabel;

  String get costDisplay => formatCpmsMoney(estimatedCost);

  factory CpmsProcurementRequest.fromJson(Map<String, dynamic> json) {
    return CpmsProcurementRequest(
      id: json['id'] as String,
      projectId: json['project_id'] as String? ?? '',
      requestCode: json['request_code'] as String? ?? '',
      title: json['title'] as String? ?? '',
      status: json['status'] as String? ?? 'draft',
      estimatedCost: (json['estimated_cost'] as num?)?.toDouble() ?? 0,
      neededBy: DateTime.tryParse(json['needed_by'] as String? ?? ''),
      requestedByLabel: json['requested_by_label'] as String?,
    );
  }
}

class CpmsChangeOrder {
  const CpmsChangeOrder({
    required this.id,
    required this.projectId,
    required this.changeCode,
    required this.title,
    this.status = ChangeOrderStatus.draft,
    this.costImpact = 0,
    this.scheduleImpactDays = 0,
    this.requestedByLabel,
    this.rationale,
    this.projectName,
  });

  final String id;
  final String projectId;
  final String changeCode;
  final String title;
  final ChangeOrderStatus status;
  final double costImpact;
  final int scheduleImpactDays;
  final String? requestedByLabel;
  final String? rationale;
  final String? projectName;

  String get costDisplay => formatCpmsMoney(costImpact);

  factory CpmsChangeOrder.fromJson(Map<String, dynamic> json) {
    String? projectName;
    final project = json['construction_projects'];
    if (project is Map) {
      projectName = project['name'] as String?;
    }
    return CpmsChangeOrder(
      id: json['id'] as String,
      projectId: json['project_id'] as String? ?? '',
      changeCode: json['change_code'] as String? ?? '',
      title: json['title'] as String? ?? '',
      status: ChangeOrderStatus.fromSlug(json['status'] as String?),
      costImpact: (json['cost_impact'] as num?)?.toDouble() ?? 0,
      scheduleImpactDays: (json['schedule_impact_days'] as num?)?.toInt() ?? 0,
      requestedByLabel: json['requested_by_label'] as String?,
      rationale: json['rationale'] as String?,
      projectName: projectName,
    );
  }
}

class CpmsSafetyIncident {
  const CpmsSafetyIncident({
    required this.id,
    required this.projectId,
    required this.title,
    this.severity = RiskSeverity.medium,
    this.status = 'open',
    this.occurredAt,
    this.locationLabel,
    this.reportedByLabel,
    this.description,
    this.projectName,
  });

  final String id;
  final String projectId;
  final String title;
  final RiskSeverity severity;
  final String status;
  final DateTime? occurredAt;
  final String? locationLabel;
  final String? reportedByLabel;
  final String? description;
  final String? projectName;

  factory CpmsSafetyIncident.fromJson(Map<String, dynamic> json) {
    String? projectName;
    final project = json['construction_projects'];
    if (project is Map) {
      projectName = project['name'] as String?;
    }
    return CpmsSafetyIncident(
      id: json['id'] as String,
      projectId: json['project_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      severity: RiskSeverity.fromSlug(json['severity'] as String?),
      status: json['status'] as String? ?? 'open',
      occurredAt: DateTime.tryParse(json['occurred_at'] as String? ?? ''),
      locationLabel: json['location_label'] as String?,
      reportedByLabel: json['reported_by_label'] as String?,
      description: json['description'] as String?,
      projectName: projectName,
    );
  }
}

class CpmsSiteDiary {
  const CpmsSiteDiary({
    required this.id,
    required this.projectId,
    required this.summary,
    this.entryDate,
    this.weather,
    this.workforceCount,
    this.blockers,
    this.authorLabel,
    this.projectName,
  });

  final String id;
  final String projectId;
  final String summary;
  final DateTime? entryDate;
  final String? weather;
  final int? workforceCount;
  final String? blockers;
  final String? authorLabel;
  final String? projectName;

  factory CpmsSiteDiary.fromJson(Map<String, dynamic> json) {
    String? projectName;
    final project = json['construction_projects'];
    if (project is Map) {
      projectName = project['name'] as String?;
    }
    return CpmsSiteDiary(
      id: json['id'] as String,
      projectId: json['project_id'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      entryDate: DateTime.tryParse(json['entry_date'] as String? ?? ''),
      weather: json['weather'] as String?,
      workforceCount: (json['workforce_count'] as num?)?.toInt(),
      blockers: json['blockers'] as String?,
      authorLabel: json['author_label'] as String?,
      projectName: projectName,
    );
  }
}

class CpmsDefect {
  const CpmsDefect({
    required this.id,
    required this.projectId,
    required this.title,
    this.severity = RiskSeverity.medium,
    this.status = 'open',
    this.locationLabel,
    this.notes,
    this.projectName,
  });

  final String id;
  final String projectId;
  final String title;
  final RiskSeverity severity;
  final String status;
  final String? locationLabel;
  final String? notes;
  final String? projectName;

  factory CpmsDefect.fromJson(Map<String, dynamic> json) {
    String? projectName;
    final project = json['construction_projects'];
    if (project is Map) {
      projectName = project['name'] as String?;
    }
    return CpmsDefect(
      id: json['id'] as String,
      projectId: json['project_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      severity: RiskSeverity.fromSlug(json['severity'] as String?),
      status: json['status'] as String? ?? 'open',
      locationLabel: json['location_label'] as String?,
      notes: json['notes'] as String?,
      projectName: projectName,
    );
  }
}

class CpmsInspection {
  const CpmsInspection({
    required this.id,
    required this.projectId,
    required this.title,
    this.inspectionType = 'site',
    this.status = 'scheduled',
    this.scheduledAt,
    this.inspectorLabel,
    this.notes,
  });

  final String id;
  final String projectId;
  final String title;
  final String inspectionType;
  final String status;
  final DateTime? scheduledAt;
  final String? inspectorLabel;
  final String? notes;

  factory CpmsInspection.fromJson(Map<String, dynamic> json) {
    return CpmsInspection(
      id: json['id'] as String,
      projectId: json['project_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      inspectionType: json['inspection_type'] as String? ?? 'site',
      status: json['status'] as String? ?? 'scheduled',
      scheduledAt: DateTime.tryParse(json['scheduled_at'] as String? ?? ''),
      inspectorLabel: json['inspector_label'] as String?,
      notes: json['notes'] as String?,
    );
  }
}

class CpmsQualityCheck {
  const CpmsQualityCheck({
    required this.id,
    required this.projectId,
    required this.title,
    this.status = 'pending',
    this.scorePct,
    this.inspectorLabel,
    this.checkedAt,
  });

  final String id;
  final String projectId;
  final String title;
  final String status;
  final double? scorePct;
  final String? inspectorLabel;
  final DateTime? checkedAt;

  factory CpmsQualityCheck.fromJson(Map<String, dynamic> json) {
    return CpmsQualityCheck(
      id: json['id'] as String,
      projectId: json['project_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      scorePct: (json['score_pct'] as num?)?.toDouble(),
      inspectorLabel: json['inspector_label'] as String?,
      checkedAt: DateTime.tryParse(json['checked_at'] as String? ?? ''),
    );
  }
}

class CpmsRisk {
  const CpmsRisk({
    required this.id,
    required this.projectId,
    required this.title,
    this.severity = RiskSeverity.medium,
    this.likelihood = 'possible',
    this.status = 'open',
    this.mitigation,
    this.ownerLabel,
  });

  final String id;
  final String projectId;
  final String title;
  final RiskSeverity severity;
  final String likelihood;
  final String status;
  final String? mitigation;
  final String? ownerLabel;

  factory CpmsRisk.fromJson(Map<String, dynamic> json) {
    return CpmsRisk(
      id: json['id'] as String,
      projectId: json['project_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      severity: RiskSeverity.fromSlug(json['severity'] as String?),
      likelihood: json['likelihood'] as String? ?? 'possible',
      status: json['status'] as String? ?? 'open',
      mitigation: json['mitigation'] as String?,
      ownerLabel: json['owner_label'] as String?,
    );
  }
}

class CpmsActivity {
  const CpmsActivity({
    required this.id,
    required this.title,
    this.projectId,
    this.eventType = 'note',
    this.description,
    this.actorLabel,
    this.occurredAt,
  });

  final String id;
  final String title;
  final String? projectId;
  final String eventType;
  final String? description;
  final String? actorLabel;
  final DateTime? occurredAt;

  factory CpmsActivity.fromJson(Map<String, dynamic> json) {
    return CpmsActivity(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      projectId: json['project_id'] as String?,
      eventType: json['event_type'] as String? ?? 'note',
      description: json['description'] as String?,
      actorLabel: json['actor_label'] as String?,
      occurredAt: DateTime.tryParse(json['occurred_at'] as String? ?? ''),
    );
  }
}

class CpmsAlert {
  const CpmsAlert({
    required this.id,
    required this.title,
    this.body,
    this.severity = 'info',
    this.status = 'unread',
    this.projectId,
    this.createdAt,
  });

  final String id;
  final String title;
  final String? body;
  final String severity;
  final String status;
  final String? projectId;
  final DateTime? createdAt;

  factory CpmsAlert.fromJson(Map<String, dynamic> json) {
    return CpmsAlert(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      body: json['body'] as String?,
      severity: json['severity'] as String? ?? 'info',
      status: json['status'] as String? ?? 'unread',
      projectId: json['project_id'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }
}

class CpmsKpi {
  const CpmsKpi({
    required this.label,
    required this.value,
    this.unit = 'count',
  });

  final String label;
  final double value;
  final String unit;

  String get displayValue {
    if (unit == 'ngn') return formatCpmsMoney(value);
    if (unit == 'percent') {
      return value == value.roundToDouble()
          ? '${value.toStringAsFixed(0)}%'
          : '${value.toStringAsFixed(1)}%';
    }
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }
}

class CpmsAiInsight {
  const CpmsAiInsight({
    required this.id,
    required this.title,
    required this.body,
    this.category = 'assistant',
    this.isAiGenerated = true,
    this.projectId,
    this.confidencePct,
    this.disclaimer = kConstructionForecastDisclaimer,
  });

  final String id;
  final String title;
  final String body;
  final String category;
  final bool isAiGenerated;
  final String? projectId;
  final double? confidencePct;
  final String disclaimer;
}

/// Project Creation Wizard — 7 steps.
class CpmsWizardDraft {
  const CpmsWizardDraft({
    this.step = 0,
    this.name = '',
    this.projectCode = '',
    this.locationLabel = '',
    this.managerLabel = '',
    this.budgetTotal = 0,
    this.startDate,
    this.targetEndDate,
    this.phaseNames = const [],
    this.milestoneNames = const [],
    this.contractorNames = const [],
    this.notes = '',
  });

  final int step;
  final String name;
  final String projectCode;
  final String locationLabel;
  final String managerLabel;
  final double budgetTotal;
  final DateTime? startDate;
  final DateTime? targetEndDate;
  final List<String> phaseNames;
  final List<String> milestoneNames;
  final List<String> contractorNames;
  final String notes;

  static const List<String> stepTitles = [
    'Basics',
    'Schedule',
    'Budget',
    'Phases',
    'Milestones',
    'Contractors',
    'Review',
  ];

  int get totalSteps => stepTitles.length;
  bool get isComplete => step >= totalSteps - 1;
  String get currentStepTitle =>
      stepTitles[step.clamp(0, totalSteps - 1)];

  CpmsWizardDraft copyWith({
    int? step,
    String? name,
    String? projectCode,
    String? locationLabel,
    String? managerLabel,
    double? budgetTotal,
    DateTime? startDate,
    DateTime? targetEndDate,
    List<String>? phaseNames,
    List<String>? milestoneNames,
    List<String>? contractorNames,
    String? notes,
  }) {
    return CpmsWizardDraft(
      step: step ?? this.step,
      name: name ?? this.name,
      projectCode: projectCode ?? this.projectCode,
      locationLabel: locationLabel ?? this.locationLabel,
      managerLabel: managerLabel ?? this.managerLabel,
      budgetTotal: budgetTotal ?? this.budgetTotal,
      startDate: startDate ?? this.startDate,
      targetEndDate: targetEndDate ?? this.targetEndDate,
      phaseNames: phaseNames ?? this.phaseNames,
      milestoneNames: milestoneNames ?? this.milestoneNames,
      contractorNames: contractorNames ?? this.contractorNames,
      notes: notes ?? this.notes,
    );
  }

  CpmsWizardDraft next() =>
      copyWith(step: (step + 1).clamp(0, totalSteps - 1));

  CpmsWizardDraft previous() =>
      copyWith(step: (step - 1).clamp(0, totalSteps - 1));
}

class CpmsCommandCenterSnapshot {
  const CpmsCommandCenterSnapshot({
    required this.kpis,
    required this.projects,
    required this.milestones,
    required this.tasks,
    required this.contractors,
    required this.procurementRequests,
    required this.changeOrders,
    required this.budgetLines,
    required this.qualityChecks,
    required this.defects,
    required this.safetyIncidents,
    required this.siteDiaries,
    required this.inspections,
    required this.risks,
    required this.activities,
    required this.alerts,
    required this.aiInsights,
    required this.progressIntelligence,
    this.fromRemote = false,
    this.loadedAt,
    this.forecastDisclaimer = kConstructionForecastDisclaimer,
  });

  final List<CpmsKpi> kpis;
  final List<CpmsProject> projects;
  final List<CpmsMilestone> milestones;
  final List<CpmsTask> tasks;
  final List<CpmsContractor> contractors;
  final List<CpmsProcurementRequest> procurementRequests;
  final List<CpmsChangeOrder> changeOrders;
  final List<CpmsBudgetLine> budgetLines;
  final List<CpmsQualityCheck> qualityChecks;
  final List<CpmsDefect> defects;
  final List<CpmsSafetyIncident> safetyIncidents;
  final List<CpmsSiteDiary> siteDiaries;
  final List<CpmsInspection> inspections;
  final List<CpmsRisk> risks;
  final List<CpmsActivity> activities;
  final List<CpmsAlert> alerts;
  final List<CpmsAiInsight> aiInsights;
  final List<String> progressIntelligence;
  final bool fromRemote;
  final DateTime? loadedAt;
  final String forecastDisclaimer;

  List<CpmsBudgetSummary> budgetSummaries() {
    final byProject = <String, List<CpmsBudgetLine>>{};
    for (final line in budgetLines) {
      byProject.putIfAbsent(line.projectId, () => []).add(line);
    }
    return byProject.entries.map((e) {
      final project = projects.cast<CpmsProject?>().firstWhere(
            (p) => p?.id == e.key,
            orElse: () => null,
          );
      final pendingImpact = changeOrders
          .where((c) =>
              c.projectId == e.key && c.status == ChangeOrderStatus.pending)
          .fold<double>(0, (s, c) => s + c.costImpact);
      return CpmsBudgetSummary(
        projectId: e.key,
        projectName: project?.name ?? e.key,
        lines: e.value,
        pendingChangeOrderImpact: pendingImpact,
      );
    }).toList();
  }
}

/// Default / offline CPMS dataset when DB is empty or unavailable.
abstract final class CpmsDemo {
  static CpmsCommandCenterSnapshot snapshot() {
    final now = DateTime.now();
    final projects = _projects(now);
    final milestones = _milestones(now);
    final tasks = _tasks(now);
    final contractors = _contractors();
    final procurement = _procurement(now);
    final changeOrders = _changeOrders();
    final budgetLines = _budgetLines();
    final qualityChecks = _qualityChecks(now);
    final defects = _defects();
    final safety = _safety(now);
    final diaries = _diaries(now);
    final inspections = _inspections(now);
    final risks = _risks();
    final activities = _activities(now);
    final alerts = _alerts(now);

    return CpmsCommandCenterSnapshot(
      kpis: aggregateKpis(
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
      aiInsights: const [
        CpmsAiInsight(
          id: 'cpms-ai-1',
          title: 'Keep Victoria Crest envelope on critical path',
          body:
              'Block A roof trusses at 55%. Sequence waterproofing inspection immediately after truss complete to protect monsoon window.',
          category: 'progress',
          projectId: 'proj-1',
          confidencePct: 78,
        ),
        CpmsAiInsight(
          id: 'cpms-ai-2',
          title: 'Ajah delay recovery needs CO approval',
          body:
              'Utility permit lock + pending CO-AJ-014 (+₦28.5M / +30d). Escalate finance approval to unlock drainage crews.',
          category: 'delay',
          projectId: 'proj-2',
          confidencePct: 52,
        ),
        CpmsAiInsight(
          id: 'cpms-ai-3',
          title: 'Ikoyi snag closeout for sales handover',
          body:
              'Punch-list 92% complete. Align client walkthrough with SBMS handover pack within 10 days.',
          category: 'quality',
          projectId: 'proj-3',
          confidencePct: 88,
        ),
      ],
      progressIntelligence: const [
        'Digital Construction Twin™ stub: 3 live sites · 1 delayed corridor.',
        'War Room: CO-AJ-014 pending · scaffold audit tomorrow.',
        'Smart Progress Intelligence™: weighted average site progress ~65%.',
        'Forecast stubs are estimates only — not guaranteed delivery dates.',
      ],
      fromRemote: false,
      loadedAt: now,
    );
  }

  static List<CpmsKpi> aggregateKpis({
    required List<CpmsProject> projects,
    required List<CpmsMilestone> milestones,
    required List<CpmsTask> tasks,
    required List<CpmsChangeOrder> changeOrders,
    required List<CpmsDefect> defects,
    required List<CpmsSafetyIncident> safetyIncidents,
  }) {
    final active = projects
        .where((p) =>
            p.status == ConstructionProjectStatus.active ||
            p.status == ConstructionProjectStatus.onHold)
        .length
        .toDouble();
    final avgProgress = projects.isEmpty
        ? 0.0
        : projects.fold<double>(0, (s, p) => s + p.progressPct) /
            projects.length;
    final delayed = projects.where((p) => p.isDelayed).length.toDouble();
    final openMilestones = milestones
        .where((m) =>
            m.status != MilestoneStatus.completed &&
            m.status != MilestoneStatus.cancelled)
        .length
        .toDouble();
    final blockedTasks =
        tasks.where((t) => t.status == TaskStatus.blocked).length.toDouble();
    final pendingCos = changeOrders
        .where((c) => c.status == ChangeOrderStatus.pending)
        .length
        .toDouble();
    final openDefects = defects
        .where((d) => d.status == 'open' || d.status == 'in_progress')
        .length
        .toDouble();
    final openSafety = safetyIncidents
        .where((s) => s.status != 'closed' && s.status != 'mitigated')
        .length
        .toDouble();
    final portfolioBudget =
        projects.fold<double>(0, (s, p) => s + p.budgetTotal);

    return [
      CpmsKpi(label: 'Active Projects', value: active),
      CpmsKpi(label: 'Avg Progress', value: avgProgress, unit: 'percent'),
      CpmsKpi(label: 'Delayed Sites', value: delayed),
      CpmsKpi(label: 'Open Milestones', value: openMilestones),
      CpmsKpi(label: 'Blocked Tasks', value: blockedTasks),
      CpmsKpi(label: 'Pending Change Orders', value: pendingCos),
      CpmsKpi(label: 'Open Defects', value: openDefects),
      CpmsKpi(label: 'Open Safety Items', value: openSafety),
      CpmsKpi(label: 'Portfolio Budget', value: portfolioBudget, unit: 'ngn'),
    ];
  }

  static List<CpmsProject> detectDelayedProjects(List<CpmsProject> projects) {
    return projects.where((p) => p.isDelayed).toList();
  }

  static List<CpmsProject> _projects(DateTime now) => [
        CpmsProject(
          id: 'proj-1',
          projectCode: 'CPMS-VC-PH1',
          name: 'Victoria Crest — Phase 1 Residential',
          description:
              'Active residential estate phase: substructure through finishes.',
          status: ConstructionProjectStatus.active,
          locationLabel: 'Lekki Phase 1, Lagos',
          managerLabel: 'Engr. Tunde Balogun',
          progressPct: 62.5,
          budgetTotal: 1850000000,
          budgetSpent: 980000000,
          riskLevel: RiskSeverity.medium,
          delayDays: 0,
          aiSummary:
              'On track for envelope close; MEP first-fix remaining in Block B.',
          forecastCompletionAt: now.add(const Duration(days: 95)),
          forecastConfidencePct: 78,
          targetEndDate: now.add(const Duration(days: 90)),
          startDate: now.subtract(const Duration(days: 120)),
          estateLabel: 'Victoria Crest Estate',
        ),
        CpmsProject(
          id: 'proj-2',
          projectCode: 'CPMS-AJ-RD',
          name: 'Ajah Road Extension — Infrastructure',
          description: 'Delayed infrastructure corridor awaiting utility clearances.',
          status: ConstructionProjectStatus.onHold,
          locationLabel: 'Ajah, Lagos',
          managerLabel: 'Engr. Ngozi Eze',
          progressPct: 41,
          budgetTotal: 620000000,
          budgetSpent: 410000000,
          riskLevel: RiskSeverity.high,
          delayDays: 45,
          aiSummary:
              'Critical path slipped 45 days awaiting utility clearances and change-order approval.',
          forecastCompletionAt: now.add(const Duration(days: 60)),
          forecastConfidencePct: 52,
          targetEndDate: now.subtract(const Duration(days: 30)),
          startDate: now.subtract(const Duration(days: 200)),
        ),
        CpmsProject(
          id: 'proj-3',
          projectCode: 'CPMS-IK-SNAG',
          name: 'Ikoyi Showhome — Snag & Handover',
          description: 'Near-completion showhome finishing and handover package.',
          status: ConstructionProjectStatus.active,
          locationLabel: 'Ikoyi, Lagos',
          managerLabel: 'Arch. Femi Adeyemi',
          progressPct: 92,
          budgetTotal: 145000000,
          budgetSpent: 138000000,
          riskLevel: RiskSeverity.low,
          delayDays: 0,
          aiSummary: 'Punch-list closing; schedule client inspection next week.',
          forecastCompletionAt: now.add(const Duration(days: 18)),
          forecastConfidencePct: 88,
          targetEndDate: now.add(const Duration(days: 21)),
          startDate: now.subtract(const Duration(days: 300)),
        ),
      ];

  static List<CpmsMilestone> _milestones(DateTime now) => [
        CpmsMilestone(
          id: 'ms-1',
          projectId: 'proj-1',
          name: 'Block A roof structure',
          status: MilestoneStatus.inProgress,
          dueDate: now.add(const Duration(days: 14)),
          progressPct: 68,
          isCritical: true,
          projectName: 'Victoria Crest — Phase 1 Residential',
        ),
        CpmsMilestone(
          id: 'ms-2',
          projectId: 'proj-1',
          name: 'MEP first-fix Block B',
          status: MilestoneStatus.planned,
          dueDate: now.add(const Duration(days: 45)),
          progressPct: 10,
          isCritical: true,
          projectName: 'Victoria Crest — Phase 1 Residential',
        ),
        CpmsMilestone(
          id: 'ms-3',
          projectId: 'proj-2',
          name: 'Utility relocation clearance',
          status: MilestoneStatus.delayed,
          dueDate: now.subtract(const Duration(days: 20)),
          progressPct: 35,
          isCritical: true,
          notes: 'Blocked on agency permits',
          projectName: 'Ajah Road Extension — Infrastructure',
        ),
        CpmsMilestone(
          id: 'ms-4',
          projectId: 'proj-3',
          name: 'Client snag walkthrough',
          status: MilestoneStatus.planned,
          dueDate: now.add(const Duration(days: 10)),
          projectName: 'Ikoyi Showhome — Snag & Handover',
        ),
      ];

  static List<CpmsTask> _tasks(DateTime now) => [
        CpmsTask(
          id: 'task-1',
          projectId: 'proj-1',
          title: 'Install roof trusses Block A',
          status: TaskStatus.inProgress,
          priority: 'high',
          assigneeLabel: 'Steelworks Team',
          dueDate: now.add(const Duration(days: 7)),
          progressPct: 55,
          projectName: 'Victoria Crest — Phase 1 Residential',
        ),
        CpmsTask(
          id: 'task-2',
          projectId: 'proj-1',
          title: 'Waterproofing inspection prep',
          status: TaskStatus.todo,
          priority: 'medium',
          assigneeLabel: 'QA Lead',
          dueDate: now.add(const Duration(days: 12)),
          projectName: 'Victoria Crest — Phase 1 Residential',
        ),
        CpmsTask(
          id: 'task-3',
          projectId: 'proj-2',
          title: 'Chase utility permit package',
          status: TaskStatus.blocked,
          priority: 'critical',
          assigneeLabel: 'PM Office',
          dueDate: now.subtract(const Duration(days: 5)),
          progressPct: 40,
          projectName: 'Ajah Road Extension — Infrastructure',
        ),
        CpmsTask(
          id: 'task-4',
          projectId: 'proj-3',
          title: 'Close bathroom snags',
          status: TaskStatus.inProgress,
          priority: 'high',
          assigneeLabel: 'Finishes Crew',
          dueDate: now.add(const Duration(days: 5)),
          progressPct: 70,
          projectName: 'Ikoyi Showhome — Snag & Handover',
        ),
      ];

  static List<CpmsContractor> _contractors() => const [
        CpmsContractor(
          id: 'ctr-1',
          projectId: 'proj-1',
          companyName: 'Apex Steelworks Ltd',
          contactName: 'Ibrahim Musa',
          specialty: 'structural_steel',
          contractValue: 240000000,
          performanceScore: 86,
          projectName: 'Victoria Crest — Phase 1 Residential',
        ),
        CpmsContractor(
          id: 'ctr-2',
          projectId: 'proj-1',
          companyName: 'BlueLine MEP Partners',
          contactName: 'Sarah Nwosu',
          specialty: 'mep',
          contractValue: 180000000,
          performanceScore: 81,
          projectName: 'Victoria Crest — Phase 1 Residential',
        ),
        CpmsContractor(
          id: 'ctr-3',
          projectId: 'proj-2',
          companyName: 'Delta Civil Works',
          contactName: 'Kunle Ade',
          specialty: 'civil',
          status: 'on_hold',
          contractValue: 95000000,
          performanceScore: 62,
          projectName: 'Ajah Road Extension — Infrastructure',
        ),
      ];

  static List<CpmsProcurementRequest> _procurement(DateTime now) => [
        CpmsProcurementRequest(
          id: 'pr-1',
          projectId: 'proj-1',
          requestCode: 'PR-VC-001',
          title: 'Additional waterproofing membrane',
          status: 'approved',
          estimatedCost: 4200000,
          neededBy: now.add(const Duration(days: 10)),
          requestedByLabel: 'QA Lead',
        ),
        CpmsProcurementRequest(
          id: 'pr-2',
          projectId: 'proj-2',
          requestCode: 'PR-AJ-002',
          title: 'Storm drain culvert sections',
          status: 'submitted',
          estimatedCost: 18500000,
          neededBy: now.add(const Duration(days: 21)),
          requestedByLabel: 'PM Office',
        ),
      ];

  static List<CpmsChangeOrder> _changeOrders() => const [
        CpmsChangeOrder(
          id: 'co-1',
          projectId: 'proj-2',
          changeCode: 'CO-AJ-014',
          title: 'Utility relocation scope increase',
          status: ChangeOrderStatus.pending,
          costImpact: 28500000,
          scheduleImpactDays: 30,
          requestedByLabel: 'Engr. Ngozi Eze',
          rationale:
              'Agency requires deeper trench and protective sleeves — awaiting finance/PM approval.',
          projectName: 'Ajah Road Extension — Infrastructure',
        ),
        CpmsChangeOrder(
          id: 'co-2',
          projectId: 'proj-1',
          changeCode: 'CO-VC-003',
          title: 'Extra balcony waterproofing detail',
          status: ChangeOrderStatus.approved,
          costImpact: 6500000,
          scheduleImpactDays: 5,
          requestedByLabel: 'Arch. Team',
          projectName: 'Victoria Crest — Phase 1 Residential',
        ),
      ];

  static List<CpmsBudgetLine> _budgetLines() => const [
        CpmsBudgetLine(
          id: 'bl-1',
          projectId: 'proj-1',
          category: 'Structural',
          description: 'Concrete, steel, formwork',
          budgetedAmount: 720000000,
          committedAmount: 510000000,
          spentAmount: 445000000,
        ),
        CpmsBudgetLine(
          id: 'bl-2',
          projectId: 'proj-1',
          category: 'MEP',
          budgetedAmount: 380000000,
          committedAmount: 210000000,
          spentAmount: 98000000,
        ),
        CpmsBudgetLine(
          id: 'bl-3',
          projectId: 'proj-2',
          category: 'Civil Works',
          budgetedAmount: 410000000,
          committedAmount: 350000000,
          spentAmount: 300000000,
        ),
        CpmsBudgetLine(
          id: 'bl-4',
          projectId: 'proj-3',
          category: 'Snag & Handover',
          budgetedAmount: 22000000,
          committedAmount: 18000000,
          spentAmount: 16000000,
        ),
      ];

  static List<CpmsQualityCheck> _qualityChecks(DateTime now) => [
        CpmsQualityCheck(
          id: 'qc-1',
          projectId: 'proj-1',
          title: 'Slab level survey Block A',
          status: 'passed',
          scorePct: 94,
          inspectorLabel: 'QA Lead',
          checkedAt: now.subtract(const Duration(days: 3)),
        ),
        CpmsQualityCheck(
          id: 'qc-2',
          projectId: 'proj-3',
          title: 'Paint adhesion sample',
          status: 'failed',
          scorePct: 62,
          inspectorLabel: 'Finishes QA',
          checkedAt: now.subtract(const Duration(days: 1)),
        ),
      ];

  static List<CpmsDefect> _defects() => const [
        CpmsDefect(
          id: 'def-1',
          projectId: 'proj-3',
          title: 'Hairline crack — guest bath tile joint',
          severity: RiskSeverity.medium,
          status: 'in_progress',
          locationLabel: 'Showhome en-suite',
          projectName: 'Ikoyi Showhome — Snag & Handover',
        ),
        CpmsDefect(
          id: 'def-2',
          projectId: 'proj-1',
          title: 'Missing firestop sleeve Level 2',
          severity: RiskSeverity.high,
          status: 'open',
          locationLabel: 'Block B riser',
          projectName: 'Victoria Crest — Phase 1 Residential',
        ),
      ];

  static List<CpmsSafetyIncident> _safety(DateTime now) => [
        CpmsSafetyIncident(
          id: 'si-1',
          projectId: 'proj-1',
          title: 'Near-miss: unsecured scaffold plank',
          severity: RiskSeverity.high,
          status: 'investigating',
          occurredAt: now.subtract(const Duration(days: 2)),
          locationLabel: 'Block A east elevation',
          reportedByLabel: 'HSE Officer',
          description:
              'Worker reported loose plank before shift. Access closed pending scaffolding audit.',
          projectName: 'Victoria Crest — Phase 1 Residential',
        ),
      ];

  static List<CpmsSiteDiary> _diaries(DateTime now) => [
        CpmsSiteDiary(
          id: 'sd-1',
          projectId: 'proj-1',
          summary:
              'Roof trusses installed on grids A1–A4. Concrete team prepping pour for tomorrow.',
          entryDate: now.subtract(const Duration(days: 1)),
          weather: 'Partly cloudy',
          workforceCount: 46,
          authorLabel: 'Site Agent',
          projectName: 'Victoria Crest — Phase 1 Residential',
        ),
        CpmsSiteDiary(
          id: 'sd-2',
          projectId: 'proj-1',
          summary:
              'Waterproofing prep delayed 2h by rain. Steel delivery accepted.',
          entryDate: now,
          weather: 'Light rain AM',
          workforceCount: 41,
          blockers: 'Rain delay morning window',
          authorLabel: 'Site Agent',
          projectName: 'Victoria Crest — Phase 1 Residential',
        ),
        CpmsSiteDiary(
          id: 'sd-3',
          projectId: 'proj-2',
          summary:
              'Skeleton crew on permit follow-ups only. Civil works on hold.',
          entryDate: now.subtract(const Duration(days: 1)),
          weather: 'Overcast',
          workforceCount: 8,
          blockers: 'Utility permits outstanding',
          authorLabel: 'PM Office',
          projectName: 'Ajah Road Extension — Infrastructure',
        ),
      ];

  static List<CpmsInspection> _inspections(DateTime now) => [
        CpmsInspection(
          id: 'insp-1',
          projectId: 'proj-1',
          title: 'Scaffolding safety audit',
          inspectionType: 'safety',
          status: 'scheduled',
          scheduledAt: now.add(const Duration(days: 1)),
          inspectorLabel: 'HSE Officer',
        ),
        CpmsInspection(
          id: 'insp-2',
          projectId: 'proj-3',
          title: 'Pre-handover client inspection',
          inspectionType: 'handover',
          status: 'scheduled',
          scheduledAt: now.add(const Duration(days: 10)),
          inspectorLabel: 'Sales + QA',
        ),
      ];

  static List<CpmsRisk> _risks() => const [
        CpmsRisk(
          id: 'risk-1',
          projectId: 'proj-1',
          title: 'Monsoon waterproofing failure',
          severity: RiskSeverity.high,
          likelihood: 'possible',
          status: 'mitigating',
          mitigation: 'Extra membrane detail + CO-VC-003',
          ownerLabel: 'QA Lead',
        ),
        CpmsRisk(
          id: 'risk-2',
          projectId: 'proj-2',
          title: 'Extended utility permit lock',
          severity: RiskSeverity.critical,
          likelihood: 'likely',
          status: 'open',
          mitigation: 'Escalate to agency liaison + approve CO-AJ-014',
          ownerLabel: 'PM Office',
        ),
      ];

  static List<CpmsActivity> _activities(DateTime now) => [
        CpmsActivity(
          id: 'act-1',
          projectId: 'proj-1',
          eventType: 'milestone',
          title: 'Roof structure advanced',
          description: 'Truss install reached 55% on Block A.',
          actorLabel: 'Site Agent',
          occurredAt: now.subtract(const Duration(hours: 6)),
        ),
        CpmsActivity(
          id: 'act-2',
          projectId: 'proj-1',
          eventType: 'safety',
          title: 'Scaffold near-miss logged',
          description: 'HSE closed access for audit.',
          actorLabel: 'HSE Officer',
          occurredAt: now.subtract(const Duration(days: 2)),
        ),
        CpmsActivity(
          id: 'act-3',
          projectId: 'proj-2',
          eventType: 'change_order',
          title: 'CO-AJ-014 pending approval',
          description: 'Cost impact ₦28.5M / +30 days.',
          actorLabel: 'Engr. Ngozi Eze',
          occurredAt: now.subtract(const Duration(days: 1)),
        ),
      ];

  static List<CpmsAlert> _alerts(DateTime now) => [
        CpmsAlert(
          id: 'al-1',
          projectId: 'proj-2',
          title: 'Change order awaiting approval',
          body: 'CO-AJ-014 needs finance/construction approval.',
          severity: 'warning',
          createdAt: now.subtract(const Duration(hours: 8)),
        ),
        CpmsAlert(
          id: 'al-2',
          projectId: 'proj-1',
          title: 'Safety audit scheduled',
          body: 'Scaffolding inspection tomorrow after near-miss.',
          severity: 'critical',
          createdAt: now.subtract(const Duration(hours: 4)),
        ),
        CpmsAlert(
          id: 'al-3',
          projectId: 'proj-3',
          title: 'Handover inspection in 10 days',
          body: 'Align sales handover pack with snag close-out.',
          severity: 'info',
          createdAt: now.subtract(const Duration(hours: 2)),
        ),
      ];
}
