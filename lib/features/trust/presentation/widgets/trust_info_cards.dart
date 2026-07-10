import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

abstract final class TrustIcons {
  static IconData resolve(String name) => switch (name) {
        'building' => LucideIcons.building2,
        'users' => LucideIcons.users,
        'eye' => LucideIcons.eye,
        'shieldCheck' => LucideIcons.shieldCheck,
        'scale' => LucideIcons.scale,
        'heart' => LucideIcons.heart,
        'lock' => LucideIcons.lock,
        'badgeCheck' => LucideIcons.badgeCheck,
        _ => LucideIcons.checkCircle,
      };
}
