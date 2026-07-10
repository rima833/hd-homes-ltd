import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/app_theme.dart';
import 'package:hdhomesproject/features/search/presentation/pages/search_intelligence_page.dart';

void main() {
  testWidgets('Search intelligence page loads discovery sections', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 2400));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(body: SingleChildScrollView(child: SearchIntelligencePage())),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Find Your Perfect Property'), findsOneWidget);
    expect(find.text('One-click discovery'), findsOneWidget);
    expect(find.text('AI Smart Search'), findsOneWidget);

    addTearDown(() => tester.binding.setSurfaceSize(null));
  });
}
