import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/core/email/email_models.dart';

void main() {
  group('EmailBrandConfig', () {
    test('fromJson applies defaults for missing fields', () {
      final brand = EmailBrandConfig.fromJson(const {});
      expect(brand.senderName, 'HD Homes Limited');
      expect(brand.senderEmail, contains('@'));
      expect(brand.primaryColor, '#D4A34E');
    });

    test('round-trips through toJson', () {
      const original = EmailBrandConfig(
        logoUrl: 'https://cdn.example/logo.png',
        senderEmail: 'hello@hdhomes.ng',
      );
      final again = EmailBrandConfig.fromJson(original.toJson());
      expect(again.logoUrl, original.logoUrl);
      expect(again.senderEmail, original.senderEmail);
    });
  });

  group('EmailTemplateKeys', () {
    test('security templates are locked', () {
      expect(
        EmailTemplateKeys.securityLocked,
        containsAll([
          EmailTemplateKeys.securityAlert,
          EmailTemplateKeys.passwordChanged,
          EmailTemplateKeys.emailChanged,
        ]),
      );
    });
  });

  group('EmailDeliveryStatus', () {
    test('parses slugs', () {
      expect(EmailDeliveryStatus.fromSlug('queued'), EmailDeliveryStatus.queued);
      expect(EmailDeliveryStatus.fromSlug('SENT'), EmailDeliveryStatus.sent);
      expect(EmailDeliveryStatus.fromSlug('failed'), EmailDeliveryStatus.failed);
    });
  });

  group('EmailSystemStatus', () {
    test('fromJson maps provider configured flag', () {
      final status = EmailSystemStatus.fromJson({
        'brand': {'sender_name': 'HD Homes Limited'},
        'provider': {
          'configured': true,
          'provider': 'resend',
          'notes': 'ok',
        },
        'queued': 2,
        'sent': 10,
        'failed': 1,
      });
      expect(status.configured, isTrue);
      expect(status.provider, 'resend');
      expect(status.queued, 2);
      expect(status.brand.senderName, 'HD Homes Limited');
    });
  });
}
