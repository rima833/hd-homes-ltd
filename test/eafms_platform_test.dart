import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/features/eafms/domain/entities/eafms_models.dart';
import 'package:hdhomesproject/features/eafms/domain/services/eafms_service.dart';
import 'package:hdhomesproject/features/eafms/presentation/providers/eafms_controller.dart';

void main() {
  group('EafmsDemo', () {
    test('snapshot is non-empty across command-center surfaces', () {
      final snap = EafmsDemo.snapshot();
      expect(snap.kpis, isNotEmpty);
      expect(snap.assets, isNotEmpty);
      expect(snap.facilities, isNotEmpty);
      expect(snap.workOrders, isNotEmpty);
      expect(snap.maintenance, isNotEmpty);
      expect(snap.inspections, isNotEmpty);
      expect(snap.fleet, isNotEmpty);
      expect(snap.fuelLogs, isNotEmpty);
      expect(snap.utilities, isNotEmpty);
      expect(snap.warranties, isNotEmpty);
      expect(snap.depreciation, isNotEmpty);
      expect(snap.aiInsights, isNotEmpty);
      expect(snap.activities, isNotEmpty);
      expect(snap.reports, isNotEmpty);
      expect(snap.fromRemote, isFalse);
    });

    test('KPI strip includes asset command-center labels', () {
      final snap = EafmsDemo.snapshot();
      expect(
        snap.kpis.map((k) => k.label),
        containsAll([
          'Active Assets',
          'Open WOs',
          'Maint Due',
          'Facilities',
          'Fleet Units',
          'Warranty Risk',
          'Book Value',
        ]),
      );
    });

    test('AI insights carry editable advisory disclaimer', () {
      final snap = EafmsDemo.snapshot();
      expect(snap.aiDisclaimer.toLowerCase(), contains('ai-generated'));
      expect(snap.aiDisclaimer.toLowerCase(), contains('editable'));
      expect(snap.aiDisclaimer.toLowerCase(), contains('advisory'));
      for (final insight in snap.aiInsights) {
        expect(insight.disclaimer.toLowerCase(), contains('ai-generated'));
        expect(insight.editable, isTrue);
        expect(insight.confidencePct, isNotNull);
      }
    });

    test('register spans IT fleet construction and open WOs with maint due', () {
      final snap = EafmsDemo.snapshot();
      expect(snap.assets.length, greaterThanOrEqualTo(4));
      expect(snap.facilities.length, greaterThanOrEqualTo(2));
      expect(snap.assets.any((a) => a.assetClass == 'it'), isTrue);
      expect(snap.assets.any((a) => a.assetClass == 'fleet'), isTrue);
      expect(snap.assets.any((a) => a.assetClass == 'construction'), isTrue);
      expect(snap.workOrders.any((w) => w.status == 'open'), isTrue);
      expect(snap.maintenance.any((m) => m.isDue), isTrue);
      expect(snap.warranties.any((w) => w.isExpiringSoon), isTrue);
      expect(snap.fleet, isNotEmpty);
      expect(snap.fuelLogs, isNotEmpty);
      expect(snap.utilities, isNotEmpty);
    });
  });

  group('EafmsService', () {
    test('offline client returns demo command center', () async {
      final service = EafmsService();
      final snap = await service.loadCommandCenter();
      expect(snap.fromRemote, isFalse);
      expect(snap.kpis.length, greaterThanOrEqualTo(7));
      expect(snap.assets, isNotEmpty);
    });

    test('AI intelligence briefing stub includes disclaimer and signals', () {
      final service = EafmsService();
      final snap = EafmsDemo.snapshot();
      final briefing = service.generateIntelligenceBriefing(snap);
      expect(briefing.toLowerCase(), contains('asset'));
      expect(briefing.toLowerCase(), contains('advisory'));
      expect(briefing.toLowerCase(), contains('maintenance'));
    });

    test('asset signals flag maintenance work orders and warranties', () {
      final snap = EafmsDemo.snapshot();
      final signals = EafmsService.detectAssetSignals(snap);
      expect(signals, isNotEmpty);
      expect(
        signals.any((s) => s.toLowerCase().contains('maintenance')),
        isTrue,
      );
      expect(
        signals.any((s) => s.toLowerCase().contains('work order')),
        isTrue,
      );
      expect(
        signals.any((s) => s.toLowerCase().contains('warrant')),
        isTrue,
      );
    });
  });

  group('EafmsController contract', () {
    test('tabs cover required asset surfaces without state-in-build', () {
      expect(EafmsCommandTab.values.map((t) => t.name), containsAll([
        'overview',
        'register',
        'facilities',
        'maintenance',
        'workOrders',
        'inspections',
        'fleet',
        'utilities',
        'warranties',
        'depreciation',
        'analytics',
        'ai',
      ]));
      const initial = EafmsUiState();
      expect(initial.selectedTab, EafmsCommandTab.overview);
      expect(initial.tickerIndex, 0);
      expect(initial.copyWith(tickerIndex: 1).tickerIndex, 1);
    });
  });
}
