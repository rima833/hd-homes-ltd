import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/mfa_models.dart';
import 'package:hdhomesproject/features/authentication/domain/services/device_fingerprint_service.dart';
import 'package:hdhomesproject/features/authentication/domain/services/mfa_service.dart';
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

/// MFA gate snapshot — always waits for a stable device fingerprint so trusted
/// devices are matched before the router decides `/mfa/challenge`.
final mfaStatusProvider = FutureProvider<MfaStatusSnapshot>((ref) async {
  // Select only gate-relevant fields. Watching the full session re-fetched MFA
  // on every token refresh / activity tick and caused dashboard blink loops.
  final gate = ref.watch(
    identitySessionProvider.select(
      (s) => (s.userId, s.primaryRole, s.isAuthenticated),
    ),
  );
  if (!gate.$3 || gate.$1 == null) {
    return const MfaStatusSnapshot(statusKnown: false);
  }

  final fpService = await ref.watch(deviceFingerprintServiceProvider.future);
  // Mint / load the stable id before any trust comparison.
  await fpService.fingerprint();

  final configured = ref.watch(supabaseConfiguredProvider);
  final service = MfaService(
    security: ref.watch(securityServiceProvider),
    client: configured ? ref.watch(supabaseClientProvider) : null,
    fingerprint: fpService,
  );
  return service.status(role: gate.$2);
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
        error: userFacingError(e),
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
        error: userFacingError(e),
      );
      return false;
    }
  }

  Future<bool> verifyChallenge({
    required String factorId,
    required String code,
    bool trustDevice = false,
    int trustDurationDays = MfaTrustDurationOptions.days30,
  }) async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await _service.verifyLoginFactor(factorId: factorId, code: code);
      if (trustDevice) {
        await _persistTrust(trustDurationDays);
      }
      state = state.copyWith(isBusy: false, message: 'Verification successful.');
      ref.invalidate(mfaStatusProvider);
      await ref.read(mfaStatusProvider.future);
      return true;
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: userFacingError(e),
      );
      return false;
    }
  }

  Future<bool> verifyWithBackupCode(
    String code, {
    bool trustDevice = false,
    int trustDurationDays = MfaTrustDurationOptions.days30,
  }) async {
    state = state.copyWith(isBusy: true, clearError: true);
    final ok = await _service.verifyBackupCode(code);
    if (ok && trustDevice) {
      try {
        await _persistTrust(trustDurationDays);
      } catch (e) {
        state = state.copyWith(
          isBusy: false,
          error: userFacingError(e),
          message: 'Backup code accepted, but device trust failed.',
        );
        ref.invalidate(mfaStatusProvider);
        return true;
      }
    }
    state = state.copyWith(
      isBusy: false,
      error: ok ? null : 'Invalid or used backup code.',
      message: ok ? 'Backup code accepted.' : null,
      clearError: ok,
    );
    if (ok) {
      ref.invalidate(mfaStatusProvider);
      await ref.read(mfaStatusProvider.future);
    }
    return ok;
  }

  Future<void> _persistTrust(int trustDurationDays) async {
    final fpService = await ref.read(deviceFingerprintServiceProvider.future);
    await fpService.fingerprint();
    final role = ref.read(identitySessionProvider).primaryRole;
    final policy = MfaPolicyCatalog.forRole(role);
    final configured = ref.read(supabaseConfiguredProvider);
    final service = MfaService(
      security: ref.read(securityServiceProvider),
      client: configured ? ref.read(supabaseClientProvider) : null,
      fingerprint: fpService,
    );
    await service.trustCurrentDevice(
      durationDays: MfaTrustDurationOptions.clampToAllowed(
        trustDurationDays,
      ),
      maxTrustedDevices: policy.maxTrustedDevices,
    );
  }

  Future<void> extendDeviceTrust({
    required String deviceId,
    required int durationDays,
  }) async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await _service.extendTrustedDevice(
        deviceId: deviceId,
        durationDays: durationDays,
      );
      state = state.copyWith(isBusy: false, message: 'Device trust updated.');
      ref.invalidate(mfaStatusProvider);
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: userFacingError(e),
      );
    }
  }

  Future<void> trustThisDevice({
    required int durationDays,
  }) async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await _persistTrust(durationDays);
      state = state.copyWith(isBusy: false, message: 'This device is trusted.');
      ref.invalidate(mfaStatusProvider);
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: userFacingError(e),
      );
    }
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
        error: userFacingError(e),
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
        error: userFacingError(e),
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
