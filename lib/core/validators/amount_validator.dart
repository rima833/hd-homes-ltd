import 'package:hdhomesproject/core/errors/app_exception.dart';

abstract final class AmountValidator {
  static String? validate(String? value, {double min = 0}) {
    if (value == null || value.trim().isEmpty) {
      return 'Amount is required';
    }
    final amount = double.tryParse(value.replaceAll(',', ''));
    if (amount == null) {
      return 'Enter a valid amount';
    }
    if (amount < min) {
      return 'Amount must be at least $min';
    }
    return null;
  }

  static void validateOrThrow(String value, {double min = 0}) {
    final error = validate(value, min: min);
    if (error != null) throw ValidationException(error);
  }
}
