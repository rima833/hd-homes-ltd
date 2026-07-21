import 'package:hdhomesproject/features/authentication/domain/entities/app_role.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/user_profile.dart';

/// Supported authentication methods (current + future-ready).
enum LoginMethod {
  emailPassword,
  phonePassword,
  magicLink,
  google,
  apple,
  microsoft,
}

extension LoginMethodX on LoginMethod {
  String get id => switch (this) {
        LoginMethod.emailPassword => 'email_password',
        LoginMethod.phonePassword => 'phone_password',
        LoginMethod.magicLink => 'magic_link',
        LoginMethod.google => 'google',
        LoginMethod.apple => 'apple',
        LoginMethod.microsoft => 'microsoft',
      };

  String get label => switch (this) {
        LoginMethod.emailPassword => 'Email',
        LoginMethod.phonePassword => 'Phone',
        LoginMethod.magicLink => 'Magic link',
        LoginMethod.google => 'Google',
        LoginMethod.apple => 'Apple',
        LoginMethod.microsoft => 'Microsoft',
      };

  /// Phase 1 enabled methods.
  bool get enabled => this == LoginMethod.emailPassword;

  bool get isSocial => switch (this) {
        LoginMethod.google || LoginMethod.apple || LoginMethod.microsoft => true,
        _ => false,
      };
}

/// Credentials for email/password sign-in.
class LoginCredentials {
  const LoginCredentials({
    required this.email,
    required this.password,
    this.rememberMe = false,
    this.method = LoginMethod.emailPassword,
  });

  final String email;
  final String password;
  final bool rememberMe;
  final LoginMethod method;
}

/// Outcome of a successful authentication attempt.
class LoginResult {
  const LoginResult({
    required this.profile,
    required this.destination,
    this.needsEmailVerification = false,
    this.needsMfaChallenge = false,
    this.needsMfaSetup = false,
    this.sessionId,
  });

  final UserProfile profile;
  final String destination;
  final bool needsEmailVerification;
  final bool needsMfaChallenge;
  final bool needsMfaSetup;
  final String? sessionId;
}

/// Active application session row (maps to `user_sessions`).
class ActiveSession {
  const ActiveSession({
    required this.id,
    required this.startedAt,
    required this.lastSeenAt,
    this.userAgent,
    this.deviceName,
    this.isCurrent = false,
    this.revokedAt,
  });

  final String id;
  final DateTime startedAt;
  final DateTime lastSeenAt;
  final String? userAgent;
  final String? deviceName;
  final bool isCurrent;
  final DateTime? revokedAt;

  bool get isActive => revokedAt == null;
}

/// Trusted / known device (maps to `trusted_devices`).
class TrustedDevice {
  const TrustedDevice({
    required this.id,
    required this.fingerprint,
    this.deviceName,
    this.browser,
    this.operatingSystem,
    this.lastActivityAt,
    this.isTrusted = false,
  });

  final String id;
  final String fingerprint;
  final String? deviceName;
  final String? browser;
  final String? operatingSystem;
  final DateTime? lastActivityAt;
  final bool isTrusted;
}

/// Context passed to Smart Login Router™ after authentication.
class SmartLoginContext {
  const SmartLoginContext({
    required this.profile,
    this.redirectPath,
    this.permissions = const {},
    this.profileComplete = true,
    this.pendingKyc = false,
  });

  final UserProfile profile;
  final String? redirectPath;
  final Set<String> permissions;
  final bool profileComplete;
  final bool pendingKyc;

  AppRole? get primaryRole => profile.primaryRole;
}
