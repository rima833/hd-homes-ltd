import 'package:flutter/animation.dart';
import 'package:hdhomesproject/core/theme/tokens/app_durations.dart';

/// Animation curves and presets.
abstract final class AppAnimations {
  static const Curve standard = Curves.easeOutCubic;
  static const Curve enter = Curves.easeOut;
  static const Curve exit = Curves.easeIn;
  static const Curve bounce = Curves.easeOutBack;

  static const Duration fadeIn = AppDurations.normal;
  static const Duration slideIn = AppDurations.normal;
  static const Duration scaleIn = AppDurations.fast;
  static const Duration hover = AppDurations.fast;
}
