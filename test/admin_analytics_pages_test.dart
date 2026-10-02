import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/enterprise_search_models.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/personalization_models.dart';
import 'package:hdhomesproject/features/authentication/presentation/pages/personalization_analytics_page.dart';
import 'package:hdhomesproject/features/authentication/presentation/pages/search_insights_page.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/enterprise_search_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/personalization_controller.dart';

void main() {
  for (final size in const [Size(1440, 900), Size(768, 700), Size(390, 700)]) {
    testWidgets('Search Insights has no overflow at ${size.width}', (
      tester,
    ) async {
      _setSize(tester, size);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            searchAnalyticsProvider.overrideWith(
              (ref, days) async => _searchSnapshot,
            ),
            searchAnalyticsRealtimeStateProvider.overrideWith(
              (ref) => SearchAnalyticsRealtimeState.live,
            ),
          ],
          child: const MaterialApp(home: SearchInsightsPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Search performance'), findsOneWidget);
      expect(find.text('Total searches'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Personalization Analytics has no overflow at ${size.width}', (
      tester,
    ) async {
      _setSize(tester, size);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            personalizationAnalyticsProvider.overrideWith(
              (ref) async => _personalizationSnapshot,
            ),
            personalizationAnalyticsRealtimeStateProvider.overrideWith(
              (ref) => PersonalizationAnalyticsRealtimeState.live,
            ),
          ],
          child: const MaterialApp(home: PersonalizationAnalyticsPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Preference center adoption'), findsOneWidget);
      expect(find.text('Preference profiles'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

final _searchSnapshot = SearchAnalyticsSnapshot(
  loadedAt: DateTime.utc(2026, 9, 9, 9),
  periodDays: 30,
  totalSearches: 20,
  uniqueSearchers: 7,
  zeroResultCount: 2,
  avgLatencyMs: 38,
  topTerms: const [SearchAnalyticsCount(label: 'properties', count: 8)],
  zeroResultTerms: const [SearchAnalyticsCount(label: 'duplex', count: 2)],
  popularModes: const [SearchAnalyticsCount(label: 'universal', count: 20)],
  dailySeries: [
    SearchAnalyticsDailyPoint(
      date: DateTime.utc(2026, 9, 8),
      searches: 8,
      zeroResults: 1,
    ),
    SearchAnalyticsDailyPoint(
      date: DateTime.utc(2026, 9, 9),
      searches: 12,
      zeroResults: 1,
    ),
  ],
);

final _personalizationSnapshot = PersonalizationAnalyticsSnapshot(
  loadedAt: DateTime(2026, 9, 9, 9),
  periodDays: 30,
  preferenceProfiles: 12,
  accessibilityAdoptionPct: 16.7,
  savedSearches: 5,
  favorites: 14,
  dashboardLayouts: 8,
  workspaceSwitchesToday: 3,
  themeDistribution: const [
    PersonalizationMetricBreakdown(label: 'system', count: 7),
    PersonalizationMetricBreakdown(label: 'dark', count: 5),
  ],
  eventsByType: const [
    PersonalizationMetricBreakdown(label: 'layout_updated', count: 4),
  ],
  favoriteTypes: const [
    PersonalizationMetricBreakdown(label: 'property', count: 14),
  ],
  dailySeries: [
    PersonalizationDailyMetric(date: DateTime(2026, 9, 9), events: 4),
  ],
);
