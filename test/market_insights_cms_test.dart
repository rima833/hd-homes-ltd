import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/core/theme/app_theme.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/pages/cms_market_insights_page.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/investment/presentation/sections/investment_market_insights_section.dart';

CmsWebsiteMarketInsight _insight({
  required String id,
  required String title,
  required String value,
  String status = 'published',
  bool isPublished = true,
  String summary = 'Strong buyer and rental demand.',
  String trend = 'Rising',
  String location = 'Lekki, Lagos',
}) {
  return CmsWebsiteMarketInsight(
    id: id,
    title: title,
    value: value,
    trend: trend,
    summary: summary,
    location: location,
    category: 'Demand',
    status: status,
    isPublishedFlag: isPublished,
    sortOrder: 10,
    updatedAt: DateTime(2026, 8, 14, 10, 32),
  );
}

void main() {
  group('CmsWebsiteMarketInsight publishing helpers', () {
    test('published rows are public', () {
      final item = _insight(id: '1', title: 'Lekki', value: '+22% YoY');
      expect(item.isPublished, isTrue);
      expect(item.isDraft, isFalse);
      expect(item.statusLabel, 'Published');
    });

    test('draft rows stay private', () {
      final item = _insight(
        id: '2',
        title: 'Lekki',
        value: '+22% YoY',
        status: 'draft',
        isPublished: false,
      );
      expect(item.isPublished, isFalse);
      expect(item.isDraft, isTrue);
      expect(item.statusLabel, 'Draft');
    });

    test('archived rows stay private', () {
      final item = _insight(
        id: '3',
        title: 'Lekki',
        value: '+22% YoY',
        status: 'archived',
        isPublished: false,
      );
      expect(item.isPublished, isFalse);
      expect(item.isArchived, isTrue);
      expect(item.statusLabel, 'Archived');
    });

    test('legacy active rows still count as published', () {
      final item = CmsWebsiteMarketInsight.fromJson({
        'id': '4',
        'title': 'Legacy',
        'value': '+18% YoY',
        'status': 'active',
      });
      expect(item.isPublished, isTrue);
      expect(item.statusLabel, 'Published');
    });
  });

  testWidgets('public section shows published insights only', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final published = _insight(
      id: 'pub',
      title: 'Lekki Corridor Demand',
      value: '+22% YoY',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supabaseConfiguredProvider.overrideWithValue(false),
          websiteMarketInsightsRealtimeProvider.overrideWith((ref) {}),
          publishedWebsiteMarketInsightsProvider.overrideWith(
            (ref) async => [published],
          ),
          publishedCompanyStatsHomeProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: InvestmentMarketInsightsSection(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Market insights'), findsOneWidget);
    expect(find.text('Lekki Corridor Demand'), findsOneWidget);
    expect(find.text('+22% YoY'), findsOneWidget);
    expect(find.text('Lekki, Lagos'), findsOneWidget);
    expect(
      find.text('Market insights are currently being updated.'),
      findsNothing,
    );
  });

  testWidgets('public section updates when published value changes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final live = StateProvider<List<CmsWebsiteMarketInsight>>(
      (ref) => [
        _insight(
          id: 'lekki',
          title: 'Lekki Corridor Demand',
          value: '+22% YoY',
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supabaseConfiguredProvider.overrideWithValue(false),
          websiteMarketInsightsRealtimeProvider.overrideWith((ref) {}),
          publishedWebsiteMarketInsightsProvider.overrideWith((ref) async {
            return ref.watch(live);
          }),
          publishedCompanyStatsHomeProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: InvestmentMarketInsightsSection(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('+22% YoY'), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(InvestmentMarketInsightsSection)),
    );
    container.read(live.notifier).state = [
      _insight(id: 'lekki', title: 'Lekki Corridor Demand', value: '+25% YoY'),
    ];
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('+25% YoY'), findsOneWidget);
    expect(find.text('+22% YoY'), findsNothing);

    container.read(live.notifier).state = const [];
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(
      find.text('Market insights are currently being updated.'),
      findsOneWidget,
    );
    expect(find.text('Lekki Corridor Demand'), findsNothing);
  });

  testWidgets('public section shows retryable error, not empty copy', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supabaseConfiguredProvider.overrideWithValue(false),
          websiteMarketInsightsRealtimeProvider.overrideWith((ref) {}),
          publishedWebsiteMarketInsightsProvider.overrideWith(
            (ref) async => throw Exception('permission denied'),
          ),
          publishedCompanyStatsHomeProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: InvestmentMarketInsightsSection(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Market insights could not be loaded.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(
      find.text('Market insights are currently being updated.'),
      findsNothing,
    );
  });

  testWidgets('admin CMS distinguishes draft, published, and archived', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final items = [
      _insight(id: 'p1', title: 'Lekki Corridor Demand', value: '+22% YoY'),
      _insight(
        id: 'd1',
        title: 'Draft Corridor Note',
        value: '+5% QoQ',
        status: 'draft',
        isPublished: false,
      ),
      _insight(
        id: 'a1',
        title: 'Archived Yield',
        value: '7%',
        status: 'archived',
        isPublished: false,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supabaseConfiguredProvider.overrideWithValue(false),
          websiteMarketInsightsRealtimeProvider.overrideWith((ref) {}),
          cmsWebsiteMarketInsightsProvider.overrideWith((ref) async => items),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: const Scaffold(body: CmsMarketInsightsTab()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Market insights'), findsWidgets);
    expect(find.text('Lekki Corridor Demand'), findsWidgets);
    expect(find.text('Draft Corridor Note'), findsWidgets);
    expect(find.text('Archived Yield'), findsWidgets);
    expect(find.text('Published'), findsWidgets);
    expect(find.text('Draft'), findsWidgets);
    expect(find.text('Archived'), findsWidgets);
    expect(find.text('Add Market Insight'), findsOneWidget);
  });
}
