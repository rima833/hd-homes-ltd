import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/core/auth/auth.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/validators/password_validator.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/app_role.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/user_profile.dart';

void main() {
  group('resolveAuthStatus', () {
    test('returns unauthenticated without session', () {
      expect(
        resolveAuthStatus(hasSession: false, isLoading: false),
        AuthStatus.unauthenticated,
      );
    });

    test('returns authenticating while loading', () {
      expect(
        resolveAuthStatus(hasSession: false, isLoading: true),
        AuthStatus.authenticating,
      );
    });

    test('maps account statuses', () {
      expect(
        resolveAuthStatus(
          hasSession: true,
          isLoading: false,
          accountStatus: 'suspended',
        ),
        AuthStatus.suspended,
      );
      expect(
        resolveAuthStatus(
          hasSession: true,
          isLoading: false,
          accountStatus: 'active',
          emailConfirmed: true,
        ),
        AuthStatus.authenticated,
      );
      expect(
        resolveAuthStatus(
          hasSession: true,
          isLoading: false,
          emailConfirmed: false,
        ),
        AuthStatus.emailPending,
      );
    });
  });

  group('PermissionEngine', () {
    const engine = PermissionEngine();

    test('super admin receives all permissions', () {
      final perms = engine.permissionsForRoles([AppRole.superAdmin]);
      expect(perms.contains('manage_roles'), isTrue);
      expect(perms.contains('view_properties'), isTrue);
    });

    test('client receives view_properties only from defaults', () {
      final perms = engine.permissionsForRoles([AppRole.client]);
      expect(perms, equals({'view_properties'}));
    });

    test('investor includes reports', () {
      final perms = engine.permissionsForRoles([AppRole.investor]);
      expect(perms.contains('manage_reports'), isTrue);
    });
  });

  group('RouteAuthorization', () {
    test('public paths are recognized', () {
      expect(RouteAuthorization.isPublicPath('/'), isTrue);
      expect(RouteAuthorization.isPublicPath(RoutePaths.properties), isTrue);
      expect(RouteAuthorization.isPublicPath(RoutePaths.login), isTrue);
      expect(RouteAuthorization.isProtectedPath(RoutePaths.client), isTrue);
    });

    test('unauthenticated users redirected from protected routes', () {
      final decision = RouteAuthorization.evaluate(
        path: RoutePaths.client,
        session: AuthSessionSnapshot.empty,
        supabaseConfigured: true,
      );
      expect(decision.allowed, isFalse);
      expect(decision.redirectLocation, contains(RoutePaths.login));
    });

    test('authenticated users stay on login until routing resolves MFA', () {
      final session = AuthSessionSnapshot(
        status: AuthStatus.authenticated,
        profile: const UserProfile(
          id: 'u1',
          email: 'a@b.com',
          primaryRole: AppRole.client,
          roles: [AppRole.client],
          accountStatus: 'active',
        ),
        permissions: const {'view_properties'},
      );
      final decision = RouteAuthorization.evaluate(
        path: RoutePaths.login,
        session: session,
        supabaseConfigured: true,
      );
      expect(decision.allowed, isTrue);
      expect(decision.redirectLocation, isNull);
    });

    test('email-pending users cannot enter protected portals', () {
      final session = AuthSessionSnapshot(
        status: AuthStatus.emailPending,
        email: 'pending@hdhomesltd.com',
        emailConfirmed: false,
        profile: const UserProfile(
          id: 'u2',
          email: 'pending@hdhomesltd.com',
          emailConfirmed: false,
          primaryRole: AppRole.client,
          roles: [AppRole.client],
          accountStatus: 'pending_verification',
        ),
      );
      final decision = RouteAuthorization.evaluate(
        path: RoutePaths.client,
        session: session,
        supabaseConfigured: true,
      );
      expect(decision.allowed, isFalse);
      expect(decision.redirectLocation, contains(RoutePaths.verifyEmail));
    });

    test('authenticated users may stay on verify-email success screen', () {
      final session = AuthSessionSnapshot(
        status: AuthStatus.authenticated,
        emailConfirmed: true,
        profile: const UserProfile(
          id: 'u3',
          email: 'ok@hdhomesltd.com',
          emailConfirmed: true,
          primaryRole: AppRole.client,
          roles: [AppRole.client],
          accountStatus: 'active',
        ),
        permissions: const {'view_properties'},
      );
      final decision = RouteAuthorization.evaluate(
        path: RoutePaths.verifyEmail,
        session: session,
        supabaseConfigured: true,
      );
      expect(decision.allowed, isTrue);
    });
  });

  group('PasswordValidator', () {
    test('rejects weak passwords', () {
      expect(PasswordValidator.validate('short'), isNotNull);
      expect(PasswordValidator.validate('nouppercase1!'), isNotNull);
      expect(PasswordValidator.validate('NoNumber!'), isNotNull);
      expect(PasswordValidator.validate('NoSpecial1'), isNotNull);
    });

    test('accepts strong password', () {
      expect(PasswordValidator.validate('Secure1!pass'), isNull);
    });
  });

  group('AppRole', () {
    test('investor default route is investor portal', () {
      expect(AppRole.investor.defaultRoute, RoutePaths.investor);
      expect(AppRole.investor.canAccessInvestorPortal, isTrue);
    });
  });
}
