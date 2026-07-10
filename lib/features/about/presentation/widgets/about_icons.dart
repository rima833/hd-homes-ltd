import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Shared icon resolver for About page sections.
abstract final class AboutIcons {
  static IconData resolve(String name) => switch (name) {
        'shield' => LucideIcons.shieldCheck,
        'sparkles' => LucideIcons.sparkles,
        'award' => LucideIcons.award,
        'heart' => LucideIcons.heart,
        'eye' => LucideIcons.eye,
        'star' => LucideIcons.star,
        'leaf' => LucideIcons.leaf,
        'users' => LucideIcons.users,
        'hard_hat' => LucideIcons.hardHat,
        'wallet' => LucideIcons.wallet,
        'map_pin' => LucideIcons.mapPin,
        'trending_up' => LucideIcons.trendingUp,
        'headphones' => LucideIcons.headphones,
        'file_check' => LucideIcons.fileCheck,
        'building' => LucideIcons.building2,
        'home' => LucideIcons.home,
        'pen_tool' => LucideIcons.penTool,
        'clipboard' => LucideIcons.clipboard,
        'map' => LucideIcons.map,
        'message_circle' => LucideIcons.messageCircle,
        'zap' => LucideIcons.zap,
        'droplet' => LucideIcons.droplet,
        'tree' => LucideIcons.trees,
        'cpu' => LucideIcons.cpu,
        'message' => LucideIcons.messageSquare,
        'search' => LucideIcons.search,
        'file' => LucideIcons.fileText,
        'key' => LucideIcons.key,
        _ => LucideIcons.circle,
      };
}
