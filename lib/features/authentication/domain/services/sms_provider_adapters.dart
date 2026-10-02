import 'package:flutter/foundation.dart';
import 'package:hdhomesproject/features/authentication/domain/services/phone_otp_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// SMS OTP via Supabase Auth (`updateUser` + `verifyOTP` phone_change).
///
/// Requires Phone provider / SMS to be enabled in Supabase Auth settings.
class SupabaseAuthPhoneOtpService implements PhoneOtpService {
  SupabaseAuthPhoneOtpService(this._client);

  final SupabaseClient _client;

  @override
  PhoneOtpProviderId get providerId => PhoneOtpProviderId.supabaseAuth;

  @override
  Future<PhoneOtpSendResult> sendOtp({
    required String phoneE164,
    String? userId,
  }) async {
    try {
      await _client.auth.updateUser(UserAttributes(phone: phoneE164));
      return PhoneOtpSendResult(
        success: true,
        requestId: phoneE164,
        message: 'We sent a verification code by SMS.',
      );
    } on AuthException catch (e) {
      return PhoneOtpSendResult(
        success: false,
        message: _friendly(e.message),
      );
    } catch (e) {
      return PhoneOtpSendResult(
        success: false,
        message: e.toString().replaceFirst(RegExp(r'^[^:]+:\s*'), ''),
      );
    }
  }

  @override
  Future<PhoneOtpVerifyResult> verifyOtp({
    required String phoneE164,
    required String code,
    String? requestId,
  }) async {
    try {
      await _client.auth.verifyOTP(
        phone: phoneE164,
        token: code.trim(),
        type: OtpType.phoneChange,
      );
      return const PhoneOtpVerifyResult(success: true);
    } on AuthException catch (e) {
      // Some projects use sms type for phone updates.
      try {
        await _client.auth.verifyOTP(
          phone: phoneE164,
          token: code.trim(),
          type: OtpType.sms,
        );
        return const PhoneOtpVerifyResult(success: true);
      } catch (_) {
        return PhoneOtpVerifyResult(
          success: false,
          message: _friendly(e.message),
        );
      }
    } catch (e) {
      return PhoneOtpVerifyResult(
        success: false,
        message: e.toString().replaceFirst(RegExp(r'^[^:]+:\s*'), ''),
      );
    }
  }

  String _friendly(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('phone') && lower.contains('provider')) {
      return 'SMS is not enabled yet. In local development use code 123456, '
          'or enable Phone Auth in Supabase Dashboard.';
    }
    if (lower.contains('rate') || lower.contains('limit')) {
      return 'Too many SMS requests. Please wait and try again.';
    }
    if (lower.contains('invalid') || lower.contains('token')) {
      return 'Invalid or expired code. Request a new one.';
    }
    return raw;
  }
}

/// Provider Failover Architecture — try primary, then backups.
class FailoverPhoneOtpService implements PhoneOtpService {
  FailoverPhoneOtpService({
    required this.primary,
    this.fallbacks = const [],
    this.onFailover,
  });

  final PhoneOtpService primary;
  final List<PhoneOtpService> fallbacks;
  final void Function(
    PhoneOtpProviderId from,
    PhoneOtpProviderId to,
    String reason,
  )? onFailover;

  PhoneOtpService? _lastSuccessfulSend;

  @override
  PhoneOtpProviderId get providerId =>
      _lastSuccessfulSend?.providerId ?? primary.providerId;

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
          _lastSuccessfulSend = provider;
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
    final provider = _lastSuccessfulSend ?? primary;
    return provider.verifyOtp(
      phoneE164: phoneE164,
      code: code,
      requestId: requestId,
    );
  }
}

/// Stub adapters — configure Edge Functions when credentials are available.
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
      message:
          'Termii provider not configured. Use mock or configure Edge Function.',
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
      message:
          'Twilio provider not configured. Use mock or configure Edge Function.',
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

/// Whether mock OTP (code 123456) is allowed in this build.
bool get allowMockPhoneOtp => kDebugMode;
