import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/features/authentication/domain/services/auth_confirmation_link.dart';

void main() {
  group('AuthConfirmationLink', () {
    test('PKCE confirm on /verify-email opens the confirmed screen', () {
      final link = AuthConfirmationLink.parse(
        Uri.parse('http://localhost:56512/verify-email?code=confirm-code'),
      );

      expect(link.isEmailConfirmation, isTrue);
      expect(link.isRecovery, isFalse);
      expect(
        link.verifyEmailLocation(),
        '${RoutePaths.verifyEmail}?confirmed=1',
      );
    });

    test('implicit signup hash opens the confirmed screen', () {
      final link = AuthConfirmationLink.parse(
        Uri.parse(
          'http://localhost:56512/verify-email#access_token=token&type=signup',
        ),
      );

      expect(link.isEmailConfirmation, isTrue);
      expect(
        link.verifyEmailLocation(),
        '${RoutePaths.verifyEmail}?confirmed=1',
      );
    });

    test('token hash on the site root is still a confirmation', () {
      final link = AuthConfirmationLink.parse(
        Uri.parse(
          'https://hdhomesltd.com/?token_hash=hash&type=signup&email=person@example.com',
        ),
      );

      expect(link.isEmailConfirmation, isTrue);
      expect(link.email, 'person@example.com');
      expect(
        link.verifyEmailLocation(),
        '${RoutePaths.verifyEmail}?confirmed=1&email=person%40example.com',
      );
    });

    test('expired confirm link stays an error, not a success', () {
      final link = AuthConfirmationLink.parse(
        Uri.parse(
          'http://localhost:56512/verify-email#error_description=Email+link+is+invalid+or+has+expired',
        ),
      );

      expect(link.isEmailConfirmation, isFalse);
      expect(link.errorDescription, contains('expired'));
      expect(link.verifyEmailLocation(), contains('error_description='));
      expect(link.verifyEmailLocation(), isNot(contains('confirmed=1')));
    });

    test('password recovery is not an email confirmation', () {
      final link = AuthConfirmationLink.parse(
        Uri.parse('http://localhost:56512/reset-password?code=recovery-code'),
      );

      expect(link.isRecovery, isTrue);
      expect(link.isEmailConfirmation, isFalse);
      expect(link.verifyEmailLocation(), isNull);
    });

    test('a normal visit is not a confirmation', () {
      final link = AuthConfirmationLink.parse(
        Uri.parse(
          'http://localhost:56512/verify-email?email=person@example.com',
        ),
      );

      expect(link.isEmailConfirmation, isFalse);
      expect(link.verifyEmailLocation(), isNull);
    });
  });
}
