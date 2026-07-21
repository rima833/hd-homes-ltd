import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/features/eaih/domain/entities/eaih_models.dart';
import 'package:hdhomesproject/features/eaih/domain/services/eaih_service.dart';
import 'package:hdhomesproject/features/eaih/presentation/providers/eaih_controller.dart';

void main() {
  group('EaihDemo', () {
    test('snapshot is non-empty across command-center surfaces', () {
      final snap = EaihDemo.snapshot();
      expect(snap.kpis, isNotEmpty);
      expect(snap.services, isNotEmpty);
      expect(snap.copilots, isNotEmpty);
      expect(snap.models, isNotEmpty);
      expect(snap.modelVersions, isNotEmpty);
      expect(snap.predictions, isNotEmpty);
      expect(snap.recommendations, isNotEmpty);
      expect(snap.searchQueries, isNotEmpty);
      expect(snap.knowledgeNodes, isNotEmpty);
      expect(snap.knowledgeEdges, isNotEmpty);
      expect(snap.automationJobs, isNotEmpty);
      expect(snap.workflowRules, isNotEmpty);
      expect(snap.governancePolicies, isNotEmpty);
      expect(snap.monitoring, isNotEmpty);
      expect(snap.driftReports, isNotEmpty);
      expect(snap.hubInsights, isNotEmpty);
      expect(snap.activities, isNotEmpty);
      expect(snap.fromRemote, isFalse);
    });

    test('KPI strip includes AI command-center labels', () {
      final snap = EaihDemo.snapshot();
      expect(
        snap.kpis.map((k) => k.label),
        containsAll([
          'Active Copilots',
          'Predictions 7d',
          'Avg Confidence',
          'Open Drift',
          'Awaiting Approval',
        ]),
      );
    });

    test('AI hub insights carry editable advisory disclaimer', () {
      final snap = EaihDemo.snapshot();
      expect(snap.aiDisclaimer.toLowerCase(), contains('ai-generated'));
      expect(snap.aiDisclaimer.toLowerCase(), contains('editable'));
      expect(snap.aiDisclaimer.toLowerCase(), contains('advisory'));
      for (final insight in snap.hubInsights) {
        expect(insight.disclaimer.toLowerCase(), contains('ai-generated'));
        expect(insight.editable, isTrue);
        expect(insight.confidencePct, isNotNull);
      }
    });

    test('register spans copilots predictions automation drift governance', () {
      final snap = EaihDemo.snapshot();
      expect(snap.copilots.length, greaterThanOrEqualTo(7));
      expect(snap.copilots.any((c) => c.slug == 'executive'), isTrue);
      expect(snap.copilots.any((c) => c.slug == 'sales'), isTrue);
      expect(snap.automationJobs.any((j) => j.isFailed), isTrue);
      expect(snap.automationJobs.any((j) => j.awaitsApproval), isTrue);
      expect(snap.predictions.any((p) => p.confidencePct > 0), isTrue);
      expect(snap.driftReports.any((d) => d.isOpen), isTrue);
      expect(
        snap.governancePolicies.any((p) => p.policyArea == 'responsible_ai'),
        isTrue,
      );
      expect(snap.models.any((m) => m.status == 'active'), isTrue);
    });
  });

  group('EaihService', () {
    test('offline client returns demo command center', () async {
      final service = EaihService();
      final snap = await service.loadCommandCenter();
      expect(snap.fromRemote, isFalse);
      expect(snap.kpis.length, greaterThanOrEqualTo(5));
      expect(snap.copilots, isNotEmpty);
    });

    test('decision briefing stub includes disclaimer and signals', () {
      final service = EaihService();
      final snap = EaihDemo.snapshot();
      final briefing = service.generateDecisionBriefing(snap);
      expect(briefing.toLowerCase(), contains('decision'));
      expect(briefing.toLowerCase(), contains('advisory'));
      expect(briefing.toLowerCase(), contains('drift'));
    });

    test('AI signals flag automation drift predictions and approvals', () {
      final snap = EaihDemo.snapshot();
      final signals = EaihService.detectAiSignals(snap);
      expect(signals, isNotEmpty);
      expect(
        signals.any((s) => s.toLowerCase().contains('automation')),
        isTrue,
      );
      expect(
        signals.any((s) => s.toLowerCase().contains('drift')),
        isTrue,
      );
      expect(
        signals.any((s) => s.toLowerCase().contains('prediction') ||
            s.toLowerCase().contains('recommendation') ||
            s.toLowerCase().contains('monitoring')),
        isTrue,
      );
    });
  });

  group('EaihController contract', () {
    test('tabs cover required AI surfaces without state-in-build', () {
      expect(EaihCommandTab.values.map((t) => t.name), containsAll([
        'overview',
        'copilots',
        'models',
        'predictions',
        'recommendations',
        'search',
        'knowledge',
        'automation',
        'decision',
        'governance',
        'observability',
        'analytics',
      ]));
      const initial = EaihUiState();
      expect(initial.selectedTab, EaihCommandTab.overview);
      expect(initial.tickerIndex, 0);
      expect(initial.copyWith(tickerIndex: 1).tickerIndex, 1);
    });
  });
}
