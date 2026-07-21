import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/enterprise_search_models.dart';
import 'package:hdhomesproject/features/authentication/domain/services/enterprise_search_service.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/audit_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/auth_controller.dart';

final enterpriseSearchServiceProvider = Provider<EnterpriseSearchService>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return EnterpriseSearchService(
    audit: ref.watch(auditServiceProvider),
    client: configured ? ref.watch(supabaseClientProvider) : null,
  );
});

final enterpriseSearchIndexProvider =
    FutureProvider<List<SearchIndexEntry>>((ref) async {
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
      runSearch(state.query);
    }
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
    state = state.copyWith(
      filters: state.filters.copyWith(location: location),
    );
    runSearch(state.query);
  }

  void runSearch(String query) {
    final session = ref.read(identitySessionProvider);
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

  Future<void> clearHistory() async {
    final userId = ref.read(identitySessionProvider).userId;
    if (userId == null) return;
    await _service.clearHistory(userId);
    ref.invalidate(enterpriseSearchSnapshotProvider);
  }
}
