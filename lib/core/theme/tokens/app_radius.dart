import 'package:flutter/material.dart';

/// Border radius tokens — no sharp edges.
abstract final class AppRadius {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double pill = 999;
  static const double circle = 999;

  static const double button = 16;
  static const double card = 20;
  static const double dialog = 24;
  static const double input = 16;
  static const double image = 24;
  static const double badge = 8;
  static const double full = 999;

  static BorderRadius get buttonBorder => BorderRadius.circular(button);
  static BorderRadius get cardBorder => BorderRadius.circular(card);
  static BorderRadius get dialogBorder => BorderRadius.circular(dialog);
  static BorderRadius get inputBorder => BorderRadius.circular(input);
  static BorderRadius get imageBorder => BorderRadius.circular(image);
}
