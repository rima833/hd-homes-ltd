import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/app_theme.dart';
import 'package:hdhomesproject/features/trust/data/providers/trust_document_verification_provider.dart';
import 'package:hdhomesproject/features/trust/presentation/pages/trust_center_page.dart';

void main() {
  test('verifyDocument validates known certificate references', () {
    final result = verifyDocument('REDAN-2018-042');
    expect(result.isValid, isTrue);
    expect(result.status, 'Verified authentic');
  });

  test('verifyDocument rejects unknown references', () {
    final result = verifyDocument('INVALID-REF');
    expect(result.isValid, isFalse);
  });

  testWidgets('Trust center page loads transparency sections', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 2400));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(body: TrustCenterPage()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Built on Trust'), findsOneWidget);
    expect(find.text('Why trust HD Homes'), findsOneWidget);
    expect(find.text('Licenses & certifications'), findsOneWidget);
    expect(find.text('Legal document center'), findsOneWidget);

    addTearDown(() => tester.binding.setSurfaceSize(null));
  });
}
