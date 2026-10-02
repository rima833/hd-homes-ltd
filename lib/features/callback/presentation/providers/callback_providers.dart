import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/callback/domain/entities/callback_models.dart';
import 'package:hdhomesproject/features/callback/domain/services/callback_admin_service.dart';
import 'package:hdhomesproject/features/callback/domain/services/callback_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final callbackServiceProvider = Provider<CallbackService>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return CallbackService(
    client: configured ? ref.watch(supabaseClientProvider) : null,
  );
});

final callbackAdminServiceProvider = Provider<CallbackAdminService>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return CallbackAdminService(
    client: configured ? ref.watch(supabaseClientProvider) : null,
  );
});

void _invalidateCallbackPublic(Ref ref) {
  ref.invalidate(callbackSettingsProvider);
  ref.invalidate(callbackDepartmentsProvider);
  ref.invalidate(callbackPrioritiesProvider);
  ref.invalidate(callbackWorkingHoursProvider);
  ref.invalidate(adminCallbackDepartmentsProvider);
  ref.invalidate(adminCallbackPrioritiesProvider);
}

final callbackPublicRealtimeProvider = Provider<void>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = ref.watch(supabaseClientProvider);
  final channel = client.channel('public-callback-settings')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'callback_settings',
      callback: (_) => _invalidateCallbackPublic(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'callback_departments',
      callback: (_) => _invalidateCallbackPublic(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'callback_priorities',
      callback: (_) => _invalidateCallbackPublic(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'callback_working_hours',
      callback: (_) => _invalidateCallbackPublic(ref),
    )
    ..subscribe();

  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

final callbackSettingsProvider = FutureProvider<CallbackSettings?>((ref) async {
  ref.watch(callbackPublicRealtimeProvider);
  return ref.read(callbackServiceProvider).fetchSettings();
});

final callbackDepartmentsProvider =
    FutureProvider<List<CallbackDepartment>>((ref) async {
  ref.watch(callbackPublicRealtimeProvider);
  return ref.read(callbackServiceProvider).fetchDepartments();
});

final callbackPrioritiesProvider =
    FutureProvider<List<CallbackPriority>>((ref) async {
  ref.watch(callbackPublicRealtimeProvider);
  return ref.read(callbackServiceProvider).fetchPriorities();
});

final callbackWorkingHoursProvider =
    FutureProvider<List<CallbackWorkingHour>>((ref) async {
  ref.watch(callbackPublicRealtimeProvider);
  return ref.read(callbackServiceProvider).fetchWorkingHours();
});

final adminCallbacksRealtimeProvider = Provider<void>((ref) {
  ref.keepAlive();
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = ref.watch(supabaseClientProvider);
  final channel = client.channel('admin-callbacks')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'callback_requests',
      callback: (_) {
        ref.invalidate(adminCallbacksProvider);
        ref.invalidate(adminCallbackStatsProvider);
      },
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'callback_settings',
      callback: (_) => _invalidateCallbackPublic(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'callback_departments',
      callback: (_) => _invalidateCallbackPublic(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'callback_priorities',
      callback: (_) => _invalidateCallbackPublic(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'callback_working_hours',
      callback: (_) => _invalidateCallbackPublic(ref),
    )
    ..subscribe();

  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

final adminCallbacksProvider =
    FutureProvider<List<AdminCallbackRow>>((ref) async {
  return ref.read(callbackAdminServiceProvider).listRequests();
});

final adminCallbackStatsProvider =
    FutureProvider<AdminCallbackStats>((ref) async {
  return ref.read(callbackAdminServiceProvider).fetchStats();
});

final adminCallbackHistoryProvider =
    FutureProvider.family<List<CallbackStatusHistoryEntry>, String>(
  (ref, id) async {
    return ref.read(callbackAdminServiceProvider).fetchHistory(id);
  },
);

final adminCallbackDepartmentsProvider =
    FutureProvider<List<CallbackDepartment>>((ref) async {
  ref.watch(adminCallbacksRealtimeProvider);
  return ref.read(callbackServiceProvider).fetchDepartments(activeOnly: false);
});

final adminCallbackPrioritiesProvider =
    FutureProvider<List<CallbackPriority>>((ref) async {
  ref.watch(adminCallbacksRealtimeProvider);
  return ref.read(callbackServiceProvider).fetchPriorities(activeOnly: false);
});

final adminCallbackStaffProvider =
    FutureProvider<List<CallbackStaffMember>>((ref) async {
  ref.watch(adminCallbacksRealtimeProvider);
  return ref.read(callbackAdminServiceProvider).listAssignableStaff();
});

final adminCallbackWorkingHoursProvider =
    FutureProvider<List<CallbackWorkingHour>>((ref) async {
  ref.watch(adminCallbacksRealtimeProvider);
  return ref.read(callbackServiceProvider).fetchWorkingHours();
});
