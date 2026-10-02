import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/email/email_config.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/app_role.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/login_models.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/user_profile.dart';
import 'package:hdhomesproject/features/authentication/domain/services/smart_login_router.dart';

void main() {
  group('EmailConfig', () {
    test('detects local development origins', () {
      expect(EmailConfig.isLocalDevOrigin('http://localhost:56512'), isTrue);
      expect(EmailConfig.isLocalDevOrigin('http://127.0.0.1:8080/'), isTrue);
      expect(
        EmailConfig.isLocalDevOrigin('https://hdhomesltd.com'),
        isFalse,
      );
    });

    test('mailed action links never keep a localhost host', () {
      expect(
        EmailConfig.composeActionUrl(
          'http://localhost:56512',
          '/register?invite=token&email=a%40hdhomesltd.com',
        ),
        'https://hdhomesltd.com/register?invite=token&email=a%40hdhomesltd.com',
      );
      expect(
        EmailConfig.composeActionUrl(
          'https://hdhomesltd.com',
          'https://hdhomesltd.com/register?invite=abc',
        ),
        'https://hdhomesltd.com/register?invite=abc',
      );
      expect(
        EmailConfig.composeActionUrl(
          'https://hdhomesltd.com',
          'http://localhost:56512/register?invite=abc',
        ),
        'https://hdhomesltd.com/register?invite=abc',
      );
    });

    test('authRedirect builds path-style production verify URL in VM tests',
        () async {
      // kIsWeb is false in unit tests → production landing.
      final config = EmailConfig(null);
      final url = await config.authRedirect('/verify-email');
      expect(url.contains('/#/'), isFalse);
      expect(url.contains('/functions/v1/'), isFalse);
      expect(url, 'https://hdhomesltd.com/verify-email');
    });

    test('authRedirect for login CTA uses public site, not localhost', () async {
      final config = EmailConfig(null);
      final url = await config.authRedirect('/login');
      expect(url.contains('localhost'), isFalse);
      expect(url.endsWith('/login'), isTrue);
      expect(url.startsWith('https://'), isTrue);
    });

    test('authRedirect normalizes legacy hash-style callers for verify',
        () async {
      final config = EmailConfig(null);
      final url = await config.authRedirect('/#/verify-email');
      expect(url.contains('/#/'), isFalse);
      expect(url, endsWith('/verify-email'));
    });

    test('authRedirect for password reset uses path-style /reset-password',
        () async {
      final config = EmailConfig(null);
      final url = await config.authRedirect('/reset-password');
      expect(url.contains('/#/'), isFalse);
      expect(url.endsWith('/reset-password'), isTrue);
      expect(url.contains('localhost'), isFalse);
    });
  });

  group('SmartLoginRouter', () {
    test('unverified email goes to verify-email', () {
      final dest = SmartLoginRouter.resolve(
        SmartLoginContext(
          profile: const UserProfile(
            id: 'u1',
            email: 'new@hdhomesltd.com',
            emailConfirmed: false,
            primaryRole: AppRole.client,
            roles: [AppRole.client],
            accountStatus: 'pending_verification',
          ),
        ),
      );
      expect(dest, startsWith(RoutePaths.verifyEmail));
    });

    test('verified email with pending account status is not trapped on verify',
        () {
      final dest = SmartLoginRouter.resolve(
        SmartLoginContext(
          profile: const UserProfile(
            id: 'u2',
            email: 'ready@hdhomesltd.com',
            emailConfirmed: true,
            primaryRole: AppRole.client,
            roles: [AppRole.client],
            accountStatus: 'pending_verification',
          ),
          profileComplete: true,
        ),
      );
      expect(dest, isNot(contains(RoutePaths.verifyEmail)));
      expect(dest, RoutePaths.client);
    });
  });
}
