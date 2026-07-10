import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/growth/analytics/analytics_events.dart';
import 'package:hdhomesproject/core/growth/consent/consent_gate.dart';

/// In-memory analytics buffer (Supabase `analytics_events` in Volume 1.5).
class AnalyticsNotifier extends Notifier<List<AnalyticsEvent>> {
  static const _maxEvents = 500;

  @override
  List<AnalyticsEvent> build() => [];

  void track(AnalyticsEvent event) {
    if (!ref.read(consentGateProvider)) return;
    state = [event, ...state].take(_maxEvents).toList();
  }

  void trackPageView(String path, {Map<String, String>? utm}) {
    track(
      AnalyticsEvent(
        type: AnalyticsEventType.pageView,
        name: 'page_view',
        timestamp: DateTime.now(),
        path: path,
        utmSource: utm?['utm_source'],
        utmCampaign: utm?['utm_campaign'],
      ),
    );
  }

  void trackPropertyView(String propertyId) {
    track(
      AnalyticsEvent(
        type: AnalyticsEventType.propertyView,
        name: 'property_view',
        timestamp: DateTime.now(),
        entityId: propertyId,
      ),
    );
  }

  void trackSearch(String query, {Map<String, dynamic>? filters}) {
    track(
      AnalyticsEvent(
        type: AnalyticsEventType.search,
        name: 'search',
        timestamp: DateTime.now(),
        properties: {'query': query, if (filters != null) 'filters': filters},
      ),
    );
  }
}

final analyticsProvider =
    NotifierProvider<AnalyticsNotifier, List<AnalyticsEvent>>(AnalyticsNotifier.new);

final analyticsSummaryProvider = Provider<AnalyticsSummary>((ref) {
  final events = ref.watch(analyticsProvider);
  final pageViews = events.where((e) => e.type == AnalyticsEventType.pageView).length;
  final searches = events.where((e) => e.type == AnalyticsEventType.search).length;
  final propertyViews = events.where((e) => e.type == AnalyticsEventType.propertyView).length;
  final leads = events.where((e) => e.type == AnalyticsEventType.leadSubmitted).length;

  return AnalyticsSummary(
    totalEvents: events.length,
    pageViews: pageViews,
    searches: searches,
    propertyViews: propertyViews,
    leadsSubmitted: leads,
    topPaths: _topPaths(events),
  );
});

class AnalyticsSummary {
  const AnalyticsSummary({
    required this.totalEvents,
    required this.pageViews,
    required this.searches,
    required this.propertyViews,
    required this.leadsSubmitted,
    required this.topPaths,
  });

  final int totalEvents;
  final int pageViews;
  final int searches;
  final int propertyViews;
  final int leadsSubmitted;
  final List<String> topPaths;
}

List<String> _topPaths(List<AnalyticsEvent> events) {
  final counts = <String, int>{};
  for (final e in events) {
    if (e.path != null) counts[e.path!] = (counts[e.path!] ?? 0) + 1;
  }
  final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return sorted.take(5).map((e) => e.key).toList();
}
