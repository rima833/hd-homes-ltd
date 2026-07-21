import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/features/biadw/domain/entities/biadw_models.dart';
import 'package:hdhomesproject/features/biadw/domain/services/biadw_service.dart';
import 'package:hdhomesproject/features/biadw/presentation/providers/biadw_controller.dart';

void main() {
  group('BiadwDemo', () {
    test('snapshot is non-empty across command-center surfaces', () {
      final snap = BiadwDemo.snapshot();
      expect(snap.kpis, isNotEmpty);
      expect(snap.dataSources, isNotEmpty);
      expect(snap.datasets, isNotEmpty);
      expect(snap.etlJobs, isNotEmpty);
      expect(snap.dashboards, isNotEmpty);
      expect(snap.reports, isNotEmpty);
      expect(snap.forecasts, isNotEmpty);
      expect(snap.scorecards, isNotEmpty);
      expect(snap.qualityIssues, isNotEmpty);
      expect(snap.lineage, isNotEmpty);
      expect(snap.catalog, isNotEmpty);
      expect(snap.aiInsights, isNotEmpty);
      expect(snap.activities, isNotEmpty);
      expect(snap.fromRemote, isFalse);
    });

    test('KPI strip includes BI command-center labels', () {
      final snap = BiadwDemo.snapshot();
      expect(
        snap.kpis.map((k) => k.label),
        containsAll([
          'Revenue MTD',
          'Conversion Rate',
          'Construction %',
          'ETL Success 7d',
          'Open DQ Issues',
        ]),
      );
    });

    test('AI insights carry editable advisory disclaimer', () {
      final snap = BiadwDemo.snapshot();
      expect(snap.aiDisclaimer.toLowerCase(), contains('ai-generated'));
      expect(snap.aiDisclaimer.toLowerCase(), contains('editable'));
      expect(snap.aiDisclaimer.toLowerCase(), contains('advisory'));
      for (final insight in snap.aiInsights) {
        expect(insight.disclaimer.toLowerCase(), contains('ai-generated'));
        expect(insight.editable, isTrue);
        expect(insight.confidencePct, isNotNull);
      }
    });

    test('register spans sources etl forecasts quality scorecards', () {
      final snap = BiadwDemo.snapshot();
      expect(snap.dataSources.length, greaterThanOrEqualTo(4));
      expect(snap.etlJobs.any((j) => j.isFailed), isTrue);
      expect(snap.etlJobs.any((j) => j.isSuccess), isTrue);
      expect(snap.forecasts.any((f) => f.confidencePct > 0), isTrue);
      expect(snap.qualityIssues.any((q) => q.isOpen), isTrue);
      expect(snap.scorecards.any((s) => s.audience == 'ceo'), isTrue);
      expect(snap.scorecards.any((s) => s.audience == 'cfo'), isTrue);
      expect(snap.dashboards.any((d) => d.status == 'published'), isTrue);
    });
  });

  group('BiadwService', () {
    test('offline client returns demo command center', () async {
      final service = BiadwService();
      final snap = await service.loadCommandCenter();
      expect(snap.fromRemote, isFalse);
      expect(snap.kpis.length, greaterThanOrEqualTo(5));
      expect(snap.dataSources, isNotEmpty);
    });

    test('AI executive briefing stub includes disclaimer and signals', () {
      final service = BiadwService();
      final snap = BiadwDemo.snapshot();
      final briefing = service.generateExecutiveBriefing(snap);
      expect(briefing.toLowerCase(), contains('briefing'));
      expect(briefing.toLowerCase(), contains('advisory'));
      expect(briefing.toLowerCase(), contains('etl'));
    });

    test('BI signals flag etl quality kpis and forecasts', () {
      final snap = BiadwDemo.snapshot();
      final signals = BiadwService.detectBiSignals(snap);
      expect(signals, isNotEmpty);
      expect(
        signals.any((s) => s.toLowerCase().contains('etl')),
        isTrue,
      );
      expect(
        signals.any((s) => s.toLowerCase().contains('quality')),
        isTrue,
      );
      expect(
        signals.any((s) => s.toLowerCase().contains('kpi')),
        isTrue,
      );
    });
  });

  group('BiadwController contract', () {
    test('tabs cover required BI surfaces without state-in-build', () {
      expect(BiadwCommandTab.values.map((t) => t.name), containsAll([
        'overview',
        'warehouse',
        'etl',
        'kpis',
        'dashboards',
        'reports',
        'forecasts',
        'scorecards',
        'quality',
        'governance',
        'analytics',
        'ai',
      ]));
      const initial = BiadwUiState();
      expect(initial.selectedTab, BiadwCommandTab.overview);
      expect(initial.tickerIndex, 0);
      expect(initial.copyWith(tickerIndex: 1).tickerIndex, 1);
    });
  });
}
