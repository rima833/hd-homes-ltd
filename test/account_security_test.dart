import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/account_security_models.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/app_role.dart';
import 'package:hdhomesproject/features/authentication/domain/services/registration_validator.dart';

void main() {
  group('PasswordPolicy', () {
    test('standard requires complexity', () {
      expect(PasswordPolicy.standard.validate('short'), isNotNull);
      expect(PasswordPolicy.standard.validate('Password1!'), isNull);
    });

    test('admin policy requires longer passwords', () {
      final policy = PasswordPolicy.forRole(AppRole.admin);
      expect(policy.minLength, 12);
      expect(policy.validate('Password1!'), isNotNull);
      expect(policy.validate('Password12!x'), isNull);
    });
  });

  group('SecurityHealthSnapshot', () {
    test('scores verified channels higher', () {
      final weak = SecurityHealthSnapshot.compute(
        passwordStrength: PasswordStrength.weak,
        emailVerified: false,
        phoneVerified: false,
      );
      final strong = SecurityHealthSnapshot.compute(
        passwordStrength: PasswordStrength.excellent,
        emailVerified: true,
        phoneVerified: true,
        mfaEnabled: true,
      );
      expect(strong.score, greaterThan(weak.score));
      expect(strong.score, 100);
    });
  });

  group('PasswordStrengthEvaluator', () {
    test('can reach excellent', () {
      expect(
        PasswordStrengthEvaluator.evaluate('ExcellentPass1!xyz'),
        PasswordStrength.excellent,
      );
    });
  });
}
