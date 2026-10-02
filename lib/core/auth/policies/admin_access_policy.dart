import 'package:hdhomesproject/core/auth/models/auth_session_snapshot.dart';
import 'package:hdhomesproject/core/auth/policies/dashboard_access_policy.dart';
import 'package:hdhomesproject/core/auth/policies/role_nav_policy.dart';
import 'package:hdhomesproject/core/auth/services/permission_engine.dart';
import 'package:hdhomesproject/core/constants/permissions.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/navigation/nav_item.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/app_role.dart';

/// Role-scoped admin dashboard access — nav visibility and route guards.
abstract final class AdminAccessPolicy {
  static const _engine = PermissionEngine();

  // ── Shared permission bundles (match Supabase role_permissions seeds) ─────

  static const website = [
    PermissionSlugs.marketingCms,
    PermissionSlugs.manageMarketing,
    PermissionSlugs.manageBlog,
    PermissionSlugs.marketingRead,
    PermissionSlugs.marketingWrite,
  ];

  static const properties = [
    PermissionSlugs.viewProperties,
    PermissionSlugs.propertiesRead,
    PermissionSlugs.propertiesWrite,
    PermissionSlugs.createProperty,
    PermissionSlugs.editProperty,
    PermissionSlugs.propertiesInspections,
    PermissionSlugs.consultationsView,
    PermissionSlugs.consultationsManage,
    PermissionSlugs.callbacksView,
    PermissionSlugs.callbacksManage,
  ];

  static const sales = [
    PermissionSlugs.manageCrm,
    PermissionSlugs.crmRead,
    PermissionSlugs.crmWrite,
    PermissionSlugs.salesRead,
    PermissionSlugs.salesWrite,
  ];

  static const investors = [
    PermissionSlugs.investorsRead,
    PermissionSlugs.investorsWrite,
  ];

  /// Nav + route access for the investor desk (IMP). Sales leadership often
  /// needs read access alongside dedicated investor ops roles.
  static const investorsDesk = [
    PermissionSlugs.investorsRead,
    PermissionSlugs.investorsWrite,
    PermissionSlugs.manageCrm,
    PermissionSlugs.crmRead,
    PermissionSlugs.viewExecutiveDashboard,
  ];

  static const clientApplications = [
    PermissionSlugs.manageCrm,
    PermissionSlugs.crmRead,
    PermissionSlugs.salesRead,
    PermissionSlugs.salesBookings,
  ];

  static const construction = [
    PermissionSlugs.manageConstruction,
    PermissionSlugs.constructionRead,
    PermissionSlugs.constructionWrite,
  ];

  static const finance = [
    PermissionSlugs.managePayments,
    PermissionSlugs.financeRead,
    PermissionSlugs.financeWrite,
  ];

  static const documents = [
    PermissionSlugs.documentsRead,
    PermissionSlugs.documentsWrite,
  ];

  static const marketingHub = [
    PermissionSlugs.manageMarketing,
    PermissionSlugs.manageBlog,
    PermissionSlugs.marketingRead,
    PermissionSlugs.marketingWrite,
  ];

  static const reports = [
    PermissionSlugs.manageReports,
    PermissionSlugs.analyticsReports,
    PermissionSlugs.generateExecutiveReports,
  ];

  static const analytics = [PermissionSlugs.analyticsRead];

  static const support = [
    PermissionSlugs.supportRead,
    PermissionSlugs.supportWrite,
  ];

  static const communications = [
    PermissionSlugs.supportRead,
    PermissionSlugs.supportWrite,
    PermissionSlugs.manageSettings,
  ];

  static const users = [
    PermissionSlugs.manageUsers,
    PermissionSlugs.viewOrganization,
    PermissionSlugs.manageStaff,
  ];

  static const roles = [
    PermissionSlugs.manageRoles,
    PermissionSlugs.configurePermissions,
  ];

  static const settings = [PermissionSlugs.manageSettings];

  static const activityLogs = [PermissionSlugs.viewAuditLogs];

  static const aiHub = [PermissionSlugs.aihubRead, PermissionSlugs.aihubAdmin];

  /// Paths open to every staff role without extra permission slugs.
  static const staffOpenPaths = {RoutePaths.dashboardProfile};

  /// Longest-prefix-first route rules for `/dashboard/*`.
  static const _routeRules = <_RouteRule>[
    _RouteRule(RoutePaths.dashboardRoles, roles),
    _RouteRule(RoutePaths.dashboardPlatformUsers, users),
    _RouteRule(RoutePaths.dashboardUsers, users),
    _RouteRule(RoutePaths.dashboardOrganization, users),
    _RouteRule(RoutePaths.dashboardSettings, settings),
    // Company Profile is the Settings alias — require manage_settings, not CMS.
    _RouteRule(RoutePaths.dashboardWebsiteCompany, settings),
    _RouteRule(RoutePaths.dashboardActivityLogs, activityLogs),
    _RouteRule(RoutePaths.aiGovernance, aiHub),
    _RouteRule(RoutePaths.dashboardWebsite, website),
    _RouteRule(RoutePaths.dashboardBlog, website),
    _RouteRule(RoutePaths.dashboardMedia, website),
    _RouteRule(RoutePaths.dashboardBanners, website),
    _RouteRule(RoutePaths.dashboardSeo, website),
    _RouteRule(RoutePaths.dashboardEstates, properties),
    _RouteRule(RoutePaths.dashboardProperties, properties),
    _RouteRule(RoutePaths.dashboardInspections, properties),
    _RouteRule(RoutePaths.dashboardConsultations, properties),
    _RouteRule(RoutePaths.dashboardCallbacks, properties),
    _RouteRule(RoutePaths.dashboardCrm, sales),
    _RouteRule(RoutePaths.dashboardClients, sales),
    _RouteRule(RoutePaths.dashboardInvestors, investorsDesk),
    _RouteRule(RoutePaths.dashboardClientApplications, clientApplications),
    _RouteRule(RoutePaths.dashboardConstruction, construction),
    _RouteRule(RoutePaths.dashboardFinance, finance),
    _RouteRule(RoutePaths.dashboardDocuments, documents),
    _RouteRule(RoutePaths.dashboardMarketing, marketingHub),
    _RouteRule(RoutePaths.dashboardReports, reports),
    _RouteRule(RoutePaths.dashboardAnalytics, analytics),
    _RouteRule(RoutePaths.dashboardSupport, support),
    _RouteRule(RoutePaths.dashboardLiveChat, support),
    _RouteRule(RoutePaths.kycCompliance, users),
    _RouteRule(RoutePaths.adminCommunications, communications),
    _RouteRule(RoutePaths.personalizationAnalytics, analytics),
    _RouteRule(RoutePaths.searchInsights, analytics),
  ];

  static bool isStaffWithDashboardAccess(AuthSessionSnapshot session) {
    if (!session.isAuthenticated) return false;
    if (session.hasRole(AppRole.superAdmin)) return true;
    return session.roles.any((r) => r.canAccessDashboard);
  }

  static bool canAny(AuthSessionSnapshot session, List<String> slugs) {
    if (!session.isAuthenticated) return false;
    if (session.hasRole(AppRole.superAdmin)) return true;
    for (final slug in slugs) {
      if (_engine.can(session.permissions, slug)) return true;
    }
    return false;
  }

  static bool canAccessNavItem(AuthSessionSnapshot session, NavItem item) {
    if (!isStaffWithDashboardAccess(session)) return false;

    // Module staff (Sales, Finance, …) — strict role menu, not broad SQL reads.
    if (RoleNavPolicy.usesStrictModuleNav(session)) {
      return RoleNavPolicy.canSeeNavItem(session, item.path);
    }

    final required = item.anyOfPermissions;
    if (required == null) return true;
    if (required.isEmpty) return false;
    return canAny(session, required);
  }

  static List<NavItem> filterNavItems(
    List<NavItem> items,
    AuthSessionSnapshot session,
  ) {
    if (!isStaffWithDashboardAccess(session)) return const [];

    final filtered = <NavItem>[];
    for (final item in items) {
      if (item.isSectionHeader || item.isDivider) {
        filtered.add(item);
        continue;
      }

      final childItems = item.hasChildren
          ? filterNavItems(item.children, session)
          : const <NavItem>[];

      final selfVisible = canAccessNavItem(session, item);
      if (!selfVisible && childItems.isEmpty) continue;

      final home = DashboardAccessPolicy.homeRouteFor(session);
      final path =
          item.path == RoutePaths.dashboard && home != RoutePaths.dashboard
          ? home
          : item.path;

      filtered.add(
        NavItem(
          label: item.label,
          path: path,
          icon: item.icon,
          children: childItems,
          isDivider: item.isDivider,
          isSectionHeader: item.isSectionHeader,
          badge: item.badge,
          isDestructive: item.isDestructive,
          anyOfPermissions: item.anyOfPermissions,
        ),
      );
    }

    return _trimOrphanSectionHeaders(filtered);
  }

  static List<NavItem> _trimOrphanSectionHeaders(List<NavItem> items) {
    final result = <NavItem>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item.isSectionHeader) {
        final hasFollowingItem = items
            .skip(i + 1)
            .any((next) => !next.isSectionHeader && !next.isDivider);
        if (!hasFollowingItem) continue;
      }
      result.add(item);
    }
    return result;
  }

  /// Returns `null` when the path is open to all staff; otherwise required slugs.
  static List<String>? requiredPermissionsForPath(String path) {
    if (staffOpenPaths.contains(path)) return null;
    if (!path.startsWith(RoutePaths.dashboard)) return null;

    for (final rule in _routeRules) {
      if (path == rule.prefix || path.startsWith('${rule.prefix}/')) {
        return rule.anyOf;
      }
    }

    // Unknown dashboard sub-routes: admin/super_admin only (via broad grants).
    return settings;
  }

  static bool canAccessDashboardPath(AuthSessionSnapshot session, String path) {
    if (!path.startsWith(RoutePaths.dashboard)) return true;
    if (!isStaffWithDashboardAccess(session)) return false;

    if (path == RoutePaths.dashboard) {
      return DashboardAccessPolicy.canAccessExecutiveHome(session);
    }

    // Module staff — role allowlist overrides SQL read grants.
    if (RoleNavPolicy.usesStrictModuleNav(session)) {
      return RoleNavPolicy.canAccessPath(session, path);
    }

    final role = session.primaryRole;
    if (role != null && !role.canAccessDashboard && !role.isStaff) {
      return false;
    }

    final required = requiredPermissionsForPath(path);
    if (required == null) return true;
    return canAny(session, required);
  }
}

class _RouteRule {
  const _RouteRule(this.prefix, this.anyOf);

  final String prefix;
  final List<String> anyOf;
}
