import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/app_theme.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/contact/presentation/pages/contact_page.dart';

void main() {
  testWidgets('Contact hub loads lead generation sections', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 8000));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(body: SingleChildScrollView(child: ContactPage())),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(seconds: 2));

    expect(find.textContaining('Build Your Future'), findsOneWidget);
    expect(find.text('Choose how to reach us'), findsOneWidget);
    expect(find.text('Office directory'), findsOneWidget);
    expect(find.text('Book property inspection'), findsOneWidget);
    expect(find.text('Book a consultation'), findsOneWidget);
    expect(find.text('Request a callback'), findsOneWidget);
    expect(find.text('Department directory'), findsOneWidget);
    expect(find.text('Enterprise lead pipeline'), findsOneWidget);

    addTearDown(() => tester.binding.setSurfaceSize(null));
  });

  testWidgets('Book inspection route scrolls to inspection section', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 8000));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: ContactPage(initialTarget: ContactScrollTarget.inspection),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Book property inspection'), findsOneWidget);
    expect(find.widgetWithText(PrimaryButton, 'Book Inspection').last, findsOneWidget);

    addTearDown(() => tester.binding.setSurfaceSize(null));
  });

  testWidgets('Inspection form submits and shows CRM routing', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1200));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: ContactPage(initialTarget: ContactScrollTarget.inspection),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    await tester.enterText(find.widgetWithText(TextFormField, 'Full name *').first, 'John Doe');
    await tester.enterText(find.widgetWithText(TextFormField, 'Phone *').first, '+234 800 000 0000');
    await tester.enterText(find.widgetWithText(TextFormField, 'Email *').first, 'john@example.com');
    await tester.tap(find.widgetWithText(PrimaryButton, 'Book Inspection').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Request received'), findsOneWidget);
    expect(find.textContaining('Lead scored'), findsOneWidget);
    expect(find.text('Digital Visitor Pass'), findsOneWidget);

    addTearDown(() => tester.binding.setSurfaceSize(null));
  });
}
