import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';

void main() {
  group('userFacingError', () {
    test('hides ClientException fetch dumps', () {
      const raw =
          'ClientException: Failed to fetch, uri=https://wbonjdqsifwsawhhxygl.supabase.co/rest/v1/client_property_applications?select=%2A';
      expect(userFacingError(raw), kNetworkErrorMessage);
    });

    test('keeps incorrect password friendly', () {
      expect(
        userFacingError(const AuthenticationException('Incorrect email or password.')),
        'Incorrect email or password.',
      );
    });

    test('maps AppException that embeds technical dump', () {
      expect(
        userFacingError(
          const AuthenticationException(
            'ClientException: Failed to fetch, uri=https://example.com',
          ),
        ),
        kNetworkErrorMessage,
      );
    });
  });
}
