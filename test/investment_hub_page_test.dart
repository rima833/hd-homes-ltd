import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/app_theme.dart';
import 'package:hdhomesproject/features/investment/presentation/pages/investment_hub_page.dart';

void main() {
  testWidgets('Investment hub page loads key sections', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 3200));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(body: InvestmentHubPage()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Grow Your Wealth'), findsOneWidget);
    expect(find.text('Why invest with HD Homes'), findsOneWidget);
    expect(find.text('Current investment opportunities'), findsOneWidget);
    expect(find.text('How investing works'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Investment ROI calculator'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Investment ROI calculator'), findsOneWidget);
    expect(find.text('AI investment insights'), findsOneWidget);
    expect(find.text('Investor Portal'), findsWidgets);
    expect(find.text('Investor FAQ'), findsOneWidget);

    addTearDown(() => tester.binding.setSurfaceSize(null));
  });
}
