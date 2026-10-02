import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/app_role.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/enterprise_search_models.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/portal_search_catalog.dart';

void main() {
  group('empty-query counts (footer probe)', () {
    test('client empty query is near the reported 34 results', () {
      final index = [
        ...EnterpriseSearchCatalog.seedIndex(),
        ...PortalSearchCatalog.allEntries(),
      ];
      final byId = <String, SearchIndexEntry>{};
      for (final e in index) {
        byId.putIfAbsent(e.id, () => e);
      }
      final scoped = byId.values.where(
        (e) => PortalSearchCatalog.isPathAllowedForRole(e.path, AppRole.client),
      );
      final ranked = SearchRankingEngine.rank(
        scoped,
        '',
        permissions: {},
        isStaff: false,
        role: AppRole.client,
      );
      final groups = SearchRankingEngine.group(ranked);
      final total = groups.fold<int>(0, (s, g) => s + g.items.length);
      // Matches the reported command-palette footer ("34 results · …ms")
      // when the remote search_index is empty and portal+seed catalogs apply.
      expect(total, 34);
    });
  });

  group('SearchRankingEngine permissions', () {
    final payroll = SearchIndexEntry(
      id: 'payroll',
      module: SearchResultModule.report,
      title: 'Payroll Report',
      path: '/dashboard/finance',
      permissionSlug: 'manage_reports',
    );
    final property = SearchIndexEntry(
      id: 'prop-1',
      module: SearchResultModule.property,
      title: 'Lekki Phase 1 Villa',
      path: '/properties/1',
      keywords: const ['lekki', 'villa'],
      popularity: 80,
    );

    test('sales user cannot see executive reports', () {
      expect(
        SearchRankingEngine.canView(
          payroll,
          permissions: {'manage_crm', 'view_properties'},
          isStaff: true,
          role: AppRole.salesTeam,
        ),
        isFalse,
      );
    });

    test('admin can see restricted modules', () {
      expect(
        SearchRankingEngine.canView(
          payroll,
          permissions: {},
          isStaff: true,
          role: AppRole.admin,
        ),
        isTrue,
      );
    });

    test('properties are visible without special permission', () {
      expect(
        SearchRankingEngine.canView(
          property,
          permissions: {},
          isStaff: false,
          role: AppRole.client,
        ),
        isTrue,
      );
    });
  });

  group('ranking and grouping', () {
    test('exact title ranks above partial', () {
      final index = EnterpriseSearchCatalog.seedIndex();
      final ranked = SearchRankingEngine.rank(
        index,
        'Create Property',
        permissions: {'edit_property'},
        isStaff: true,
        role: AppRole.salesTeam,
      );
      expect(ranked, isNotEmpty);
      expect(ranked.first.title.toLowerCase(), contains('create property'));
    });

    test('groups results by module', () {
      final index = EnterpriseSearchCatalog.seedIndex();
      final ranked = SearchRankingEngine.rank(
        index,
        'lekki',
        permissions: {},
        isStaff: false,
        role: AppRole.client,
      );
      final groups = SearchRankingEngine.group(ranked);
      expect(groups, isNotEmpty);
      expect(groups.first.label, contains('('));
    });

    test('commands mode returns only commands', () {
      final ranked = SearchRankingEngine.rank(
        EnterpriseSearchCatalog.seedIndex(),
        '',
        permissions: {'edit_property', 'manage_reports', 'view_audit_logs'},
        isStaff: true,
        role: AppRole.admin,
        mode: SearchMode.commands,
      );
      expect(
        ranked.every((r) => r.module == SearchResultModule.command),
        isTrue,
      );
    });
  });

  group('SemanticSearchFoundation', () {
    test('expands house ↔ property synonyms', () {
      final expanded = SemanticSearchFoundation.expand('house');
      expect(expanded, contains('property'));
    });

    test('parses natural language property intent', () {
      final intent = SemanticSearchFoundation.parseIntent(
        'Show available 4-bedroom homes in Lekki under ₦250M',
      );
      expect(intent.location?.toLowerCase(), contains('lekki'));
      expect(intent.minBedrooms, 4);
      expect(intent.maxPrice, 250000000);
      expect(intent.status, 'Available');
    });
  });

  group('suggestions and cross-module links', () {
    test('suggests actions from the production command catalog', () {
      final suggestions = EnterpriseSearchCatalog.suggest('properties');
      expect(suggestions, isNotEmpty);
      expect(suggestions.every((item) => item.kind == 'command'), isTrue);
      expect(
        suggestions.any(
          (item) => item.label.toLowerCase().contains('properties'),
        ),
        isTrue,
      );
    });

    test('related links surface for property hits', () {
      final property = EnterpriseSearchCatalog.seedIndex().firstWhere(
        (e) => e.id == 'prop-lekki-pearl',
      );
      final related = SearchRankingEngine.relatedFor(
        property,
        EnterpriseSearchCatalog.seedIndex(),
        permissions: {'manage_crm', 'view_users', 'view_properties'},
        isStaff: true,
        role: AppRole.salesTeam,
      );
      expect(related, isNotEmpty);
      expect(
        related.map((r) => r.entry.id),
        containsAll(['staff-ada', 'booking-lekki-1', 'doc-brochure-1']),
      );
    });
  });

  group('SearchAnalyticsSnapshot', () {
    test('parses privacy-safe RPC aggregates', () {
      final snapshot = SearchAnalyticsSnapshot.fromJson({
        'loaded_at': '2026-09-09T08:00:00Z',
        'period_days': 30,
        'total_searches': 125,
        'unique_searchers': 18,
        'zero_result_count': 5,
        'avg_latency_ms': 42.5,
        'top_terms': [
          {'label': 'lekki', 'count': 24},
        ],
        'zero_result_terms': [
          {'label': 'penthouse', 'count': 3},
        ],
        'popular_modes': [
          {'label': 'properties', 'count': 80},
        ],
        'daily_series': [
          {'date': '2026-09-09', 'searches': 12, 'zero_results': 1},
        ],
      });

      expect(snapshot.totalSearches, 125);
      expect(snapshot.topTerms.single.label, 'lekki');
      expect(snapshot.popularModes.single.count, 80);
      expect(snapshot.dailySeries.single.zeroResults, 1);
      expect(snapshot.zeroResultRate, closeTo(0.04, 0.0001));
      expect(snapshot.isEmpty, isFalse);
    });

    test('represents an empty live period without demo values', () {
      final snapshot = SearchAnalyticsSnapshot.fromJson({
        'period_days': 7,
        'total_searches': 0,
      });

      expect(snapshot.isEmpty, isTrue);
      expect(snapshot.topTerms, isEmpty);
      expect(snapshot.zeroResultTerms, isEmpty);
      expect(snapshot.popularModes, isEmpty);
      expect(snapshot.zeroResultRate, 0);
    });
  });
}
