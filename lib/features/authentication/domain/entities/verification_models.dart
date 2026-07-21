import 'package:hdhomesproject/features/authentication/domain/entities/app_role.dart';

/// Channel being verified.
enum VerificationChannel { email, phone }

/// Lifecycle for a verification attempt / channel status.
enum VerificationLifecycle {
  notAdded,
  waiting,
  sending,
  sent,
  pending,
  verified,
  expired,
  failed,
  resending,
  cancelled,
}

extension VerificationLifecycleX on VerificationLifecycle {
  String get id => name;

  bool get isTerminalSuccess => this == VerificationLifecycle.verified;

  bool get canResend => switch (this) {
        VerificationLifecycle.waiting ||
        VerificationLifecycle.sent ||
        VerificationLifecycle.pending ||
        VerificationLifecycle.expired ||
        VerificationLifecycle.failed =>
          true,
        _ => false,
      };
}

/// Email verification status surface for the app.
enum EmailVerificationStatus {
  unverified,
  pending,
  verified,
  failed,
}

/// Phone verification status surface for the app.
enum PhoneVerificationStatus {
  notAdded,
  pending,
  verified,
  failed,
}

/// How strictly phone verification is enforced for a role.
enum PhoneVerificationRequirement {
  disabled,
  optional,
  required,
}

/// Smart Verification Policies — role-based rules (admin-configurable later via CMS).
class VerificationPolicy {
  const VerificationPolicy({
    required this.role,
    this.emailRequired = true,
    this.phoneRequirement = PhoneVerificationRequirement.optional,
    this.mfaRecommended = false,
    this.blockProtectedUntilEmailVerified = true,
  });

  final AppRole role;
  final bool emailRequired;
  final PhoneVerificationRequirement phoneRequirement;
  final bool mfaRecommended;
  final bool blockProtectedUntilEmailVerified;

  bool get phoneRequired =>
      phoneRequirement == PhoneVerificationRequirement.required;
}

/// Default HD Homes policies (editable later from Admin without code changes via JSON).
abstract final class VerificationPolicyCatalog {
  static const client = VerificationPolicy(
    role: AppRole.client,
    emailRequired: true,
    phoneRequirement: PhoneVerificationRequirement.optional,
  );

  static const investor = VerificationPolicy(
    role: AppRole.investor,
    emailRequired: true,
    phoneRequirement: PhoneVerificationRequirement.required,
  );

  static const staff = VerificationPolicy(
    role: AppRole.salesTeam,
    emailRequired: true,
    phoneRequirement: PhoneVerificationRequirement.required,
  );

  static const superAdmin = VerificationPolicy(
    role: AppRole.superAdmin,
    emailRequired: true,
    phoneRequirement: PhoneVerificationRequirement.required,
    mfaRecommended: true,
  );

  static VerificationPolicy forRole(AppRole? role) {
    return switch (role) {
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
}

/// OTP security policy (server + client).
abstract final class OtpSecurityPolicy {
  static const int codeLength = 6;
  static const Duration expiry = Duration(minutes: 10);
  static const Duration resendCooldown = Duration(seconds: 60);
  static const int maxResendAttempts = 5;
  static const int maxVerifyAttempts = 5;
  static const Duration emailResendCooldown = Duration(seconds: 60);
  static const int maxEmailResendAttempts = 8;
}

/// Aggregate verification snapshot for UI / trust score.
class VerificationSnapshot {
  const VerificationSnapshot({
    this.emailStatus = EmailVerificationStatus.unverified,
    this.phoneStatus = PhoneVerificationStatus.notAdded,
    this.email,
    this.phone,
    this.emailLifecycle = VerificationLifecycle.waiting,
    this.phoneLifecycle = VerificationLifecycle.notAdded,
    this.trustScore = 0,
    this.policy = VerificationPolicyCatalog.client,
  });

  final EmailVerificationStatus emailStatus;
  final PhoneVerificationStatus phoneStatus;
  final String? email;
  final String? phone;
  final VerificationLifecycle emailLifecycle;
  final VerificationLifecycle phoneLifecycle;
  final int trustScore;
  final VerificationPolicy policy;

  bool get emailVerified => emailStatus == EmailVerificationStatus.verified;
  bool get phoneVerified => phoneStatus == PhoneVerificationStatus.verified;

  bool get meetsPolicy {
    if (policy.emailRequired && !emailVerified) return false;
    if (policy.phoneRequired && !phoneVerified) return false;
    return true;
  }

  VerificationSnapshot copyWith({
    EmailVerificationStatus? emailStatus,
    PhoneVerificationStatus? phoneStatus,
    String? email,
    String? phone,
    VerificationLifecycle? emailLifecycle,
    VerificationLifecycle? phoneLifecycle,
    int? trustScore,
    VerificationPolicy? policy,
  }) {
    return VerificationSnapshot(
      emailStatus: emailStatus ?? this.emailStatus,
      phoneStatus: phoneStatus ?? this.phoneStatus,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      emailLifecycle: emailLifecycle ?? this.emailLifecycle,
      phoneLifecycle: phoneLifecycle ?? this.phoneLifecycle,
      trustScore: trustScore ?? this.trustScore,
      policy: policy ?? this.policy,
    );
  }
}

/// Audit / history row.
class VerificationEvent {
  const VerificationEvent({
    required this.id,
    required this.channel,
    required this.eventType,
    required this.createdAt,
    this.success = true,
    this.metadata = const {},
  });

  final String id;
  final VerificationChannel channel;
  final String eventType;
  final DateTime createdAt;
  final bool success;
  final Map<String, dynamic> metadata;
}

/// Pending email change request.
class EmailChangeRequest {
  const EmailChangeRequest({
    required this.id,
    required this.newEmail,
    required this.createdAt,
    this.expiresAt,
    this.confirmed = false,
  });

  final String id;
  final String newEmail;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final bool confirmed;
}

/// Trust Score Foundation — points for successful verifications.
abstract final class TrustScoreFoundation {
  static const int emailVerifiedPoints = 25;
  static const int phoneVerifiedPoints = 25;
  static const int maxBaseScore = 50;

  static int compute({
    required bool emailVerified,
    required bool phoneVerified,
  }) {
    var score = 0;
    if (emailVerified) score += emailVerifiedPoints;
    if (phoneVerified) score += phoneVerifiedPoints;
    return score.clamp(0, maxBaseScore);
  }
}
