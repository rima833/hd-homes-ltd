import 'package:flutter/foundation.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/utils/app_logger.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/registration_models.dart';
import 'package:hdhomesproject/features/authentication/domain/repositories/auth_repository.dart';
import 'package:hdhomesproject/features/authentication/domain/repositories/registration_repository.dart';
import 'package:hdhomesproject/features/authentication/domain/services/captcha_service.dart';
import 'package:hdhomesproject/features/authentication/domain/services/registration_validator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegistrationRepositoryImpl implements RegistrationRepository {
  RegistrationRepositoryImpl({
    required AuthRepository authRepository,
    SupabaseClient? client,
    CaptchaService captcha = const NoOpCaptchaService(),
  })  : _authRepository = authRepository,
        _client = client,
        _captcha = captcha;

  final AuthRepository _authRepository;
  final SupabaseClient? _client;
  final CaptchaService _captcha;
  final String _sessionKey = DateTime.now().millisecondsSinceEpoch.toString();

  @override
  Future<RegistrationResult> register(RegistrationDraft draft) async {
    if (!RegistrationValidator.stepIsValid(RegistrationStep.review, draft)) {
      throw const RegistrationException(
        'Please complete all registration steps before creating your account.',
      );
    }

    final referralError = RegistrationValidator.validateReferralCode(draft.referralCode);
    if (referralError != null) {
      throw RegistrationException(referralError);
    }

    final captchaToken = await _captcha.obtainToken(action: 'register');
    if (!await _captcha.verifyToken(captchaToken)) {
      throw const RegistrationException(
        'Security check failed. Please refresh and try again.',
      );
    }

    trackEvent(
      RegistrationAnalyticsEvent.submitted,
      accountType: draft.accountType,
    );

    try {
      final metadata = {
        ...draft.toAuthMetadata(),
        'captcha_token': ?captchaToken,
      };

      final profile = await _authRepository.signUpWithEmail(
        email: draft.email.trim(),
        password: draft.password,
        firstName: draft.firstName.trim(),
        lastName: draft.lastName.trim(),
        metadata: metadata,
      );

      final needsVerification = !profile.emailConfirmed;
      trackEvent(
        RegistrationAnalyticsEvent.succeeded,
        accountType: draft.accountType,
        metadata: {'user_id': profile.id, 'needs_verification': needsVerification},
      );

      return RegistrationResult(
        userId: profile.id,
        email: profile.email,
        accountType: draft.accountType ?? RegistrationAccountType.client,
        needsEmailVerification: needsVerification,
        sessionCreated: _client?.auth.currentSession != null,
      );
    } on AuthenticationException catch (e) {
      trackEvent(
        RegistrationAnalyticsEvent.failed,
        accountType: draft.accountType,
        metadata: {'reason': e.message},
      );
      rethrow;
    } catch (e) {
      trackEvent(
        RegistrationAnalyticsEvent.failed,
        accountType: draft.accountType,
        metadata: {'reason': e.toString()},
      );
      if (e is AppException) rethrow;
      throw RegistrationException(
        'Unable to create your account. Please try again.',
        cause: e,
      );
    }
  }

  @override
  Future<bool> isReferralCodeValid(String code) async {
    final error = RegistrationValidator.validateReferralCode(code);
    if (error != null) return false;
    final client = _client;
    if (client == null) {
      // Offline / unconfigured: accept format-valid codes for UX continuity.
      return true;
    }
    try {
      final row = await client
          .from('referral_links')
          .select('id')
          .eq('code', code.trim().toUpperCase())
          .eq('is_active', true)
          .maybeSingle();
      return row != null;
    } catch (_) {
      return true;
    }
  }

  @override
  void trackEvent(
    RegistrationAnalyticsEvent event, {
    RegistrationStep? step,
    RegistrationAccountType? accountType,
    Map<String, dynamic> metadata = const {},
  }) {
    AppLogger.info(
      'RegistrationAnalytics: ${event.name} step=${step?.name} type=${accountType?.id}',
    );
    final client = _client;
    if (client == null) return;
    // Best-effort insert; table may not exist until migration is applied.
    // ignore: unawaited_futures
    client.from('registration_events').insert({
      'session_key': _sessionKey,
      'event_type': event.name,
      'step': step?.name,
      'account_type': accountType?.id,
      'metadata': {
        ...metadata,
        'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      },
    }).then((_) {}, onError: (_) {});
  }
}
