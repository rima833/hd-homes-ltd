import 'package:hdhomesproject/features/authentication/domain/services/phone_otp_service.dart';

/// Provider Failover Architecture — try primary, then backups.
class FailoverPhoneOtpService implements PhoneOtpService {
  FailoverPhoneOtpService({
    required this.primary,
    this.fallbacks = const [],
    this.onFailover,
  });

  final PhoneOtpService primary;
  final List<PhoneOtpService> fallbacks;
  final void Function(PhoneOtpProviderId from, PhoneOtpProviderId to, String reason)?
      onFailover;

  PhoneOtpProviderId _lastUsed = PhoneOtpProviderId.mock;

  @override
  PhoneOtpProviderId get providerId => _lastUsed;

  Iterable<PhoneOtpService> get _chain sync* {
    yield primary;
    yield* fallbacks;
  }

  @override
  Future<PhoneOtpSendResult> sendOtp({
    required String phoneE164,
    String? userId,
  }) async {
    PhoneOtpProviderId? previous;
    Object? lastError;
    for (final provider in _chain) {
      try {
        final result = await provider.sendOtp(
          phoneE164: phoneE164,
          userId: userId,
        );
        if (result.success) {
          if (previous != null && previous != provider.providerId) {
            onFailover?.call(
              previous,
              provider.providerId,
              'primary_failed',
            );
          }
          _lastUsed = provider.providerId;
          return result;
        }
        lastError = result.message;
        previous = provider.providerId;
      } catch (e) {
        lastError = e;
        previous = provider.providerId;
      }
    }
    return PhoneOtpSendResult(
      success: false,
      message: lastError?.toString() ?? 'Unable to send verification code.',
    );
  }

  @override
  Future<PhoneOtpVerifyResult> verifyOtp({
    required String phoneE164,
    required String code,
    String? requestId,
  }) {
    // Verification always goes through the last successful send provider;
    // for Phase 1 mock + future Edge Function, primary owns validation.
    return primary.verifyOtp(
      phoneE164: phoneE164,
      code: code,
      requestId: requestId,
    );
  }
}

/// Stub adapters — swap to Edge Function HTTP when credentials are configured.
class TermiiPhoneOtpService implements PhoneOtpService {
  const TermiiPhoneOtpService();

  @override
  PhoneOtpProviderId get providerId => PhoneOtpProviderId.termii;

  @override
  Future<PhoneOtpSendResult> sendOtp({
    required String phoneE164,
    String? userId,
  }) async {
    return const PhoneOtpSendResult(
      success: false,
      message: 'Termii provider not configured. Use mock or configure Edge Function.',
    );
  }

  @override
  Future<PhoneOtpVerifyResult> verifyOtp({
    required String phoneE164,
    required String code,
    String? requestId,
  }) async {
    return const PhoneOtpVerifyResult(
      success: false,
      message: 'Termii provider not configured.',
    );
  }
}

class TwilioPhoneOtpService implements PhoneOtpService {
  const TwilioPhoneOtpService();

  @override
  PhoneOtpProviderId get providerId => PhoneOtpProviderId.twilio;

  @override
  Future<PhoneOtpSendResult> sendOtp({
    required String phoneE164,
    String? userId,
  }) async {
    return const PhoneOtpSendResult(
      success: false,
      message: 'Twilio provider not configured. Use mock or configure Edge Function.',
    );
  }

  @override
  Future<PhoneOtpVerifyResult> verifyOtp({
    required String phoneE164,
    required String code,
    String? requestId,
  }) async {
    return const PhoneOtpVerifyResult(
      success: false,
      message: 'Twilio provider not configured.',
    );
  }
}

class AfricasTalkingPhoneOtpService implements PhoneOtpService {
  const AfricasTalkingPhoneOtpService();

  @override
  PhoneOtpProviderId get providerId => PhoneOtpProviderId.africasTalking;

  @override
  Future<PhoneOtpSendResult> sendOtp({
    required String phoneE164,
    String? userId,
  }) async {
    return const PhoneOtpSendResult(
      success: false,
      message: "Africa's Talking provider not configured.",
    );
  }

  @override
  Future<PhoneOtpVerifyResult> verifyOtp({
    required String phoneE164,
    required String code,
    String? requestId,
  }) async {
    return const PhoneOtpVerifyResult(
      success: false,
      message: "Africa's Talking provider not configured.",
    );
  }
}
