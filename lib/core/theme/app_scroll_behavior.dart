import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Scroll with the mouse or trackpad, without drawing scrollbar tracks.
class HdHomesScrollBehavior extends MaterialScrollBehavior {
  const HdHomesScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.unknown,
  };

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
