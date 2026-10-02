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

  /// Digits only for `https://wa.me/<digits>` (no `+`, no leading `0`).
  ///
  /// Converts common Nigerian local forms (`0708…`, `708…`) to
  /// `234708…`. Already-international numbers are left intact.
  static String? whatsappDigits(
    String? raw, {
    String defaultCountryCode = '234',
  }) {
    if (raw == null) return null;
    var value = raw.trim();
    if (value.isEmpty) return null;

    value = value.replaceAll(RegExp(r'[^\d+]'), '');
    if (value.startsWith('+')) value = value.substring(1);
    if (value.startsWith('00')) value = value.substring(2);
    value = value.replaceAll(RegExp(r'\D'), '');
    if (value.isEmpty) return null;

    if (value.startsWith('0') && value.length >= 10) {
      value = '$defaultCountryCode${value.substring(1)}';
    } else if (value.length == 10 && RegExp(r'^[789]').hasMatch(value)) {
      value = '$defaultCountryCode$value';
    }

    return value;
  }

  /// `https://wa.me/<digits>?text=…` or null when [raw] has no usable number.
  static Uri? whatsappUri(String? raw, {String? prefillText}) {
    final digits = whatsappDigits(raw);
    if (digits == null || digits.isEmpty) return null;
    return Uri.parse(
      prefillText == null || prefillText.isEmpty
          ? 'https://wa.me/$digits'
          : 'https://wa.me/$digits?text=${Uri.encodeComponent(prefillText)}',
    );
  }
}
