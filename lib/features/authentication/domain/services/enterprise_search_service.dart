import 'dart:async';

import 'package:hdhomesproject/features/authentication/domain/entities/app_role.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/command_palette_catalog.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/enterprise_search_models.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/observability_models.dart';
import 'package:hdhomesproject/features/authentication/domain/services/audit_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Central Enterprise Search & Global Command Center service.
class EnterpriseSearchService {
  EnterpriseSearchService({
    required AuditService audit,
    SupabaseClient? client,
  })  : _audit = audit,
        _client = client;

  final AuditService _audit;
  final SupabaseClient? _client;

  List<SearchIndexEntry> _index = EnterpriseSearchCatalog.seedIndex();
  final List<SearchHistoryItem> _localHistory = [];
  final List<FavoriteCommand> _localFavorites = [
    const FavoriteCommand(
      id: 'fav-create-property',
      actionKey: 'create_property',
      label: 'Add Property',
      path: '/dashboard/properties',
    ),
    const FavoriteCommand(
      id: 'fav-inspection',
      actionKey: 'book_inspection',
      label: 'Schedule Inspection',
      path: '/book-inspection',
    ),
  ];

  bool get isConfigured => _client != null;

  Future<List<SearchIndexEntry>> loadIndex() async {
    final client = _client;
    if (client == null) {
      _index = EnterpriseSearchCatalog.seedIndex();
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
      _index = remote.isEmpty ? EnterpriseSearchCatalog.seedIndex() : remote;
    } catch (_) {
      _index = EnterpriseSearchCatalog.seedIndex();
    }
    return _index;
  }

  SearchQueryResult search({
    required String query,
    SearchMode mode = SearchMode.universal,
    SearchFilterState filters = const SearchFilterState(),
    Set<String> permissions = const {},
    bool isStaff = false,
    AppRole? role,
  }) {
    final sw = Stopwatch()..start();
    final intent = SemanticSearchFoundation.parseIntent(query);
    var effectiveQuery = query.trim();
    if (intent.location != null &&
        !effectiveQuery.toLowerCase().contains(intent.location!)) {
      effectiveQuery = '$effectiveQuery ${intent.location}';
    }

    final ranked = SearchRankingEngine.rank(
      _index,
      effectiveQuery,
      permissions: permissions,
      isStaff: isStaff,
      role: role,
      mode: mode,
      filters: filters,
    );
    final groups = SearchRankingEngine.group(ranked);
    final commands = EnterpriseSearchCatalog.allCommands().where((c) {
      if (c.requiredPermission != null &&
          !permissions.contains(c.requiredPermission) &&
          role != AppRole.superAdmin &&
          role != AppRole.admin) {
        return false;
      }
      if (effectiveQuery.isEmpty) return mode == SearchMode.commands;
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
      suggestions: EnterpriseSearchCatalog.suggest(query),
      commands: commands,
      related: related,
      latencyMs: sw.elapsedMilliseconds,
      zeroResults: groups.isEmpty && commands.isEmpty,
      intent: intent,
    );

    if (query.trim().isNotEmpty) {
      unawaited(_recordAnalytics(query, result));
    }
    return result;
  }

  Future<EnterpriseSearchSnapshot> loadSnapshot(String? userId) async {
    final history = await listHistory(userId);
    final favorites = await listFavoriteCommands(userId);
    return EnterpriseSearchSnapshot(
      history: history,
      favoriteCommands: favorites,
      analytics: demoAnalytics(),
      pinnedWorkspaces: _index
          .where((e) => e.module == SearchResultModule.workspace)
          .toList(),
    );
  }

  Future<List<SearchHistoryItem>> listHistory(String? userId) async {
    if (userId == null || _client == null) {
      return _localHistory.isEmpty
          ? [
              SearchHistoryItem(
                id: 'h1',
                query: 'Lekki Phase 1',
                createdAt: DateTime.now().toUtc(),
              ),
              SearchHistoryItem(
                id: 'h2',
                query: 'Create Property',
                mode: SearchMode.commands,
                createdAt: DateTime.now().toUtc(),
              ),
            ]
          : List.of(_localHistory);
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
    } catch (_) {
      return _localHistory;
    }
  }

  Future<void> recordHistory({
    required String userId,
    required String query,
    SearchMode mode = SearchMode.universal,
  }) async {
    final item = SearchHistoryItem(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      query: query,
      mode: mode,
      createdAt: DateTime.now().toUtc(),
    );
    _localHistory.insert(0, item);
    if (_localHistory.length > 40) {
      _localHistory.removeRange(40, _localHistory.length);
    }
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
    _localHistory.clear();
    final client = _client;
    if (client == null) return;
    try {
      await client.from('search_history').delete().eq('user_id', userId);
    } catch (_) {}
  }

  Future<List<FavoriteCommand>> listFavoriteCommands(String? userId) async {
    if (userId == null || _client == null) return _localFavorites;
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
      return list.isEmpty ? _localFavorites : list;
    } catch (_) {
      return _localFavorites;
    }
  }

  SearchAnalyticsSnapshot demoAnalytics() {
    return const SearchAnalyticsSnapshot(
      topTerms: [
        (label: 'Lekki', count: 412),
        (label: 'Create Property', count: 188),
        (label: 'Investor', count: 96),
      ],
      zeroResultTerms: ['payroll slip', 'legacy crm id'],
      popularCommands: [
        (label: 'Book Inspection', count: 120),
        (label: 'Add Property', count: 98),
        (label: "Today's sales summary", count: 44),
      ],
      avgLatencyMs: 38,
      adoptionByDepartment: [
        (department: 'Sales', searches: 920),
        (department: 'Finance', searches: 210),
        (department: 'Executive', searches: 145),
      ],
    );
  }

  List<CommandPaletteAction> executiveCommands({
    required Set<String> permissions,
    AppRole? role,
  }) {
    final isExec = role == AppRole.admin ||
        role == AppRole.superAdmin ||
        permissions.contains('manage_reports');
    if (!isExec) return const [];
    return EnterpriseSearchCatalog.allCommands()
        .where((c) =>
            c.label.toLowerCase().contains('sales') ||
            c.label.toLowerCase().contains('health') ||
            c.label.toLowerCase().contains('report') ||
            c.label.toLowerCase().contains('investor'))
        .toList();
  }

  Future<void> _recordAnalytics(String query, SearchQueryResult result) async {
    unawaited(
      _audit.publish(
        AuditPublishRequest(
          action: 'search_executed',
          module: 'enterprise_search',
          category: AuditEventCategory.system,
          severity: AuditSeverity.info,
          metadata: {
            'query': query,
            'mode': result.mode.name,
            'result_count': result.totalCount,
            'zero_results': result.zeroResults,
            'latency_ms': result.latencyMs,
          },
          visibleToUser: false,
        ),
      ),
    );
    final client = _client;
    if (client == null) return;
    try {
      await client.from('search_analytics').insert({
        'metric_key': result.zeroResults ? 'zero_result' : 'search',
        'metric_value': 1,
        'dimensions': {
          'query': query,
          'mode': result.mode.name,
          'latency_ms': result.latencyMs,
        },
      });
    } catch (_) {}
  }

  SearchIndexEntry _entryFromRow(Map<String, dynamic> row) {
    return SearchIndexEntry(
      id: row['entity_id'] as String? ?? row['id'] as String,
      module: SearchResultModule.fromSlug(row['module'] as String?),
      title: row['title'] as String? ?? 'Result',
      subtitle: row['subtitle'] as String?,
      path: row['path'] as String? ?? '/',
      keywords: (row['keywords'] as List?)?.map((e) => e.toString()).toList() ??
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
