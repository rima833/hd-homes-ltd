import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/inspection/domain/entities/inspection_booking_models.dart';
import 'package:hdhomesproject/features/inspection/presentation/pages/book_inspection_page.dart';
import 'package:hdhomesproject/features/inspection/presentation/providers/inspection_booking_controller.dart';

void main() {
  test('goNext advances only after each wizard step is valid', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(inspectionBookingControllerProvider.notifier);

    expect(notifier.goNext(), isFalse);
    expect(container.read(inspectionBookingControllerProvider).step, 0);

    notifier.patch(
      (d) => d.copyWith(
        fullName: 'Ada Lovelace',
        phone: '08031234567',
        email: 'ada@hdhomes.ng',
      ),
    );
    expect(notifier.goNext(), isTrue);
    expect(container.read(inspectionBookingControllerProvider).step, 1);
    expect(container.read(inspectionBookingControllerProvider).maxStepReached, 1);

    expect(notifier.goNext(), isFalse);
    notifier.patch((d) => d.copyWith(propertyId: 'prop-1'));
    expect(notifier.goNext(), isTrue);
    expect(container.read(inspectionBookingControllerProvider).step, 2);

    expect(notifier.goNext(), isFalse);
    notifier.patch(
      (d) => d.copyWith(
        preferredDate: DateTime(2026, 8, 16),
        preferredTime: const TimeOfDayLike(11, 0),
        scheduledAt: DateTime(2026, 8, 16, 11),
      ),
    );
    expect(notifier.goNext(), isTrue);
    expect(container.read(inspectionBookingControllerProvider).step, 3);

    expect(notifier.goNext(), isTrue);
    expect(container.read(inspectionBookingControllerProvider).step, 4);
  });

  test('setStep cannot skip ahead of reached wizard steps', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(inspectionBookingControllerProvider.notifier);

    notifier.setStep(3);
    expect(container.read(inspectionBookingControllerProvider).step, 0);

    notifier.patch(
      (d) => d.copyWith(
        fullName: 'Ada Lovelace',
        phone: '08031234567',
        email: 'ada@hdhomes.ng',
      ),
    );
    expect(notifier.goNext(), isTrue);
    notifier.setStep(3);
    expect(container.read(inspectionBookingControllerProvider).step, 1);
  });

  test('liveStep advances as the draft is filled', () {
    var draft = const InspectionBookingDraft();
    expect(draft.liveStep, 0);
    draft = draft.copyWith(
      fullName: 'Ada Lovelace',
      phone: '08031234567',
      email: 'ada@hdhomes.ng',
    );
    expect(draft.liveStep, 1);
    draft = draft.copyWith(propertyId: 'prop-1');
    expect(draft.liveStep, 2);
    draft = draft.copyWith(
      preferredDate: DateTime(2026, 8, 16),
      preferredTime: const TimeOfDayLike(11, 0),
    );
    expect(draft.liveStep, 3);
  });

  testWidgets('Continue moves from personal info to property', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supabaseConfiguredProvider.overrideWith((ref) => false),
          inspectionBookingRealtimeProvider.overrideWith((ref) {}),
          publishedEstatesCatalogProvider.overrideWith((ref) async => []),
          inspectionBookablePropertiesProvider.overrideWith(
            (ref) async => [
              const CmsPropertyFeatured(
                id: 'prop-1',
                title: 'Horizon Gardens 3BR',
                slug: 'horizon-gardens-3br',
                isPublished: true,
                bedrooms: 3,
                bathrooms: 2,
              ),
            ],
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BookInspectionPage(embedded: true),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Personal Information'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Full name'),
      'Ada Lovelace',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Phone number'),
      '08031234567',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email address'),
      'ada@hdhomes.ng',
    );
    await tester.pump();

    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Choose Property'), findsOneWidget);
  });
}
