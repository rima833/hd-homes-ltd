import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Applies [BackdropFilter] on native platforms; skips it on web.
///
/// BackdropFilter is known to freeze Flutter web on some GPUs — use this
/// anywhere a glass blur is decorative rather than required.
Widget webSafeBackdropBlur({
  required double sigma,
  required Widget child,
}) {
  if (kIsWeb) return child;
  return BackdropFilter(
    filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
    child: child,
  );
}
