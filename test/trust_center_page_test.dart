import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/app_theme.dart';
import 'package:hdhomesproject/features/trust/presentation/pages/trust_center_page.dart';

void main() {
  testWidgets('Trust center page loads live transparency sections', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 2400));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: TrustCenterPage(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('Built on Trust'), findsOneWidget);
    expect(find.text('Why trust HD Homes'), findsOneWidget);
    expect(find.text('Investor protection'), findsOneWidget);
    expect(find.text('Legal document center'), findsOneWidget);

    addTearDown(() => tester.binding.setSurfaceSize(null));
  });
}
