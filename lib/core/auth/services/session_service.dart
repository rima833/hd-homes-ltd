import 'dart:async';

import 'package:hdhomesproject/core/auth/models/auth_session_snapshot.dart';
import 'package:hdhomesproject/core/auth/policies/auth_security_policy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Adaptive session intelligence — refresh skew, inactivity, activity tracking.
class SessionService {
  SessionService({
    required GoTrueClient auth,
    this.onInactivityWarning,
    this.onInactivityTimeout,
  }) : _auth = auth;

  final GoTrueClient _auth;
  void Function()? onInactivityWarning;
  void Function()? onInactivityTimeout;

  Timer? _inactivityTimer;
  Timer? _warningTimer;
  DateTime _lastActivity = DateTime.now();
  bool _warningFired = false;

  DateTime get lastActivityAt => _lastActivity;

  Session? get currentSession => _auth.currentSession;

  bool get isSessionValid {
    final session = currentSession;
    if (session == null) return false;
    final expiresAt = session.expiresAt;
    if (expiresAt == null) return true;
    return DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000).isAfter(DateTime.now());
  }

  /// Call on user interaction to reset inactivity clocks.
  void recordActivity() {
    _lastActivity = DateTime.now();
    _warningFired = false;
    _restartInactivityTimers();
  }

  void startMonitoring() {
    recordActivity();
  }

  void stopMonitoring() {
    _inactivityTimer?.cancel();
    _warningTimer?.cancel();
    _inactivityTimer = null;
    _warningTimer = null;
  }

  void _restartInactivityTimers() {
    _warningTimer?.cancel();
    _inactivityTimer?.cancel();

    _warningTimer = Timer(AuthSecurityPolicy.inactivityWarning, () {
      if (!_warningFired) {
        _warningFired = true;
        onInactivityWarning?.call();
      }
    });

    _inactivityTimer = Timer(AuthSecurityPolicy.inactivityTimeout, () {
      onInactivityTimeout?.call();
    });
  }

  /// Refresh if the access token expires within [AuthSecurityPolicy.refreshSkew].
  Future<AuthSessionSnapshot?> refreshIfNeeded(AuthSessionSnapshot snapshot) async {
    final session = currentSession;
    if (session == null) return null;

    final expiresAtSec = session.expiresAt;
    if (expiresAtSec == null) return snapshot;

    final expiresAt = DateTime.fromMillisecondsSinceEpoch(expiresAtSec * 1000);
    final skewDeadline = DateTime.now().add(AuthSecurityPolicy.refreshSkew);
    if (expiresAt.isAfter(skewDeadline)) {
      return snapshot.copyWith(accessTokenExpiresAt: expiresAt, lastActivityAt: _lastActivity);
    }

    final response = await _auth.refreshSession();
    final refreshed = response.session;
    if (refreshed == null) return snapshot;

    final newExpiry = refreshed.expiresAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(refreshed.expiresAt! * 1000);

    return snapshot.copyWith(
      accessTokenExpiresAt: newExpiry,
      lastActivityAt: _lastActivity,
      sessionId: refreshed.accessToken.isNotEmpty ? refreshed.accessToken.hashCode.toString() : snapshot.sessionId,
    );
  }

  Future<void> signOut({SignOutScope scope = SignOutScope.local}) {
    stopMonitoring();
    return _auth.signOut(scope: scope);
  }
}
