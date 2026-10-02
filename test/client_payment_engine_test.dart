import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/features/client/domain/entities/client_models.dart';
import 'package:hdhomesproject/features/client/domain/entities/client_payment_engine_models.dart';
import 'package:hdhomesproject/features/client/domain/services/client_payment_engine_service.dart';
import 'package:hdhomesproject/features/client/presentation/providers/client_providers.dart';
import 'package:hdhomesproject/features/fapms/domain/entities/payment_verification_models.dart';
import 'package:hdhomesproject/features/fapms/presentation/providers/fapms_controller.dart';

void main() {
  group('ClientPaymentEngineService.friendlyError', () {
    test('maps known RPC exception codes to human messages', () {
      expect(
        ClientPaymentEngineService.friendlyError(
          StateError('partial_payments_disabled'),
        ),
        contains('Partial payments'),
      );
      expect(
        ClientPaymentEngineService.friendlyError(
          Exception('ERROR: overpayment_not_allowed'),
        ),
        contains('exceeds'),
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
          Exception('forbidden_client_complete'),
        ),
        contains('permission'),
      );
    });
  });

  group('ClientPaymentSummary', () {
    test('parses server summary JSON as source of truth', () {
      final summary = ClientPaymentSummary.fromJson({
        'client_id': 'c1',
        'currency': 'NGN',
        'property_value': 50000000,
        'total_paid': 2500000,
        'outstanding': 2500000,
        'charges_outstanding': 50000,
        'pending_verification': 0,
        'total_payable': 2550000,
        'next_payment': {
          'installment_id': 'i1',
          'property_id': 'p1',
          'property_title': 'Victoria Crest',
          'amount': 2500000,
          'amount_outstanding': 2500000,
          'due_date': '2026-08-21',
          'status': 'pending',
        },
      });

      expect(summary.outstanding, 2500000);
      expect(summary.totalPaid, 2500000);
      expect(summary.chargesOutstanding, 50000);
      expect(summary.totalPayable, 2550000);
      expect(summary.nextPayment?.propertyTitle, 'Victoria Crest');
      expect(summary.paidProgress, closeTo(0.5, 0.001));
    });
  });

  group('ClientPaymentsBundle prefers server summary', () {
    test('outstanding and totalPaid come from summary when present', () {
      final summary = ClientPaymentSummary.fromJson({
        'client_id': 'c1',
        'property_value': 0,
        'total_paid': 100,
        'outstanding': 200,
        'charges_outstanding': 0,
        'pending_verification': 0,
        'total_payable': 200,
      });
      final bundle = ClientPaymentsBundle(
        payments: const [
          ClientPayment(id: 'pay-1', amount: 999, status: 'completed'),
        ],
        installments: [
          ClientInstallment(
            id: 'i1',
            amount: 9999,
            dueDate: DateTime(2026, 8, 21),
            status: 'pending',
          ),
        ],
        summary: summary,
      );

      expect(bundle.outstanding, 200);
      expect(bundle.totalPaid, 100);
    });

    test('falls back to local aggregates when summary missing', () {
      final bundle = ClientPaymentsBundle(
        payments: const [
          ClientPayment(id: 'pay-1', amount: 1000, status: 'completed'),
          ClientPayment(id: 'pay-2', amount: 500, status: 'pending'),
        ],
        installments: [
          ClientInstallment(
            id: 'i1',
            amount: 2500,
            dueDate: DateTime(2026, 8, 21),
            status: 'pending',
          ),
          ClientInstallment(
            id: 'i2',
            amount: 2500,
            dueDate: DateTime(2026, 7, 1),
            status: 'paid',
            amountPaid: 2500,
            amountOutstanding: 0,
          ),
        ],
      );

      expect(bundle.outstanding, 2500);
      expect(bundle.totalPaid, 1000);
    });
  });

  group('ClientInstallment payableAmount', () {
    test('uses amount_outstanding from server', () {
      final i = ClientInstallment.fromJson({
        'id': 'i1',
        'amount': 2500000,
        'amount_paid': 1000000,
        'amount_outstanding': 1500000,
        'due_date': '2026-08-21',
        'status': 'partially_paid',
        'property_id': 'p1',
        'properties': {'title': 'Victoria Crest'},
      });
      expect(i.payableAmount, 1500000);
      expect(i.propertyId, 'p1');
      expect(i.isPayable, isTrue);
    });
  });

  group('BankTransferSubmissionResult', () {
    test('parses pending_verification result — never completed', () {
      final result = BankTransferSubmissionResult.fromJson({
        'intent_id': 'intent-1',
        'verification_id': 'ver-1',
        'payment_reference': 'HDH-PAY-20260820-ABC123',
        'amount': 2500000,
        'status': 'pending_verification',
        'receiving_account_id': 'acc-1',
      });
      expect(result.status, 'pending_verification');
      expect(result.status, isNot(equals('completed')));
      expect(result.paymentReference, startsWith('HDH-PAY-'));
    });
  });

  group('Payment methods UX contract', () {
    test('bank transfer is recommended and not online checkout', () {
      final method = ClientPaymentMethodOption.fromJson({
        'id': 'm1',
        'slug': 'bank_transfer',
        'name': 'Bank Transfer',
        'is_active': true,
        'client_enabled': true,
        'is_recommended': true,
        'sort_order': 0,
        'client_description': 'Transfer to HD Homes',
      });
      expect(method.isBankTransfer, isTrue);
      expect(method.isOnlineCheckout, isFalse);
      expect(method.isRecommended, isTrue);
    });

    test('paystack is online checkout', () {
      final method = ClientPaymentMethodOption.fromJson({
        'id': 'm2',
        'slug': 'paystack',
        'name': 'Paystack',
        'is_active': true,
        'client_enabled': false,
        'is_recommended': false,
        'sort_order': 10,
      });
      expect(method.isOnlineCheckout, isTrue);
      expect(method.isBankTransfer, isFalse);
    });
  });

  group('Finance verification intent statuses', () {
    test('maps pending_verification correctly', () {
      expect(
        PaymentIntentStatus.fromSlug('pending_verification'),
        PaymentIntentStatus.pendingVerification,
      );
      expect(
        PaymentIntentStatus.pendingVerification.slug,
        'pending_verification',
      );
      expect(
        PaymentIntentStatus.pendingVerification.label,
        'Pending verification',
      );
      expect(PaymentIntentStatus.pendingVerification.isActionable, isTrue);
    });
  });

  group('FAPMS tabs include verification surfaces', () {
    test('verification and website money ops tabs exist', () {
      expect(
        FapmsCommandTab.values.map((t) => t.name),
        containsAll([
          'verification',
          'setup',
          'payments',
          'investor',
          'installments',
          'leads',
          'commissions',
        ]),
      );
    });
  });
}
