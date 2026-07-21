import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/notification_models.dart';

void main() {
  group('NotificationTemplateEngine', () {
    test('replaces variables and strips unknowns', () {
      final out = NotificationTemplateEngine.render(
        'Hello {{first_name}}, ref {{booking_reference}} {{missing}}',
        {'first_name': 'Ada', 'booking_reference': 'BK-1'},
      );
      expect(out, 'Hello Ada, ref BK-1');
    });
  });

  group('SmartCommunicationOrchestrator', () {
    test('respects quiet hours for normal priority', () {
      const prefs = CommunicationChannelPrefs(
        quietHours: QuietHours(enabled: true, startHour: 22, endHour: 7),
      );
      final plan = SmartCommunicationOrchestrator.plan(
        requested: const [NotificationChannel.inApp, NotificationChannel.email],
        prefs: prefs,
        priority: NotificationPriority.normal,
        type: NotificationType.information,
        now: DateTime(2026, 7, 13, 23),
      );
      expect(plan.sendImmediately, isFalse);
      expect(plan.reason, 'quiet_hours');
      expect(plan.channels, isNotEmpty);
    });

    test('critical bypasses quiet hours', () {
      const prefs = CommunicationChannelPrefs(
        quietHours: QuietHours(enabled: true, startHour: 22, endHour: 7),
      );
      final plan = SmartCommunicationOrchestrator.plan(
        requested: const [NotificationChannel.inApp, NotificationChannel.email],
        prefs: prefs,
        priority: NotificationPriority.critical,
        type: NotificationType.critical,
        now: DateTime(2026, 7, 13, 23),
      );
      expect(plan.sendImmediately, isTrue);
    });

    test('skips marketing when opted out', () {
      const prefs = CommunicationChannelPrefs(marketing: false);
      final plan = SmartCommunicationOrchestrator.plan(
        requested: const [NotificationChannel.email],
        prefs: prefs,
        priority: NotificationPriority.normal,
        type: NotificationType.marketing,
      );
      // Falls back to in-app if empty
      expect(plan.channels, contains(NotificationChannel.inApp));
    });
  });

  group('QuietHours', () {
    test('detects wrap-around window', () {
      const q = QuietHours(enabled: true, startHour: 22, endHour: 7);
      expect(q.isQuiet(DateTime(2026, 1, 1, 23)), isTrue);
      expect(q.isQuiet(DateTime(2026, 1, 1, 6)), isTrue);
      expect(q.isQuiet(DateTime(2026, 1, 1, 12)), isFalse);
    });
  });
}
