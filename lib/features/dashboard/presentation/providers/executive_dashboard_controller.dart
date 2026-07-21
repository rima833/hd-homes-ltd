import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/identity_provider.dart';
import 'package:hdhomesproject/features/dashboard/domain/entities/executive_dashboard_models.dart';
import 'package:hdhomesproject/features/dashboard/domain/services/executive_dashboard_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final executiveDashboardServiceProvider =
    Provider<ExecutiveDashboardService>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return ExecutiveDashboardService(
    client: configured ? ref.watch(supabaseClientProvider) : null,
  );
});

final executiveDashboardSnapshotProvider =
    FutureProvider<ExecutiveDashboardSnapshot>((ref) async {
  return ref.watch(executiveDashboardServiceProvider).loadSnapshot();
});

/// Invalidates snapshot when live tables change (after SQL apply + Realtime).
final executiveDashboardRealtimeProvider = Provider<void>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = ref.watch(supabaseClientProvider);
  final channel = client.channel('executive-mission-control')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'kpi_snapshots',
      callback: (_) => ref.invalidate(executiveDashboardSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'executive_activity_feed',
      callback: (_) => ref.invalidate(executiveDashboardSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'ai_executive_insights',
      callback: (_) => ref.invalidate(executiveDashboardSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'executive_notifications',
      callback: (_) => ref.invalidate(executiveDashboardSnapshotProvider),
    )
    ..subscribe();

  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

class ExecutiveDashboardUiState {
  const ExecutiveDashboardUiState({
    this.presentationMode = false,
    this.autoRefresh = true,
    this.tickerIndex = 0,
    this.lastReportMessage,
    this.hiddenModules = const {},
  });

  final bool presentationMode;
  final bool autoRefresh;
  final int tickerIndex;
  final String? lastReportMessage;
  final Set<String> hiddenModules;

  ExecutiveDashboardUiState copyWith({
    bool? presentationMode,
    bool? autoRefresh,
    int? tickerIndex,
    String? lastReportMessage,
    Set<String>? hiddenModules,
    bool clearReport = false,
  }) {
    return ExecutiveDashboardUiState(
      presentationMode: presentationMode ?? this.presentationMode,
      autoRefresh: autoRefresh ?? this.autoRefresh,
      tickerIndex: tickerIndex ?? this.tickerIndex,
      lastReportMessage:
          clearReport ? null : (lastReportMessage ?? this.lastReportMessage),
      hiddenModules: hiddenModules ?? this.hiddenModules,
    );
  }
}

class ExecutiveDashboardController
    extends Notifier<ExecutiveDashboardUiState> {
  Timer? _refreshTimer;
  Timer? _tickerTimer;

  @override
  ExecutiveDashboardUiState build() {
    ref.onDispose(() {
      _refreshTimer?.cancel();
      _tickerTimer?.cancel();
    });
    // Keep Realtime subscription alive while controller is watched.
    ref.watch(executiveDashboardRealtimeProvider);

    const initial = ExecutiveDashboardUiState();
    // Do not read `state` during build — it is uninitialized until build returns.
    _armRefresh(enabled: initial.autoRefresh);
    _armTicker();
    return initial;
  }

  void _armRefresh({bool? enabled}) {
    _refreshTimer?.cancel();
    final autoRefresh = enabled ?? state.autoRefresh;
    if (!autoRefresh) return;
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      ref.invalidate(executiveDashboardSnapshotProvider);
    });
  }

  void _armTicker() {
    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      // Timer runs after build; state is safe here.
      state = state.copyWith(tickerIndex: state.tickerIndex + 1);
    });
  }

  void togglePresentationMode() {
    state = state.copyWith(presentationMode: !state.presentationMode);
  }

  void setAutoRefresh(bool value) {
    state = state.copyWith(autoRefresh: value);
    _armRefresh(enabled: value);
  }

  void toggleModule(String key) {
    final next = {...state.hiddenModules};
    if (next.contains(key)) {
      next.remove(key);
    } else {
      next.add(key);
    }
    state = state.copyWith(hiddenModules: next);
  }

  Future<void> refresh() async {
    ref.invalidate(executiveDashboardSnapshotProvider);
  }

  Future<void> markRead(String id) async {
    await ref.read(executiveDashboardServiceProvider).markNotificationRead(id);
    ref.invalidate(executiveDashboardSnapshotProvider);
  }

  Future<void> generateReport(String reportType, {String format = 'pdf'}) async {
    final userId = ref.read(identitySessionProvider).userId ?? 'anonymous';
    final result = await ref.read(executiveDashboardServiceProvider).queueReport(
          reportType: reportType,
          format: format,
          userId: userId,
        );
    state = state.copyWith(
      lastReportMessage:
          '${result['title'] ?? reportType} ready (${result['format'] ?? format}).',
    );
  }

  String briefingText(ExecutiveDashboardSnapshot snap) {
    return ref.read(executiveDashboardServiceProvider).buildBriefing(snap);
  }
}

final executiveDashboardControllerProvider = NotifierProvider<
    ExecutiveDashboardController, ExecutiveDashboardUiState>(
  ExecutiveDashboardController.new,
);
