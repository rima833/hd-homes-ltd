import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/app.dart';

void main() {
  testWidgets('App loads home page with branding', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: HdHomesApp(),
      ),
    );

    // Cinematic splash (~1.6s) + fade-out
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('HD Homes Limited'), findsWidgets);
    expect(find.text('Making Quality Housing Accessible'), findsWidgets);
    expect(find.textContaining('Building Exceptional Homes'), findsOneWidget);
  });
}
