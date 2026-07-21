import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/app_role.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/kyc_models.dart';

void main() {
  group('KycLevel', () {
    test('targets investors at level 3', () {
      expect(KycLevel.targetForRole(AppRole.investor), KycLevel.investor);
      expect(KycLevel.targetForRole(AppRole.client), KycLevel.basic);
    });
  });

  group('IntelligentVerificationEngine', () {
    test('basic progress requires email and phone', () {
      final progress = IntelligentVerificationEngine.evaluateProgress(
        emailVerified: true,
        phoneVerified: false,
        documents: const [],
        compliance: const InvestorComplianceInfo(),
        targetLevel: KycLevel.basic,
        isInvestor: false,
      );
      expect(progress.percent, 50);
      expect(progress.missing.any((m) => m.id == 'phone'), isTrue);
    });

    test('identity level requires documents', () {
      final progress = IntelligentVerificationEngine.evaluateProgress(
        emailVerified: true,
        phoneVerified: true,
        documents: const [],
        compliance: const InvestorComplianceInfo(),
        targetLevel: KycLevel.identity,
        isInvestor: false,
      );
      expect(progress.missing.map((m) => m.id), containsAll(['gov_id', 'selfie', 'address']));
      expect(
        IntelligentVerificationEngine.canSubmitForReview(
          progress,
          KycLevel.identity,
        ),
        isFalse,
      );
    });

    test('trust score increases with verification', () {
      final low = IntelligentVerificationEngine.trustScore(
        emailVerified: false,
        phoneVerified: false,
        level: KycLevel.guest,
        status: KycStatus.pending,
        mfaEnabled: false,
        approvedDocuments: 0,
      );
      final high = IntelligentVerificationEngine.trustScore(
        emailVerified: true,
        phoneVerified: true,
        level: KycLevel.investor,
        status: KycStatus.approved,
        mfaEnabled: true,
        approvedDocuments: 3,
      );
      expect(high, greaterThan(low));
      expect(high, lessThanOrEqualTo(100));
    });
  });

  group('DigitalVerificationPassport', () {
    test('investor ready when level and approved', () {
      const passport = DigitalVerificationPassport(
        userId: 'u1',
        level: KycLevel.investor,
        status: KycStatus.approved,
        trustScore: 90,
      );
      expect(passport.isInvestorReady, isTrue);
      expect(passport.isIdentityReady, isTrue);
    });
  });
}
