import 'package:flutter/foundation.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/login_models.dart';
import 'package:hdhomesproject/features/authentication/domain/repositories/session_repository.dart';
import 'package:hdhomesproject/features/authentication/domain/services/device_fingerprint_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SessionRepositoryImpl implements SessionRepository {
  SessionRepositoryImpl({
    required SupabaseClient client,
    required DeviceFingerprintService fingerprint,
  })  : _client = client,
        _fingerprint = fingerprint;

  final SupabaseClient _client;
  final DeviceFingerprintService _fingerprint;

  @override
  Future<List<ActiveSession>> listSessions() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];
    try {
      final rows = await _client
          .from('user_sessions')
          .select('id, started_at, last_seen_at, user_agent, is_current, revoked_at')
          .eq('user_id', userId)
          .eq('is_deleted', false)
          .order('last_seen_at', ascending: false);
      return (rows as List)
          .map((raw) {
            final row = Map<String, dynamic>.from(raw as Map);
            return ActiveSession(
              id: row['id'] as String,
              startedAt: DateTime.parse(row['started_at'] as String),
              lastSeenAt: DateTime.parse(row['last_seen_at'] as String),
              userAgent: row['user_agent'] as String?,
              isCurrent: row['is_current'] as bool? ?? false,
              revokedAt: row['revoked_at'] != null
                  ? DateTime.parse(row['revoked_at'] as String)
                  : null,
            );
          })
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> revokeSession(String sessionId) async {
    try {
      await _client.from('user_sessions').update({
        'revoked_at': DateTime.now().toUtc().toIso8601String(),
        'revoke_reason': 'user_revoked',
        'is_current': false,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', sessionId);
    } catch (_) {}
  }

  @override
  Future<void> revokeOtherSessions() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _client.from('user_sessions').update({
        'revoked_at': DateTime.now().toUtc().toIso8601String(),
        'revoke_reason': 'user_revoked_others',
        'is_current': false,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('user_id', userId).eq('is_current', false).isFilter('revoked_at', null);
    } catch (_) {}
  }

  @override
  Future<List<TrustedDevice>> listDevices() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];
    try {
      final rows = await _client
          .from('trusted_devices')
          .select(
            'id, device_fingerprint, device_name, browser, operating_system, '
            'last_activity_at, is_trusted',
          )
          .eq('user_id', userId)
          .eq('is_deleted', false)
          .isFilter('revoked_at', null)
          .order('last_activity_at', ascending: false);
      return (rows as List)
          .map((raw) {
            final row = Map<String, dynamic>.from(raw as Map);
            return TrustedDevice(
              id: row['id'] as String,
              fingerprint: row['device_fingerprint'] as String,
              deviceName: row['device_name'] as String?,
              browser: row['browser'] as String?,
              operatingSystem: row['operating_system'] as String?,
              lastActivityAt: row['last_activity_at'] != null
                  ? DateTime.parse(row['last_activity_at'] as String)
                  : null,
              isTrusted: row['is_trusted'] as bool? ?? false,
            );
          })
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> revokeDevice(String deviceId) async {
    try {
      await _client.from('trusted_devices').update({
        'revoked_at': DateTime.now().toUtc().toIso8601String(),
        'is_trusted': false,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', deviceId);
    } catch (_) {}
  }

  @override
  Future<String?> registerCurrentSession({
    required String userId,
    String? authSessionId,
  }) async {
    try {
      final fp = await _fingerprint.fingerprint();
      // Prefer RPC when Part 3 migration is applied; fall back to direct upserts.
      try {
        final result = await _client.rpc(
          'register_login_session',
          params: {
            'p_user_id': userId,
            'p_device_fingerprint': fp,
            'p_device_name': _fingerprint.deviceLabel,
            'p_browser': _fingerprint.browserLabel,
            'p_operating_system':
                kIsWeb ? 'web' : defaultTargetPlatform.name,
            'p_user_agent': _fingerprint.userAgentSummary,
            'p_auth_session_id': authSessionId,
          },
        );
        if (result is String) return result;
        if (result is Map && result['session_id'] != null) {
          return result['session_id'] as String;
        }
      } catch (_) {
        // RPC may not exist until migration is applied.
      }

      final device = await _client
          .from('trusted_devices')
          .upsert({
            'user_id': userId,
            'device_fingerprint': fp,
            'device_name': _fingerprint.deviceLabel,
            'browser': _fingerprint.browserLabel,
            'operating_system': kIsWeb ? 'web' : defaultTargetPlatform.name,
            'last_activity_at': DateTime.now().toUtc().toIso8601String(),
          }, onConflict: 'user_id,device_fingerprint')
          .select('id')
          .maybeSingle();

      await _client.from('user_sessions').update({
        'is_current': false,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('user_id', userId).eq('is_current', true);

      final session = await _client
          .from('user_sessions')
          .insert({
            'user_id': userId,
            'device_id': device?['id'],
            'auth_session_id': authSessionId,
            'user_agent': _fingerprint.userAgentSummary,
            'is_current': true,
            'last_seen_at': DateTime.now().toUtc().toIso8601String(),
          })
          .select('id')
          .maybeSingle();

      return session?['id'] as String?;
    } catch (_) {
      return null;
    }
  }
}
