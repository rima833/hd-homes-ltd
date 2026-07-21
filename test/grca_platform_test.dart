import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/features/grca/domain/entities/grca_models.dart';
import 'package:hdhomesproject/features/grca/domain/services/grca_service.dart';
import 'package:hdhomesproject/features/grca/presentation/providers/grca_controller.dart';

void main() {
  group('GrcaDemo', () {
    test('snapshot is non-empty across command-center surfaces', () {
      final snap = GrcaDemo.snapshot();
      expect(snap.kpis, isNotEmpty);
      expect(snap.risks, isNotEmpty);
      expect(snap.complianceFrameworks, isNotEmpty);
      expect(snap.policies, isNotEmpty);
      expect(snap.auditPlans, isNotEmpty);
      expect(snap.auditFindings, isNotEmpty);
      expect(snap.legalCases, isNotEmpty);
      expect(snap.ethicsReports, isNotEmpty);
      expect(snap.boardMeetings, isNotEmpty);
      expect(snap.bcmPlans, isNotEmpty);
      expect(snap.calendarEvents, isNotEmpty);
      expect(snap.aiInsights, isNotEmpty);
      expect(snap.activities, isNotEmpty);
      expect(snap.reports, isNotEmpty);
      expect(snap.fromRemote, isFalse);
    });

    test('KPI strip includes GRC command-center labels', () {
      final snap = GrcaDemo.snapshot();
      expect(
        snap.kpis.map((k) => k.label),
        containsAll([
          'Open Risks',
          'Critical Open',
          'Compliance Score',
          'Open Findings',
          'Legal Cases',
          'Policies Active',
          'Deadlines 30d',
        ]),
      );
    });

    test('AI insights carry editable advisory disclaimer', () {
      final snap = GrcaDemo.snapshot();
      expect(snap.aiDisclaimer.toLowerCase(), contains('ai-generated'));
      expect(snap.aiDisclaimer.toLowerCase(), contains('editable'));
      expect(snap.aiDisclaimer.toLowerCase(), contains('advisory'));
      for (final insight in snap.aiInsights) {
        expect(insight.disclaimer.toLowerCase(), contains('ai-generated'));
        expect(insight.editable, isTrue);
        expect(insight.confidencePct, isNotNull);
      }
    });

    test('register spans critical open risks compliance audit legal ethics', () {
      final snap = GrcaDemo.snapshot();
      expect(snap.risks.length, greaterThanOrEqualTo(3));
      expect(snap.risks.any((r) => r.isCriticalOpen), isTrue);
      expect(snap.complianceFrameworks.length, greaterThanOrEqualTo(2));
      expect(snap.policies.any((p) => p.status == 'active'), isTrue);
      expect(snap.auditFindings.any((f) => f.isOpen), isTrue);
      expect(snap.legalCases, isNotEmpty);
      expect(snap.ethicsReports.any((e) => e.summaryRedacted != null), isTrue);
      expect(snap.boardMeetings, isNotEmpty);
      expect(snap.bcmPlans, isNotEmpty);
      expect(snap.calendarEvents.any((e) => e.isDueSoon), isTrue);
    });
  });

  group('GrcaService', () {
    test('offline client returns demo command center', () async {
      final service = GrcaService();
      final snap = await service.loadCommandCenter();
      expect(snap.fromRemote, isFalse);
      expect(snap.kpis.length, greaterThanOrEqualTo(7));
      expect(snap.risks, isNotEmpty);
    });

    test('AI intelligence briefing stub includes disclaimer and signals', () {
      final service = GrcaService();
      final snap = GrcaDemo.snapshot();
      final briefing = service.generateIntelligenceBriefing(snap);
      expect(briefing.toLowerCase(), contains('governance'));
      expect(briefing.toLowerCase(), contains('advisory'));
      expect(briefing.toLowerCase(), contains('risk'));
    });

    test('GRC signals flag risks findings deadlines and legal', () {
      final snap = GrcaDemo.snapshot();
      final signals = GrcaService.detectGrcSignals(snap);
      expect(signals, isNotEmpty);
      expect(
        signals.any((s) => s.toLowerCase().contains('risk')),
        isTrue,
      );
      expect(
        signals.any((s) => s.toLowerCase().contains('audit')),
        isTrue,
      );
      expect(
        signals.any((s) => s.toLowerCase().contains('deadline')),
        isTrue,
      );
    });
  });

  group('GrcaController contract', () {
    test('tabs cover required GRC surfaces without state-in-build', () {
      expect(GrcaCommandTab.values.map((t) => t.name), containsAll([
        'overview',
        'risks',
        'compliance',
        'policies',
        'audit',
        'legal',
        'ethics',
        'board',
        'bcm',
        'calendar',
        'analytics',
        'ai',
      ]));
      const initial = GrcaUiState();
      expect(initial.selectedTab, GrcaCommandTab.overview);
      expect(initial.tickerIndex, 0);
      expect(initial.copyWith(tickerIndex: 1).tickerIndex, 1);
    });
  });
}
