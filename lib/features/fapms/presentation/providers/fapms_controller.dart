import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/fapms/domain/entities/fapms_models.dart';
import 'package:hdhomesproject/features/fapms/domain/services/fapms_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final fapmsServiceProvider = Provider<FapmsService>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return FapmsService(
    client: configured ? ref.watch(supabaseClientProvider) : null,
  );
});

final fapmsSnapshotProvider =
    FutureProvider<FapmsCommandCenterSnapshot>((ref) async {
  return ref.watch(fapmsServiceProvider).loadCommandCenter();
});

/// Invalidates snapshot when FAPMS live tables change (after SQL apply + Realtime).
final fapmsRealtimeProvider = Provider<void>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = ref.watch(supabaseClientProvider);
  final channel = client.channel('fapms-command-center')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'invoices',
      callback: (_) => ref.invalidate(fapmsSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'payments',
      callback: (_) => ref.invalidate(fapmsSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'payment_transactions',
      callback: (_) => ref.invalidate(fapmsSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'expenses',
      callback: (_) => ref.invalidate(fapmsSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'budgets',
      callback: (_) => ref.invalidate(fapmsSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'bank_transactions',
      callback: (_) => ref.invalidate(fapmsSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'journal_entries',
      callback: (_) => ref.invalidate(fapmsSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'finance_activity_logs',
      callback: (_) => ref.invalidate(fapmsSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'finance_notifications',
      callback: (_) => ref.invalidate(fapmsSnapshotProvider),
    )
    ..subscribe();

  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

enum FapmsCommandTab {
  overview,
  ledger,
  ar,
  ap,
  invoices,
  payments,
  banking,
  budgets,
  expenses,
  approvals,
  ai;

  String get label => switch (this) {
        FapmsCommandTab.overview => 'Overview',
        FapmsCommandTab.ledger => 'Ledger',
        FapmsCommandTab.ar => 'AR',
        FapmsCommandTab.ap => 'AP',
        FapmsCommandTab.invoices => 'Invoices',
        FapmsCommandTab.payments => 'Payments',
        FapmsCommandTab.banking => 'Banking',
        FapmsCommandTab.budgets => 'Budgets',
        FapmsCommandTab.expenses => 'Expenses',
        FapmsCommandTab.approvals => 'Approvals',
        FapmsCommandTab.ai => 'AI / CFO',
      };
}

class FapmsUiState {
  const FapmsUiState({
    this.searchQuery = '',
    this.statusFilter,
    this.selectedTab = FapmsCommandTab.overview,
    this.lastMessage,
    this.tickerIndex = 0,
  });

  final String searchQuery;
  final String? statusFilter;
  final FapmsCommandTab selectedTab;
  final String? lastMessage;
  final int tickerIndex;

  FapmsUiState copyWith({
    String? searchQuery,
    String? statusFilter,
    bool clearStatusFilter = false,
    FapmsCommandTab? selectedTab,
    String? lastMessage,
    bool clearMessage = false,
    int? tickerIndex,
  }) {
    return FapmsUiState(
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter:
          clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
      selectedTab: selectedTab ?? this.selectedTab,
      lastMessage: clearMessage ? null : (lastMessage ?? this.lastMessage),
      tickerIndex: tickerIndex ?? this.tickerIndex,
    );
  }
}

class FapmsController extends Notifier<FapmsUiState> {
  Timer? _tickerTimer;

  @override
  FapmsUiState build() {
    // CRITICAL: never read `state` here — arm ticker from initial constants only.
    ref.onDispose(() => _tickerTimer?.cancel());
    ref.watch(fapmsRealtimeProvider);
    _armTicker();
    return const FapmsUiState();
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

  void setTab(FapmsCommandTab tab) {
    state = state.copyWith(selectedTab: tab);
  }

  void setMessage(String message) {
    state = state.copyWith(lastMessage: message);
  }

  void clearMessage() {
    state = state.copyWith(clearMessage: true);
  }

  Future<void> refresh() async {
    ref.invalidate(fapmsSnapshotProvider);
  }

  List<FapmsInvoice> filteredInvoices(FapmsCommandCenterSnapshot snap) {
    final q = state.searchQuery.trim().toLowerCase();
    return snap.invoices.where((inv) {
      if (state.statusFilter != null && inv.status.slug != state.statusFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return inv.invoiceNumber.toLowerCase().contains(q) ||
          inv.partyName.toLowerCase().contains(q);
    }).toList();
  }

  List<FapmsExpense> filteredExpenses(FapmsCommandCenterSnapshot snap) {
    final q = state.searchQuery.trim().toLowerCase();
    return snap.expenses.where((e) {
      if (state.statusFilter != null && e.status.slug != state.statusFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return e.expenseCode.toLowerCase().contains(q) ||
          e.title.toLowerCase().contains(q) ||
          (e.vendorLabel?.toLowerCase().contains(q) ?? false);
    }).toList();
  }
}

final fapmsControllerProvider =
    NotifierProvider<FapmsController, FapmsUiState>(FapmsController.new);
