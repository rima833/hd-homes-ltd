import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/l10n/app_strings.dart';

enum ExperienceMode {
  lifestyle,
  budget,
  investment,
  map,
}

extension ExperienceModeX on ExperienceMode {
  String get label => switch (this) {
        ExperienceMode.lifestyle => AppStrings.modeLifestyle,
        ExperienceMode.budget => AppStrings.modeBudget,
        ExperienceMode.investment => AppStrings.modeInvestment,
        ExperienceMode.map => AppStrings.modeMap,
      };

  IconData get icon => switch (this) {
        ExperienceMode.lifestyle => Icons.favorite_outline_rounded,
        ExperienceMode.budget => Icons.payments_outlined,
        ExperienceMode.investment => Icons.trending_up_rounded,
        ExperienceMode.map => Icons.map_outlined,
      };

  String get route => switch (this) {
        ExperienceMode.lifestyle => RoutePaths.properties,
        ExperienceMode.budget => RoutePaths.properties,
        ExperienceMode.investment => RoutePaths.investment,
        ExperienceMode.map => RoutePaths.estates,
      };
}

/// Visitor exploration mode selector (personalization scaffold).
class ExperienceModesBar extends StatelessWidget {
  const ExperienceModesBar({
    super.key,
    this.selected,
    this.onSelected,
  });

  final ExperienceMode? selected;
  final ValueChanged<ExperienceMode>? onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
      child: Row(
        children: ExperienceMode.values.map((mode) {
          final isSelected = selected == mode;
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: FilterChip(
              selected: isSelected,
              showCheckmark: false,
              avatar: Icon(
                mode.icon,
                size: 18,
                color: isSelected ? AppColors.deepBlack : AppColors.gold,
              ),
              label: Text(mode.label),
              selectedColor: AppColors.gold,
              backgroundColor: Theme.of(context).colorScheme.surface,
              side: BorderSide(
                color: isSelected ? AppColors.gold : AppColors.neutral200,
              ),
              onSelected: (_) {
                onSelected?.call(mode);
                context.go(mode.route);
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}
