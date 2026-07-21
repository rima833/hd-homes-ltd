import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
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

/// Live invalidation for admin command center + timelines.
final auditRealtimeProvider = Provider<void>((ref) {
  final session = ref.watch(identitySessionProvider);
  if (session.userId == null) return;

  RealtimeChannel? auditChannel;
  RealtimeChannel? alertChannel;
  final service = ref.read(auditServiceProvider);

  auditChannel = service.subscribeAuditFeed((_) {
    ref.invalidate(activityTimelineProvider);
    ref.invalidate(commandCenterProvider);
    ref.invalidate(adminAuditSearchProvider);
  });
  alertChannel = service.subscribeAlerts(() {
    ref.invalidate(commandCenterProvider);
  });

  ref.onDispose(() {
    auditChannel?.unsubscribe();
    alertChannel?.unsubscribe();
  });
});

class AuditUiState {
  const AuditUiState({
    this.isBusy = false,
    this.message,
    this.error,
    this.exportedCsv,
  });

  final bool isBusy;
  final String? message;
  final String? error;
  final String? exportedCsv;

  AuditUiState copyWith({
    bool? isBusy,
    String? message,
    String? error,
    String? exportedCsv,
    bool clearMessage = false,
    bool clearError = false,
    bool clearExport = false,
  }) {
    return AuditUiState(
      isBusy: isBusy ?? this.isBusy,
      message: clearMessage ? null : (message ?? this.message),
      error: clearError ? null : (error ?? this.error),
      exportedCsv: clearExport ? null : (exportedCsv ?? this.exportedCsv),
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

  Future<void> publishDemoEvent() async {
    final userId = ref.read(identitySessionProvider).userId;
    state = state.copyWith(isBusy: true, clearError: true);
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
        message: 'Probe event published.',
      );
    } catch (e) {
      state = state.copyWith(isBusy: false, error: e.toString());
    }
  }

  Future<void> acknowledgeAlert(String id) async {
    final userId = ref.read(identitySessionProvider).userId;
    await _service.acknowledgeAlert(id, actorId: userId);
    ref.invalidate(commandCenterProvider);
    state = state.copyWith(message: 'Alert acknowledged.');
  }

  Future<void> resolveAlert(String id) async {
    final userId = ref.read(identitySessionProvider).userId;
    await _service.resolveAlert(id, actorId: userId);
    ref.invalidate(commandCenterProvider);
    state = state.copyWith(message: 'Alert resolved.');
  }

  Future<void> exportVisible(List<AuditRecord> records) async {
    state = state.copyWith(isBusy: true);
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
  }
}
