import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/core/website/components/viewport_mount.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  testWidgets('ViewportMount failsafe mounts child if visibility never fires',
      (tester) async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() {
      tester.binding.setSurfaceSize(null);
      VisibilityDetectorController.instance.updateInterval =
          const Duration(milliseconds: 500);
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: 5000),
                ViewportMount(
                  placeholderHeight: 200,
                  maxWait: Duration(milliseconds: 200),
                  child: Text('failsafe-mounted'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('failsafe-mounted'), findsNothing);

    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('failsafe-mounted'), findsOneWidget);

    // Flush any residual VisibilityDetector timers.
    await tester.pump(const Duration(milliseconds: 50));
  });
}
