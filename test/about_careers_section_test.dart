import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/core/theme/app_theme.dart';
import 'package:hdhomesproject/features/about/data/models/about_cms_content.dart';
import 'package:hdhomesproject/features/about/presentation/pages/about_page.dart';
import 'package:hdhomesproject/features/about/presentation/sections/about_careers_section.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget harness({required Widget child}) {
    final router = GoRouter(
      initialLocation: '/about',
      routes: [
        GoRoute(
          path: '/about',
          builder: (context, state) => Scaffold(
            body: SingleChildScrollView(child: child),
          ),
        ),
        GoRoute(
          path: '/careers',
          builder: (context, state) =>
              const Scaffold(body: Text('Careers destination')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        supabaseConfiguredProvider.overrideWithValue(false),
      ],
      child: MaterialApp.router(
        theme: AppTheme.dark,
        routerConfig: router,
      ),
    );
  }

  const fallback = AboutCareersPreview(
    whyWorkWithUs: ['Growth-oriented culture'],
    culture: 'We foster innovation and excellence.',
    benefits: ['Health Insurance'],
    openPositions: 8,
    ctaLabel: 'View Careers',
    ctaPath: '/careers',
  );

  testWidgets('About careers shows premium mockup only', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 5200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      harness(child: const AboutCareersSection(fallback: fallback)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(find.text('Join the HD Homes team'), findsNothing);
    expect(
      find.textContaining('Build the Future', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('With Us', findRichText: true), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Why Join HD Homes?'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Why Join HD Homes?'), findsOneWidget);
    expect(find.text('Growth & Learning'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Current Opportunities'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Current Opportunities'), findsOneWidget);
    expect(find.text('Civil Engineer'), findsOneWidget);
    expect(find.textContaining("Don't see the right role"), findsOneWidget);
  });

  testWidgets('About page mounts the careers section', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(harness(child: const AboutPage()));
    await tester.pump();
    expect(find.byType(AboutCareersSection), findsOneWidget);
    expect(
      find.textContaining('Build the Future', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Join the HD Homes team'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
  });
}
