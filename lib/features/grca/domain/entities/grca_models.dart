// Volume 4 Part 15 — GRCA domain models + demo command-center snapshot.

const String kGrcaAiDisclaimer = 'AI-generated — editable / advisory';

enum RiskSeverity {
  low,
  medium,
  high,
  critical;

  static RiskSeverity fromDb(String? raw) => switch (raw) {
        'low' => RiskSeverity.low,
        'high' => RiskSeverity.high,
        'critical' => RiskSeverity.critical,
        _ => RiskSeverity.medium,
      };
}

enum RiskStatus {
  draft,
  open,
  mitigating,
  accepted,
  closed,
  transferred;

  static RiskStatus fromDb(String? raw) => switch (raw) {
        'draft' => RiskStatus.draft,
        'mitigating' => RiskStatus.mitigating,
        'accepted' => RiskStatus.accepted,
        'closed' => RiskStatus.closed,
        'transferred' => RiskStatus.transferred,
        _ => RiskStatus.open,
      };
}

class GrcaKpi {
  const GrcaKpi({
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
}

class GrcaRisk {
  const GrcaRisk({
    required this.id,
    required this.title,
    this.code,
    this.riskType = 'operational',
    this.severity = 'medium',
    this.status = 'open',
    this.ownerLabel,
    this.categoryLabel,
    this.inherentScore = 0,
    this.residualScore = 0,
    this.summary,
  });

  final String id;
  final String title;
  final String? code;
  final String riskType;
  final String severity;
  final String status;
  final String? ownerLabel;
  final String? categoryLabel;
  final double inherentScore;
  final double residualScore;
  final String? summary;

  bool get isCriticalOpen => severity == 'critical' && status == 'open';

  factory GrcaRisk.fromJson(Map<String, dynamic> json) {
    return GrcaRisk(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      code: json['code'] as String?,
      riskType: json['risk_type'] as String? ?? 'operational',
      severity: json['severity'] as String? ?? 'medium',
      status: json['status'] as String? ?? 'open',
      ownerLabel: json['owner_label'] as String?,
      categoryLabel: json['category_label'] as String?,
      inherentScore: (json['inherent_score'] as num?)?.toDouble() ?? 0,
      residualScore: (json['residual_score'] as num?)?.toDouble() ?? 0,
      summary: json['summary'] as String?,
    );
  }
}

class GrcaComplianceFramework {
  const GrcaComplianceFramework({
    required this.id,
    required this.name,
    this.code,
    this.regulatorLabel,
    this.status = 'active',
    this.scorePct = 0,
    this.summary,
  });

  final String id;
  final String name;
  final String? code;
  final String? regulatorLabel;
  final String status;
  final double scorePct;
  final String? summary;

  factory GrcaComplianceFramework.fromJson(Map<String, dynamic> json) {
    return GrcaComplianceFramework(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      code: json['code'] as String?,
      regulatorLabel: json['regulator_label'] as String?,
      status: json['status'] as String? ?? 'active',
      scorePct: (json['score_pct'] as num?)?.toDouble() ?? 0,
      summary: json['summary'] as String?,
    );
  }
}

class GrcaPolicy {
  const GrcaPolicy({
    required this.id,
    required this.title,
    this.code,
    this.policyDomain = 'corporate',
    this.status = 'draft',
    this.ownerLabel,
    this.summary,
  });

  final String id;
  final String title;
  final String? code;
  final String policyDomain;
  final String status;
  final String? ownerLabel;
  final String? summary;

  factory GrcaPolicy.fromJson(Map<String, dynamic> json) {
    return GrcaPolicy(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      code: json['code'] as String?,
      policyDomain: json['policy_domain'] as String? ?? 'corporate',
      status: json['status'] as String? ?? 'draft',
      ownerLabel: json['owner_label'] as String?,
      summary: json['summary'] as String?,
    );
  }
}

class GrcaAuditFinding {
  const GrcaAuditFinding({
    required this.id,
    required this.title,
    this.code,
    this.severity = 'medium',
    this.status = 'open',
    this.findingType = 'control_gap',
    this.ownerLabel,
    this.dueAt,
    this.description,
  });

  final String id;
  final String title;
  final String? code;
  final String severity;
  final String status;
  final String findingType;
  final String? ownerLabel;
  final DateTime? dueAt;
  final String? description;

  bool get isOpen => {'open', 'remediating'}.contains(status);

  factory GrcaAuditFinding.fromJson(Map<String, dynamic> json) {
    return GrcaAuditFinding(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      code: json['code'] as String?,
      severity: json['severity'] as String? ?? 'medium',
      status: json['status'] as String? ?? 'open',
      findingType: json['finding_type'] as String? ?? 'control_gap',
      ownerLabel: json['owner_label'] as String?,
      dueAt: DateTime.tryParse(json['due_at'] as String? ?? ''),
      description: json['description'] as String?,
    );
  }
}

class GrcaAuditPlan {
  const GrcaAuditPlan({
    required this.id,
    required this.title,
    this.code,
    this.status = 'planned',
    this.fiscalYear,
    this.leadAuditorLabel,
    this.scopeSummary,
  });

  final String id;
  final String title;
  final String? code;
  final String status;
  final String? fiscalYear;
  final String? leadAuditorLabel;
  final String? scopeSummary;

  factory GrcaAuditPlan.fromJson(Map<String, dynamic> json) {
    return GrcaAuditPlan(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      code: json['code'] as String?,
      status: json['status'] as String? ?? 'planned',
      fiscalYear: json['fiscal_year'] as String?,
      leadAuditorLabel: json['lead_auditor_label'] as String?,
      scopeSummary: json['scope_summary'] as String?,
    );
  }
}

class GrcaLegalCase {
  const GrcaLegalCase({
    required this.id,
    required this.title,
    this.code,
    this.caseType = 'civil',
    this.status = 'open',
    this.riskLevel = 'medium',
    this.counselLabel,
    this.opposingParty,
    this.summary,
  });

  final String id;
  final String title;
  final String? code;
  final String caseType;
  final String status;
  final String riskLevel;
  final String? counselLabel;
  final String? opposingParty;
  final String? summary;

  factory GrcaLegalCase.fromJson(Map<String, dynamic> json) {
    return GrcaLegalCase(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      code: json['code'] as String?,
      caseType: json['case_type'] as String? ?? 'civil',
      status: json['status'] as String? ?? 'open',
      riskLevel: json['risk_level'] as String? ?? 'medium',
      counselLabel: json['counsel_label'] as String?,
      opposingParty: json['opposing_party'] as String?,
      summary: json['summary'] as String?,
    );
  }
}

class GrcaEthicsReport {
  const GrcaEthicsReport({
    required this.id,
    this.code,
    this.reportCategory = 'other',
    this.status = 'intake',
    this.severity = 'medium',
    this.channelLabel,
    this.summaryRedacted,
    this.receivedAt,
  });

  final String id;
  final String? code;
  final String reportCategory;
  final String status;
  final String severity;
  final String? channelLabel;
  final String? summaryRedacted;
  final DateTime? receivedAt;

  factory GrcaEthicsReport.fromJson(Map<String, dynamic> json) {
    return GrcaEthicsReport(
      id: json['id'] as String? ?? '',
      code: json['code'] as String?,
      reportCategory: json['report_category'] as String? ?? 'other',
      status: json['status'] as String? ?? 'intake',
      severity: json['severity'] as String? ?? 'medium',
      channelLabel: json['channel_label'] as String?,
      summaryRedacted: json['summary_redacted'] as String?,
      receivedAt: DateTime.tryParse(json['received_at'] as String? ?? ''),
    );
  }
}

class GrcaBoardMeeting {
  const GrcaBoardMeeting({
    required this.id,
    required this.title,
    this.code,
    this.meetingType = 'board',
    this.status = 'scheduled',
    this.scheduledAt,
    this.locationLabel,
    this.chairLabel,
    this.agendaSummary,
  });

  final String id;
  final String title;
  final String? code;
  final String meetingType;
  final String status;
  final DateTime? scheduledAt;
  final String? locationLabel;
  final String? chairLabel;
  final String? agendaSummary;

  factory GrcaBoardMeeting.fromJson(Map<String, dynamic> json) {
    return GrcaBoardMeeting(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      code: json['code'] as String?,
      meetingType: json['meeting_type'] as String? ?? 'board',
      status: json['status'] as String? ?? 'scheduled',
      scheduledAt: DateTime.tryParse(json['scheduled_at'] as String? ?? ''),
      locationLabel: json['location_label'] as String?,
      chairLabel: json['chair_label'] as String?,
      agendaSummary: json['agenda_summary'] as String?,
    );
  }
}

class GrcaBcmPlan {
  const GrcaBcmPlan({
    required this.id,
    required this.title,
    this.code,
    this.planType = 'bcm',
    this.status = 'draft',
    this.ownerLabel,
    this.rtoHours,
    this.rpoHours,
    this.summary,
  });

  final String id;
  final String title;
  final String? code;
  final String planType;
  final String status;
  final String? ownerLabel;
  final double? rtoHours;
  final double? rpoHours;
  final String? summary;

  factory GrcaBcmPlan.fromJson(Map<String, dynamic> json) {
    return GrcaBcmPlan(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      code: json['code'] as String?,
      planType: json['plan_type'] as String? ?? 'bcm',
      status: json['status'] as String? ?? 'draft',
      ownerLabel: json['owner_label'] as String?,
      rtoHours: (json['rto_hours'] as num?)?.toDouble(),
      rpoHours: (json['rpo_hours'] as num?)?.toDouble(),
      summary: json['summary'] as String?,
    );
  }
}

class GrcaCalendarEvent {
  const GrcaCalendarEvent({
    required this.id,
    required this.title,
    this.regulatorLabel,
    this.eventType = 'deadline',
    this.status = 'upcoming',
    this.dueAt,
    this.ownerLabel,
    this.notes,
  });

  final String id;
  final String title;
  final String? regulatorLabel;
  final String eventType;
  final String status;
  final DateTime? dueAt;
  final String? ownerLabel;
  final String? notes;

  bool get isDueSoon {
    final d = dueAt;
    if (d == null) return false;
    final days = d.difference(DateTime.now()).inDays;
    return days <= 30 && status != 'completed' && status != 'cancelled';
  }

  factory GrcaCalendarEvent.fromJson(Map<String, dynamic> json) {
    return GrcaCalendarEvent(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      regulatorLabel: json['regulator_label'] as String?,
      eventType: json['event_type'] as String? ?? 'deadline',
      status: json['status'] as String? ?? 'upcoming',
      dueAt: DateTime.tryParse(json['due_at'] as String? ?? ''),
      ownerLabel: json['owner_label'] as String?,
      notes: json['notes'] as String?,
    );
  }
}

class GrcaAiInsight {
  const GrcaAiInsight({
    required this.id,
    required this.title,
    required this.body,
    this.insightType = 'risk',
    this.confidencePct,
    this.editable = true,
    this.disclaimer = kGrcaAiDisclaimer,
  });

  final String id;
  final String title;
  final String body;
  final String insightType;
  final double? confidencePct;
  final bool editable;
  final String disclaimer;

  factory GrcaAiInsight.fromJson(Map<String, dynamic> json) {
    return GrcaAiInsight(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      insightType: json['insight_type'] as String? ?? 'risk',
      confidencePct: (json['confidence_pct'] as num?)?.toDouble(),
      editable: json['editable'] as bool? ?? true,
      disclaimer: json['disclaimer'] as String? ?? kGrcaAiDisclaimer,
    );
  }
}

class GrcaActivity {
  const GrcaActivity({
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

  factory GrcaActivity.fromJson(Map<String, dynamic> json) {
    return GrcaActivity(
      id: json['id'] as String? ?? '',
      action: json['action'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      actorLabel: json['actor_label'] as String?,
      occurredAt: DateTime.tryParse(json['occurred_at'] as String? ?? ''),
    );
  }
}

class GrcaReport {
  const GrcaReport({
    required this.id,
    required this.title,
    this.reportType = 'risk',
    this.periodLabel,
    this.summary,
  });

  final String id;
  final String title;
  final String reportType;
  final String? periodLabel;
  final String? summary;

  factory GrcaReport.fromJson(Map<String, dynamic> json) {
    return GrcaReport(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      reportType: json['report_type'] as String? ?? 'risk',
      periodLabel: json['period_label'] as String?,
      summary: json['summary'] as String?,
    );
  }
}

class GrcaCommandCenterSnapshot {
  const GrcaCommandCenterSnapshot({
    required this.kpis,
    required this.risks,
    required this.complianceFrameworks,
    required this.policies,
    required this.auditPlans,
    required this.auditFindings,
    required this.legalCases,
    required this.ethicsReports,
    required this.boardMeetings,
    required this.bcmPlans,
    required this.calendarEvents,
    required this.aiInsights,
    required this.activities,
    required this.reports,
    this.fromRemote = false,
    this.loadedAt,
    this.aiDisclaimer = kGrcaAiDisclaimer,
  });

  final List<GrcaKpi> kpis;
  final List<GrcaRisk> risks;
  final List<GrcaComplianceFramework> complianceFrameworks;
  final List<GrcaPolicy> policies;
  final List<GrcaAuditPlan> auditPlans;
  final List<GrcaAuditFinding> auditFindings;
  final List<GrcaLegalCase> legalCases;
  final List<GrcaEthicsReport> ethicsReports;
  final List<GrcaBoardMeeting> boardMeetings;
  final List<GrcaBcmPlan> bcmPlans;
  final List<GrcaCalendarEvent> calendarEvents;
  final List<GrcaAiInsight> aiInsights;
  final List<GrcaActivity> activities;
  final List<GrcaReport> reports;
  final bool fromRemote;
  final DateTime? loadedAt;
  final String aiDisclaimer;
}

abstract final class GrcaDemo {
  static GrcaCommandCenterSnapshot snapshot() {
    final now = DateTime.now();
    return GrcaCommandCenterSnapshot(
      kpis: _kpis(),
      risks: _risks(),
      complianceFrameworks: _compliance(),
      policies: _policies(),
      auditPlans: _auditPlans(),
      auditFindings: _auditFindings(now),
      legalCases: _legalCases(),
      ethicsReports: _ethicsReports(now),
      boardMeetings: _boardMeetings(now),
      bcmPlans: _bcmPlans(),
      calendarEvents: _calendar(now),
      aiInsights: _aiInsights(),
      activities: _activities(now),
      reports: _reports(),
      fromRemote: false,
      loadedAt: now,
    );
  }

  static List<GrcaKpi> _kpis() => const [
        GrcaKpi(label: 'Open Risks', value: 2, status: 'watch'),
        GrcaKpi(label: 'Critical Open', value: 1, status: 'watch'),
        GrcaKpi(label: 'Compliance Score', value: 84.8, unit: 'pct'),
        GrcaKpi(label: 'Open Findings', value: 2, status: 'watch'),
        GrcaKpi(label: 'Legal Cases', value: 1),
        GrcaKpi(label: 'Policies Active', value: 2),
        GrcaKpi(label: 'Deadlines 30d', value: 3, status: 'watch'),
      ];

  static List<GrcaRisk> _risks() => const [
        GrcaRisk(
          id: 'd1500003-0000-4000-8000-000000000001',
          code: 'RSK-2026-1501',
          title: 'Construction permit delay — Oceanview Phase 2',
          riskType: 'operational',
          severity: 'critical',
          status: 'open',
          ownerLabel: 'Construction Manager',
          categoryLabel: 'Operational',
          inherentScore: 20,
          residualScore: 16,
          summary:
              'Critical/open: permit lag may slip handover and investor milestones.',
        ),
        GrcaRisk(
          id: 'd1500003-0000-4000-8000-000000000002',
          code: 'RSK-2026-1502',
          title: 'FX volatility on imported fixtures',
          riskType: 'financial',
          severity: 'high',
          status: 'mitigating',
          ownerLabel: 'CFO',
          categoryLabel: 'Financial',
          inherentScore: 12,
          residualScore: 8,
          summary: 'NGN/USD swing pressure on specified finishing packages.',
        ),
        GrcaRisk(
          id: 'd1500003-0000-4000-8000-000000000003',
          code: 'RSK-2026-1503',
          title: 'Data protection compliance gap — CRM exports',
          riskType: 'compliance',
          severity: 'high',
          status: 'open',
          ownerLabel: 'Compliance Lead',
          categoryLabel: 'Compliance',
          inherentScore: 12,
          residualScore: 10,
          summary: 'Open compliance risk on client data export controls.',
        ),
      ];

  static List<GrcaComplianceFramework> _compliance() => const [
        GrcaComplianceFramework(
          id: 'd1500006-0000-4000-8000-000000000001',
          code: 'CF-NDPR-01',
          name: 'Nigeria Data Protection Regulation (NDPR)',
          regulatorLabel: 'NDPC',
          status: 'active',
          scorePct: 78.5,
          summary: 'Compliance score stub — privacy controls and DPO oversight.',
        ),
        GrcaComplianceFramework(
          id: 'd1500006-0000-4000-8000-000000000002',
          code: 'CF-CAMA-01',
          name: 'Companies and Allied Matters Act (CAMA)',
          regulatorLabel: 'CAC',
          status: 'active',
          scorePct: 91.0,
          summary: 'Corporate filings and statutory register compliance stub.',
        ),
      ];

  static List<GrcaPolicy> _policies() => const [
        GrcaPolicy(
          id: 'd150000a-0000-4000-8000-000000000001',
          code: 'POL-ETH-01',
          title: 'Code of Conduct & Ethics',
          policyDomain: 'ethics',
          status: 'active',
          ownerLabel: 'Chief People Officer',
          summary: 'Mandatory annual acknowledgement for all staff.',
        ),
        GrcaPolicy(
          id: 'd150000a-0000-4000-8000-000000000002',
          code: 'POL-IT-01',
          title: 'Information Security Acceptable Use',
          policyDomain: 'it',
          status: 'active',
          ownerLabel: 'CTO',
          summary: 'Device and data handling standards.',
        ),
        GrcaPolicy(
          id: 'd150000a-0000-4000-8000-000000000003',
          code: 'POL-FIN-01',
          title: 'Anti-Bribery & Gifts Policy',
          policyDomain: 'finance',
          status: 'under_review',
          ownerLabel: 'CFO',
          summary: 'Gift thresholds and third-party diligence.',
        ),
      ];

  static List<GrcaAuditPlan> _auditPlans() => const [
        GrcaAuditPlan(
          id: 'd150000d-0000-4000-8000-000000000001',
          code: 'AP-2026-Q3',
          title: 'Q3 Internal Audit Plan — Ops & Procurement',
          status: 'in_progress',
          fiscalYear: 'FY2026',
          leadAuditorLabel: 'Internal Audit Lead',
          scopeSummary:
              'Procurement controls, site cash handling, NDPR export controls',
        ),
      ];

  static List<GrcaAuditFinding> _auditFindings(DateTime now) => [
        GrcaAuditFinding(
          id: 'd1500010-0000-4000-8000-000000000001',
          code: 'AF-2026-1501',
          title: 'Vendor KYC incomplete on 3 active vendors',
          severity: 'high',
          status: 'open',
          findingType: 'control_gap',
          ownerLabel: 'Procurement Lead',
          dueAt: now.add(const Duration(days: 30)),
          description:
              'Three vendors missing tax ID / beneficial ownership attestation.',
        ),
        GrcaAuditFinding(
          id: 'd1500010-0000-4000-8000-000000000002',
          code: 'AF-2026-1502',
          title: 'PO approval threshold bypassed twice',
          severity: 'medium',
          status: 'remediating',
          findingType: 'policy_breach',
          ownerLabel: 'Finance Controller',
          dueAt: now.add(const Duration(days: 14)),
          description:
              'Two POs above threshold without dual approval evidence.',
        ),
      ];

  static List<GrcaLegalCase> _legalCases() => const [
        GrcaLegalCase(
          id: 'd1500012-0000-4000-8000-000000000001',
          code: 'LC-2026-1501',
          title: 'Contractor variations dispute — Oceanview Phase 2',
          caseType: 'contract',
          status: 'open',
          riskLevel: 'high',
          counselLabel: 'External Counsel — Banjo & Co.',
          opposingParty: 'SiteWorks Engineering Ltd',
          summary:
              'Dispute over variation claims and retention release timing.',
        ),
      ];

  static List<GrcaEthicsReport> _ethicsReports(DateTime now) => [
        GrcaEthicsReport(
          id: 'd1500017-0000-4000-8000-000000000001',
          code: 'ETH-2026-1501',
          reportCategory: 'conflict',
          status: 'triage',
          severity: 'medium',
          channelLabel: 'anonymous_hotline',
          summaryRedacted:
              'Anonymous tip: alleged undeclared conflict on vendor selection (metadata only).',
          receivedAt: now.subtract(const Duration(days: 2)),
        ),
      ];

  static List<GrcaBoardMeeting> _boardMeetings(DateTime now) => [
        GrcaBoardMeeting(
          id: 'd150001c-0000-4000-8000-000000000001',
          code: 'BM-2026-Q3',
          title: 'Board of Directors — Q3 2026',
          meetingType: 'board',
          status: 'scheduled',
          scheduledAt: now.add(const Duration(days: 28)),
          locationLabel: 'Victoria Island Boardroom',
          chairLabel: 'Board Chair',
          agendaSummary: 'Risk appetite, Oceanview dispute, BCM refresh',
        ),
      ];

  static List<GrcaBcmPlan> _bcmPlans() => const [
        GrcaBcmPlan(
          id: 'd150001a-0000-4000-8000-000000000001',
          code: 'BCP-HQ-01',
          title: 'HQ Business Continuity Plan',
          planType: 'bcm',
          status: 'active',
          ownerLabel: 'COO',
          rtoHours: 24,
          rpoHours: 4,
          summary: 'Primary BCM for Lagos HQ and critical SaaS failover.',
        ),
      ];

  static List<GrcaCalendarEvent> _calendar(DateTime now) => [
        GrcaCalendarEvent(
          id: 'd1500009-0000-4000-8000-000000000001',
          title: 'NDPR annual compliance filing',
          regulatorLabel: 'NDPC',
          eventType: 'filing',
          status: 'upcoming',
          dueAt: now.add(const Duration(days: 21)),
          ownerLabel: 'Compliance Lead',
          notes: 'Regulatory deadline within 3 weeks',
        ),
        GrcaCalendarEvent(
          id: 'd1500009-0000-4000-8000-000000000002',
          title: 'CAC annual returns deadline',
          regulatorLabel: 'CAC',
          eventType: 'deadline',
          status: 'upcoming',
          dueAt: now.add(const Duration(days: 60)),
          ownerLabel: 'Company Secretary',
        ),
        GrcaCalendarEvent(
          id: 'd1500009-0000-4000-8000-000000000003',
          title: 'LASBCA inspection — Oceanview Phase 2',
          regulatorLabel: 'LASBCA',
          eventType: 'inspection',
          status: 'due',
          dueAt: now.add(const Duration(days: 10)),
          ownerLabel: 'Construction Manager',
        ),
      ];

  static List<GrcaAiInsight> _aiInsights() => const [
        GrcaAiInsight(
          id: 'd1500022-0000-4000-8000-000000000001',
          title: 'Critical risk cluster — construction regulatory path',
          body:
              'RSK-2026-1501 + LASBCA inspection window suggest elevating MD risk brief this week.',
          insightType: 'risk',
          confidencePct: 88,
        ),
        GrcaAiInsight(
          id: 'd1500022-0000-4000-8000-000000000002',
          title: 'Compliance score watch — NDPR vs CRM exports',
          body:
              'NDPR score stub 78.5% with open CRM export incident; prioritize REQ-NDPR-01 evidence.',
          insightType: 'compliance',
          confidencePct: 82,
        ),
        GrcaAiInsight(
          id: 'd1500022-0000-4000-8000-000000000003',
          title: 'Audit remediation overdue risk',
          body:
              'AF-2026-1501/1502 open concurrent with LC-2026-1501 — align legal & audit closures.',
          insightType: 'audit',
          confidencePct: 79,
        ),
      ];

  static List<GrcaActivity> _activities(DateTime now) => [
        GrcaActivity(
          id: 'd1500020-0000-4000-8000-000000000001',
          action: 'risk_opened',
          summary: 'RSK-2026-1501 opened as critical/open',
          actorLabel: 'Chief Risk Officer',
          occurredAt: now.subtract(const Duration(days: 14)),
        ),
        GrcaActivity(
          id: 'd1500020-0000-4000-8000-000000000002',
          action: 'finding_logged',
          summary: 'AF-2026-1501 vendor KYC finding logged',
          actorLabel: 'Internal Audit Lead',
          occurredAt: now.subtract(const Duration(days: 3)),
        ),
        GrcaActivity(
          id: 'd1500020-0000-4000-8000-000000000003',
          action: 'policy_published',
          summary: 'POL-ETH-01 v2026.1 published',
          actorLabel: 'Company Secretary',
          occurredAt: now.subtract(const Duration(days: 30)),
        ),
        GrcaActivity(
          id: 'd1500020-0000-4000-8000-000000000004',
          action: 'ethics_intake',
          summary: 'ETH-2026-1501 metadata-only intake recorded',
          actorLabel: 'Ethics Officer',
          occurredAt: now.subtract(const Duration(days: 2)),
        ),
      ];

  static List<GrcaReport> _reports() => const [
        GrcaReport(
          id: 'd150001f-0000-4000-8000-000000000001',
          title: 'Enterprise Risk & Compliance Snapshot',
          reportType: 'executive',
          periodLabel: 'Jul 2026',
          summary:
              '3 register risks (1 critical open); NDPR score 78.5%; 2 open audit findings.',
        ),
        GrcaReport(
          id: 'd150001f-0000-4000-8000-000000000002',
          title: 'Internal Audit Q3 Progress',
          reportType: 'audit',
          periodLabel: 'Q3 2026',
          summary: 'AP-2026-Q3 in progress — vendor KYC findings open.',
        ),
      ];
}
