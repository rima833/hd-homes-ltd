import 'package:hdhomesproject/features/esp/domain/entities/esp_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Loads the ESP snapshot from Supabase, preserving demo data per unavailable table.
class EspService {
  EspService({SupabaseClient? client}) : _client = client;
  final SupabaseClient? _client;

  Future<List<EspRecord>> _records(
    SupabaseClient client,
    String table,
    List<EspRecord> fallback,
  ) async {
    try {
      final rows = await client
          .from(table)
          .select()
          .order('created_at', ascending: false)
          .limit(40);
      if (rows.isEmpty) return fallback;
      return rows
          .map((e) => EspRecord.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return fallback;
    }
  }

  Future<List<EspAiInsight>> _insights(
    SupabaseClient client,
    List<EspAiInsight> fallback,
  ) async {
    try {
      final rows = await client
          .from('security_ai_insights')
          .select()
          .order('created_at', ascending: false)
          .limit(20);
      if (rows.isEmpty) return fallback;
      return rows
          .map(
            (e) => EspAiInsight.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    } catch (_) {
      return fallback;
    }
  }

  Future<EspCommandCenterSnapshot> loadCommandCenter() async {
    final demo = EspDemo.snapshot();
    final client = _client;
    if (client == null) return demo;
    return EspCommandCenterSnapshot(
      kpis: demo.kpis,
      sessions: await _records(client, 'user_sessions', demo.sessions),
      alerts: await _records(client, 'security_alerts', demo.alerts),
      threats: await _records(client, 'threat_detections', demo.threats),
      incidents: await _records(client, 'security_incidents', demo.incidents),
      mfa: await _records(client, 'mfa_settings', demo.mfa),
      audit: await _records(client, 'audit_logs', demo.audit),
      privacy: await _records(client, 'privacy_requests', demo.privacy),
      secrets: await _records(client, 'secrets_registry', demo.secrets),
      backups: await _records(client, 'backup_history', demo.backups),
      disasterRecovery: await _records(
        client,
        'disaster_recovery_plans',
        demo.disasterRecovery,
      ),
      aiSecurity: await _records(client, 'ai_security_events', demo.aiSecurity),
      insights: await _insights(client, demo.insights),
      activity: await _records(client, 'security_activity_logs', demo.activity),
      fromRemote: true,
      loadedAt: DateTime.now(),
    );
  }

  String generateSecurityBriefing(EspCommandCenterSnapshot snap) {
    final critical = snap.threats
        .where((e) => e.severity == EspSeverity.critical)
        .length;
    final open = snap.incidents.where((e) => e.status != 'resolved').length;
    return 'Enterprise Security Command Center™ advisory: $critical critical '
        'threat(s), $open open incident(s), ${snap.alerts.length} active alert(s). '
        'Prioritize identity containment and evidence preservation. ${snap.aiDisclaimer}';
  }

  static List<String> detectSecuritySignals(EspCommandCenterSnapshot snap) {
    final signals = <String>[];
    if (snap.threats.any((e) => e.severity == EspSeverity.critical)) {
      signals.add('Critical threat detection requires SOC triage');
    }
    if (snap.incidents.any((e) => e.status != 'resolved')) {
      signals.add('Open incident requires containment tracking');
    }
    if (snap.backups.any((e) => e.status != 'succeeded')) {
      signals.add('Backup job needs resilience review');
    }
    if (snap.privacy.any((e) => e.status == 'open')) {
      signals.add('Privacy request is awaiting action');
    }
    return signals.isEmpty
        ? ['Security posture nominal — continue monitoring']
        : signals;
  }
}
