import 'package:hdhomesproject/features/authentication/domain/entities/app_role.dart';

/// MFA factor kinds (current + future-ready).
enum MfaMethodKind {
  totp,
  backupCode,
  emailOtp,
  smsOtp,
  passkey,
  webAuthn,
  biometric,
  hardwareKey,
  sso,
}

extension MfaMethodKindX on MfaMethodKind {
  String get id => name;

  String get label => switch (this) {
        MfaMethodKind.totp => 'Authenticator app',
        MfaMethodKind.backupCode => 'Backup code',
        MfaMethodKind.emailOtp => 'Email code',
        MfaMethodKind.smsOtp => 'SMS code',
        MfaMethodKind.passkey => 'Passkey',
        MfaMethodKind.webAuthn => 'Security key',
        MfaMethodKind.biometric => 'Biometrics',
        MfaMethodKind.hardwareKey => 'Hardware key',
        MfaMethodKind.sso => 'Enterprise SSO',
      };

  bool get enabledInPhase1 =>
      this == MfaMethodKind.totp ||
      this == MfaMethodKind.backupCode ||
      this == MfaMethodKind.emailOtp ||
      this == MfaMethodKind.smsOtp;
}

/// How strongly MFA is enforced for a role.
enum MfaRequirement {
  optional,
  recommended,
  required,
  mandatory,
}

/// MFA policy — admin-editable via DB when migration applied.
class MfaPolicy {
  const MfaPolicy({
    required this.role,
    this.requirement = MfaRequirement.optional,
    this.allowEmailFallback = true,
    this.allowSms = false,
    this.trustDurationDays = 30,
    this.maxTrustedDevices = 5,
    this.stepUpSensitiveActions = true,
  });

  final AppRole role;
  final MfaRequirement requirement;
  final bool allowEmailFallback;
  final bool allowSms;
  final int trustDurationDays;
  final int maxTrustedDevices;
  final bool stepUpSensitiveActions;

  bool get isEnforced =>
      requirement == MfaRequirement.required ||
      requirement == MfaRequirement.mandatory;

  bool get isMandatory => requirement == MfaRequirement.mandatory;
}

abstract final class MfaPolicyCatalog {
  static const client = MfaPolicy(
    role: AppRole.client,
    requirement: MfaRequirement.optional,
  );

  static const investor = MfaPolicy(
    role: AppRole.investor,
    requirement: MfaRequirement.recommended,
  );

  static const staff = MfaPolicy(
    role: AppRole.salesTeam,
    requirement: MfaRequirement.required,
    allowEmailFallback: false,
  );

  static const superAdmin = MfaPolicy(
    role: AppRole.superAdmin,
    requirement: MfaRequirement.mandatory,
    allowEmailFallback: false,
    trustDurationDays: 14,
    maxTrustedDevices: 3,
  );

  static MfaPolicy forRole(AppRole? role) => switch (role) {
        AppRole.investor => investor,
        AppRole.superAdmin => superAdmin,
        AppRole.admin ||
        AppRole.finance ||
        AppRole.salesTeam ||
        AppRole.marketing ||
        AppRole.constructionManager =>
          staff,
        AppRole.client || null => client,
      };
}

/// High-risk actions that may require step-up MFA.
enum StepUpAction {
  changeEmail,
  changePassword,
  deleteAccount,
  createAdmin,
  modifyPermissions,
  exportSensitiveData,
  editPaymentDetails,
  withdrawInvestment,
}

/// Enrollment draft while setting up TOTP.
class MfaEnrollmentDraft {
  const MfaEnrollmentDraft({
    required this.factorId,
    required this.secret,
    required this.uri,
    this.qrCodeSvg,
    this.friendlyName = 'Authenticator',
  });

  final String factorId;
  final String secret;
  final String uri;
  final String? qrCodeSvg;
  final String friendlyName;
}

/// Snapshot of MFA state for UI / Security Readiness Score.
class MfaStatusSnapshot {
  const MfaStatusSnapshot({
    this.enabled = false,
    this.totpEnrolled = false,
    this.backupCodesRemaining = 0,
    this.trustedDeviceCount = 0,
    this.aalSatisfied = true,
    this.policy = MfaPolicyCatalog.client,
    this.factorIds = const [],
  });

  final bool enabled;
  final bool totpEnrolled;
  final int backupCodesRemaining;
  final int trustedDeviceCount;
  final bool aalSatisfied;
  final MfaPolicy policy;
  final List<String> factorIds;

  bool get needsSetup => policy.isEnforced && !enabled;

  bool get needsChallenge => enabled && !aalSatisfied;
}

/// Adaptive Security Engine™ decision.
class AdaptiveSecurityDecision {
  const AdaptiveSecurityDecision({
    required this.requireMfa,
    required this.reason,
    this.allowTrustedDeviceSkip = true,
    this.riskScore = 0,
  });

  final bool requireMfa;
  final String reason;
  final bool allowTrustedDeviceSkip;
  final int riskScore;
}

/// Plaintext backup codes shown once after generation.
class BackupCodeBundle {
  const BackupCodeBundle({
    required this.codes,
    required this.createdAt,
  });

  final List<String> codes;
  final DateTime createdAt;
}

/// Trusted device with MFA trust window.
class MfaTrustedDevice {
  const MfaTrustedDevice({
    required this.id,
    required this.fingerprint,
    this.deviceName,
    this.browser,
    this.operatingSystem,
    this.trustedUntil,
    this.lastActivityAt,
    this.isCurrent = false,
  });

  final String id;
  final String fingerprint;
  final String? deviceName;
  final String? browser;
  final String? operatingSystem;
  final DateTime? trustedUntil;
  final DateTime? lastActivityAt;
  final bool isCurrent;

  bool get isTrustValid =>
      trustedUntil != null && trustedUntil!.isAfter(DateTime.now());
}

/// Security Readiness Score (extends Part 5 health).
abstract final class SecurityReadinessScore {
  static int compute({
    required int baseSecurityHealth,
    required bool mfaEnabled,
    required bool hasBackupCodes,
    required bool hasTrustedDevices,
  }) {
    var score = baseSecurityHealth.clamp(0, 100);
    if (mfaEnabled) {
      score = (score + 15).clamp(0, 100);
    }
    if (hasBackupCodes) {
      score = (score + 5).clamp(0, 100);
    }
    if (hasTrustedDevices) {
      score = (score + 5).clamp(0, 100);
    }
    return score;
  }
}
