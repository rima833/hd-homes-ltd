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
}
