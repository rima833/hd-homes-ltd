import 'package:hdhomesproject/features/eaih/domain/entities/eaih_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Loads AI Command Center snapshot from Supabase (falls back to demo).
class EaihService {
  EaihService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  Future<EaihCommandCenterSnapshot> loadCommandCenter() async {
    final demo = EaihDemo.snapshot();
    final client = _client;
    if (client == null) return demo;

    try {
      List<EaihServiceRecord> services = demo.services;
      try {
        final rows = await client
            .from('ai_services')
            .select()
            .order('name')
            .limit(40);
        if (rows.isNotEmpty) {
          services = rows
              .map(
                (e) => EaihServiceRecord.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<EaihCopilot> copilots = demo.copilots;
      try {
        final rows = await client
            .from('ai_copilots')
            .select()
            .order('name')
            .limit(40);
        if (rows.isNotEmpty) {
          copilots = rows
              .map(
                (e) =>
                    EaihCopilot.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<EaihModel> models = demo.models;
      try {
        final rows =
            await client.from('ai_models').select().order('name').limit(40);
        if (rows.isNotEmpty) {
          models = rows
              .map(
                (e) => EaihModel.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<EaihModelVersion> versions = demo.modelVersions;
      try {
        final rows = await client
            .from('ai_model_versions')
            .select()
            .order('version_label')
            .limit(40);
        if (rows.isNotEmpty) {
          versions = rows
              .map(
                (e) => EaihModelVersion.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<EaihPrediction> predictions = demo.predictions;
      try {
        final rows = await client
            .from('ai_predictions')
            .select()
            .order('predicted_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          predictions = rows
              .map(
                (e) => EaihPrediction.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<EaihRecommendation> recommendations = demo.recommendations;
      try {
        final rows = await client
            .from('ai_recommendations')
            .select()
            .order('created_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          recommendations = rows
              .map(
                (e) => EaihRecommendation.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<EaihSearchQuery> searchQueries = demo.searchQueries;
      try {
        final rows = await client
            .from('ai_search_queries')
            .select()
            .order('queried_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          searchQueries = rows
              .map(
                (e) => EaihSearchQuery.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<EaihKnowledgeNode> nodes = demo.knowledgeNodes;
      try {
        final rows = await client
            .from('ai_knowledge_graph_nodes')
            .select()
            .order('label')
            .limit(40);
        if (rows.isNotEmpty) {
          nodes = rows
              .map(
                (e) => EaihKnowledgeNode.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<EaihKnowledgeEdge> edges = demo.knowledgeEdges;
      try {
        final rows = await client
            .from('ai_knowledge_graph_edges')
            .select()
            .order('code')
            .limit(40);
        if (rows.isNotEmpty) {
          edges = rows
              .map(
                (e) => EaihKnowledgeEdge.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<EaihAutomationJob> jobs = demo.automationJobs;
      try {
        final rows = await client
            .from('ai_automation_jobs')
            .select()
            .order('created_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          jobs = rows
              .map(
                (e) => EaihAutomationJob.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<EaihWorkflowRule> rules = demo.workflowRules;
      try {
        final rows = await client
            .from('ai_workflow_rules')
            .select()
            .order('name')
            .limit(40);
        if (rows.isNotEmpty) {
          rules = rows
              .map(
                (e) => EaihWorkflowRule.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<EaihGovernancePolicy> policies = demo.governancePolicies;
      try {
        final rows = await client
            .from('ai_governance_policies')
            .select()
            .order('title')
            .limit(40);
        if (rows.isNotEmpty) {
          policies = rows
              .map(
                (e) => EaihGovernancePolicy.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<EaihMonitoringMetric> monitoring = demo.monitoring;
      try {
        final rows = await client
            .from('ai_model_monitoring')
            .select()
            .order('observed_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          monitoring = rows
              .map(
                (e) => EaihMonitoringMetric.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<EaihDriftReport> drift = demo.driftReports;
      try {
        final rows = await client
            .from('ai_drift_reports')
            .select()
            .order('detected_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          drift = rows
              .map(
                (e) => EaihDriftReport.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<EaihHubInsight> insights = demo.hubInsights;
      try {
        final rows = await client
            .from('ai_hub_insights')
            .select()
            .order('created_at', ascending: false)
            .limit(20);
        if (rows.isNotEmpty) {
          insights = rows
              .map(
                (e) => EaihHubInsight.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<EaihActivity> activities = demo.activities;
      try {
        final rows = await client
            .from('ai_activity_logs')
            .select()
            .order('occurred_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          activities = rows
              .map(
                (e) => EaihActivity.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      return EaihCommandCenterSnapshot(
        kpis: demo.kpis,
        services: services,
        copilots: copilots,
        models: models,
        modelVersions: versions,
        predictions: predictions,
        recommendations: recommendations,
        searchQueries: searchQueries,
        knowledgeNodes: nodes,
        knowledgeEdges: edges,
        automationJobs: jobs,
        workflowRules: rules,
        governancePolicies: policies,
        monitoring: monitoring,
        driftReports: drift,
        hubInsights: insights,
        activities: activities,
        fromRemote: true,
        loadedAt: DateTime.now(),
      );
    } catch (_) {
      return demo;
    }
  }

  String generateDecisionBriefing(EaihCommandCenterSnapshot snap) {
    final openDrift = snap.driftReports.where((d) => d.isOpen).length;
    final awaiting =
        snap.automationJobs.where((j) => j.awaitsApproval).length;
    final watchPred =
        snap.predictions.where((p) => p.confidencePct < 80).length;
    return 'Executive Decision Intelligence™ advisory: '
        '$openDrift open drift report(s), $awaiting automation job(s) awaiting approval, '
        '$watchPred prediction(s) below 80% confidence. '
        'Prioritize PMO delay review and sales forecaster drift mitigation. '
        '${snap.aiDisclaimer}';
  }

  static List<String> detectAiSignals(EaihCommandCenterSnapshot snap) {
    final signals = <String>[];
    if (snap.automationJobs.any((j) => j.isFailed)) {
      signals.add('Automation job failures detected on AI pipelines');
    }
    if (snap.automationJobs.any((j) => j.awaitsApproval)) {
      signals.add('Automation jobs awaiting human approval');
    }
    if (snap.driftReports.any((d) => d.isOpen && d.severity == 'high')) {
      signals.add('High-severity model drift reports open');
    }
    if (snap.monitoring.any((m) => m.status == 'watch' || m.status == 'critical')) {
      signals.add('Model monitoring metrics on watch or critical');
    }
    if (snap.predictions.any((p) => p.confidencePct < 80)) {
      signals.add('Prediction confidence below 80% on one or more models');
    }
    if (snap.recommendations.any((r) => r.needsReview)) {
      signals.add('Recommendations pending human review');
    }
    return signals;
  }
}
