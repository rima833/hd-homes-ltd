import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/app_role.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/registration_models.dart';
import 'package:hdhomesproject/features/authentication/domain/services/registration_assistant.dart';
import 'package:hdhomesproject/features/authentication/domain/services/registration_validator.dart';

void main() {
  group('RegistrationAccountType', () {
    test('selectable types are enabled client and investor', () {
      final ids = RegistrationAccountType.selectable.map((t) => t.id).toList();
      expect(ids, containsAll(['client', 'investor']));
      expect(RegistrationAccountType.upcoming, isNotEmpty);
    });

    test('maps to default roles', () {
      expect(RegistrationAccountType.client.defaultRole, AppRole.client);
      expect(RegistrationAccountType.investor.defaultRole, AppRole.investor);
    });
  });

  group('RegistrationValidator', () {
    test('requires account type', () {
      expect(
        RegistrationValidator.validateAccountType(const RegistrationDraft()),
        isNotNull,
      );
    });

    test('validates personal info', () {
      final errors = RegistrationValidator.validatePersonalInfo(
        const RegistrationDraft(
          accountType: RegistrationAccountType.client,
          firstName: 'Ada',
          lastName: 'Okafor',
          email: 'ada@example.com',
          phone: '08012345678',
          country: 'Nigeria',
          state: 'Lagos',
        ),
      );
      expect(errors.values.every((e) => e == null), isTrue);
    });

    test('rejects mismatched passwords', () {
      final errors = RegistrationValidator.validateCredentials(
        const RegistrationDraft(
          password: 'Secure1!pass',
          confirmPassword: 'Different1!',
        ),
      );
      expect(errors['confirmPassword'], isNotNull);
    });

    test('requires legal acceptance', () {
      expect(
        RegistrationValidator.validateLegal(const RegistrationDraft()),
        isNotNull,
      );
      expect(
        RegistrationValidator.validateLegal(
          const RegistrationDraft(
            acceptTerms: true,
            acceptPrivacy: true,
            acceptCookies: true,
          ),
        ),
        isNull,
      );
    });

    test('full review draft is valid', () {
      const draft = RegistrationDraft(
        accountType: RegistrationAccountType.investor,
        firstName: 'Chidi',
        lastName: 'Okeke',
        email: 'chidi@example.com',
        phone: '+2348012345678',
        country: 'Nigeria',
        state: 'Abuja',
        password: 'Secure1!pass',
        confirmPassword: 'Secure1!pass',
        acceptTerms: true,
        acceptPrivacy: true,
        acceptCookies: true,
      );
      expect(RegistrationValidator.stepIsValid(RegistrationStep.review, draft), isTrue);
    });
  });

  group('PasswordStrengthEvaluator', () {
    test('scores strong password', () {
      expect(
        PasswordStrengthEvaluator.evaluate('Secure1!ab'),
        PasswordStrength.strong,
      );
      final checks = PasswordStrengthEvaluator.checklist('Secure1!ab');
      expect(checks.values.every((v) => v), isTrue);
    });
  });

  group('RegistrationDraft metadata', () {
    test('includes account type and legal versions', () {
      final meta = const RegistrationDraft(
        accountType: RegistrationAccountType.investor,
        firstName: 'A',
        lastName: 'B',
        acceptTerms: true,
      ).toAuthMetadata();
      expect(meta['account_type'], 'investor');
      expect(meta['terms_version'], LegalDocumentVersions.terms);
      expect(meta['first_name'], 'A');
    });
  });

  group('RegistrationAssistant', () {
    test('adapts tips by account type', () {
      final clientTip = RegistrationAssistant.tipForStep(
        RegistrationStep.personalInfo,
        accountType: RegistrationAccountType.client,
      );
      final investorTip = RegistrationAssistant.tipForStep(
        RegistrationStep.personalInfo,
        accountType: RegistrationAccountType.investor,
      );
      expect(clientTip, isNot(equals(investorTip)));
      expect(
        RegistrationAssistant.onboardingHint(RegistrationAccountType.investor),
        contains('KYC'),
      );
    });
  });
}
