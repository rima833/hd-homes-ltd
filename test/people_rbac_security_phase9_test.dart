import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/core/auth/models/auth_session_snapshot.dart';
import 'package:hdhomesproject/core/auth/models/auth_status.dart';
import 'package:hdhomesproject/core/auth/policies/admin_access_policy.dart';
import 'package:hdhomesproject/core/auth/policies/role_nav_policy.dart';
import 'package:hdhomesproject/core/auth/routing/route_authorization.dart';
import 'package:hdhomesproject/core/constants/permissions.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/app_role.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/mfa_models.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/user_profile.dart';
import 'package:hdhomesproject/features/authentication/domain/services/adaptive_security_engine.dart';

AuthSessionSnapshot _session({
  required AppRole role,
  Set<String> permissions = const {},
  List<AppRole>? roles,
}) {
  return AuthSessionSnapshot(
    status: AuthStatus.authenticated,
    userId: 'u1',
    email: 'a@b.com',
    profile: UserProfile(
      id: 'u1',
      email: 'a@b.com',
      primaryRole: role,
      roles: roles ?? [role],
      accountStatus: 'active',
    ),
    permissions: permissions,
  );
}

void main() {
  group('AdminAccessPolicy people/RBAC routes', () {
    test('admin with manage_users can access /dashboard/users', () {
      final session = _session(
        role: AppRole.admin,
        permissions: {PermissionSlugs.manageUsers, PermissionSlugs.manageRoles},
      );
      expect(
        AdminAccessPolicy.canAccessDashboardPath(
          session,
          RoutePaths.dashboardUsers,
        ),
        isTrue,
      );
      expect(
        AdminAccessPolicy.canAccessDashboardPath(
          session,
          RoutePaths.dashboardRoles,
        ),
        isTrue,
      );
    });

    test('admin with only configure_permissions can access roles', () {
      final session = _session(
        role: AppRole.admin,
        permissions: {PermissionSlugs.configurePermissions},
      );
      expect(
        AdminAccessPolicy.canAccessDashboardPath(
          session,
          RoutePaths.dashboardRoles,
        ),
        isTrue,
      );
      expect(
        AdminAccessPolicy.canAccessDashboardPath(
          session,
          RoutePaths.dashboardUsers,
        ),
        isFalse,
      );
    });

    test('sales module staff cannot deep-link users or roles', () {
      final session = _session(
        role: AppRole.salesTeam,
        permissions: {
          PermissionSlugs.manageCrm,
          // Even if SQL grants exist, module nav is strict.
          PermissionSlugs.manageUsers,
          PermissionSlugs.manageRoles,
        },
      );
      expect(RoleNavPolicy.usesStrictModuleNav(session), isTrue);
      expect(
        AdminAccessPolicy.canAccessDashboardPath(
          session,
          RoutePaths.dashboardUsers,
        ),
        isFalse,
      );
      expect(
        AdminAccessPolicy.canAccessDashboardPath(
          session,
          RoutePaths.dashboardRoles,
        ),
        isFalse,
      );
    });

    test('finance module staff cannot access users or roles', () {
      final session = _session(
        role: AppRole.finance,
        permissions: {
          PermissionSlugs.managePayments,
          PermissionSlugs.manageRoles,
        },
      );
      expect(
        AdminAccessPolicy.canAccessDashboardPath(
          session,
          RoutePaths.dashboardUsers,
        ),
        isFalse,
      );
      expect(
        AdminAccessPolicy.canAccessDashboardPath(
          session,
          RoutePaths.dashboardRoles,
        ),
        isFalse,
      );
    });

    test('super admin with roles bundle can access roles', () {
      final session = _session(
        role: AppRole.superAdmin,
        permissions: {
          PermissionSlugs.manageRoles,
          PermissionSlugs.configurePermissions,
          PermissionSlugs.manageUsers,
        },
      );
      expect(
        AdminAccessPolicy.canAccessDashboardPath(
          session,
          RoutePaths.dashboardRoles,
        ),
        isTrue,
      );
    });

    test('RouteAuthorization redirects unauthenticated from roles', () {
      final decision = RouteAuthorization.evaluate(
        path: RoutePaths.dashboardRoles,
        session: AuthSessionSnapshot.empty,
        supabaseConfigured: true,
      );
      expect(decision.allowed, isFalse);
      expect(decision.redirectLocation, contains(RoutePaths.login));
    });
  });

  group('Staff workspace labels and document audience', () {
    test('each staff role has its own desk label', () {
      expect(
        RoleNavPolicy.brandLineFor(_session(role: AppRole.superAdmin)),
        'SUPER ADMIN',
      );
      expect(
        RoleNavPolicy.workspaceLabelFor(_session(role: AppRole.admin)),
        'Admin workspace',
      );
      expect(
        RoleNavPolicy.brandLineFor(_session(role: AppRole.salesTeam)),
        'SALES DESK',
      );
      expect(
        RoleNavPolicy.workspaceLabelFor(_session(role: AppRole.salesTeam)),
        'Sales workspace',
      );
      expect(
        RoleNavPolicy.brandLineFor(_session(role: AppRole.constructionManager)),
        'CONSTRUCTION DESK',
      );
      expect(
        RoleNavPolicy.brandLineFor(_session(role: AppRole.finance)),
        'FINANCE DESK',
      );
      expect(
        RoleNavPolicy.brandLineFor(_session(role: AppRole.marketing)),
        'MARKETING DESK',
      );
    });

    test('admin searches clients and investors; sales see clients', () {
      expect(
        RoleNavPolicy.documentAudienceFor(_session(role: AppRole.admin)),
        StaffDocumentAudience.both,
      );
      expect(
        RoleNavPolicy.documentAudienceFor(_session(role: AppRole.salesTeam)),
        StaffDocumentAudience.clients,
      );
      expect(
        RoleNavPolicy.documentAudienceFor(_session(role: AppRole.finance)),
        StaffDocumentAudience.investors,
      );
    });
  });

  group('AdaptiveSecurityEngine step-up for people/RBAC', () {
    test('modifyPermissions requires step-up when AAL1 and staff policy', () {
      expect(
        AdaptiveSecurityEngine.requiresStepUp(
          action: StepUpAction.modifyPermissions,
          policy: MfaPolicyCatalog.staff,
          aal2Satisfied: false,
        ),
        isTrue,
      );
    });

    test('modifyPermissions skipped when AAL2 satisfied', () {
      expect(
        AdaptiveSecurityEngine.requiresStepUp(
          action: StepUpAction.modifyPermissions,
          policy: MfaPolicyCatalog.staff,
          aal2Satisfied: true,
        ),
        isFalse,
      );
    });

    test('createAdmin still flagged even with AAL2', () {
      expect(
        AdaptiveSecurityEngine.requiresStepUp(
          action: StepUpAction.createAdmin,
          policy: MfaPolicyCatalog.superAdmin,
          aal2Satisfied: true,
        ),
        isTrue,
      );
    });
  });
}
