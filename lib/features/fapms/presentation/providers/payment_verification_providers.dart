import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/fapms/domain/entities/payment_verification_models.dart';
import 'package:hdhomesproject/features/fapms/domain/services/payment_verification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final paymentVerificationServiceProvider =
    Provider<PaymentVerificationService>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return PaymentVerificationService(
    client: configured ? ref.watch(supabaseClientProvider) : null,
  );
});

/// Realtime on client payment intents + verification rows.
final Provider<void> paymentVerificationRealtimeProvider = Provider<void>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = ref.watch(supabaseClientProvider);
  final channel = client.channel('fapms-payment-verification')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'client_payment_intents',
      callback: (_) => _invalidateVerificationQueue(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'payment_verifications',
      callback: (_) => _invalidateVerificationQueue(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'company_receiving_accounts',
      callback: (_) => ref.invalidate(receivingAccountsProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'payment_methods',
      callback: (_) => ref.invalidate(paymentMethodsConfigProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'late_fee_rules',
      callback: (_) => ref.invalidate(lateFeeRulesProvider),
    )
    ..subscribe();

  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

void _invalidateVerificationQueue(Ref ref) {
  ref.invalidate(paymentIntentsProvider);
  ref.invalidate(pendingPaymentIntentsProvider);
  ref.invalidate(pendingVerificationCountProvider);
}

/// Status filter for the verification queue (`null` / empty = all).
final paymentIntentStatusFilterProvider =
    NotifierProvider<PaymentIntentStatusFilter, String?>(
  PaymentIntentStatusFilter.new,
);

class PaymentIntentStatusFilter extends Notifier<String?> {
  @override
  String? build() => 'pending_verification';

  void set(String? status) => state = status;
}

final paymentIntentSearchProvider =
    NotifierProvider<PaymentIntentSearch, String>(PaymentIntentSearch.new);

class PaymentIntentSearch extends Notifier<String> {
  @override
  String build() => '';

  void set(String query) => state = query;
}

final selectedPaymentIntentIdProvider =
    NotifierProvider<SelectedPaymentIntentId, String?>(
  SelectedPaymentIntentId.new,
);

class SelectedPaymentIntentId extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? id) => state = id;
}

final paymentIntentsProvider =
    FutureProvider<List<PaymentIntentRow>>((ref) async {
  ref.watch(paymentVerificationRealtimeProvider);
  final status = ref.watch(paymentIntentStatusFilterProvider);
  final service = ref.watch(paymentVerificationServiceProvider);
  if (status == null || status.isEmpty || status == 'all') {
    return service.listIntents();
  }
  if (status == 'actionable') {
    return service.listPendingIntents();
  }
  return service.listIntents(status: status);
});

final pendingPaymentIntentsProvider =
    FutureProvider<List<PaymentIntentRow>>((ref) async {
  ref.watch(paymentVerificationRealtimeProvider);
  return ref.watch(paymentVerificationServiceProvider).listPendingIntents();
});

final pendingVerificationCountProvider = Provider<AsyncValue<int>>((ref) {
  return ref.watch(pendingPaymentIntentsProvider).whenData((rows) => rows.length);
});

final paymentIntentDetailProvider =
    FutureProvider.family<PaymentIntentRow, String>((ref, intentId) async {
  ref.watch(paymentVerificationRealtimeProvider);
  return ref.watch(paymentVerificationServiceProvider).getIntentDetail(intentId);
});

final proofSignedUrlProvider =
    FutureProvider.family<String?, String>((ref, path) async {
  return ref.watch(paymentVerificationServiceProvider).proofSignedUrl(path);
});

final receivingAccountsProvider =
    FutureProvider<List<CompanyReceivingAccount>>((ref) async {
  ref.watch(paymentVerificationRealtimeProvider);
  return ref.watch(paymentVerificationServiceProvider).listReceivingAccounts();
});

final paymentMethodsConfigProvider =
    FutureProvider<List<PaymentMethodConfig>>((ref) async {
  ref.watch(paymentVerificationRealtimeProvider);
  return ref.watch(paymentVerificationServiceProvider).listPaymentMethods();
});

final lateFeeRulesProvider = FutureProvider<List<LateFeeRule>>((ref) async {
  ref.watch(paymentVerificationRealtimeProvider);
  return ref.watch(paymentVerificationServiceProvider).listLateFeeRules();
});

List<PaymentIntentRow> filterPaymentIntents(
  List<PaymentIntentRow> rows,
  String searchQuery,
) {
  final q = searchQuery.trim().toLowerCase();
  if (q.isEmpty) return rows;
  return rows.where((r) {
    return r.clientDisplay.toLowerCase().contains(q) ||
        r.propertyDisplay.toLowerCase().contains(q) ||
        r.referenceDisplay.toLowerCase().contains(q) ||
        r.status.label.toLowerCase().contains(q) ||
        r.amountDisplay.toLowerCase().contains(q) ||
        (r.senderName?.toLowerCase().contains(q) ?? false) ||
        (r.transactionReference?.toLowerCase().contains(q) ?? false);
  }).toList();
}
