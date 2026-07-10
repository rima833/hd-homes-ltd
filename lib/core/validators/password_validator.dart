import 'package:hdhomesproject/core/errors/app_exception.dart';

abstract final class PasswordValidator {
  static const minLength = 8;

  static String? validate(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < minLength) {
      return 'Password must be at least $minLength characters';
    }
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }
    return null;
  }

  static void validateOrThrow(String value) {
    final error = validate(value);
    if (error != null) throw ValidationException(error);
  }
}
