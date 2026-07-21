import 'package:hdhomesproject/features/authentication/domain/entities/app_role.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/verification_models.dart';
import 'package:hdhomesproject/features/authentication/domain/services/phone_otp_service.dart';

/// Unified Verification Service™ — single entry point for all verification flows.
abstract interface class VerificationService {
  VerificationSnapshot snapshotFor({
    required String? email,
    required bool emailConfirmed,
    String? phone,
    bool phoneConfirmed = false,
    AppRole? role,
  });

  Future<void> sendEmailVerification(String email);

  Future<void> requestEmailChange(String newEmail);

  Future<PhoneOtpSendResult> sendPhoneOtp({
    required String phoneE164,
    String? userId,
    String purpose = 'phone_verify',
  });

  Future<PhoneOtpVerifyResult> verifyPhoneOtp({
    required String phoneE164,
    required String code,
    String? requestId,
    String? userId,
  });

  Future<List<VerificationEvent>> listEvents({int limit = 20});

  Future<EmailChangeRequest?> pendingEmailChange();
}
