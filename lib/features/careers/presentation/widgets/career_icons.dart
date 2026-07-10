import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

abstract final class CareerIcons {
  static IconData resolve(String name) => switch (name) {
        'award' => LucideIcons.award,
        'eye' => LucideIcons.eye,
        'sparkles' => LucideIcons.sparkles,
        'heart' => LucideIcons.heart,
        _ => LucideIcons.briefcase,
      };
}
