import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/features/ddcms/domain/services/ddcms_service.dart';

void main() {
  group('DocumentRecipient names', () {
    test('client name comes from the linked profile', () {
      final person = DocumentRecipient.fromRow(
        {
          'id': '54e44f66-c6b3-4bbb-b5e8-fbace561844f',
          'client_code': 'CLT-54E44F66',
          'profiles': {
            'first_name': 'Gift',
            'last_name': 'barnabas',
            'email': 'rishagodwin75@gmail.com',
          },
        },
        audience: 'client',
        codeColumn: 'client_code',
      );

      expect(person.displayName, 'Gift Barnabas');
      expect(person.email, 'rishagodwin75@gmail.com');
      expect(person.code, 'CLT-54E44F66');
      expect(person.initials, 'GB');
      expect(person.kindLabel, 'Client');
      expect(person.searchText, contains('gift barnabas'));
    });

    test('investor name comes from full_name when there is no profile', () {
      final person = DocumentRecipient.fromRow(
        {
          'id': 'inv-1',
          'investor_code': 'INV-54E44F66',
          'full_name': 'Gift barnabas',
          'email': 'rishagodwin75@gmail.com',
        },
        audience: 'investor',
        codeColumn: 'investor_code',
      );

      expect(person.displayName, 'Gift Barnabas');
      expect(person.kindLabel, 'Investor');
      expect(person.code, 'INV-54E44F66');
    });

    test('preferred name wins over first and last', () {
      final person = DocumentRecipient.fromRow(
        {
          'id': '1',
          'client_code': 'CLT-1',
          'profiles': {
            'preferred_name': 'Rishamah',
            'first_name': 'john',
            'last_name': 'shammah',
          },
        },
        audience: 'client',
        codeColumn: 'client_code',
      );

      expect(person.displayName, 'Rishamah');
      expect(person.initials, 'R');
    });
  });
}
