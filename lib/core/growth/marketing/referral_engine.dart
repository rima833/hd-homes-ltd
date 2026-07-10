import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/growth/analytics/analytics_events.dart';
import 'package:hdhomesproject/core/growth/analytics/analytics_service.dart';
import 'package:hdhomesproject/core/growth/models/growth_models.dart';
import 'package:hdhomesproject/core/website/seo/seo_config.dart';

final referralLinksProvider = StateProvider<List<ReferralLink>>((ref) => [
      ReferralLink(
        code: 'HD-REF-DEMO',
        url: '${SeoConfig.siteUrl}/properties?ref=HD-REF-DEMO',
        clicks: 42,
        conversions: 3,
      ),
    ]);

ReferralLink generateReferralLink(WidgetRef ref, {required String userCode}) {
  final code = 'HD-$userCode';
  final link = ReferralLink(
    code: code,
    url: '${SeoConfig.siteUrl}/properties?ref=$code',
    clicks: 0,
    conversions: 0,
  );
  ref.read(referralLinksProvider.notifier).update((s) => [link, ...s]);
  return link;
}

void trackReferralClick(WidgetRef ref, String code) {
  ref.read(analyticsProvider.notifier).track(
        AnalyticsEvent(
          type: AnalyticsEventType.referralClick,
          name: 'referral_click',
          timestamp: DateTime.now(),
          properties: {'code': code},
        ),
      );
}
