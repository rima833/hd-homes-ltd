import 'package:hdhomesproject/core/auth/policies/auth_security_policy.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/app_role.dart';
import 'package:hdhomesproject/features/authentication/domain/services/registration_validator.dart';

/// Adaptive Password Policies — admin-configurable (DB-backed later).
class PasswordPolicy {
  const PasswordPolicy({
    this.minLength = 8,
    this.maxLength = 128,
    this.requireUppercase = true,
    this.requireLowercase = true,
    this.requireNumber = true,
    this.requireSpecial = true,
    this.historyLimit = 5,
    this.preventReuse = false,
    this.expiryDays,
  });

  final int minLength;
  final int maxLength;
  final bool requireUppercase;
  final bool requireLowercase;
  final bool requireNumber;
  final bool requireSpecial;
  /// Future-ready: number of previous passwords to block.
  final int historyLimit;
  final bool preventReuse;
  final int? expiryDays;

  static const standard = PasswordPolicy();

  static const adminStrict = PasswordPolicy(
    minLength: 12,
    preventReuse: true,
    historyLimit: 5,
  );

  static PasswordPolicy forRole(AppRole? role) {
    return switch (role) {
      AppRole.superAdmin || AppRole.admin => adminStrict,
      _ => standard,
    };
  }

  String? validate(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < minLength) {
      return 'Password must be at least $minLength characters';
    }
    if (value.length > maxLength) {
      return 'Password must be at most $maxLength characters';
    }
    if (requireUppercase && !value.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }
    if (requireLowercase && !value.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter';
    }
    if (requireNumber && !value.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }
    if (requireSpecial &&
        !value.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=\[\]\\;/`~]'))) {
      return 'Password must contain at least one special character';
    }
    return null;
  }

  Map<String, bool> checklist(String password) => {
        'At least $minLength characters': password.length >= minLength,
        if (maxLength < 256) 'At most $maxLength characters': password.length <= maxLength,
        'Uppercase letter': RegExp(r'[A-Z]').hasMatch(password),
        'Lowercase letter': RegExp(r'[a-z]').hasMatch(password),
        'Number': RegExp(r'[0-9]').hasMatch(password),
        'Special character':
            RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=\[\]\\;/`~]').hasMatch(password),
      };
}

/// Aligns [AuthSecurityPolicy] defaults with adaptive catalog.
abstract final class AdaptivePasswordPolicyBridge {
  static void applyToAuthSecurityPolicy(PasswordPolicy policy) {
    AuthSecurityPolicy.requiresUppercase = policy.requireUppercase;
    AuthSecurityPolicy.requiresLowercase = policy.requireLowercase;
    AuthSecurityPolicy.requiresNumber = policy.requireNumber;
    AuthSecurityPolicy.requiresSpecialCharacter = policy.requireSpecial;
  }
}

/// Password recovery / security event types for audit.
enum AccountSecurityEventType {
  passwordResetRequested,
  passwordResetCompleted,
  passwordResetFailed,
  passwordChanged,
  passwordValidationFailed,
  suspiciousResetActivity,
  sessionRevoked,
  deviceRemoved,
  lockoutTriggered,
}

/// Rate-limit policy for recovery requests.
abstract final class PasswordRecoveryPolicy {
  static const Duration requestCooldown = Duration(seconds: 60);
  static const int maxDailyRequests = 5;
  static const int maxFailedResetsBeforeFlag = 5;
  static const Duration lockoutDuration = Duration(minutes: 15);
}

/// Security Health Dashboard™ score inputs.
class SecurityHealthSnapshot {
  const SecurityHealthSnapshot({
    required this.score,
    required this.passwordStrength,
    required this.emailVerified,
    required this.phoneVerified,
    required this.mfaEnabled,
    required this.activeSessionCount,
    required this.trustedDeviceCount,
    required this.recommendations,
  });

  final int score;
  final PasswordStrength passwordStrength;
  final bool emailVerified;
  final bool phoneVerified;
  final bool mfaEnabled;
  final int activeSessionCount;
  final int trustedDeviceCount;
  final List<String> recommendations;

  static SecurityHealthSnapshot compute({
    required PasswordStrength passwordStrength,
    required bool emailVerified,
    required bool phoneVerified,
    bool mfaEnabled = false,
    int activeSessionCount = 0,
    int trustedDeviceCount = 0,
  }) {
    var score = 0;
    final recommendations = <String>[];

    score += switch (passwordStrength) {
      PasswordStrength.excellent => 30,
      PasswordStrength.strong => 25,
      PasswordStrength.good => 18,
      PasswordStrength.fair => 10,
      PasswordStrength.weak || PasswordStrength.empty => 0,
    };
    if (passwordStrength == PasswordStrength.weak ||
        passwordStrength == PasswordStrength.empty) {
      recommendations.add('Choose a stronger password.');
    }

    if (emailVerified) {
      score += 25;
    } else {
      recommendations.add('Verify your email address.');
    }

    if (phoneVerified) {
      score += 20;
    } else {
      recommendations.add('Add and verify a phone number.');
    }

    if (mfaEnabled) {
      score += 25;
    } else {
      recommendations.add('Enable multi-factor authentication when available.');
    }

    if (activeSessionCount > 5) {
      recommendations.add('Review and end unused active sessions.');
      score = (score - 5).clamp(0, 100);
    }

    if (recommendations.isEmpty) {
      recommendations.add('Your account security looks healthy.');
    }

    return SecurityHealthSnapshot(
      score: score.clamp(0, 100),
      passwordStrength: passwordStrength,
      emailVerified: emailVerified,
      phoneVerified: phoneVerified,
      mfaEnabled: mfaEnabled,
      activeSessionCount: activeSessionCount,
      trustedDeviceCount: trustedDeviceCount,
      recommendations: recommendations,
    );
  }
}

/// Intelligent Risk Detection signals (client-side flags for admin review).
class SecurityRiskSignal {
  const SecurityRiskSignal({
    required this.code,
    required this.description,
    this.severity = 'warning',
  });

  final String code;
  final String description;
  final String severity;
}
