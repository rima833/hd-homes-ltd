import 'package:hdhomesproject/features/authentication/domain/entities/app_role.dart';

/// Authenticated user profile from Supabase.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    this.firstName,
    this.lastName,
    this.phone,
    this.avatarUrl,
    this.accountStatus,
    this.roles = const [],
    this.primaryRole,
  });

  final String id;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String? avatarUrl;
  final String? accountStatus;
  final List<AppRole> roles;
  final AppRole? primaryRole;

  String get displayName {
    final name = [firstName, lastName].where((n) => n?.isNotEmpty == true).join(' ');
    return name.isNotEmpty ? name : email;
  }

  bool get isAuthenticated => id.isNotEmpty;
  bool get isStaff => roles.any((r) => r.isStaff);
  bool hasRole(AppRole role) => roles.contains(role);
}
