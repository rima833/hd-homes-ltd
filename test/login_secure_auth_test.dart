import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/app_role.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/login_models.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/user_profile.dart';
import 'package:hdhomesproject/features/authentication/domain/services/login_validator.dart';
import 'package:hdhomesproject/features/authentication/domain/services/smart_login_router.dart';

void main() {
  group('LoginValidator', () {
    test('requires email and password', () {
      expect(
        LoginValidator.isValid(
          const LoginCredentials(email: '', password: ''),
        ),
        isFalse,
      );
      expect(
        LoginValidator.isValid(
          const LoginCredentials(
            email: 'user@hdhomes.ng',
            password: 'Secret1!',
          ),
        ),
        isTrue,
      );
    });
  });

  group('SmartLoginRouter', () {
    UserProfile profile({
      AppRole role = AppRole.client,
      bool emailConfirmed = true,
      String status = 'active',
      String? firstName = 'Ada',
      String? lastName = 'Lovelace',
    }) {
      return UserProfile(
        id: 'u1',
        email: 'ada@hdhomes.ng',
        firstName: firstName,
        lastName: lastName,
        primaryRole: role,
        roles: [role],
        accountStatus: status,
        emailConfirmed: emailConfirmed,
      );
    }

    test('routes clients to client dashboard', () {
      expect(
        SmartLoginRouter.resolve(SmartLoginContext(profile: profile())),
        RoutePaths.client,
      );
    });

    test('routes investors to investor portal', () {
      expect(
        SmartLoginRouter.resolve(
          SmartLoginContext(profile: profile(role: AppRole.investor)),
        ),
        RoutePaths.investor,
      );
    });

    test('routes admins to dashboard', () {
      expect(
        SmartLoginRouter.resolve(
          SmartLoginContext(profile: profile(role: AppRole.admin)),
        ),
        RoutePaths.dashboard,
      );
    });

    test('honors safe redirect query', () {
      expect(
        SmartLoginRouter.resolve(
          SmartLoginContext(
            profile: profile(),
            redirectPath: RoutePaths.clientSaved,
          ),
        ),
        RoutePaths.clientSaved,
      );
    });

    test('rejects open redirects', () {
      expect(
        SmartLoginRouter.sanitizeRedirect('https://evil.example'),
        isNull,
      );
      expect(SmartLoginRouter.sanitizeRedirect('//evil.example'), isNull);
      expect(SmartLoginRouter.sanitizeRedirect(RoutePaths.login), isNull);
    });

    test('sends unverified users to verify-email', () {
      final dest = SmartLoginRouter.resolve(
        SmartLoginContext(
          profile: profile(emailConfirmed: false, status: 'pending_verification'),
        ),
      );
      expect(dest.startsWith(RoutePaths.verifyEmail), isTrue);
      expect(dest.contains('email='), isTrue);
    });

    test('incomplete profile goes to settings', () {
      expect(
        SmartLoginRouter.resolve(
          SmartLoginContext(
            profile: profile(firstName: null, lastName: null),
            profileComplete: false,
          ),
        ),
        RoutePaths.clientSettings,
      );
    });
  });

  group('LoginMethod', () {
    test('only email password is enabled in phase 1', () {
      expect(LoginMethod.emailPassword.enabled, isTrue);
      expect(LoginMethod.google.enabled, isFalse);
      expect(LoginMethod.magicLink.enabled, isFalse);
    });
  });
}
