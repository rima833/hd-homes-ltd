import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/theme/app_theme.dart';
import 'package:hdhomesproject/features/properties/presentation/pages/marketplace_page.dart';

void main() {
  testWidgets('Marketplace page loads search and results', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 2400));

    final router = GoRouter(
      initialLocation: RoutePaths.properties,
      routes: [
        GoRoute(
          path: RoutePaths.properties,
          builder: (_, _) => const Scaffold(
            body: SingleChildScrollView(child: MarketplacePage()),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supabaseConfiguredProvider.overrideWithValue(false),
        ],
        child: MaterialApp.router(
          theme: AppTheme.dark,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('Find Your Perfect Property'), findsOneWidget);
    expect(find.text('4-Bedroom Luxury Duplex'), findsWidgets);

    addTearDown(() => tester.binding.setSurfaceSize(null));
  });
}
