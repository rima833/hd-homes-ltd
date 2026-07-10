import 'package:hdhomesproject/core/errors/app_exception.dart';

abstract final class EmailValidator {
  static final _pattern = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  static String? validate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    if (!_pattern.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static void validateOrThrow(String value) {
    final error = validate(value);
    if (error != null) throw ValidationException(error);
  }
}
