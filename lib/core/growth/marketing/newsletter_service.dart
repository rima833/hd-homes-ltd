import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/growth/analytics/analytics_events.dart';
import 'package:hdhomesproject/core/growth/analytics/analytics_service.dart';
import 'package:hdhomesproject/core/growth/models/growth_models.dart';

final newsletterSubscribersProvider = StateProvider<List<NewsletterSubscriber>>((ref) => []);

bool subscribeNewsletter(WidgetRef ref, {required String email, List<String> topics = const ['Property updates']}) {
  final normalized = email.trim().toLowerCase();
  if (normalized.isEmpty || !normalized.contains('@')) return false;

  final existing = ref.read(newsletterSubscribersProvider);
  if (existing.any((s) => s.email == normalized)) return true;

  ref.read(newsletterSubscribersProvider.notifier).update(
        (s) => [
          NewsletterSubscriber(email: normalized, subscribedAt: DateTime.now(), topics: topics),
          ...s,
        ],
      );

  ref.read(analyticsProvider.notifier).track(
        AnalyticsEvent(
          type: AnalyticsEventType.newsletterSubscribe,
          name: 'newsletter_subscribe',
          timestamp: DateTime.now(),
          properties: {'email': normalized, 'topics': topics},
        ),
      );

  return true;
}
