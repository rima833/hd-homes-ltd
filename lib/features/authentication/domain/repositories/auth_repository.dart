import 'package:hdhomesproject/features/authentication/domain/entities/user_profile.dart';

/// Contract for authentication operations.
abstract interface class AuthRepository {
  Stream<UserProfile?> authStateChanges();
  UserProfile? get currentProfile;
  Future<UserProfile> signInWithEmail({
    required String email,
    required String password,
  });
  Future<UserProfile> signUpWithEmail({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  });
  Future<void> signOut();
  Future<void> resetPassword(String email);
  Future<UserProfile?> fetchCurrentProfile();
}
