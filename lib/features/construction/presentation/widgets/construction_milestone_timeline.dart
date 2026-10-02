import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/construction/domain/entities/construction_platform_models.dart';
import 'package:lucide_icons/lucide_icons.dart';

class ConstructionMilestoneTimeline extends StatelessWidget {
  const ConstructionMilestoneTimeline({
    super.key,
    required this.milestones,
    this.activeIndex,
    this.compact = false,
    this.projectProgressPct = 0,
  });

  final List<ConstructionMilestonePublic> milestones;
  final int? activeIndex;
  final bool compact;
  final double projectProgressPct;

  @override
  Widget build(BuildContext context) {
    if (milestones.isEmpty) return const SizedBox.shrink();

    final active = activeIndex ??
        milestones.indexWhere((m) => m.isActive).clamp(0, milestones.length - 1);

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 520 || compact;
        if (stacked) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < milestones.length; i++)
                  SizedBox(
                    width: 108,
                    child: _MilestoneNode(
                      milestone: milestones[i],
                      index: i,
                      activeIndex: active,
                      isLast: i == milestones.length - 1,
                      projectProgressPct: projectProgressPct,
                    ),
                  ),
              ],
            ),
          );
        }
        return Row(
          children: [
            for (var i = 0; i < milestones.length; i++)
              Expanded(
                    child: _MilestoneNode(
                      milestone: milestones[i],
                      index: i,
                      activeIndex: active,
                      isLast: i == milestones.length - 1,
                      projectProgressPct: projectProgressPct,
                    ),
              ),
          ],
        );
      },
    );
  }
}

class _MilestoneNode extends StatelessWidget {
  const _MilestoneNode({
    required this.milestone,
    required this.index,
    required this.activeIndex,
    required this.isLast,
    required this.projectProgressPct,
  });

  final ConstructionMilestonePublic milestone;
  final int index;
  final int activeIndex;
  final bool isLast;
  final double projectProgressPct;

  @override
  Widget build(BuildContext context) {
    final completed = milestone.isCompleted || index < activeIndex;
    final active = index == activeIndex && !completed;

    Color nodeColor;
    Widget nodeChild;
    if (completed) {
      nodeColor = AppColors.success;
      nodeChild = const Icon(LucideIcons.check, size: 12, color: Colors.white);
    } else if (active) {
      nodeColor = AppColors.gold;
      nodeChild = Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: AppColors.gold,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.45),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
      );
    } else {
      nodeColor = AppColors.charcoal;
      nodeChild = Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.textSecondaryDark.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    final pctLabel = completed
        ? '100%'
        : active
            ? '${(milestone.progressPct > 0 ? milestone.progressPct : projectProgressPct).round()}%'
            : '0%';

    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: completed || active
                    ? nodeColor.withValues(alpha: completed ? 1 : 0.15)
                    : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: completed || active ? nodeColor : AppColors.charcoal,
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: nodeChild,
            ),
            if (!isLast)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  color: index < activeIndex
                      ? AppColors.gold
                      : AppColors.charcoal.withValues(alpha: 0.5),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          milestone.name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: active
                ? AppColors.gold
                : completed
                    ? AppColors.white
                    : AppColors.textSecondaryDark,
            fontSize: 10,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          pctLabel,
          style: TextStyle(
            color: active
                ? AppColors.gold
                : completed
                    ? AppColors.success
                    : AppColors.textSecondaryDark.withValues(alpha: 0.7),
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
