/// Security / audit event types for the Identity Platform.
enum SecurityEventType {
  loginSuccess,
  loginFailure,
  logout,
  passwordChanged,
  passwordResetRequested,
  emailVerified,
  emailVerificationSent,
  phoneVerified,
  otpRequested,
  otpFailed,
  roleUpdated,
  permissionChanged,
  mfaEnabled,
  mfaDisabled,
  profileUpdated,
  sessionRevoked,
  suspiciousLogin,
  accountSuspended,
  permissionDenied,
}

class SecurityEvent {
  const SecurityEvent({
    required this.type,
    required this.timestamp,
    this.userId,
    this.email,
    this.deviceLabel,
    this.userAgent,
    this.metadata = const {},
  });

  final SecurityEventType type;
  final DateTime timestamp;
  final String? userId;
  final String? email;
  final String? deviceLabel;
  final String? userAgent;
  final Map<String, dynamic> metadata;

  String get actionSlug => switch (type) {
        SecurityEventType.loginSuccess => 'login',
        SecurityEventType.loginFailure => 'login_failed',
        SecurityEventType.logout => 'logout',
        SecurityEventType.passwordChanged => 'password_changed',
        SecurityEventType.passwordResetRequested => 'password_reset_requested',
        SecurityEventType.emailVerified => 'email_verified',
        SecurityEventType.emailVerificationSent => 'email_verification_sent',
        SecurityEventType.phoneVerified => 'phone_verified',
        SecurityEventType.otpRequested => 'otp_requested',
        SecurityEventType.otpFailed => 'otp_verify_failed',
        SecurityEventType.roleUpdated => 'role_updated',
        SecurityEventType.permissionChanged => 'permission_changed',
        SecurityEventType.mfaEnabled => 'mfa_enabled',
        SecurityEventType.mfaDisabled => 'mfa_disabled',
        SecurityEventType.profileUpdated => 'profile_updated',
        SecurityEventType.sessionRevoked => 'session_revoked',
        SecurityEventType.suspiciousLogin => 'suspicious_login',
        SecurityEventType.accountSuspended => 'account_suspended',
        SecurityEventType.permissionDenied => 'permission_denied',
      };
}
