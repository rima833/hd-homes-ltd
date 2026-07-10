import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/features/authentication/data/datasources/auth_remote_datasource.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/user_profile.dart';
import 'package:hdhomesproject/features/authentication/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._dataSource);

  final AuthRemoteDataSource _dataSource;
  UserProfile? _cachedProfile;

  @override
  UserProfile? get currentProfile => _cachedProfile;

  @override
  Stream<UserProfile?> authStateChanges() async* {
    await for (final state in _dataSource.authStateChanges) {
      if (state.session?.user != null) {
        _cachedProfile = await fetchCurrentProfile();
        yield _cachedProfile;
      } else {
        _cachedProfile = null;
        yield null;
      }
    }
  }

  @override
  Future<UserProfile> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dataSource.signInWithEmail(
        email: email,
        password: password,
      );
      final user = response.user;
      if (user == null) {
        throw const AuthenticationException('Sign in failed');
      }
      final profile = await _dataSource.fetchProfile(user.id);
      if (profile == null) {
        throw const AuthenticationException('Profile not found');
      }
      _cachedProfile = profile;
      return profile;
    } catch (e) {
      throw _dataSource.mapAuthError(e);
    }
  }

  @override
  Future<UserProfile> signUpWithEmail({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  }) async {
    try {
      final response = await _dataSource.signUpWithEmail(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
      );
      final user = response.user;
      if (user == null) {
        throw const AuthenticationException('Registration failed');
      }
      final profile = await _dataSource.fetchProfile(user.id);
      _cachedProfile = profile;
      return profile ??
          UserProfile(
            id: user.id,
            email: user.email ?? email,
            firstName: firstName,
            lastName: lastName,
          );
    } catch (e) {
      throw _dataSource.mapAuthError(e);
    }
  }

  @override
  Future<void> signOut() async {
    await _dataSource.signOut();
    _cachedProfile = null;
  }

  @override
  Future<void> resetPassword(String email) async {
    try {
      await _dataSource.resetPassword(email);
    } catch (e) {
      throw _dataSource.mapAuthError(e);
    }
  }

  @override
  Future<UserProfile?> fetchCurrentProfile() async {
    final user = _dataSource.currentUser;
    if (user == null) {
      _cachedProfile = null;
      return null;
    }
    try {
      final profile = await _dataSource.fetchProfile(user.id);
      _cachedProfile = profile;
      return profile;
    } catch (_) {
      return _cachedProfile;
    }
  }
}
