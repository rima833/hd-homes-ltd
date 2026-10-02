import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/authentication/data/services/verification_service_impl.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/verification_models.dart';
import 'package:hdhomesproject/features/authentication/domain/services/phone_otp_service.dart';
import 'package:hdhomesproject/features/authentication/domain/services/sms_provider_adapters.dart';
import 'package:hdhomesproject/features/authentication/domain/services/verification_service.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/identity_provider.dart';

final phoneOtpServiceProvider = Provider<PhoneOtpService>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  if (!configured) {
    return const MockPhoneOtpService();
  }
  final client = ref.watch(supabaseClientProvider);
  return FailoverPhoneOtpService(
    primary: SupabaseAuthPhoneOtpService(client),
    fallbacks: [
      if (allowMockPhoneOtp) const MockPhoneOtpService(),
      const TermiiPhoneOtpService(),
      const TwilioPhoneOtpService(),
      const AfricasTalkingPhoneOtpService(),
    ],
  );
});

final verificationServiceProvider = Provider<VerificationService>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return VerificationServiceImpl(
    authRepository: ref.watch(authRepositoryProvider),
    phoneOtp: ref.watch(phoneOtpServiceProvider),
    security: ref.watch(securityServiceProvider),
    client: configured ? ref.watch(supabaseClientProvider) : null,
  );
});

/// Live verification snapshot derived from identity session.
final verificationSnapshotProvider = Provider<VerificationSnapshot>((ref) {
  final session = ref.watch(identitySessionProvider);
  final service = ref.watch(verificationServiceProvider);
  final phone = session.profile?.phone?.trim();
  final phoneOnFile = (phone != null && phone.isNotEmpty) ||
      (session.profile?.phoneVerified ?? false);
  return service.snapshotFor(
    email: session.email ?? session.profile?.email,
    emailConfirmed: session.emailConfirmed,
    phone: phone,
    // Phone from registration / profile counts as confirmed (no SMS OTP).
    phoneConfirmed: phoneOnFile,
    role: session.primaryRole,
  );
});

class VerificationUiState {
  const VerificationUiState({
    this.emailLifecycle = VerificationLifecycle.waiting,
    this.phoneLifecycle = VerificationLifecycle.notAdded,
    this.emailCooldownSeconds = 0,
    this.phoneCooldownSeconds = 0,
    this.message,
    this.error,
    this.otpRequestId,
  });

  final VerificationLifecycle emailLifecycle;
  final VerificationLifecycle phoneLifecycle;
  final int emailCooldownSeconds;
  final int phoneCooldownSeconds;
  final String? message;
  final String? error;
  final String? otpRequestId;

  VerificationUiState copyWith({
    VerificationLifecycle? emailLifecycle,
    VerificationLifecycle? phoneLifecycle,
    int? emailCooldownSeconds,
    int? phoneCooldownSeconds,
    String? message,
    String? error,
    String? otpRequestId,
    bool clearMessage = false,
    bool clearError = false,
  }) {
    return VerificationUiState(
      emailLifecycle: emailLifecycle ?? this.emailLifecycle,
      phoneLifecycle: phoneLifecycle ?? this.phoneLifecycle,
      emailCooldownSeconds: emailCooldownSeconds ?? this.emailCooldownSeconds,
      phoneCooldownSeconds: phoneCooldownSeconds ?? this.phoneCooldownSeconds,
      message: clearMessage ? null : (message ?? this.message),
      error: clearError ? null : (error ?? this.error),
      otpRequestId: otpRequestId ?? this.otpRequestId,
    );
  }
}

class VerificationController extends Notifier<VerificationUiState> {
  @override
  VerificationUiState build() {
    final snap = ref.watch(verificationSnapshotProvider);
    return VerificationUiState(
      emailLifecycle: snap.emailLifecycle,
      phoneLifecycle: snap.phoneLifecycle,
    );
  }

  VerificationService get _service => ref.read(verificationServiceProvider);

  Future<void> resendEmail(String email) async {
    state = state.copyWith(
      emailLifecycle: VerificationLifecycle.resending,
      clearError: true,
      clearMessage: true,
    );
    try {
      await _service.sendEmailVerification(email);
      state = state.copyWith(
        emailLifecycle: VerificationLifecycle.sent,
        emailCooldownSeconds: OtpSecurityPolicy.emailResendCooldown.inSeconds,
        message: 'Verification email sent. Check your inbox and spam folder.',
      );
    } catch (e) {
      state = state.copyWith(
        emailLifecycle: VerificationLifecycle.failed,
        error: userFacingError(e),
      );
    }
  }

  Future<void> requestEmailChange(String newEmail) async {
    state = state.copyWith(clearError: true, clearMessage: true);
    try {
      await _service.requestEmailChange(newEmail);
      state = state.copyWith(
        emailLifecycle: VerificationLifecycle.sent,
        message: 'Confirmation sent to the new address. It becomes active after you verify.',
      );
    } catch (e) {
      state = state.copyWith(
        error: userFacingError(e),
      );
    }
  }

  Future<bool> sendPhoneOtp(String phone) async {
    state = state.copyWith(
      phoneLifecycle: VerificationLifecycle.sending,
      clearError: true,
      clearMessage: true,
    );
    final userId = ref.read(identitySessionProvider).userId;
    final result = await _service.sendPhoneOtp(
      phoneE164: phone,
      userId: userId,
    );
    if (!result.success) {
      state = state.copyWith(
        phoneLifecycle: VerificationLifecycle.failed,
        error: result.message ?? 'Unable to send code.',
      );
      return false;
    }
    state = state.copyWith(
      phoneLifecycle: VerificationLifecycle.sent,
      phoneCooldownSeconds: OtpSecurityPolicy.resendCooldown.inSeconds,
      otpRequestId: result.requestId,
      message: result.message ?? 'Verification code sent.',
    );
    return true;
  }

  Future<bool> verifyPhoneOtp({
    required String phone,
    required String code,
  }) async {
    state = state.copyWith(clearError: true, clearMessage: true);
    final userId = ref.read(identitySessionProvider).userId;
    final result = await _service.verifyPhoneOtp(
      phoneE164: phone,
      code: code,
      requestId: state.otpRequestId,
      userId: userId,
    );
    if (!result.success) {
      state = state.copyWith(
        phoneLifecycle: VerificationLifecycle.failed,
        error: result.message ?? 'Invalid code.',
      );
      return false;
    }
    state = state.copyWith(
      phoneLifecycle: VerificationLifecycle.verified,
      message: 'Phone number verified.',
    );
    // Reload profile so phone_verified chips update across portals.
    await ref.read(identitySessionProvider.notifier).reloadProfile();
    return true;
  }

  void tickCooldowns() {
    final email = state.emailCooldownSeconds > 0 ? state.emailCooldownSeconds - 1 : 0;
    final phone = state.phoneCooldownSeconds > 0 ? state.phoneCooldownSeconds - 1 : 0;
    if (email != state.emailCooldownSeconds || phone != state.phoneCooldownSeconds) {
      state = state.copyWith(
        emailCooldownSeconds: email,
        phoneCooldownSeconds: phone,
      );
    }
  }

  void markEmailVerified() {
    state = state.copyWith(
      emailLifecycle: VerificationLifecycle.verified,
      message: 'Email verified successfully.',
      clearError: true,
    );
  }

  /// Checks Supabase Auth for real confirmation, then reports the result.
  ///
  /// Cross-device note: confirming on a phone does not create a session in the
  /// local Flutter web tab. When there is no Auth session, callers should send
  /// the user to Login instead of treating that as “not verified”.
  Future<bool> confirmVerifiedFromServer() async {
    state = state.copyWith(clearError: true, clearMessage: true);
    try {
      final session = ref.read(identitySessionProvider);
      if (session.userId == null) {
        // No local session — cannot read email_confirmed_at here.
        // After confirming on another device, Sign in is the correct next step.
        state = state.copyWith(
          message:
              'If you already tapped Confirm in your email, sign in with your '
              'password to continue.',
          clearError: true,
        );
        return true;
      }

      final ok = await ref
          .read(identitySessionProvider.notifier)
          .confirmEmailVerifiedFromServer();
      if (ok) {
        markEmailVerified();
        return true;
      }
      state = state.copyWith(
        emailLifecycle: VerificationLifecycle.waiting,
        error:
            'Your email has not been verified yet. Please open the confirmation '
            'email and click the verification link. After that, tap Continue to Sign in.',
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        error: userFacingError(e),
      );
      return false;
    }
  }
}

final verificationControllerProvider =
    NotifierProvider<VerificationController, VerificationUiState>(
  VerificationController.new,
);
