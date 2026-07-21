import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/features/eip/domain/entities/eip_models.dart';
import 'package:hdhomesproject/features/eip/domain/services/eip_service.dart';
import 'package:hdhomesproject/features/eip/presentation/providers/eip_controller.dart';

void main() {
  group('EipDemo', () {
    test('snapshot is non-empty across command-center surfaces', () {
      final snap = EipDemo.snapshot();
      expect(snap.kpis, isNotEmpty);
      expect(snap.apiServices, isNotEmpty);
      expect(snap.apiConsumers, isNotEmpty);
      expect(snap.workflows, isNotEmpty);
      expect(snap.workflowTasks, isNotEmpty);
      expect(snap.workflowApprovals, isNotEmpty);
      expect(snap.domainEvents, isNotEmpty);
      expect(snap.queues, isNotEmpty);
      expect(snap.queueItems, isNotEmpty);
      expect(snap.webhooks, isNotEmpty);
      expect(snap.webhookDeliveries, isNotEmpty);
      expect(snap.connectors, isNotEmpty);
      expect(snap.securityPolicies, isNotEmpty);
      expect(snap.healthChecks, isNotEmpty);
      expect(snap.serviceRegistry, isNotEmpty);
      expect(snap.featureFlags, isNotEmpty);
      expect(snap.configSettings, isNotEmpty);
      expect(snap.reports, isNotEmpty);
      expect(snap.aiInsights, isNotEmpty);
      expect(snap.activities, isNotEmpty);
      expect(snap.fromRemote, isFalse);
    });

    test('KPI strip includes integration command-center labels', () {
      final snap = EipDemo.snapshot();
      expect(
        snap.kpis.map((k) => k.label),
        containsAll([
          'API Services',
          'Active Workflows',
          'Events 24h',
          'Queue Depth',
          'Webhook Failures',
        ]),
      );
    });

    test('AI insights carry editable advisory disclaimer', () {
      final snap = EipDemo.snapshot();
      expect(snap.aiDisclaimer.toLowerCase(), contains('ai-generated'));
      expect(snap.aiDisclaimer.toLowerCase(), contains('editable'));
      expect(snap.aiDisclaimer.toLowerCase(), contains('advisory'));
      for (final insight in snap.aiInsights) {
        expect(insight.disclaimer.toLowerCase(), contains('ai-generated'));
        expect(insight.editable, isTrue);
        expect(insight.confidencePct, isNotNull);
      }
    });

    test('register spans apis workflows events queues connectors', () {
      final snap = EipDemo.snapshot();
      expect(snap.apiServices.length, greaterThanOrEqualTo(3));
      expect(
        snap.domainEvents.any((e) => e.eventType == 'PaymentCompleted'),
        isTrue,
      );
      expect(snap.workflows.any((w) => w.eipEnabled), isTrue);
      expect(snap.workflowApprovals.any((a) => a.isPending), isTrue);
      expect(snap.webhookDeliveries.any((d) => d.isFailed), isTrue);
      expect(snap.queueItems.any((i) => i.isFailed), isTrue);
      expect(snap.connectors.any((c) => c.providerSlug == 'paystack'), isTrue);
      expect(snap.healthChecks.any((h) => h.isWatch), isTrue);
    });
  });

  group('EipService', () {
    test('offline client returns demo command center', () async {
      final service = EipService();
      final snap = await service.loadCommandCenter();
      expect(snap.fromRemote, isFalse);
      expect(snap.kpis.length, greaterThanOrEqualTo(5));
      expect(snap.apiServices, isNotEmpty);
    });

    test('ops briefing stub includes disclaimer and signals', () {
      final service = EipService();
      final snap = EipDemo.snapshot();
      final briefing = service.generateOpsBriefing(snap);
      expect(briefing.toLowerCase(), contains('operations'));
      expect(briefing.toLowerCase(), contains('advisory'));
      expect(briefing.toLowerCase(), contains('webhook'));
    });

    test('integration signals flag webhooks queues health and approvals', () {
      final snap = EipDemo.snapshot();
      final signals = EipService.detectIntegrationSignals(snap);
      expect(signals, isNotEmpty);
      expect(
        signals.any((s) => s.toLowerCase().contains('webhook')),
        isTrue,
      );
      expect(
        signals.any((s) => s.toLowerCase().contains('queue') ||
            s.toLowerCase().contains('health') ||
            s.toLowerCase().contains('approval') ||
            s.toLowerCase().contains('connector')),
        isTrue,
      );
    });
  });

  group('EipController contract', () {
    test('tabs cover required integration surfaces without state-in-build', () {
      expect(EipCommandTab.values.map((t) => t.name), containsAll([
        'overview',
        'apis',
        'workflows',
        'events',
        'queues',
        'webhooks',
        'connectors',
        'security',
        'monitoring',
        'config',
        'analytics',
        'ai',
      ]));
      const initial = EipUiState();
      expect(initial.selectedTab, EipCommandTab.overview);
      expect(initial.tickerIndex, 0);
      expect(initial.copyWith(tickerIndex: 1).tickerIndex, 1);
    });
  });
}
