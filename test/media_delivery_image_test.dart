import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/core/media/widgets/delivery_image.dart';

void main() {
  testWidgets('MediaDeliveryImage shows placeholder for empty url', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 120,
            height: 80,
            child: MediaDeliveryImage(url: ''),
          ),
        ),
      ),
    );
    expect(find.byType(MediaDeliveryImage), findsOneWidget);
    expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
    // Lucide imageOff is used as default error/placeholder icon.
    expect(find.byType(Icon), findsOneWidget);
  });

  testWidgets('MediaDeliveryImage tolerates infinite layout sizes', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 120,
            child: MediaDeliveryImage(
              url: 'https://example.com/a.jpg',
              width: double.infinity,
              height: double.infinity,
            ),
          ),
        ),
      ),
    );
    // Should build without throwing on .round() of Infinity.
    await tester.pump();
    expect(find.byType(MediaDeliveryImage), findsOneWidget);
  });
}
