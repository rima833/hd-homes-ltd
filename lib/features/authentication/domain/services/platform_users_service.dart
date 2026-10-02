import 'dart:async';

import 'package:hdhomesproject/core/auth/models/security_event.dart';
import 'package:hdhomesproject/core/auth/services/security_service.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/account_status.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/observability_models.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/platform_user_models.dart';
import 'package:hdhomesproject/features/authentication/domain/services/audit_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Admin service for auth accounts (`profiles`) and direct `user_roles` assignment.
class PlatformUsersService {
  PlatformUsersService({
    required AuditService audit,
    SecurityService? security,
    SupabaseClient? client,
  })  : _audit = audit,
        _security = security,
        _client = client;

  final AuditService _audit;
  final SecurityService? _security;
  final SupabaseClient? _client;

  bool get isConfigured => _client != null;

  Future<PlatformUsersSnapshot> loadSnapshot() async {
    final users = await listPlatformUsers();
    return PlatformUsersSnapshot(
      users: users,
      analytics: PlatformUsersAnalytics.fromUsers(users),
    );
  }

  Future<List<PlatformUser>> listPlatformUsers() async {
    final client = _client;
    if (client == null) return const [];

    try {
      final rows = await client
          .from('profiles')
          .select('''
            id, email, first_name, last_name, phone, avatar_url,
            account_status, last_login_at, created_at, is_deleted,
            user_roles (
              id, role_id, is_primary, is_deleted,
              roles ( id, slug, name )
            )
          ''')
          .eq('is_deleted', false)
          .order('created_at', ascending: false);

      final staffLinks = await _loadEmployeeLinks();

      return (rows as List).map((raw) {
        final map = Map<String, dynamic>.from(raw as Map);
        final userId = map['id'] as String;
        final link = staffLinks[userId];
        return PlatformUser.fromRow(
          map,
          linkedEmployeeId: link?.$1,
          linkedEmployeeCode: link?.$2,
        );
      }).toList();
    } catch (e) {
      throw StateError('Unable to load platform users: $e');
    }
  }

  Future<Map<String, (String, String?)>> _loadEmployeeLinks() async {
    final client = _client;
    if (client == null) return {};

    try {
      final rows = await client
          .from('employees')
          .select('id, user_id, employee_code')
          .eq('is_deleted', false)
          .not('user_id', 'is', null);
      final map = <String, (String, String?)>{};
      for (final raw in rows as List) {
        final row = Map<String, dynamic>.from(raw as Map);
        final userId = row['user_id'] as String?;
        if (userId == null) continue;
        map[userId] = (
          row['id'] as String,
          row['employee_code'] as String?,
        );
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  Future<void> assignRole({
    required String userId,
    required String roleId,
    bool isPrimary = false,
    String? actorId,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase is not configured.');
    }

    final existing = await client
        .from('user_roles')
        .select('id')
        .eq('user_id', userId)
        .eq('role_id', roleId)
        .maybeSingle();

    if (existing == null) {
      await client.from('user_roles').insert({
        'user_id': userId,
        'role_id': roleId,
        'is_primary': isPrimary,
        if (actorId != null) 'created_by': actorId,
      });
    } else {
      await client.from('user_roles').update({
        'is_deleted': false,
        'is_primary': isPrimary,
        if (actorId != null) 'updated_by': actorId,
      }).eq('user_id', userId).eq('role_id', roleId);
    }

    if (isPrimary) {
      await _clearOtherPrimaryRoles(userId, roleId);
    }

    await _audit.publish(
      AuditPublishRequest(
        action: 'platform_user_role_assigned',
        module: 'auth',
        category: AuditEventCategory.security,
        userId: actorId,
        entityType: 'user_roles',
        entityId: userId,
        newValues: {'user_id': userId, 'role_id': roleId, 'is_primary': isPrimary},
      ),
    );
    _security?.record(
      SecurityEvent(
        type: SecurityEventType.roleUpdated,
        timestamp: DateTime.now(),
        userId: actorId,
        metadata: {
          'target_user_id': userId,
          'role_id': roleId,
          'action': 'assigned',
          'is_primary': isPrimary,
        },
      ),
    );
  }

  Future<void> revokeRole({
    required String assignmentId,
    required String userId,
    required String roleId,
    String? actorId,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase is not configured.');
    }

    await client.from('user_roles').delete().eq('id', assignmentId);

    await _audit.publish(
      AuditPublishRequest(
        action: 'platform_user_role_revoked',
        module: 'auth',
        category: AuditEventCategory.security,
        userId: actorId,
        entityType: 'user_roles',
        entityId: userId,
        oldValues: {'user_id': userId, 'role_id': roleId},
      ),
    );
    _security?.record(
      SecurityEvent(
        type: SecurityEventType.roleUpdated,
        timestamp: DateTime.now(),
        userId: actorId,
        metadata: {
          'target_user_id': userId,
          'role_id': roleId,
          'action': 'revoked',
        },
      ),
    );
  }

  Future<void> setPrimaryRole({
    required String userId,
    required String roleId,
    String? actorId,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase is not configured.');
    }

    await _clearOtherPrimaryRoles(userId, roleId);
    await client
        .from('user_roles')
        .update({
          'is_primary': true,
          if (actorId != null) 'updated_by': actorId,
        })
        .eq('user_id', userId)
        .eq('role_id', roleId);

    await _audit.publish(
      AuditPublishRequest(
        action: 'platform_user_primary_role_set',
        module: 'auth',
        category: AuditEventCategory.security,
        userId: actorId,
        entityType: 'user_roles',
        entityId: userId,
        newValues: {'user_id': userId, 'role_id': roleId},
      ),
    );
  }

  Future<void> updateAccountStatus({
    required String userId,
    required AccountStatus status,
    String? actorId,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase is not configured.');
    }

    await client.from('profiles').update({
      'account_status': status.slug,
      if (actorId != null) 'updated_by': actorId,
    }).eq('id', userId);

    await _audit.publish(
      AuditPublishRequest(
        action: 'platform_user_status_updated',
        module: 'auth',
        category: AuditEventCategory.security,
        userId: actorId,
        entityType: 'profiles',
        entityId: userId,
        newValues: {'account_status': status.slug},
      ),
    );
    _security?.record(
      SecurityEvent(
        type: status == AccountStatus.suspended || status == AccountStatus.inactive
            ? SecurityEventType.accountSuspended
            : SecurityEventType.profileUpdated,
        timestamp: DateTime.now(),
        userId: actorId,
        metadata: {
          'target_user_id': userId,
          'account_status': status.slug,
        },
      ),
    );
  }

  Future<void> _clearOtherPrimaryRoles(String userId, String keepRoleId) async {
    final client = _client!;
    await client
        .from('user_roles')
        .update({'is_primary': false})
        .eq('user_id', userId)
        .neq('role_id', keepRoleId);
  }

  RealtimeChannel? subscribePlatformUserChanges(void Function() onChange) {
    final client = _client;
    if (client == null) return null;
    final channel = client.channel('platform-users-hub');
    for (final table in ['profiles', 'user_roles']) {
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
}
