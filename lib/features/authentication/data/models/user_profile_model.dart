import 'package:hdhomesproject/features/authentication/domain/entities/app_role.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/user_profile.dart';

class UserProfileModel extends UserProfile {
  const UserProfileModel({
    required super.id,
    required super.email,
    super.firstName,
    super.lastName,
    super.phone,
    super.avatarUrl,
    super.accountStatus,
    super.roles = const [],
    super.primaryRole,
    super.company,
    super.address,
    super.preferredLanguage,
    super.lastLoginAt,
    super.emailConfirmed = true,
  });

  factory UserProfileModel.fromJson(
    Map<String, dynamic> json, {
    bool emailConfirmed = true,
  }) {
    final rolesData = json['user_roles'] as List<dynamic>? ?? [];
    final roles = <AppRole>[];
    AppRole? primaryRole;

    for (final entry in rolesData) {
      final roleJson = entry['roles'] as Map<String, dynamic>?;
      final slug = roleJson?['slug'] as String?;
      final role = AppRole.fromSlug(slug);
      if (role != null) {
        roles.add(role);
        if (entry['is_primary'] == true) primaryRole = role;
      }
    }

    DateTime? lastLogin;
    final rawLastLogin = json['last_login_at'];
    if (rawLastLogin is String) {
      lastLogin = DateTime.tryParse(rawLastLogin);
    }

    return UserProfileModel(
      id: json['id'] as String,
      email: json['email'] as String,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      accountStatus: json['account_status'] as String?,
      address: json['address'] as String?,
      preferredLanguage: json['preferred_language'] as String?,
      lastLoginAt: lastLogin,
      roles: roles,
      primaryRole: primaryRole ?? (roles.isNotEmpty ? roles.first : null),
      emailConfirmed: emailConfirmed,
    );
  }
}
