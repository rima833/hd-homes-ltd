import 'package:hdhomesproject/features/authentication/domain/entities/app_role.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/account_status.dart';

/// Layer 1 — Supabase Auth identity (tokens live in session; this is the subject).
class AuthIdentity {
  const AuthIdentity({
    required this.id,
    required this.email,
    this.phone,
    this.emailConfirmed = false,
    this.phoneConfirmed = false,
    this.providers = const ['email'],
  });

  final String id;
  final String email;
  final String? phone;
  final bool emailConfirmed;
  final bool phoneConfirmed;
  final List<String> providers;
}

/// Layer 2 — Business profile stored in PostgreSQL `profiles`.
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
    this.company,
    this.address,
    this.preferredLanguage,
    this.lastLoginAt,
    this.emailConfirmed = true,
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
  final String? company;
  final String? address;
  final String? preferredLanguage;
  final DateTime? lastLoginAt;
  final bool emailConfirmed;

  AccountStatus get status => AccountStatus.fromSlug(accountStatus);

  String get displayName {
    final name = [firstName, lastName].where((n) => n?.isNotEmpty == true).join(' ');
    return name.isNotEmpty ? name : email;
  }

  bool get isAuthenticated => id.isNotEmpty;
  bool get isStaff => roles.any((r) => r.isStaff);
  bool get isInvestor => roles.contains(AppRole.investor) || primaryRole == AppRole.investor;
  bool hasRole(AppRole role) => roles.contains(role);

  AuthIdentity get identity => AuthIdentity(
        id: id,
        email: email,
        phone: phone,
        emailConfirmed: emailConfirmed,
      );
}
