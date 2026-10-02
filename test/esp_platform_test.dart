import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/features/esp/domain/entities/esp_models.dart';
import 'package:hdhomesproject/features/esp/domain/services/esp_service.dart';
import 'package:hdhomesproject/features/esp/presentation/providers/esp_controller.dart';

void main() {
  group('EspDemo', () {
    test('snapshot covers every command-center surface', () {
      final snap = EspDemo.snapshot();
      expect(snap.kpis, isNotEmpty);
      expect(snap.sessions, isNotEmpty);
      expect(snap.alerts, isNotEmpty);
      expect(snap.threats, isNotEmpty);
      expect(snap.incidents, isNotEmpty);
      expect(snap.mfa, isNotEmpty);
      expect(snap.audit, isNotEmpty);
      expect(snap.privacy, isNotEmpty);
      expect(snap.secrets, isNotEmpty);
      expect(snap.backups, isNotEmpty);
      expect(snap.disasterRecovery, isNotEmpty);
      expect(snap.aiSecurity, isNotEmpty);
      expect(snap.insights, isNotEmpty);
      expect(snap.activity, isNotEmpty);
      expect(snap.fromRemote, isFalse);
    });

    test('security KPI strip has posture and resilience metrics', () {
      final labels = EspDemo.snapshot().kpis.map((item) => item.label);
      expect(
        labels,
        containsAll([
          'Security Score',
          'Open Alerts',
          'Critical Threats',
          'MFA Coverage',
          'Backup Success',
          'DR Readiness',
        ]),
      );
    });

    test('AI security insights are editable advisory output', () {
      final snap = EspDemo.snapshot();
      expect(snap.aiDisclaimer.toLowerCase(), contains('ai-generated'));
      expect(snap.aiDisclaimer.toLowerCase(), contains('editable'));
      expect(snap.aiDisclaimer.toLowerCase(), contains('advisory'));
      for (final insight in snap.insights) {
        expect(insight.editable, isTrue);
        expect(insight.confidencePct, isNotNull);
        expect(insight.disclaimer, kEspAiDisclaimer);
      }
    });

    test('SOC register includes critical threat and open incident', () {
      final snap = EspDemo.snapshot();
      expect(
        snap.threats.any((item) => item.severity == EspSeverity.critical),
        isTrue,
      );
      expect(
        snap.incidents.any((item) => item.status == 'investigating'),
        isTrue,
      );
      expect(snap.privacy.any((item) => item.status == 'open'), isTrue);
      expect(snap.backups.any((item) => item.status == 'succeeded'), isTrue);
    });
  });

  group('EspService', () {
    test('offline service returns demo command center', () async {
      final snap = await EspService().loadCommandCenter();
      expect(snap.fromRemote, isFalse);
      expect(snap.kpis.length, greaterThanOrEqualTo(6));
      expect(snap.alerts, isNotEmpty);
    });

    test('briefing includes incident, threat, and advisory language', () {
      final briefing = EspService()
          .generateSecurityBriefing(EspDemo.snapshot())
          .toLowerCase();
      expect(briefing, contains('threat'));
      expect(briefing, contains('incident'));
      expect(briefing, contains('advisory'));
    });

    test('signals flag critical threats, incidents, and privacy', () {
      final signals = EspService.detectSecuritySignals(EspDemo.snapshot());
      expect(
        signals.any((item) => item.toLowerCase().contains('threat')),
        isTrue,
      );
      expect(
        signals.any((item) => item.toLowerCase().contains('incident')),
        isTrue,
      );
      expect(
        signals.any((item) => item.toLowerCase().contains('privacy')),
        isTrue,
      );
    });
  });

  group('EspController contract', () {
    test('tabs cover enterprise security surfaces without state-in-build', () {
      expect(
        EspCommandTab.values.map((tab) => tab.name),
        containsAll([
          'overview',
          'iam',
          'mfa',
          'threats',
          'incidents',
          'audit',
          'privacy',
          'secrets',
          'backup',
          'dr',
          'analytics',
          'ai',
        ]),
      );
      const initial = EspUiState();
      expect(initial.selectedTab, EspCommandTab.overview);
      expect(initial.tickerIndex, 0);
      expect(initial.copyWith(tickerIndex: 1).tickerIndex, 1);
    });
  });
}
