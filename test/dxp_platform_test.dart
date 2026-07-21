import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/features/dxp/domain/entities/dxp_models.dart';
import 'package:hdhomesproject/features/dxp/domain/services/dxp_service.dart';
import 'package:hdhomesproject/features/dxp/presentation/providers/dxp_controller.dart';

void main() {
  group('DxpDemo', () {
    test('snapshot is non-empty across command-center surfaces', () {
      final snap = DxpDemo.snapshot();
      expect(snap.landingPages.length, greaterThanOrEqualTo(2));
      expect(snap.campaigns, isNotEmpty);
      expect(snap.blogPosts, isNotEmpty);
      expect(snap.mediaAssets, isNotEmpty);
      expect(snap.formSubmissions, isNotEmpty);
      expect(snap.seoHealth, isNotEmpty);
      expect(snap.calendar, isNotEmpty);
      expect(snap.abTests, isNotEmpty);
      expect(snap.funnel.length, greaterThanOrEqualTo(3));
      expect(snap.activities, isNotEmpty);
      expect(snap.alerts, isNotEmpty);
      expect(snap.kpis, isNotEmpty);
      expect(snap.aiInsights, isNotEmpty);
      expect(snap.fromRemote, isFalse);
    });

    test('KPI strip includes conversion funnel labels', () {
      final snap = DxpDemo.snapshot();
      expect(
        snap.kpis.map((k) => k.label),
        containsAll([
          'Published LPs',
          'Active Campaigns',
          'Form Leads',
          'Funnel CVR',
          'Conversions',
        ]),
      );
      expect(snap.funnel.map((f) => f.stageKey), containsAll([
        'awareness',
        'consideration',
        'conversion',
      ]));
      final awareness =
          snap.funnel.firstWhere((f) => f.stageKey == 'awareness').value;
      final conversion =
          snap.funnel.firstWhere((f) => f.stageKey == 'conversion').value;
      expect(awareness, greaterThan(conversion));
      expect(conversion, greaterThan(0));
    });

    test('AI insights carry editable disclaimer', () {
      final snap = DxpDemo.snapshot();
      expect(snap.aiDisclaimer.toLowerCase(), contains('ai-generated'));
      expect(snap.aiDisclaimer.toLowerCase(), contains('editable'));
      for (final insight in snap.aiInsights) {
        expect(insight.disclaimer.toLowerCase(), contains('ai-generated'));
        expect(insight.disclaimer.toLowerCase(), contains('editable'));
        expect(insight.editable, isTrue);
        expect(insight.confidencePct, isNotNull);
      }
      final draft = snap.blogPosts.firstWhere((b) => b.aiGenerated);
      expect(draft.aiDisclaimer, isNotNull);
      expect(draft.aiEditable, isTrue);
    });

    test('campaign channels and landing statuses are present', () {
      final snap = DxpDemo.snapshot();
      expect(
        snap.campaigns.map((c) => c.channel),
        containsAll(['email', 'sms', 'whatsapp']),
      );
      expect(
        snap.landingPages.any((p) => p.status == LandingPageStatus.published),
        isTrue,
      );
      expect(
        snap.landingPages.any((p) => p.status == LandingPageStatus.draft),
        isTrue,
      );
      expect(
        snap.blogPosts.any((b) => b.status == BlogPostStatus.draft),
        isTrue,
      );
    });
  });

  group('DxpService', () {
    test('offline client returns demo command center', () async {
      final service = DxpService();
      final snap = await service.loadCommandCenter();
      expect(snap.fromRemote, isFalse);
      expect(snap.landingPages, isNotEmpty);
      expect(snap.kpis.length, greaterThanOrEqualTo(7));
      expect(snap.funnel.length, greaterThanOrEqualTo(3));
    });

    test('AI content briefing stub includes disclaimer and leads', () {
      final service = DxpService();
      final snap = DxpDemo.snapshot();
      final briefing = service.generateContentBriefing(snap);
      expect(briefing, contains('AI content briefing'));
      expect(briefing.toLowerCase(), contains('ai-generated'));
      expect(briefing.toLowerCase(), contains('editable'));
      expect(briefing.toLowerCase(), contains('lead'));
    });

    test('conversion signals flag funnel CVR and running A/B', () {
      final snap = DxpDemo.snapshot();
      final signals = DxpService.detectConversionSignals(snap);
      expect(signals, isNotEmpty);
      expect(
        signals.any((s) => s.toLowerCase().contains('funnel')),
        isTrue,
      );
      expect(
        signals.any((s) => s.toLowerCase().contains('a/b')),
        isTrue,
      );
    });
  });

  group('DxpController contract', () {
    test('tabs cover required surfaces without state-in-build', () {
      // Conceptual guard: tabs match deliverable; Notifier.build must return
      // initial DxpUiState without reading `state` (see dxp_controller.dart).
      expect(DxpCommandTab.values.map((t) => t.name), containsAll([
        'overview',
        'pages',
        'landing',
        'blog',
        'media',
        'campaigns',
        'forms',
        'seo',
        'calendar',
        'ai',
      ]));
      const initial = DxpUiState();
      expect(initial.selectedTab, DxpCommandTab.overview);
      expect(initial.tickerIndex, 0);
      expect(initial.copyWith(tickerIndex: 1).tickerIndex, 1);
    });
  });
}
