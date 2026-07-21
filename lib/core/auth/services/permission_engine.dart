import 'package:hdhomesproject/core/auth/models/auth_session_snapshot.dart';
import 'package:hdhomesproject/core/constants/permissions.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/app_role.dart';

/// Resolves and caches permission slugs for the active session.
///
/// Prefer database-driven grants; [_roleDefaults] is offline fallback only.
/// Runtime policy evaluation (ownership, branch, approvals) lives in
/// [PolicyEngine] / [RbacService].
class PermissionEngine {
  const PermissionEngine();

  bool can(Set<String> permissions, String slug) {
    if (permissions.contains(slug)) return true;
    // Accept dotted aliases that map to legacy snake_case grants.
    final dotted = slug.contains('.') ? slug : null;
    if (dotted != null) {
      final legacy = slug.replaceAll('.', '_');
      // properties.view → view_properties heuristic
      final parts = slug.split('.');
      if (parts.length == 2) {
        final alt = '${parts[1]}_${parts[0]}';
        if (permissions.contains(alt) || permissions.contains(legacy)) {
          return true;
        }
      }
    }
    return false;
  }

  /// Fallback when DB RPC is unavailable — derive from known role mappings.
  Set<String> permissionsForRoles(List<AppRole> roles) {
    if (roles.contains(AppRole.superAdmin)) {
      return PermissionSlugs.all.toSet();
    }

    final perms = <String>{};
    for (final role in roles) {
      perms.addAll(_roleDefaults[role] ?? const {});
    }
    return perms;
  }

  AuthSessionSnapshot attachPermissions(
    AuthSessionSnapshot snapshot, {
    Set<String>? fromServer,
  }) {
    final roles = snapshot.roles;
    final resolved = fromServer ?? permissionsForRoles(roles);
    return snapshot.copyWith(permissions: resolved);
  }

  static const Map<AppRole, Set<String>> _roleDefaults = {
    AppRole.admin: {
      PermissionSlugs.viewProperties,
      PermissionSlugs.createProperty,
      PermissionSlugs.editProperty,
      PermissionSlugs.deleteProperty,
      PermissionSlugs.publishProperty,
      PermissionSlugs.manageUsers,
      PermissionSlugs.managePayments,
      PermissionSlugs.manageBlog,
      PermissionSlugs.manageMarketing,
      PermissionSlugs.manageConstruction,
      PermissionSlugs.manageCrm,
      PermissionSlugs.manageReports,
      PermissionSlugs.manageSettings,
    },
    AppRole.salesTeam: {
      PermissionSlugs.viewProperties,
      PermissionSlugs.manageCrm,
      PermissionSlugs.constructionRead,
      PermissionSlugs.constructionAnalytics,
    },
    AppRole.finance: {
      PermissionSlugs.viewProperties,
      PermissionSlugs.managePayments,
      PermissionSlugs.manageReports,
      PermissionSlugs.constructionRead,
      PermissionSlugs.constructionBudget,
      PermissionSlugs.constructionAnalytics,
      PermissionSlugs.constructionApprovals,
    },
    AppRole.marketing: {
      PermissionSlugs.viewProperties,
      PermissionSlugs.manageBlog,
      PermissionSlugs.manageMarketing,
      PermissionSlugs.constructionRead,
      PermissionSlugs.constructionAi,
    },
    AppRole.constructionManager: {
      PermissionSlugs.viewProperties,
      PermissionSlugs.manageConstruction,
      PermissionSlugs.constructionRead,
      PermissionSlugs.constructionWrite,
      PermissionSlugs.constructionProjects,
      PermissionSlugs.constructionMilestones,
      PermissionSlugs.constructionTasks,
      PermissionSlugs.constructionProcurement,
      PermissionSlugs.constructionBudget,
      PermissionSlugs.constructionQuality,
      PermissionSlugs.constructionSafety,
      PermissionSlugs.constructionAnalytics,
      PermissionSlugs.constructionAi,
      PermissionSlugs.constructionApprovals,
    },
    AppRole.client: {
      PermissionSlugs.viewProperties,
    },
    AppRole.investor: {
      PermissionSlugs.viewProperties,
      PermissionSlugs.manageReports,
    },
  };
}
