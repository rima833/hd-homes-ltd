import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

abstract final class SearchIcons {
  static IconData resolve(String name) => switch (name) {
        'home' => LucideIcons.home,
        'building' => LucideIcons.building2,
        'layers' => LucideIcons.layers,
        'grid' => LucideIcons.grid,
        'map' => LucideIcons.map,
        'briefcase' => LucideIcons.briefcase,
        'crown' => LucideIcons.crown,
        'sparkles' => LucideIcons.sparkles,
        'star' => LucideIcons.star,
        'key' => LucideIcons.key,
        'hardHat' => LucideIcons.hardHat,
        'trending' => LucideIcons.trendingUp,
        'users' => LucideIcons.users,
        'graduationCap' => LucideIcons.graduationCap,
        'trees' => LucideIcons.trees,
        'landmark' => LucideIcons.landmark,
        'waves' => LucideIcons.waves,
        'heart' => LucideIcons.heart,
        _ => LucideIcons.search,
      };
}
