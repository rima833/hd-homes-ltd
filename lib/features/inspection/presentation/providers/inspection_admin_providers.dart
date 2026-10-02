import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/inspection/domain/entities/inspection_admin_models.dart';
import 'package:hdhomesproject/features/inspection/domain/services/inspection_admin_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final inspectionAdminServiceProvider = Provider<InspectionAdminService>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return InspectionAdminService(
    client: configured ? ref.watch(supabaseClientProvider) : null,
  );
});

void _bumpLiveTick(Ref ref) {
  ref.read(adminInspectionsLiveTickProvider.notifier).state++;
}

void _invalidateAdminInspections(Ref ref) {
  _bumpLiveTick(ref);
  ref.invalidate(adminInspectionsProvider);
  ref.invalidate(adminInspectionStatsProvider);
}

void _invalidateAdminInspectionConfig(Ref ref) {
  _bumpLiveTick(ref);
  ref.invalidate(adminInspectionSettingsProvider);
  ref.invalidate(adminInspectionWorkingHoursProvider);
  ref.invalidate(adminInspectionHolidaysProvider);
  ref.invalidate(adminInspectionBlockedSlotsProvider);
  ref.invalidate(adminInspectionAgentsProvider);
}

final adminInspectionsRealtimeProvider = Provider<void>((ref) {
  ref.keepAlive();
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = ref.watch(supabaseClientProvider);
  final channel = client.channel('admin-inspections')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'property_inspections',
      callback: (_) => _invalidateAdminInspections(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'inspection_status_history',
      callback: (_) {
        ref.invalidate(adminInspectionsProvider);
        ref.invalidate(adminInspectionStatusHistoryProvider);
      },
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'inspection_settings',
      callback: (_) => _invalidateAdminInspectionConfig(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'inspection_working_hours',
      callback: (_) => _invalidateAdminInspectionConfig(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'inspection_holidays',
      callback: (_) => _invalidateAdminInspectionConfig(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'inspection_blocked_slots',
      callback: (_) => _invalidateAdminInspectionConfig(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'inspection_agents',
      callback: (_) => _invalidateAdminInspectionConfig(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'property_inspection_config',
      callback: (_) {
        _bumpLiveTick(ref);
        ref.invalidate(adminPropertyInspectionConfigProvider);
      },
    )
    ..subscribe();

  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

final adminInspectionsProvider =
    FutureProvider<List<AdminInspectionRow>>((ref) async {
  return ref.read(inspectionAdminServiceProvider).listInspections();
});

final adminInspectionStatsProvider =
    FutureProvider<AdminInspectionStats>((ref) async {
  return ref.read(inspectionAdminServiceProvider).fetchStats();
});

final adminInspectionSettingsProvider =
    FutureProvider<InspectionSettingsRow?>((ref) async {
  return ref.read(inspectionAdminServiceProvider).fetchSettings();
});

final adminInspectionWorkingHoursProvider =
    FutureProvider<List<InspectionWorkingHourRow>>((ref) async {
  return ref.read(inspectionAdminServiceProvider).listWorkingHours();
});

final adminInspectionHolidaysProvider =
    FutureProvider<List<InspectionHolidayRow>>((ref) async {
  return ref.read(inspectionAdminServiceProvider).listHolidays();
});

final adminInspectionBlockedSlotsProvider =
    FutureProvider<List<InspectionBlockedSlotRow>>((ref) async {
  return ref.read(inspectionAdminServiceProvider).listBlockedSlots();
});

final adminInspectionAgentsProvider =
    FutureProvider<List<InspectionAgentRow>>((ref) async {
  return ref.read(inspectionAdminServiceProvider).listAgents();
});

final adminPropertyInspectionConfigProvider =
    FutureProvider.family<PropertyInspectionConfigRow?, String>(
  (ref, propertyId) async {
    return ref.read(inspectionAdminServiceProvider).fetchPropertyConfig(
          propertyId,
        );
  },
);

final adminInspectionStatusHistoryProvider =
    FutureProvider.family<List<InspectionStatusHistoryEntry>, String>(
  (ref, inspectionId) async {
    return ref.read(inspectionAdminServiceProvider).fetchStatusHistory(
          inspectionId,
        );
  },
);

final adminInspectionPropertyOptionsProvider =
    FutureProvider<List<InspectionPropertyOption>>((ref) async {
  return ref.read(inspectionAdminServiceProvider).listPropertyOptions();
});

final adminInspectionAdvisorOptionsProvider =
    FutureProvider<List<InspectionAdvisorOption>>((ref) async {
  return ref.read(inspectionAdminServiceProvider).listAdvisorOptions();
});

final adminInspectionEstateOptionsProvider =
    FutureProvider<List<InspectionEstateOption>>((ref) async {
  return ref.read(inspectionAdminServiceProvider).listEstateOptions();
});

/// Bumped whenever realtime fires so the UI can show a live pulse.
final adminInspectionsLiveTickProvider = StateProvider<int>((ref) => 0);
