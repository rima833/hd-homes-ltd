import 'package:hdhomesproject/features/crm/domain/entities/crm_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Loads CRM Command Center snapshot from Supabase (falls back to demo).
class CrmService {
  CrmService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  Future<CrmCommandCenterSnapshot> loadCommandCenter() async {
    final demo = CrmDemo.snapshot();
    final client = _client;
    if (client == null) return demo;

    try {
      final clientRows = await client
          .from('crm_clients')
          .select()
          .order('updated_at', ascending: false)
          .limit(100);

      final clients = <CrmClient>[];
      for (final row in clientRows) {
        clients.add(
          CrmClient.fromJson(Map<String, dynamic>.from(row as Map)),
        );
      }

      if (clients.isEmpty) return demo;

      // Attach preferences when available.
      try {
        final prefRows = await client.from('crm_preferences').select().limit(100);
        if (prefRows.isNotEmpty) {
          final byClient = <String, CrmClientPreference>{};
          for (final row in prefRows) {
            final map = Map<String, dynamic>.from(row as Map);
            final id = map['client_id']?.toString();
            if (id != null) {
              byClient[id] = CrmClientPreference.fromJson(map);
            }
          }
          for (var i = 0; i < clients.length; i++) {
            final pref = byClient[clients[i].id];
            if (pref == null) continue;
            final c = clients[i];
            clients[i] = CrmClient(
              id: c.id,
              clientCode: c.clientCode,
              fullName: c.fullName,
              email: c.email,
              phone: c.phone,
              whatsapp: c.whatsapp,
              customerType: c.customerType,
              relationshipStatus: c.relationshipStatus,
              assignedStaffId: c.assignedStaffId,
              profileId: c.profileId,
              nationality: c.nationality,
              preferredLanguage: c.preferredLanguage,
              occupation: c.occupation,
              company: c.company,
              industry: c.industry,
              budgetMin: c.budgetMin,
              budgetMax: c.budgetMax,
              preferredLocations: c.preferredLocations,
              healthScore: c.healthScore,
              healthLabel: c.healthLabel,
              leadScore: c.leadScore,
              aiSummary: c.aiSummary,
              marketingConsent: c.marketingConsent,
              preferences: pref,
              tags: c.tags,
            );
          }
        }
      } catch (_) {}

      List<CrmPipelineStage> stages = demo.stages;
      try {
        final stageRows = await client
            .from('crm_pipeline_stages')
            .select()
            .eq('is_active', true)
            .order('sort_order');
        if (stageRows.isNotEmpty) {
          stages = stageRows
              .map(
                (e) => CrmPipelineStage.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<CrmLead> leads = demo.leads;
      try {
        final leadRows = await client
            .from('crm_leads')
            .select(
              '*, crm_pipeline_stages(slug, name), crm_lead_sources(name), crm_clients(full_name)',
            )
            .order('captured_at', ascending: false)
            .limit(100);
        if (leadRows.isNotEmpty) {
          leads = leadRows
              .map(
                (e) => CrmLead.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<CrmTask> tasks = demo.tasks;
      try {
        final taskRows = await client
            .from('crm_tasks')
            .select('*, crm_clients(full_name)')
            .order('due_at', ascending: true)
            .limit(50);
        if (taskRows.isNotEmpty) {
          tasks = taskRows
              .map(
                (e) => CrmTask.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<CrmAppointment> appointments = demo.appointments;
      try {
        final apptRows = await client
            .from('crm_appointments')
            .select('*, crm_clients(full_name)')
            .order('scheduled_at', ascending: true)
            .limit(50);
        if (apptRows.isNotEmpty) {
          appointments = apptRows
              .map(
                (e) => CrmAppointment.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<CrmTimelineEvent> timeline = demo.timeline;
      try {
        final lifeRows = await client
            .from('crm_activity_logs')
            .select('*, crm_clients(full_name)')
            .order('occurred_at', ascending: false)
            .limit(40);
        if (lifeRows.isNotEmpty) {
          timeline = lifeRows
              .map(
                (e) => CrmTimelineEvent.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      return CrmCommandCenterSnapshot(
        kpis: CrmDemo.aggregateKpis(
          clients: clients,
          leads: leads,
          tasks: tasks,
        ),
        clients: clients,
        leads: leads,
        tasks: tasks,
        appointments: appointments,
        timeline: timeline,
        stages: stages,
        aiInsights: demo.aiInsights,
        leadIntelligence: demo.leadIntelligence,
        relationshipGraph: demo.relationshipGraph,
        fromRemote: true,
        loadedAt: DateTime.now(),
      );
    } catch (_) {
      return demo;
    }
  }

  /// Stub AI summary for a CRM client 360° view.
  String generateClientSummary(CrmClient client) {
    final status = client.relationshipStatus.label.toLowerCase();
    final type = client.customerType.label.toLowerCase();
    final health = client.healthLabel.label;
    final budget = client.budgetRange;
    final locs = client.preferredLocations.isEmpty
        ? 'Nigeria'
        : client.preferredLocations.join(', ');
    final score = client.leadScore.toStringAsFixed(0);

    return 'AI CRM summary: $type ($status) in $locs with budget $budget. '
        'Health $health · lead score $score/100. '
        '${client.company != null ? 'Company: ${client.company}. ' : ''}'
        '${client.aiSummary ?? 'Recommend reviewing open tasks and next appointment.'}';
  }

  static double computeHealthScore({
    double engagement = 0,
    double recency = 0,
    double pipeline = 0,
    double referrals = 0,
  }) {
    final score = (engagement * 0.35) +
        (recency * 0.25) +
        (pipeline * 0.25) +
        (referrals * 0.15);
    return score.clamp(0, 100);
  }

  static CrmHealthLabel labelForScore(double score) =>
      CrmHealthLabel.fromScore(score);

  static double computeLeadScore({
    double budgetFit = 0,
    double engagement = 0,
    double stageProbability = 0,
    double priorityBoost = 0,
  }) {
    final score = (budgetFit * 0.3) +
        (engagement * 0.3) +
        (stageProbability * 0.25) +
        (priorityBoost * 0.15);
    return score.clamp(0, 100);
  }
}
