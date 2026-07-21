import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hdhomesproject/core/auth/models/security_event.dart';
import 'package:hdhomesproject/core/auth/policies/auth_security_policy.dart';
import 'package:hdhomesproject/core/utils/app_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Adaptive Security Monitoring — lockout, audit trail, suspicious activity flags.
class SecurityService {
  SecurityService(this._client);

  final SupabaseClient? _client;

  int _failedAttempts = 0;
  DateTime? _lockoutUntil;
  String? _lastFailedEmail;
  DateTime? _lastSuccessAt;

  final List<SecurityEvent> _localEvents = [];

  List<SecurityEvent> get recentEvents => List.unmodifiable(_localEvents);

  int get failedAttemptCount => _failedAttempts;

  bool get isLockedOut {
    final until = _lockoutUntil;
    if (until == null) return false;
    if (DateTime.now().isAfter(until)) {
      _lockoutUntil = null;
      _failedAttempts = 0;
      return false;
    }
    return true;
  }

  Duration? get lockoutRemaining {
    final until = _lockoutUntil;
    if (until == null) return null;
    final remaining = until.difference(DateTime.now());
    return remaining.isNegative ? null : remaining;
  }

  /// Progressive delay before allowing another attempt (client UX).
  Duration progressiveDelay() {
    if (_failedAttempts <= 1) return Duration.zero;
    if (_failedAttempts == 2) return const Duration(seconds: 1);
    if (_failedAttempts == 3) return const Duration(seconds: 2);
    if (_failedAttempts == 4) return const Duration(seconds: 4);
    return const Duration(seconds: 8);
  }

  void recordFailedLogin({String? email, String? reason}) {
    _failedAttempts++;
    _lastFailedEmail = email;
    final event = SecurityEvent(
      type: SecurityEventType.loginFailure,
      timestamp: DateTime.now(),
      email: email,
      userAgent: kIsWeb ? 'web' : defaultTargetPlatform.name,
      metadata: {
        'attempt': _failedAttempts,
        'reason': ?reason,
      },
    );
    _emit(event);

    if (_failedAttempts >= AuthSecurityPolicy.maxFailedAttempts) {
      _lockoutUntil = DateTime.now().add(AuthSecurityPolicy.lockoutDuration);
      _emit(
        SecurityEvent(
          type: SecurityEventType.suspiciousLogin,
          timestamp: DateTime.now(),
          email: email,
          metadata: {
            'reason': 'max_failed_attempts',
            'attempts': _failedAttempts,
          },
        ),
      );
    }
  }

  void recordSuccessfulLogin({String? userId, String? email}) {
    final previousSuccess = _lastSuccessAt;
    _failedAttempts = 0;
    _lockoutUntil = null;
    _lastSuccessAt = DateTime.now();
    _emit(
      SecurityEvent(
        type: SecurityEventType.loginSuccess,
        timestamp: DateTime.now(),
        userId: userId,
        email: email,
        userAgent: kIsWeb ? 'web' : defaultTargetPlatform.name,
        metadata: {
          if (previousSuccess != null)
            'seconds_since_last':
                DateTime.now().difference(previousSuccess).inSeconds,
          if (_lastFailedEmail != null && _lastFailedEmail != email)
            'prior_failed_email': _lastFailedEmail,
        },
      ),
    );
    _lastFailedEmail = null;
  }

  void recordLogout({String? userId}) {
    _emit(
      SecurityEvent(
        type: SecurityEventType.logout,
        timestamp: DateTime.now(),
        userId: userId,
      ),
    );
  }

  void record(SecurityEvent event) => _emit(event);

  void _emit(SecurityEvent event) {
    _localEvents.insert(0, event);
    if (_localEvents.length > 100) {
      _localEvents.removeRange(100, _localEvents.length);
    }
    AppLogger.info('SecurityEvent: ${event.actionSlug}');
    unawaited(_persist(event));
  }

  Future<void> _persist(SecurityEvent event) async {
    final client = _client;
    if (client == null) return;

    // Prefer SECURITY DEFINER RPC when Part 3 migration is applied.
    try {
      await client.rpc(
        'record_auth_event',
        params: {
          'p_user_id': event.userId,
          'p_email': event.email,
          'p_action': event.actionSlug,
          'p_success': event.type != SecurityEventType.loginFailure,
          'p_user_agent': event.userAgent,
          'p_metadata': event.metadata,
          'p_severity': event.type == SecurityEventType.suspiciousLogin
              ? 'warning'
              : (event.type == SecurityEventType.loginFailure ? 'info' : 'info'),
        },
      );
      return;
    } catch (_) {
      // Fall through to best-effort direct inserts.
    }

    try {
      await client.from('authentication_logs').insert({
        'user_id': event.userId,
        'action': event.actionSlug,
        'success': event.type != SecurityEventType.loginFailure,
        'user_agent': event.userAgent,
        'metadata': {
          ...event.metadata,
          if (event.email != null) 'email': event.email,
        },
      });
    } catch (_) {}

    try {
      if (event.type == SecurityEventType.loginSuccess ||
          event.type == SecurityEventType.loginFailure) {
        await client.from('login_history').insert({
          'user_id': event.userId,
          'email': event.email,
          'success': event.type == SecurityEventType.loginSuccess,
          'failure_reason': event.type == SecurityEventType.loginFailure
              ? (event.metadata['reason'] as String? ?? 'invalid_credentials')
              : null,
          'user_agent': event.userAgent,
          'metadata': event.metadata,
        });
      }
    } catch (_) {}

    try {
      if (event.type == SecurityEventType.suspiciousLogin ||
          event.type == SecurityEventType.accountSuspended) {
        await client.from('security_events').insert({
          'user_id': event.userId,
          'event_type': event.actionSlug,
          'severity': 'warning',
          'description': event.actionSlug,
          'user_agent': event.userAgent,
          'metadata': {
            ...event.metadata,
            if (event.email != null) 'email': event.email,
          },
        });
      }
    } catch (_) {}
  }
}
