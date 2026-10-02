import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/core/theme/app_theme.dart';
import 'package:hdhomesproject/features/dxp/domain/entities/dxp_models.dart';
import 'package:hdhomesproject/features/dxp/domain/services/dxp_service.dart';
import 'package:hdhomesproject/features/dxp/presentation/pages/marketing_command_center_page.dart';
import 'package:hdhomesproject/features/dxp/presentation/providers/dxp_controller.dart';

DxpCommandCenterSnapshot dashboardSnapshot() {
  final empty = DxpCommandCenterSnapshot.empty(fromRemote: true);
  return DxpCommandCenterSnapshot(
    kpis: empty.kpis,
    funnel: const [
      DxpFunnelStage(label: 'CRM leads', value: 12, stageKey: 'leads'),
      DxpFunnelStage(label: 'Qualified', value: 1, stageKey: 'qualified'),
      DxpFunnelStage(label: 'Won / clients', value: 1, stageKey: 'won'),
    ],
    campaigns: const [],
    landingPages: const [],
    cmsPages: const [],
    blogPosts: const [],
    mediaAssets: const [],
    formSubmissions: const [],
    seoHealth: const [],
    calendar: const [],
    abTests: const [],
    activities: [
      DxpActivity(
        id: 'activity-1',
        summary: 'Published a new website article from the marketing workspace',
        actorLabel: 'Marketing team',
        occurredAt: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
    ],
    alerts: const [],
    aiInsights: const [],
    fromRemote: true,
    loadedAt: DateTime.now(),
    crmLeadCount: 12,
    crmQualifiedCount: 1,
  );
}

void main() {
  group('DxpService live-safe behavior', () {
    test('offline client returns an empty snapshot without fixtures', () async {
      final snap = await DxpService().loadCommandCenter();

      expect(snap.fromRemote, isFalse);
      expect(snap.campaigns, isEmpty);
      expect(snap.landingPages, isEmpty);
      expect(snap.formSubmissions, isEmpty);
      expect(snap.activities, isEmpty);
      expect(snap.alerts, isEmpty);
      expect(snap.kpis.every((kpi) => kpi.value == 0), isTrue);
    });

    test('operational KPIs only use supplied live records', () {
      final kpis = DxpKpiBuilder.build(
        campaigns: const [
          DxpCampaign(
            id: 'campaign-1',
            name: 'Real campaign',
            status: CampaignStatus.active,
            budgetAmount: 250000,
          ),
        ],
        formSubmissions: const [
          DxpFormSubmission(
            id: 'synced',
            formId: 'form-1',
            crmLeadId: 'lead-1',
          ),
          DxpFormSubmission(id: 'awaiting', formId: 'form-1'),
        ],
        seoHealth: const [
          DxpSeoHealth(id: 'seo-1', path: '/', healthScore: 80, issueCount: 2),
        ],
        crmLeadCount: 14,
        crmQualifiedCount: 3,
        crmWonCount: 1,
        publishedContentCount: 4,
        mediaCount: 7,
        scheduledContentCount: 2,
      );

      double value(String label) =>
          kpis.firstWhere((kpi) => kpi.label == label).value;

      // Synced forms are already CRM leads and must not be double-counted.
      expect(value('CRM Leads'), 15);
      expect(value('Qualified Leads'), 3);
      expect(value('Won / Clients'), 1);
      expect(value('Active Campaigns'), 1);
      expect(value('Planned Budget'), 250000);
      expect(value('Awaiting CRM Sync'), 1);
      expect(value('SEO Issues'), 2);
      expect(kpis.map((kpi) => kpi.label), isNot(contains('Website Visitors')));
      expect(kpis.map((kpi) => kpi.label), isNot(contains('Campaign Spend')));
      expect(
        kpis.map((kpi) => kpi.label),
        isNot(contains('Revenue Attributed')),
      );
    });
  });

  group('DxpController contract', () {
    test('tabs expose only working management surfaces', () {
      expect(
        DxpCommandTab.values.map((tab) => tab.name),
        containsAll([
          'overview',
          'pages',
          'landing',
          'blog',
          'media',
          'campaigns',
          'forms',
          'seo',
          'calendar',
        ]),
      );
      expect(
        DxpCommandTab.values.map((tab) => tab.name),
        isNot(contains('ai')),
      );
      expect(const DxpUiState().selectedTab, DxpCommandTab.overview);
    });
  });

  testWidgets('command center renders the live operational workspace', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final size in const [
      Size(1280, 1200),
      Size(1024, 576),
      Size(900, 1600),
      Size(768, 700),
      Size(390, 2600),
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supabaseConfiguredProvider.overrideWith((ref) => false),
            dxpSnapshotProvider.overrideWith(
              (ref) async => dashboardSnapshot(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const MarketingCommandCenterPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'overflow at $size');
    }

    expect(
      find.text('Here’s what’s happening across marketing today.'),
      findsOneWidget,
    );
    expect(find.text('CRM Leads'), findsOneWidget);
    expect(find.text('Sales pipeline'), findsOneWidget);
    expect(find.text('Lead Pipeline'), findsOneWidget);
    expect(find.text('Website Visitors'), findsNothing);
    expect(find.text('Campaign Spend'), findsNothing);
    expect(find.text('AI Studio'), findsNothing);
  });
}
