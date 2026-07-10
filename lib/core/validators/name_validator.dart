import 'package:hdhomesproject/core/errors/app_exception.dart';

abstract final class NameValidator {
  static String? validate(String? value, {String fieldName = 'Name'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    if (value.trim().length < 2) {
      return '$fieldName must be at least 2 characters';
    }
    return null;
  }

  static void validateOrThrow(String value, {String fieldName = 'Name'}) {
    final error = validate(value, fieldName: fieldName);
    if (error != null) throw ValidationException(error);
  }
}
