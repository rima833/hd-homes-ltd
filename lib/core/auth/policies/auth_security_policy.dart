/// Enterprise session / password / lockout policies for HD Homes IAM.
abstract final class AuthSecurityPolicy {
  /// Soft inactivity timeout before warning the user (client-side).
  static const Duration inactivityWarning = Duration(minutes: 25);

  /// Soft inactivity timeout before forced client logout (client-side).
  static const Duration inactivityTimeout = Duration(minutes: 30);

  /// Refresh access token this long before JWT expiry.
  static const Duration refreshSkew = Duration(minutes: 2);

  /// Failed login attempts before showing lockout messaging.
  static const int maxFailedAttempts = 5;

  /// Client-side lockout window after repeated failures.
  static const Duration lockoutDuration = Duration(minutes: 15);

  /// Minimum password length (enterprise).
  static const int passwordMinLength = 8;

  static bool requiresSpecialCharacter = true;
  static bool requiresUppercase = true;
  static bool requiresLowercase = true;
  static bool requiresNumber = true;
}
