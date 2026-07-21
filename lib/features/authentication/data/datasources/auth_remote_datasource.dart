import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/features/authentication/data/models/user_profile_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Remote Supabase auth and profile data source.
class AuthRemoteDataSource {
  AuthRemoteDataSource(this._client);

  final SupabaseClient _client;

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
  }) {
    final data = <String, dynamic>{
      ...?metadata,
    };
    if (firstName != null) data['first_name'] = firstName;
    if (lastName != null) data['last_name'] = lastName;

    return _auth.signUp(
      email: email,
      password: password,
      data: data,
    );
  }

  Future<void> signOut({SignOutScope scope = SignOutScope.local}) {
    return _auth.signOut(scope: scope);
  }

  Future<void> resetPassword(String email) {
    return _auth.resetPasswordForEmail(email);
  }

  Future<UserResponse> updatePassword(String newPassword) {
    return _auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<void> resendSignupEmail(String email) {
    return _auth.resend(type: OtpType.signup, email: email);
  }

  Future<UserProfileModel?> fetchProfile(String userId, {bool emailConfirmed = true}) async {
    final response = await _client
        .from('profiles')
        .select('''
          id, email, first_name, last_name, phone, avatar_url, account_status,
          address, preferred_language, last_login_at,
          user_roles (
            is_primary,
            roles ( slug, name )
          )
        ''')
        .eq('id', userId)
        .maybeSingle();

    if (response == null) return null;
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
    if (error is AuthException) {
      return AuthenticationException(_friendlyAuthMessage(error.message), cause: error);
    }
    if (error is PostgrestException) {
      return DatabaseException(error.message, cause: error);
    }
    return const AuthenticationException('Authentication failed. Please try again.');
  }

  String _friendlyAuthMessage(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('invalid login') || lower.contains('invalid credentials')) {
      return 'Incorrect email or password.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Please verify your email before signing in.';
    }
    if (lower.contains('user already registered')) {
      return 'An account with this email already exists.';
    }
    if (lower.contains('rate limit') || lower.contains('too many')) {
      return 'Too many attempts. Please wait and try again.';
    }
    return 'Unable to complete authentication. Please try again.';
  }
}
