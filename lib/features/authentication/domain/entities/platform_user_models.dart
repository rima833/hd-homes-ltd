import 'package:hdhomesproject/features/authentication/domain/entities/account_status.dart';

/// Role assignment row from `user_roles` joined with `roles`.
class PlatformUserRoleAssignment {
  const PlatformUserRoleAssignment({
    required this.assignmentId,
    required this.roleId,
    required this.roleSlug,
    required this.roleName,
    this.isPrimary = false,
  });

  final String assignmentId;
  final String roleId;
  final String roleSlug;
  final String roleName;
  final bool isPrimary;

  factory PlatformUserRoleAssignment.fromRow(Map<String, dynamic> row) {
    final role = Map<String, dynamic>.from(row['roles'] as Map? ?? {});
    return PlatformUserRoleAssignment(
      assignmentId: row['id'] as String,
      roleId: row['role_id'] as String? ?? role['id'] as String? ?? '',
      roleSlug: role['slug'] as String? ?? '',
      roleName: role['name'] as String? ?? role['slug'] as String? ?? 'Role',
      isPrimary: row['is_primary'] as bool? ?? false,
    );
  }
}

/// Auth account (`profiles`) with platform role assignments.
class PlatformUser {
  const PlatformUser({
    required this.id,
    required this.email,
    this.firstName,
    this.lastName,
    this.phone,
    this.avatarUrl,
    this.accountStatus = AccountStatus.pendingVerification,
    this.lastLoginAt,
    this.createdAt,
    this.roles = const [],
    this.linkedEmployeeId,
    this.linkedEmployeeCode,
  });

  final String id;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String? avatarUrl;
  final AccountStatus accountStatus;
  final DateTime? lastLoginAt;
  final DateTime? createdAt;
  final List<PlatformUserRoleAssignment> roles;
  final String? linkedEmployeeId;
  final String? linkedEmployeeCode;

  String get displayName {
    final name =
        [firstName, lastName].where((n) => n?.trim().isNotEmpty == true).join(' ');
    return name.isNotEmpty ? name : email;
  }

  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
  }

  PlatformUserRoleAssignment? get primaryRole =>
      roles.cast<PlatformUserRoleAssignment?>().firstWhere(
            (r) => r!.isPrimary,
            orElse: () => roles.isEmpty ? null : roles.first,
          );

  bool get hasStaffRecord => linkedEmployeeId != null;

  bool hasRoleSlug(String slug) =>
      roles.any((r) => r.roleSlug == slug || r.roleId == slug);

  factory PlatformUser.fromRow(
    Map<String, dynamic> row, {
    String? linkedEmployeeId,
    String? linkedEmployeeCode,
  }) {
    final rolesRaw = row['user_roles'] as List<dynamic>? ?? [];
    final roles = rolesRaw
        .where((e) => (e as Map)['is_deleted'] != true)
        .map(
          (e) => PlatformUserRoleAssignment.fromRow(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();

    DateTime? parseTs(Object? raw) {
      if (raw is String) return DateTime.tryParse(raw);
      return null;
    }

    return PlatformUser(
      id: row['id'] as String,
      email: row['email'] as String? ?? '',
      firstName: row['first_name'] as String?,
      lastName: row['last_name'] as String?,
      phone: row['phone'] as String?,
      avatarUrl: row['avatar_url'] as String?,
      accountStatus: AccountStatus.fromSlug(row['account_status'] as String?),
      lastLoginAt: parseTs(row['last_login_at']),
      createdAt: parseTs(row['created_at']),
      roles: roles,
      linkedEmployeeId: linkedEmployeeId,
      linkedEmployeeCode: linkedEmployeeCode,
    );
  }
}

class PlatformUsersAnalytics {
  const PlatformUsersAnalytics({
    this.totalAccounts = 0,
    this.activeAccounts = 0,
    this.pendingVerification = 0,
    this.suspendedAccounts = 0,
    this.withRoles = 0,
    this.linkedToStaff = 0,
  });

  final int totalAccounts;
  final int activeAccounts;
  final int pendingVerification;
  final int suspendedAccounts;
  final int withRoles;
  final int linkedToStaff;

  factory PlatformUsersAnalytics.fromUsers(List<PlatformUser> users) {
    var active = 0;
    var pending = 0;
    var suspended = 0;
    var withRoles = 0;
    var linked = 0;
    for (final u in users) {
      switch (u.accountStatus) {
        case AccountStatus.active:
          active++;
        case AccountStatus.pendingVerification:
          pending++;
        case AccountStatus.suspended:
        case AccountStatus.inactive:
          suspended++;
        case AccountStatus.deleted:
          break;
      }
      if (u.roles.isNotEmpty) withRoles++;
      if (u.hasStaffRecord) linked++;
    }
    return PlatformUsersAnalytics(
      totalAccounts: users.length,
      activeAccounts: active,
      pendingVerification: pending,
      suspendedAccounts: suspended,
      withRoles: withRoles,
      linkedToStaff: linked,
    );
  }
}

class PlatformUsersSnapshot {
  const PlatformUsersSnapshot({
    this.users = const [],
    this.analytics = const PlatformUsersAnalytics(),
  });

  final List<PlatformUser> users;
  final PlatformUsersAnalytics analytics;

  PlatformUsersSnapshot copyWith({
    List<PlatformUser>? users,
    PlatformUsersAnalytics? analytics,
  }) {
    return PlatformUsersSnapshot(
      users: users ?? this.users,
      analytics: analytics ?? this.analytics,
    );
  }
}
