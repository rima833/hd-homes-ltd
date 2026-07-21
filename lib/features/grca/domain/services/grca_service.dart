import 'package:hdhomesproject/features/grca/domain/entities/grca_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Loads GRC Command Center snapshot from Supabase (falls back to demo).
class GrcaService {
  GrcaService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  Future<GrcaCommandCenterSnapshot> loadCommandCenter() async {
    final demo = GrcaDemo.snapshot();
    final client = _client;
    if (client == null) return demo;

    try {
      List<GrcaRisk> risks = demo.risks;
      try {
        final rows = await client
            .from('risk_register')
            .select()
            .order('severity')
            .limit(50);
        if (rows.isNotEmpty) {
          risks = rows
              .map(
                (e) =>
                    GrcaRisk.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<GrcaComplianceFramework> compliance = demo.complianceFrameworks;
      try {
        final rows = await client
            .from('compliance_frameworks')
            .select()
            .order('name')
            .limit(20);
        if (rows.isNotEmpty) {
          compliance = rows
              .map(
                (e) => GrcaComplianceFramework.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<GrcaPolicy> policies = demo.policies;
      try {
        final rows = await client
            .from('corporate_policies')
            .select()
            .order('title')
            .limit(40);
        if (rows.isNotEmpty) {
          policies = rows
              .map(
                (e) =>
                    GrcaPolicy.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<GrcaAuditPlan> auditPlans = demo.auditPlans;
      try {
        final rows =
            await client.from('audit_plans').select().order('title').limit(20);
        if (rows.isNotEmpty) {
          auditPlans = rows
              .map(
                (e) => GrcaAuditPlan.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<GrcaAuditFinding> findings = demo.auditFindings;
      try {
        final rows = await client
            .from('audit_findings')
            .select()
            .order('created_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          findings = rows
              .map(
                (e) => GrcaAuditFinding.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<GrcaLegalCase> legalCases = demo.legalCases;
      try {
        final rows = await client
            .from('legal_cases')
            .select()
            .order('opened_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          legalCases = rows
              .map(
                (e) => GrcaLegalCase.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<GrcaEthicsReport> ethics = demo.ethicsReports;
      try {
        final rows = await client
            .from('ethics_reports')
            .select()
            .order('received_at', ascending: false)
            .limit(20);
        if (rows.isNotEmpty) {
          ethics = rows
              .map(
                (e) => GrcaEthicsReport.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<GrcaBoardMeeting> board = demo.boardMeetings;
      try {
        final rows = await client
            .from('board_meetings')
            .select()
            .order('scheduled_at')
            .limit(20);
        if (rows.isNotEmpty) {
          board = rows
              .map(
                (e) => GrcaBoardMeeting.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<GrcaBcmPlan> bcm = demo.bcmPlans;
      try {
        final rows = await client
            .from('business_continuity_plans')
            .select()
            .order('title')
            .limit(20);
        if (rows.isNotEmpty) {
          bcm = rows
              .map(
                (e) =>
                    GrcaBcmPlan.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<GrcaCalendarEvent> calendar = demo.calendarEvents;
      try {
        final rows = await client
            .from('regulatory_calendar')
            .select()
            .order('due_at')
            .limit(40);
        if (rows.isNotEmpty) {
          calendar = rows
              .map(
                (e) => GrcaCalendarEvent.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<GrcaAiInsight> aiInsights = demo.aiInsights;
      try {
        final rows = await client
            .from('grc_ai_insights')
            .select()
            .order('created_at', ascending: false)
            .limit(20);
        if (rows.isNotEmpty) {
          aiInsights = rows
              .map(
                (e) => GrcaAiInsight.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<GrcaActivity> activities = demo.activities;
      try {
        final rows = await client
            .from('grc_activity_logs')
            .select()
            .order('occurred_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          activities = rows
              .map(
                (e) => GrcaActivity.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<GrcaReport> reports = demo.reports;
      try {
        final rows = await client
            .from('grc_reports')
            .select()
            .order('created_at', ascending: false)
            .limit(20);
        if (rows.isNotEmpty) {
          reports = rows
              .map(
                (e) =>
                    GrcaReport.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      final kpis = _deriveKpis(
        risks: risks,
        compliance: compliance,
        findings: findings,
        legalCases: legalCases,
        policies: policies,
        calendar: calendar,
      );

      return GrcaCommandCenterSnapshot(
        kpis: kpis,
        risks: risks,
        complianceFrameworks: compliance,
        policies: policies,
        auditPlans: auditPlans,
        auditFindings: findings,
        legalCases: legalCases,
        ethicsReports: ethics,
        boardMeetings: board,
        bcmPlans: bcm,
        calendarEvents: calendar,
        aiInsights: aiInsights,
        activities: activities,
        reports: reports,
        fromRemote: true,
        loadedAt: DateTime.now(),
      );
    } catch (_) {
      return demo;
    }
  }

  List<GrcaKpi> _deriveKpis({
    required List<GrcaRisk> risks,
    required List<GrcaComplianceFramework> compliance,
    required List<GrcaAuditFinding> findings,
    required List<GrcaLegalCase> legalCases,
    required List<GrcaPolicy> policies,
    required List<GrcaCalendarEvent> calendar,
  }) {
    final openRisks = risks
        .where((r) => {'open', 'mitigating'}.contains(r.status))
        .length
        .toDouble();
    final criticalOpen =
        risks.where((r) => r.isCriticalOpen).length.toDouble();
    final avgScore = compliance.isEmpty
        ? 0.0
        : compliance.fold<double>(0, (s, c) => s + c.scorePct) /
            compliance.length;
    final openFindings =
        findings.where((f) => f.isOpen).length.toDouble();
    final activePolicies =
        policies.where((p) => p.status == 'active').length.toDouble();
    final deadlines = calendar.where((e) => e.isDueSoon).length.toDouble();

    return [
      GrcaKpi(
        label: 'Open Risks',
        value: openRisks,
        status: openRisks > 0 ? 'watch' : 'ok',
      ),
      GrcaKpi(
        label: 'Critical Open',
        value: criticalOpen,
        status: criticalOpen > 0 ? 'watch' : 'ok',
      ),
      GrcaKpi(label: 'Compliance Score', value: avgScore, unit: 'pct'),
      GrcaKpi(
        label: 'Open Findings',
        value: openFindings,
        status: openFindings > 0 ? 'watch' : 'ok',
      ),
      GrcaKpi(label: 'Legal Cases', value: legalCases.length.toDouble()),
      GrcaKpi(label: 'Policies Active', value: activePolicies),
      GrcaKpi(
        label: 'Deadlines 30d',
        value: deadlines,
        status: deadlines > 0 ? 'watch' : 'ok',
      ),
    ];
  }

  String generateIntelligenceBriefing(GrcaCommandCenterSnapshot snap) {
    final critical = snap.risks.where((r) => r.isCriticalOpen).length;
    final findings = snap.auditFindings.where((f) => f.isOpen).length;
    final deadlines = snap.calendarEvents.where((e) => e.isDueSoon).length;
    return 'Enterprise Governance Command Center™ advisory brief: '
        '$critical critical open risk(s), $findings open audit finding(s), '
        '$deadlines regulatory deadline(s) within 30 days. '
        'Prioritize permit risk, NDPR evidence, and vendor KYC remediations. '
        '${snap.aiDisclaimer}';
  }

  static List<String> detectGrcSignals(GrcaCommandCenterSnapshot snap) {
    final signals = <String>[];
    if (snap.risks.any((r) => r.isCriticalOpen)) {
      signals.add('Critical risks open on the enterprise risk register');
    }
    if (snap.auditFindings.any((f) => f.isOpen)) {
      signals.add('Open audit findings awaiting corrective action');
    }
    if (snap.calendarEvents.any((e) => e.isDueSoon)) {
      signals.add('Regulatory deadlines or inspections within 30 days');
    }
    if (snap.legalCases.any((c) => c.status == 'open')) {
      signals.add('Open legal cases requiring counsel attention');
    }
    if (snap.ethicsReports.isNotEmpty) {
      signals.add('Ethics/whistleblower intake requiring restricted access');
    }
    return signals;
  }
}
