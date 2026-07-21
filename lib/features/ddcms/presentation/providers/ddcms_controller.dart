import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/ddcms/domain/entities/ddcms_models.dart';
import 'package:hdhomesproject/features/ddcms/domain/services/ddcms_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final ddcmsServiceProvider = Provider<DdcmsService>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return DdcmsService(
    client: configured ? ref.watch(supabaseClientProvider) : null,
  );
});

final ddcmsSnapshotProvider =
    FutureProvider<DdcmsCommandCenterSnapshot>((ref) async {
  return ref.watch(ddcmsServiceProvider).loadCommandCenter();
});

/// Invalidates snapshot when DDCMS live tables change (after SQL apply + Realtime).
final ddcmsRealtimeProvider = Provider<void>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = ref.watch(supabaseClientProvider);
  final channel = client.channel('ddcms-command-center')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'documents',
      callback: (_) => ref.invalidate(ddcmsSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'document_approvals',
      callback: (_) => ref.invalidate(ddcmsSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'signature_requests',
      callback: (_) => ref.invalidate(ddcmsSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'ocr_processing_jobs',
      callback: (_) => ref.invalidate(ddcmsSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'document_activity_logs',
      callback: (_) => ref.invalidate(ddcmsSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'document_notifications',
      callback: (_) => ref.invalidate(ddcmsSnapshotProvider),
    )
    ..subscribe();

  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

enum DdcmsCommandTab {
  overview,
  repository,
  contracts,
  signatures,
  approvals,
  dam,
  ocr,
  sharing,
  retention,
  analytics,
  ai,
  compliance;

  String get label => switch (this) {
        DdcmsCommandTab.overview => 'Overview',
        DdcmsCommandTab.repository => 'Repository',
        DdcmsCommandTab.contracts => 'Contracts',
        DdcmsCommandTab.signatures => 'Signatures',
        DdcmsCommandTab.approvals => 'Approvals',
        DdcmsCommandTab.dam => 'DAM',
        DdcmsCommandTab.ocr => 'OCR',
        DdcmsCommandTab.sharing => 'Sharing',
        DdcmsCommandTab.retention => 'Retention',
        DdcmsCommandTab.analytics => 'Analytics',
        DdcmsCommandTab.ai => 'AI',
        DdcmsCommandTab.compliance => 'Compliance',
      };
}

class DdcmsUiState {
  const DdcmsUiState({
    this.searchQuery = '',
    this.statusFilter,
    this.categoryFilter,
    this.selectedTab = DdcmsCommandTab.overview,
    this.lastMessage,
    this.tickerIndex = 0,
  });

  final String searchQuery;
  final String? statusFilter;
  final String? categoryFilter;
  final DdcmsCommandTab selectedTab;
  final String? lastMessage;
  final int tickerIndex;

  DdcmsUiState copyWith({
    String? searchQuery,
    String? statusFilter,
    bool clearStatusFilter = false,
    String? categoryFilter,
    bool clearCategoryFilter = false,
    DdcmsCommandTab? selectedTab,
    String? lastMessage,
    bool clearMessage = false,
    int? tickerIndex,
  }) {
    return DdcmsUiState(
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

class DdcmsController extends Notifier<DdcmsUiState> {
  Timer? _tickerTimer;

  @override
  DdcmsUiState build() {
    // CRITICAL: never read `state` here — arm ticker from initial constants only.
    ref.onDispose(() => _tickerTimer?.cancel());
    ref.watch(ddcmsRealtimeProvider);
    _armTicker();
    return const DdcmsUiState();
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

  void setTab(DdcmsCommandTab tab) {
    state = state.copyWith(selectedTab: tab);
  }

  void setMessage(String message) {
    state = state.copyWith(lastMessage: message);
  }

  void clearMessage() {
    state = state.copyWith(clearMessage: true);
  }

  Future<void> refresh() async {
    ref.invalidate(ddcmsSnapshotProvider);
  }

  List<DdcmsDocument> filteredDocuments(DdcmsCommandCenterSnapshot snap) {
    final q = state.searchQuery.trim().toLowerCase();
    return snap.documents.where((d) {
      if (state.statusFilter != null && d.status != state.statusFilter) {
        return false;
      }
      if (state.categoryFilter != null && d.category != state.categoryFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return d.title.toLowerCase().contains(q) ||
          (d.code?.toLowerCase().contains(q) ?? false) ||
          (d.ownerLabel?.toLowerCase().contains(q) ?? false) ||
          d.tags.any((t) => t.toLowerCase().contains(q));
    }).toList();
  }

  List<DdcmsContract> filteredContracts(DdcmsCommandCenterSnapshot snap) {
    final q = state.searchQuery.trim().toLowerCase();
    return snap.contracts.where((c) {
      if (state.statusFilter != null && c.status != state.statusFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return c.title.toLowerCase().contains(q) ||
          c.contractNumber.toLowerCase().contains(q) ||
          (c.counterpartyName?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  List<DdcmsAsset> filteredAssets(DdcmsCommandCenterSnapshot snap) {
    final q = state.searchQuery.trim().toLowerCase();
    if (q.isEmpty) return snap.assets;
    return snap.assets
        .where(
          (a) =>
              a.title.toLowerCase().contains(q) ||
              a.assetType.toLowerCase().contains(q) ||
              a.tags.any((t) => t.toLowerCase().contains(q)),
        )
        .toList();
  }
}

final ddcmsControllerProvider =
    NotifierProvider<DdcmsController, DdcmsUiState>(DdcmsController.new);
