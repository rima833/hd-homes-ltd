import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/biadw/domain/entities/biadw_models.dart';
import 'package:hdhomesproject/features/biadw/domain/services/biadw_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final biadwServiceProvider = Provider<BiadwService>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return BiadwService(
    client: configured ? ref.watch(supabaseClientProvider) : null,
  );
});

final biadwSnapshotProvider =
    FutureProvider<BiadwCommandCenterSnapshot>((ref) async {
  return ref.watch(biadwServiceProvider).loadCommandCenter();
});

/// Invalidates snapshot when analytics live tables change (after SQL apply + Realtime).
final biadwRealtimeProvider = Provider<void>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = ref.watch(supabaseClientProvider);
  final channel = client.channel('bi-command-center')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'analytics_kpis',
      callback: (_) => ref.invalidate(biadwSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'analytics_dashboards',
      callback: (_) => ref.invalidate(biadwSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'analytics_etl_jobs',
      callback: (_) => ref.invalidate(biadwSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'analytics_quality_issues',
      callback: (_) => ref.invalidate(biadwSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'analytics_activity_logs',
      callback: (_) => ref.invalidate(biadwSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'analytics_notifications',
      callback: (_) => ref.invalidate(biadwSnapshotProvider),
    )
    ..subscribe();

  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

enum BiadwCommandTab {
  overview,
  warehouse,
  etl,
  kpis,
  dashboards,
  reports,
  forecasts,
  scorecards,
  quality,
  governance,
  analytics,
  ai;

  String get label => switch (this) {
        BiadwCommandTab.overview => 'Overview',
        BiadwCommandTab.warehouse => 'Warehouse',
        BiadwCommandTab.etl => 'ETL',
        BiadwCommandTab.kpis => 'KPIs',
        BiadwCommandTab.dashboards => 'Dashboards',
        BiadwCommandTab.reports => 'Reports',
        BiadwCommandTab.forecasts => 'Forecasts',
        BiadwCommandTab.scorecards => 'Scorecards',
        BiadwCommandTab.quality => 'Quality',
        BiadwCommandTab.governance => 'Governance',
        BiadwCommandTab.analytics => 'Analytics',
        BiadwCommandTab.ai => 'AI',
      };
}

class BiadwUiState {
  const BiadwUiState({
    this.searchQuery = '',
    this.statusFilter,
    this.selectedTab = BiadwCommandTab.overview,
    this.lastMessage,
    this.tickerIndex = 0,
  });

  final String searchQuery;
  final String? statusFilter;
  final BiadwCommandTab selectedTab;
  final String? lastMessage;
  final int tickerIndex;

  BiadwUiState copyWith({
    String? searchQuery,
    String? statusFilter,
    bool clearStatusFilter = false,
    BiadwCommandTab? selectedTab,
    String? lastMessage,
    bool clearMessage = false,
    int? tickerIndex,
  }) {
    return BiadwUiState(
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter:
          clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
      selectedTab: selectedTab ?? this.selectedTab,
      lastMessage: clearMessage ? null : (lastMessage ?? this.lastMessage),
      tickerIndex: tickerIndex ?? this.tickerIndex,
    );
  }
}

class BiadwController extends Notifier<BiadwUiState> {
  Timer? _tickerTimer;

  @override
  BiadwUiState build() {
    // CRITICAL: never read `state` here — arm ticker from initial constants only.
    ref.onDispose(() => _tickerTimer?.cancel());
    ref.watch(biadwRealtimeProvider);
    _armTicker();
    return const BiadwUiState();
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

  void setTab(BiadwCommandTab tab) {
    state = state.copyWith(selectedTab: tab);
  }

  void setMessage(String message) {
    state = state.copyWith(lastMessage: message);
  }

  void clearMessage() {
    state = state.copyWith(clearMessage: true);
  }

  Future<void> refresh() async {
    ref.invalidate(biadwSnapshotProvider);
  }

  List<BiadwEtlJob> filteredEtlJobs(BiadwCommandCenterSnapshot snap) {
    final q = state.searchQuery.trim().toLowerCase();
    return snap.etlJobs.where((j) {
      if (state.statusFilter != null && j.status != state.statusFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return j.name.toLowerCase().contains(q) ||
          (j.code?.toLowerCase().contains(q) ?? false) ||
          (j.ownerLabel?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  List<BiadwQualityIssue> filteredQuality(BiadwCommandCenterSnapshot snap) {
    final q = state.searchQuery.trim().toLowerCase();
    return snap.qualityIssues.where((issue) {
      if (state.statusFilter != null && issue.status != state.statusFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return issue.title.toLowerCase().contains(q) ||
          (issue.code?.toLowerCase().contains(q) ?? false) ||
          (issue.datasetLabel?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  List<BiadwDashboard> filteredDashboards(BiadwCommandCenterSnapshot snap) {
    final q = state.searchQuery.trim().toLowerCase();
    return snap.dashboards.where((d) {
      if (state.statusFilter != null && d.status != state.statusFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return d.title.toLowerCase().contains(q) ||
          (d.code?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  List<BiadwReport> filteredReports(BiadwCommandCenterSnapshot snap) {
    final q = state.searchQuery.trim().toLowerCase();
    return snap.reports.where((r) {
      if (state.statusFilter != null && r.status != state.statusFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return r.title.toLowerCase().contains(q) ||
          (r.code?.toLowerCase().contains(q) ?? false);
    }).toList();
  }
}

final biadwControllerProvider =
    NotifierProvider<BiadwController, BiadwUiState>(BiadwController.new);
