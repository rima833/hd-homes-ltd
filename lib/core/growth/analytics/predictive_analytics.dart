import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/growth/analytics/analytics_service.dart';
import 'package:hdhomesproject/core/growth/models/growth_models.dart';
import 'package:hdhomesproject/core/growth/personalization/visitor_profile.dart';
import 'package:hdhomesproject/features/search/data/providers/search_intelligence_provider.dart';

final predictiveInsightsProvider = Provider<List<PredictiveInsight>>((ref) {
  final profile = ref.watch(visitorProfileProvider);
  final analytics = ref.watch(analyticsSummaryProvider);
  final searchAnalytics = ref.watch(searchAnalyticsProvider);

  return [
    PredictiveInsight(
      title: 'Emerging hotspot',
      prediction: profile.preferredLocations.isNotEmpty
          ? '${profile.preferredLocations.first} demand up 18% QoQ'
          : 'Lekki corridor demand up 18% QoQ',
      confidence: 82,
      category: 'Location',
    ),
    PredictiveInsight(
      title: 'High-demand property type',
      prediction: '3–4 bedroom terraces outperforming duplexes',
      confidence: 76,
      category: 'Inventory',
    ),
    PredictiveInsight(
      title: 'Lead quality forecast',
      prediction: analytics.leadsSubmitted > 0
          ? 'Lead volume stable — prioritize hot leads within 24h'
          : 'Increase top-of-funnel content to grow qualified leads',
      confidence: 71,
      category: 'Sales',
    ),
    PredictiveInsight(
      title: 'Seasonal pattern',
      prediction: 'Q2 historically peaks for inspection bookings',
      confidence: 88,
      category: 'Seasonality',
    ),
    PredictiveInsight(
      title: 'Search intent',
      prediction: searchAnalytics.favoriteLocations.isNotEmpty
          ? 'Strong interest in ${searchAnalytics.favoriteLocations.take(2).join(' & ')}'
          : 'Broad discovery searches — refine filters for conversion',
      confidence: 74,
      category: 'Marketing',
    ),
  ];
});
