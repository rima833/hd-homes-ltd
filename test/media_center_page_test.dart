import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/app_theme.dart';
import 'package:hdhomesproject/features/media/presentation/pages/media_center_hub_page.dart';
import 'package:hdhomesproject/features/media/presentation/pages/media_experience_page.dart';

void main() {
  testWidgets('Media center hub loads showroom sections', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 2400));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(body: MediaCenterHubPage()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Experience Properties Before You Visit'), findsOneWidget);
    expect(find.text('Featured media experiences'), findsOneWidget);
    expect(find.text('Press & brand kit'), findsOneWidget);

    addTearDown(() => tester.binding.setSurfaceSize(null));
  });

  testWidgets('Media experience page loads immersive sections', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 3200));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(body: MediaExperiencePage(slug: 'horizon-gardens')),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Horizon Gardens'), findsWidgets);
    expect(find.text('HD image gallery'), findsOneWidget);
    expect(find.text('Virtual property tour'), findsOneWidget);
    expect(find.text('Featured media'), findsOneWidget);

    addTearDown(() => tester.binding.setSurfaceSize(null));
  });

  testWidgets('Media experience page shows not found for unknown slug', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(body: MediaExperiencePage(slug: 'unknown-slug')),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Media experience not found'), findsOneWidget);
  });
}
