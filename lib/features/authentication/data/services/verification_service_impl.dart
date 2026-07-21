import 'package:flutter/foundation.dart';
import 'package:hdhomesproject/core/auth/models/security_event.dart';
import 'package:hdhomesproject/core/auth/services/security_service.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/validators/email_validator.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/app_role.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/verification_models.dart';
import 'package:hdhomesproject/features/authentication/domain/repositories/auth_repository.dart';
import 'package:hdhomesproject/features/authentication/domain/services/phone_otp_service.dart';
import 'package:hdhomesproject/features/authentication/domain/services/verification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VerificationServiceImpl implements VerificationService {
  VerificationServiceImpl({
    required AuthRepository? authRepository,
    required PhoneOtpService phoneOtp,
    required SecurityService security,
    SupabaseClient? client,
  })  : _auth = authRepository,
        _phoneOtp = phoneOtp,
        _security = security,
        _client = client;

  final AuthRepository? _auth;
  final PhoneOtpService _phoneOtp;
  final SecurityService _security;
  final SupabaseClient? _client;

  int _emailResendCount = 0;
  DateTime? _emailCooldownUntil;
  int _otpResendCount = 0;
  DateTime? _otpCooldownUntil;
  int _otpVerifyAttempts = 0;
  String? _activeOtpRequestId;

  @override
  VerificationSnapshot snapshotFor({
    required String? email,
    required bool emailConfirmed,
    String? phone,
    bool phoneConfirmed = false,
    AppRole? role,
  }) {
    final policy = VerificationPolicyCatalog.forRole(role);
    final emailStatus = emailConfirmed
        ? EmailVerificationStatus.verified
        : (email == null || email.isEmpty
            ? EmailVerificationStatus.unverified
            : EmailVerificationStatus.pending);
    final phoneStatus = phoneConfirmed
        ? PhoneVerificationStatus.verified
        : (phone == null || phone.isEmpty
            ? PhoneVerificationStatus.notAdded
            : PhoneVerificationStatus.pending);

    return VerificationSnapshot(
      email: email,
      phone: phone,
      emailStatus: emailStatus,
      phoneStatus: phoneStatus,
      emailLifecycle: emailConfirmed
          ? VerificationLifecycle.verified
          : VerificationLifecycle.waiting,
      phoneLifecycle: phoneConfirmed
          ? VerificationLifecycle.verified
          : (phone == null || phone.isEmpty
              ? VerificationLifecycle.notAdded
              : VerificationLifecycle.pending),
      trustScore: TrustScoreFoundation.compute(
        emailVerified: emailConfirmed,
        phoneVerified: phoneConfirmed,
      ),
      policy: policy,
    );
  }

  @override
  Future<void> sendEmailVerification(String email) async {
    final error = EmailValidator.validate(email);
    if (error != null) {
      throw AuthenticationException(error);
    }

    final now = DateTime.now();
    if (_emailCooldownUntil != null && now.isBefore(_emailCooldownUntil!)) {
      final secs = _emailCooldownUntil!.difference(now).inSeconds;
      throw AuthenticationException(
        'Please wait ${secs}s before requesting another email.',
      );
    }
    if (_emailResendCount >= OtpSecurityPolicy.maxEmailResendAttempts) {
      throw const AuthenticationException(
        'Too many verification emails requested. Try again later or contact support.',
      );
    }

    final auth = _auth;
    if (auth == null) {
      throw const AuthenticationException('Authentication is not configured.');
    }

    // Anti-enumeration: same success path regardless of whether email exists.
    try {
      await auth.resendSignupEmail(email.trim());
    } catch (_) {
      // Swallow provider detail; still cooldown.
    }

    _emailResendCount++;
    _emailCooldownUntil = now.add(OtpSecurityPolicy.emailResendCooldown);
    _audit(
      action: 'email_verification_sent',
      email: email.trim(),
      success: true,
    );
  }

  @override
  Future<void> requestEmailChange(String newEmail) async {
    final error = EmailValidator.validate(newEmail);
    if (error != null) {
      throw AuthenticationException(error);
    }
    final client = _client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) {
      throw const AuthenticationException('Sign in to change your email.');
    }

    try {
      await client.auth.updateUser(UserAttributes(email: newEmail.trim()));
    } catch (e) {
      throw const AuthenticationException(
        'Unable to start email change. Please try again.',
      );
    }

    try {
      await client.from('email_change_requests').insert({
        'user_id': user.id,
        'new_email': newEmail.trim(),
        'status': 'pending',
      });
    } catch (_) {}

    _audit(
      action: 'email_change_requested',
      email: newEmail.trim(),
      userId: user.id,
      success: true,
    );
  }

  @override
  Future<PhoneOtpSendResult> sendPhoneOtp({
    required String phoneE164,
    String? userId,
    String purpose = 'phone_verify',
  }) async {
    final digits = phoneE164.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) {
      return const PhoneOtpSendResult(
        success: false,
        message: 'Enter a valid phone number.',
      );
    }

    final now = DateTime.now();
    if (_otpCooldownUntil != null && now.isBefore(_otpCooldownUntil!)) {
      final secs = _otpCooldownUntil!.difference(now).inSeconds;
      return PhoneOtpSendResult(
        success: false,
        message: 'Please wait ${secs}s before requesting another code.',
      );
    }
    if (_otpResendCount >= OtpSecurityPolicy.maxResendAttempts) {
      return const PhoneOtpSendResult(
        success: false,
        message: 'Too many OTP requests. Try again later.',
      );
    }

    final result = await _phoneOtp.sendOtp(
      phoneE164: phoneE164,
      userId: userId,
    );

    if (result.success) {
      _otpResendCount++;
      _otpCooldownUntil = now.add(OtpSecurityPolicy.resendCooldown);
      _otpVerifyAttempts = 0;
      _activeOtpRequestId = result.requestId;
      await _persistOtpRequest(
        phoneE164: phoneE164,
        userId: userId,
        requestId: result.requestId,
        purpose: purpose,
        provider: _phoneOtp.providerId.name,
      );
      _audit(
        action: 'otp_requested',
        userId: userId,
        success: true,
        metadata: {'purpose': purpose, 'provider': _phoneOtp.providerId.name},
      );
    } else {
      _audit(
        action: 'otp_provider_failure',
        userId: userId,
        success: false,
        metadata: {'message': result.message},
      );
    }
    return result;
  }

  @override
  Future<PhoneOtpVerifyResult> verifyPhoneOtp({
    required String phoneE164,
    required String code,
    String? requestId,
    String? userId,
  }) async {
    if (code.trim().length != OtpSecurityPolicy.codeLength) {
      return PhoneOtpVerifyResult(
        success: false,
        message: 'Enter the ${OtpSecurityPolicy.codeLength}-digit code.',
      );
    }
    if (_otpVerifyAttempts >= OtpSecurityPolicy.maxVerifyAttempts) {
      return const PhoneOtpVerifyResult(
        success: false,
        message: 'Too many incorrect attempts. Request a new code.',
      );
    }

    final result = await _phoneOtp.verifyOtp(
      phoneE164: phoneE164,
      code: code,
      requestId: requestId ?? _activeOtpRequestId,
    );

    if (!result.success) {
      _otpVerifyAttempts++;
      _audit(
        action: 'otp_verify_failed',
        userId: userId,
        success: false,
        metadata: {'attempts': _otpVerifyAttempts},
      );
      return result;
    }

    _otpVerifyAttempts = 0;
    await _markPhoneVerified(userId: userId, phoneE164: phoneE164);
    _audit(
      action: 'otp_verified',
      userId: userId,
      success: true,
    );
    return result;
  }

  @override
  Future<List<VerificationEvent>> listEvents({int limit = 20}) async {
    final client = _client;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) return const [];
    try {
      final rows = await client
          .from('verification_events')
          .select('id, channel, event_type, success, metadata, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);
      return (rows as List).map((raw) {
        final row = Map<String, dynamic>.from(raw as Map);
        final channel = row['channel'] == 'phone'
            ? VerificationChannel.phone
            : VerificationChannel.email;
        return VerificationEvent(
          id: row['id'] as String,
          channel: channel,
          eventType: row['event_type'] as String,
          createdAt: DateTime.parse(row['created_at'] as String),
          success: row['success'] as bool? ?? true,
          metadata: Map<String, dynamic>.from(
            (row['metadata'] as Map?) ?? const {},
          ),
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<EmailChangeRequest?> pendingEmailChange() async {
    final client = _client;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) return null;
    try {
      final row = await client
          .from('email_change_requests')
          .select('id, new_email, created_at, expires_at, status')
          .eq('user_id', userId)
          .eq('status', 'pending')
          .order('created_at', ascending: false)
          .maybeSingle();
      if (row == null) return null;
      return EmailChangeRequest(
        id: row['id'] as String,
        newEmail: row['new_email'] as String,
        createdAt: DateTime.parse(row['created_at'] as String),
        expiresAt: row['expires_at'] != null
            ? DateTime.parse(row['expires_at'] as String)
            : null,
        confirmed: false,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistOtpRequest({
    required String phoneE164,
    required String purpose,
    required String provider,
    String? userId,
    String? requestId,
  }) async {
    final client = _client;
    if (client == null) return;
    try {
      await client.from('otp_requests').insert({
        'user_id': userId ?? client.auth.currentUser?.id,
        'phone': phoneE164,
        'purpose': purpose,
        'provider': provider,
        'external_request_id': requestId,
        'expires_at': DateTime.now()
            .toUtc()
            .add(OtpSecurityPolicy.expiry)
            .toIso8601String(),
        'metadata': {
          'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
        },
      });
    } catch (_) {}
  }

  Future<void> _markPhoneVerified({
    String? userId,
    required String phoneE164,
  }) async {
    final client = _client;
    final id = userId ?? client?.auth.currentUser?.id;
    if (client == null || id == null) return;
    try {
      await client.from('profiles').update({
        'phone': phoneE164,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', id);
      await client.from('phone_change_requests').upsert({
        'user_id': id,
        'new_phone': phoneE164,
        'status': 'verified',
        'verified_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id');
    } catch (_) {}
  }

  void _audit({
    required String action,
    String? email,
    String? userId,
    bool success = true,
    Map<String, dynamic> metadata = const {},
  }) {
    final type = switch (action) {
      'email_verification_sent' || 'email_change_requested' =>
        SecurityEventType.emailVerificationSent,
      'otp_verified' || 'phone_verified' => SecurityEventType.phoneVerified,
      'otp_requested' => SecurityEventType.otpRequested,
      'otp_verify_failed' || 'otp_provider_failure' => SecurityEventType.otpFailed,
      _ when success => SecurityEventType.emailVerified,
      _ => SecurityEventType.otpFailed,
    };

    _security.record(
      SecurityEvent(
        type: type,
        timestamp: DateTime.now(),
        userId: userId,
        email: email,
        userAgent: kIsWeb ? 'web' : defaultTargetPlatform.name,
        metadata: {'action': action, 'success': success, ...metadata},
      ),
    );

    final client = _client;
    if (client == null) return;
    // Best-effort verification_events insert (RPC preferred when migration applied).
    // ignore: unawaited_futures
    client.rpc(
      'record_verification_event',
      params: {
        'p_user_id': userId ?? client.auth.currentUser?.id,
        'p_channel': action.startsWith('otp') || action.contains('phone')
            ? 'phone'
            : 'email',
        'p_event_type': action,
        'p_success': success,
        'p_metadata': metadata,
      },
    ).then((_) {}, onError: (_) {
      client.from('verification_events').insert({
        'user_id': userId ?? client.auth.currentUser?.id,
        'channel': action.startsWith('otp') || action.contains('phone')
            ? 'phone'
            : 'email',
        'event_type': action,
        'success': success,
        'metadata': metadata,
      }).then((_) {}, onError: (_) {});
    });
  }
}
