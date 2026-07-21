import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/sbms/domain/entities/sbms_models.dart';
import 'package:hdhomesproject/features/sbms/domain/services/sbms_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final sbmsServiceProvider = Provider<SbmsService>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return SbmsService(
    client: configured ? ref.watch(supabaseClientProvider) : null,
  );
});

final sbmsSnapshotProvider =
    FutureProvider<SbmsCommandCenterSnapshot>((ref) async {
  return ref.watch(sbmsServiceProvider).loadCommandCenter();
});

/// Invalidates snapshot when SBMS live tables change (after SQL apply + Realtime).
final sbmsRealtimeProvider = Provider<void>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = ref.watch(supabaseClientProvider);
  final channel = client.channel('sbms-command-center')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'sales_reservations',
      callback: (_) => ref.invalidate(sbmsSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'sales_bookings',
      callback: (_) => ref.invalidate(sbmsSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'sales_orders',
      callback: (_) => ref.invalidate(sbmsSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'sales_quotes',
      callback: (_) => ref.invalidate(sbmsSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'sales_contracts',
      callback: (_) => ref.invalidate(sbmsSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'sales_installments',
      callback: (_) => ref.invalidate(sbmsSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'sales_commissions',
      callback: (_) => ref.invalidate(sbmsSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'sales_discount_requests',
      callback: (_) => ref.invalidate(sbmsSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'sales_activity_logs',
      callback: (_) => ref.invalidate(sbmsSnapshotProvider),
    )
    ..subscribe();

  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

enum SbmsCommandTab {
  overview,
  pipeline,
  reservations,
  bookings,
  quotes,
  deals,
  commissions,
  handovers,
  approvals,
  ai;

  String get label => switch (this) {
        SbmsCommandTab.overview => 'Overview',
        SbmsCommandTab.pipeline => 'Pipeline',
        SbmsCommandTab.reservations => 'Reservations',
        SbmsCommandTab.bookings => 'Bookings',
        SbmsCommandTab.quotes => 'Quotes',
        SbmsCommandTab.deals => 'Deal Room',
        SbmsCommandTab.commissions => 'Commissions',
        SbmsCommandTab.handovers => 'Handovers',
        SbmsCommandTab.approvals => 'Approvals',
        SbmsCommandTab.ai => 'AI Assistant',
      };
}

class SbmsUiState {
  const SbmsUiState({
    this.searchQuery = '',
    this.stageFilter,
    this.selectedTab = SbmsCommandTab.overview,
    this.selectedDealId,
    this.lastMessage,
    this.tickerIndex = 0,
  });

  final String searchQuery;
  final String? stageFilter;
  final SbmsCommandTab selectedTab;
  final String? selectedDealId;
  final String? lastMessage;
  final int tickerIndex;

  SbmsUiState copyWith({
    String? searchQuery,
    String? stageFilter,
    bool clearStageFilter = false,
    SbmsCommandTab? selectedTab,
    String? selectedDealId,
    bool clearSelectedDeal = false,
    String? lastMessage,
    bool clearMessage = false,
    int? tickerIndex,
  }) {
    return SbmsUiState(
      searchQuery: searchQuery ?? this.searchQuery,
      stageFilter:
          clearStageFilter ? null : (stageFilter ?? this.stageFilter),
      selectedTab: selectedTab ?? this.selectedTab,
      selectedDealId: clearSelectedDeal
          ? null
          : (selectedDealId ?? this.selectedDealId),
      lastMessage: clearMessage ? null : (lastMessage ?? this.lastMessage),
      tickerIndex: tickerIndex ?? this.tickerIndex,
    );
  }
}

class SbmsController extends Notifier<SbmsUiState> {
  Timer? _tickerTimer;

  @override
  SbmsUiState build() {
    ref.onDispose(() => _tickerTimer?.cancel());
    ref.watch(sbmsRealtimeProvider);
    _armTicker();
    return const SbmsUiState();
  }

  void _armTicker() {
    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      state = state.copyWith(tickerIndex: state.tickerIndex + 1);
    });
  }

  void setSearch(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setStageFilter(String? stageSlug) {
    if (stageSlug == null) {
      state = state.copyWith(clearStageFilter: true);
    } else {
      state = state.copyWith(stageFilter: stageSlug);
    }
  }

  void setTab(SbmsCommandTab tab) {
    state = state.copyWith(selectedTab: tab);
  }

  void selectDeal(String? dealId) {
    if (dealId == null) {
      state = state.copyWith(clearSelectedDeal: true);
    } else {
      state = state.copyWith(
        selectedDealId: dealId,
        selectedTab: SbmsCommandTab.deals,
      );
    }
  }

  void setMessage(String message) {
    state = state.copyWith(lastMessage: message);
  }

  void clearMessage() {
    state = state.copyWith(clearMessage: true);
  }

  Future<void> refresh() async {
    ref.invalidate(sbmsSnapshotProvider);
  }

  List<SbmsDeal> filteredDeals(SbmsCommandCenterSnapshot snap) {
    final q = state.searchQuery.trim().toLowerCase();
    return snap.deals.where((d) {
      if (state.stageFilter != null && d.stageSlug != state.stageFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return d.title.toLowerCase().contains(q) ||
          d.orderCode.toLowerCase().contains(q) ||
          (d.clientName?.toLowerCase().contains(q) ?? false) ||
          (d.stageName?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  List<SbmsReservation> filteredReservations(SbmsCommandCenterSnapshot snap) {
    final q = state.searchQuery.trim().toLowerCase();
    if (q.isEmpty) return snap.reservations;
    return snap.reservations.where((r) {
      return r.reservationCode.toLowerCase().contains(q) ||
          (r.clientName?.toLowerCase().contains(q) ?? false) ||
          (r.propertyLabel?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  SbmsDeal? selectedDeal(SbmsCommandCenterSnapshot snap) {
    final id = state.selectedDealId;
    if (id == null) {
      return snap.deals.isEmpty ? null : snap.deals.first;
    }
    for (final d in snap.deals) {
      if (d.id == id) return d;
    }
    return snap.deals.isEmpty ? null : snap.deals.first;
  }
}

final sbmsControllerProvider =
    NotifierProvider<SbmsController, SbmsUiState>(SbmsController.new);
