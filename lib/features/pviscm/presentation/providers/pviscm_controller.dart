import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/pviscm/domain/entities/pviscm_models.dart';
import 'package:hdhomesproject/features/pviscm/domain/services/pviscm_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final pviscmServiceProvider = Provider<PviscmService>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return PviscmService(
    client: configured ? ref.watch(supabaseClientProvider) : null,
  );
});

final pviscmSnapshotProvider =
    FutureProvider<PviscmCommandCenterSnapshot>((ref) async {
  return ref.watch(pviscmServiceProvider).loadCommandCenter();
});

/// Invalidates snapshot when PVISCM live tables change (after SQL apply + Realtime).
final pviscmRealtimeProvider = Provider<void>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = ref.watch(supabaseClientProvider);
  final channel = client.channel('pviscm-command-center')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'purchase_requisitions',
      callback: (_) => ref.invalidate(pviscmSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'purchase_orders',
      callback: (_) => ref.invalidate(pviscmSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'goods_receipts',
      callback: (_) => ref.invalidate(pviscmSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'inventory_transactions',
      callback: (_) => ref.invalidate(pviscmSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'procurement_approvals',
      callback: (_) => ref.invalidate(pviscmSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'procurement_activity_logs',
      callback: (_) => ref.invalidate(pviscmSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'procurement_notifications',
      callback: (_) => ref.invalidate(pviscmSnapshotProvider),
    )
    ..subscribe();

  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

enum PviscmCommandTab {
  overview,
  vendors,
  requisitions,
  rfqs,
  purchaseOrders,
  receiving,
  inventory,
  warehouses,
  logistics,
  approvals,
  analytics,
  ai;

  String get label => switch (this) {
        PviscmCommandTab.overview => 'Overview',
        PviscmCommandTab.vendors => 'Vendors',
        PviscmCommandTab.requisitions => 'Requisitions',
        PviscmCommandTab.rfqs => 'RFQs',
        PviscmCommandTab.purchaseOrders => 'Purchase Orders',
        PviscmCommandTab.receiving => 'Receiving',
        PviscmCommandTab.inventory => 'Inventory',
        PviscmCommandTab.warehouses => 'Warehouses',
        PviscmCommandTab.logistics => 'Logistics',
        PviscmCommandTab.approvals => 'Approvals',
        PviscmCommandTab.analytics => 'Analytics',
        PviscmCommandTab.ai => 'AI',
      };
}

class PviscmUiState {
  const PviscmUiState({
    this.searchQuery = '',
    this.statusFilter,
    this.categoryFilter,
    this.selectedTab = PviscmCommandTab.overview,
    this.lastMessage,
    this.tickerIndex = 0,
  });

  final String searchQuery;
  final String? statusFilter;
  final String? categoryFilter;
  final PviscmCommandTab selectedTab;
  final String? lastMessage;
  final int tickerIndex;

  PviscmUiState copyWith({
    String? searchQuery,
    String? statusFilter,
    bool clearStatusFilter = false,
    String? categoryFilter,
    bool clearCategoryFilter = false,
    PviscmCommandTab? selectedTab,
    String? lastMessage,
    bool clearMessage = false,
    int? tickerIndex,
  }) {
    return PviscmUiState(
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter:
          clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
      categoryFilter:
          clearCategoryFilter ? null : (categoryFilter ?? this.categoryFilter),
      selectedTab: selectedTab ?? this.selectedTab,
      lastMessage: clearMessage ? null : (lastMessage ?? this.lastMessage),
      tickerIndex: tickerIndex ?? this.tickerIndex,
    );
  }
}

class PviscmController extends Notifier<PviscmUiState> {
  Timer? _tickerTimer;

  @override
  PviscmUiState build() {
    // CRITICAL: never read `state` here — arm ticker from initial constants only.
    ref.onDispose(() => _tickerTimer?.cancel());
    ref.watch(pviscmRealtimeProvider);
    _armTicker();
    return const PviscmUiState();
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

  void setCategoryFilter(String? category) {
    if (category == null) {
      state = state.copyWith(clearCategoryFilter: true);
    } else {
      state = state.copyWith(categoryFilter: category);
    }
  }

  void setTab(PviscmCommandTab tab) {
    state = state.copyWith(selectedTab: tab);
  }

  void setMessage(String message) {
    state = state.copyWith(lastMessage: message);
  }

  void clearMessage() {
    state = state.copyWith(clearMessage: true);
  }

  Future<void> refresh() async {
    ref.invalidate(pviscmSnapshotProvider);
  }

  List<PviscmVendor> filteredVendors(PviscmCommandCenterSnapshot snap) {
    final q = state.searchQuery.trim().toLowerCase();
    return snap.vendors.where((v) {
      if (state.statusFilter != null && v.status != state.statusFilter) {
        return false;
      }
      if (state.categoryFilter != null && v.category != state.categoryFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return v.name.toLowerCase().contains(q) ||
          (v.code?.toLowerCase().contains(q) ?? false) ||
          (v.city?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  List<PviscmRequisition> filteredRequisitions(
    PviscmCommandCenterSnapshot snap,
  ) {
    final q = state.searchQuery.trim().toLowerCase();
    return snap.requisitions.where((r) {
      if (state.statusFilter != null && r.status != state.statusFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return r.title.toLowerCase().contains(q) ||
          (r.code?.toLowerCase().contains(q) ?? false) ||
          (r.requesterLabel?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  List<PviscmPurchaseOrder> filteredPurchaseOrders(
    PviscmCommandCenterSnapshot snap,
  ) {
    final q = state.searchQuery.trim().toLowerCase();
    return snap.purchaseOrders.where((p) {
      if (state.statusFilter != null && p.status != state.statusFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return p.title.toLowerCase().contains(q) ||
          (p.code?.toLowerCase().contains(q) ?? false) ||
          (p.vendorName?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  List<PviscmInventoryItem> filteredInventory(
    PviscmCommandCenterSnapshot snap,
  ) {
    final q = state.searchQuery.trim().toLowerCase();
    return snap.inventory.where((i) {
      if (state.statusFilter != null && i.status != state.statusFilter) {
        return false;
      }
      if (state.categoryFilter != null && i.category != state.categoryFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return i.name.toLowerCase().contains(q) ||
          (i.sku?.toLowerCase().contains(q) ?? false);
    }).toList();
  }
}

final pviscmControllerProvider =
    NotifierProvider<PviscmController, PviscmUiState>(PviscmController.new);
