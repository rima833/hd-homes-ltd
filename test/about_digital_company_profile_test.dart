import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/about/data/models/about_cms_content.dart';
import 'package:hdhomesproject/features/about/presentation/sections/about_digital_company_profile_section.dart';

void main() {
  testWidgets('Digital company profile renders mockup content and KPIs',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const profile = AboutCompanyProfile(
      title: 'Digital company profile',
      description:
          'Interactive overview of our history, projects, leadership, and investment opportunities.',
      cardTitle: 'Interactive Company Profile',
      downloadUrl: '#',
      viewUrl: '#',
      trustStats: [
        AboutProfileTrustStat(value: '15+', label: 'Years Experience'),
        AboutProfileTrustStat(value: '3200+', label: 'Homes Delivered'),
        AboutProfileTrustStat(value: '12000+', label: 'Happy Clients'),
        AboutProfileTrustStat(value: '48', label: 'Projects Completed'),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supabaseConfiguredProvider.overrideWithValue(false),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AboutDigitalCompanyProfileSection(fallback: profile),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));

    expect(tester.takeException(), isNull);
    expect(find.text('Digital company profile'), findsOneWidget);
    expect(find.text('Interactive Company Profile'), findsOneWidget);
    expect(find.text('Download PDF'), findsOneWidget);
    expect(find.text('Download Brochure'), findsOneWidget);
    expect(find.text('OR'), findsOneWidget);
    expect(find.text('15+'), findsOneWidget);
    expect(find.text('Happy Clients'), findsOneWidget);
    expect(find.text('Projects Completed'), findsOneWidget);
  });
}
