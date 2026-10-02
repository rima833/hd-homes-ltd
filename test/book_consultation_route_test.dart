import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/consultation/presentation/pages/book_consultation_page.dart';
import 'package:hdhomesproject/features/consultation/presentation/providers/consultation_booking_controller.dart';

void main() {
  testWidgets('book-consultation page shows the premium multi-step wizard',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: RoutePaths.bookConsultation,
      routes: [
        GoRoute(
          path: RoutePaths.bookConsultation,
          builder: (context, state) => const Scaffold(
            body: SingleChildScrollView(
              child: BookConsultationPage(),
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supabaseConfiguredProvider.overrideWith((ref) => false),
          consultationSlotsRealtimeProvider.overrideWith((ref) {}),
          consultationDepartmentsProvider.overrideWith((ref) async => []),
          consultationAdvisorsProvider.overrideWith((ref, deptId) async => []),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Personal Details'), findsWidgets);
    expect(find.text('Consultation Type'), findsWidgets);
    expect(find.text('Schedule'), findsWidgets);
    expect(find.text('Review & Confirm'), findsWidgets);
    expect(find.text('Personal Information'), findsOneWidget);
    expect(find.text('Continue'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
