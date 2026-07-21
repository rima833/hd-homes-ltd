import 'package:hdhomesproject/core/auth/policies/auth_security_policy.dart';
import 'package:hdhomesproject/core/validators/email_validator.dart';
import 'package:hdhomesproject/core/validators/name_validator.dart';
import 'package:hdhomesproject/core/validators/password_validator.dart';
import 'package:hdhomesproject/core/validators/phone_validator.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/registration_models.dart';

/// Password strength for the credentials step meter.
enum PasswordStrength { empty, weak, fair, good, strong, excellent }

abstract final class PasswordStrengthEvaluator {
  static PasswordStrength evaluate(String password) {
    if (password.isEmpty) return PasswordStrength.empty;
    var score = 0;
    if (password.length >= AuthSecurityPolicy.passwordMinLength) score++;
    if (password.length >= 12) score++;
    if (password.length >= 16) score++;
    if (RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=\[\]\\;/`~]').hasMatch(password)) {
      score++;
    }
    if (score <= 2) return PasswordStrength.weak;
    if (score == 3) return PasswordStrength.fair;
    if (score == 4) return PasswordStrength.good;
    if (score == 5) return PasswordStrength.strong;
    return PasswordStrength.excellent;
  }

  static Map<String, bool> checklist(String password) => {
        'At least ${AuthSecurityPolicy.passwordMinLength} characters':
            password.length >= AuthSecurityPolicy.passwordMinLength,
        'Uppercase letter': RegExp(r'[A-Z]').hasMatch(password),
        'Lowercase letter': RegExp(r'[a-z]').hasMatch(password),
        'Number': RegExp(r'[0-9]').hasMatch(password),
        'Special character':
            RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=\[\]\\;/`~]').hasMatch(password),
      };
}

/// Step and full-draft validation for Progressive Registration™.
abstract final class RegistrationValidator {
  static String? validateAccountType(RegistrationDraft draft) {
    if (draft.accountType == null || !draft.accountType!.enabled) {
      return 'Please select an account type';
    }
    return null;
  }

  static Map<String, String?> validatePersonalInfo(RegistrationDraft draft) {
    return {
      'firstName': NameValidator.validate(draft.firstName, fieldName: 'First name'),
      'lastName': NameValidator.validate(draft.lastName, fieldName: 'Last name'),
      'email': EmailValidator.validate(draft.email),
      'phone': PhoneValidator.validate(draft.phone),
      'country': draft.country.trim().isEmpty ? 'Country is required' : null,
      'state': draft.state.trim().isEmpty ? 'State is required' : null,
    };
  }

  static Map<String, String?> validateCredentials(RegistrationDraft draft) {
    final passwordError = PasswordValidator.validate(draft.password);
    String? confirmError;
    if (draft.confirmPassword.isEmpty) {
      confirmError = 'Please confirm your password';
    } else if (draft.password != draft.confirmPassword) {
      confirmError = 'Passwords do not match';
    }
    return {
      'password': passwordError,
      'confirmPassword': confirmError,
    };
  }

  static String? validateLegal(RegistrationDraft draft) {
    if (!draft.acceptTerms || !draft.acceptPrivacy || !draft.acceptCookies) {
      return 'Please accept Terms, Privacy, and Cookie policies to continue';
    }
    return null;
  }

  static bool stepIsValid(RegistrationStep step, RegistrationDraft draft) {
    return switch (step) {
      RegistrationStep.accountType => validateAccountType(draft) == null,
      RegistrationStep.personalInfo =>
        validatePersonalInfo(draft).values.every((e) => e == null),
      RegistrationStep.credentials =>
        validateCredentials(draft).values.every((e) => e == null),
      RegistrationStep.legal => validateLegal(draft) == null,
      RegistrationStep.review =>
        validateAccountType(draft) == null &&
            validatePersonalInfo(draft).values.every((e) => e == null) &&
            validateCredentials(draft).values.every((e) => e == null) &&
            validateLegal(draft) == null,
    };
  }

  static String? validateReferralCode(String? code) {
    if (code == null || code.trim().isEmpty) return null;
    final normalized = code.trim().toUpperCase();
    if (normalized.length < 4 || normalized.length > 24) {
      return 'Enter a valid referral code';
    }
    if (!RegExp(r'^[A-Z0-9\-]+$').hasMatch(normalized)) {
      return 'Referral codes use letters and numbers only';
    }
    return null;
  }
}
