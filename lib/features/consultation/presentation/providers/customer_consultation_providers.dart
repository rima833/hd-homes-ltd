import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/identity_provider.dart';
import 'package:hdhomesproject/features/consultation/domain/entities/customer_consultation_models.dart';
import 'package:hdhomesproject/features/consultation/domain/services/customer_consultation_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final customerConsultationServiceProvider =
    Provider<CustomerConsultationService>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return CustomerConsultationService(
    client: configured ? ref.watch(supabaseClientProvider) : null,
  );
});

final clientConsultationsProvider =
    FutureProvider<List<CustomerConsultationBooking>>((ref) async {
  final userId = ref.watch(identitySessionProvider).userId;
  if (userId == null) return [];
  final service = ref.read(customerConsultationServiceProvider);
  await service.claimGuestBookings();
  return service.listMyBookings();
});

final clientConsultationsRealtimeProvider = Provider<void>((ref) {
  ref.keepAlive();
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final userId = ref.watch(identitySessionProvider).userId;
  if (userId == null) return;

  final client = ref.watch(supabaseClientProvider);
  final channel = client.channel('client-consultations-$userId')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'consultation_bookings',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: userId,
      ),
      callback: (_) {
        Future.microtask(() {
          try {
            ref.invalidate(clientConsultationsProvider);
          } catch (_) {}
        });
      },
    )
    ..subscribe();

  ref.onDispose(() => unawaited(client.removeChannel(channel)));
});
