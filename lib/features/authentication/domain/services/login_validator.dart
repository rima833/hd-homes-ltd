import 'package:hdhomesproject/core/validators/email_validator.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/login_models.dart';

/// Validation for login forms (non-revealing — never confirms email existence).
abstract final class LoginValidator {
  static String? validateEmail(String? value) => EmailValidator.validate(value);

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    return null;
  }

  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) return 'Phone number is required';
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) return 'Enter a valid phone number';
    return null;
  }

  static bool isValid(LoginCredentials credentials) {
    return switch (credentials.method) {
      LoginMethod.emailPassword =>
        validateEmail(credentials.email) == null &&
            validatePassword(credentials.password) == null,
      LoginMethod.phonePassword =>
        validatePhone(credentials.email) == null &&
            validatePassword(credentials.password) == null,
      LoginMethod.magicLink => validateEmail(credentials.email) == null,
      _ => false,
    };
  }
}
