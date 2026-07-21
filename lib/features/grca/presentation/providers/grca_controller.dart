import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/grca/domain/entities/grca_models.dart';
import 'package:hdhomesproject/features/grca/domain/services/grca_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final grcaServiceProvider = Provider<GrcaService>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return GrcaService(
    client: configured ? ref.watch(supabaseClientProvider) : null,
  );
});

final grcaSnapshotProvider =
    FutureProvider<GrcaCommandCenterSnapshot>((ref) async {
  return ref.watch(grcaServiceProvider).loadCommandCenter();
});

/// Invalidates snapshot when GRC live tables change (after SQL apply + Realtime).
final grcaRealtimeProvider = Provider<void>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = ref.watch(supabaseClientProvider);
  final channel = client.channel('grc-command-center')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'risk_register',
      callback: (_) => ref.invalidate(grcaSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'audit_findings',
      callback: (_) => ref.invalidate(grcaSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'ethics_reports',
      callback: (_) => ref.invalidate(grcaSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'regulatory_calendar',
      callback: (_) => ref.invalidate(grcaSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'legal_cases',
      callback: (_) => ref.invalidate(grcaSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'grc_activity_logs',
      callback: (_) => ref.invalidate(grcaSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'grc_notifications',
      callback: (_) => ref.invalidate(grcaSnapshotProvider),
    )
    ..subscribe();

  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

enum GrcaCommandTab {
  overview,
  risks,
  compliance,
  policies,
  audit,
  legal,
  ethics,
  board,
  bcm,
  calendar,
  analytics,
  ai;

  String get label => switch (this) {
        GrcaCommandTab.overview => 'Overview',
        GrcaCommandTab.risks => 'Risks',
        GrcaCommandTab.compliance => 'Compliance',
        GrcaCommandTab.policies => 'Policies',
        GrcaCommandTab.audit => 'Audit',
        GrcaCommandTab.legal => 'Legal',
        GrcaCommandTab.ethics => 'Ethics',
        GrcaCommandTab.board => 'Board',
        GrcaCommandTab.bcm => 'BCM',
        GrcaCommandTab.calendar => 'Calendar',
        GrcaCommandTab.analytics => 'Analytics',
        GrcaCommandTab.ai => 'AI',
      };
}

class GrcaUiState {
  const GrcaUiState({
    this.searchQuery = '',
    this.statusFilter,
    this.severityFilter,
    this.selectedTab = GrcaCommandTab.overview,
    this.lastMessage,
    this.tickerIndex = 0,
  });

  final String searchQuery;
  final String? statusFilter;
  final String? severityFilter;
  final GrcaCommandTab selectedTab;
  final String? lastMessage;
  final int tickerIndex;

  GrcaUiState copyWith({
    String? searchQuery,
    String? statusFilter,
    bool clearStatusFilter = false,
    String? severityFilter,
    bool clearSeverityFilter = false,
    GrcaCommandTab? selectedTab,
    String? lastMessage,
    bool clearMessage = false,
    int? tickerIndex,
  }) {
    return GrcaUiState(
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter:
          clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
      severityFilter: clearSeverityFilter
          ? null
          : (severityFilter ?? this.severityFilter),
      selectedTab: selectedTab ?? this.selectedTab,
      lastMessage: clearMessage ? null : (lastMessage ?? this.lastMessage),
      tickerIndex: tickerIndex ?? this.tickerIndex,
    );
  }
}

class GrcaController extends Notifier<GrcaUiState> {
  Timer? _tickerTimer;

  @override
  GrcaUiState build() {
    // CRITICAL: never read `state` here — arm ticker from initial constants only.
    ref.onDispose(() => _tickerTimer?.cancel());
    ref.watch(grcaRealtimeProvider);
    _armTicker();
    return const GrcaUiState();
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

  void setSeverityFilter(String? severity) {
    if (severity == null) {
      state = state.copyWith(clearSeverityFilter: true);
    } else {
      state = state.copyWith(severityFilter: severity);
    }
  }

  void setTab(GrcaCommandTab tab) {
    state = state.copyWith(selectedTab: tab);
  }

  void setMessage(String message) {
    state = state.copyWith(lastMessage: message);
  }

  void clearMessage() {
    state = state.copyWith(clearMessage: true);
  }

  Future<void> refresh() async {
    ref.invalidate(grcaSnapshotProvider);
  }

  List<GrcaRisk> filteredRisks(GrcaCommandCenterSnapshot snap) {
    final q = state.searchQuery.trim().toLowerCase();
    return snap.risks.where((r) {
      if (state.statusFilter != null && r.status != state.statusFilter) {
        return false;
      }
      if (state.severityFilter != null &&
          r.severity != state.severityFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return r.title.toLowerCase().contains(q) ||
          (r.code?.toLowerCase().contains(q) ?? false) ||
          (r.ownerLabel?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  List<GrcaAuditFinding> filteredFindings(GrcaCommandCenterSnapshot snap) {
    final q = state.searchQuery.trim().toLowerCase();
    return snap.auditFindings.where((f) {
      if (state.statusFilter != null && f.status != state.statusFilter) {
        return false;
      }
      if (state.severityFilter != null &&
          f.severity != state.severityFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return f.title.toLowerCase().contains(q) ||
          (f.code?.toLowerCase().contains(q) ?? false) ||
          (f.ownerLabel?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  List<GrcaPolicy> filteredPolicies(GrcaCommandCenterSnapshot snap) {
    final q = state.searchQuery.trim().toLowerCase();
    return snap.policies.where((p) {
      if (state.statusFilter != null && p.status != state.statusFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return p.title.toLowerCase().contains(q) ||
          (p.code?.toLowerCase().contains(q) ?? false) ||
          (p.ownerLabel?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  List<GrcaLegalCase> filteredLegalCases(GrcaCommandCenterSnapshot snap) {
    final q = state.searchQuery.trim().toLowerCase();
    return snap.legalCases.where((c) {
      if (state.statusFilter != null && c.status != state.statusFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return c.title.toLowerCase().contains(q) ||
          (c.code?.toLowerCase().contains(q) ?? false) ||
          (c.opposingParty?.toLowerCase().contains(q) ?? false);
    }).toList();
  }
}

final grcaControllerProvider =
    NotifierProvider<GrcaController, GrcaUiState>(GrcaController.new);
