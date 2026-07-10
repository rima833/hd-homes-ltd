import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/app_theme.dart';
import 'package:hdhomesproject/features/estates/presentation/pages/estate_detail_page.dart';
import 'package:hdhomesproject/features/estates/presentation/pages/estates_listing_page.dart';

void main() {
  testWidgets('Estates listing page loads estate cards', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1200));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(body: SingleChildScrollView(child: EstatesListingPage())),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Flagship developments'), findsOneWidget);
    expect(find.text('Horizon Gardens'), findsOneWidget);
    expect(find.text('Emerald Heights'), findsOneWidget);

    addTearDown(() => tester.binding.setSurfaceSize(null));
  });

  testWidgets('Estate detail page loads showcase sections', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 5600));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: EstateDetailPage(estateSlug: 'horizon-gardens'),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(seconds: 2));

    expect(find.textContaining('Horizon Gardens'), findsWidgets);
    expect(find.text('Estate overview'), findsOneWidget);
    expect(find.text('Interactive master plan'), findsOneWidget);
    expect(find.text('Available properties'), findsOneWidget);
    expect(find.text('Construction Time Machine'), findsNothing);
    expect(find.text('Progress over time'), findsOneWidget);
    expect(find.text('Live Estate Dashboard'), findsNothing);
    expect(find.text('Estate availability & progress'), findsOneWidget);
    expect(find.text('Estate Investment Intelligence'), findsOneWidget);

    addTearDown(() => tester.binding.setSurfaceSize(null));
  });

  testWidgets('Estate detail shows not found for invalid slug', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: EstateDetailPage(estateSlug: 'invalid-slug'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Estate not found'), findsOneWidget);
    expect(find.text('Browse estates'), findsOneWidget);
  });
}
