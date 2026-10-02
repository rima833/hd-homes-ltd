import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/client/domain/entities/client_payment_engine_models.dart';
import 'package:hdhomesproject/features/client/domain/services/client_payment_engine_service.dart';
import 'package:hdhomesproject/features/client/presentation/providers/client_providers.dart';

final clientPaymentEngineServiceProvider =
    Provider<ClientPaymentEngineService>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return ClientPaymentEngineService(
    client: configured ? ref.watch(supabaseClientProvider) : null,
  );
});

final clientPaymentSummaryProvider =
    FutureProvider<ClientPaymentSummary?>((ref) async {
  ref.watch(clientPaymentEngineRealtimeProvider);
  final record = await ref.watch(clientRecordProvider.future);
  if (record == null) return null;
  return ref.watch(clientPaymentEngineServiceProvider).fetchPaymentSummary();
});

final clientPaymentMethodsProvider =
    FutureProvider<List<ClientPaymentMethodOption>>((ref) async {
  ref.watch(clientPaymentEngineRealtimeProvider);
  final record = await ref.watch(clientRecordProvider.future);
  if (record == null) return [];
  return ref
      .watch(clientPaymentEngineServiceProvider)
      .listClientPaymentMethods();
});

final clientReceivingAccountsProvider =
    FutureProvider<List<CompanyReceivingAccount>>((ref) async {
  ref.watch(clientPaymentEngineRealtimeProvider);
  final record = await ref.watch(clientRecordProvider.future);
  if (record == null) return [];
  return ref
      .watch(clientPaymentEngineServiceProvider)
      .listReceivingAccounts();
});

final clientPaymentIntentsProvider =
    FutureProvider<List<ClientPaymentIntentRecord>>((ref) async {
  ref.watch(clientPaymentEngineRealtimeProvider);
  final record = await ref.watch(clientRecordProvider.future);
  if (record == null) return [];
  return ref
      .watch(clientPaymentEngineServiceProvider)
      .listPaymentIntents(record.id);
});

final clientPaymentChargesProvider =
    FutureProvider<List<ClientPaymentCharge>>((ref) async {
  ref.watch(clientPaymentEngineRealtimeProvider);
  final record = await ref.watch(clientRecordProvider.future);
  if (record == null) return [];
  return ref
      .watch(clientPaymentEngineServiceProvider)
      .listCharges(record.id);
});

final clientFinanceReceiptsProvider =
    FutureProvider<List<ClientFinanceReceipt>>((ref) async {
  ref.watch(clientPaymentEngineRealtimeProvider);
  final record = await ref.watch(clientRecordProvider.future);
  if (record == null) return [];
  return ref
      .watch(clientPaymentEngineServiceProvider)
      .listReceipts(record.id);
});

/// History: pending verification intents + completed payments (server data only).
final clientPaymentHistoryProvider =
    FutureProvider<List<ClientPaymentHistoryItem>>((ref) async {
  ref.watch(clientPaymentEngineRealtimeProvider);
  final bundle = await ref.watch(clientPaymentsProvider.future);
  final intents = await ref.watch(clientPaymentIntentsProvider.future);

  final items = <ClientPaymentHistoryItem>[];

  for (final intent in intents) {
    if (intent.isPendingVerification ||
        intent.status == 'rejected' ||
        intent.status == 'pending') {
      items.add(
        ClientPaymentHistoryItem(
          id: intent.id,
          amount: intent.amount,
          status: intent.status,
          kind: 'intent',
          propertyTitle: intent.propertyTitle,
          reference: intent.paymentReference ?? intent.providerReference,
          occurredAt: intent.submittedAt ?? intent.createdAt,
          provider: intent.provider,
        ),
      );
    }
  }

  for (final payment in bundle.payments) {
    if (payment.status == 'completed' ||
        payment.status == 'paid' ||
        payment.status == 'succeeded' ||
        payment.status == 'success') {
      items.add(
        ClientPaymentHistoryItem(
          id: payment.id,
          amount: payment.amount,
          status: payment.status,
          kind: 'payment',
          propertyTitle: payment.propertyTitle,
          reference: payment.providerReference,
          occurredAt: payment.paidAt,
          provider: payment.provider ?? payment.paymentMethod,
        ),
      );
    }
  }

  items.sort((a, b) {
    final aAt = a.occurredAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bAt = b.occurredAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return bAt.compareTo(aAt);
  });
  return items;
});

/// Deprecated stub — payment tables are subscribed via
/// [clientPortalRealtimeProvider] (avoids a second channel / invalidate storm).
/// Kept so existing `ref.watch(clientPaymentEngineRealtimeProvider)` call sites
/// still compile; prefer the portal hub in new code.
final Provider<void> clientPaymentEngineRealtimeProvider = Provider<void>((ref) {
  ref.keepAlive();
});
