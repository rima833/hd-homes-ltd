import 'package:hdhomesproject/features/authentication/domain/entities/registration_models.dart';

/// Intelligent Registration Assistant — contextual guidance (Phase 1: static tips).
/// Future: HD Homes AI Concierge can replace these copy sources.
abstract final class RegistrationAssistant {
  static String tipForStep(
    RegistrationStep step, {
    RegistrationAccountType? accountType,
  }) {
    return switch (step) {
      RegistrationStep.accountType =>
        'Choose Client if you are buying or exploring homes. Choose Investor if you want portfolios, ROI tools, and the Investor Portal.',
      RegistrationStep.personalInfo => accountType == RegistrationAccountType.investor
          ? 'Use the email you will use for investment documents and KYC. A referral code is optional.'
          : 'Use an email you check regularly — we send inspection updates and purchase progress here.',
      RegistrationStep.credentials => accountType == RegistrationAccountType.investor
          ? 'Create a strong password to protect portfolio data and investment documents.'
          : 'Create a strong password to protect saved properties and booking history.',
      RegistrationStep.legal =>
        'We record the document versions you accept for compliance. Marketing options are optional.',
      RegistrationStep.review => accountType == RegistrationAccountType.investor
          ? 'Confirm your details, then create your investor account. You can complete KYC after verification.'
          : 'Confirm your details, then create your client account. You can browse and book right after verification.',
    };
  }

  static String onboardingHint(RegistrationAccountType? accountType) {
    if (accountType == RegistrationAccountType.investor) {
      return 'After signup you will verify email, then explore opportunities and finish KYC when prompted.';
    }
    return 'After signup you will verify email, then save favorites and book inspections from your dashboard.';
  }
}
