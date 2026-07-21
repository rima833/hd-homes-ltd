import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/eoc/domain/entities/eoc_models.dart';
import 'package:hdhomesproject/features/eoc/domain/services/eoc_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final eocServiceProvider = Provider<EocService>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return EocService(
    client: configured ? ref.watch(supabaseClientProvider) : null,
  );
});

final eocSnapshotProvider =
    FutureProvider<EocMissionControlSnapshot>((ref) async {
  return ref.watch(eocServiceProvider).loadMissionControl();
});

/// Invalidates snapshot when EOC live tables change (after SQL apply + Realtime).
final eocRealtimeProvider = Provider<void>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = ref.watch(supabaseClientProvider);
  final channel = client.channel('eoc-mission-control')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'enterprise_alerts',
      callback: (_) => ref.invalidate(eocSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'enterprise_tasks',
      callback: (_) => ref.invalidate(eocSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'approval_requests',
      callback: (_) => ref.invalidate(eocSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'eoc_activity_logs',
      callback: (_) => ref.invalidate(eocSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'workflow_instances',
      callback: (_) => ref.invalidate(eocSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'enterprise_kpis',
      callback: (_) => ref.invalidate(eocSnapshotProvider),
    )
    ..subscribe();

  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

enum EocCommandTab {
  overview,
  kpis,
  search,
  ai,
  workflows,
  approvals,
  alerts,
  tasks,
  forecasts,
  scorecards,
  knowledge,
  audit;

  String get label => switch (this) {
        EocCommandTab.overview => 'Overview',
        EocCommandTab.kpis => 'KPIs',
        EocCommandTab.search => 'Search',
        EocCommandTab.ai => 'AI Copilot',
        EocCommandTab.workflows => 'Workflows',
        EocCommandTab.approvals => 'Approvals',
        EocCommandTab.alerts => 'Alerts',
        EocCommandTab.tasks => 'Tasks',
        EocCommandTab.forecasts => 'BI / Forecasts',
        EocCommandTab.scorecards => 'Scorecards',
        EocCommandTab.knowledge => 'Knowledge',
        EocCommandTab.audit => 'Audit',
      };
}

class EocUiState {
  const EocUiState({
    this.searchQuery = '',
    this.statusFilter,
    this.selectedTab = EocCommandTab.overview,
    this.lastMessage,
    this.tickerIndex = 0,
  });

  final String searchQuery;
  final String? statusFilter;
  final EocCommandTab selectedTab;
  final String? lastMessage;
  final int tickerIndex;

  EocUiState copyWith({
    String? searchQuery,
    String? statusFilter,
    bool clearStatusFilter = false,
    EocCommandTab? selectedTab,
    String? lastMessage,
    bool clearMessage = false,
    int? tickerIndex,
  }) {
    return EocUiState(
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter:
          clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
      selectedTab: selectedTab ?? this.selectedTab,
      lastMessage: clearMessage ? null : (lastMessage ?? this.lastMessage),
      tickerIndex: tickerIndex ?? this.tickerIndex,
    );
  }
}

class EocController extends Notifier<EocUiState> {
  Timer? _tickerTimer;

  @override
  EocUiState build() {
    // CRITICAL: never read `state` here — arm ticker from initial constants only.
    ref.onDispose(() => _tickerTimer?.cancel());
    ref.watch(eocRealtimeProvider);
    _armTicker();
    return const EocUiState();
  }

  void _armTicker() {
    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      // Tickers may update state only inside Timer callbacks.
      state = state.copyWith(tickerIndex: state.tickerIndex + 1);
    });
  }

  void setSearch(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setStatusFilter(String? statusSlug) {
    if (statusSlug == null) {
      state = state.copyWith(clearStatusFilter: true);
    } else {
      state = state.copyWith(statusFilter: statusSlug);
    }
  }

  void setTab(EocCommandTab tab) {
    state = state.copyWith(selectedTab: tab);
  }

  void setMessage(String message) {
    state = state.copyWith(lastMessage: message);
  }

  void clearMessage() {
    state = state.copyWith(clearMessage: true);
  }

  Future<void> refresh() async {
    ref.invalidate(eocSnapshotProvider);
  }

  List<EocAlert> filteredAlerts(EocMissionControlSnapshot snap) {
    final q = state.searchQuery.trim().toLowerCase();
    return snap.alerts.where((a) {
      if (state.statusFilter != null && a.status != state.statusFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return a.title.toLowerCase().contains(q) ||
          (a.body?.toLowerCase().contains(q) ?? false) ||
          (a.moduleSlug?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  List<EocApproval> filteredApprovals(EocMissionControlSnapshot snap) {
    final q = state.searchQuery.trim().toLowerCase();
    return snap.approvals.where((a) {
      if (state.statusFilter != null && a.status != state.statusFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return a.title.toLowerCase().contains(q) ||
          (a.summary?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  List<EocTask> filteredTasks(EocMissionControlSnapshot snap) {
    final q = state.searchQuery.trim().toLowerCase();
    return snap.tasks.where((t) {
      if (state.statusFilter != null && t.status != state.statusFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return t.title.toLowerCase().contains(q) ||
          (t.assigneeLabel?.toLowerCase().contains(q) ?? false);
    }).toList();
  }
}

final eocControllerProvider =
    NotifierProvider<EocController, EocUiState>(EocController.new);
