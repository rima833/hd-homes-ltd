import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/imp/domain/entities/imp_models.dart';
import 'package:hdhomesproject/features/imp/domain/services/imp_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final impServiceProvider = Provider<ImpService>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return ImpService(
    client: configured ? ref.watch(supabaseClientProvider) : null,
  );
});

final impSnapshotProvider =
    FutureProvider<ImpCommandCenterSnapshot>((ref) async {
  return ref.watch(impServiceProvider).loadCommandCenter();
});

/// Invalidates snapshot when IMP live tables change (after SQL apply + Realtime).
final impRealtimeProvider = Provider<void>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = ref.watch(supabaseClientProvider);
  final channel = client.channel('imp-command-center')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'investors',
      callback: (_) => ref.invalidate(impSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'investment_opportunities',
      callback: (_) => ref.invalidate(impSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'investment_commitments',
      callback: (_) => ref.invalidate(impSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'investment_distributions',
      callback: (_) => ref.invalidate(impSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'investor_activity_logs',
      callback: (_) => ref.invalidate(impSnapshotProvider),
    )
    ..subscribe();

  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

enum ImpCommandTab {
  overview,
  investors,
  opportunities,
  portfolio,
  distributions,
  alerts,
  ai,
  investor360;

  String get label => switch (this) {
        ImpCommandTab.overview => 'Overview',
        ImpCommandTab.investors => 'Investors',
        ImpCommandTab.opportunities => 'Capital Raise',
        ImpCommandTab.portfolio => 'Portfolio',
        ImpCommandTab.distributions => 'Distributions',
        ImpCommandTab.alerts => 'Alerts',
        ImpCommandTab.ai => 'AI Assistant',
        ImpCommandTab.investor360 => '360° Investor',
      };
}

class ImpUiState {
  const ImpUiState({
    this.searchQuery = '',
    this.typeFilter,
    this.selectedTab = ImpCommandTab.overview,
    this.selectedInvestorId,
    this.lastMessage,
    this.tickerIndex = 0,
  });

  final String searchQuery;
  final String? typeFilter;
  final ImpCommandTab selectedTab;
  final String? selectedInvestorId;
  final String? lastMessage;
  final int tickerIndex;

  ImpUiState copyWith({
    String? searchQuery,
    String? typeFilter,
    bool clearTypeFilter = false,
    ImpCommandTab? selectedTab,
    String? selectedInvestorId,
    bool clearSelectedInvestor = false,
    String? lastMessage,
    bool clearMessage = false,
    int? tickerIndex,
  }) {
    return ImpUiState(
      searchQuery: searchQuery ?? this.searchQuery,
      typeFilter: clearTypeFilter ? null : (typeFilter ?? this.typeFilter),
      selectedTab: selectedTab ?? this.selectedTab,
      selectedInvestorId: clearSelectedInvestor
          ? null
          : (selectedInvestorId ?? this.selectedInvestorId),
      lastMessage: clearMessage ? null : (lastMessage ?? this.lastMessage),
      tickerIndex: tickerIndex ?? this.tickerIndex,
    );
  }
}

class ImpController extends Notifier<ImpUiState> {
  Timer? _tickerTimer;

  @override
  ImpUiState build() {
    ref.onDispose(() => _tickerTimer?.cancel());
    ref.watch(impRealtimeProvider);
    _armTicker();
    return const ImpUiState();
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

  void setTypeFilter(String? typeSlug) {
    if (typeSlug == null) {
      state = state.copyWith(clearTypeFilter: true);
    } else {
      state = state.copyWith(typeFilter: typeSlug);
    }
  }

  void setTab(ImpCommandTab tab) {
    state = state.copyWith(selectedTab: tab);
  }

  void selectInvestor(String? investorId) {
    if (investorId == null) {
      state = state.copyWith(clearSelectedInvestor: true);
    } else {
      state = state.copyWith(
        selectedInvestorId: investorId,
        selectedTab: ImpCommandTab.investor360,
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
    ref.invalidate(impSnapshotProvider);
  }

  List<ImpInvestor> filteredInvestors(ImpCommandCenterSnapshot snap) {
    final q = state.searchQuery.trim().toLowerCase();
    return snap.investors.where((inv) {
      if (state.typeFilter != null && inv.investorType.slug != state.typeFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return inv.fullName.toLowerCase().contains(q) ||
          inv.investorCode.toLowerCase().contains(q) ||
          (inv.email?.toLowerCase().contains(q) ?? false) ||
          (inv.company?.toLowerCase().contains(q) ?? false) ||
          inv.tags.any((t) => t.toLowerCase().contains(q));
    }).toList();
  }

  List<ImpOpportunity> filteredOpportunities(ImpCommandCenterSnapshot snap) {
    final q = state.searchQuery.trim().toLowerCase();
    if (q.isEmpty) return snap.opportunities;
    return snap.opportunities.where((o) {
      return o.title.toLowerCase().contains(q) ||
          o.code.toLowerCase().contains(q) ||
          (o.description?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  ImpInvestor? selectedInvestor(ImpCommandCenterSnapshot snap) {
    final id = state.selectedInvestorId;
    if (id == null) {
      return snap.investors.isEmpty ? null : snap.investors.first;
    }
    for (final inv in snap.investors) {
      if (inv.id == id) return inv;
    }
    return snap.investors.isEmpty ? null : snap.investors.first;
  }
}

final impControllerProvider =
    NotifierProvider<ImpController, ImpUiState>(ImpController.new);
