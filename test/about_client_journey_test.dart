import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/about/data/models/about_cms_content.dart';
import 'package:hdhomesproject/features/about/presentation/sections/about_client_journey_section.dart';

void main() {
  final canonicalSteps = [
    AboutProcessStep(
      title: 'Inquiry',
      description: 'Reach out via web, phone, or visit our sales office.',
      timeline: 'Day 1',
      iconName: 'message',
    ),
    AboutProcessStep(
      title: 'Consultation',
      description: 'Personalised needs assessment with our advisors.',
      timeline: '1-3 Days',
      iconName: 'users',
    ),
    AboutProcessStep(
      title: 'Property Selection',
      description: 'Choose from available units, estates, or investment products.',
      timeline: '1-2 Weeks',
      iconName: 'search',
    ),
    AboutProcessStep(
      title: 'Site Inspection',
      description: 'Tour the property or development site.',
      timeline: 'Scheduled',
      iconName: 'map_pin',
    ),
    AboutProcessStep(
      title: 'Documentation',
      description: 'Transparent contracts and verified title documents.',
      timeline: '1-2 Weeks',
      iconName: 'file',
    ),
    AboutProcessStep(
      title: 'Payment',
      description: 'Flexible plans aligned to your budget.',
      timeline: 'Ongoing',
      iconName: 'wallet',
    ),
    AboutProcessStep(
      title: 'Construction',
      description: 'Regular progress updates and milestone tracking.',
      timeline: 'Project-dependent',
      iconName: 'hard_hat',
    ),
    AboutProcessStep(
      title: 'Handover',
      description: 'Quality-checked delivery with full documentation.',
      timeline: 'On completion',
      iconName: 'key',
    ),
    AboutProcessStep(
      title: 'After-Sales Support',
      description: 'Dedicated support for maintenance and referrals.',
      timeline: 'Lifetime',
      iconName: 'headphones',
    ),
  ];

  testWidgets('Client journey renders Inquiry first and After-Sales last',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supabaseConfiguredProvider.overrideWithValue(false),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AboutClientJourneySection(fallbackSteps: canonicalSteps),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(tester.takeException(), isNull);
    expect(find.text('Our client journey'), findsOneWidget);
    expect(find.text('Transparent Process'), findsOneWidget);
    expect(find.text('Inquiry'), findsOneWidget);
    expect(find.text('After-Sales Support'), findsOneWidget);

    // Number badges follow logical order (not reversed).
    expect(find.text('01'), findsWidgets);
    expect(find.text('09'), findsWidgets);

    // Inquiry must appear before After-Sales in the paint/hit-test order.
    final inquiry = tester.getTopLeft(find.text('Inquiry'));
    final afterSales = tester.getTopLeft(find.text('After-Sales Support'));
    expect(inquiry.dy, lessThan(afterSales.dy));
  });
}
