import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/features/client/domain/services/client_payment_engine_service.dart';

void main() {
  group('ClientPaymentEngineService.friendlyError', () {
    test('maps known rpc codes to readable messages', () {
      expect(
        ClientPaymentEngineService.friendlyError(
          StateError('partial_payments_disabled'),
        ),
        contains('Partial payments'),
      );
      expect(
        ClientPaymentEngineService.friendlyError(
          Exception('proof_required'),
        ),
        contains('proof'),
      );
      expect(
        ClientPaymentEngineService.friendlyError(
          Exception('payment_method_unavailable'),
        ),
        contains('unavailable'),
      );
      expect(
        ClientPaymentEngineService.friendlyError(
          Exception('overpayment_not_allowed'),
        ),
        contains('exceeds'),
      );
    });

    test('never exposes raw unknown errors as stack traces', () {
      final msg = ClientPaymentEngineService.friendlyError(
        Exception('some_db_internal_xyz'),
      );
      expect(msg.toLowerCase(), contains('could not submit'));
      expect(msg.contains('Exception'), isFalse);
    });
  });
}
