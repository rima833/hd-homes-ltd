import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/consultation/domain/entities/consultation_admin_models.dart';
import 'package:hdhomesproject/features/consultation/domain/services/consultation_admin_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final consultationAdminServiceProvider =
    Provider<ConsultationAdminService>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return ConsultationAdminService(
    client: configured ? ref.watch(supabaseClientProvider) : null,
  );
});

void _invalidateAdminConsultationConfig(Ref ref) {
  ref.invalidate(adminConsultationDepartmentsProvider);
  ref.invalidate(adminConsultationAdvisorsProvider);
  ref.invalidate(adminConsultationTypesProvider);
  ref.invalidate(adminConsultationWorkingHoursProvider);
  ref.invalidate(adminConsultationHolidaysProvider);
  ref.invalidate(adminConsultationSettingsProvider);
  ref.read(adminConsultationsLiveTickProvider.notifier).state++;
}

void _invalidateAdminConsultationBookings(Ref ref) {
  ref.invalidate(adminConsultationsProvider);
  ref.invalidate(adminConsultationStatsProvider);
  ref.read(adminConsultationsLiveTickProvider.notifier).state++;
}

final adminConsultationsRealtimeProvider = Provider<void>((ref) {
  ref.keepAlive();
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = ref.watch(supabaseClientProvider);
  final channel = client.channel('admin-consultations')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'consultation_bookings',
      callback: (_) => _invalidateAdminConsultationBookings(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'consultation_booking_events',
      callback: (_) {
        ref.invalidate(adminConsultationsProvider);
        ref.invalidate(consultationBookingEventsProvider);
      },
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'consultation_departments',
      callback: (_) => _invalidateAdminConsultationConfig(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'consultation_advisors',
      callback: (_) => _invalidateAdminConsultationConfig(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'consultation_types',
      callback: (_) => _invalidateAdminConsultationConfig(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'consultation_working_hours',
      callback: (_) => _invalidateAdminConsultationConfig(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'consultation_holidays',
      callback: (_) => _invalidateAdminConsultationConfig(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'consultation_settings',
      callback: (_) => _invalidateAdminConsultationConfig(ref),
    )
    ..subscribe();

  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

final adminConsultationsProvider =
    FutureProvider<List<AdminConsultationRow>>((ref) async {
  return ref.read(consultationAdminServiceProvider).listBookings();
});

final adminConsultationStatsProvider =
    FutureProvider<AdminConsultationStats>((ref) async {
  return ref.read(consultationAdminServiceProvider).fetchStats();
});

final adminConsultationAdvisorsProvider =
    FutureProvider<List<AdminConsultationAdvisor>>((ref) async {
  return ref.read(consultationAdminServiceProvider).listAdvisors();
});

final adminConsultationDepartmentsProvider =
    FutureProvider<List<AdminConsultationDepartment>>((ref) async {
  return ref.read(consultationAdminServiceProvider).listDepartments();
});

final adminConsultationTypesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.read(consultationAdminServiceProvider).listConsultationTypes();
});

final adminConsultationWorkingHoursProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.read(consultationAdminServiceProvider).listWorkingHours();
});

final adminConsultationHolidaysProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.read(consultationAdminServiceProvider).listHolidays();
});

final adminConsultationSettingsProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  return ref.read(consultationAdminServiceProvider).fetchSettings();
});

final consultationBookingEventsProvider =
    FutureProvider.family<List<ConsultationBookingEvent>, String>(
  (ref, bookingId) {
    return ref.read(consultationAdminServiceProvider).fetchEvents(bookingId);
  },
);

final adminConsultationsLiveTickProvider = StateProvider<int>((ref) => 0);
