/// Real platform health signals for Settings Overview.
///
/// Status values: `connected`, `warning`, `error`, `not_configured`, `unknown`.
/// Never invent "connected" without evidence from Supabase / client state.
class PlatformHealthSnapshot {
  const PlatformHealthSnapshot({
    required this.checkedAt,
    required this.checks,
    this.lastSettingsUpdateAt,
    this.lastSettingsUpdateBy,
    this.lastSettingsAuditAt,
    this.raw = const {},
  });

  final DateTime checkedAt;
  final Map<String, PlatformHealthCheck> checks;
  final DateTime? lastSettingsUpdateAt;
  final String? lastSettingsUpdateBy;
  final DateTime? lastSettingsAuditAt;
  final Map<String, dynamic> raw;

  List<PlatformHealthCheck> get issues => checks.values
      .where(
        (c) =>
            c.status == PlatformHealthStatus.warning ||
            c.status == PlatformHealthStatus.error ||
            c.status == PlatformHealthStatus.notConfigured,
      )
      .toList(growable: false);

  factory PlatformHealthSnapshot.fromJson(
    Map<String, dynamic> json, {
    required PlatformHealthStatus realtimeStatus,
    String? realtimeNotes,
    required PlatformHealthStatus clientSupabaseStatus,
    String? clientSupabaseNotes,
  }) {
    PlatformHealthCheck parse(
      String id,
      String label,
      Map<String, dynamic>? node, {
      PlatformHealthStatus? overrideStatus,
      String? overrideNotes,
    }) {
      final status = overrideStatus ??
          PlatformHealthStatus.parse('${node?['status'] ?? 'unknown'}');
      final notes = overrideNotes ?? node?['notes']?.toString();
      return PlatformHealthCheck(
        id: id,
        label: label,
        status: status,
        notes: notes,
        metrics: {
          for (final e in (node ?? const {}).entries)
            if (e.key != 'status' && e.key != 'notes') e.key: e.value,
        },
      );
    }

    final database = _asMap(json['database']);
    final auth = _asMap(json['authentication']);
    final cloudinary = _asMap(json['cloudinary']);
    final seo = _asMap(json['seo']);
    final last = _asMap(json['last_settings_update']);

    return PlatformHealthSnapshot(
      checkedAt:
          DateTime.tryParse('${json['checked_at'] ?? ''}') ?? DateTime.now(),
      lastSettingsUpdateAt: DateTime.tryParse('${last['at'] ?? ''}'),
      lastSettingsUpdateBy: last['by']?.toString(),
      lastSettingsAuditAt:
          DateTime.tryParse('${json['last_settings_audit_at'] ?? ''}'),
      raw: json,
      checks: {
        'database': parse('database', 'Database', database),
        'authentication': parse('authentication', 'Authentication', auth),
        'supabase_client': PlatformHealthCheck(
          id: 'supabase_client',
          label: 'Supabase client',
          status: clientSupabaseStatus,
          notes: clientSupabaseNotes,
        ),
        'realtime': PlatformHealthCheck(
          id: 'realtime',
          label: 'Realtime',
          status: realtimeStatus,
          notes: realtimeNotes,
        ),
        'cloudinary': parse('cloudinary', 'Cloudinary media', cloudinary),
        'seo': parse('seo', 'SEO metadata', seo),
      },
    );
  }

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }
}

enum PlatformHealthStatus {
  connected,
  warning,
  error,
  notConfigured,
  unknown;

  static PlatformHealthStatus parse(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'connected':
        return PlatformHealthStatus.connected;
      case 'warning':
        return PlatformHealthStatus.warning;
      case 'error':
        return PlatformHealthStatus.error;
      case 'not_configured':
      case 'not-configured':
        return PlatformHealthStatus.notConfigured;
      default:
        return PlatformHealthStatus.unknown;
    }
  }

  String get label => switch (this) {
        PlatformHealthStatus.connected => 'CONNECTED',
        PlatformHealthStatus.warning => 'WARNING',
        PlatformHealthStatus.error => 'ERROR',
        PlatformHealthStatus.notConfigured => 'NOT CONFIGURED',
        PlatformHealthStatus.unknown => 'UNKNOWN',
      };
}

class PlatformHealthCheck {
  const PlatformHealthCheck({
    required this.id,
    required this.label,
    required this.status,
    this.notes,
    this.metrics = const {},
  });

  final String id;
  final String label;
  final PlatformHealthStatus status;
  final String? notes;
  final Map<String, dynamic> metrics;
}
