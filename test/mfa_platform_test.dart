import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/app_role.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/mfa_models.dart';
import 'package:hdhomesproject/features/authentication/domain/services/adaptive_security_engine.dart';

void main() {
  group('MfaPolicyCatalog', () {
    test('clients are optional, investors recommended', () {
      expect(
        MfaPolicyCatalog.forRole(AppRole.client).requirement,
        MfaRequirement.optional,
      );
      expect(
        MfaPolicyCatalog.forRole(AppRole.investor).requirement,
        MfaRequirement.recommended,
      );
    });

    test('staff required and super admin mandatory', () {
      expect(MfaPolicyCatalog.forRole(AppRole.admin).isEnforced, isTrue);
      expect(MfaPolicyCatalog.forRole(AppRole.superAdmin).isMandatory, isTrue);
      expect(
        MfaPolicyCatalog.forRole(AppRole.superAdmin).allowEmailFallback,
        isFalse,
      );
    });
  });

  group('AdaptiveSecurityEngine', () {
    test('does not require MFA when not enabled for optional roles', () {
      final decision = AdaptiveSecurityEngine.evaluateLogin(
        role: AppRole.client,
        mfaEnabled: false,
        trustedDevice: false,
        newDevice: true,
        aal2Satisfied: true,
      );
      expect(decision.requireMfa, isFalse);
      expect(decision.reason, 'mfa_not_enabled');
    });

    test('requires enrollment for enforced roles without MFA', () {
      final decision = AdaptiveSecurityEngine.evaluateLogin(
        role: AppRole.admin,
        mfaEnabled: false,
        trustedDevice: false,
        newDevice: false,
        aal2Satisfied: true,
      );
      expect(decision.requireMfa, isTrue);
      expect(decision.reason, 'mfa_enrollment_required');
    });

    test('requires second factor when MFA enabled and AAL1', () {
      final decision = AdaptiveSecurityEngine.evaluateLogin(
        role: AppRole.client,
        mfaEnabled: true,
        trustedDevice: false,
        newDevice: false,
        aal2Satisfied: false,
      );
      expect(decision.requireMfa, isTrue);
      expect(decision.reason, 'second_factor_required');
    });

    test('trusted device can skip MFA except for mandatory roles', () {
      final client = AdaptiveSecurityEngine.evaluateLogin(
        role: AppRole.client,
        mfaEnabled: true,
        trustedDevice: true,
        newDevice: false,
        aal2Satisfied: false,
      );
      expect(client.requireMfa, isFalse);
      expect(client.reason, 'trusted_device');

      final sa = AdaptiveSecurityEngine.evaluateLogin(
        role: AppRole.superAdmin,
        mfaEnabled: true,
        trustedDevice: true,
        newDevice: false,
        aal2Satisfied: false,
      );
      expect(sa.requireMfa, isTrue);
    });

    test('step-up required for createAdmin', () {
      expect(
        AdaptiveSecurityEngine.requiresStepUp(
          action: StepUpAction.createAdmin,
          policy: MfaPolicyCatalog.staff,
          aal2Satisfied: true,
        ),
        isTrue,
      );
    });
  });

  group('SecurityReadinessScore', () {
    test('adds MFA bonuses', () {
      final base = SecurityReadinessScore.compute(
        baseSecurityHealth: 70,
        mfaEnabled: false,
        hasBackupCodes: false,
        hasTrustedDevices: false,
      );
      final full = SecurityReadinessScore.compute(
        baseSecurityHealth: 70,
        mfaEnabled: true,
        hasBackupCodes: true,
        hasTrustedDevices: true,
      );
      expect(base, 70);
      expect(full, 95);
    });
  });
}
