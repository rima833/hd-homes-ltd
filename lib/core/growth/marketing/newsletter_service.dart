import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/growth/analytics/analytics_events.dart';
import 'package:hdhomesproject/core/growth/analytics/analytics_service.dart';
import 'package:hdhomesproject/core/growth/models/growth_models.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/core/utils/app_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final newsletterSubscribersProvider =
    StateProvider<List<NewsletterSubscriber>>((ref) => []);

/// Persists a newsletter subscription to Supabase `newsletter`.
///
/// Returns true when the email is accepted (new or already subscribed).
/// Throws [StateError] when Supabase is offline so the UI can show a real error.
Future<bool> subscribeNewsletter(
  WidgetRef ref, {
  required String email,
  String? name,
  List<String> topics = const ['Property updates'],
}) async {
  final normalized = email.trim().toLowerCase();
  if (normalized.isEmpty || !normalized.contains('@')) return false;

  final existing = ref.read(newsletterSubscribersProvider);
  if (existing.any((s) => s.email == normalized)) return true;

  if (!ref.read(supabaseConfiguredProvider)) {
    throw StateError('Newsletter signup is temporarily unavailable.');
  }

  final client = ref.read(supabaseClientProvider);

  try {
    await client.from('newsletter').upsert(
      {
        'email': normalized,
        'is_subscribed': true,
        'subscribed_at': DateTime.now().toUtc().toIso8601String(),
        'status': 'active',
        'is_deleted': false,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'email',
    );
  } on PostgrestException catch (e, st) {
    AppLogger.error('Newsletter subscribe failed', error: e, stackTrace: st);
    final msg = e.message.toLowerCase();
    if (!(msg.contains('duplicate') || msg.contains('unique'))) {
      throw StateError('Unable to subscribe right now. Please try again.');
    }
  } catch (e, st) {
    AppLogger.error('Newsletter subscribe failed', error: e, stackTrace: st);
    throw StateError('Unable to subscribe right now. Please try again.');
  }

  ref.read(newsletterSubscribersProvider.notifier).update(
        (s) => [
          NewsletterSubscriber(
            email: normalized,
            subscribedAt: DateTime.now(),
            topics: topics,
          ),
          ...s,
        ],
      );

  ref.read(analyticsProvider.notifier).track(
        AnalyticsEvent(
          type: AnalyticsEventType.newsletterSubscribe,
          name: 'newsletter_subscribe',
          timestamp: DateTime.now(),
          properties: {
            'email': normalized,
            if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
            'topics': topics,
          },
        ),
      );

  return true;
}
