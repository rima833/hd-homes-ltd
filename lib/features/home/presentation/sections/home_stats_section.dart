import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/website/components/company_statistics_section.dart';
import 'package:hdhomesproject/features/home/data/models/home_cms_content.dart';

/// Homepage company statistics — circular hub + summary cards from CMS.
class HomeStatsSection extends StatelessWidget {
  const HomeStatsSection({super.key, required this.stats});

  final List<HomeStatItem> stats;

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) return const SizedBox.shrink();

    return CompanyStatisticsSection(
      stats: [
        for (final s in stats)
          CompanyStatItem(
            value: s.value,
            label: s.label,
            suffix: s.suffix ?? '',
            description: s.description.isNotEmpty
                ? s.description
                : (s.caption ?? ''),
            iconName: s.iconName ?? 'barChart',
            logoUrl: s.logoUrl,
            placement: s.placement,
          ),
      ],
    );
  }
}
