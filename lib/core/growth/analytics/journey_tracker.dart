import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/growth/analytics/analytics_events.dart';
import 'package:hdhomesproject/core/growth/analytics/analytics_service.dart';
import 'package:hdhomesproject/core/growth/lead_scoring/smart_lead_scoring.dart';
import 'package:hdhomesproject/core/growth/models/growth_models.dart';
import 'package:hdhomesproject/core/growth/personalization/visitor_profile.dart';
import 'package:hdhomesproject/features/contact/data/models/contact_content.dart';
import 'package:hdhomesproject/features/contact/data/providers/lead_routing_provider.dart';

class JourneyTrackerNotifier extends Notifier<List<CustomerJourneyStage>> {
  @override
  List<CustomerJourneyStage> build() => [CustomerJourneyStage.anonymousVisitor];

  void advance(CustomerJourneyStage stage) {
    if (state.isEmpty || state.last != stage) {
      state = [...state, stage];
    }
  }
}

final journeyTrackerProvider =
    NotifierProvider<JourneyTrackerNotifier, List<CustomerJourneyStage>>(JourneyTrackerNotifier.new);

final currentJourneyStageProvider = Provider<CustomerJourneyStage>((ref) {
  final journey = ref.watch(journeyTrackerProvider);
  return journey.isEmpty ? CustomerJourneyStage.anonymousVisitor : journey.last;
});

/// Records growth events across analytics, profile, and journey.
void trackGrowthPageView(WidgetRef ref, String path, {Map<String, String>? utm}) {
  ref.read(visitorProfileProvider.notifier).recordPageView(path, utm: utm);
  ref.read(analyticsProvider.notifier).trackPageView(path, utm: utm);
}

void trackGrowthPropertyView(WidgetRef ref, String propertyId) {
  ref.read(visitorProfileProvider.notifier).recordPropertyView(propertyId);
  ref.read(analyticsProvider.notifier).trackPropertyView(propertyId);
}

void trackGrowthSearch(WidgetRef ref, String query, {Map<String, dynamic>? filters}) {
  ref.read(visitorProfileProvider.notifier).recordSearch(query);
  ref.read(analyticsProvider.notifier).trackSearch(query, filters: filters);
}

void trackGrowthLeadSubmitted(WidgetRef ref, SubmittedLead lead, SmartLeadScore smartScore) {
  ref.read(journeyTrackerProvider.notifier).advance(CustomerJourneyStage.qualifiedLead);
  ref.read(analyticsProvider.notifier).track(
        AnalyticsEvent(
          type: AnalyticsEventType.leadSubmitted,
          name: 'lead_submitted',
          timestamp: DateTime.now(),
          properties: {
            'leadId': lead.id,
            'type': lead.type,
            'score': smartScore.score,
            'temperature': smartScore.temperature.label,
            'department': lead.routing.department,
          },
        ),
      );
}

final smartLeadScoresProvider = Provider<Map<String, SmartLeadScore>>((ref) {
  final leads = ref.watch(submittedLeadsProvider);
  final profile = ref.watch(visitorProfileProvider);
  return {
    for (final lead in leads)
      lead.id: computeSmartLeadScore(baseRouting: lead.routing, profile: profile),
  };
});

// submittedLeadsProvider imported from lead_routing_provider above
