import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/pms/domain/entities/pms_models.dart';
import 'package:hdhomesproject/features/pms/domain/services/pms_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final pmsServiceProvider = Provider<PmsService>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return PmsService(
    client: configured ? ref.watch(supabaseClientProvider) : null,
  );
});

final pmsSnapshotProvider = FutureProvider<PmsCommandCenterSnapshot>((ref) async {
  return ref.watch(pmsServiceProvider).loadCommandCenter();
});

/// Invalidates snapshot when PMS live tables change (after SQL apply + Realtime).
final pmsRealtimeProvider = Provider<void>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = ref.watch(supabaseClientProvider);
  final channel = client.channel('property-command-center')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'properties',
      callback: (_) => ref.invalidate(pmsSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'property_inspections',
      callback: (_) => ref.invalidate(pmsSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'property_lifecycle_events',
      callback: (_) => ref.invalidate(pmsSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'property_approvals',
      callback: (_) => ref.invalidate(pmsSnapshotProvider),
    )
    ..subscribe();

  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

enum PmsCommandTab {
  inventory,
  wizard,
  twin,
  analytics,
  approvals;

  String get label => switch (this) {
        PmsCommandTab.inventory => 'Inventory',
        PmsCommandTab.wizard => 'Create',
        PmsCommandTab.twin => 'Digital Twin',
        PmsCommandTab.analytics => 'Intelligence',
        PmsCommandTab.approvals => 'Approvals',
      };
}

class PmsUiState {
  const PmsUiState({
    this.searchQuery = '',
    this.statusFilter,
    this.selectedTab = PmsCommandTab.inventory,
    this.wizardDraft = const PmsWizardDraft(),
    this.selectedPropertyIds = const {},
    this.lastMessage,
    this.tickerIndex = 0,
  });

  final String searchQuery;
  final InventoryStatus? statusFilter;
  final PmsCommandTab selectedTab;
  final PmsWizardDraft wizardDraft;
  final Set<String> selectedPropertyIds;
  final String? lastMessage;
  final int tickerIndex;

  PmsUiState copyWith({
    String? searchQuery,
    InventoryStatus? statusFilter,
    bool clearFilter = false,
    PmsCommandTab? selectedTab,
    PmsWizardDraft? wizardDraft,
    Set<String>? selectedPropertyIds,
    String? lastMessage,
    bool clearMessage = false,
    int? tickerIndex,
  }) {
    return PmsUiState(
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: clearFilter ? null : (statusFilter ?? this.statusFilter),
      selectedTab: selectedTab ?? this.selectedTab,
      wizardDraft: wizardDraft ?? this.wizardDraft,
      selectedPropertyIds: selectedPropertyIds ?? this.selectedPropertyIds,
      lastMessage: clearMessage ? null : (lastMessage ?? this.lastMessage),
      tickerIndex: tickerIndex ?? this.tickerIndex,
    );
  }
}

class PmsController extends Notifier<PmsUiState> {
  Timer? _tickerTimer;

  @override
  PmsUiState build() {
    ref.onDispose(() => _tickerTimer?.cancel());
    ref.watch(pmsRealtimeProvider);
    _armTicker();
    return const PmsUiState();
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

  void setFilter(InventoryStatus? status) {
    if (status == null) {
      state = state.copyWith(clearFilter: true);
    } else {
      state = state.copyWith(statusFilter: status);
    }
  }

  void setTab(PmsCommandTab tab) {
    state = state.copyWith(selectedTab: tab);
  }

  void updateWizardStep(PmsWizardDraft draft) {
    state = state.copyWith(wizardDraft: draft);
  }

  void submitWizardDraft() {
    final draft = state.wizardDraft;
    final title = draft.title.trim().isEmpty ? 'Untitled property' : draft.title.trim();
    state = state.copyWith(
      lastMessage:
          'Queued “$title” — apply PMS SQL for persistence',
      wizardDraft: const PmsWizardDraft(),
      selectedTab: PmsCommandTab.inventory,
    );
  }

  void toggleSelect(String propertyId) {
    final next = {...state.selectedPropertyIds};
    if (next.contains(propertyId)) {
      next.remove(propertyId);
    } else {
      next.add(propertyId);
    }
    state = state.copyWith(selectedPropertyIds: next);
  }

  void clearSelection() {
    state = state.copyWith(selectedPropertyIds: {});
  }

  void setMessage(String message) {
    state = state.copyWith(lastMessage: message);
  }

  void clearMessage() {
    state = state.copyWith(clearMessage: true);
  }

  Future<void> refresh() async {
    ref.invalidate(pmsSnapshotProvider);
  }

  List<PmsProperty> filteredProperties(PmsCommandCenterSnapshot snap) {
    final q = state.searchQuery.trim().toLowerCase();
    return snap.properties.where((p) {
      if (state.statusFilter != null &&
          p.inventoryStatus != state.statusFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return p.title.toLowerCase().contains(q) ||
          (p.propertyCode?.toLowerCase().contains(q) ?? false) ||
          (p.city?.toLowerCase().contains(q) ?? false) ||
          (p.estateName?.toLowerCase().contains(q) ?? false) ||
          p.tags.any((t) => t.toLowerCase().contains(q));
    }).toList();
  }
}

final pmsControllerProvider =
    NotifierProvider<PmsController, PmsUiState>(PmsController.new);
