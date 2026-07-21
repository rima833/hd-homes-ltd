import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/eaih/domain/entities/eaih_models.dart';
import 'package:hdhomesproject/features/eaih/domain/services/eaih_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final eaihServiceProvider = Provider<EaihService>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return EaihService(
    client: configured ? ref.watch(supabaseClientProvider) : null,
  );
});

final eaihSnapshotProvider =
    FutureProvider<EaihCommandCenterSnapshot>((ref) async {
  return ref.watch(eaihServiceProvider).loadCommandCenter();
});

/// Invalidates snapshot when AI hub live tables change (after SQL apply + Realtime).
final eaihRealtimeProvider = Provider<void>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = ref.watch(supabaseClientProvider);
  final channel = client.channel('ai-command-center')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'ai_predictions',
      callback: (_) => ref.invalidate(eaihSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'ai_recommendations',
      callback: (_) => ref.invalidate(eaihSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'ai_automation_jobs',
      callback: (_) => ref.invalidate(eaihSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'ai_model_monitoring',
      callback: (_) => ref.invalidate(eaihSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'ai_activity_logs',
      callback: (_) => ref.invalidate(eaihSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'ai_notifications',
      callback: (_) => ref.invalidate(eaihSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'ai_conversations',
      callback: (_) => ref.invalidate(eaihSnapshotProvider),
    )
    ..subscribe();

  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

enum EaihCommandTab {
  overview,
  copilots,
  models,
  predictions,
  recommendations,
  search,
  knowledge,
  automation,
  decision,
  governance,
  observability,
  analytics;

  String get label => switch (this) {
        EaihCommandTab.overview => 'Overview',
        EaihCommandTab.copilots => 'Copilots',
        EaihCommandTab.models => 'Models',
        EaihCommandTab.predictions => 'Predictions',
        EaihCommandTab.recommendations => 'Recommendations',
        EaihCommandTab.search => 'Search',
        EaihCommandTab.knowledge => 'Knowledge',
        EaihCommandTab.automation => 'Automation',
        EaihCommandTab.decision => 'Decision',
        EaihCommandTab.governance => 'Governance',
        EaihCommandTab.observability => 'Observability',
        EaihCommandTab.analytics => 'Analytics',
      };
}

class EaihUiState {
  const EaihUiState({
    this.searchQuery = '',
    this.statusFilter,
    this.selectedTab = EaihCommandTab.overview,
    this.lastMessage,
    this.tickerIndex = 0,
  });

  final String searchQuery;
  final String? statusFilter;
  final EaihCommandTab selectedTab;
  final String? lastMessage;
  final int tickerIndex;

  EaihUiState copyWith({
    String? searchQuery,
    String? statusFilter,
    bool clearStatusFilter = false,
    EaihCommandTab? selectedTab,
    String? lastMessage,
    bool clearMessage = false,
    int? tickerIndex,
  }) {
    return EaihUiState(
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter:
          clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
      selectedTab: selectedTab ?? this.selectedTab,
      lastMessage: clearMessage ? null : (lastMessage ?? this.lastMessage),
      tickerIndex: tickerIndex ?? this.tickerIndex,
    );
  }
}

class EaihController extends Notifier<EaihUiState> {
  Timer? _tickerTimer;

  @override
  EaihUiState build() {
    // CRITICAL: never read `state` here — arm ticker from initial constants only.
    ref.onDispose(() => _tickerTimer?.cancel());
    ref.watch(eaihRealtimeProvider);
    _armTicker();
    return const EaihUiState();
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

  void setTab(EaihCommandTab tab) {
    state = state.copyWith(selectedTab: tab);
  }

  void setMessage(String message) {
    state = state.copyWith(lastMessage: message);
  }

  void clearMessage() {
    state = state.copyWith(clearMessage: true);
  }

  Future<void> refresh() async {
    ref.invalidate(eaihSnapshotProvider);
  }

  List<EaihAutomationJob> filteredAutomation(EaihCommandCenterSnapshot snap) {
    final q = state.searchQuery.trim().toLowerCase();
    return snap.automationJobs.where((j) {
      if (state.statusFilter != null && j.status != state.statusFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return j.name.toLowerCase().contains(q) ||
          (j.code?.toLowerCase().contains(q) ?? false) ||
          (j.ownerLabel?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  List<EaihPrediction> filteredPredictions(EaihCommandCenterSnapshot snap) {
    final q = state.searchQuery.trim().toLowerCase();
    return snap.predictions.where((p) {
      if (state.statusFilter != null && p.status != state.statusFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return p.title.toLowerCase().contains(q) ||
          (p.code?.toLowerCase().contains(q) ?? false) ||
          (p.targetModule?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  List<EaihRecommendation> filteredRecommendations(
    EaihCommandCenterSnapshot snap,
  ) {
    final q = state.searchQuery.trim().toLowerCase();
    return snap.recommendations.where((r) {
      if (state.statusFilter != null && r.status != state.statusFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return r.title.toLowerCase().contains(q) ||
          (r.code?.toLowerCase().contains(q) ?? false) ||
          r.body.toLowerCase().contains(q);
    }).toList();
  }

  List<EaihCopilot> filteredCopilots(EaihCommandCenterSnapshot snap) {
    final q = state.searchQuery.trim().toLowerCase();
    return snap.copilots.where((c) {
      if (state.statusFilter != null && c.status != state.statusFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return c.name.toLowerCase().contains(q) ||
          c.slug.toLowerCase().contains(q) ||
          c.department.toLowerCase().contains(q);
    }).toList();
  }

  List<EaihDriftReport> filteredDrift(EaihCommandCenterSnapshot snap) {
    final q = state.searchQuery.trim().toLowerCase();
    return snap.driftReports.where((d) {
      if (state.statusFilter != null && d.status != state.statusFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return d.title.toLowerCase().contains(q) ||
          (d.code?.toLowerCase().contains(q) ?? false);
    }).toList();
  }
}

final eaihControllerProvider =
    NotifierProvider<EaihController, EaihUiState>(EaihController.new);
