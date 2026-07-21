/// Phone OTP handoff for post-registration verification.
///
/// UI talks only to this contract so Termii / Twilio / regional providers
/// can be swapped without changing screens.
enum PhoneOtpProviderId { termii, twilio, africasTalking, mock }

class PhoneOtpSendResult {
  const PhoneOtpSendResult({
    required this.success,
    this.requestId,
    this.message,
  });

  final bool success;
  final String? requestId;
  final String? message;
}

class PhoneOtpVerifyResult {
  const PhoneOtpVerifyResult({
    required this.success,
    this.message,
  });

  final bool success;
  final String? message;
}

abstract interface class PhoneOtpService {
  PhoneOtpProviderId get providerId;

  Future<PhoneOtpSendResult> sendOtp({
    required String phoneE164,
    String? userId,
  });

  Future<PhoneOtpVerifyResult> verifyOtp({
    required String phoneE164,
    required String code,
    String? requestId,
  });
}

/// Local stub used until an SMS provider Edge Function is wired.
class MockPhoneOtpService implements PhoneOtpService {
  const MockPhoneOtpService({this.debugCode = '123456'});

  final String debugCode;

  @override
  PhoneOtpProviderId get providerId => PhoneOtpProviderId.mock;

  @override
  Future<PhoneOtpSendResult> sendOtp({
    required String phoneE164,
    String? userId,
  }) async {
    return PhoneOtpSendResult(
      success: true,
      requestId: 'mock-${phoneE164.hashCode.abs()}',
      message: 'OTP queued (mock provider).',
    );
  }

  @override
  Future<PhoneOtpVerifyResult> verifyOtp({
    required String phoneE164,
    required String code,
    String? requestId,
  }) async {
    final ok = code.trim() == debugCode;
    return PhoneOtpVerifyResult(
      success: ok,
      message: ok ? null : 'Invalid verification code.',
    );
  }
}
