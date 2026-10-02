import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/home/data/models/home_cms_content.dart';
import 'package:hdhomesproject/features/home/presentation/sections/home_investment_section.dart';

void main() {
  testWidgets('Investment opportunities section renders premium layout',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supabaseConfiguredProvider.overrideWithValue(false),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HomeInvestmentSection(
                fallbackItems: const [
                  HomeInvestmentItem(
                    title: 'Horizon Gardens Fund',
                    roi: '18-22%',
                    type: 'Estate Development',
                    duration: '24 months',
                    risk: 'Moderate',
                    growth: 'High',
                    route: '/investment/horizon-gardens-fund',
                  ),
                  HomeInvestmentItem(
                    title: 'Lagos Commercial Yield',
                    roi: '14-18%',
                    type: 'Commercial Asset',
                    duration: '36 months',
                    risk: 'Moderate',
                    growth: 'High',
                    route: '/investment/lagos-commercial-yield',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1300));

    expect(tester.takeException(), isNull);
    expect(find.text('Investment opportunities'), findsOneWidget);
    expect(find.text('Horizon Gardens Fund'), findsOneWidget);
    expect(find.text('Attractive Returns'), findsOneWidget);
    expect(find.textContaining('View Opportunity'), findsWidgets);
  });
}
