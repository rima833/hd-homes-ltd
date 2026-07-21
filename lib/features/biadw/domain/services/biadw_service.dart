import 'package:hdhomesproject/features/biadw/domain/entities/biadw_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Loads BI Command Center snapshot from Supabase (falls back to demo).
class BiadwService {
  BiadwService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  Future<BiadwCommandCenterSnapshot> loadCommandCenter() async {
    final demo = BiadwDemo.snapshot();
    final client = _client;
    if (client == null) return demo;

    try {
      List<BiadwKpi> kpis = demo.kpis;
      try {
        final rows = await client
            .from('analytics_kpis')
            .select()
            .order('name')
            .limit(40);
        if (rows.isNotEmpty) {
          kpis = rows
              .map(
                (e) =>
                    BiadwKpi.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<BiadwDataSource> sources = demo.dataSources;
      try {
        final rows = await client
            .from('analytics_data_sources')
            .select()
            .order('name')
            .limit(40);
        if (rows.isNotEmpty) {
          sources = rows
              .map(
                (e) => BiadwDataSource.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<BiadwDataset> datasets = demo.datasets;
      try {
        final rows = await client
            .from('analytics_datasets')
            .select()
            .order('name')
            .limit(40);
        if (rows.isNotEmpty) {
          datasets = rows
              .map(
                (e) => BiadwDataset.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<BiadwEtlJob> etlJobs = demo.etlJobs;
      try {
        final rows = await client
            .from('analytics_etl_jobs')
            .select()
            .order('name')
            .limit(40);
        if (rows.isNotEmpty) {
          etlJobs = rows
              .map(
                (e) =>
                    BiadwEtlJob.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<BiadwDashboard> dashboards = demo.dashboards;
      try {
        final rows = await client
            .from('analytics_dashboards')
            .select()
            .order('title')
            .limit(40);
        if (rows.isNotEmpty) {
          dashboards = rows
              .map(
                (e) => BiadwDashboard.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<BiadwReport> reports = demo.reports;
      try {
        final rows = await client
            .from('analytics_reports')
            .select()
            .order('created_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          reports = rows
              .map(
                (e) =>
                    BiadwReport.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<BiadwForecast> forecasts = demo.forecasts;
      try {
        final rows = await client
            .from('analytics_forecasts')
            .select()
            .order('forecast_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          forecasts = rows
              .map(
                (e) => BiadwForecast.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<BiadwScorecard> scorecards = demo.scorecards;
      try {
        final rows = await client
            .from('analytics_scorecards')
            .select()
            .order('title')
            .limit(20);
        if (rows.isNotEmpty) {
          scorecards = rows
              .map(
                (e) => BiadwScorecard.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<BiadwQualityIssue> quality = demo.qualityIssues;
      try {
        final rows = await client
            .from('analytics_quality_issues')
            .select()
            .order('detected_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          quality = rows
              .map(
                (e) => BiadwQualityIssue.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<BiadwLineageEdge> lineage = demo.lineage;
      try {
        final rows = await client
            .from('analytics_lineage')
            .select()
            .order('source_label')
            .limit(40);
        if (rows.isNotEmpty) {
          lineage = rows
              .map(
                (e) => BiadwLineageEdge.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<BiadwCatalogEntry> catalog = demo.catalog;
      try {
        final rows = await client
            .from('analytics_data_catalog')
            .select()
            .order('title')
            .limit(40);
        if (rows.isNotEmpty) {
          catalog = rows
              .map(
                (e) => BiadwCatalogEntry.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<BiadwAiInsight> aiInsights = demo.aiInsights;
      try {
        final rows = await client
            .from('analytics_ai_insights')
            .select()
            .order('created_at', ascending: false)
            .limit(20);
        if (rows.isNotEmpty) {
          aiInsights = rows
              .map(
                (e) => BiadwAiInsight.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<BiadwActivity> activities = demo.activities;
      try {
        final rows = await client
            .from('analytics_activity_logs')
            .select()
            .order('occurred_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          activities = rows
              .map(
                (e) => BiadwActivity.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      return BiadwCommandCenterSnapshot(
        kpis: kpis.isEmpty ? demo.kpis : kpis,
        dataSources: sources,
        datasets: datasets,
        etlJobs: etlJobs,
        dashboards: dashboards,
        reports: reports,
        forecasts: forecasts,
        scorecards: scorecards,
        qualityIssues: quality,
        lineage: lineage,
        catalog: catalog,
        aiInsights: aiInsights,
        activities: activities,
        fromRemote: true,
        loadedAt: DateTime.now(),
      );
    } catch (_) {
      return demo;
    }
  }

  String generateExecutiveBriefing(BiadwCommandCenterSnapshot snap) {
    final failedEtl = snap.etlJobs.where((j) => j.isFailed).length;
    final openDq = snap.qualityIssues.where((q) => q.isOpen).length;
    final watchKpis =
        snap.kpis.where((k) => k.status == 'watch' || k.status == 'critical').length;
    return 'AI Executive Briefing™ advisory: '
        '$watchKpis KPI(s) on watch/critical, $failedEtl failed ETL job(s), '
        '$openDq open data-quality issue(s). '
        'Prioritize conversion mart schema fix and construction pace brief. '
        '${snap.aiDisclaimer}';
  }

  static List<String> detectBiSignals(BiadwCommandCenterSnapshot snap) {
    final signals = <String>[];
    if (snap.etlJobs.any((j) => j.isFailed)) {
      signals.add('ETL job failures detected on analytics pipelines');
    }
    if (snap.qualityIssues.any((q) => q.isOpen && q.severity == 'critical')) {
      signals.add('Critical data quality issues open');
    }
    if (snap.kpis.any((k) => k.status == 'watch' || k.status == 'critical')) {
      signals.add('KPIs on watch or critical status');
    }
    if (snap.forecasts.any((f) => f.confidencePct < 80)) {
      signals.add('Forecast confidence below 80% on one or more models');
    }
    if (snap.dashboards.any((d) => d.status == 'draft')) {
      signals.add('Draft dashboards pending publish for board pack');
    }
    return signals;
  }
}
