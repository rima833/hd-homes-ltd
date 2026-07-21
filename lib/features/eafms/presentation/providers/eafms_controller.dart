import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/eafms/domain/entities/eafms_models.dart';
import 'package:hdhomesproject/features/eafms/domain/services/eafms_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final eafmsServiceProvider = Provider<EafmsService>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return EafmsService(
    client: configured ? ref.watch(supabaseClientProvider) : null,
  );
});

final eafmsSnapshotProvider =
    FutureProvider<EafmsCommandCenterSnapshot>((ref) async {
  return ref.watch(eafmsServiceProvider).loadCommandCenter();
});

/// Invalidates snapshot when EAFMS live tables change (after SQL apply + Realtime).
final eafmsRealtimeProvider = Provider<void>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = ref.watch(supabaseClientProvider);
  final channel = client.channel('eafms-command-center')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'assets',
      callback: (_) => ref.invalidate(eafmsSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'work_orders',
      callback: (_) => ref.invalidate(eafmsSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'maintenance_records',
      callback: (_) => ref.invalidate(eafmsSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'inspections',
      callback: (_) => ref.invalidate(eafmsSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'asset_activity_logs',
      callback: (_) => ref.invalidate(eafmsSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'asset_notifications',
      callback: (_) => ref.invalidate(eafmsSnapshotProvider),
    )
    ..subscribe();

  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

enum EafmsCommandTab {
  overview,
  register,
  facilities,
  maintenance,
  workOrders,
  inspections,
  fleet,
  utilities,
  warranties,
  depreciation,
  analytics,
  ai;

  String get label => switch (this) {
        EafmsCommandTab.overview => 'Overview',
        EafmsCommandTab.register => 'Register',
        EafmsCommandTab.facilities => 'Facilities',
        EafmsCommandTab.maintenance => 'Maintenance',
        EafmsCommandTab.workOrders => 'Work Orders',
        EafmsCommandTab.inspections => 'Inspections',
        EafmsCommandTab.fleet => 'Fleet',
        EafmsCommandTab.utilities => 'Utilities',
        EafmsCommandTab.warranties => 'Warranties',
        EafmsCommandTab.depreciation => 'Depreciation',
        EafmsCommandTab.analytics => 'Analytics',
        EafmsCommandTab.ai => 'AI',
      };
}

class EafmsUiState {
  const EafmsUiState({
    this.searchQuery = '',
    this.statusFilter,
    this.classFilter,
    this.selectedTab = EafmsCommandTab.overview,
    this.lastMessage,
    this.tickerIndex = 0,
  });

  final String searchQuery;
  final String? statusFilter;
  final String? classFilter;
  final EafmsCommandTab selectedTab;
  final String? lastMessage;
  final int tickerIndex;

  EafmsUiState copyWith({
    String? searchQuery,
    String? statusFilter,
    bool clearStatusFilter = false,
    String? classFilter,
    bool clearClassFilter = false,
    EafmsCommandTab? selectedTab,
    String? lastMessage,
    bool clearMessage = false,
    int? tickerIndex,
  }) {
    return EafmsUiState(
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter:
          clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
      classFilter: clearClassFilter ? null : (classFilter ?? this.classFilter),
      selectedTab: selectedTab ?? this.selectedTab,
      lastMessage: clearMessage ? null : (lastMessage ?? this.lastMessage),
      tickerIndex: tickerIndex ?? this.tickerIndex,
    );
  }
}

class EafmsController extends Notifier<EafmsUiState> {
  Timer? _tickerTimer;

  @override
  EafmsUiState build() {
    // CRITICAL: never read `state` here — arm ticker from initial constants only.
    ref.onDispose(() => _tickerTimer?.cancel());
    ref.watch(eafmsRealtimeProvider);
    _armTicker();
    return const EafmsUiState();
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

  void setClassFilter(String? assetClass) {
    if (assetClass == null) {
      state = state.copyWith(clearClassFilter: true);
    } else {
      state = state.copyWith(classFilter: assetClass);
    }
  }

  void setTab(EafmsCommandTab tab) {
    state = state.copyWith(selectedTab: tab);
  }

  void setMessage(String message) {
    state = state.copyWith(lastMessage: message);
  }

  void clearMessage() {
    state = state.copyWith(clearMessage: true);
  }

  Future<void> refresh() async {
    ref.invalidate(eafmsSnapshotProvider);
  }

  List<EafmsAsset> filteredAssets(EafmsCommandCenterSnapshot snap) {
    final q = state.searchQuery.trim().toLowerCase();
    return snap.assets.where((a) {
      if (state.statusFilter != null && a.status != state.statusFilter) {
        return false;
      }
      if (state.classFilter != null && a.assetClass != state.classFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return a.name.toLowerCase().contains(q) ||
          (a.assetTag?.toLowerCase().contains(q) ?? false) ||
          (a.facilityName?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  List<EafmsWorkOrder> filteredWorkOrders(EafmsCommandCenterSnapshot snap) {
    final q = state.searchQuery.trim().toLowerCase();
    return snap.workOrders.where((w) {
      if (state.statusFilter != null && w.status != state.statusFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return w.title.toLowerCase().contains(q) ||
          (w.code?.toLowerCase().contains(q) ?? false) ||
          (w.assigneeLabel?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  List<EafmsFacility> filteredFacilities(EafmsCommandCenterSnapshot snap) {
    final q = state.searchQuery.trim().toLowerCase();
    return snap.facilities.where((f) {
      if (state.statusFilter != null && f.status != state.statusFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return f.name.toLowerCase().contains(q) ||
          (f.code?.toLowerCase().contains(q) ?? false) ||
          (f.city?.toLowerCase().contains(q) ?? false);
    }).toList();
  }
}

final eafmsControllerProvider =
    NotifierProvider<EafmsController, EafmsUiState>(EafmsController.new);
