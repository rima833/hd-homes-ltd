import 'package:hdhomesproject/features/authentication/domain/entities/login_models.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/user_profile.dart';

/// Unified Authentication Gateway — one identity, many sign-in methods.
///
/// Feature modules must not call Supabase Auth directly; go through
/// [AuthRepository] / this gateway contract.
abstract interface class AuthMethodGateway {
  /// Methods currently offered in the UI (enabled only).
  List<LoginMethod> get availableMethods;

  Future<UserProfile> signInWithEmailPassword({
    required String email,
    required String password,
  });

  /// Architecture-ready: phone + password (not enabled in Phase 1).
  Future<UserProfile> signInWithPhonePassword({
    required String phone,
    required String password,
  });

  /// Architecture-ready: magic link request.
  Future<void> requestMagicLink(String email);

  /// Architecture-ready: OAuth providers.
  Future<void> signInWithOAuth(LoginMethod provider);
}

/// Phase 1 capabilities matrix for UI disabling / messaging.
abstract final class AuthMethodCapabilities {
  static bool isEnabled(LoginMethod method) => method.enabled;

  static String comingSoonLabel(LoginMethod method) => switch (method) {
        LoginMethod.phonePassword => 'Phone sign-in coming soon',
        LoginMethod.magicLink => 'Magic link coming soon',
        LoginMethod.google => 'Google sign-in coming soon',
        LoginMethod.apple => 'Apple sign-in coming soon',
        LoginMethod.microsoft => 'Microsoft sign-in coming soon',
        LoginMethod.emailPassword => 'Email & password',
      };
}
