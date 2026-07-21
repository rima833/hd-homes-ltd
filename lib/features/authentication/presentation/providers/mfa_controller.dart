import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/mfa_models.dart';
import 'package:hdhomesproject/features/authentication/domain/services/device_fingerprint_service.dart';
import 'package:hdhomesproject/features/authentication/domain/services/mfa_service.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/account_security_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/auth_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

final mfaServiceProvider = Provider<MfaService>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  final fp = ref.watch(deviceFingerprintServiceProvider).valueOrNull;
  return MfaService(
    security: ref.watch(securityServiceProvider),
    client: configured ? ref.watch(supabaseClientProvider) : null,
    fingerprint: fp,
  );
});

final mfaStatusProvider = FutureProvider<MfaStatusSnapshot>((ref) async {
  final role = ref.watch(identitySessionProvider).primaryRole;
  return ref.watch(mfaServiceProvider).status(role: role);
});

class MfaUiState {
  const MfaUiState({
    this.step = 0,
    this.isBusy = false,
    this.enrollment,
    this.backupCodes,
    this.message,
    this.error,
    this.selectedMethod = MfaMethodKind.totp,
  });

  final int step;
  final bool isBusy;
  final MfaEnrollmentDraft? enrollment;
  final BackupCodeBundle? backupCodes;
  final String? message;
  final String? error;
  final MfaMethodKind selectedMethod;

  MfaUiState copyWith({
    int? step,
    bool? isBusy,
    MfaEnrollmentDraft? enrollment,
    BackupCodeBundle? backupCodes,
    String? message,
    String? error,
    MfaMethodKind? selectedMethod,
    bool clearError = false,
    bool clearMessage = false,
  }) {
    return MfaUiState(
      step: step ?? this.step,
      isBusy: isBusy ?? this.isBusy,
      enrollment: enrollment ?? this.enrollment,
      backupCodes: backupCodes ?? this.backupCodes,
      message: clearMessage ? null : (message ?? this.message),
      error: clearError ? null : (error ?? this.error),
      selectedMethod: selectedMethod ?? this.selectedMethod,
    );
  }
}

class MfaController extends Notifier<MfaUiState> {
  @override
  MfaUiState build() => const MfaUiState();

  MfaService get _service => ref.read(mfaServiceProvider);

  void setStep(int step) => state = state.copyWith(step: step, clearError: true);

  void selectMethod(MfaMethodKind method) {
    state = state.copyWith(selectedMethod: method, clearError: true);
  }

  Future<void> startEnrollment() async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final draft = await _service.startTotpEnrollment();
      state = state.copyWith(
        isBusy: false,
        enrollment: draft,
        step: 3,
      );
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: e.toString().replaceFirst(RegExp(r'^[^:]+:\s*'), ''),
      );
    }
  }

  Future<bool> confirmEnrollment(String code) async {
    final enrollment = state.enrollment;
    if (enrollment == null) return false;
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final codes = await _service.confirmTotpEnrollment(
        factorId: enrollment.factorId,
        code: code,
      );
      state = state.copyWith(
        isBusy: false,
        backupCodes: codes,
        step: 5,
        message: 'MFA successfully enabled.',
      );
      ref.invalidate(mfaStatusProvider);
      return true;
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: e.toString().replaceFirst(RegExp(r'^[^:]+:\s*'), ''),
      );
      return false;
    }
  }

  Future<bool> verifyChallenge({
    required String factorId,
    required String code,
    bool trustDevice = false,
  }) async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await _service.verifyLoginFactor(factorId: factorId, code: code);
      if (trustDevice) {
        final role = ref.read(identitySessionProvider).primaryRole;
        final policy = MfaPolicyCatalog.forRole(role);
        await _service.trustCurrentDevice(durationDays: policy.trustDurationDays);
      }
      state = state.copyWith(isBusy: false, message: 'Verification successful.');
      ref.invalidate(mfaStatusProvider);
      return true;
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: e.toString().replaceFirst(RegExp(r'^[^:]+:\s*'), ''),
      );
      return false;
    }
  }

  Future<bool> verifyWithBackupCode(String code) async {
    state = state.copyWith(isBusy: true, clearError: true);
    final ok = await _service.verifyBackupCode(code);
    state = state.copyWith(
      isBusy: false,
      error: ok ? null : 'Invalid or used backup code.',
      message: ok ? 'Backup code accepted.' : null,
      clearError: ok,
    );
    if (ok) ref.invalidate(mfaStatusProvider);
    return ok;
  }

  Future<void> regenerateBackupCodes() async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final codes = await _service.regenerateBackupCodes();
      state = state.copyWith(isBusy: false, backupCodes: codes);
      ref.invalidate(mfaStatusProvider);
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: e.toString().replaceFirst(RegExp(r'^[^:]+:\s*'), ''),
      );
    }
  }

  Future<bool> disableMfa(String code) async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await _service.disableMfa(code: code);
      state = state.copyWith(
        isBusy: false,
        message: 'MFA disabled.',
        enrollment: null,
        backupCodes: null,
        step: 0,
      );
      ref.invalidate(mfaStatusProvider);
      return true;
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: e.toString().replaceFirst(RegExp(r'^[^:]+:\s*'), ''),
      );
      return false;
    }
  }

  void finishWizard() {
    state = state.copyWith(step: 6);
  }
}

final mfaControllerProvider =
    NotifierProvider<MfaController, MfaUiState>(MfaController.new);

/// Ensures fingerprint service is warmed for MFA trust.
final mfaFingerprintWarmupProvider = FutureProvider<DeviceFingerprintService?>((ref) async {
  if (!ref.watch(supabaseConfiguredProvider)) return null;
  final prefs = await SharedPreferences.getInstance();
  return DeviceFingerprintService(prefs);
});

/// Security readiness combining Part 5 health + MFA.
final securityReadinessProvider = Provider<int>((ref) {
  final health = ref.watch(securityHealthProvider);
  final mfa = ref.watch(mfaStatusProvider).valueOrNull;
  return SecurityReadinessScore.compute(
    baseSecurityHealth: health.score,
    mfaEnabled: mfa?.enabled ?? false,
    hasBackupCodes: (mfa?.backupCodesRemaining ?? 0) > 0,
    hasTrustedDevices: (mfa?.trustedDeviceCount ?? 0) > 0,
  );
});
