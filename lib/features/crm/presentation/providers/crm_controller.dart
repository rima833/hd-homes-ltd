import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/core/utils/provider_lifecycle.dart';
import 'package:hdhomesproject/features/crm/domain/entities/crm_models.dart';
import 'package:hdhomesproject/features/crm/domain/services/crm_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final crmServiceProvider = Provider<CrmService>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return CrmService(
    client: configured ? ref.watch(supabaseClientProvider) : null,
  );
});

final crmSnapshotProvider = FutureProvider<CrmCommandCenterSnapshot>((
  ref,
) async {
  return ref.watch(crmServiceProvider).loadCommandCenter();
});

final crmRealtimeStatusProvider = StateProvider<bool>((ref) => false);

/// Invalidates snapshot when CRM / inbound sales tables change.
final crmRealtimeProvider = Provider<void>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) {
    deferProviderMutation(
      () => ref.read(crmRealtimeStatusProvider.notifier).state = false,
    );
    return;
  }
  final client = ref.watch(supabaseClientProvider);
  void bump() =>
      deferProviderMutation(() => ref.invalidate(crmSnapshotProvider));

  final channel = client.channel('sales-command-center')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'crm_leads',
      callback: (_) => bump(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'crm_tasks',
      callback: (_) => bump(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'crm_clients',
      callback: (_) => bump(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'crm_activity_logs',
      callback: (_) => bump(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'crm_appointments',
      callback: (_) => bump(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'crm_notes',
      callback: (_) => bump(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'property_inspections',
      callback: (_) => bump(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'client_property_applications',
      callback: (_) => bump(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'client_documents',
      callback: (_) => bump(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'client_timeline',
      callback: (_) => bump(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'callback_requests',
      callback: (_) => bump(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'consultation_bookings',
      callback: (_) => bump(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'client_payment_intents',
      callback: (_) => bump(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'properties',
      callback: (_) => bump(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'clients',
      callback: (_) => bump(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'client_conversations',
      callback: (_) => bump(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'client_conversation_messages',
      callback: (_) => bump(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'payments',
      callback: (_) => bump(),
    )
    ..subscribe((status, [error]) {
      final live = status == RealtimeSubscribeStatus.subscribed;
      deferProviderMutation(
        () => ref.read(crmRealtimeStatusProvider.notifier).state = live,
      );
    });

  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
    deferProviderMutation(
      () => ref.read(crmRealtimeStatusProvider.notifier).state = false,
    );
  });
});

enum CrmCommandTab {
  overview,
  leads,
  pipeline,
  clients,
  properties,
  inspections,
  applications,
  calculator,
  payments,
  tasks,
  appointments,
  activity,
  analytics,
  client360;

  String get label => switch (this) {
    CrmCommandTab.overview => 'Overview',
    CrmCommandTab.leads => 'Leads',
    CrmCommandTab.pipeline => 'Pipeline',
    CrmCommandTab.clients => 'Clients',
    CrmCommandTab.properties => 'Properties',
    CrmCommandTab.inspections => 'Inspections',
    CrmCommandTab.applications => 'Applications',
    CrmCommandTab.calculator => 'Calculator',
    CrmCommandTab.payments => 'Payments',
    CrmCommandTab.tasks => 'Tasks',
    CrmCommandTab.appointments => 'Appointments',
    CrmCommandTab.activity => 'Activity',
    CrmCommandTab.analytics => 'Analytics',
    CrmCommandTab.client360 => '360°',
  };
}

enum CrmKpiFilter {
  none,
  newLeads,
  activePipeline,
  qualified,
  inspectionsToday,
  followUpsDue,
  activeClients,
  pipelineValue,
  conversion,
}

class CrmUiState {
  const CrmUiState({
    this.searchQuery = '',
    this.stageFilter,
    this.kpiFilter = CrmKpiFilter.none,
    this.selectedTab = CrmCommandTab.overview,
    this.selectedClientId,
    this.selectedLeadId,
    this.lastMessage,
  });

  final String searchQuery;
  final String? stageFilter;
  final CrmKpiFilter kpiFilter;
  final CrmCommandTab selectedTab;
  final String? selectedClientId;
  final String? selectedLeadId;
  final String? lastMessage;

  CrmUiState copyWith({
    String? searchQuery,
    String? stageFilter,
    bool clearStageFilter = false,
    CrmKpiFilter? kpiFilter,
    CrmCommandTab? selectedTab,
    String? selectedClientId,
    bool clearSelectedClient = false,
    String? selectedLeadId,
    bool clearSelectedLead = false,
    String? lastMessage,
    bool clearMessage = false,
  }) {
    return CrmUiState(
      searchQuery: searchQuery ?? this.searchQuery,
      stageFilter: clearStageFilter ? null : (stageFilter ?? this.stageFilter),
      kpiFilter: kpiFilter ?? this.kpiFilter,
      selectedTab: selectedTab ?? this.selectedTab,
      selectedClientId: clearSelectedClient
          ? null
          : (selectedClientId ?? this.selectedClientId),
      selectedLeadId: clearSelectedLead
          ? null
          : (selectedLeadId ?? this.selectedLeadId),
      lastMessage: clearMessage ? null : (lastMessage ?? this.lastMessage),
    );
  }
}

class CrmController extends Notifier<CrmUiState> {
  @override
  CrmUiState build() {
    ref.watch(crmRealtimeProvider);
    return const CrmUiState();
  }

  void setSearch(String query) => state = state.copyWith(searchQuery: query);

  void setStageFilter(String? stageSlug) {
    if (stageSlug == null) {
      state = state.copyWith(clearStageFilter: true);
    } else {
      state = state.copyWith(stageFilter: stageSlug);
    }
  }

  void applyKpi(CrmKpiFilter filter) {
    switch (filter) {
      case CrmKpiFilter.newLeads:
        state = state.copyWith(
          kpiFilter: filter,
          selectedTab: CrmCommandTab.leads,
          stageFilter: 'new',
        );
      case CrmKpiFilter.activePipeline:
        state = state.copyWith(
          kpiFilter: filter,
          selectedTab: CrmCommandTab.pipeline,
          clearStageFilter: true,
        );
      case CrmKpiFilter.qualified:
        state = state.copyWith(
          kpiFilter: filter,
          selectedTab: CrmCommandTab.leads,
          stageFilter: 'qualified',
        );
      case CrmKpiFilter.inspectionsToday:
        state = state.copyWith(
          kpiFilter: filter,
          selectedTab: CrmCommandTab.inspections,
          clearStageFilter: true,
        );
      case CrmKpiFilter.followUpsDue:
        state = state.copyWith(
          kpiFilter: filter,
          selectedTab: CrmCommandTab.tasks,
          clearStageFilter: true,
        );
      case CrmKpiFilter.activeClients:
        state = state.copyWith(
          kpiFilter: filter,
          selectedTab: CrmCommandTab.clients,
          clearStageFilter: true,
        );
      case CrmKpiFilter.pipelineValue:
        state = state.copyWith(
          kpiFilter: filter,
          selectedTab: CrmCommandTab.pipeline,
          clearStageFilter: true,
        );
      case CrmKpiFilter.conversion:
        state = state.copyWith(
          kpiFilter: filter,
          selectedTab: CrmCommandTab.analytics,
          clearStageFilter: true,
        );
      case CrmKpiFilter.none:
        state = state.copyWith(kpiFilter: CrmKpiFilter.none);
    }
  }

  void setTab(CrmCommandTab tab) => state = state.copyWith(selectedTab: tab);

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

  void selectLead(String? leadId) {
    if (leadId == null) {
      state = state.copyWith(clearSelectedLead: true);
    } else {
      state = state.copyWith(selectedLeadId: leadId);
    }
  }

  void setMessage(String message) =>
      state = state.copyWith(lastMessage: message);

  void clearMessage() => state = state.copyWith(clearMessage: true);

  Future<void> refresh() async => ref.invalidate(crmSnapshotProvider);

  Future<void> afterMutation([String? message]) async {
    ref.invalidate(crmSnapshotProvider);
    if (message != null) setMessage(message);
  }

  List<CrmLead> filteredLeads(CrmCommandCenterSnapshot snap) {
    final q = state.searchQuery.trim().toLowerCase();
    final now = DateTime.now();
    return snap.leads.where((lead) {
      if (state.stageFilter != null && lead.stageSlug != state.stageFilter) {
        return false;
      }
      if (state.kpiFilter == CrmKpiFilter.newLeads && lead.stageSlug != 'new') {
        return false;
      }
      if (state.kpiFilter == CrmKpiFilter.qualified &&
          lead.stageSlug != 'qualified' &&
          lead.stageSlug != 'property_matched') {
        return false;
      }
      if (state.kpiFilter == CrmKpiFilter.activePipeline &&
          (lead.status == CrmLeadStatus.won ||
              lead.status == CrmLeadStatus.lost)) {
        return false;
      }
      if (q.isEmpty) return true;
      return lead.title.toLowerCase().contains(q) ||
          (lead.clientName?.toLowerCase().contains(q) ?? false) ||
          (lead.stageName?.toLowerCase().contains(q) ?? false) ||
          (lead.sourceName?.toLowerCase().contains(q) ?? false) ||
          (lead.notes?.toLowerCase().contains(q) ?? false) ||
          (lead.propertyTitle?.toLowerCase().contains(q) ?? false) ||
          lead.id.toLowerCase().contains(q) ||
          now.year > 0;
    }).toList();
  }

  List<CrmClient> filteredClients(CrmCommandCenterSnapshot snap) {
    final q = state.searchQuery.trim().toLowerCase();
    var list = snap.clients;
    if (state.kpiFilter == CrmKpiFilter.activeClients) {
      list = list
          .where(
            (c) =>
                c.relationshipStatus == CrmRelationshipStatus.activeBuyer ||
                c.relationshipStatus == CrmRelationshipStatus.prospect ||
                c.relationshipStatus == CrmRelationshipStatus.vip,
          )
          .toList();
    }
    if (q.isEmpty) return list;
    return list.where((c) {
      return c.fullName.toLowerCase().contains(q) ||
          c.clientCode.toLowerCase().contains(q) ||
          (c.email?.toLowerCase().contains(q) ?? false) ||
          (c.phone?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  CrmClient? selectedClient(CrmCommandCenterSnapshot snap) {
    final id = state.selectedClientId;
    if (id == null) return null;
    for (final c in snap.clients) {
      if (c.id == id) return c;
    }
    return null;
  }

  CrmLead? selectedLead(CrmCommandCenterSnapshot snap) {
    final id = state.selectedLeadId;
    if (id == null) return null;
    for (final l in snap.leads) {
      if (l.id == id) return l;
    }
    return null;
  }
}

final crmControllerProvider = NotifierProvider<CrmController, CrmUiState>(
  CrmController.new,
);
