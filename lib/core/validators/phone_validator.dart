import 'package:hdhomesproject/core/errors/app_exception.dart';

abstract final class PhoneValidator {
  static final _pattern = RegExp(r'^(\+?234|0)[789][01]\d{8}$');

  static String? validate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    final normalized = value.replaceAll(RegExp(r'[\s-]'), '');
    if (!_pattern.hasMatch(normalized)) {
      return 'Enter a valid Nigerian phone number';
    }
    return null;
  }

  static void validateOrThrow(String value) {
    final error = validate(value);
    if (error != null) throw ValidationException(error);
  }
}
