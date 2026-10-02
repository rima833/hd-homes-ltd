import 'package:hdhomesproject/core/auth/models/auth_session_snapshot.dart';
import 'package:hdhomesproject/core/auth/policies/role_nav_policy.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/app_role.dart';

/// Which home dashboard a staff member should land on.
enum StaffDashboardKind {
  /// Full Mission Control — all KPIs, health, strategy, executive reports.
  superAdminExecutive,

  /// Operations overview — module metrics the admin may access (no super-admin KPIs).
  adminOperations,

  /// Module command-center home (Sales / Finance / Marketing / Construction).
  moduleHome,
}

/// Role → dashboard routing. Super Admin sees Mission Control; Admin sees
/// operations overview; module staff land on their command center only.
abstract final class DashboardAccessPolicy {
  static StaffDashboardKind kindFor(AuthSessionSnapshot session) {
    if (!session.isAuthenticated) return StaffDashboardKind.moduleHome;
    if (session.hasRole(AppRole.superAdmin)) {
      return StaffDashboardKind.superAdminExecutive;
    }
    if (session.hasRole(AppRole.admin)) {
      return StaffDashboardKind.adminOperations;
    }
    return StaffDashboardKind.moduleHome;
  }

  static bool isSuperAdmin(AuthSessionSnapshot session) =>
      session.hasRole(AppRole.superAdmin);

  static bool isAdmin(AuthSessionSnapshot session) =>
      session.hasRole(AppRole.admin) && !session.hasRole(AppRole.superAdmin);

  static bool canAccessExecutiveHome(AuthSessionSnapshot session) {
    final kind = kindFor(session);
    return kind == StaffDashboardKind.superAdminExecutive ||
        kind == StaffDashboardKind.adminOperations;
  }

  /// Post-login / sidebar Dashboard target for the active staff role.
  static String homeRouteFor(AuthSessionSnapshot session) {
    if (session.hasRole(AppRole.superAdmin) || session.hasRole(AppRole.admin)) {
      return RoutePaths.dashboard;
    }
    return switch (RoleNavPolicy.moduleNavRole(session)) {
      AppRole.salesTeam => RoutePaths.dashboardCrm,
      AppRole.finance => RoutePaths.dashboardFinance,
      AppRole.marketing => RoutePaths.dashboardMarketing,
      AppRole.constructionManager => RoutePaths.dashboardConstruction,
      _ => RoutePaths.dashboard,
    };
  }

  /// Redirect module staff away from `/dashboard` (Mission Control URL).
  static String? redirectIfWrongDashboardHome(
    AuthSessionSnapshot session,
    String path,
  ) {
    if (path != RoutePaths.dashboard) return null;
    if (!session.isAuthenticated) return null;
    if (canAccessExecutiveHome(session)) return null;
    final home = homeRouteFor(session);
    return home == RoutePaths.dashboard ? null : home;
  }

  /// Super-admin-only Mission Control modules (hidden from Admin operations view).
  static const superAdminOnlyModules = {
    'health',
    'briefing',
    'kpis',
    'insights',
    'risks',
    'schedule',
    'forecasts',
    'reports',
    'strategy',
  };

  /// Whether an executive dashboard module key is visible for this session.
  static bool isExecutiveModuleVisible(
    AuthSessionSnapshot session,
    String moduleKey,
  ) {
    if (isSuperAdmin(session)) return true;
    if (isAdmin(session)) {
      return !superAdminOnlyModules.contains(moduleKey);
    }
    return false;
  }
}
