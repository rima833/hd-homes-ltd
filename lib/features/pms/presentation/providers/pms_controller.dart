import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/pms/domain/entities/pms_models.dart';
import 'package:hdhomesproject/features/pms/domain/services/pms_service.dart';
import 'package:hdhomesproject/features/pms/domain/services/property_wizard_persistence.dart';
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
    this.wizardSubmitting = false,
  });

  final String searchQuery;
  final InventoryStatus? statusFilter;
  final PmsCommandTab selectedTab;
  final PmsWizardDraft wizardDraft;
  final Set<String> selectedPropertyIds;
  final String? lastMessage;
  final int tickerIndex;
  final bool wizardSubmitting;

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
    bool? wizardSubmitting,
  }) {
    return PmsUiState(
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: clearFilter ? null : (statusFilter ?? this.statusFilter),
      selectedTab: selectedTab ?? this.selectedTab,
      wizardDraft: wizardDraft ?? this.wizardDraft,
      selectedPropertyIds: selectedPropertyIds ?? this.selectedPropertyIds,
      lastMessage: clearMessage ? null : (lastMessage ?? this.lastMessage),
      tickerIndex: tickerIndex ?? this.tickerIndex,
      wizardSubmitting: wizardSubmitting ?? this.wizardSubmitting,
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

  Future<void> submitWizardDraft() async {
    if (state.wizardSubmitting) return;
    final draft = state.wizardDraft;
    final title =
        draft.title.trim().isEmpty ? 'Untitled property' : draft.title.trim();
    state = state.copyWith(wizardSubmitting: true, clearMessage: true);
    try {
      final cms = ref.read(cmsServiceProvider);
      final created = await persistWizardDraft(cms: cms, draft: draft);
      final published = created.isPublished;
      state = state.copyWith(
        wizardSubmitting: false,
        lastMessage: published
            ? 'Published “${created.title}” — live on /properties'
            : 'Saved “${created.title}” as draft in Listings',
        wizardDraft: const PmsWizardDraft(),
        selectedTab: PmsCommandTab.inventory,
      );
      ref.invalidate(pmsSnapshotProvider);
      ref.invalidate(cmsFeaturedPropertiesProvider(null));
      ref.invalidate(publishedFeaturedPropertiesProvider);
      ref.invalidate(publishedPropertiesCatalogProvider);
    } catch (e) {
      state = state.copyWith(
        wizardSubmitting: false,
        lastMessage: 'Could not save “$title”: $e',
      );
    }
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

  Future<void> publishSelected() async {
    final ids = state.selectedPropertyIds.toList();
    if (ids.isEmpty) return;
    final cms = ref.read(cmsServiceProvider);
    try {
      for (final id in ids) {
        await cms.setPropertyPublished(id, true);
      }
      state = state.copyWith(
        selectedPropertyIds: {},
        lastMessage:
            'Published ${ids.length} ${ids.length == 1 ? 'listing' : 'listings'}.',
      );
      ref.invalidate(pmsSnapshotProvider);
      ref.invalidate(cmsFeaturedPropertiesProvider(null));
      ref.invalidate(publishedFeaturedPropertiesProvider);
      ref.invalidate(publishedPropertiesCatalogProvider);
    } catch (error) {
      state = state.copyWith(
        lastMessage: 'Could not publish the selection: $error',
      );
    }
  }

  Future<void> archiveSelected() async {
    final ids = state.selectedPropertyIds.toList();
    if (ids.isEmpty) return;
    final cms = ref.read(cmsServiceProvider);
    try {
      for (final id in ids) {
        await cms.archiveProperty(id);
      }
      state = state.copyWith(
        selectedPropertyIds: {},
        lastMessage:
            'Archived ${ids.length} ${ids.length == 1 ? 'listing' : 'listings'}. They are off the public site.',
      );
      ref.invalidate(pmsSnapshotProvider);
      ref.invalidate(cmsFeaturedPropertiesProvider(null));
      ref.invalidate(publishedFeaturedPropertiesProvider);
      ref.invalidate(publishedPropertiesCatalogProvider);
    } catch (error) {
      state = state.copyWith(
        lastMessage: 'Could not archive the selection: $error',
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
