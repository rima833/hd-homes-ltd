import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/features/authentication/data/datasources/auth_remote_datasource.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/user_profile.dart';
import 'package:hdhomesproject/features/authentication/domain/repositories/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._dataSource);

  final AuthRemoteDataSource _dataSource;
  UserProfile? _cachedProfile;
  Set<String> _cachedPermissions = {};

  @override
  UserProfile? get currentProfile => _cachedProfile;

  @override
  Set<String> get currentPermissions => _cachedPermissions;

  @override
  Stream<UserProfile?> authStateChanges() async* {
    await for (final state in _dataSource.authStateChanges) {
      if (state.session?.user != null) {
        _cachedProfile = await fetchCurrentProfile();
        yield _cachedProfile;
      } else {
        _cachedProfile = null;
        _cachedPermissions = {};
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
        throw const AuthenticationException('Incorrect email or password.');
      }
      final confirmed = user.emailConfirmedAt != null;
      final profile = await _dataSource.fetchProfile(user.id, emailConfirmed: confirmed);
      if (profile == null) {
        throw const AuthenticationException('Profile not found. Please contact support.');
      }
      final status = profile.accountStatus;
      if (status == 'suspended') {
        await _dataSource.signOut();
        throw const AuthenticationException(
          'Your account has been suspended. Contact support.',
        );
      }
      if (status == 'inactive') {
        await _dataSource.signOut();
        throw const AuthenticationException(
          'Your account is inactive. Contact support.',
        );
      }
      if (status == 'deleted') {
        await _dataSource.signOut();
        throw const AuthenticationException(
          'This account is no longer available.',
        );
      }
      if (!confirmed) {
        // Allow profile load so Smart Login Router can send users to verify-email.
        _cachedPermissions = await _dataSource.fetchPermissionSlugs(user.id);
        _cachedProfile = profile;
        return profile;
      }
      _cachedPermissions = await _dataSource.fetchPermissionSlugs(user.id);
      await _dataSource.touchLastLogin(user.id);
      _cachedProfile = profile;
      return profile;
    } catch (e) {
      if (e is AppException) rethrow;
      throw _dataSource.mapAuthError(e);
    }
  }

  @override
  Future<UserProfile> signUpWithEmail({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final response = await _dataSource.signUpWithEmail(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        metadata: metadata,
      );
      final user = response.user;
      if (user == null) {
        throw const AuthenticationException('Registration failed. Please try again.');
      }
      final confirmed = user.emailConfirmedAt != null;
      final profile = await _dataSource.fetchProfile(user.id, emailConfirmed: confirmed);
      _cachedProfile = profile;
      _cachedPermissions = profile != null
          ? await _dataSource.fetchPermissionSlugs(user.id)
          : {};
      return profile ??
          UserProfile(
            id: user.id,
            email: user.email ?? email,
            firstName: firstName,
            lastName: lastName,
            emailConfirmed: confirmed,
            accountStatus: 'pending_verification',
          );
    } catch (e) {
      if (e is AppException) rethrow;
      throw _dataSource.mapAuthError(e);
    }
  }

  @override
  Future<void> signOut({bool everywhere = false}) async {
    await _dataSource.signOut(
      scope: everywhere ? SignOutScope.global : SignOutScope.local,
    );
    _cachedProfile = null;
    _cachedPermissions = {};
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
  Future<void> updatePassword(String newPassword) async {
    try {
      await _dataSource.updatePassword(newPassword);
    } catch (e) {
      throw _dataSource.mapAuthError(e);
    }
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final email = _dataSource.currentUser?.email;
    if (email == null || email.isEmpty) {
      throw const AuthenticationException('Sign in to change your password.');
    }
    try {
      await _dataSource.signInWithEmail(email: email, password: currentPassword);
      await _dataSource.updatePassword(newPassword);
    } catch (e) {
      if (e is AppException) rethrow;
      throw _dataSource.mapAuthError(e);
    }
  }

  @override
  Future<void> resendSignupEmail(String email) async {
    try {
      await _dataSource.resendSignupEmail(email.trim());
    } catch (e) {
      throw _dataSource.mapAuthError(e);
    }
  }

  @override
  Future<UserProfile?> fetchCurrentProfile() async {
    final user = _dataSource.currentUser;
    if (user == null) {
      _cachedProfile = null;
      _cachedPermissions = {};
      return null;
    }
    try {
      final confirmed = user.emailConfirmedAt != null;
      final profile = await _dataSource.fetchProfile(user.id, emailConfirmed: confirmed);
      _cachedPermissions = await _dataSource.fetchPermissionSlugs(user.id);
      _cachedProfile = profile;
      return profile;
    } catch (_) {
      return _cachedProfile;
    }
  }

  @override
  Future<Set<String>> refreshPermissions() async {
    final user = _dataSource.currentUser;
    if (user == null) {
      _cachedPermissions = {};
      return {};
    }
    _cachedPermissions = await _dataSource.fetchPermissionSlugs(user.id);
    return _cachedPermissions;
  }
}
