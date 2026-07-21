import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/account_security_models.dart';
import 'package:hdhomesproject/features/authentication/domain/services/account_security_service.dart';
import 'package:hdhomesproject/features/authentication/domain/services/registration_validator.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/auth_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/verification_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final accountSecurityServiceProvider = Provider<AccountSecurityService>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return AccountSecurityService(
    authRepository: ref.watch(authRepositoryProvider),
    security: ref.watch(securityServiceProvider),
    sessions: ref.watch(sessionRepositoryProvider),
    client: configured ? ref.watch(supabaseClientProvider) : null,
  );
});

final securityHealthProvider = Provider<SecurityHealthSnapshot>((ref) {
  final verification = ref.watch(verificationSnapshotProvider);
  return SecurityHealthSnapshot.compute(
    passwordStrength: PasswordStrength.good,
    emailVerified: verification.emailVerified,
    phoneVerified: verification.phoneVerified,
  );
});

class AccountSecurityUiState {
  const AccountSecurityUiState({
    this.isSubmitting = false,
    this.message,
    this.error,
    this.recoveryReady = false,
  });

  final bool isSubmitting;
  final String? message;
  final String? error;
  final bool recoveryReady;

  AccountSecurityUiState copyWith({
    bool? isSubmitting,
    String? message,
    String? error,
    bool? recoveryReady,
    bool clearMessage = false,
    bool clearError = false,
  }) {
    return AccountSecurityUiState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      message: clearMessage ? null : (message ?? this.message),
      error: clearError ? null : (error ?? this.error),
      recoveryReady: recoveryReady ?? this.recoveryReady,
    );
  }
}

class AccountSecurityController extends Notifier<AccountSecurityUiState> {
  @override
  AccountSecurityUiState build() => const AccountSecurityUiState();

  AccountSecurityService get _service =>
      ref.read(accountSecurityServiceProvider);

  void markRecoveryReady(bool ready) {
    state = state.copyWith(recoveryReady: ready);
  }

  Future<bool> requestReset(String email) async {
    state = state.copyWith(isSubmitting: true, clearError: true, clearMessage: true);
    try {
      await _service.requestPasswordReset(email);
      state = state.copyWith(
        isSubmitting: false,
        message:
            'If an account exists for that email, we sent a secure reset link. Check your inbox and spam folder.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: e.toString().replaceFirst(RegExp(r'^[^:]+:\s*'), ''),
      );
      return false;
    }
  }

  Future<bool> completeReset({
    required String password,
    required String confirm,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true, clearMessage: true);
    try {
      final role = ref.read(identitySessionProvider).primaryRole;
      await _service.completePasswordReset(
        newPassword: password,
        confirmPassword: confirm,
        role: role,
      );
      state = state.copyWith(
        isSubmitting: false,
        message: 'Password updated. Please sign in with your new password.',
        recoveryReady: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: e.toString().replaceFirst(RegExp(r'^[^:]+:\s*'), ''),
      );
      return false;
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
    bool revokeOtherSessions = true,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true, clearMessage: true);
    try {
      final role = ref.read(identitySessionProvider).primaryRole;
      await _service.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
        revokeOtherSessions: revokeOtherSessions,
        role: role,
      );
      state = state.copyWith(
        isSubmitting: false,
        message: 'Password changed successfully.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: e.toString().replaceFirst(RegExp(r'^[^:]+:\s*'), ''),
      );
      return false;
    }
  }
}

final accountSecurityControllerProvider =
    NotifierProvider<AccountSecurityController, AccountSecurityUiState>(
  AccountSecurityController.new,
);

bool isPasswordRecoveryEvent(AuthChangeEvent event) {
  return event == AuthChangeEvent.passwordRecovery;
}
