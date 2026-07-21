import 'package:hdhomesproject/features/authentication/domain/entities/registration_models.dart';

/// Contract for Progressive Registration™.
abstract interface class RegistrationRepository {
  Future<RegistrationResult> register(RegistrationDraft draft);

  Future<bool> isReferralCodeValid(String code);

  void trackEvent(
    RegistrationAnalyticsEvent event, {
    RegistrationStep? step,
    RegistrationAccountType? accountType,
    Map<String, dynamic> metadata = const {},
  });
}
