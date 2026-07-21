import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/features/home/data/models/home_cms_content.dart';
import 'package:hdhomesproject/features/home/presentation/widgets/animated_statistic.dart';

/// Section 6 — Quick statistics with animated counters.
class HomeStatsSection extends StatelessWidget {
  const HomeStatsSection({super.key, required this.stats});

  final List<HomeStatItem> stats;

  @override
  Widget build(BuildContext context) {
    final columns = context.isMobile ? 2 : context.isTablet ? 4 : 4;

    return SectionWrapper(
      backgroundColor: AppColors.charcoal,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth.isFinite && constraints.maxWidth > 0
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;
          final gaps = (columns - 1) * AppSpacing.lg;
          final raw = (maxW - gaps) / columns;
          final itemWidth = raw.isFinite ? raw.clamp(96.0, maxW) : 160.0;

          return Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.xl,
            alignment: WrapAlignment.center,
            children: stats
                .map(
                  (stat) => SizedBox(
                    width: itemWidth,
                    child: AnimatedStatistic(
                      value: stat.value,
                      label: stat.label,
                      suffix: stat.suffix,
                      textColor: AppColors.white,
                      valueColor: AppColors.gold,
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }
}
