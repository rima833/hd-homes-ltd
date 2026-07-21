import 'dart:async';

import 'package:hdhomesproject/features/authentication/domain/entities/app_role.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/observability_models.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/rbac_models.dart';
import 'package:hdhomesproject/features/authentication/domain/services/audit_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Enterprise RBAC service — roles, matrix, groups, approvals (no hardcoded grants).
class RbacService {
  RbacService({
    required AuditService audit,
    SupabaseClient? client,
  })  : _audit = audit,
        _client = client;

  final AuditService _audit;
  final SupabaseClient? _client;

  final Map<String, Set<String>> _localRolePerms = {};
  final List<RoleDefinition> _localRoles = [];
  final List<PermissionGroup> _localGroups = [];
  int _accessDenied = 0;

  bool get isConfigured => _client != null;

  Future<RbacSnapshot> loadSnapshot() async {
    final roles = await listRoles();
    final permissions = await listPermissions();
    final groups = await listGroups();
    final policies = await listApprovalPolicies();
    final matrix = buildMatrix(roles, permissions);
    final analytics = RbacAnalytics(
      rolesInUse: roles.where((r) => r.lifecycle == RoleLifecycle.active).length,
      permissionCount: permissions.length,
      systemRoles: roles.where((r) => r.isSystem).length,
      customRoles: roles.where((r) => !r.isSystem).length,
      privilegedAccounts: roles
          .where((r) =>
              r.slug == AppRole.superAdmin.slug || r.slug == AppRole.admin.slug)
          .fold<int>(0, (a, r) => a + r.memberCount),
      accessDeniedEvents: _accessDenied,
      openApprovals: 0,
      breakGlassSessions: 0,
    );
    return RbacSnapshot(
      roles: roles,
      permissions: permissions,
      groups: groups,
      matrix: matrix,
      policies: policies,
      analytics: analytics,
    );
  }

  PermissionMatrix buildMatrix(
    List<RoleDefinition> roles,
    List<PermissionDefinition> permissions,
  ) {
    final cells = <String, bool>{};
    for (final role in roles) {
      for (final perm in permissions) {
        final granted = role.permissionSlugs.contains(perm.effectiveDbSlug) ||
            role.permissionSlugs.contains(perm.slug) ||
            (perm.legacySlug != null &&
                role.permissionSlugs.contains(perm.legacySlug));
        cells[PermissionMatrix.cellKey(role.slug, perm.effectiveDbSlug)] =
            granted;
      }
    }
    return PermissionMatrix(
      roles: roles,
      permissions: permissions,
      cells: cells,
    );
  }

  Future<List<RoleDefinition>> listRoles() async {
    final client = _client;
    if (client == null) return _ensureLocalRoles();

    try {
      final rows = await client
          .from('roles')
          .select()
          .eq('is_deleted', false)
          .order('name');
      final rolePerms = await _loadAllRolePermissions();
      return (rows as List).map((raw) {
        final map = Map<String, dynamic>.from(raw as Map);
        final id = map['id'] as String;
        return RoleDefinition.fromRow(
          map,
          permissions: rolePerms[id] ?? const {},
        );
      }).toList();
    } catch (_) {
      return _ensureLocalRoles();
    }
  }

  Future<List<PermissionDefinition>> listPermissions() async {
    final client = _client;
    if (client == null) return PermissionCatalog.defaults;

    try {
      final rows = await client
          .from('permissions')
          .select()
          .eq('is_deleted', false)
          .order('module')
          .order('name');
      final fromDb = (rows as List)
          .map(
            (e) =>
                PermissionDefinition.fromRow(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
      if (fromDb.isEmpty) return PermissionCatalog.defaults;
      // Merge catalog metadata (dotted aliases) onto DB rows.
      return fromDb.map((db) {
        PermissionDefinition? catalog;
        for (final c in PermissionCatalog.defaults) {
          if (c.effectiveDbSlug == db.slug ||
              c.slug == db.slug ||
              c.legacySlug == db.slug) {
            catalog = c;
            break;
          }
        }
        if (catalog == null) return db;
        return PermissionDefinition(
          slug: catalog.slug,
          name: db.name,
          module: db.module.isNotEmpty ? db.module : catalog.module,
          action: catalog.action,
          description: db.description ?? catalog.description,
          legacySlug: db.slug,
        );
      }).toList();
    } catch (_) {
      return PermissionCatalog.defaults;
    }
  }

  Future<List<PermissionGroup>> listGroups() async {
    final client = _client;
    if (client == null) return _ensureLocalGroups();

    try {
      final rows = await client.from('permission_groups').select().order('name');
      final result = <PermissionGroup>[];
      for (final raw in rows as List) {
        final map = Map<String, dynamic>.from(raw as Map);
        final id = map['id'] as String;
        final perms = await _groupPermissionSlugs(id);
        result.add(PermissionGroup.fromRow(map, permissions: perms));
      }
      if (result.isEmpty) return _ensureLocalGroups();
      return result;
    } catch (_) {
      return _ensureLocalGroups();
    }
  }

  Future<List<ApprovalPolicy>> listApprovalPolicies() async {
    final client = _client;
    if (client == null) return _defaultPolicies();

    try {
      final rows = await client.from('approval_policies').select().order('name');
      final list = (rows as List)
          .map((e) => ApprovalPolicy.fromRow(Map<String, dynamic>.from(e as Map)))
          .toList();
      if (list.isEmpty) return _defaultPolicies();
      return list;
    } catch (_) {
      return _defaultPolicies();
    }
  }

  PolicyEvaluation authorize({
    required String permission,
    required AuthorizationContext context,
    bool ownershipRequired = false,
    bool branchScoped = false,
    List<ApprovalPolicy> policies = const [],
  }) {
    final result = PolicyEngine.evaluate(
      permission: permission,
      context: context,
      approvalPolicies: policies,
      ownershipRequired: ownershipRequired,
      branchScoped: branchScoped,
    );
    if (result.decision == PolicyDecision.deny) {
      _accessDenied++;
      unawaited(
        _audit.publish(
          AuditPublishRequest(
            action: 'access_denied',
            module: 'rbac',
            category: AuditEventCategory.security,
            userId: context.userId,
            severity: AuditSeverity.warning,
            status: AuditResultStatus.denied,
            reason: result.reason,
            metadata: {'permission': permission},
          ),
        ),
      );
    }
    return result;
  }

  Future<void> setRolePermission({
    required String roleId,
    required String roleSlug,
    required String permissionSlug,
    required bool granted,
    String? actorId,
  }) async {
    final dbSlug = PermissionCatalog.normalize(permissionSlug);
    final client = _client;

    if (client == null) {
      final set = _localRolePerms.putIfAbsent(roleSlug, () => {});
      if (granted) {
        set.add(dbSlug);
      } else {
        set.remove(dbSlug);
      }
      await _auditRbac(
        granted ? 'permission_assigned' : 'permission_removed',
        actorId,
        {
          'role': roleSlug,
          'permission': dbSlug,
        },
      );
      return;
    }

    try {
      final permRows = await client
          .from('permissions')
          .select('id')
          .eq('slug', dbSlug)
          .limit(1);
      if ((permRows as List).isEmpty) return;
      final permissionId = (permRows.first as Map)['id'] as String;

      if (granted) {
        await client.from('role_permissions').upsert({
          'role_id': roleId,
          'permission_id': permissionId,
        });
      } else {
        await client
            .from('role_permissions')
            .delete()
            .eq('role_id', roleId)
            .eq('permission_id', permissionId);
      }

      await _auditRbac(
        granted ? 'permission_assigned' : 'permission_removed',
        actorId,
        {'role': roleSlug, 'permission': dbSlug},
      );
    } catch (_) {
      final set = _localRolePerms.putIfAbsent(roleSlug, () => {});
      if (granted) {
        set.add(dbSlug);
      } else {
        set.remove(dbSlug);
      }
    }
  }

  Future<RoleDefinition?> createRole({
    required String name,
    required String slug,
    String? description,
    String? cloneFromRoleId,
    String? actorId,
  }) async {
    final client = _client;
    Set<String> seedPerms = {};

    if (cloneFromRoleId != null) {
      final roles = await listRoles();
      RoleDefinition? source;
      for (final r in roles) {
        if (r.id == cloneFromRoleId) {
          source = r;
          break;
        }
      }
      seedPerms = {...?source?.permissionSlugs};
    }

    if (client == null) {
      final role = RoleDefinition(
        id: 'local-$slug',
        name: name,
        slug: slug,
        description: description,
        permissionSlugs: seedPerms,
      );
      _localRoles.add(role);
      _localRolePerms[slug] = {...seedPerms};
      await _auditRbac('role_created', actorId, {'role': slug, 'cloned': cloneFromRoleId != null});
      return role;
    }

    try {
      final inserted = await client.from('roles').insert({
        'name': name,
        'slug': slug,
        'description': description,
        'is_system': false,
        'status': 'active',
      }).select().single();

      final roleId = inserted['id'] as String;
      for (final perm in seedPerms) {
        await setRolePermission(
          roleId: roleId,
          roleSlug: slug,
          permissionSlug: perm,
          granted: true,
          actorId: actorId,
        );
      }

      await _auditRbac('role_created', actorId, {
        'role': slug,
        'cloned_from': cloneFromRoleId,
      });

      return RoleDefinition.fromRow(
        Map<String, dynamic>.from(inserted),
        permissions: seedPerms,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> archiveRole(String roleId, String roleSlug, {String? actorId}) async {
    final client = _client;
    if (client == null) {
      _localRoles.removeWhere((r) => r.id == roleId);
      await _auditRbac('role_archived', actorId, {'role': roleSlug});
      return;
    }
    try {
      await client.from('roles').update({
        'status': 'archived',
        'is_deleted': true,
      }).eq('id', roleId);
      await _auditRbac('role_archived', actorId, {'role': roleSlug});
    } catch (_) {}
  }

  Future<void> assignGroupToRole({
    required String roleId,
    required String roleSlug,
    required PermissionGroup group,
    String? actorId,
  }) async {
    for (final perm in group.permissionSlugs) {
      await setRolePermission(
        roleId: roleId,
        roleSlug: roleSlug,
        permissionSlug: perm,
        granted: true,
        actorId: actorId,
      );
    }
    await _auditRbac('permission_group_assigned', actorId, {
      'role': roleSlug,
      'group': group.slug,
    });
  }

  RealtimeChannel? subscribeRbac(void Function() onChange) {
    final client = _client;
    if (client == null) return null;
    final channel = client.channel('rbac-engine');
    for (final table in ['roles', 'role_permissions', 'permissions', 'user_roles']) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (_) => onChange(),
      );
    }
    channel.subscribe();
    return channel;
  }

  Future<Map<String, Set<String>>> _loadAllRolePermissions() async {
    final client = _client;
    if (client == null) return {};
    try {
      final rows = await client.from('role_permissions').select(
            'role_id, permissions(slug)',
          );
      final map = <String, Set<String>>{};
      for (final raw in rows as List) {
        final row = Map<String, dynamic>.from(raw as Map);
        final roleId = row['role_id'] as String?;
        final perm = row['permissions'];
        final slug = perm is Map ? perm['slug'] as String? : null;
        if (roleId == null || slug == null) continue;
        map.putIfAbsent(roleId, () => {}).add(slug);
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  Future<Set<String>> _groupPermissionSlugs(String groupId) async {
    final client = _client;
    if (client == null) return {};
    try {
      final rows = await client
          .from('permission_group_items')
          .select('permissions(slug)')
          .eq('group_id', groupId);
      final out = <String>{};
      for (final raw in rows as List) {
        final perm = (raw as Map)['permissions'];
        if (perm is Map && perm['slug'] is String) {
          out.add(perm['slug'] as String);
        }
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  Future<void> _auditRbac(
    String action,
    String? actorId,
    Map<String, dynamic> metadata,
  ) async {
    unawaited(
      _audit.publish(
        AuditPublishRequest(
          action: action,
          module: 'rbac',
          category: AuditEventCategory.admin,
          userId: actorId,
          severity: AuditSeverity.notice,
          metadata: metadata,
          immutableVault: action.contains('role') || action.contains('permission'),
        ),
      ),
    );
  }

  List<RoleDefinition> _ensureLocalRoles() {
    if (_localRoles.isEmpty) {
      for (final role in AppRole.values) {
        final slug = role.slug;
        _localRoles.add(
          RoleDefinition(
            id: 'role-$slug',
            name: slug.replaceAll('_', ' '),
            slug: slug,
            isSystem: true,
            permissionSlugs: _localRolePerms[slug] ??
                (role == AppRole.superAdmin
                    ? PermissionCatalog.defaults
                        .map((p) => p.effectiveDbSlug)
                        .toSet()
                    : const {}),
          ),
        );
      }
      // Seed matrix-friendly defaults for demo roles
      _localRolePerms[AppRole.admin.slug] = {
        for (final p in PermissionCatalog.defaults)
          if (p.effectiveDbSlug != 'manage_roles') p.effectiveDbSlug,
      };
      _localRolePerms[AppRole.salesTeam.slug] = {
        'view_properties',
        'manage_crm',
      };
      _localRolePerms[AppRole.client.slug] = {'view_properties'};
      _localRolePerms[AppRole.investor.slug] = {
        'view_properties',
        'manage_reports',
      };
    }
    return _localRoles
        .map(
          (r) => RoleDefinition(
            id: r.id,
            name: r.name,
            slug: r.slug,
            description: r.description,
            isSystem: r.isSystem,
            lifecycle: r.lifecycle,
            permissionSlugs: _localRolePerms[r.slug] ?? r.permissionSlugs,
            memberCount: r.memberCount,
          ),
        )
        .toList();
  }

  List<PermissionGroup> _ensureLocalGroups() {
    if (_localGroups.isEmpty) {
      for (final g in PermissionCatalog.defaultGroups) {
        _localGroups.add(
          PermissionGroup(
            id: 'group-${g.slug}',
            name: g.name,
            slug: g.slug,
            permissionSlugs: g.perms.toSet(),
          ),
        );
      }
    }
    return List.unmodifiable(_localGroups);
  }

  List<ApprovalPolicy> _defaultPolicies() => const [
        ApprovalPolicy(
          id: 'pol-delete-property',
          name: 'Delete Property',
          actionType: ApprovalActionType.deleteProperty,
          approverRoleSlug: 'admin',
          description: 'Manager approval required to delete properties',
        ),
        ApprovalPolicy(
          id: 'pol-refund',
          name: 'Large Refund',
          actionType: ApprovalActionType.largeRefund,
          approverRoleSlug: 'finance',
          thresholdAmount: 500000,
          description: 'Finance approval for refunds ≥ ₦500,000',
        ),
        ApprovalPolicy(
          id: 'pol-role-change',
          name: 'Role Change',
          actionType: ApprovalActionType.roleChange,
          approverRoleSlug: 'super_admin',
          description: 'Super Admin approval for role changes',
        ),
      ];
}
