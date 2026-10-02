import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/inspection/presentation/pages/book_inspection_page.dart';
import 'package:hdhomesproject/features/inspection/presentation/providers/inspection_booking_controller.dart';

void main() {
  testWidgets('book-inspection page shows the premium 5-step wizard',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supabaseConfiguredProvider.overrideWith((ref) => false),
          inspectionBookingRealtimeProvider.overrideWith((ref) {}),
          publishedEstatesCatalogProvider.overrideWith((ref) async => []),
          inspectionBookablePropertiesProvider.overrideWith((ref) async => []),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BookInspectionPage(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Personal Info'), findsWidgets);
    expect(find.text('Property'), findsWidgets);
    expect(find.text('Schedule'), findsWidgets);
    expect(find.text('Preferences'), findsWidgets);
    expect(find.text('Confirm'), findsWidgets);
    expect(find.text('Personal Information'), findsOneWidget);
    expect(find.text('Continue'), findsWidgets);
  });
}
