import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/app_theme.dart';
import 'package:hdhomesproject/features/about/presentation/pages/about_page.dart';

void main() {
  testWidgets('About page loads corporate content', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 2400));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(body: SingleChildScrollView(child: AboutPage())),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Building Homes'), findsOneWidget);
    expect(find.textContaining('Meet our leadership team'), findsOneWidget);
    expect(find.textContaining('Trust & compliance center'), findsWidgets);

    addTearDown(() => tester.binding.setSurfaceSize(null));
  });
}
