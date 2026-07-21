import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/app_role.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/enterprise_search_models.dart';

void main() {
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
    test('suggests Lekki completions', () {
      final s = EnterpriseSearchCatalog.suggest('Lek');
      expect(s.any((e) => e.label.toLowerCase().contains('lekki')), isTrue);
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
}
