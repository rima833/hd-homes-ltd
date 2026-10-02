import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/core/utils/provider_lifecycle.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A public popular property-search chip (backed by `popular_searches`).
class PopularPropertySearch {
  const PopularPropertySearch({
    required this.term,
    required this.count,
    this.lastSearchedAt,
  });

  final String term;
  final int count;
  final DateTime? lastSearchedAt;
}

final popularSearchesTickProvider = StateProvider<int>((ref) => 0);

/// Soft realtime so homepage chips refresh when someone searches.
final popularSearchesRealtimeProvider = Provider<void>((ref) {
  ref.keepAlive();
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = ref.watch(supabaseClientProvider);
  final channel = client.channel('public:popular_searches')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'popular_searches',
      callback: (_) {
        deferProviderMutation(() {
          ref.read(popularSearchesTickProvider.notifier).state++;
        });
      },
    )
    ..subscribe();
  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

/// Top real search terms only — empty until users actually search.
final popularPropertySearchesProvider =
    FutureProvider<List<PopularPropertySearch>>((ref) async {
  ref.watch(popularSearchesTickProvider);
  ref.watch(popularSearchesRealtimeProvider);
  if (!ref.watch(supabaseConfiguredProvider)) return const [];

  final client = ref.watch(supabaseClientProvider);
  try {
    final rows = await client.rpc(
      'list_popular_searches',
      params: {'p_limit': 8},
    );
    if (rows is! List) return const [];
    return rows
        .map((row) {
          final map = Map<String, dynamic>.from(row as Map);
          final term = '${map['search_term'] ?? ''}'.trim();
          if (term.isEmpty) return null;
          return PopularPropertySearch(
            term: term,
            count: (map['search_count'] as num?)?.toInt() ?? 0,
            lastSearchedAt: DateTime.tryParse(
              '${map['last_searched_at'] ?? ''}',
            ),
          );
        })
        .whereType<PopularPropertySearch>()
        .where((s) => s.count > 0)
        .toList();
  } catch (_) {
    try {
      final rows = await client
          .from('popular_searches')
          .select('search_term, search_count, last_searched_at')
          .eq('is_deleted', false)
          .eq('status', 'active')
          .order('search_count', ascending: false)
          .limit(8);
      return rows
          .map((row) {
            final map = Map<String, dynamic>.from(row as Map);
            final term = '${map['search_term'] ?? ''}'.trim();
            if (term.isEmpty) return null;
            return PopularPropertySearch(
              term: term,
              count: (map['search_count'] as num?)?.toInt() ?? 0,
              lastSearchedAt: DateTime.tryParse(
                '${map['last_searched_at'] ?? ''}',
              ),
            );
          })
          .whereType<PopularPropertySearch>()
          .toList();
    } catch (_) {
      return const [];
    }
  }
});

/// Persist a real marketplace/home search term (no-op for blank / noisy values).
Future<void> recordPopularPropertySearch(
  WidgetRef ref, {
  required String term,
}) async {
  final trimmed = term.trim();
  if (trimmed.length < 2 || !ref.read(supabaseConfiguredProvider)) return;
  try {
    await ref.read(supabaseClientProvider).rpc(
      'record_popular_search',
      params: {'p_search_term': trimmed},
    );
    deferProviderMutation(() {
      ref.read(popularSearchesTickProvider.notifier).state++;
    });
  } catch (_) {
    // Public search UX must not fail if analytics write is blocked.
  }
}

/// Prefer the most specific location label from marketplace filters.
String? popularSearchTermFromFilters({
  String? query,
  String? location,
  String? city,
  String? estate,
  String? state,
}) {
  for (final candidate in [location, estate, city, state, query]) {
    final value = candidate?.trim() ?? '';
    if (value.length >= 2) return value;
  }
  return null;
}
