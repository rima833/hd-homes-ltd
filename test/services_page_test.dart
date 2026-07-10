import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/app_theme.dart';
import 'package:hdhomesproject/features/services/presentation/pages/service_detail_page.dart';
import 'package:hdhomesproject/features/services/presentation/pages/services_page.dart';

void main() {
  testWidgets('Services page loads catalog and sections', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 6400));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(body: SingleChildScrollView(child: ServicesPage())),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(seconds: 2));

    expect(find.textContaining('Building Exceptional Spaces'), findsOneWidget);
    expect(find.text('Service categories'), findsOneWidget);
    expect(find.text('Featured services'), findsOneWidget);
    expect(find.text('Why choose HD Homes'), findsOneWidget);
    expect(find.text('Smart project estimator'), findsOneWidget);
    expect(find.text('Request a consultation'), findsOneWidget);

    addTearDown(() => tester.binding.setSurfaceSize(null));
  });

  testWidgets('Service detail page loads landing sections', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 5200));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: ServiceDetailPage(serviceSlug: 'property-sales'),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Property Sales'), findsWidgets);
    expect(find.text('Key benefits'), findsOneWidget);
    expect(find.text('How we deliver'), findsOneWidget);
    expect(find.text('Project eligibility checker'), findsOneWidget);
    expect(find.text('You may also need'), findsOneWidget);

    addTearDown(() => tester.binding.setSurfaceSize(null));
  });

  testWidgets('Service detail shows not found for invalid slug', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: ServiceDetailPage(serviceSlug: 'invalid-service'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Service not found'), findsOneWidget);
    expect(find.text('Browse services'), findsOneWidget);
  });
}
