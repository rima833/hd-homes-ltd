// Volume 4 Part 19 — ESP domain models and offline command-center snapshot.

const String kEspAiDisclaimer = 'AI-generated — editable / advisory';

enum EspSeverity { info, low, medium, high, critical }

enum EspIncidentStatus { open, investigating, contained, resolved }

class EspKpi {
  const EspKpi(
    this.label,
    this.value, {
    this.unit = 'count',
    this.status = 'ok',
  });
  final String label;
  final double value;
  final String unit;
  final String status;
  String get displayValue => unit == 'pct'
      ? '${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)}%'
      : value.toStringAsFixed(value % 1 == 0 ? 0 : 1);
}

class EspRecord {
  const EspRecord({
    required this.id,
    required this.title,
    required this.category,
    this.status = 'active',
    this.severity = EspSeverity.info,
    this.summary = '',
    this.occurredAt,
  });
  final String id;
  final String title;
  final String category;
  final String status;
  final EspSeverity severity;
  final String summary;
  final DateTime? occurredAt;

  factory EspRecord.fromJson(Map<String, dynamic> json) => EspRecord(
    id: json['id']?.toString() ?? '',
    title:
        (json['title'] ??
                json['name'] ??
                json['event_type'] ??
                'Security record')
            .toString(),
    category:
        (json['category'] ??
                json['alert_type'] ??
                json['threat_type'] ??
                'security')
            .toString(),
    status: (json['status'] ?? 'active').toString(),
    severity:
        EspSeverity.values
            .where((e) => e.name == json['severity'])
            .firstOrNull ??
        EspSeverity.info,
    summary: (json['summary'] ?? json['description'] ?? '').toString(),
    occurredAt: DateTime.tryParse(
      (json['occurred_at'] ?? json['created_at'] ?? '').toString(),
    ),
  );
}

class EspAiInsight {
  const EspAiInsight({
    required this.id,
    required this.title,
    required this.body,
    this.confidencePct,
    this.editable = true,
    this.disclaimer = kEspAiDisclaimer,
  });
  final String id;
  final String title;
  final String body;
  final double? confidencePct;
  final bool editable;
  final String disclaimer;

  factory EspAiInsight.fromJson(Map<String, dynamic> json) => EspAiInsight(
    id: json['id']?.toString() ?? '',
    title: json['title']?.toString() ?? '',
    body: json['body']?.toString() ?? '',
    confidencePct: (json['confidence_pct'] as num?)?.toDouble(),
    editable: json['editable'] as bool? ?? true,
    disclaimer: json['disclaimer']?.toString() ?? kEspAiDisclaimer,
  );
}

class EspCommandCenterSnapshot {
  const EspCommandCenterSnapshot({
    required this.kpis,
    required this.sessions,
    required this.alerts,
    required this.threats,
    required this.incidents,
    required this.mfa,
    required this.audit,
    required this.privacy,
    required this.secrets,
    required this.backups,
    required this.disasterRecovery,
    required this.aiSecurity,
    required this.insights,
    required this.activity,
    this.fromRemote = false,
    this.loadedAt,
    this.aiDisclaimer = kEspAiDisclaimer,
  });
  final List<EspKpi> kpis;
  final List<EspRecord> sessions;
  final List<EspRecord> alerts;
  final List<EspRecord> threats;
  final List<EspRecord> incidents;
  final List<EspRecord> mfa;
  final List<EspRecord> audit;
  final List<EspRecord> privacy;
  final List<EspRecord> secrets;
  final List<EspRecord> backups;
  final List<EspRecord> disasterRecovery;
  final List<EspRecord> aiSecurity;
  final List<EspAiInsight> insights;
  final List<EspRecord> activity;
  final bool fromRemote;
  final DateTime? loadedAt;
  final String aiDisclaimer;
}

class EspDemo {
  static EspCommandCenterSnapshot snapshot() {
    final now = DateTime.now();
    EspRecord item(
      String id,
      String title,
      String category, {
      String status = 'active',
      EspSeverity severity = EspSeverity.info,
      String summary = '',
    }) => EspRecord(
      id: id,
      title: title,
      category: category,
      status: status,
      severity: severity,
      summary: summary,
      occurredAt: now.subtract(const Duration(minutes: 18)),
    );
    return EspCommandCenterSnapshot(
      kpis: const [
        EspKpi('Security Score', 92, unit: 'pct'),
        EspKpi('Open Alerts', 4, status: 'watch'),
        EspKpi('Critical Threats', 1, status: 'critical'),
        EspKpi('MFA Coverage', 86, unit: 'pct'),
        EspKpi('Backup Success', 99.8, unit: 'pct'),
        EspKpi('DR Readiness', 94, unit: 'pct'),
      ],
      sessions: [
        item(
          'b1900001-0000-4000-8000-000000000001',
          'Admin · Windows / Edge',
          'trusted session',
        ),
        item(
          'b1900001-0000-4000-8000-000000000002',
          'Finance · Android',
          'step-up required',
          status: 'watch',
        ),
      ],
      alerts: [
        item(
          'b1900002-0000-4000-8000-000000000001',
          'Impossible travel signal',
          'identity',
          severity: EspSeverity.high,
        ),
        item(
          'b1900002-0000-4000-8000-000000000002',
          'Repeated API authorization failures',
          'application',
          severity: EspSeverity.medium,
        ),
      ],
      threats: [
        item(
          'b1900003-0000-4000-8000-000000000001',
          'Credential stuffing pattern',
          'account takeover',
          severity: EspSeverity.critical,
        ),
        item(
          'b1900003-0000-4000-8000-000000000002',
          'Suspicious export volume',
          'data loss',
          severity: EspSeverity.high,
        ),
      ],
      incidents: [
        item(
          'b1900004-0000-4000-8000-000000000001',
          'INC-2026-019 · Account takeover investigation',
          'identity',
          status: 'investigating',
          severity: EspSeverity.high,
        ),
      ],
      mfa: [
        item(
          'b1900005-0000-4000-8000-000000000001',
          'Administrators',
          'mandatory',
          summary: '100% enrolled',
        ),
        item(
          'b1900005-0000-4000-8000-000000000002',
          'Finance',
          'required',
          summary: '92% enrolled',
        ),
      ],
      audit: [
        item(
          'b1900006-0000-4000-8000-000000000001',
          'Role grant reviewed',
          'IAM',
        ),
        item(
          'b1900006-0000-4000-8000-000000000002',
          'Secret access approved',
          'vault',
        ),
      ],
      privacy: [
        item(
          'b1900007-0000-4000-8000-000000000001',
          'PRV-2026-004 · Data access request',
          'DSAR',
          status: 'open',
        ),
        item(
          'b1900007-0000-4000-8000-000000000002',
          'Marketing consent register',
          'consent',
          summary: '98.4% traceable',
        ),
      ],
      secrets: [
        item(
          'b1900008-0000-4000-8000-000000000001',
          'Paystack production key',
          'payment',
          summary: 'Rotation due in 21 days',
        ),
        item(
          'b1900008-0000-4000-8000-000000000002',
          'Email provider credential',
          'communications',
        ),
      ],
      backups: [
        item(
          'b1900009-0000-4000-8000-000000000001',
          'Nightly database backup',
          'database',
          status: 'succeeded',
          summary: 'Encrypted · verified',
        ),
      ],
      disasterRecovery: [
        item(
          'b190000a-0000-4000-8000-000000000001',
          'Primary platform recovery plan',
          'tier 1',
          summary: 'RTO 2h · RPO 15m',
        ),
        item(
          'b190000a-0000-4000-8000-000000000002',
          'Quarterly failover exercise',
          'test',
          status: 'passed',
        ),
      ],
      aiSecurity: [
        item(
          'b190000b-0000-4000-8000-000000000001',
          'Prompt injection blocked',
          'AI firewall',
          severity: EspSeverity.high,
        ),
        item(
          'b190000b-0000-4000-8000-000000000002',
          'Sensitive output redacted',
          'DLP',
        ),
      ],
      insights: const [
        EspAiInsight(
          id: 'b190000c-0000-4000-8000-000000000001',
          title: 'Enforce step-up for anomalous finance sessions',
          body:
              'Identity risk and transaction sensitivity indicate step-up authentication.',
          confidencePct: 88,
        ),
        EspAiInsight(
          id: 'b190000c-0000-4000-8000-000000000002',
          title: 'Prioritize credential-stuffing containment',
          body:
              'Rate-limit, revoke affected sessions, and review exposed identifiers.',
          confidencePct: 93,
        ),
      ],
      activity: [
        item(
          'b190000d-0000-4000-8000-000000000001',
          'Incident assigned to SOC lead',
          'incident',
        ),
        item(
          'b190000d-0000-4000-8000-000000000002',
          'Backup verification completed',
          'resilience',
        ),
      ],
      loadedAt: now,
    );
  }
}
