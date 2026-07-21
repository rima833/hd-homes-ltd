import 'package:hdhomesproject/core/auth/models/auth_status.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/app_role.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/user_profile.dart';

/// Immutable snapshot of the resolved identity for the current session.
///
/// Layer 1 (Supabase Auth) + Layer 2 (business profile) + permissions.
class AuthSessionSnapshot {
  const AuthSessionSnapshot({
    required this.status,
    this.userId,
    this.email,
    this.emailConfirmed = false,
    this.profile,
    this.permissions = const {},
    this.accessTokenExpiresAt,
    this.lastActivityAt,
    this.sessionId,
  });

  static const empty = AuthSessionSnapshot(status: AuthStatus.unauthenticated);

  final AuthStatus status;
  final String? userId;
  final String? email;
  final bool emailConfirmed;
  final UserProfile? profile;
  final Set<String> permissions;
  final DateTime? accessTokenExpiresAt;
  final DateTime? lastActivityAt;
  final String? sessionId;

  bool get isAuthenticated =>
      status == AuthStatus.authenticated || status == AuthStatus.verificationPending;

  bool get isLoading => status == AuthStatus.authenticating;

  AppRole? get primaryRole => profile?.primaryRole;

  List<AppRole> get roles => profile?.roles ?? const [];

  bool hasPermission(String slug) => permissions.contains(slug);

  bool hasRole(AppRole role) => roles.contains(role);

  bool get isStaff => profile?.isStaff ?? false;

  bool get isInvestor => profile?.isInvestor ?? false;

  AuthSessionSnapshot copyWith({
    AuthStatus? status,
    String? userId,
    String? email,
    bool? emailConfirmed,
    UserProfile? profile,
    Set<String>? permissions,
    DateTime? accessTokenExpiresAt,
    DateTime? lastActivityAt,
    String? sessionId,
    bool clearProfile = false,
  }) {
    return AuthSessionSnapshot(
      status: status ?? this.status,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      emailConfirmed: emailConfirmed ?? this.emailConfirmed,
      profile: clearProfile ? null : (profile ?? this.profile),
      permissions: permissions ?? this.permissions,
      accessTokenExpiresAt: accessTokenExpiresAt ?? this.accessTokenExpiresAt,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      sessionId: sessionId ?? this.sessionId,
    );
  }
}
