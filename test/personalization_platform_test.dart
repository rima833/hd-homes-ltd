import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/app_role.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/personalization_models.dart';

void main() {
  group('PreferenceEngine greetings', () {
    test('morning salutation uses first name', () {
      final g = PreferenceEngine.buildGreeting(
        displayName: 'Rima Okoro',
        now: DateTime(2026, 7, 13, 9),
        newMatches: 3,
        unreadMessages: 2,
        upcomingInspections: 1,
      );
      expect(g.salutation, 'Good morning');
      expect(g.displayName, 'Rima');
      expect(g.highlights, contains('3 new property matches'));
      expect(g.highlights, contains('2 unread messages'));
      expect(g.highlights, contains('1 upcoming inspection(s)'));
    });

    test('evening fallback welcome when no highlights', () {
      final g = PreferenceEngine.buildGreeting(
        displayName: 'Ada',
        now: DateTime(2026, 7, 13, 20),
      );
      expect(g.salutation, 'Good evening');
      expect(g.highlights.first, contains('Welcome back'));
    });
  });

  group('role default widgets', () {
    test('client dashboard includes saved properties', () {
      final widgets = PreferenceEngine.defaultWidgetsForRole(AppRole.client);
      expect(
        widgets.map((w) => w.widgetId),
        contains(DashboardWidgetId.savedProperties),
      );
    });

    test('investor dashboard includes portfolio value', () {
      final layout = PreferenceEngine.defaultLayoutForRole(AppRole.investor);
      expect(layout.name, 'Investor Dashboard');
      expect(
        layout.widgets.map((w) => w.widgetId),
        contains(DashboardWidgetId.portfolioValue),
      );
    });

    test('admin dashboard includes executive KPIs', () {
      final widgets = PreferenceEngine.defaultWidgetsForRole(AppRole.admin);
      expect(
        widgets.map((w) => w.widgetId),
        contains(DashboardWidgetId.executiveKpis),
      );
    });
  });

  group('adaptive suggestions', () {
    test('suggests quick action after frequent report views', () {
      final s = PreferenceEngine.suggestFromBehavior(
        investmentReportViews: 5,
        lekkiSearches: 0,
        unusedWidgetDays: 0,
      );
      expect(s, isNotEmpty);
      expect(s.first.actionKey, 'add_shortcut_investment_reports');
    });

    test('suggests saving Lekki search', () {
      final s = PreferenceEngine.suggestFromBehavior(
        investmentReportViews: 0,
        lekkiSearches: 3,
        unusedWidgetDays: 0,
      );
      expect(s.single.actionKey, 'save_search_lekki');
    });
  });

  group('layout engine', () {
    test('toggle widget visibility', () {
      final layout = PreferenceEngine.defaultLayoutForRole(AppRole.client);
      final id = DashboardWidgetId.messages;
      final next = PreferenceEngine.toggleWidgetVisibility(layout, id);
      final before = layout.widgets.firstWhere((w) => w.widgetId == id).visible;
      final after = next.widgets.firstWhere((w) => w.widgetId == id).visible;
      expect(after, !before);
    });

    test('reorder widget updates order indices', () {
      final layout = PreferenceEngine.defaultLayoutForRole(AppRole.client);
      final last = layout.widgets.last.widgetId;
      final next = PreferenceEngine.reorderWidget(layout, last, 0);
      expect(next.widgets.first.widgetId, last);
      expect(next.widgets.first.order, 0);
    });
  });

  group('recommendation foundation', () {
    test('uses interest city and type', () {
      const interests = PropertyInterestProfile(
        cities: ['Lekki'],
        propertyTypes: ['duplex'],
        minBedrooms: 4,
      );
      final recs = PreferenceEngine.recommendProperties(interests);
      expect(recs.first, contains('duplex'));
      expect(recs.first, contains('Lekki'));
      expect(recs, anyElement(contains('4+')));
    });
  });

  group('personalization analytics', () {
    test('parses the aggregate RPC response without user-level data', () {
      final snapshot = PersonalizationAnalyticsSnapshot.fromJson({
        'loaded_at': '2026-09-09T08:30:00Z',
        'period_days': 30,
        'preference_profiles': 42,
        'accessibility_adoption_pct': 16.7,
        'saved_searches': 18,
        'favorites': 73,
        'dashboard_layouts': 24,
        'workspace_switches_today': 9,
        'theme_distribution': [
          {'label': 'dark', 'count': 25},
          {'label': 'system', 'count': 17},
        ],
        'events_by_type': [
          {'label': 'layout_updated', 'count': 12},
          {'label': 'favorite_added', 'count': 8},
        ],
        'favorite_types': [
          {'label': 'property', 'count': 3},
        ],
        'daily_series': [
          {'date': '2026-09-08', 'events': 7},
          {'date': '2026-09-09', 'events': 13},
        ],
      });

      expect(snapshot.periodDays, 30);
      expect(snapshot.preferenceProfiles, 42);
      expect(snapshot.accessibilityAdoptionPct, 16.7);
      expect(snapshot.totalEvents, 20);
      expect(snapshot.dailySeries.last.events, 13);
      expect(snapshot.isEmpty, isFalse);
      expect(snapshot.eventsByType.first.displayLabel, 'Layout Updated');
      expect(snapshot.favoriteTypes.single.displayLabel, 'Property');
    });

    test('recognizes an empty aggregate response', () {
      final snapshot = PersonalizationAnalyticsSnapshot.fromJson({
        'period_days': 7,
        'theme_distribution': <Object>[],
        'events_by_type': <Object>[],
        'daily_series': [
          {'date': '2026-09-09', 'events': 0},
        ],
      });

      expect(snapshot.isEmpty, isTrue);
    });

    test('event metric values match the constrained RPC contract', () {
      expect(
        PersonalizationEventMetric.values.map((metric) => metric.rpcValue),
        {
          'theme_changed',
          'accessibility_updated',
          'layout_updated',
          'workspace_switched',
          'saved_search_created',
          'favorite_added',
        },
      );
    });
  });
}
