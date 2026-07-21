// Volume 4 Part 16 — BIADW domain models + demo command-center snapshot.

const String kBiadwAiDisclaimer = 'AI-generated — editable / advisory';

class BiadwKpi {
  const BiadwKpi({
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

  factory BiadwKpi.fromJson(Map<String, dynamic> json) {
    return BiadwKpi(
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

class BiadwDataSource {
  const BiadwDataSource({
    required this.id,
    required this.name,
    this.code,
    this.sourceModule = 'core',
    this.status = 'active',
    this.ownerLabel,
    this.summary,
  });

  final String id;
  final String name;
  final String? code;
  final String sourceModule;
  final String status;
  final String? ownerLabel;
  final String? summary;

  factory BiadwDataSource.fromJson(Map<String, dynamic> json) {
    return BiadwDataSource(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      code: json['code'] as String?,
      sourceModule: json['source_module'] as String? ?? 'core',
      status: json['status'] as String? ?? 'active',
      ownerLabel: json['owner_label'] as String?,
      summary: json['summary'] as String?,
    );
  }
}

class BiadwDataset {
  const BiadwDataset({
    required this.id,
    required this.name,
    this.code,
    this.datasetType = 'mart',
    this.status = 'active',
    this.grainLabel,
    this.ownerLabel,
    this.rowEstimate = 0,
    this.summary,
  });

  final String id;
  final String name;
  final String? code;
  final String datasetType;
  final String status;
  final String? grainLabel;
  final String? ownerLabel;
  final int rowEstimate;
  final String? summary;

  factory BiadwDataset.fromJson(Map<String, dynamic> json) {
    return BiadwDataset(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      code: json['code'] as String?,
      datasetType: json['dataset_type'] as String? ?? 'mart',
      status: json['status'] as String? ?? 'active',
      grainLabel: json['grain_label'] as String?,
      ownerLabel: json['owner_label'] as String?,
      rowEstimate: (json['row_estimate'] as num?)?.toInt() ?? 0,
      summary: json['summary'] as String?,
    );
  }
}

class BiadwEtlJob {
  const BiadwEtlJob({
    required this.id,
    required this.name,
    this.code,
    this.status = 'idle',
    this.lastRunAt,
    this.lastDurationMs,
    this.ownerLabel,
    this.summary,
  });

  final String id;
  final String name;
  final String? code;
  final String status;
  final DateTime? lastRunAt;
  final int? lastDurationMs;
  final String? ownerLabel;
  final String? summary;

  bool get isFailed => status == 'failed';
  bool get isSuccess => status == 'success';

  factory BiadwEtlJob.fromJson(Map<String, dynamic> json) {
    return BiadwEtlJob(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      code: json['code'] as String?,
      status: json['status'] as String? ?? 'idle',
      lastRunAt: DateTime.tryParse(json['last_run_at'] as String? ?? ''),
      lastDurationMs: (json['last_duration_ms'] as num?)?.toInt(),
      ownerLabel: json['owner_label'] as String?,
      summary: json['summary'] as String?,
    );
  }
}

class BiadwDashboard {
  const BiadwDashboard({
    required this.id,
    required this.title,
    this.code,
    this.audience = 'executive',
    this.status = 'published',
    this.ownerLabel,
    this.summary,
  });

  final String id;
  final String title;
  final String? code;
  final String audience;
  final String status;
  final String? ownerLabel;
  final String? summary;

  factory BiadwDashboard.fromJson(Map<String, dynamic> json) {
    return BiadwDashboard(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      code: json['code'] as String?,
      audience: json['audience'] as String? ?? 'executive',
      status: json['status'] as String? ?? 'published',
      ownerLabel: json['owner_label'] as String?,
      summary: json['summary'] as String?,
    );
  }
}

class BiadwReport {
  const BiadwReport({
    required this.id,
    required this.title,
    this.code,
    this.reportType = 'executive',
    this.periodLabel,
    this.status = 'ready',
    this.summary,
    this.ownerLabel,
  });

  final String id;
  final String title;
  final String? code;
  final String reportType;
  final String? periodLabel;
  final String status;
  final String? summary;
  final String? ownerLabel;

  factory BiadwReport.fromJson(Map<String, dynamic> json) {
    return BiadwReport(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      code: json['code'] as String?,
      reportType: json['report_type'] as String? ?? 'executive',
      periodLabel: json['period_label'] as String?,
      status: json['status'] as String? ?? 'ready',
      summary: json['summary'] as String?,
      ownerLabel: json['owner_label'] as String?,
    );
  }
}

class BiadwForecast {
  const BiadwForecast({
    required this.id,
    required this.title,
    this.code,
    this.metricLabel,
    this.horizonLabel,
    this.forecastValue = 0,
    this.confidencePct = 0,
    this.unit = 'currency',
    this.status = 'active',
    this.summary,
  });

  final String id;
  final String title;
  final String? code;
  final String? metricLabel;
  final String? horizonLabel;
  final double forecastValue;
  final double confidencePct;
  final String unit;
  final String status;
  final String? summary;

  String get displayValue {
    if (unit == 'pct') {
      return '${forecastValue.toStringAsFixed(1)}%';
    }
    if (unit == 'currency') {
      if (forecastValue >= 1000000) {
        return '₦${(forecastValue / 1000000).toStringAsFixed(1)}M';
      }
      return '₦${forecastValue.toStringAsFixed(0)}';
    }
    return forecastValue.toStringAsFixed(1);
  }

  factory BiadwForecast.fromJson(Map<String, dynamic> json) {
    return BiadwForecast(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      code: json['code'] as String?,
      metricLabel: json['metric_label'] as String?,
      horizonLabel: json['horizon_label'] as String?,
      forecastValue: (json['forecast_value'] as num?)?.toDouble() ?? 0,
      confidencePct: (json['confidence_pct'] as num?)?.toDouble() ?? 0,
      unit: json['unit'] as String? ?? 'currency',
      status: json['status'] as String? ?? 'active',
      summary: json['summary'] as String?,
    );
  }
}

class BiadwScorecard {
  const BiadwScorecard({
    required this.id,
    required this.title,
    this.code,
    this.audience = 'ceo',
    this.periodLabel,
    this.overallScore = 0,
    this.status = 'draft',
    this.ownerLabel,
    this.summary,
  });

  final String id;
  final String title;
  final String? code;
  final String audience;
  final String? periodLabel;
  final double overallScore;
  final String status;
  final String? ownerLabel;
  final String? summary;

  factory BiadwScorecard.fromJson(Map<String, dynamic> json) {
    return BiadwScorecard(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      code: json['code'] as String?,
      audience: json['audience'] as String? ?? 'ceo',
      periodLabel: json['period_label'] as String?,
      overallScore: (json['overall_score'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'draft',
      ownerLabel: json['owner_label'] as String?,
      summary: json['summary'] as String?,
    );
  }
}

class BiadwQualityIssue {
  const BiadwQualityIssue({
    required this.id,
    required this.title,
    this.code,
    this.severity = 'medium',
    this.status = 'open',
    this.datasetLabel,
    this.ownerLabel,
    this.summary,
  });

  final String id;
  final String title;
  final String? code;
  final String severity;
  final String status;
  final String? datasetLabel;
  final String? ownerLabel;
  final String? summary;

  bool get isOpen => {'open', 'investigating'}.contains(status);

  factory BiadwQualityIssue.fromJson(Map<String, dynamic> json) {
    return BiadwQualityIssue(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      code: json['code'] as String?,
      severity: json['severity'] as String? ?? 'medium',
      status: json['status'] as String? ?? 'open',
      datasetLabel: json['dataset_label'] as String?,
      ownerLabel: json['owner_label'] as String?,
      summary: json['summary'] as String?,
    );
  }
}

class BiadwLineageEdge {
  const BiadwLineageEdge({
    required this.id,
    required this.sourceLabel,
    required this.targetLabel,
    this.code,
    this.lineageType = 'etl',
    this.summary,
  });

  final String id;
  final String sourceLabel;
  final String targetLabel;
  final String? code;
  final String lineageType;
  final String? summary;

  factory BiadwLineageEdge.fromJson(Map<String, dynamic> json) {
    return BiadwLineageEdge(
      id: json['id'] as String? ?? '',
      sourceLabel: json['source_label'] as String? ?? '',
      targetLabel: json['target_label'] as String? ?? '',
      code: json['code'] as String?,
      lineageType: json['lineage_type'] as String? ?? 'etl',
      summary: json['summary'] as String?,
    );
  }
}

class BiadwCatalogEntry {
  const BiadwCatalogEntry({
    required this.id,
    required this.title,
    this.code,
    this.catalogType = 'dataset',
    this.ownerLabel,
    this.summary,
    this.status = 'published',
  });

  final String id;
  final String title;
  final String? code;
  final String catalogType;
  final String? ownerLabel;
  final String? summary;
  final String status;

  factory BiadwCatalogEntry.fromJson(Map<String, dynamic> json) {
    return BiadwCatalogEntry(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      code: json['code'] as String?,
      catalogType: json['catalog_type'] as String? ?? 'dataset',
      ownerLabel: json['owner_label'] as String?,
      summary: json['summary'] as String?,
      status: json['status'] as String? ?? 'published',
    );
  }
}

class BiadwAiInsight {
  const BiadwAiInsight({
    required this.id,
    required this.title,
    required this.body,
    this.insightType = 'briefing',
    this.confidencePct,
    this.editable = true,
    this.disclaimer = kBiadwAiDisclaimer,
  });

  final String id;
  final String title;
  final String body;
  final String insightType;
  final double? confidencePct;
  final bool editable;
  final String disclaimer;

  factory BiadwAiInsight.fromJson(Map<String, dynamic> json) {
    return BiadwAiInsight(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      insightType: json['insight_type'] as String? ?? 'briefing',
      confidencePct: (json['confidence_pct'] as num?)?.toDouble(),
      editable: json['editable'] as bool? ?? true,
      disclaimer: json['disclaimer'] as String? ?? kBiadwAiDisclaimer,
    );
  }
}

class BiadwActivity {
  const BiadwActivity({
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

  factory BiadwActivity.fromJson(Map<String, dynamic> json) {
    return BiadwActivity(
      id: json['id'] as String? ?? '',
      action: json['action'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      actorLabel: json['actor_label'] as String?,
      occurredAt: DateTime.tryParse(json['occurred_at'] as String? ?? ''),
    );
  }
}

class BiadwCommandCenterSnapshot {
  const BiadwCommandCenterSnapshot({
    required this.kpis,
    required this.dataSources,
    required this.datasets,
    required this.etlJobs,
    required this.dashboards,
    required this.reports,
    required this.forecasts,
    required this.scorecards,
    required this.qualityIssues,
    required this.lineage,
    required this.catalog,
    required this.aiInsights,
    required this.activities,
    this.fromRemote = false,
    this.loadedAt,
    this.aiDisclaimer = kBiadwAiDisclaimer,
  });

  final List<BiadwKpi> kpis;
  final List<BiadwDataSource> dataSources;
  final List<BiadwDataset> datasets;
  final List<BiadwEtlJob> etlJobs;
  final List<BiadwDashboard> dashboards;
  final List<BiadwReport> reports;
  final List<BiadwForecast> forecasts;
  final List<BiadwScorecard> scorecards;
  final List<BiadwQualityIssue> qualityIssues;
  final List<BiadwLineageEdge> lineage;
  final List<BiadwCatalogEntry> catalog;
  final List<BiadwAiInsight> aiInsights;
  final List<BiadwActivity> activities;
  final bool fromRemote;
  final DateTime? loadedAt;
  final String aiDisclaimer;
}

abstract final class BiadwDemo {
  static BiadwCommandCenterSnapshot snapshot() {
    final now = DateTime.now();
    return BiadwCommandCenterSnapshot(
      kpis: _kpis(),
      dataSources: _sources(),
      datasets: _datasets(),
      etlJobs: _etlJobs(now),
      dashboards: _dashboards(),
      reports: _reports(),
      forecasts: _forecasts(),
      scorecards: _scorecards(),
      qualityIssues: _quality(),
      lineage: _lineage(),
      catalog: _catalog(),
      aiInsights: _aiInsights(),
      activities: _activities(now),
      fromRemote: false,
      loadedAt: now,
    );
  }

  static List<BiadwKpi> _kpis() => const [
        BiadwKpi(
          label: 'Revenue MTD',
          value: 185000000,
          unit: 'currency',
          changePct: 14.2,
          code: 'KPI-REV-MTD',
        ),
        BiadwKpi(
          label: 'Conversion Rate',
          value: 18.6,
          unit: 'pct',
          changePct: 15.5,
          code: 'KPI-CONV',
        ),
        BiadwKpi(
          label: 'Construction %',
          value: 72.4,
          unit: 'pct',
          changePct: 6.5,
          status: 'watch',
          code: 'KPI-CONST-PCT',
        ),
        BiadwKpi(
          label: 'ETL Success 7d',
          value: 87.5,
          unit: 'pct',
          changePct: -7.9,
          status: 'watch',
          code: 'KPI-ETL-HEALTH',
        ),
        BiadwKpi(
          label: 'Open DQ Issues',
          value: 3,
          status: 'critical',
          code: 'KPI-DQ-OPEN',
        ),
        BiadwKpi(label: 'Active Sources', value: 5),
        BiadwKpi(label: 'Published Dashboards', value: 2),
      ];

  static List<BiadwDataSource> _sources() => const [
        BiadwDataSource(
          id: 'e1600001-0000-4000-8000-000000000001',
          code: 'SRC-FIN-01',
          name: 'Finance Ledger Mirror',
          sourceModule: 'finance',
          ownerLabel: 'CFO Office',
          summary: 'Invoice, receipt, and GL extracts for warehouse marts.',
        ),
        BiadwDataSource(
          id: 'e1600001-0000-4000-8000-000000000002',
          code: 'SRC-SALES-01',
          name: 'Sales & Booking Feed',
          sourceModule: 'sales',
          ownerLabel: 'Sales Ops',
          summary: 'Reservations, bookings, and conversion events.',
        ),
        BiadwDataSource(
          id: 'e1600001-0000-4000-8000-000000000003',
          code: 'SRC-CRM-01',
          name: 'CRM Pipeline Feed',
          sourceModule: 'crm',
          ownerLabel: 'CRM Lead',
        ),
        BiadwDataSource(
          id: 'e1600001-0000-4000-8000-000000000004',
          code: 'SRC-CPMS-01',
          name: 'Construction Progress Feed',
          sourceModule: 'construction',
          ownerLabel: 'PMO',
        ),
        BiadwDataSource(
          id: 'e1600001-0000-4000-8000-000000000005',
          code: 'SRC-INV-01',
          name: 'Inventory & Supply Mirror',
          sourceModule: 'inventory',
          ownerLabel: 'Supply Chain',
        ),
      ];

  static List<BiadwDataset> _datasets() => const [
        BiadwDataset(
          id: 'e1600002-0000-4000-8000-000000000001',
          code: 'DS-REV-DAILY',
          name: 'Daily Revenue Mart',
          grainLabel: 'day × estate',
          rowEstimate: 42000,
          summary: 'Daily recognized revenue by estate and channel.',
        ),
        BiadwDataset(
          id: 'e1600002-0000-4000-8000-000000000002',
          code: 'DS-CONV',
          name: 'Sales Conversion Mart',
          grainLabel: 'week × funnel stage',
          rowEstimate: 18000,
        ),
        BiadwDataset(
          id: 'e1600002-0000-4000-8000-000000000003',
          code: 'DS-CONST-PCT',
          name: 'Construction Completeness Mart',
          grainLabel: 'week × project',
          rowEstimate: 9600,
        ),
      ];

  static List<BiadwEtlJob> _etlJobs(DateTime now) => [
        BiadwEtlJob(
          id: 'e1600005-0000-4000-8000-000000000001',
          code: 'ETL-REV-DAILY',
          name: 'Load Daily Revenue Mart',
          status: 'success',
          lastRunAt: now.subtract(const Duration(hours: 6)),
          lastDurationMs: 48200,
          ownerLabel: 'Data Eng',
          summary: 'Nightly finance → DS-REV-DAILY load.',
        ),
        BiadwEtlJob(
          id: 'e1600005-0000-4000-8000-000000000002',
          code: 'ETL-CONV-WK',
          name: 'Load Sales Conversion Mart',
          status: 'failed',
          lastRunAt: now.subtract(const Duration(days: 2)),
          lastDurationMs: 1200,
          ownerLabel: 'Data Eng',
          summary: 'Weekly sales funnel load — last run failed on schema drift.',
        ),
      ];

  static List<BiadwDashboard> _dashboards() => const [
        BiadwDashboard(
          id: 'e1600009-0000-4000-8000-000000000001',
          code: 'DB-EXEC-01',
          title: 'Executive Intelligence Hub',
          audience: 'executive',
          status: 'published',
          ownerLabel: 'CEO Office',
          summary: 'Primary executive BI surface.',
        ),
        BiadwDashboard(
          id: 'e1600009-0000-4000-8000-000000000002',
          code: 'DB-FIN-01',
          title: 'Finance Performance Board',
          audience: 'finance',
          status: 'published',
          ownerLabel: 'CFO Office',
        ),
        BiadwDashboard(
          id: 'e1600009-0000-4000-8000-000000000003',
          code: 'DB-BOARD-01',
          title: 'Board Pack Snapshot',
          audience: 'board',
          status: 'draft',
          ownerLabel: 'Company Secretary',
        ),
      ];

  static List<BiadwReport> _reports() => const [
        BiadwReport(
          id: 'e160000c-0000-4000-8000-000000000001',
          code: 'RPT-2026-0714',
          title: 'Weekly Executive Brief — 14 Jul 2026',
          reportType: 'executive',
          periodLabel: 'W29 2026',
          status: 'published',
          summary:
              'Revenue MTD up 14.2%; conversion 18.6%; construction 72.4%; ETL watch.',
          ownerLabel: 'BI Team',
        ),
        BiadwReport(
          id: 'e160000c-0000-4000-8000-000000000002',
          code: 'RPT-BOARD-Q3',
          title: 'Board Q3 Intelligence Pack (stub)',
          reportType: 'board',
          periodLabel: 'Q3 2026',
          status: 'draft',
          summary: 'Board pack stub linking scorecards and forecasts.',
        ),
      ];

  static List<BiadwForecast> _forecasts() => const [
        BiadwForecast(
          id: 'e1600012-0000-4000-8000-000000000001',
          code: 'FC-REV-30',
          title: 'Revenue next 30 days',
          metricLabel: 'Revenue',
          horizonLabel: '30d',
          forecastValue: 210000000,
          confidencePct: 84,
          unit: 'currency',
          summary: 'Enterprise Forecast Engine™ stub — confidence 84%.',
        ),
        BiadwForecast(
          id: 'e1600012-0000-4000-8000-000000000002',
          code: 'FC-CONV-4W',
          title: 'Conversion next 4 weeks',
          metricLabel: 'Conversion %',
          horizonLabel: '4w',
          forecastValue: 19.2,
          confidencePct: 78.5,
          unit: 'pct',
          summary: 'Conversion outlook with mid confidence band.',
        ),
      ];

  static List<BiadwScorecard> _scorecards() => const [
        BiadwScorecard(
          id: 'e1600010-0000-4000-8000-000000000001',
          code: 'SC-CEO-01',
          title: 'CEO Scorecard — Jul 2026',
          audience: 'ceo',
          periodLabel: 'Jul 2026',
          overallScore: 82.5,
          status: 'published',
          ownerLabel: 'CEO Office',
          summary: 'Executive scorecard stub — growth, delivery, risk.',
        ),
        BiadwScorecard(
          id: 'e1600010-0000-4000-8000-000000000002',
          code: 'SC-CFO-01',
          title: 'CFO Scorecard — Jul 2026',
          audience: 'cfo',
          periodLabel: 'Jul 2026',
          overallScore: 79.0,
          status: 'published',
          ownerLabel: 'CFO Office',
          summary: 'Finance scorecard stub.',
        ),
      ];

  static List<BiadwQualityIssue> _quality() => const [
        BiadwQualityIssue(
          id: 'e1600014-0000-4000-8000-000000000001',
          code: 'DQI-2026-1601',
          title: 'Schema drift — booking_stage missing',
          severity: 'critical',
          status: 'open',
          datasetLabel: 'DS-CONV',
          ownerLabel: 'Data Steward',
          summary: 'ETL-CONV-WK failed; stage column absent in source extract.',
        ),
        BiadwQualityIssue(
          id: 'e1600014-0000-4000-8000-000000000002',
          code: 'DQI-2026-1602',
          title: 'Null revenue rows (12)',
          severity: 'high',
          status: 'investigating',
          datasetLabel: 'DS-REV-DAILY',
          ownerLabel: 'Finance Analyst',
        ),
        BiadwQualityIssue(
          id: 'e1600014-0000-4000-8000-000000000003',
          code: 'DQI-2026-1603',
          title: 'Late construction weekly feed',
          severity: 'medium',
          status: 'open',
          datasetLabel: 'DS-CONST-PCT',
          ownerLabel: 'PMO Analyst',
        ),
      ];

  static List<BiadwLineageEdge> _lineage() => const [
        BiadwLineageEdge(
          id: 'e1600017-0000-4000-8000-000000000001',
          code: 'LIN-FIN-REV',
          sourceLabel: 'Finance Ledger Mirror',
          targetLabel: 'Daily Revenue Mart',
          lineageType: 'etl',
          summary: 'SRC-FIN-01 → DS-REV-DAILY via ETL-REV-DAILY',
        ),
        BiadwLineageEdge(
          id: 'e1600017-0000-4000-8000-000000000002',
          code: 'LIN-REV-KPI',
          sourceLabel: 'Daily Revenue Mart',
          targetLabel: 'Revenue MTD KPI',
          lineageType: 'aggregate',
        ),
      ];

  static List<BiadwCatalogEntry> _catalog() => const [
        BiadwCatalogEntry(
          id: 'e1600016-0000-4000-8000-000000000001',
          code: 'CAT-REV',
          title: 'Daily Revenue Mart',
          catalogType: 'dataset',
          ownerLabel: 'BI Team',
          summary: 'Catalog entry for DS-REV-DAILY',
        ),
        BiadwCatalogEntry(
          id: 'e1600016-0000-4000-8000-000000000002',
          code: 'CAT-KPI-REV',
          title: 'Revenue MTD KPI',
          catalogType: 'kpi',
          ownerLabel: 'CFO Office',
        ),
      ];

  static List<BiadwAiInsight> _aiInsights() => const [
        BiadwAiInsight(
          id: 'e1600019-0000-4000-8000-000000000001',
          title: 'Revenue momentum vs board target',
          body:
              'MTD revenue at ₦185M (+14.2%) tracking toward ₦200M target; collections lag may compress cash conversion.',
          insightType: 'briefing',
          confidencePct: 86,
        ),
        BiadwAiInsight(
          id: 'e1600019-0000-4000-8000-000000000002',
          title: 'ETL failure impacting sales KPIs',
          body:
              'ETL-CONV-WK failure and DQI-2026-1601 suggest treating conversion KPI as watch until schema fix lands.',
          insightType: 'quality',
          confidencePct: 91,
        ),
        BiadwAiInsight(
          id: 'e1600019-0000-4000-8000-000000000003',
          title: 'Construction completion slowing',
          body:
              'Construction completion 72.4% with watch status; board pack should call out site delay risk.',
          insightType: 'kpi',
          confidencePct: 79,
        ),
      ];

  static List<BiadwActivity> _activities(DateTime now) => [
        BiadwActivity(
          id: 'e160001a-0000-4000-8000-000000000001',
          action: 'etl_success',
          summary: 'ETL-REV-DAILY completed — 12,540 rows',
          actorLabel: 'Data Eng',
          occurredAt: now.subtract(const Duration(hours: 6)),
        ),
        BiadwActivity(
          id: 'e160001a-0000-4000-8000-000000000002',
          action: 'etl_failed',
          summary: 'ETL-CONV-WK failed — booking_stage missing',
          actorLabel: 'Data Eng',
          occurredAt: now.subtract(const Duration(days: 2)),
        ),
        BiadwActivity(
          id: 'e160001a-0000-4000-8000-000000000003',
          action: 'quality_opened',
          summary: 'DQI-2026-1601 opened as critical',
          actorLabel: 'Data Steward',
          occurredAt: now.subtract(const Duration(days: 2)),
        ),
        BiadwActivity(
          id: 'e160001a-0000-4000-8000-000000000004',
          action: 'dashboard_published',
          summary: 'DB-EXEC-01 Executive Intelligence Hub published',
          actorLabel: 'BI Lead',
          occurredAt: now.subtract(const Duration(days: 5)),
        ),
      ];
}
