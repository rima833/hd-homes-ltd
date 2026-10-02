import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/core/theme/app_theme.dart';
import 'package:hdhomesproject/features/about/data/models/about_cms_content.dart';
import 'package:hdhomesproject/features/about/presentation/pages/about_page.dart';
import 'package:hdhomesproject/features/about/presentation/sections/about_services_section.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('About page', () {
    testWidgets('loads corporate content without Supabase', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 3200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supabaseConfiguredProvider.overrideWithValue(false),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const Scaffold(
              body: SingleChildScrollView(child: AboutPage()),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Building Homes'), findsOneWidget);
      expect(find.textContaining('Meet our leadership team'), findsNothing);
      expect(find.textContaining('Trust & compliance center'), findsNothing);
      expect(find.text('Our services'), findsNothing);
      expect(find.textContaining('Why choose'), findsWidgets);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('services section layouts in scroll view at desktop + mobile',
        (tester) async {
      final why = List.generate(
        8,
        (i) => AboutWhyChooseItem(
          title: 'Title $i',
          description: 'Desc $i',
          iconName: 'shield',
        ),
      );
      final services = List.generate(
        8,
        (i) => AboutServiceItem(
          title: 'Service $i',
          description: 'Desc $i',
          iconName: 'home',
          route: '/properties',
        ),
      );

      for (final size in const [Size(1400, 900), Size(390, 800)]) {
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, __) => Scaffold(
                body: SingleChildScrollView(
                  child: AboutServicesSection(
                    whyChoose: why,
                    services: services,
                  ),
                ),
              ),
            ),
          ],
        );

        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(tester.takeException(), isNull, reason: 'size $size');
        expect(find.text('Our services'), findsNothing);
        expect(find.textContaining('Why choose'), findsWidgets);
      }

      addTearDown(() => tester.binding.setSurfaceSize(null));
    });
  });
}
