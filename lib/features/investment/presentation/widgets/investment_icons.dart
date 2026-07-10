import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

abstract final class InvestmentIcons {
  static IconData resolve(String name) => switch (name) {
        'trendingUp' => LucideIcons.trendingUp,
        'fileBarChart' => LucideIcons.fileBarChart,
        'shield' => LucideIcons.shield,
        'percent' => LucideIcons.percent,
        'pieChart' => LucideIcons.pieChart,
        'headphones' => LucideIcons.headphones,
        _ => LucideIcons.circleDollarSign,
      };
}
