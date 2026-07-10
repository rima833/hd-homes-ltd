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
  }) {
    final metadata = <String, dynamic>{};
    if (firstName != null) metadata['first_name'] = firstName;
    if (lastName != null) metadata['last_name'] = lastName;

    return _auth.signUp(
      email: email,
      password: password,
      data: metadata,
    );
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> resetPassword(String email) {
    return _auth.resetPasswordForEmail(email);
  }

  Future<UserProfileModel?> fetchProfile(String userId) async {
    final response = await _client
        .from('profiles')
        .select('''
          id, email, first_name, last_name, phone, avatar_url, account_status,
          user_roles (
            is_primary,
            roles ( slug, name )
          )
        ''')
        .eq('id', userId)
        .maybeSingle();

    if (response == null) return null;
    return UserProfileModel.fromJson(response);
  }

  AppException mapAuthError(Object error) {
    if (error is AuthException) {
      return AuthenticationException(error.message, cause: error);
    }
    if (error is PostgrestException) {
      return DatabaseException(error.message, cause: error);
    }
    return AuthenticationException('Authentication failed', cause: error);
  }
}
