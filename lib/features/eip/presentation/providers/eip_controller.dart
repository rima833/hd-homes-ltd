import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/eip/domain/entities/eip_models.dart';
import 'package:hdhomesproject/features/eip/domain/services/eip_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final eipServiceProvider = Provider<EipService>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return EipService(
    client: configured ? ref.watch(supabaseClientProvider) : null,
  );
});

final eipSnapshotProvider =
    FutureProvider<EipCommandCenterSnapshot>((ref) async {
  return ref.watch(eipServiceProvider).loadCommandCenter();
});

/// Invalidates snapshot when EIP live tables change (after SQL apply + Realtime).
final eipRealtimeProvider = Provider<void>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = ref.watch(supabaseClientProvider);
  final channel = client.channel('integration-command-center')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'domain_events',
      callback: (_) => ref.invalidate(eipSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'workflow_instances',
      callback: (_) => ref.invalidate(eipSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'webhook_deliveries',
      callback: (_) => ref.invalidate(eipSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'message_queue_items',
      callback: (_) => ref.invalidate(eipSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'integration_health_checks',
      callback: (_) => ref.invalidate(eipSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'integration_activity_logs',
      callback: (_) => ref.invalidate(eipSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'integration_notifications',
      callback: (_) => ref.invalidate(eipSnapshotProvider),
    )
    ..subscribe();

  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

enum EipCommandTab {
  overview,
  apis,
  workflows,
  events,
  queues,
  webhooks,
  connectors,
  security,
  monitoring,
  config,
  analytics,
  ai;

  String get label => switch (this) {
        EipCommandTab.overview => 'Overview',
        EipCommandTab.apis => 'APIs',
        EipCommandTab.workflows => 'Workflows',
        EipCommandTab.events => 'Events',
        EipCommandTab.queues => 'Queues',
        EipCommandTab.webhooks => 'Webhooks',
        EipCommandTab.connectors => 'Connectors',
        EipCommandTab.security => 'Security',
        EipCommandTab.monitoring => 'Monitoring',
        EipCommandTab.config => 'Config',
        EipCommandTab.analytics => 'Analytics',
        EipCommandTab.ai => 'AI',
      };
}

class EipUiState {
  const EipUiState({
    this.searchQuery = '',
    this.statusFilter,
    this.selectedTab = EipCommandTab.overview,
    this.lastMessage,
    this.tickerIndex = 0,
  });

  final String searchQuery;
  final String? statusFilter;
  final EipCommandTab selectedTab;
  final String? lastMessage;
  final int tickerIndex;

  EipUiState copyWith({
    String? searchQuery,
    String? statusFilter,
    bool clearStatusFilter = false,
    EipCommandTab? selectedTab,
    String? lastMessage,
    bool clearMessage = false,
    int? tickerIndex,
  }) {
    return EipUiState(
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter:
          clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
      selectedTab: selectedTab ?? this.selectedTab,
      lastMessage: clearMessage ? null : (lastMessage ?? this.lastMessage),
      tickerIndex: tickerIndex ?? this.tickerIndex,
    );
  }
}

class EipController extends Notifier<EipUiState> {
  Timer? _tickerTimer;

  @override
  EipUiState build() {
    // CRITICAL: never read `state` here — arm ticker from initial constants only.
    ref.onDispose(() => _tickerTimer?.cancel());
    ref.watch(eipRealtimeProvider);
    _armTicker();
    return const EipUiState();
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

  void setTab(EipCommandTab tab) {
    state = state.copyWith(selectedTab: tab);
  }

  void setMessage(String message) {
    state = state.copyWith(lastMessage: message);
  }

  void clearMessage() {
    state = state.copyWith(clearMessage: true);
  }

  Future<void> refresh() async {
    ref.invalidate(eipSnapshotProvider);
  }

  List<EipApiService> filteredApis(EipCommandCenterSnapshot snap) {
    final q = state.searchQuery.trim().toLowerCase();
    return snap.apiServices.where((a) {
      if (state.statusFilter != null && a.status != state.statusFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return a.name.toLowerCase().contains(q) ||
          (a.code?.toLowerCase().contains(q) ?? false) ||
          (a.ownerLabel?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  List<EipWorkflowDef> filteredWorkflows(EipCommandCenterSnapshot snap) {
    final q = state.searchQuery.trim().toLowerCase();
    return snap.workflows.where((w) {
      if (state.statusFilter != null && w.status != state.statusFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return w.name.toLowerCase().contains(q) ||
          (w.code?.toLowerCase().contains(q) ?? false) ||
          (w.triggerEvent?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  List<EipDomainEvent> filteredEvents(EipCommandCenterSnapshot snap) {
    final q = state.searchQuery.trim().toLowerCase();
    return snap.domainEvents.where((e) {
      if (state.statusFilter != null && e.status != state.statusFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return e.eventType.toLowerCase().contains(q) ||
          (e.code?.toLowerCase().contains(q) ?? false) ||
          (e.aggregateType?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  List<EipConnector> filteredConnectors(EipCommandCenterSnapshot snap) {
    final q = state.searchQuery.trim().toLowerCase();
    return snap.connectors.where((c) {
      if (state.statusFilter != null && c.status != state.statusFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return c.name.toLowerCase().contains(q) ||
          (c.code?.toLowerCase().contains(q) ?? false) ||
          (c.providerSlug?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  List<EipWebhookEndpoint> filteredWebhooks(EipCommandCenterSnapshot snap) {
    final q = state.searchQuery.trim().toLowerCase();
    return snap.webhooks.where((w) {
      if (state.statusFilter != null && w.status != state.statusFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return w.name.toLowerCase().contains(q) ||
          (w.code?.toLowerCase().contains(q) ?? false) ||
          w.url.toLowerCase().contains(q);
    }).toList();
  }
}

final eipControllerProvider =
    NotifierProvider<EipController, EipUiState>(EipController.new);
