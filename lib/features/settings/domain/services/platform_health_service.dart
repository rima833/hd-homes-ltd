import 'package:hdhomesproject/core/config/supabase_config.dart';
import 'package:hdhomesproject/features/settings/domain/entities/platform_health.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Loads real health signals for Settings Overview.
class PlatformHealthService {
  PlatformHealthService({
    SupabaseClient? client,
    this.realtimeSubscribed = false,
    this.realtimePending = false,
    this.realtimeDetail,
  }) : _client = client;

  final SupabaseClient? _client;

  /// Whether the settings Realtime channel is currently subscribed.
  final bool realtimeSubscribed;

  /// True while the channel is still joining, or waiting for a session.
  /// Pending is not a failure.
  final bool realtimePending;

  /// Subscribe error, or a short status note from the channel.
  final String? realtimeDetail;

  Future<PlatformHealthSnapshot> loadSnapshot() async {
    final clientConfigured = SupabaseConfig.isConfigured;
    final clientStatus = !clientConfigured
        ? PlatformHealthStatus.notConfigured
        : (_client == null
            ? PlatformHealthStatus.error
            : PlatformHealthStatus.connected);
    final clientNotes = !clientConfigured
        ? 'SUPABASE_URL / publishable key missing'
        : (_client == null
            ? 'Supabase client failed to initialize'
            : 'Client initialized');

    final realtimeStatus = !clientConfigured
        ? PlatformHealthStatus.notConfigured
        : realtimeSubscribed
            ? PlatformHealthStatus.connected
            : realtimePending
                ? PlatformHealthStatus.unknown
                : PlatformHealthStatus.warning;
    final realtimeNotes = realtimeSubscribed
        ? (realtimeDetail ?? 'app_settings channel subscribed')
        : realtimePending
            ? (realtimeDetail ?? 'Connecting to app_settings')
            : (realtimeDetail ??
                'Settings Realtime channel is not subscribed in this session');

    if (_client == null) {
      return PlatformHealthSnapshot(
        checkedAt: DateTime.now(),
        checks: {
          'supabase_client': PlatformHealthCheck(
            id: 'supabase_client',
            label: 'Supabase client',
            status: clientStatus,
            notes: clientNotes,
          ),
          'realtime': PlatformHealthCheck(
            id: 'realtime',
            label: 'Realtime',
            status: realtimeStatus,
            notes: realtimeNotes,
          ),
          'cloudinary': PlatformHealthCheck(
            id: 'cloudinary',
            label: 'Cloudinary',
            status: PlatformHealthStatus.notConfigured,
            notes:
                'Cloudinary uploads use the Edge Function. A client cloud name is optional.',
          ),
        },
      );
    }

    final raw = await _client.rpc('platform_health_snapshot');
    final map = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};

    final snapshot = PlatformHealthSnapshot.fromJson(
      map,
      realtimeStatus: realtimeStatus,
      realtimeNotes: realtimeNotes,
      clientSupabaseStatus: clientStatus,
      clientSupabaseNotes: clientNotes,
    );

    return snapshot;
  }
}
