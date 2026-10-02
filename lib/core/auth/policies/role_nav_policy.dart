import 'package:hdhomesproject/core/auth/models/auth_session_snapshot.dart';
import 'package:hdhomesproject/core/auth/policies/dashboard_access_policy.dart';
import 'package:hdhomesproject/core/constants/permissions.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/app_role.dart';

/// Strict sidebar + route allowlists for module staff (Sales, Finance, etc.).
///
/// Module roles get a fixed menu — not every module where they have read access
/// in SQL. Super Admin and Admin use permission-based filtering instead.
enum StaffDocumentAudience { clients, investors, both }

abstract final class RoleNavPolicy {
  static bool usesStrictModuleNav(AuthSessionSnapshot session) {
    if (!session.isAuthenticated) return false;
    if (session.hasRole(AppRole.superAdmin)) return false;
    if (session.hasRole(AppRole.admin)) return false;
    return moduleNavRole(session) != null;
  }

  /// Module desk role used for sidebar allowlists (Sales, Finance, …).
  static AppRole? moduleNavRole(AuthSessionSnapshot session) {
    if (session.hasRole(AppRole.superAdmin) || session.hasRole(AppRole.admin)) {
      return null;
    }
    final primary = session.primaryRole;
    if (primary != null && _moduleAllowlists.containsKey(primary)) {
      return primary;
    }
    for (final role in session.roles) {
      if (_moduleAllowlists.containsKey(role)) return role;
    }
    return null;
  }

  static String portalTitleFor(AuthSessionSnapshot session) {
    if (session.hasRole(AppRole.superAdmin)) return 'Super Admin';
    if (session.hasRole(AppRole.admin)) return 'Admin Dashboard';
    return switch (moduleNavRole(session)) {
      AppRole.salesTeam => 'Sales Dashboard',
      AppRole.finance => 'Finance Dashboard',
      AppRole.marketing => 'Marketing Dashboard',
      AppRole.constructionManager => 'Construction Dashboard',
      _ => 'Staff Dashboard',
    };
  }

  /// Short brand under the logo. Sales, finance, and construction are not Admin Control.
  static String brandLineFor(AuthSessionSnapshot session) {
    if (session.hasRole(AppRole.superAdmin)) return 'SUPER ADMIN';
    if (session.hasRole(AppRole.admin)) return 'ADMIN CONTROL';
    return switch (moduleNavRole(session)) {
      AppRole.salesTeam => 'SALES DESK',
      AppRole.finance => 'FINANCE DESK',
      AppRole.marketing => 'MARKETING DESK',
      AppRole.constructionManager => 'CONSTRUCTION DESK',
      _ => 'STAFF DESK',
    };
  }

  static String workspaceLabelFor(AuthSessionSnapshot session) {
    if (session.hasRole(AppRole.superAdmin)) return 'Super Admin workspace';
    if (session.hasRole(AppRole.admin)) return 'Admin workspace';
    return switch (moduleNavRole(session)) {
      AppRole.salesTeam => 'Sales workspace',
      AppRole.finance => 'Finance workspace',
      AppRole.marketing => 'Marketing workspace',
      AppRole.constructionManager => 'Construction workspace',
      _ => 'Staff workspace',
    };
  }

  /// Who a role may issue a document to.
  ///
  /// Admin and super admin search clients and investors. Sales issue to
  /// clients. Finance issues to investors.
  static StaffDocumentAudience documentAudienceFor(
    AuthSessionSnapshot session,
  ) {
    if (session.hasRole(AppRole.superAdmin) || session.hasRole(AppRole.admin)) {
      return StaffDocumentAudience.both;
    }
    return switch (moduleNavRole(session)) {
      AppRole.salesTeam => _canManageInvestors(session)
          ? StaffDocumentAudience.both
          : StaffDocumentAudience.clients,
      AppRole.constructionManager => StaffDocumentAudience.clients,
      AppRole.finance => StaffDocumentAudience.investors,
      _ => StaffDocumentAudience.both,
    };
  }

  static String portalBreadcrumbRoot(AuthSessionSnapshot session) {
    if (session.hasRole(AppRole.superAdmin)) return 'Super Admin';
    if (session.hasRole(AppRole.admin)) return 'Admin';
    return switch (moduleNavRole(session)) {
      AppRole.salesTeam => 'Sales',
      AppRole.finance => 'Finance',
      AppRole.marketing => 'Marketing',
      AppRole.constructionManager => 'Construction',
      _ => 'Dashboard',
    };
  }

  /// Whether a dashboard path is in the module role's allowed set.
  static bool canAccessPath(AuthSessionSnapshot session, String path) {
    if (!path.startsWith(RoutePaths.dashboard)) return true;
    if (!usesStrictModuleNav(session)) return true;

    if (path == RoutePaths.dashboardProfile) return true;

    final home = DashboardAccessPolicy.homeRouteFor(session);
    if (path == RoutePaths.dashboard || path == home) return true;

    return _pathMatchesAllowlist(session, path);
  }

  /// Whether a sidebar item should show for module staff.
  static bool canSeeNavItem(AuthSessionSnapshot session, String path) {
    if (!usesStrictModuleNav(session)) return true;

    if (path == RoutePaths.dashboard) return true;

    return _pathMatchesAllowlist(session, path);
  }

  static bool _pathMatchesAllowlist(AuthSessionSnapshot session, String path) {
    final role = moduleNavRole(session);
    if (role == null) return false;
    final allowed = _moduleAllowlists[role];
    if (allowed == null) return false;

    // Platform Control Center / company profile is not a CMS desk route.
    if (path == RoutePaths.dashboardSettings ||
        path.startsWith('${RoutePaths.dashboardSettings}/') ||
        path == RoutePaths.dashboardWebsiteCompany) {
      return false;
    }

    for (final prefix in allowed) {
      if (path == prefix || path.startsWith('$prefix/')) return true;
    }

    if (role == AppRole.salesTeam &&
        _canManageInvestors(session) &&
        (path == RoutePaths.dashboardInvestors ||
            path.startsWith('${RoutePaths.dashboardInvestors}/'))) {
      return true;
    }
    return false;
  }

  static bool _canManageInvestors(AuthSessionSnapshot session) {
    return session.hasPermission(PermissionSlugs.investorsRead) ||
        session.hasPermission(PermissionSlugs.investorsWrite) ||
        session.hasPermission(PermissionSlugs.investorsTasks);
  }

  /// Sales — CRM desk + client workflow only (no Finance, Construction, etc.).
  static const _salesPaths = {
    RoutePaths.dashboardCrm,
    RoutePaths.dashboardClients,
    RoutePaths.dashboardClientApplications,
    RoutePaths.dashboardInspections,
    RoutePaths.dashboardConsultations,
    RoutePaths.dashboardCallbacks,
    RoutePaths.dashboardDocuments,
    RoutePaths.dashboardSupport,
    RoutePaths.dashboardLiveChat,
  };

  /// Finance — treasury desk only.
  static const _financePaths = {
    RoutePaths.dashboardFinance,
    RoutePaths.dashboardDocuments,
    RoutePaths.dashboardInvestors,
    RoutePaths.dashboardReports,
    RoutePaths.dashboardAnalytics,
    RoutePaths.dashboardSupport,
    RoutePaths.dashboardLiveChat,
  };

  /// Marketing — website CMS + marketing hub.
  static const _marketingPaths = {
    RoutePaths.dashboardMarketing,
    RoutePaths.dashboardWebsite,
    RoutePaths.dashboardBlog,
    RoutePaths.dashboardBanners,
    RoutePaths.dashboardSeo,
    RoutePaths.dashboardMedia,
    RoutePaths.dashboardDocuments,
    RoutePaths.dashboardSupport,
    RoutePaths.dashboardLiveChat,
  };

  /// Construction — project desk only.
  static const _constructionPaths = {
    RoutePaths.dashboardConstruction,
    RoutePaths.dashboardDocuments,
    RoutePaths.dashboardSupport,
    RoutePaths.dashboardLiveChat,
  };

  static const Map<AppRole, Set<String>> _moduleAllowlists = {
    AppRole.salesTeam: _salesPaths,
    AppRole.finance: _financePaths,
    AppRole.marketing: _marketingPaths,
    AppRole.constructionManager: _constructionPaths,
  };
}
