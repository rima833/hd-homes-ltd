import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/core/theme/app_theme.dart';
import 'package:hdhomesproject/features/callback/domain/entities/callback_models.dart';
import 'package:hdhomesproject/features/callback/presentation/providers/callback_providers.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/consultation/domain/entities/consultation_booking_models.dart';
import 'package:hdhomesproject/features/consultation/presentation/providers/consultation_booking_controller.dart';
import 'package:hdhomesproject/features/contact/data/models/contact_content.dart';
import 'package:hdhomesproject/features/contact/presentation/pages/contact_page.dart';
import 'package:hdhomesproject/features/inspection/presentation/providers/inspection_booking_controller.dart';
import 'package:visibility_detector/visibility_detector.dart';

List<Override> get _overrides => [
      supabaseConfiguredProvider.overrideWith((ref) => false),
      inspectionBookingRealtimeProvider.overrideWith((ref) {}),
      publishedEstatesCatalogProvider.overrideWith((ref) async => []),
      inspectionBookablePropertiesProvider.overrideWith((ref) async => []),
      consultationDepartmentsProvider.overrideWith(
        (ref) async => const [
          ConsultationDepartment(
            id: 'sales',
            slug: 'sales',
            name: 'Sales',
            description: 'Property sales & purchase guidance',
            iconName: 'briefcase',
            responseTimeLabel: 'Immediate',
            advisorCount: 12,
            durationMinutes: 45,
          ),
        ],
      ),
      consultationAdvisorsProvider.overrideWith((ref, _) async => const []),
      consultationSlotsProvider.overrideWith((ref, _) async => const []),
      callbackSettingsProvider.overrideWith(
        (ref) async => const CallbackSettings(id: 'test'),
      ),
      callbackDepartmentsProvider.overrideWith((ref) async => []),
      callbackPrioritiesProvider.overrideWith((ref) async => []),
      callbackWorkingHoursProvider.overrideWith((ref) async => []),
    ];

Future<void> _pumpHub(WidgetTester tester, {Widget? home}) async {
  VisibilityDetectorController.instance.updateInterval = Duration.zero;
  await tester.binding.setSurfaceSize(const Size(1280, 16000));
  addTearDown(() {
    tester.binding.setSurfaceSize(null);
    VisibilityDetectorController.instance.updateInterval =
        const Duration(milliseconds: 500);
  });

  // Long CMS property/estate labels can overflow narrow dropdown chrome in tests.
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.toString();
    if (text.contains('A RenderFlex overflowed')) return;
    previous?.call(details);
  };
  addTearDown(() => FlutterError.onError = previous);

  await tester.pumpWidget(
    ProviderScope(
      overrides: _overrides,
      child: MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: SingleChildScrollView(
            child: home ?? const ContactPage(),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  // VisibilityDetector + ViewportMount (no failsafe; surface is tall enough
  // that hub sections are already in view).
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('Contact hub shows peak mockup sections with embedded wizards',
      (tester) async {
    await _pumpHub(tester);

    expect(find.text('CONTACT HD HOMES'), findsOneWidget);
    expect(find.text('Book an inspection'), findsOneWidget);
    expect(find.text('Book Your Private Consultation'), findsWidgets);
    expect(find.text('Personal Information'), findsWidgets);
    expect(find.text('Request a Callback'), findsWidgets);
    expect(find.text('CALLBACK'), findsOneWidget);
    expect(find.text('Your Name'), findsWidgets);
    expect(find.textContaining('Live'), findsWidgets);

    expect(find.text('Support Center'), findsOneWidget);
    expect(find.text('Careers Contact'), findsOneWidget);
    expect(find.text('Partnership Requests'), findsOneWidget);
    expect(find.text('Submit Ticket'), findsOneWidget);
    expect(find.text('Call Us'), findsWidgets);

    // Deleted Volume-2 leftovers must stay gone.
    expect(find.text('Open full calendar booking'), findsNothing);
    expect(find.text('WhatsApp integration'), findsNothing);
    expect(find.text('Interactive map'), findsNothing);
    expect(find.text('Open in Google Maps'), findsNothing);
    expect(find.text('Department directory'), findsNothing);
    expect(find.text('Emergency contacts'), findsNothing);
    expect(find.text('AI conversation assistant'), findsNothing);
    expect(find.text('How inquiries progress'), findsNothing);
    expect(find.text('Frequently asked questions'), findsNothing);
    expect(find.text('Request inspection follow-up'), findsNothing);

    await _disposeTree(tester);
  });

  testWidgets('Inspection hub section embeds full booking wizard',
      (tester) async {
    await _pumpHub(
      tester,
      home: const ContactPage(initialTarget: ContactScrollTarget.inspection),
    );

    expect(find.text('Book an inspection'), findsOneWidget);
    expect(find.text('Personal Information'), findsWidgets);
    expect(find.text('Continue'), findsWidgets);
    expect(find.text('Open full calendar booking'), findsNothing);
    expect(find.text('Request inspection follow-up'), findsNothing);

    await _disposeTree(tester);
  });
}
