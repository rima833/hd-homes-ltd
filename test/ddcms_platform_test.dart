import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/features/ddcms/domain/entities/ddcms_models.dart';
import 'package:hdhomesproject/features/ddcms/domain/services/ddcms_service.dart';
import 'package:hdhomesproject/features/ddcms/presentation/providers/ddcms_controller.dart';

void main() {
  group('DdcmsDemo', () {
    test('snapshot is non-empty across command-center surfaces', () {
      final snap = DdcmsDemo.snapshot();
      expect(snap.kpis, isNotEmpty);
      expect(snap.folders, isNotEmpty);
      expect(snap.documents, isNotEmpty);
      expect(snap.contracts, isNotEmpty);
      expect(snap.signatures, isNotEmpty);
      expect(snap.approvals, isNotEmpty);
      expect(snap.assets, isNotEmpty);
      expect(snap.ocrJobs, isNotEmpty);
      expect(snap.shares, isNotEmpty);
      expect(snap.retention, isNotEmpty);
      expect(snap.archival, isNotEmpty);
      expect(snap.aiInsights, isNotEmpty);
      expect(snap.activities, isNotEmpty);
      expect(snap.reports, isNotEmpty);
      expect(snap.fromRemote, isFalse);
    });

    test('KPI strip includes document command-center labels', () {
      final snap = DdcmsDemo.snapshot();
      expect(
        snap.kpis.map((k) => k.label),
        containsAll([
          'Active Docs',
          'Contracts',
          'Pending Signatures',
          'Approvals',
          'OCR Queue',
          'DAM Assets',
          'Retention Alerts',
        ]),
      );
    });

    test('AI insights carry editable advisory disclaimer', () {
      final snap = DdcmsDemo.snapshot();
      expect(snap.aiDisclaimer.toLowerCase(), contains('ai-generated'));
      expect(snap.aiDisclaimer.toLowerCase(), contains('editable'));
      expect(snap.aiDisclaimer.toLowerCase(), contains('advisory'));
      for (final insight in snap.aiInsights) {
        expect(insight.disclaimer.toLowerCase(), contains('ai-generated'));
        expect(insight.editable, isTrue);
        expect(insight.confidencePct, isNotNull);
      }
    });

    test('documents span categories and include pending signatures', () {
      final snap = DdcmsDemo.snapshot();
      expect(snap.documents.any((d) => d.category == 'property-deed'), isTrue);
      expect(
        snap.documents.any((d) => d.category == 'construction-drawing'),
        isTrue,
      );
      expect(
        snap.documents.any((d) => d.category == 'marketing-brochure'),
        isTrue,
      );
      expect(snap.documents.any((d) => d.category == 'hr-policy'), isTrue);
      expect(
        snap.documents.any((d) => d.category == 'finance-invoice'),
        isTrue,
      );
      expect(snap.signatures.any((s) => s.status == 'sent'), isTrue);
      expect(snap.signatures.any((s) => s.status == 'pending'), isTrue);
      expect(snap.ocrJobs.any((j) => j.status == 'queued'), isTrue);
    });
  });

  group('DdcmsService', () {
    test('offline client returns demo command center', () async {
      final service = DdcmsService();
      final snap = await service.loadCommandCenter();
      expect(snap.fromRemote, isFalse);
      expect(snap.kpis.length, greaterThanOrEqualTo(7));
      expect(snap.documents, isNotEmpty);
    });

    test('AI intelligence briefing stub includes disclaimer and signals', () {
      final service = DdcmsService();
      final snap = DdcmsDemo.snapshot();
      final briefing = service.generateIntelligenceBriefing(snap);
      expect(briefing.toLowerCase(), contains('intelligence'));
      expect(briefing.toLowerCase(), contains('advisory'));
      expect(briefing.toLowerCase(), contains('signature'));
    });

    test('document signals flag signatures OCR and retention', () {
      final snap = DdcmsDemo.snapshot();
      final signals = DdcmsService.detectDocumentSignals(snap);
      expect(signals, isNotEmpty);
      expect(
        signals.any((s) => s.toLowerCase().contains('signature')),
        isTrue,
      );
      expect(
        signals.any((s) => s.toLowerCase().contains('ocr')),
        isTrue,
      );
      expect(
        signals.any((s) => s.toLowerCase().contains('retention')),
        isTrue,
      );
    });
  });

  group('DdcmsController contract', () {
    test('tabs cover required document surfaces without state-in-build', () {
      expect(DdcmsCommandTab.values.map((t) => t.name), containsAll([
        'overview',
        'repository',
        'contracts',
        'signatures',
        'approvals',
        'dam',
        'ocr',
        'sharing',
        'retention',
        'analytics',
        'ai',
        'compliance',
      ]));
      const initial = DdcmsUiState();
      expect(initial.selectedTab, DdcmsCommandTab.overview);
      expect(initial.tickerIndex, 0);
      expect(initial.copyWith(tickerIndex: 1).tickerIndex, 1);
    });
  });
}
