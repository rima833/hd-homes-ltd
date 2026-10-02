import 'dart:async';

import 'package:hdhomesproject/core/auth/models/security_event.dart';
import 'package:hdhomesproject/core/auth/services/security_service.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/app_role.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/observability_models.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/rbac_models.dart';
import 'package:hdhomesproject/features/authentication/domain/services/audit_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Enterprise RBAC service — roles, matrix, groups, approvals (no hardcoded grants).
class RbacService {
  RbacService({
    required AuditService audit,
    SecurityService? security,
    SupabaseClient? client,
  })  : _audit = audit,
        _security = security,
        _client = client;

  final AuditService _audit;
  final SecurityService? _security;
  final SupabaseClient? _client;

  final Map<String, Set<String>> _localRolePerms = {};
  final List<RoleDefinition> _localRoles = [];

  bool get isConfigured => _client != null;

  Future<RbacSnapshot> loadSnapshot() async {
    final roles = await listRoles();
    final permissions = await listPermissions();
    final groups = await listGroups();
    final policies = await listApprovalPolicies();
    final accessRequests = await listAccessRequests();
    final matrix = buildMatrix(roles, permissions);
    final membersWithRoles = await _countUsersWithRoles();
    final pendingApprovals =
        accessRequests.where((r) => r.isPending).length;
    final analytics = RbacAnalytics(
      rolesInUse: roles.where((r) => r.lifecycle == RoleLifecycle.active).length,
      permissionCount: permissions.length,
      systemRoles: roles.where((r) => r.isSystem).length,
      customRoles: roles.where((r) => !r.isSystem).length,
      privilegedAccounts: roles
          .where((r) =>
              r.slug == AppRole.superAdmin.slug || r.slug == AppRole.admin.slug)
          .fold<int>(0, (a, r) => a + r.memberCount),
      accessDeniedEvents: 0,
      openApprovals: pendingApprovals,
      breakGlassSessions: 0,
      membersWithRoles: membersWithRoles,
    );
    return RbacSnapshot(
      roles: roles,
      permissions: permissions,
      groups: groups,
      matrix: matrix,
      policies: policies,
      accessRequests: accessRequests,
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
    if (client == null) return const [];

    try {
      final rows = await client
          .from('roles')
          .select()
          .eq('is_deleted', false)
          .order('name');
      final rolePerms = await _loadAllRolePermissions();
      final memberCounts = await _loadRoleMemberCounts();
      return (rows as List).map((raw) {
        final map = Map<String, dynamic>.from(raw as Map);
        final id = map['id'] as String;
        map['member_count'] = memberCounts[id] ?? 0;
        return RoleDefinition.fromRow(
          map,
          permissions: rolePerms[id] ?? const {},
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<PermissionDefinition>> listPermissions() async {
    final client = _client;
    if (client == null) return const [];

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
      if (fromDb.isEmpty) return const [];
      // Merge catalog metadata (dotted aliases) onto DB rows when available.
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
      return const [];
    }
  }

  Future<List<PermissionGroup>> listGroups() async {
    final client = _client;
    if (client == null) return const [];

    try {
      final rows = await client.from('permission_groups').select().order('name');
      final result = <PermissionGroup>[];
      for (final raw in rows as List) {
        final map = Map<String, dynamic>.from(raw as Map);
        final id = map['id'] as String;
        final perms = await _groupPermissionSlugs(id);
        result.add(PermissionGroup.fromRow(map, permissions: perms));
      }
      if (result.isEmpty) return const [];
      return result;
    } catch (_) {
      return const [];
    }
  }

  Future<List<ApprovalPolicy>> listApprovalPolicies() async {
    final client = _client;
    if (client == null) return const [];

    try {
      final rows = await client.from('approval_policies').select().order('name');
      return (rows as List)
          .map((e) => ApprovalPolicy.fromRow(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<AccessRequest>> listAccessRequests() async {
    final client = _client;
    if (client == null) return const [];

    try {
      final rows = await client
          .from('access_requests')
          .select(
            '*, requester:profiles!access_requests_requester_id_fkey(first_name, last_name, preferred_name, email)',
          )
          .order('created_at', ascending: false)
          .limit(80);
      return (rows as List)
          .map(
            (e) => AccessRequest.fromRow(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    } catch (_) {
      try {
        final rows = await client
            .from('access_requests')
            .select()
            .order('created_at', ascending: false)
            .limit(80);
        return (rows as List)
            .map(
              (e) =>
                  AccessRequest.fromRow(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
      } catch (_) {
        return const [];
      }
    }
  }

  Future<ApprovalPolicy> setApprovalPolicyEnabled({
    required String policyId,
    required bool enabled,
  }) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured.');
    final row = await client.rpc(
      'set_approval_policy_enabled',
      params: {
        'p_policy_id': policyId,
        'p_enabled': enabled,
      },
    );
    final map = row is Map
        ? Map<String, dynamic>.from(row)
        : (row is List && row.isNotEmpty
            ? Map<String, dynamic>.from(row.first as Map)
            : null);
    if (map == null) throw StateError('Could not update approval policy.');
    return ApprovalPolicy.fromRow(map);
  }

  Future<AccessRequest> createAccessRequest({
    required String reason,
    String? permissionSlug,
    String? roleSlug,
  }) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured.');
    final row = await client.rpc(
      'create_access_request',
      params: {
        'p_reason': reason,
        'p_permission_slug': ?permissionSlug,
        'p_role_slug': ?roleSlug,
      },
    );
    final map = row is Map
        ? Map<String, dynamic>.from(row)
        : (row is List && row.isNotEmpty
            ? Map<String, dynamic>.from(row.first as Map)
            : null);
    if (map == null) throw StateError('Could not create access request.');
    return AccessRequest.fromRow(map);
  }

  Future<AccessRequest> reviewAccessRequest({
    required String requestId,
    required bool approve,
    String? note,
  }) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured.');
    final row = await client.rpc(
      'review_access_request',
      params: {
        'p_request_id': requestId,
        'p_approve': approve,
        'p_note': ?note,
      },
    );
    final map = row is Map
        ? Map<String, dynamic>.from(row)
        : (row is List && row.isNotEmpty
            ? Map<String, dynamic>.from(row.first as Map)
            : null);
    if (map == null) throw StateError('Could not review access request.');
    return AccessRequest.fromRow(map);
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
      throw StateError('Supabase is not configured.');
    }

    await client.rpc(
      'set_role_permission',
      params: {
        'p_role_id': roleId,
        'p_permission_slug': dbSlug,
        'p_granted': granted,
        if (actorId != null) 'p_actor_id': actorId,
      },
    );

    await _auditRbac(
      granted ? 'permission_assigned' : 'permission_removed',
      actorId,
      {
        'role': roleSlug,
        'role_id': roleId,
        'permission': dbSlug,
        'granted': granted,
      },
      entityType: 'role_permissions',
      entityId: roleId,
      newValues: {
        'role_slug': roleSlug,
        'permission': dbSlug,
        'granted': granted,
      },
    );
    _security?.record(
      SecurityEvent(
        type: SecurityEventType.permissionChanged,
        timestamp: DateTime.now(),
        userId: actorId,
        metadata: {
          'role': roleSlug,
          'role_id': roleId,
          'permission': dbSlug,
          'granted': granted,
        },
      ),
    );
  }

  Future<PermissionDefinition> createPermission({
    required String name,
    required String slug,
    required String module,
    String? description,
    String? actorId,
  }) async {
    final client = _client;
    final trimmedName = name.trim();
    final trimmedSlug = slug.trim().toLowerCase();
    final trimmedModule = module.trim().isEmpty ? 'custom' : module.trim();
    if (trimmedName.isEmpty || trimmedSlug.isEmpty) {
      throw Exception('Permission name and slug are required.');
    }
    if (client == null) {
      throw Exception('Supabase is not configured');
    }

    try {
      final inserted = await client.from('permissions').insert({
        'name': trimmedName,
        'slug': trimmedSlug,
        'module': trimmedModule,
        'description': description?.trim().isEmpty == true
            ? null
            : description?.trim(),
        'status': 'active',
        'is_deleted': false,
        if (actorId != null) 'created_by': actorId,
      }).select().single();

      await _auditRbac('permission_created', actorId, {
        'permission': trimmedSlug,
        'module': trimmedModule,
      });

      return PermissionDefinition.fromRow(
        Map<String, dynamic>.from(inserted),
      );
    } catch (e) {
      throw Exception('Unable to create permission: $e');
    }
  }

  Future<RoleDefinition> createRole({
    required String name,
    required String slug,
    String? description,
    String? cloneFromRoleId,
    String? parentRoleId,
    String? actorId,
  }) async {
    final client = _client;
    final trimmedName = name.trim();
    final trimmedSlug = slug.trim().toLowerCase();
    if (trimmedName.isEmpty || trimmedSlug.isEmpty) {
      throw Exception('Role name and slug are required.');
    }

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
        id: 'local-$trimmedSlug',
        name: trimmedName,
        slug: trimmedSlug,
        description: description,
        permissionSlugs: seedPerms,
      );
      _localRoles.add(role);
      _localRolePerms[trimmedSlug] = {...seedPerms};
      await _auditRbac('role_created', actorId, {
        'role': trimmedSlug,
        'cloned': cloneFromRoleId != null,
      });
      return role;
    }

    try {
      final inserted = await client.from('roles').insert({
        'name': trimmedName,
        'slug': trimmedSlug,
        'description': description?.trim().isEmpty == true
            ? null
            : description?.trim(),
        'is_system': false,
        'status': 'active',
        'lifecycle': 'active',
        'is_deleted': false,
        if (parentRoleId != null && parentRoleId.isNotEmpty)
          'parent_role_id': parentRoleId,
      }).select().single();

      final roleId = inserted['id'] as String;
      for (final perm in seedPerms) {
        await setRolePermission(
          roleId: roleId,
          roleSlug: trimmedSlug,
          permissionSlug: perm,
          granted: true,
          actorId: actorId,
        );
      }

      await _auditRbac('role_created', actorId, {
        'role': trimmedSlug,
        'cloned_from': cloneFromRoleId,
      });

      return RoleDefinition.fromRow(
        Map<String, dynamic>.from(inserted),
        permissions: seedPerms,
      );
    } catch (e) {
      throw Exception('Unable to create role: $e');
    }
  }

  Future<RoleDefinition> updateRole({
    required String roleId,
    String? name,
    String? description,
    RoleLifecycle? lifecycle,
    String? parentRoleId,
    bool clearParent = false,
    String? actorId,
  }) async {
    final client = _client;
    if (client == null) {
      throw Exception('Supabase is not configured');
    }

    final roles = await listRoles();
    RoleDefinition? existing;
    for (final r in roles) {
      if (r.id == roleId) {
        existing = r;
        break;
      }
    }
    if (existing == null) {
      throw Exception('Role not found');
    }
    if (existing.isSystem && lifecycle == RoleLifecycle.archived) {
      throw Exception('System roles cannot be archived');
    }
    if (existing.isSystem &&
        ((name != null && name.trim().isNotEmpty && name.trim() != existing.name) ||
            (description != null &&
                description.trim() != (existing.description ?? '').trim()))) {
      throw Exception('System roles cannot be edited');
    }

    try {
      final patch = <String, dynamic>{
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        if (description != null)
          'description':
              description.trim().isEmpty ? null : description.trim(),
        if (clearParent)
          'parent_role_id': null
        else if (parentRoleId != null)
          'parent_role_id': parentRoleId.isEmpty ? null : parentRoleId,
        if (lifecycle != null) ...{
          'lifecycle': lifecycle.slug,
          'status': lifecycle == RoleLifecycle.archived ? 'archived' : 'active',
          if (lifecycle == RoleLifecycle.archived) 'is_deleted': true,
          if (lifecycle == RoleLifecycle.active) 'is_deleted': false,
        },
      };

      final row = await client
          .from('roles')
          .update(patch)
          .eq('id', roleId)
          .select()
          .single();

      await _auditRbac('role_updated', actorId, {
        'role': existing.slug,
        'fields': patch.keys.toList(),
      });

      return RoleDefinition.fromRow(
        Map<String, dynamic>.from(row),
        permissions: existing.permissionSlugs,
      );
    } catch (e) {
      throw Exception('Unable to update role: $e');
    }
  }

  Future<void> archiveRole(String roleId, String roleSlug, {String? actorId}) async {
    final client = _client;
    if (client == null) {
      _localRoles.removeWhere((r) => r.id == roleId);
      await _auditRbac(
        'role_archived',
        actorId,
        {'role': roleSlug, 'role_id': roleId},
        entityType: 'roles',
        entityId: roleId,
      );
      _security?.record(
        SecurityEvent(
          type: SecurityEventType.roleUpdated,
          timestamp: DateTime.now(),
          userId: actorId,
          metadata: {'role': roleSlug, 'role_id': roleId, 'action': 'archived'},
        ),
      );
      return;
    }
    try {
      await client.from('roles').update({
        'status': 'archived',
        'lifecycle': 'archived',
        'is_deleted': true,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', roleId);
      await _auditRbac(
        'role_archived',
        actorId,
        {'role': roleSlug, 'role_id': roleId},
        entityType: 'roles',
        entityId: roleId,
      );
      _security?.record(
        SecurityEvent(
          type: SecurityEventType.roleUpdated,
          timestamp: DateTime.now(),
          userId: actorId,
          metadata: {'role': roleSlug, 'role_id': roleId, 'action': 'archived'},
        ),
      );
    } catch (e) {
      throw Exception('Unable to archive role: $e');
    }
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
    for (final table in [
      'roles',
      'role_permissions',
      'permissions',
      'user_roles',
      'permission_groups',
      'permission_group_items',
      'approval_policies',
      'access_requests',
    ]) {
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

  Future<Map<String, int>> _loadRoleMemberCounts() async {
    final client = _client;
    if (client == null) return {};
    try {
      final rows = await client.from('user_roles').select('role_id');
      final counts = <String, int>{};
      for (final raw in rows as List) {
        final id = (raw as Map)['role_id'] as String?;
        if (id == null) continue;
        counts[id] = (counts[id] ?? 0) + 1;
      }
      return counts;
    } catch (_) {
      return {};
    }
  }

  Future<int> _countUsersWithRoles() async {
    final client = _client;
    if (client == null) return 0;
    try {
      final rows = await client.from('user_roles').select('user_id');
      final ids = <String>{};
      for (final raw in rows as List) {
        final id = (raw as Map)['user_id'] as String?;
        if (id != null) ids.add(id);
      }
      return ids.length;
    } catch (_) {
      return 0;
    }
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
    Map<String, dynamic> metadata, {
    String? entityType,
    String? entityId,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
  }) async {
    final resolvedEntityType = entityType ??
        (metadata['role_id'] != null
            ? 'roles'
            : metadata['permission'] != null
                ? 'permissions'
                : metadata['group'] != null
                    ? 'permission_groups'
                    : 'rbac');
    final resolvedEntityId = entityId ??
        metadata['role_id']?.toString() ??
        metadata['role']?.toString() ??
        metadata['permission']?.toString() ??
        metadata['group']?.toString();

    unawaited(
      _audit.publish(
        AuditPublishRequest(
          action: action,
          module: 'rbac',
          category: AuditEventCategory.security,
          userId: actorId,
          severity: AuditSeverity.notice,
          entityType: resolvedEntityType,
          entityId: resolvedEntityId,
          oldValues: oldValues,
          newValues: newValues ?? metadata,
          metadata: metadata,
          immutableVault:
              action.contains('role') || action.contains('permission'),
        ),
      ),
    );
  }
}
