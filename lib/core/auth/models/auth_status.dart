/// Authentication lifecycle states for the HD Homes Identity Platform.
enum AuthStatus {
  /// No session — guest visitor.
  unauthenticated,

  /// Sign-in / profile resolution in progress.
  authenticating,

  /// Valid session with resolved profile and roles.
  authenticated,

  /// Signed up but email not verified.
  emailPending,

  /// Profile exists but account awaits verification / onboarding.
  verificationPending,

  /// Admin suspended the account.
  suspended,

  /// Account marked inactive.
  inactive,

  /// Soft-deleted / closed account.
  deleted,
}

/// Maps [profiles.account_status] (+ email confirmation) to [AuthStatus].
AuthStatus resolveAuthStatus({
  required bool hasSession,
  required bool isLoading,
  String? accountStatus,
  bool emailConfirmed = true,
}) {
  if (isLoading) return AuthStatus.authenticating;
  if (!hasSession) return AuthStatus.unauthenticated;
  if (!emailConfirmed) return AuthStatus.emailPending;

  return switch (accountStatus) {
    'suspended' => AuthStatus.suspended,
    'inactive' => AuthStatus.inactive,
    'deleted' => AuthStatus.deleted,
    'pending_verification' => AuthStatus.verificationPending,
    'active' => AuthStatus.authenticated,
    _ => AuthStatus.authenticated,
  };
}

extension AuthStatusX on AuthStatus {
  bool get canAccessProtectedRoutes =>
      this == AuthStatus.authenticated || this == AuthStatus.verificationPending;

  bool get isTerminalBlocked =>
      this == AuthStatus.suspended ||
      this == AuthStatus.inactive ||
      this == AuthStatus.deleted;

  String get userMessage => switch (this) {
        AuthStatus.unauthenticated => 'Please sign in to continue.',
        AuthStatus.authenticating => 'Verifying your session…',
        AuthStatus.authenticated => 'Signed in',
        AuthStatus.emailPending => 'Please verify your email to continue.',
        AuthStatus.verificationPending => 'Your account is pending verification.',
        AuthStatus.suspended => 'Your account has been suspended. Contact support.',
        AuthStatus.inactive => 'Your account is inactive. Contact support.',
        AuthStatus.deleted => 'This account is no longer available.',
      };
}
