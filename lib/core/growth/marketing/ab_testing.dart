import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/growth/analytics/analytics_events.dart';
import 'package:hdhomesproject/core/growth/analytics/analytics_service.dart';
import 'package:hdhomesproject/core/growth/models/growth_models.dart';
import 'package:hdhomesproject/core/growth/providers/growth_cms_provider.dart';

/// Assigns A/B test variants and tracks exposures.
final abTestAssignmentsProvider = Provider<Map<String, AbTestVariant>>((ref) {
  final experiments = ref.watch(growthHubCmsProvider).abTests;
  final random = Random(42);
  final assignments = <String, AbTestVariant>{};

  for (final exp in experiments) {
    final roll = random.nextInt(3);
    assignments[exp.id] = switch (roll) {
      0 => AbTestVariant.control,
      1 => AbTestVariant.variantA,
      _ => AbTestVariant.variantB,
    };
  }
  return assignments;
});

void trackAbTestExposure(WidgetRef ref, String experimentId, AbTestVariant variant) {
  ref.read(analyticsProvider.notifier).track(
        AnalyticsEvent(
          type: AnalyticsEventType.abTestExposure,
          name: 'ab_test_exposure',
          timestamp: DateTime.now(),
          properties: {'experimentId': experimentId, 'variant': variant.name},
        ),
      );
}

String resolveAbVariantLabel(AbTestVariant variant, List<String> variantLabels) {
  return switch (variant) {
    AbTestVariant.control => variantLabels.first,
    AbTestVariant.variantA => variantLabels.length > 1 ? variantLabels[1] : variantLabels.first,
    AbTestVariant.variantB => variantLabels.length > 2 ? variantLabels[2] : variantLabels.last,
  };
}
