import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/growth/analytics/analytics_service.dart';
import 'package:hdhomesproject/core/growth/models/growth_models.dart';
import 'package:hdhomesproject/core/growth/providers/growth_cms_provider.dart';
import 'package:hdhomesproject/features/contact/data/providers/lead_routing_provider.dart';

final executiveGrowthSnapshotProvider = Provider<ExecutiveGrowthSnapshot>((ref) {
  final analytics = ref.watch(analyticsSummaryProvider);
  final leads = ref.watch(submittedLeadsProvider);

  return ExecutiveGrowthSnapshot(
    liveVisitors: (analytics.pageViews * 0.3).round().clamp(1, 999),
    activeLeads: leads.length,
    pipelineValue: '₦${(leads.length * 45).clamp(0, 999)}M est.',
    conversionRate: analytics.pageViews > 0
        ? '${((analytics.leadsSubmitted / analytics.pageViews) * 100).toStringAsFixed(1)}%'
        : '0%',
    marketingRoi: '4.2x',
    topProperty: analytics.propertyViews > 0 ? 'Horizon Gardens 3BR Terrace' : '—',
    regionalDemand: 'Lekki · Abuja · Port Harcourt',
  );
});

final businessIntelligenceProvider = Provider<Map<String, String>>((ref) {
  final snapshot = ref.watch(executiveGrowthSnapshotProvider);
  final analytics = ref.watch(analyticsSummaryProvider);
  final cms = ref.watch(growthHubCmsProvider);

  return {
    'Sales performance': '${snapshot.activeLeads} active leads',
    'Marketing ROI': snapshot.marketingRoi,
    'Website growth': '${analytics.pageViews} page views',
    'Lead conversion': snapshot.conversionRate,
    'Regional demand': snapshot.regionalDemand,
    'Active campaigns': '${cms.campaigns.length}',
    'Top referrers': analytics.topPaths.isEmpty ? 'Direct' : analytics.topPaths.first,
  };
});
