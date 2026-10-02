import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/core/validators/phone_validator.dart';

void main() {
  group('PhoneValidator.whatsappDigits', () {
    test('converts Nigerian local 0-prefix to international', () {
      expect(PhoneValidator.whatsappDigits('07080596171'), '2347080596171');
      expect(PhoneValidator.whatsappDigits('0708 059 6171'), '2347080596171');
    });

    test('keeps already-international numbers', () {
      expect(PhoneValidator.whatsappDigits('+2347080596171'), '2347080596171');
      expect(PhoneValidator.whatsappDigits('2347080596171'), '2347080596171');
      expect(PhoneValidator.whatsappDigits('002347080596171'), '2347080596171');
    });

    test('prefixes 10-digit mobile without country code', () {
      expect(PhoneValidator.whatsappDigits('7080596171'), '2347080596171');
    });

    test('builds wa.me URI for chat start', () {
      final uri = PhoneValidator.whatsappUri(
        '07080596171',
        prefillText: 'Hello HD Homes',
      );
      expect(uri, isNotNull);
      expect(uri!.host, 'wa.me');
      expect(uri.path, '/2347080596171');
      expect(uri.queryParameters['text'], 'Hello HD Homes');
    });

    test('returns null for empty input', () {
      expect(PhoneValidator.whatsappDigits(''), isNull);
      expect(PhoneValidator.whatsappUri('   '), isNull);
    });
  });
}
