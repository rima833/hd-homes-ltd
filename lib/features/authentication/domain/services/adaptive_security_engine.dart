import 'package:hdhomesproject/features/authentication/domain/entities/app_role.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/mfa_models.dart';

/// Adaptive Security Engine™ — decides if MFA / step-up is required.
abstract final class AdaptiveSecurityEngine {
  static AdaptiveSecurityDecision evaluateLogin({
    required AppRole? role,
    required bool mfaEnabled,
    required bool trustedDevice,
    required bool newDevice,
    required bool aal2Satisfied,
    int recentFailedLogins = 0,
  }) {
    final policy = MfaPolicyCatalog.forRole(role);
    var risk = 0;
    if (newDevice) risk += 25;
    if (recentFailedLogins >= 3) risk += 30;
    if (policy.isMandatory) risk += 10;

    if (!mfaEnabled) {
      if (policy.isEnforced) {
        return AdaptiveSecurityDecision(
          requireMfa: true,
          reason: 'mfa_enrollment_required',
          allowTrustedDeviceSkip: false,
          riskScore: risk,
        );
      }
      return AdaptiveSecurityDecision(
        requireMfa: false,
        reason: 'mfa_not_enabled',
        riskScore: risk,
      );
    }

    if (aal2Satisfied) {
      return AdaptiveSecurityDecision(
        requireMfa: false,
        reason: 'aal2_satisfied',
        riskScore: risk,
      );
    }

    if (trustedDevice && policy.requirement != MfaRequirement.mandatory) {
      return AdaptiveSecurityDecision(
        requireMfa: false,
        reason: 'trusted_device',
        allowTrustedDeviceSkip: true,
        riskScore: risk,
      );
    }

    return AdaptiveSecurityDecision(
      requireMfa: true,
      reason: 'second_factor_required',
      riskScore: risk,
    );
  }

  static bool requiresStepUp({
    required StepUpAction action,
    required MfaPolicy policy,
    required bool aal2Satisfied,
  }) {
    if (!policy.stepUpSensitiveActions) return false;
    if (!policy.isEnforced && action == StepUpAction.changePassword) {
      return false;
    }
    if (aal2Satisfied && action != StepUpAction.createAdmin) return false;
    return switch (action) {
      StepUpAction.createAdmin ||
      StepUpAction.modifyPermissions ||
      StepUpAction.deleteAccount ||
      StepUpAction.editPaymentDetails ||
      StepUpAction.withdrawInvestment ||
      StepUpAction.exportSensitiveData =>
        true,
      StepUpAction.changeEmail || StepUpAction.changePassword =>
        policy.isEnforced,
    };
  }
}
