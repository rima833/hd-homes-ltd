import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/core/utils/provider_lifecycle.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/observability_models.dart';
import 'package:hdhomesproject/features/authentication/domain/services/audit_service.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/auth_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final auditServiceProvider = Provider<AuditService>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return AuditService(
    client: configured ? ref.watch(supabaseClientProvider) : null,
  );
});

final activityTimelineProvider =
    FutureProvider<ActivityTimelineSnapshot?>((ref) async {
  final session = ref.watch(identitySessionProvider);
  final userId = session.userId;
  if (userId == null) return null;
  final filter = ref.watch(observabilityFilterProvider);
  return ref.watch(auditServiceProvider).loadUserTimeline(
        userId,
        filter: filter,
      );
});

final commandCenterProvider =
    FutureProvider<CommandCenterSnapshot>((ref) async {
  return ref.watch(auditServiceProvider).loadCommandCenter();
});

final adminAuditSearchProvider =
    FutureProvider<List<AuditRecord>>((ref) async {
  final filter = ref.watch(observabilityFilterProvider);
  return ref.watch(auditServiceProvider).search(filter);
});

final observabilityFilterProvider =
    NotifierProvider<ObservabilityFilterNotifier, ObservabilityFilter>(
  ObservabilityFilterNotifier.new,
);

class ObservabilityFilterNotifier extends Notifier<ObservabilityFilter> {
  @override
  ObservabilityFilter build() => const ObservabilityFilter();

  void setPreset(ActivityDatePreset preset) {
    state = state.copyWith(preset: preset);
  }

  void setCategory(AuditEventCategory? category) {
    state = state.copyWith(
      category: category,
      clearCategory: category == null,
    );
  }

  void setSeverity(AuditSeverity? severity) {
    state = state.copyWith(
      severity: severity,
      clearSeverity: severity == null,
    );
  }

  void setQuery(String? query) {
    state = state.copyWith(
      query: query,
      clearQuery: query == null || query.trim().isEmpty,
    );
  }

  void reset() => state = const ObservabilityFilter();
}

final auditRealtimeStatusProvider = StateProvider<bool>((ref) => false);

/// Live invalidation for admin command center + timelines.
final auditRealtimeProvider = Provider<void>((ref) {
  final session = ref.watch(identitySessionProvider);
  final configured = ref.watch(supabaseConfiguredProvider);
  if (!configured || session.userId == null) {
    deferProviderMutation(
      () => ref.read(auditRealtimeStatusProvider.notifier).state = false,
    );
    return;
  }

  final client = ref.watch(supabaseClientProvider);
  void bumpCenter() =>
      deferProviderMutation(() => ref.invalidate(commandCenterProvider));
  void bumpAll() => deferProviderMutation(() {
        ref.invalidate(activityTimelineProvider);
        ref.invalidate(commandCenterProvider);
        ref.invalidate(adminAuditSearchProvider);
      });

  final channel = client.channel('observability-command-center')
    ..onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'audit_logs',
      callback: (_) => bumpAll(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'system_alerts',
      callback: (_) => bumpCenter(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'system_health',
      callback: (_) => bumpCenter(),
    );
  for (final table in const [
    'crm_activity_logs',
    'sales_activity_logs',
    'project_activity_logs',
    'marketing_activity_logs',
    'finance_activity_logs',
    'support_activity_logs',
    'document_activity_logs',
    'investor_activity_logs',
  ]) {
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: table,
      callback: (_) => bumpAll(),
    );
  }
  channel.subscribe((status, [error]) {
      final live = status == RealtimeSubscribeStatus.subscribed;
      deferProviderMutation(
        () => ref.read(auditRealtimeStatusProvider.notifier).state = live,
      );
    });

  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
    deferProviderMutation(
      () => ref.read(auditRealtimeStatusProvider.notifier).state = false,
    );
  });
});

enum OccDeskTab {
  overview,
  health,
  alerts,
  activity,
  audit;

  String get label => switch (this) {
        OccDeskTab.overview => 'Overview',
        OccDeskTab.health => 'System health',
        OccDeskTab.alerts => 'Alerts',
        OccDeskTab.activity => 'Activity',
        OccDeskTab.audit => 'Audit search',
      };
}

class AuditUiState {
  const AuditUiState({
    this.isBusy = false,
    this.message,
    this.error,
    this.exportedCsv,
    this.selectedTab = OccDeskTab.overview,
  });

  final bool isBusy;
  final String? message;
  final String? error;
  final String? exportedCsv;
  final OccDeskTab selectedTab;

  AuditUiState copyWith({
    bool? isBusy,
    String? message,
    String? error,
    String? exportedCsv,
    OccDeskTab? selectedTab,
    bool clearMessage = false,
    bool clearError = false,
    bool clearExport = false,
  }) {
    return AuditUiState(
      isBusy: isBusy ?? this.isBusy,
      message: clearMessage ? null : (message ?? this.message),
      error: clearError ? null : (error ?? this.error),
      exportedCsv: clearExport ? null : (exportedCsv ?? this.exportedCsv),
      selectedTab: selectedTab ?? this.selectedTab,
    );
  }
}

final auditControllerProvider =
    NotifierProvider<AuditController, AuditUiState>(AuditController.new);

class AuditController extends Notifier<AuditUiState> {
  @override
  AuditUiState build() {
    ref.watch(auditRealtimeProvider);
    return const AuditUiState();
  }

  AuditService get _service => ref.read(auditServiceProvider);

  Future<void> publishHeartbeatProbe() async {
    final userId = ref.read(identitySessionProvider).userId;
    state = state.copyWith(isBusy: true, clearError: true, clearMessage: true);
    try {
      await _service.publish(
        AuditPublishRequest(
          action: 'observability_heartbeat',
          module: 'observability',
          category: AuditEventCategory.system,
          userId: userId,
          severity: AuditSeverity.info,
          reason: 'Manual command-center probe',
        ),
      );
      ref.invalidate(commandCenterProvider);
      ref.invalidate(activityTimelineProvider);
      state = state.copyWith(
        isBusy: false,
        message: 'Heartbeat recorded in audit trail.',
      );
    } catch (e) {
      state = state.copyWith(isBusy: false, error: userFacingError(e));
    }
  }

  Future<void> runHealthProbe() async {
    state = state.copyWith(isBusy: true, clearError: true, clearMessage: true);
    try {
      await _service.runHealthProbe();
      ref.invalidate(commandCenterProvider);
      state = state.copyWith(
        isBusy: false,
        message: 'System health probe completed.',
      );
    } catch (e) {
      state = state.copyWith(isBusy: false, error: userFacingError(e));
    }
  }

  void clearFeedback() {
    state = state.copyWith(clearMessage: true, clearError: true);
  }

  void setTab(OccDeskTab tab) {
    state = state.copyWith(selectedTab: tab);
  }

  Future<void> acknowledgeAlert(String id) async {
    final userId = ref.read(identitySessionProvider).userId;
    state = state.copyWith(clearError: true);
    try {
      await _service.acknowledgeAlert(id, actorId: userId);
      ref.invalidate(commandCenterProvider);
      state = state.copyWith(message: 'Alert acknowledged.');
    } catch (e) {
      state = state.copyWith(error: userFacingError(e));
    }
  }

  Future<void> resolveAlert(String id) async {
    final userId = ref.read(identitySessionProvider).userId;
    state = state.copyWith(clearError: true);
    try {
      await _service.resolveAlert(id, actorId: userId);
      ref.invalidate(commandCenterProvider);
      state = state.copyWith(message: 'Alert resolved.');
    } catch (e) {
      state = state.copyWith(error: userFacingError(e));
    }
  }

  Future<void> updateAlertGroup(
    SystemAlert alert,
    AlertLifecycle lifecycle,
  ) async {
    state = state.copyWith(clearError: true, clearMessage: true);
    try {
      final count = await _service.updateAlertGroup(
        title: alert.title,
        sourceModule: alert.sourceModule,
        severity: alert.severity.slug,
        lifecycle: lifecycle,
      );
      ref.invalidate(commandCenterProvider);
      final verb = lifecycle == AlertLifecycle.acknowledged
          ? 'acknowledged'
          : 'resolved';
      state = state.copyWith(
        message: count <= 1
            ? 'Alert $verb.'
            : '$count matching alerts $verb.',
      );
    } catch (e) {
      state = state.copyWith(error: userFacingError(e));
    }
  }

  Future<void> exportVisible(List<AuditRecord> records) async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final csv = _service.exportCsv(records);
      await _service.publish(
        AuditPublishRequest(
          action: 'audit_export',
          module: 'observability',
          category: AuditEventCategory.admin,
          userId: ref.read(identitySessionProvider).userId,
          severity: AuditSeverity.notice,
          reason: 'CSV export (${records.length} rows)',
          metadata: {'row_count': records.length, 'format': 'csv'},
        ),
      );
      state = state.copyWith(
        isBusy: false,
        exportedCsv: csv,
        message: 'Export ready (${records.length} rows).',
      );
    } catch (e) {
      state = state.copyWith(isBusy: false, error: userFacingError(e));
    }
  }
}
