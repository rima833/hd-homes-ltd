import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/core/theme/app_theme.dart';
import 'package:hdhomesproject/features/website_forms/domain/entities/website_form_models.dart';
import 'package:hdhomesproject/features/website_forms/presentation/providers/website_forms_providers.dart';
import 'package:hdhomesproject/features/website_forms/presentation/widgets/website_careers_form.dart';
import 'package:hdhomesproject/features/website_forms/presentation/widgets/website_partnership_form.dart';
import 'package:hdhomesproject/features/website_forms/presentation/widgets/website_support_form.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrap(Widget child) {
    return ProviderScope(
      overrides: [supabaseConfiguredProvider.overrideWith((ref) => false)],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
  }

  testWidgets('Support center form renders approved UI and validates', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(wrap(const SupportTicketForm()));
    await tester.pumpAndSettle();

    expect(find.text('SUPPORT'), findsOneWidget);
    expect(find.text('Support Center'), findsOneWidget);
    expect(find.text('Submit Ticket'), findsOneWidget);

    await tester.tap(find.text('Submit Ticket'));
    await tester.pumpAndSettle();
    expect(find.text('Required'), findsWidgets);
  });

  testWidgets('Careers contact form renders approved UI', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(wrap(const CareersContactForm()));
    await tester.pumpAndSettle();

    expect(find.text('CAREERS'), findsOneWidget);
    expect(find.text('Careers Contact'), findsOneWidget);
    expect(find.text('Upload CV'), findsOneWidget);
    expect(find.text('Submit Application'), findsOneWidget);
  });

  testWidgets('Partnership requests form renders approved UI and validates', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(wrap(const PartnershipRequestForm()));
    await tester.pumpAndSettle();

    expect(find.text('PARTNERSHIPS'), findsOneWidget);
    expect(find.text('Partnership Requests'), findsOneWidget);
    expect(find.text('Upload documents'), findsOneWidget);
    expect(find.text('Submit Partnership Request'), findsOneWidget);

    await tester.tap(find.text('Submit Partnership Request'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Required'), findsWidgets);
  });

  testWidgets('Disabled support form shows admin message instead of inputs', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supabaseConfiguredProvider.overrideWith((ref) => false),
          websiteSupportSettingsProvider.overrideWith(
            (ref) async => const WebsiteSupportSettings(
              id: 'test',
              isEnabled: false,
              disabledMessage: 'Support submissions are temporarily unavailable.',
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: SingleChildScrollView(child: SupportTicketForm()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Support submissions are temporarily unavailable.'), findsOneWidget);
    expect(find.text('Submit Ticket'), findsNothing);
  });
}
