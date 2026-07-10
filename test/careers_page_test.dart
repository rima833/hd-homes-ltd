import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/app_theme.dart';
import 'package:hdhomesproject/features/careers/presentation/pages/careers_page.dart';

void main() {
  testWidgets('Careers page loads key sections', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 3200));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(body: CareersPage()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Build the Future'), findsOneWidget);
    expect(find.text('Life at HD Homes'), findsOneWidget);
    expect(find.text('Current opportunities'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Submit your application'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Submit your application'), findsOneWidget);
    expect(find.text('Careers FAQ'), findsOneWidget);

    addTearDown(() => tester.binding.setSurfaceSize(null));
  });
}
