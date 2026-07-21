import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/crm/domain/entities/crm_models.dart';
import 'package:hdhomesproject/features/crm/domain/services/crm_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final crmServiceProvider = Provider<CrmService>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return CrmService(
    client: configured ? ref.watch(supabaseClientProvider) : null,
  );
});

final crmSnapshotProvider =
    FutureProvider<CrmCommandCenterSnapshot>((ref) async {
  return ref.watch(crmServiceProvider).loadCommandCenter();
});

/// Invalidates snapshot when CRM live tables change (after SQL apply + Realtime).
final crmRealtimeProvider = Provider<void>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = ref.watch(supabaseClientProvider);
  final channel = client.channel('crm-command-center')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'crm_leads',
      callback: (_) => ref.invalidate(crmSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'crm_tasks',
      callback: (_) => ref.invalidate(crmSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'crm_clients',
      callback: (_) => ref.invalidate(crmSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'crm_activity_logs',
      callback: (_) => ref.invalidate(crmSnapshotProvider),
    )
    ..subscribe();

  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

enum CrmCommandTab {
  pipeline,
  leads,
  tasks,
  appointments,
  timeline,
  ai,
  graph,
  client360;

  String get label => switch (this) {
        CrmCommandTab.pipeline => 'Pipeline',
        CrmCommandTab.leads => 'Leads',
        CrmCommandTab.tasks => 'Tasks',
        CrmCommandTab.appointments => 'Appointments',
        CrmCommandTab.timeline => 'Timeline',
        CrmCommandTab.ai => 'AI Assistant',
        CrmCommandTab.graph => 'Rel. Graph',
        CrmCommandTab.client360 => '360° Client',
      };
}

class CrmUiState {
  const CrmUiState({
    this.searchQuery = '',
    this.stageFilter,
    this.selectedTab = CrmCommandTab.pipeline,
    this.selectedClientId,
    this.lastMessage,
    this.tickerIndex = 0,
  });

  final String searchQuery;
  final String? stageFilter;
  final CrmCommandTab selectedTab;
  final String? selectedClientId;
  final String? lastMessage;
  final int tickerIndex;

  CrmUiState copyWith({
    String? searchQuery,
    String? stageFilter,
    bool clearStageFilter = false,
    CrmCommandTab? selectedTab,
    String? selectedClientId,
    bool clearSelectedClient = false,
    String? lastMessage,
    bool clearMessage = false,
    int? tickerIndex,
  }) {
    return CrmUiState(
      searchQuery: searchQuery ?? this.searchQuery,
      stageFilter:
          clearStageFilter ? null : (stageFilter ?? this.stageFilter),
      selectedTab: selectedTab ?? this.selectedTab,
      selectedClientId: clearSelectedClient
          ? null
          : (selectedClientId ?? this.selectedClientId),
      lastMessage: clearMessage ? null : (lastMessage ?? this.lastMessage),
      tickerIndex: tickerIndex ?? this.tickerIndex,
    );
  }
}

class CrmController extends Notifier<CrmUiState> {
  Timer? _tickerTimer;

  @override
  CrmUiState build() {
    ref.onDispose(() => _tickerTimer?.cancel());
    ref.watch(crmRealtimeProvider);
    _armTicker();
    return const CrmUiState();
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

  void setTab(CrmCommandTab tab) {
    state = state.copyWith(selectedTab: tab);
  }

  void selectClient(String? clientId) {
    if (clientId == null) {
      state = state.copyWith(clearSelectedClient: true);
    } else {
      state = state.copyWith(
        selectedClientId: clientId,
        selectedTab: CrmCommandTab.client360,
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
    ref.invalidate(crmSnapshotProvider);
  }

  List<CrmLead> filteredLeads(CrmCommandCenterSnapshot snap) {
    final q = state.searchQuery.trim().toLowerCase();
    return snap.leads.where((lead) {
      if (state.stageFilter != null && lead.stageSlug != state.stageFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return lead.title.toLowerCase().contains(q) ||
          (lead.clientName?.toLowerCase().contains(q) ?? false) ||
          (lead.stageName?.toLowerCase().contains(q) ?? false) ||
          (lead.sourceName?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  List<CrmClient> filteredClients(CrmCommandCenterSnapshot snap) {
    final q = state.searchQuery.trim().toLowerCase();
    if (q.isEmpty) return snap.clients;
    return snap.clients.where((c) {
      return c.fullName.toLowerCase().contains(q) ||
          c.clientCode.toLowerCase().contains(q) ||
          (c.email?.toLowerCase().contains(q) ?? false) ||
          c.tags.any((t) => t.toLowerCase().contains(q));
    }).toList();
  }

  CrmClient? selectedClient(CrmCommandCenterSnapshot snap) {
    final id = state.selectedClientId;
    if (id == null) {
      return snap.clients.isEmpty ? null : snap.clients.first;
    }
    for (final c in snap.clients) {
      if (c.id == id) return c;
    }
    return snap.clients.isEmpty ? null : snap.clients.first;
  }
}

final crmControllerProvider =
    NotifierProvider<CrmController, CrmUiState>(CrmController.new);
