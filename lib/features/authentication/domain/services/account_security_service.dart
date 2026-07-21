import 'package:flutter/foundation.dart';
import 'package:hdhomesproject/core/auth/models/security_event.dart';
import 'package:hdhomesproject/core/auth/policies/auth_security_policy.dart';
import 'package:hdhomesproject/core/auth/services/security_service.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/validators/email_validator.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/account_security_models.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/app_role.dart';
import 'package:hdhomesproject/features/authentication/domain/repositories/auth_repository.dart';
import 'package:hdhomesproject/features/authentication/domain/repositories/session_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Account security + password recovery orchestration.
class AccountSecurityService {
  AccountSecurityService({
    required AuthRepository? authRepository,
    required SecurityService security,
    SessionRepository? sessions,
    SupabaseClient? client,
  })  : _auth = authRepository,
        _security = security,
        _sessions = sessions,
        _client = client;

  final AuthRepository? _auth;
  final SecurityService _security;
  final SessionRepository? _sessions;
  final SupabaseClient? _client;

  int _resetRequestsToday = 0;
  DateTime? _resetDay;
  DateTime? _cooldownUntil;
  int _failedResetAttempts = 0;

  bool get isRecoveryLockedOut {
    return _security.isLockedOut;
  }

  Duration? get recoveryCooldownRemaining {
    final until = _cooldownUntil;
    if (until == null) return null;
    final rem = until.difference(DateTime.now());
    return rem.isNegative ? null : rem;
  }

  PasswordPolicy policyFor(AppRole? role) => PasswordPolicy.forRole(role);

  Future<void> requestPasswordReset(String email) async {
    final emailError = EmailValidator.validate(email);
    if (emailError != null) {
      throw ValidationException(emailError);
    }

    _rollDailyCounter();
    final now = DateTime.now();
    if (_cooldownUntil != null && now.isBefore(_cooldownUntil!)) {
      final secs = _cooldownUntil!.difference(now).inSeconds;
      throw AuthenticationException(
        'Please wait ${secs}s before requesting another reset email.',
      );
    }
    if (_resetRequestsToday >= PasswordRecoveryPolicy.maxDailyRequests) {
      _flagSuspicious(email, 'max_daily_reset_requests');
      throw const AuthenticationException(
        'Too many reset requests today. Try again tomorrow or contact support.',
      );
    }

    final auth = _auth;
    if (auth == null) {
      throw const AuthenticationException('Authentication is not configured.');
    }

    // Anti-enumeration: always report success-shaped outcome to the UI.
    try {
      await auth.resetPassword(email.trim());
    } catch (_) {
      // Swallow provider detail.
    }

    _resetRequestsToday++;
    _cooldownUntil = now.add(PasswordRecoveryPolicy.requestCooldown);
    await _persistResetRequest(email.trim());
    _emit(
      SecurityEventType.passwordResetRequested,
      email: email.trim(),
      metadata: {'action': AccountSecurityEventType.passwordResetRequested.name},
    );
  }

  Future<void> completePasswordReset({
    required String newPassword,
    required String confirmPassword,
    AppRole? role,
  }) async {
    final policy = policyFor(role);
    final error = policy.validate(newPassword);
    if (error != null) {
      _emit(
        SecurityEventType.passwordChanged,
        success: false,
        metadata: {
          'action': AccountSecurityEventType.passwordValidationFailed.name,
          'reason': error,
        },
      );
      throw ValidationException(error);
    }
    if (newPassword != confirmPassword) {
      throw const ValidationException('Passwords do not match');
    }

    final auth = _auth;
    final client = _client;
    if (auth == null || client == null) {
      throw const AuthenticationException('Authentication is not configured.');
    }

    try {
      await auth.updatePassword(newPassword);
    } catch (e) {
      _failedResetAttempts++;
      if (_failedResetAttempts >= PasswordRecoveryPolicy.maxFailedResetsBeforeFlag) {
        _flagSuspicious(null, 'repeated_failed_resets');
      }
      _emit(
        SecurityEventType.passwordChanged,
        success: false,
        metadata: {'action': AccountSecurityEventType.passwordResetFailed.name},
      );
      if (e is AppException) rethrow;
      throw const AuthenticationException(
        'Unable to update password. The reset link may have expired.',
      );
    }

    _failedResetAttempts = 0;
    await _revokeAllSessions();
    await _persistPasswordChange(reason: 'reset');
    _emit(
      SecurityEventType.passwordChanged,
      userId: client.auth.currentUser?.id,
      metadata: {'action': AccountSecurityEventType.passwordResetCompleted.name},
    );

    // Force re-login after recovery.
    await auth.signOut(everywhere: true);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
    bool revokeOtherSessions = true,
    AppRole? role,
  }) async {
    final policy = policyFor(role);
    final error = policy.validate(newPassword);
    if (error != null) throw ValidationException(error);
    if (newPassword != confirmPassword) {
      throw const ValidationException('Passwords do not match');
    }
    if (currentPassword == newPassword) {
      throw const ValidationException(
        'New password must be different from your current password.',
      );
    }

    final auth = _auth;
    final client = _client;
    final email = client?.auth.currentUser?.email;
    if (auth == null || client == null || email == null) {
      throw const AuthenticationException('Sign in to change your password.');
    }

    try {
      await auth.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
    } catch (e) {
      _emit(
        SecurityEventType.passwordChanged,
        success: false,
        userId: client.auth.currentUser?.id,
        metadata: {'action': AccountSecurityEventType.passwordChanged.name},
      );
      if (e is AppException) rethrow;
      throw const AuthenticationException(
        'Unable to change password. Check your current password and try again.',
      );
    }

    if (revokeOtherSessions) {
      await _sessions?.revokeOtherSessions();
      await auth.signOut(everywhere: true);
      // Re-sign-in locally so the user stays on this device.
      await auth.signInWithEmail(email: email, password: newPassword);
    }

    await _persistPasswordChange(reason: 'change');
    _emit(
      SecurityEventType.passwordChanged,
      userId: client.auth.currentUser?.id,
      email: email,
      metadata: {
        'action': AccountSecurityEventType.passwordChanged.name,
        'revoked_others': revokeOtherSessions,
      },
    );
  }

  List<SecurityRiskSignal> evaluateRiskSignals({
    required int recentFailedLogins,
    required int resetRequestsToday,
  }) {
    final signals = <SecurityRiskSignal>[];
    if (recentFailedLogins >= AuthSecurityPolicy.maxFailedAttempts) {
      signals.add(
        const SecurityRiskSignal(
          code: 'repeated_failed_logins',
          description: 'Multiple failed login attempts detected.',
        ),
      );
    }
    if (resetRequestsToday >= 3) {
      signals.add(
        const SecurityRiskSignal(
          code: 'frequent_reset_requests',
          description: 'Repeated password reset requests today.',
        ),
      );
    }
    return signals;
  }

  void _rollDailyCounter() {
    final today = DateTime.now();
    final day = _resetDay;
    if (day == null ||
        day.year != today.year ||
        day.month != today.month ||
        day.day != today.day) {
      _resetDay = today;
      _resetRequestsToday = 0;
    }
  }

  void _flagSuspicious(String? email, String reason) {
    _emit(
      SecurityEventType.suspiciousLogin,
      email: email,
      metadata: {
        'action': AccountSecurityEventType.suspiciousResetActivity.name,
        'reason': reason,
      },
    );
  }

  Future<void> _revokeAllSessions() async {
    try {
      await _sessions?.revokeOtherSessions();
    } catch (_) {}
    _emit(
      SecurityEventType.sessionRevoked,
      userId: _client?.auth.currentUser?.id,
      metadata: {'action': AccountSecurityEventType.sessionRevoked.name},
    );
  }

  Future<void> _persistResetRequest(String email) async {
    final client = _client;
    if (client == null) return;
    try {
      await client.from('password_reset_requests').insert({
        'email': email,
        'user_agent': kIsWeb ? 'web' : defaultTargetPlatform.name,
        'status': 'sent',
      });
    } catch (_) {}
  }

  Future<void> _persistPasswordChange({required String reason}) async {
    final client = _client;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) return;
    try {
      await client.from('password_change_history').insert({
        'user_id': userId,
        'reason': reason,
        'user_agent': kIsWeb ? 'web' : defaultTargetPlatform.name,
      });
    } catch (_) {}
  }

  void _emit(
    SecurityEventType type, {
    String? email,
    String? userId,
    bool success = true,
    Map<String, dynamic> metadata = const {},
  }) {
    _security.record(
      SecurityEvent(
        type: type,
        timestamp: DateTime.now(),
        email: email,
        userId: userId ?? _client?.auth.currentUser?.id,
        userAgent: kIsWeb ? 'web' : defaultTargetPlatform.name,
        metadata: {'success': success, ...metadata},
      ),
    );
  }
}
