import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/core/utils/provider_lifecycle.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/enterprise_search_models.dart';
import 'package:hdhomesproject/features/authentication/domain/services/enterprise_search_service.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/audit_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/auth_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final enterpriseSearchServiceProvider = Provider<EnterpriseSearchService>((
  ref,
) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return EnterpriseSearchService(
    audit: ref.watch(auditServiceProvider),
    client: configured ? ref.watch(supabaseClientProvider) : null,
  );
});

void _invalidateEnterpriseSearch(Ref ref) {
  deferProviderMutation(() {
    ref.invalidate(enterpriseSearchIndexProvider);
    ref.invalidate(enterpriseSearchSnapshotProvider);
  });
}

enum SearchAnalyticsRealtimeState { disconnected, connecting, live, error }

final searchAnalyticsRealtimeStateProvider =
    StateProvider<SearchAnalyticsRealtimeState>(
      (ref) => SearchAnalyticsRealtimeState.disconnected,
    );

final searchAnalyticsProvider =
    FutureProvider.family<SearchAnalyticsSnapshot, int>((ref, days) {
      return ref
          .watch(enterpriseSearchServiceProvider)
          .getAdminSearchAnalytics(days: days);
    });

/// Live invalidation for the command palette and admin search analytics.
final enterpriseSearchRealtimeProvider = Provider<void>((ref) {
  ref.keepAlive();
  if (!ref.watch(supabaseConfiguredProvider)) {
    deferProviderMutation(
      () => ref.read(searchAnalyticsRealtimeStateProvider.notifier).state =
          SearchAnalyticsRealtimeState.disconnected,
    );
    return;
  }
  final client = ref.watch(supabaseClientProvider);
  deferProviderMutation(
    () => ref.read(searchAnalyticsRealtimeStateProvider.notifier).state =
        SearchAnalyticsRealtimeState.connecting,
  );

  // Analytics status follows only the published aggregate table. Index,
  // history, and favorites stay on a separate channel so a missing
  // publication there cannot mark Search Insights as a realtime error.
  Timer? debounce;
  void refreshAnalytics() {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 400), () {
      deferProviderMutation(() => ref.invalidate(searchAnalyticsProvider));
    });
  }

  final token = client.auth.currentSession?.accessToken;
  if (token != null && token.isNotEmpty) {
    unawaited(client.realtime.setAuth(token));
  }

  final analyticsChannel = client.channel('admin-search-analytics')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'search_analytics',
      callback: (_) => refreshAnalytics(),
    )
    ..subscribe((status, [error]) {
      final next = switch (status) {
        RealtimeSubscribeStatus.subscribed => SearchAnalyticsRealtimeState.live,
        RealtimeSubscribeStatus.timedOut ||
        RealtimeSubscribeStatus.channelError =>
          SearchAnalyticsRealtimeState.error,
        RealtimeSubscribeStatus.closed =>
          SearchAnalyticsRealtimeState.disconnected,
      };
      deferProviderMutation(
        () => ref.read(searchAnalyticsRealtimeStateProvider.notifier).state =
            next,
      );
    });

  var indexChannel = client.channel('admin-enterprise-search-index');
  for (final table in const [
    'search_index',
    'search_history',
    'favorite_commands',
  ]) {
    indexChannel = indexChannel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: table,
      callback: (_) => _invalidateEnterpriseSearch(ref),
    );
  }
  indexChannel.subscribe();

  ref.onDispose(() {
    debounce?.cancel();
    unawaited(client.removeChannel(analyticsChannel));
    unawaited(client.removeChannel(indexChannel));
    deferProviderMutation(
      () => ref.read(searchAnalyticsRealtimeStateProvider.notifier).state =
          SearchAnalyticsRealtimeState.disconnected,
    );
  });
});

final enterpriseSearchIndexProvider = FutureProvider<List<SearchIndexEntry>>((
  ref,
) async {
  return ref.watch(enterpriseSearchServiceProvider).loadIndex();
});

final enterpriseSearchSnapshotProvider =
    FutureProvider<EnterpriseSearchSnapshot>((ref) async {
      final userId = ref.watch(identitySessionProvider).userId;
      return ref.watch(enterpriseSearchServiceProvider).loadSnapshot(userId);
    });

class CommandCenterUiState {
  const CommandCenterUiState({
    this.query = '',
    this.mode = SearchMode.universal,
    this.filters = const SearchFilterState(),
    this.result,
    this.isOpen = false,
    this.expandedModules = const {},
  });

  final String query;
  final SearchMode mode;
  final SearchFilterState filters;
  final SearchQueryResult? result;
  final bool isOpen;
  final Set<SearchResultModule> expandedModules;

  CommandCenterUiState copyWith({
    String? query,
    SearchMode? mode,
    SearchFilterState? filters,
    SearchQueryResult? result,
    bool? isOpen,
    Set<SearchResultModule>? expandedModules,
    bool clearResult = false,
  }) {
    return CommandCenterUiState(
      query: query ?? this.query,
      mode: mode ?? this.mode,
      filters: filters ?? this.filters,
      result: clearResult ? null : (result ?? this.result),
      isOpen: isOpen ?? this.isOpen,
      expandedModules: expandedModules ?? this.expandedModules,
    );
  }
}

final commandCenterControllerProvider =
    NotifierProvider<CommandCenterController, CommandCenterUiState>(
      CommandCenterController.new,
    );

class CommandCenterController extends Notifier<CommandCenterUiState> {
  @override
  CommandCenterUiState build() {
    // Do not watch the search index here — that resets UI state and rebuilds
    // the whole app whenever the FutureProvider resolves.
    return const CommandCenterUiState(
      expandedModules: {
        SearchResultModule.property,
        SearchResultModule.command,
        SearchResultModule.client,
      },
    );
  }

  EnterpriseSearchService get _service =>
      ref.read(enterpriseSearchServiceProvider);

  void setOpen(bool open) {
    state = state.copyWith(isOpen: open);
    if (!open) {
      state = state.copyWith(query: '', clearResult: true);
    } else {
      // Warm remote + portal index, then search so results appear immediately.
      unawaited(_openAndSearch());
    }
  }

  Future<void> _openAndSearch() async {
    try {
      await ref.read(enterpriseSearchIndexProvider.future);
    } catch (_) {
      // Service falls back to portal catalog + seed.
    }
    runSearch(state.query);
  }

  void setMode(SearchMode mode) {
    state = state.copyWith(mode: mode);
    runSearch(state.query);
  }

  void setQuery(String query) {
    state = state.copyWith(query: query);
    runSearch(query);
  }

  void toggleModule(SearchResultModule module) {
    final next = {...state.expandedModules};
    if (next.contains(module)) {
      next.remove(module);
    } else {
      next.add(module);
    }
    state = state.copyWith(expandedModules: next);
  }

  void setLocationFilter(String? location) {
    state = state.copyWith(filters: state.filters.copyWith(location: location));
    runSearch(state.query);
  }

  void runSearch(String query) {
    final session = ref.read(identitySessionProvider);
    // Keep service index warm (portal destinations always available).
    _service.ensureLocalIndex();
    final result = _service.search(
      query: query,
      mode: state.mode,
      filters: state.filters,
      permissions: session.permissions,
      isStaff: session.isStaff,
      role: session.primaryRole,
    );
    state = state.copyWith(result: result, query: query);
  }

  Future<void> commitHistory(String query) async {
    final userId = ref.read(identitySessionProvider).userId;
    if (userId == null || query.trim().isEmpty) return;
    await _service.recordHistory(
      userId: userId,
      query: query.trim(),
      mode: state.mode,
    );
    ref.invalidate(enterpriseSearchSnapshotProvider);
  }

  /// Records one event for an explicit keyboard submission.
  SearchQueryResult? submitSearch(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return null;
    if (state.query != query || state.result == null) {
      runSearch(query);
    }
    final result = state.result;
    if (result == null) return null;
    unawaited(commitHistory(trimmed));
    unawaited(_recordSearchEvent(result));
    return result;
  }

  /// Records one event when the user explicitly opens a search result.
  void recordResultOpen() {
    final result = state.result;
    if (result == null || result.query.trim().isEmpty) return;
    unawaited(_recordSearchEvent(result));
  }

  Future<void> _recordSearchEvent(SearchQueryResult result) async {
    try {
      await _service.recordEnterpriseSearchEvent(result);
    } catch (_) {
      // Telemetry must never block search or navigation.
    }
  }

  Future<void> clearHistory() async {
    final userId = ref.read(identitySessionProvider).userId;
    if (userId == null) return;
    await _service.clearHistory(userId);
    ref.invalidate(enterpriseSearchSnapshotProvider);
  }
}
