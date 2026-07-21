import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/app_role.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/profile_models.dart';

void main() {
  group('DynamicUserIdentity', () {
    test('investors see company section', () {
      final sections = DynamicUserIdentity.sectionsFor(AppRole.investor);
      expect(sections, contains(ProfileSection.company));
      expect(sections, contains(ProfileSection.connected));
    });

    test('clients omit company by default', () {
      final sections = DynamicUserIdentity.sectionsFor(AppRole.client);
      expect(sections, isNot(contains(ProfileSection.company)));
    });
  });

  group('ProfileCompletionEngine', () {
    test('scores empty profile low and filled profile higher', () {
      const empty = ProfileDetails(id: '1', email: 'a@b.com');
      final low = ProfileCompletionEngine.evaluate(
        profile: empty,
        company: const CompanyProfile(),
        communication: const CommunicationPreferences(),
        mfaEnabled: false,
        isInvestor: false,
      );

      final rich = ProfileCompletionEngine.evaluate(
        profile: const ProfileDetails(
          id: '1',
          email: 'a@b.com',
          firstName: 'Ada',
          lastName: 'Lovelace',
          avatarUrl: 'https://example.com/a.jpg',
          phoneVerified: true,
          address: '12 King St',
          city: 'Lagos',
          occupation: 'Engineer',
        ),
        company: const CompanyProfile(),
        communication: const CommunicationPreferences(smsEnabled: true),
        mfaEnabled: true,
        isInvestor: false,
      );

      expect(rich.percent, greaterThan(low.percent));
      expect(rich.missing.any((i) => i.id == 'kyc'), isTrue);
    });

    test('requires company for investors', () {
      final result = ProfileCompletionEngine.evaluate(
        profile: const ProfileDetails(
          id: '1',
          email: 'i@hd.com',
          firstName: 'Ivy',
          lastName: 'Investor',
        ),
        company: const CompanyProfile(),
        communication: const CommunicationPreferences(),
        mfaEnabled: false,
        isInvestor: true,
      );
      expect(
        result.items.firstWhere((i) => i.id == 'company').completed,
        isFalse,
      );
    });
  });

  group('AccountHealthScore', () {
    test('combines completion and security signals', () {
      final weak = AccountHealthScore.compute(
        profileCompletionPercent: 20,
        emailVerified: false,
        phoneVerified: false,
        mfaEnabled: false,
        securityReadiness: 40,
      );
      final strong = AccountHealthScore.compute(
        profileCompletionPercent: 90,
        emailVerified: true,
        phoneVerified: true,
        mfaEnabled: true,
        securityReadiness: 90,
      );
      expect(strong, greaterThan(weak));
      expect(strong, lessThanOrEqualTo(100));
    });
  });

  group('ProfileDetails', () {
    test('toUpdateMap includes enterprise fields', () {
      final map = const ProfileDetails(
        id: '1',
        email: 'a@b.com',
        firstName: 'Ada',
        middleName: 'A',
        preferredName: 'Ada',
        postalCode: '100001',
      ).toUpdateMap();
      expect(map['middle_name'], 'A');
      expect(map['preferred_name'], 'Ada');
      expect(map['postal_code'], '100001');
    });
  });
}
