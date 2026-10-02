import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/app_role.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/verification_models.dart';
import 'package:hdhomesproject/features/authentication/domain/services/phone_otp_service.dart';
import 'package:hdhomesproject/features/authentication/domain/services/sms_provider_adapters.dart';

void main() {
  group('VerificationPolicyCatalog', () {
    test('clients do not require SMS phone verification', () {
      final policy = VerificationPolicyCatalog.forRole(AppRole.client);
      expect(policy.emailRequired, isTrue);
      expect(policy.phoneRequired, isFalse);
      expect(
        policy.phoneRequirement,
        PhoneVerificationRequirement.disabled,
      );
    });

    test('investors do not require SMS phone verification', () {
      final policy = VerificationPolicyCatalog.forRole(AppRole.investor);
      expect(policy.phoneRequired, isFalse);
      expect(
        policy.phoneRequirement,
        PhoneVerificationRequirement.disabled,
      );
    });

    test('super admin recommends MFA without SMS phone OTP', () {
      final policy = VerificationPolicyCatalog.forRole(AppRole.superAdmin);
      expect(policy.mfaRecommended, isTrue);
      expect(policy.phoneRequired, isFalse);
    });
  });

  group('TrustScoreFoundation', () {
    test('scores email and phone verifications', () {
      expect(
        TrustScoreFoundation.compute(emailVerified: true, phoneVerified: false),
        TrustScoreFoundation.emailVerifiedPoints,
      );
      expect(
        TrustScoreFoundation.compute(emailVerified: true, phoneVerified: true),
        TrustScoreFoundation.maxBaseScore,
      );
    });
  });

  group('MockPhoneOtpService', () {
    test('accepts debug code', () async {
      const service = MockPhoneOtpService();
      final send = await service.sendOtp(phoneE164: '+2348012345678');
      expect(send.success, isTrue);
      final ok = await service.verifyOtp(
        phoneE164: '+2348012345678',
        code: '123456',
        requestId: send.requestId,
      );
      expect(ok.success, isTrue);
      final bad = await service.verifyOtp(
        phoneE164: '+2348012345678',
        code: '000000',
      );
      expect(bad.success, isFalse);
    });
  });

  group('FailoverPhoneOtpService', () {
    test('falls back when primary fails', () async {
      final failover = FailoverPhoneOtpService(
        primary: const TermiiPhoneOtpService(),
        fallbacks: const [MockPhoneOtpService()],
      );
      final result = await failover.sendOtp(phoneE164: '+2348012345678');
      expect(result.success, isTrue);
      expect(failover.providerId, PhoneOtpProviderId.mock);
    });

    test('verifies against the provider that sent the OTP', () async {
      final failover = FailoverPhoneOtpService(
        primary: const TermiiPhoneOtpService(),
        fallbacks: const [MockPhoneOtpService()],
      );
      await failover.sendOtp(phoneE164: '+2348012345678');
      final ok = await failover.verifyOtp(
        phoneE164: '+2348012345678',
        code: '123456',
      );
      expect(ok.success, isTrue);
    });
  });

  group('VerificationLifecycle', () {
    test('canResend for waiting/sent/failed', () {
      expect(VerificationLifecycle.waiting.canResend, isTrue);
      expect(VerificationLifecycle.verified.canResend, isFalse);
    });
  });
}
