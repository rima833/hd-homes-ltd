import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/core/utils/provider_lifecycle.dart';
import 'package:hdhomesproject/features/client_ops/domain/entities/client_ops_models.dart';
import 'package:hdhomesproject/features/client_ops/domain/services/client_ops_service.dart';
import 'package:hdhomesproject/features/crm/presentation/providers/crm_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final clientOpsServiceProvider = Provider<ClientOpsService>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return ClientOpsService(
    client: configured ? ref.watch(supabaseClientProvider) : null,
  );
});

final clientOpsDeskKpisProvider = FutureProvider<ClientDeskKpis>((ref) {
  return ref.watch(clientOpsServiceProvider).loadDeskKpis();
});

final clientOpsWorkQueuesProvider = FutureProvider<ClientOpsWorkQueues>((ref) {
  return ref.watch(clientOpsServiceProvider).loadWorkQueues();
});

typedef ClientOpsDirectoryQuery = ({
  String search,
  String? relationshipStatus,
  String? customerType,
  String? assignedStaffId,
  bool unassignedOnly,
  bool portalOnly,
  int limit,
  int offset,
});

final clientOpsDirectoryProvider =
    FutureProvider.family<ClientOpsPage, ClientOpsDirectoryQuery>((
      ref,
      query,
    ) {
      return ref
          .watch(clientOpsServiceProvider)
          .listClientsPage(
            search: query.search.isEmpty ? null : query.search,
            relationshipStatus: query.relationshipStatus,
            customerType: query.customerType,
            assignedStaffId: query.assignedStaffId,
            unassignedOnly: query.unassignedOnly,
            portalOnly: query.portalOnly,
            limit: query.limit,
            offset: query.offset,
          );
    });

final clientOpsDetailProvider =
    FutureProvider.family<ClientOpsDetail, String>((ref, clientId) {
      return ref.watch(clientOpsServiceProvider).loadClient360(clientId);
    });

final clientOpsManagersProvider =
    FutureProvider<List<ClientOpsStaffOption>>((ref) {
      return ref.watch(clientOpsServiceProvider).listManagers();
    });

enum ClientOpsTab { overview, directory, queues, detail }

extension ClientOpsTabX on ClientOpsTab {
  String get label => switch (this) {
    ClientOpsTab.overview => 'Overview',
    ClientOpsTab.directory => 'Directory',
    ClientOpsTab.queues => 'Work Queues',
    ClientOpsTab.detail => 'Client 360',
  };
}

class ClientOpsUiState {
  const ClientOpsUiState({
    this.selectedTab = ClientOpsTab.overview,
    this.search = '',
    this.relationshipStatus,
    this.customerType,
    this.assignedStaffId,
    this.unassignedOnly = false,
    this.portalOnly = false,
    this.limit = 25,
    this.offset = 0,
    this.selectedClientId,
    this.previewClientId,
    this.message,
    this.error,
    this.tickerIndex = 0,
  });

  final ClientOpsTab selectedTab;
  final String search;
  final String? relationshipStatus;
  final String? customerType;
  final String? assignedStaffId;
  final bool unassignedOnly;
  final bool portalOnly;
  final int limit;
  final int offset;
  final String? selectedClientId;
  final String? previewClientId;
  final String? message;
  final String? error;
  final int tickerIndex;

  ClientOpsDirectoryQuery get directoryQuery => (
    search: search,
    relationshipStatus: relationshipStatus,
    customerType: customerType,
    assignedStaffId: assignedStaffId,
    unassignedOnly: unassignedOnly,
    portalOnly: portalOnly,
    limit: limit,
    offset: offset,
  );

  ClientOpsUiState copyWith({
    ClientOpsTab? selectedTab,
    String? search,
    String? relationshipStatus,
    bool clearRelationshipStatus = false,
    String? customerType,
    bool clearCustomerType = false,
    String? assignedStaffId,
    bool clearAssignedStaffId = false,
    bool? unassignedOnly,
    bool? portalOnly,
    int? limit,
    int? offset,
    String? selectedClientId,
    bool clearSelectedClientId = false,
    String? previewClientId,
    bool clearPreviewClientId = false,
    String? message,
    bool clearMessage = false,
    String? error,
    bool clearError = false,
    int? tickerIndex,
  }) {
    return ClientOpsUiState(
      selectedTab: selectedTab ?? this.selectedTab,
      search: search ?? this.search,
      relationshipStatus: clearRelationshipStatus
          ? null
          : (relationshipStatus ?? this.relationshipStatus),
      customerType: clearCustomerType
          ? null
          : (customerType ?? this.customerType),
      assignedStaffId: clearAssignedStaffId
          ? null
          : (assignedStaffId ?? this.assignedStaffId),
      unassignedOnly: unassignedOnly ?? this.unassignedOnly,
      portalOnly: portalOnly ?? this.portalOnly,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
      selectedClientId: clearSelectedClientId
          ? null
          : (selectedClientId ?? this.selectedClientId),
      previewClientId: clearPreviewClientId
          ? null
          : (previewClientId ?? this.previewClientId),
      message: clearMessage ? null : (message ?? this.message),
      error: clearError ? null : (error ?? this.error),
      tickerIndex: tickerIndex ?? this.tickerIndex,
    );
  }
}

class ClientOpsController extends StateNotifier<ClientOpsUiState> {
  ClientOpsController(this._ref) : super(const ClientOpsUiState()) {
    _ticker = Timer.periodic(const Duration(seconds: 5), (_) {
      state = state.copyWith(tickerIndex: state.tickerIndex + 1);
    });
  }

  final Ref _ref;
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void setTab(ClientOpsTab tab) {
    state = state.copyWith(selectedTab: tab, clearError: true);
  }

  void setSearch(String value) {
    state = state.copyWith(search: value, offset: 0);
  }

  void setRelationshipStatus(String? value) {
    state = state.copyWith(
      relationshipStatus: value,
      clearRelationshipStatus: value == null,
      offset: 0,
    );
  }

  void setCustomerType(String? value) {
    state = state.copyWith(
      customerType: value,
      clearCustomerType: value == null,
      offset: 0,
    );
  }

  void setAssignedStaffId(String? value) {
    state = state.copyWith(
      assignedStaffId: value,
      clearAssignedStaffId: value == null,
      unassignedOnly: false,
      offset: 0,
    );
  }

  void setUnassignedOnly(bool value) {
    state = state.copyWith(
      unassignedOnly: value,
      clearAssignedStaffId: value,
      offset: 0,
    );
  }

  void setPortalOnly(bool value) {
    state = state.copyWith(portalOnly: value, offset: 0);
  }

  Future<void> completeTask(String taskId) async {
    try {
      await _ref.read(crmServiceProvider).updateTaskStatus(taskId, 'done');
      state = state.copyWith(message: 'Task marked done', clearError: true);
      await refresh();
    } catch (e) {
      state = state.copyWith(error: e.toString(), clearMessage: true);
    }
  }

  void nextPage(int total) {
    final next = state.offset + state.limit;
    if (next >= total) return;
    state = state.copyWith(offset: next);
  }

  void prevPage() {
    final prev = (state.offset - state.limit).clamp(0, 1 << 30);
    state = state.copyWith(offset: prev);
  }

  void previewClient(String id) {
    state = state.copyWith(previewClientId: id);
  }

  void openClient360(String id) {
    state = state.copyWith(
      selectedClientId: id,
      previewClientId: id,
      selectedTab: ClientOpsTab.detail,
      clearError: true,
    );
  }

  void dismissMessage() => state = state.copyWith(clearMessage: true);
  void dismissError() => state = state.copyWith(clearError: true);

  Future<void> refresh() async {
    _ref.invalidate(clientOpsDeskKpisProvider);
    _ref.invalidate(clientOpsWorkQueuesProvider);
    _ref.invalidate(clientOpsDirectoryProvider);
    _ref.invalidate(clientOpsManagersProvider);
    if (state.selectedClientId != null) {
      _ref.invalidate(clientOpsDetailProvider);
    }
  }

  Future<void> assignOwner({
    required String clientId,
    required String staffId,
  }) async {
    try {
      await _ref
          .read(clientOpsServiceProvider)
          .assignOwner(clientId: clientId, staffId: staffId);
      state = state.copyWith(
        message: 'Relationship owner assigned',
        clearError: true,
      );
      await refresh();
    } catch (e) {
      state = state.copyWith(error: e.toString(), clearMessage: true);
    }
  }
}

final clientOpsControllerProvider =
    StateNotifierProvider<ClientOpsController, ClientOpsUiState>((ref) {
      return ClientOpsController(ref);
    });

final clientOpsRealtimeConnectedProvider = StateProvider<bool>((ref) => false);

const clientOpsRealtimeTables = <String>[
  'crm_clients',
  'crm_leads',
  'crm_tasks',
  'clients',
  'client_property_applications',
  'client_payment_intents',
];

final clientOpsRealtimeProvider = Provider<void>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = ref.watch(supabaseClientProvider);

  void invalidateAll() {
    ref.invalidate(clientOpsDeskKpisProvider);
    ref.invalidate(clientOpsWorkQueuesProvider);
    ref.invalidate(clientOpsDirectoryProvider);
    ref.invalidate(clientOpsDetailProvider);
  }

  var channel = client.channel('client-ops-command-center');
  for (final table in clientOpsRealtimeTables) {
    channel = channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: table,
      callback: (_) => invalidateAll(),
    );
  }

  channel.subscribe((status, [error]) {
    deferProviderMutation(() {
      ref.read(clientOpsRealtimeConnectedProvider.notifier).state =
          status == RealtimeSubscribeStatus.subscribed;
    });
  });

  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
    deferProviderMutation(() {
      ref.read(clientOpsRealtimeConnectedProvider.notifier).state = false;
    });
  });
});
