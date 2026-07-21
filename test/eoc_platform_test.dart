import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/features/eoc/domain/entities/eoc_models.dart';
import 'package:hdhomesproject/features/eoc/domain/services/eoc_service.dart';
import 'package:hdhomesproject/features/eoc/presentation/providers/eoc_controller.dart';

void main() {
  group('EocDemo', () {
    test('snapshot is non-empty across mission-control surfaces', () {
      final snap = EocDemo.snapshot();
      expect(snap.kpis, isNotEmpty);
      expect(snap.moduleHealth, isNotEmpty);
      expect(snap.alerts, isNotEmpty);
      expect(snap.approvals, isNotEmpty);
      expect(snap.workflows, isNotEmpty);
      expect(snap.tasks, isNotEmpty);
      expect(snap.aiInsights, isNotEmpty);
      expect(snap.forecasts, isNotEmpty);
      expect(snap.scorecards, isNotEmpty);
      expect(snap.scorecardMetrics, isNotEmpty);
      expect(snap.meetings, isNotEmpty);
      expect(snap.decisions, isNotEmpty);
      expect(snap.activities, isNotEmpty);
      expect(snap.auditEvents, isNotEmpty);
      expect(snap.knowledge, isNotEmpty);
      expect(snap.searchHits, isNotEmpty);
      expect(snap.fromRemote, isFalse);
    });

    test('KPI strip includes mission-control labels', () {
      final snap = EocDemo.snapshot();
      expect(
        snap.kpis.map((k) => k.label),
        containsAll([
          'Revenue MTD',
          'Sales Pipeline',
          'Open Alerts',
          'Pending Approvals',
          'Active Workflows',
          'Module Health',
          'Open Tasks',
        ]),
      );
      expect(
        snap.moduleHealth.map((m) => m.label),
        containsAll(['Sales', 'Finance', 'Construction']),
      );
    });

    test('AI insights carry editable advisory disclaimer', () {
      final snap = EocDemo.snapshot();
      expect(snap.aiDisclaimer.toLowerCase(), contains('ai-generated'));
      expect(snap.aiDisclaimer.toLowerCase(), contains('editable'));
      expect(snap.aiDisclaimer.toLowerCase(), contains('advisory'));
      for (final insight in snap.aiInsights) {
        expect(insight.disclaimer.toLowerCase(), contains('ai-generated'));
        expect(insight.editable, isTrue);
        expect(insight.confidencePct, isNotNull);
      }
    });

    test('alerts approvals and workflows include actionable statuses', () {
      final snap = EocDemo.snapshot();
      expect(snap.alerts.any((a) => a.severity == 'critical'), isTrue);
      expect(snap.approvals.any((a) => a.status == 'pending'), isTrue);
      expect(snap.workflows.any((w) => w.status == 'waiting'), isTrue);
      expect(snap.tasks.any((t) => t.priority == 'urgent'), isTrue);
    });
  });

  group('EocService', () {
    test('offline client returns demo mission control', () async {
      final service = EocService();
      final snap = await service.loadMissionControl();
      expect(snap.fromRemote, isFalse);
      expect(snap.kpis.length, greaterThanOrEqualTo(7));
      expect(snap.alerts, isNotEmpty);
    });

    test('AI enterprise briefing stub includes disclaimer and signals', () {
      final service = EocService();
      final snap = EocDemo.snapshot();
      final briefing = service.generateEnterpriseBriefing(snap);
      expect(briefing.toLowerCase(), contains('enterprise'));
      expect(briefing.toLowerCase(), contains('advisory'));
      expect(briefing.toLowerCase(), contains('alert'));
    });

    test('ops signals flag critical alerts and pending approvals', () {
      final snap = EocDemo.snapshot();
      final signals = EocService.detectOpsSignals(snap);
      expect(signals, isNotEmpty);
      expect(
        signals.any((s) => s.toLowerCase().contains('critical')),
        isTrue,
      );
      expect(
        signals.any((s) => s.toLowerCase().contains('approval')),
        isTrue,
      );
    });
  });

  group('EocController contract', () {
    test('tabs cover required mission-control surfaces without state-in-build', () {
      expect(EocCommandTab.values.map((t) => t.name), containsAll([
        'overview',
        'kpis',
        'search',
        'ai',
        'workflows',
        'approvals',
        'alerts',
        'tasks',
        'forecasts',
        'scorecards',
        'knowledge',
        'audit',
      ]));
      const initial = EocUiState();
      expect(initial.selectedTab, EocCommandTab.overview);
      expect(initial.tickerIndex, 0);
      expect(initial.copyWith(tickerIndex: 1).tickerIndex, 1);
    });
  });
}
