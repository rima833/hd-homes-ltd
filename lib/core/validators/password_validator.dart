import 'package:hdhomesproject/core/auth/policies/auth_security_policy.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';

abstract final class PasswordValidator {
  static int get minLength => AuthSecurityPolicy.passwordMinLength;

  static String? validate(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < minLength) {
      return 'Password must be at least $minLength characters';
    }
    if (AuthSecurityPolicy.requiresUppercase && !value.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }
    if (AuthSecurityPolicy.requiresLowercase && !value.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter';
    }
    if (AuthSecurityPolicy.requiresNumber && !value.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }
    if (AuthSecurityPolicy.requiresSpecialCharacter &&
        !value.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=\[\]\\;/`~]'))) {
      return 'Password must contain at least one special character';
    }
    return null;
  }

  static void validateOrThrow(String value) {
    final error = validate(value);
    if (error != null) throw ValidationException(error);
  }
}
