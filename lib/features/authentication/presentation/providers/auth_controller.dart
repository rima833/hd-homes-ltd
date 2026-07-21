import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/auth/auth.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/core/router/app_router.dart';
import 'package:hdhomesproject/core/storage/storage_service.dart';
import 'package:hdhomesproject/features/authentication/data/repositories/session_repository_impl.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/login_models.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/user_profile.dart';
import 'package:hdhomesproject/features/authentication/domain/repositories/auth_repository.dart';
import 'package:hdhomesproject/features/authentication/domain/repositories/session_repository.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/features/authentication/domain/services/device_fingerprint_service.dart';
import 'package:hdhomesproject/features/authentication/domain/services/login_validator.dart';
import 'package:hdhomesproject/features/authentication/domain/services/smart_login_router.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/identity_provider.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/mfa_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

export 'identity_provider.dart';

final deviceFingerprintServiceProvider =
    FutureProvider<DeviceFingerprintService>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return DeviceFingerprintService(prefs);
});

final sessionRepositoryProvider = Provider<SessionRepository?>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) return null;
  final fp = ref.watch(deviceFingerprintServiceProvider).valueOrNull;
  if (fp == null) return null;
  return SessionRepositoryImpl(
    client: ref.watch(supabaseClientProvider),
    fingerprint: fp,
  );
});

/// Handles sign-in, sign-up, sign-out, and Smart Login Router™ navigation.
class AuthController extends AsyncNotifier<UserProfile?> {
  @override
  Future<UserProfile?> build() async {
    // Sync from identity session without wiping in-flight login errors.
    ref.listen(identitySessionProvider, (previous, next) {
      if (state.isLoading) return;
      // Keep failed-login errors visible until credentials succeed.
      if (state.hasError && next.profile == null) return;
      state = AsyncData(next.profile);
    });
    return ref.read(identitySessionProvider).profile;
  }

  AuthRepository? get _repository => ref.read(authRepositoryProvider);

  Future<LoginResult?> signIn({
    required String email,
    required String password,
    bool rememberMe = false,
    String? redirectPath,
  }) async {
    final repository = _repository;
    final security = ref.read(securityServiceProvider);
    if (repository == null) {
      state = AsyncError(
        const AuthenticationException(
          'Sign in is unavailable. Restart the app with Supabase configured (env.json).',
        ),
        StackTrace.current,
      );
      return null;
    }

    final credentials = LoginCredentials(
      email: email.trim(),
      password: password,
      rememberMe: rememberMe,
    );
    if (!LoginValidator.isValid(credentials)) {
      state = AsyncError(
        const AuthenticationException('Please enter a valid email and password.'),
        StackTrace.current,
      );
      return null;
    }

    if (security.isLockedOut) {
      final remaining = security.lockoutRemaining;
      state = AsyncError(
        AuthenticationException(
          'Too many failed attempts. Try again in ${remaining?.inMinutes ?? 15} minutes.',
        ),
        StackTrace.current,
      );
      return null;
    }

    final delay = security.progressiveDelay();
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }

    state = const AsyncLoading();
    LoginResult? result;
    state = await AsyncValue.guard(() async {
      try {
        final profile = await repository.signInWithEmail(
          email: credentials.email,
          password: credentials.password,
        );

        await _persistRememberMe(rememberMe);

        security.recordSuccessfulLogin(userId: profile.id, email: profile.email);
        await ref.read(identitySessionProvider.notifier).refreshPermissions();
        ref.read(sessionServiceProvider)?.startMonitoring();

        final sessionId = await ref.read(sessionRepositoryProvider)?.registerCurrentSession(
              userId: profile.id,
            );

        final destination = SmartLoginRouter.resolve(
          SmartLoginContext(
            profile: profile,
            redirectPath: redirectPath,
            permissions: repository.currentPermissions,
            profileComplete: _isProfileComplete(profile),
          ),
        );

        // MFA gate — Adaptive Security Engine™
        final mfa = ref.read(mfaServiceProvider);
        final mfaStatus = await mfa.status(role: profile.primaryRole);
        final trusted = await mfa.isCurrentDeviceTrusted();
        final decision = mfa.evaluateLogin(
          role: profile.primaryRole,
          status: mfaStatus,
          trustedDevice: trusted,
          newDevice: !trusted,
        );

        var needsChallenge = false;
        var needsSetup = false;
        var nextPath = destination;

        final emailPending = !profile.emailConfirmed ||
            destination.startsWith(RoutePaths.verifyEmail);

        if (!emailPending && decision.requireMfa) {
          if (decision.reason == 'mfa_enrollment_required') {
            needsSetup = true;
            final enc = Uri.encodeComponent(destination);
            nextPath = '${RoutePaths.mfaSetup}?required=1&redirect=$enc';
          } else {
            needsChallenge = true;
            final enc = Uri.encodeComponent(destination);
            nextPath = '${RoutePaths.mfaChallenge}?redirect=$enc';
          }
        }

        result = LoginResult(
          profile: profile,
          destination: nextPath,
          needsEmailVerification: !profile.emailConfirmed,
          needsMfaChallenge: needsChallenge,
          needsMfaSetup: needsSetup,
          sessionId: sessionId,
        );

        ref.read(goRouterProvider).go(nextPath);
        return profile;
      } catch (e) {
        security.recordFailedLogin(
          email: credentials.email,
          reason: e is AppException ? e.message : 'auth_error',
        );
        rethrow;
      }
    });
    return result;
  }

  Future<void> _persistRememberMe(bool rememberMe) async {
    try {
      final storage = await ref.read(storageServiceProvider.future);
      await storage.setRememberMe(rememberMe);
      // Supabase Flutter persists sessions by default; remember-me preference
      // is stored for product analytics / future session-duration policies.
    } catch (_) {}
  }

  bool _isProfileComplete(UserProfile profile) {
    return (profile.firstName?.trim().isNotEmpty ?? false) &&
        (profile.lastName?.trim().isNotEmpty ?? false);
  }

  Future<void> signUp({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
    Map<String, dynamic>? metadata,
  }) async {
    final repository = _repository;
    if (repository == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final profile = await repository.signUpWithEmail(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        metadata: metadata,
      );
      return profile;
    });
  }

  Future<void> signOut({bool everywhere = false}) async {
    final userId = state.valueOrNull?.id;
    ref.read(securityServiceProvider).recordLogout(userId: userId);
    await ref.read(identitySessionProvider.notifier).signOut(everywhere: everywhere);
    state = const AsyncData(null);
    ref.read(goRouterProvider).go('/');
  }

  Future<void> resetPassword(String email) async {
    final repository = _repository;
    if (repository == null) return;
    await repository.resetPassword(email);
    ref.read(securityServiceProvider).record(
          SecurityEvent(
            type: SecurityEventType.passwordResetRequested,
            timestamp: DateTime.now(),
            email: email,
          ),
        );
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, UserProfile?>(AuthController.new);
