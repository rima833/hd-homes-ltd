import 'package:hdhomesproject/features/authentication/domain/entities/user_profile.dart';

/// Contract for authentication operations.
abstract interface class AuthRepository {
  Stream<UserProfile?> authStateChanges();
  UserProfile? get currentProfile;
  Set<String> get currentPermissions;

  Future<UserProfile> signInWithEmail({
    required String email,
    required String password,
  });

  Future<UserProfile> signUpWithEmail({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
    Map<String, dynamic>? metadata,
  });

  Future<void> signOut({bool everywhere = false});
  Future<void> resetPassword(String email);

  /// Completes recovery / sets a new password for the recovery session.
  Future<void> updatePassword(String newPassword);

  /// Re-authenticates with [currentPassword] then updates to [newPassword].
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// Resends the signup confirmation email (Supabase Auth).
  Future<void> resendSignupEmail(String email);

  Future<UserProfile?> fetchCurrentProfile();
  Future<Set<String>> refreshPermissions();
}
