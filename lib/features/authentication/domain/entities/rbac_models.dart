import 'package:hdhomesproject/core/constants/permissions.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/app_role.dart';

/// Policy evaluation outcome from the Enterprise Authorization Engine.
enum PolicyDecision {
  allow,
  deny,
  conditional;

  String get slug => name;

  bool get isAllowed => this == PolicyDecision.allow;
}

enum RoleLifecycle {
  active,
  archived,
  draft;

  String get slug => name;

  static RoleLifecycle fromSlug(String? raw) {
    return switch ((raw ?? 'active').toLowerCase()) {
      'archived' => RoleLifecycle.archived,
      'draft' => RoleLifecycle.draft,
      _ => RoleLifecycle.active,
    };
  }
}

enum ApprovalActionType {
  deleteProperty,
  largeRefund,
  roleChange,
  breakGlass,
  exportSensitive,
  other;

  String get slug => switch (this) {
        ApprovalActionType.deleteProperty => 'delete_property',
        ApprovalActionType.largeRefund => 'large_refund',
        ApprovalActionType.roleChange => 'role_change',
        ApprovalActionType.breakGlass => 'break_glass',
        ApprovalActionType.exportSensitive => 'export_sensitive',
        ApprovalActionType.other => 'other',
      };
}

/// Canonical permission definition — supports both `module.action` and legacy slugs.
class PermissionDefinition {
  const PermissionDefinition({
    required this.slug,
    required this.name,
    required this.module,
    required this.action,
    this.description,
    this.legacySlug,
  });

  final String slug;
  final String name;
  final String module;
  final String action;
  final String? description;

  /// Existing DB slug if different from canonical dotted form.
  final String? legacySlug;

  String get effectiveDbSlug => legacySlug ?? slug;

  factory PermissionDefinition.fromRow(Map<String, dynamic> row) {
    final slug = row['slug'] as String? ?? '';
    final module = row['module'] as String? ?? 'system';
    final parts = slug.contains('.') ? slug.split('.') : <String>[];
    return PermissionDefinition(
      slug: slug,
      name: row['name'] as String? ?? slug,
      module: module,
      action: parts.length >= 2 ? parts[1] : slug,
      description: row['description'] as String?,
      legacySlug: row['legacy_slug'] as String?,
    );
  }
}

class RoleDefinition {
  const RoleDefinition({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.isSystem = false,
    this.lifecycle = RoleLifecycle.active,
    this.permissionSlugs = const {},
    this.memberCount = 0,
  });

  final String id;
  final String name;
  final String slug;
  final String? description;
  final bool isSystem;
  final RoleLifecycle lifecycle;
  final Set<String> permissionSlugs;
  final int memberCount;

  bool get isSuperAdmin => slug == AppRole.superAdmin.slug;

  factory RoleDefinition.fromRow(
    Map<String, dynamic> row, {
    Set<String> permissions = const {},
  }) {
    return RoleDefinition(
      id: row['id'] as String,
      name: row['name'] as String? ?? 'Role',
      slug: row['slug'] as String? ?? '',
      description: row['description'] as String?,
      isSystem: row['is_system'] as bool? ?? false,
      lifecycle: RoleLifecycle.fromSlug(
        row['lifecycle'] as String? ?? row['status'] as String?,
      ),
      permissionSlugs: permissions,
      memberCount: (row['member_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class PermissionGroup {
  const PermissionGroup({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.permissionSlugs = const {},
  });

  final String id;
  final String name;
  final String slug;
  final String? description;
  final Set<String> permissionSlugs;

  factory PermissionGroup.fromRow(
    Map<String, dynamic> row, {
    Set<String> permissions = const {},
  }) {
    return PermissionGroup(
      id: row['id'] as String,
      name: row['name'] as String? ?? 'Group',
      slug: row['slug'] as String? ?? '',
      description: row['description'] as String?,
      permissionSlugs: permissions,
    );
  }
}

class ApprovalPolicy {
  const ApprovalPolicy({
    required this.id,
    required this.name,
    required this.actionType,
    required this.approverRoleSlug,
    this.enabled = true,
    this.thresholdAmount,
    this.description,
  });

  final String id;
  final String name;
  final ApprovalActionType actionType;
  final String approverRoleSlug;
  final bool enabled;
  final double? thresholdAmount;
  final String? description;

  factory ApprovalPolicy.fromRow(Map<String, dynamic> row) {
    final action = (row['action_type'] as String? ?? 'other').toLowerCase();
    return ApprovalPolicy(
      id: row['id'] as String,
      name: row['name'] as String? ?? 'Policy',
      actionType: switch (action) {
        'delete_property' => ApprovalActionType.deleteProperty,
        'large_refund' => ApprovalActionType.largeRefund,
        'role_change' => ApprovalActionType.roleChange,
        'break_glass' => ApprovalActionType.breakGlass,
        'export_sensitive' => ApprovalActionType.exportSensitive,
        _ => ApprovalActionType.other,
      },
      approverRoleSlug: row['approver_role_slug'] as String? ?? 'admin',
      enabled: row['enabled'] as bool? ?? true,
      thresholdAmount: (row['threshold_amount'] as num?)?.toDouble(),
      description: row['description'] as String?,
    );
  }
}

class AuthorizationContext {
  const AuthorizationContext({
    this.userId,
    this.roles = const [],
    this.permissions = const {},
    this.departmentId,
    this.branchId,
    this.resourceOwnerId,
    this.resourceBranchId,
    this.amount,
    this.breakGlassActive = false,
  });

  final String? userId;
  final List<AppRole> roles;
  final Set<String> permissions;
  final String? departmentId;
  final String? branchId;
  final String? resourceOwnerId;
  final String? resourceBranchId;
  final double? amount;
  final bool breakGlassActive;

  bool get isSuperAdmin => roles.contains(AppRole.superAdmin);
}

class PolicyEvaluation {
  const PolicyEvaluation({
    required this.decision,
    required this.permission,
    this.reason,
    this.requiresApproval = false,
    this.approverRoleSlug,
  });

  final PolicyDecision decision;
  final String permission;
  final String? reason;
  final bool requiresApproval;
  final String? approverRoleSlug;
}

/// Cell in the Permission Matrix — role × permission.
class MatrixCell {
  const MatrixCell({
    required this.roleSlug,
    required this.permissionSlug,
    required this.granted,
  });

  final String roleSlug;
  final String permissionSlug;
  final bool granted;
}

class PermissionMatrix {
  const PermissionMatrix({
    required this.roles,
    required this.permissions,
    required this.cells,
  });

  final List<RoleDefinition> roles;
  final List<PermissionDefinition> permissions;
  final Map<String, bool> cells;

  /// Key: `$roleSlug|$permissionSlug`
  static String cellKey(String roleSlug, String permissionSlug) =>
      '$roleSlug|$permissionSlug';

  bool isGranted(String roleSlug, String permissionSlug) =>
      cells[cellKey(roleSlug, permissionSlug)] ?? false;
}

class RbacAnalytics {
  const RbacAnalytics({
    required this.rolesInUse,
    required this.permissionCount,
    required this.systemRoles,
    required this.customRoles,
    required this.privilegedAccounts,
    required this.accessDeniedEvents,
    required this.openApprovals,
    required this.breakGlassSessions,
  });

  final int rolesInUse;
  final int permissionCount;
  final int systemRoles;
  final int customRoles;
  final int privilegedAccounts;
  final int accessDeniedEvents;
  final int openApprovals;
  final int breakGlassSessions;
}

class RbacSnapshot {
  const RbacSnapshot({
    required this.roles,
    required this.permissions,
    required this.groups,
    required this.matrix,
    required this.policies,
    required this.analytics,
  });

  final List<RoleDefinition> roles;
  final List<PermissionDefinition> permissions;
  final List<PermissionGroup> groups;
  final PermissionMatrix matrix;
  final List<ApprovalPolicy> policies;
  final RbacAnalytics analytics;
}

/// Enterprise Policy Engine — centralized allow / deny / conditional.
abstract final class PolicyEngine {
  static PolicyEvaluation evaluate({
    required String permission,
    required AuthorizationContext context,
    List<ApprovalPolicy> approvalPolicies = const [],
    bool ownershipRequired = false,
    bool branchScoped = false,
  }) {
    if (context.breakGlassActive) {
      return PolicyEvaluation(
        decision: PolicyDecision.allow,
        permission: permission,
        reason: 'break_glass',
      );
    }

    if (context.isSuperAdmin) {
      return PolicyEvaluation(
        decision: PolicyDecision.allow,
        permission: permission,
        reason: 'super_admin',
      );
    }

    final normalized = PermissionCatalog.normalize(permission);
    final hasPerm = context.permissions.contains(normalized) ||
        context.permissions.contains(permission) ||
        PermissionCatalog.aliasesOf(normalized)
            .any(context.permissions.contains);

    if (!hasPerm) {
      return PolicyEvaluation(
        decision: PolicyDecision.deny,
        permission: permission,
        reason: 'missing_permission',
      );
    }

    if (ownershipRequired &&
        context.resourceOwnerId != null &&
        context.userId != null &&
        context.resourceOwnerId != context.userId) {
      return PolicyEvaluation(
        decision: PolicyDecision.conditional,
        permission: permission,
        reason: 'ownership_mismatch',
      );
    }

    if (branchScoped &&
        context.branchId != null &&
        context.resourceBranchId != null &&
        context.branchId != context.resourceBranchId) {
      return PolicyEvaluation(
        decision: PolicyDecision.conditional,
        permission: permission,
        reason: 'branch_scope_mismatch',
      );
    }

    final matching = approvalPolicies.where((p) {
      if (!p.enabled) return false;
      if (p.actionType == ApprovalActionType.largeRefund &&
          context.amount != null &&
          p.thresholdAmount != null &&
          context.amount! >= p.thresholdAmount!) {
        return true;
      }
      return PermissionCatalog.matchesApproval(permission, p.actionType);
    }).toList();

    if (matching.isNotEmpty) {
      return PolicyEvaluation(
        decision: PolicyDecision.conditional,
        permission: permission,
        reason: 'approval_required',
        requiresApproval: true,
        approverRoleSlug: matching.first.approverRoleSlug,
      );
    }

    return PolicyEvaluation(
      decision: PolicyDecision.allow,
      permission: permission,
      reason: 'granted',
    );
  }

  static Set<String> expandGroupPermissions(
    Iterable<PermissionGroup> groups,
    Iterable<String> groupSlugs,
  ) {
    final bySlug = {for (final g in groups) g.slug: g};
    final out = <String>{};
    for (final slug in groupSlugs) {
      final g = bySlug[slug];
      if (g != null) out.addAll(g.permissionSlugs);
    }
    return out;
  }
}

/// Catalog of enterprise permissions — dotted + legacy snake_case.
abstract final class PermissionCatalog {
  static const List<PermissionDefinition> defaults = [
    // Properties
    PermissionDefinition(
      slug: 'properties.view',
      name: 'View Properties',
      module: 'properties',
      action: 'view',
      legacySlug: PermissionSlugs.viewProperties,
    ),
    PermissionDefinition(
      slug: 'properties.create',
      name: 'Create Properties',
      module: 'properties',
      action: 'create',
      legacySlug: PermissionSlugs.createProperty,
    ),
    PermissionDefinition(
      slug: 'properties.edit',
      name: 'Edit Properties',
      module: 'properties',
      action: 'edit',
      legacySlug: PermissionSlugs.editProperty,
    ),
    PermissionDefinition(
      slug: 'properties.delete',
      name: 'Delete Properties',
      module: 'properties',
      action: 'delete',
      legacySlug: PermissionSlugs.deleteProperty,
    ),
    PermissionDefinition(
      slug: 'properties.publish',
      name: 'Publish Properties',
      module: 'properties',
      action: 'publish',
      legacySlug: PermissionSlugs.publishProperty,
    ),
    PermissionDefinition(
      slug: 'properties.archive',
      name: 'Archive Properties',
      module: 'properties',
      action: 'archive',
      legacySlug: 'archive_property',
    ),
    // Users
    PermissionDefinition(
      slug: 'users.view',
      name: 'View Users',
      module: 'users',
      action: 'view',
      legacySlug: 'view_users',
    ),
    PermissionDefinition(
      slug: 'users.create',
      name: 'Create Users',
      module: 'users',
      action: 'create',
      legacySlug: 'create_users',
    ),
    PermissionDefinition(
      slug: 'users.edit',
      name: 'Edit Users',
      module: 'users',
      action: 'edit',
      legacySlug: PermissionSlugs.manageUsers,
    ),
    PermissionDefinition(
      slug: 'users.delete',
      name: 'Delete Users',
      module: 'users',
      action: 'delete',
      legacySlug: 'delete_users',
    ),
    PermissionDefinition(
      slug: 'users.export',
      name: 'Export Users',
      module: 'users',
      action: 'export',
      legacySlug: 'export_users',
    ),
    // Roles / system
    PermissionDefinition(
      slug: 'roles.manage',
      name: 'Manage Roles',
      module: 'roles',
      action: 'manage',
      legacySlug: PermissionSlugs.manageRoles,
    ),
    PermissionDefinition(
      slug: 'permissions.configure',
      name: 'Configure Permissions',
      module: 'roles',
      action: 'configure',
      legacySlug: 'configure_permissions',
    ),
    // Finance
    PermissionDefinition(
      slug: 'finance.view',
      name: 'View Transactions',
      module: 'finance',
      action: 'view',
      legacySlug: PermissionSlugs.managePayments,
    ),
    PermissionDefinition(
      slug: 'finance.export',
      name: 'Export Finance Reports',
      module: 'finance',
      action: 'export',
      legacySlug: 'export_finance',
    ),
    PermissionDefinition(
      slug: 'finance.refund',
      name: 'Manage Refunds',
      module: 'finance',
      action: 'refund',
      legacySlug: 'manage_refunds',
    ),
    // CRM
    PermissionDefinition(
      slug: 'crm.view',
      name: 'View Leads',
      module: 'crm',
      action: 'view',
      legacySlug: PermissionSlugs.manageCrm,
    ),
    PermissionDefinition(
      slug: 'crm.manage',
      name: 'Manage CRM',
      module: 'crm',
      action: 'manage',
      legacySlug: PermissionSlugs.manageCrm,
    ),
    // Investments
    PermissionDefinition(
      slug: 'investments.view',
      name: 'View Investments',
      module: 'investments',
      action: 'view',
      legacySlug: 'view_investments',
    ),
    PermissionDefinition(
      slug: 'investments.approve',
      name: 'Approve Investments',
      module: 'investments',
      action: 'approve',
      legacySlug: 'approve_investments',
    ),
    // Marketing
    PermissionDefinition(
      slug: 'marketing.campaigns',
      name: 'Publish Campaigns',
      module: 'marketing',
      action: 'campaigns',
      legacySlug: PermissionSlugs.manageMarketing,
    ),
    PermissionDefinition(
      slug: 'blog.publish',
      name: 'Publish Blog',
      module: 'marketing',
      action: 'publish',
      legacySlug: PermissionSlugs.manageBlog,
    ),
    // Support
    PermissionDefinition(
      slug: 'support.tickets',
      name: 'Manage Tickets',
      module: 'support',
      action: 'tickets',
      legacySlug: 'manage_tickets',
    ),
    // Reports / settings / org / audit
    PermissionDefinition(
      slug: 'reports.export',
      name: 'Export Reports',
      module: 'reports',
      action: 'export',
      legacySlug: PermissionSlugs.manageReports,
    ),
    PermissionDefinition(
      slug: 'settings.update',
      name: 'Update Settings',
      module: 'settings',
      action: 'update',
      legacySlug: PermissionSlugs.manageSettings,
    ),
    PermissionDefinition(
      slug: 'construction.manage',
      name: 'Manage Construction',
      module: 'construction',
      action: 'manage',
      legacySlug: PermissionSlugs.manageConstruction,
    ),
    PermissionDefinition(
      slug: 'organization.view',
      name: 'View Organization',
      module: 'organization',
      action: 'view',
      legacySlug: 'view_organization',
    ),
    PermissionDefinition(
      slug: 'audit.view',
      name: 'View Audit Logs',
      module: 'observability',
      action: 'view',
      legacySlug: 'view_audit_logs',
    ),
  ];

  static String normalize(String permission) {
    final p = permission.trim().toLowerCase();
    for (final def in defaults) {
      if (def.slug == p || def.legacySlug == p || def.effectiveDbSlug == p) {
        return def.effectiveDbSlug;
      }
    }
    return p;
  }

  static Set<String> aliasesOf(String permission) {
    final n = normalize(permission);
    final out = <String>{n, permission};
    for (final def in defaults) {
      if (def.effectiveDbSlug == n || def.slug == n) {
        out.add(def.slug);
        out.add(def.effectiveDbSlug);
        if (def.legacySlug != null) out.add(def.legacySlug!);
      }
    }
    return out;
  }

  static bool matchesApproval(String permission, ApprovalActionType type) {
    final n = normalize(permission);
    return switch (type) {
      ApprovalActionType.deleteProperty =>
        n == PermissionSlugs.deleteProperty || n == 'properties.delete',
      ApprovalActionType.roleChange =>
        n == PermissionSlugs.manageRoles || n == 'roles.manage',
      ApprovalActionType.exportSensitive =>
        n.contains('export') || n == PermissionSlugs.manageReports,
      ApprovalActionType.largeRefund =>
        n.contains('refund') || n == 'finance.refund',
      ApprovalActionType.breakGlass => n.contains('break'),
      ApprovalActionType.other => false,
    };
  }

  static const defaultGroups = <({String slug, String name, List<String> perms})>[
    (
      slug: 'sales_management',
      name: 'Sales Management',
      perms: [
        PermissionSlugs.viewProperties,
        PermissionSlugs.editProperty,
        PermissionSlugs.manageCrm,
        PermissionSlugs.manageReports,
      ],
    ),
    (
      slug: 'finance_management',
      name: 'Finance Management',
      perms: [
        PermissionSlugs.managePayments,
        PermissionSlugs.manageReports,
        'manage_refunds',
      ],
    ),
    (
      slug: 'support_management',
      name: 'Support Management',
      perms: ['manage_tickets'],
    ),
  ];
}
