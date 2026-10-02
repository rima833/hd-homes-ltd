import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/core/theme/app_theme.dart';
import 'package:hdhomesproject/features/investment/presentation/pages/investment_hub_page.dart';

void main() {
  testWidgets('Investment hub page loads key sections', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 3200));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supabaseConfiguredProvider.overrideWithValue(false),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: SingleChildScrollView(child: InvestmentHubPage()),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Grow Your Wealth'), findsOneWidget);
    expect(find.text('WHY INVEST'), findsOneWidget);
    expect(find.text('Current investment opportunities'), findsOneWidget);
    expect(find.text('How investing works'), findsOneWidget);
    expect(find.text('Market insights'), findsOneWidget);
    expect(find.text('Investor Portal'), findsWidgets);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    addTearDown(() => tester.binding.setSurfaceSize(null));
  });
}
