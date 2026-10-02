import 'package:hdhomesproject/core/email/email_config.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/features/authentication/data/models/user_profile_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Remote Supabase auth and profile data source.
class AuthRemoteDataSource {
  AuthRemoteDataSource(this._client);

  final SupabaseClient _client;
  late final EmailConfig _emailConfig = EmailConfig(_client);

  GoTrueClient get _auth => _client.auth;

  Stream<AuthState> get authStateChanges => _auth.onAuthStateChange;

  User? get currentUser => _auth.currentUser;

  Session? get currentSession => _auth.currentSession;

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
    Map<String, dynamic>? metadata,
  }) async {
    final data = <String, dynamic>{
      ...?metadata,
    };
    if (firstName != null) data['first_name'] = firstName;
    if (lastName != null) data['last_name'] = lastName;

    final emailRedirectTo = await _emailConfig.authRedirect('/verify-email');

    return _auth.signUp(
      email: email,
      password: password,
      data: data,
      emailRedirectTo: emailRedirectTo,
    );
  }

  Future<void> signOut({SignOutScope scope = SignOutScope.local}) {
    return _auth.signOut(scope: scope);
  }

  Future<void> resetPassword(String email) async {
    final redirectTo = await _emailConfig.authRedirect('/reset-password');
    return _auth.resetPasswordForEmail(email, redirectTo: redirectTo);
  }

  Future<UserResponse> updatePassword(String newPassword) {
    return _auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<void> resendSignupEmail(String email) async {
    final emailRedirectTo = await _emailConfig.authRedirect('/verify-email');
    await _auth.resend(
      type: OtpType.signup,
      email: email,
      emailRedirectTo: emailRedirectTo,
    );
  }

  /// Forces a fresh Auth user payload (includes `email_confirmed_at`).
  Future<User?> refreshAuthUser() async {
    try {
      final response = await _auth.getUser();
      return response.user;
    } catch (_) {
      try {
        final refreshed = await _auth.refreshSession();
        return refreshed.user ?? _auth.currentUser;
      } catch (_) {
        return _auth.currentUser;
      }
    }
  }

  Future<UserResponse> updateEmail(String newEmail) async {
    final emailRedirectTo = await _emailConfig.authRedirect('/verify-email');
    return _auth.updateUser(
      UserAttributes(email: newEmail),
      emailRedirectTo: emailRedirectTo,
    );
  }

  Future<UserProfileModel?> fetchProfile(String userId, {bool emailConfirmed = true}) async {
    final response = await _client
        .from('profiles')
        .select('''
          id, email, first_name, last_name, phone, phone_verified, avatar_url, account_status,
          address, preferred_language, last_login_at,
          user_roles (
            is_primary,
            roles ( slug, name )
          )
        ''')
        .eq('id', userId)
        .maybeSingle();

    if (response == null) return null;

    // `employees.user_id` is the canonical staff link. Resolve it into the
    // session profile so Attendance/HCM and module ownership can share identity.
    try {
      final employee = await _client
          .from('employees')
          .select('id')
          .eq('user_id', userId)
          .eq('is_deleted', false)
          .maybeSingle();
      if (employee != null) response['employee_id'] = employee['id'];
    } catch (_) {
      // Non-staff users and deployments without employee self-read still sign in.
    }

    return UserProfileModel.fromJson(response, emailConfirmed: emailConfirmed);
  }

  /// Loads permission slugs via SECURITY DEFINER RPC when available.
  Future<Set<String>> fetchPermissionSlugs(String userId) async {
    try {
      final result = await _client.rpc(
        'get_user_permission_slugs',
        params: {'target_user_id': userId},
      );
      if (result is List) {
        return result.map((e) => e.toString()).toSet();
      }
      return const {};
    } catch (_) {
      return const {};
    }
  }

  Future<void> touchLastLogin(String userId) async {
    try {
      await _client.from('profiles').update({
        'last_login_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', userId);
    } catch (_) {}
  }

  AppException mapAuthError(Object error) {
    return mapToAppException(error);
  }
}
