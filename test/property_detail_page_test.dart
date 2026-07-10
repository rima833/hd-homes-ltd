import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/app_theme.dart';
import 'package:hdhomesproject/features/properties/presentation/pages/property_detail_page.dart';

void main() {
  testWidgets('Property detail page loads showroom sections', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 4800));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: PropertyDetailPage(propertyId: 'h001'),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Quick actions'), findsOneWidget);
    expect(find.text('Property overview'), findsOneWidget);
    expect(find.text('Mortgage calculator'), findsOneWidget);
    expect(find.text('Book an inspection slot'), findsOneWidget);
    expect(find.text('AI Decision Assistant'), findsOneWidget);
    expect(find.textContaining('4-Bedroom Luxury Duplex'), findsWidgets);

    addTearDown(() => tester.binding.setSurfaceSize(null));
  });

  testWidgets('Property detail shows not found for invalid id', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: PropertyDetailPage(propertyId: 'invalid-id'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Property not found'), findsOneWidget);
    expect(find.text('Browse properties'), findsOneWidget);
  });
}
