import 'dart:async';

import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/app_role.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/command_palette_catalog.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/enterprise_search_models.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/observability_models.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/portal_search_catalog.dart';
import 'package:hdhomesproject/features/authentication/domain/services/audit_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Central Enterprise Search & Global Command Center service.
class EnterpriseSearchService {
  EnterpriseSearchService({required AuditService audit, SupabaseClient? client})
    : _audit = audit,
      _client = client;

  final AuditService _audit;
  final SupabaseClient? _client;

  List<SearchIndexEntry> _index = const [];

  bool get isConfigured => _client != null;

  Future<List<SearchIndexEntry>> loadIndex() async {
    final portal = PortalSearchCatalog.allEntries();
    final client = _client;
    if (client == null) {
      _index = _mergeById([
        ...EnterpriseSearchCatalog.seedIndex(),
        ...portal,
      ]);
      return _index;
    }
    try {
      final rows = await client
          .from('search_index')
          .select()
          .eq('is_active', true)
          .order('popularity', ascending: false)
          .limit(500);
      final remote = (rows as List)
          .map((e) => _entryFromRow(Map<String, dynamic>.from(e as Map)))
          .toList();
      _index = _mergeById([
        ...remote,
        if (remote.isEmpty) ...EnterpriseSearchCatalog.seedIndex(),
        ...portal,
      ]);
    } catch (_) {
      // Live index optional — portal destinations + seed stay searchable.
      _index = _mergeById([
        ...EnterpriseSearchCatalog.seedIndex(),
        ...portal,
      ]);
    }
    return _index;
  }

  List<SearchIndexEntry> _mergeById(List<SearchIndexEntry> entries) {
    final map = <String, SearchIndexEntry>{};
    for (final e in entries) {
      map.putIfAbsent(e.id, () => e);
    }
    return map.values.toList();
  }

  /// Ensures [_index] has at least portal destinations before querying.
  void ensureLocalIndex() {
    if (_index.isEmpty) {
      _index = _mergeById([
        ...EnterpriseSearchCatalog.seedIndex(),
        ...PortalSearchCatalog.allEntries(),
      ]);
    } else {
      _index = _mergeById([
        ..._index,
        ...PortalSearchCatalog.allEntries(),
      ]);
    }
  }

  SearchQueryResult search({
    required String query,
    SearchMode mode = SearchMode.universal,
    SearchFilterState filters = const SearchFilterState(),
    Set<String> permissions = const {},
    bool isStaff = false,
    AppRole? role,
  }) {
    ensureLocalIndex();
    final sw = Stopwatch()..start();
    final intent = SemanticSearchFoundation.parseIntent(query);
    var effectiveQuery = query.trim();
    if (intent.location != null &&
        !effectiveQuery.toLowerCase().contains(intent.location!)) {
      effectiveQuery = '$effectiveQuery ${intent.location}';
    }

    final scoped = _index.where(
      (e) => PortalSearchCatalog.isPathAllowedForRole(e.path, role),
    );

    final ranked = SearchRankingEngine.rank(
      scoped,
      effectiveQuery,
      permissions: permissions,
      isStaff: isStaff,
      role: role,
      mode: mode,
      filters: filters,
    );
    final groups = SearchRankingEngine.group(ranked);

    final commandPool = <CommandPaletteAction>[
      ...EnterpriseSearchCatalog.allCommands(),
      ...PortalSearchCatalog.commandsForRole(role),
    ];
    final seenCmd = <String>{};
    final commands = commandPool.where((c) {
      if (!seenCmd.add(c.id)) return false;
      if (!PortalSearchCatalog.isPathAllowedForRole(c.routeOrKey, role)) {
        return false;
      }
      if (c.requiredPermission != null &&
          !permissions.contains(c.requiredPermission) &&
          role != AppRole.superAdmin &&
          role != AppRole.admin) {
        return false;
      }
      // Empty query: surface portal destinations in universal + commands modes.
      if (effectiveQuery.isEmpty) {
        return mode == SearchMode.commands || mode == SearchMode.universal;
      }
      final hay = [c.label, c.id, ...c.keywords].join(' ').toLowerCase();
      return hay.contains(effectiveQuery.toLowerCase());
    }).toList();

    final related = <SearchResultItem>[];
    if (ranked.isNotEmpty) {
      final top = ranked.first;
      for (final rid in top.entry.relatedIds) {
        final match = _index.where((e) => e.id == rid);
        if (match.isEmpty) continue;
        final e = match.first;
        if (!PortalSearchCatalog.isPathAllowedForRole(e.path, role)) continue;
        if (!SearchRankingEngine.canView(
          e,
          permissions: permissions,
          isStaff: isStaff,
          role: role,
        )) {
          continue;
        }
        related.add(SearchResultItem(entry: e, score: 1, matchedOn: 'related'));
      }
    }

    sw.stop();
    final result = SearchQueryResult(
      query: query,
      mode: mode,
      groups: groups,
      suggestions: _suggestionsFor(query, role),
      commands: commands,
      related: related,
      latencyMs: sw.elapsedMilliseconds,
      zeroResults: groups.isEmpty && commands.isEmpty,
      intent: intent,
    );

    return result;
  }

  List<SearchSuggestion> _suggestionsFor(String query, AppRole? role) {
    final p = query.trim().toLowerCase();
    final pool = PortalSearchCatalog.commandsForRole(role);
    return pool
        .where((action) {
          if (p.isEmpty) return true;
          final searchable = [
            action.label,
            action.id,
            ...action.keywords,
          ].join(' ').toLowerCase();
          return searchable.contains(p);
        })
        .map(
          (action) => SearchSuggestion(
            label: action.label,
            query: action.label,
            kind: 'command',
          ),
        )
        .take(8)
        .toList();
  }

  Future<EnterpriseSearchSnapshot> loadSnapshot(String? userId) async {
    final history = await listHistory(userId);
    final favorites = await listFavoriteCommands(userId);
    return EnterpriseSearchSnapshot(
      history: history,
      favoriteCommands: favorites,
      pinnedWorkspaces: _index
          .where((e) => e.module == SearchResultModule.workspace)
          .toList(),
    );
  }

  Future<List<SearchHistoryItem>> listHistory(String? userId) async {
    if (userId == null || _client == null) {
      return const [];
    }
    try {
      final rows = await _client
          .from('search_history')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(30);
      return (rows as List).map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return SearchHistoryItem(
          id: m['id'] as String,
          query: m['query'] as String? ?? '',
          mode: SearchMode.values.firstWhere(
            (mode) => mode.name == (m['mode'] as String? ?? 'universal'),
            orElse: () => SearchMode.universal,
          ),
          createdAt: m['created_at'] != null
              ? DateTime.parse(m['created_at'] as String).toUtc()
              : null,
        );
      }).toList();
    } catch (error) {
      throw DatabaseException(
        userFacingError(error, fallback: 'Unable to load search history.'),
        cause: error,
      );
    }
  }

  Future<void> recordHistory({
    required String userId,
    required String query,
    SearchMode mode = SearchMode.universal,
  }) async {
    final client = _client;
    if (client == null) return;
    try {
      await client.from('search_history').insert({
        'user_id': userId,
        'query': query,
        'mode': mode.name,
      });
    } catch (_) {}
  }

  Future<void> clearHistory(String userId) async {
    final client = _client;
    if (client == null) return;
    try {
      await client.from('search_history').delete().eq('user_id', userId);
    } catch (_) {}
  }

  Future<List<FavoriteCommand>> listFavoriteCommands(String? userId) async {
    if (userId == null || _client == null) return const [];
    try {
      final rows = await _client
          .from('favorite_commands')
          .select()
          .eq('user_id', userId)
          .order('sort_order');
      final list = (rows as List).map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return FavoriteCommand(
          id: m['id'] as String,
          actionKey: m['action_key'] as String? ?? '',
          label: m['label'] as String? ?? '',
          path: m['path'] as String? ?? '/',
        );
      }).toList();
      return list;
    } catch (error) {
      throw DatabaseException(
        userFacingError(error, fallback: 'Unable to load favorite commands.'),
        cause: error,
      );
    }
  }

  Future<SearchAnalyticsSnapshot> getAdminSearchAnalytics({
    int days = 30,
  }) async {
    final client = _client;
    if (client == null) {
      throw const DatabaseException(
        'Live search analytics requires a Supabase connection.',
      );
    }
    try {
      final response = await client.rpc(
        'get_admin_search_analytics',
        params: {'p_days': days},
      );
      if (response is! Map) {
        throw const FormatException('Invalid search analytics response.');
      }
      return SearchAnalyticsSnapshot.fromJson(
        Map<String, dynamic>.from(response),
      );
    } catch (error) {
      throw DatabaseException(
        userFacingError(
          error,
          fallback: 'Unable to load live search analytics.',
        ),
        cause: error,
      );
    }
  }

  List<CommandPaletteAction> executiveCommands({
    required Set<String> permissions,
    AppRole? role,
  }) {
    final isExec =
        role == AppRole.admin ||
        role == AppRole.superAdmin ||
        permissions.contains('manage_reports');
    if (!isExec) return const [];
    return EnterpriseSearchCatalog.allCommands()
        .where(
          (c) =>
              c.label.toLowerCase().contains('sales') ||
              c.label.toLowerCase().contains('health') ||
              c.label.toLowerCase().contains('report') ||
              c.label.toLowerCase().contains('investor'),
        )
        .toList();
  }

  Future<void> recordEnterpriseSearchEvent(SearchQueryResult result) async {
    final query = result.query.trim();
    if (query.isEmpty) return;

    final client = _client;
    if (client == null) {
      throw const DatabaseException(
        'Search telemetry requires a Supabase connection.',
      );
    }
    try {
      await client.rpc(
        'record_enterprise_search_event',
        params: {
          'p_query': query,
          'p_mode': result.mode.name,
          'p_result_count': result.totalCount + result.commands.length,
          'p_latency_ms': result.latencyMs,
        },
      );
    } catch (error) {
      throw DatabaseException(
        userFacingError(error, fallback: 'Unable to record the search event.'),
        cause: error,
      );
    }

    unawaited(
      _audit.publish(
        AuditPublishRequest(
          action: 'search_executed',
          module: 'enterprise_search',
          category: AuditEventCategory.system,
          severity: AuditSeverity.info,
          metadata: {
            'mode': result.mode.name,
            'result_count': result.totalCount + result.commands.length,
            'zero_results': result.zeroResults,
            'latency_ms': result.latencyMs,
          },
          visibleToUser: false,
        ),
      ),
    );
  }

  SearchIndexEntry _entryFromRow(Map<String, dynamic> row) {
    return SearchIndexEntry(
      id: row['entity_id'] as String? ?? row['id'] as String,
      module: SearchResultModule.fromSlug(row['module'] as String?),
      title: row['title'] as String? ?? 'Result',
      subtitle: row['subtitle'] as String?,
      path: row['path'] as String? ?? '/',
      keywords:
          (row['keywords'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      permissionSlug: row['permission_slug'] as String?,
      popularity: (row['popularity'] as num?)?.toInt() ?? 0,
      preview: Map<String, String>.from(
        (row['preview'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), v.toString()),
            ) ??
            {},
      ),
      relatedIds:
          (row['related_ids'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
    );
  }
}
