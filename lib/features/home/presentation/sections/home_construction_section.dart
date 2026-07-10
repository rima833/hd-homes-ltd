import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/home/data/models/home_cms_content.dart';

/// Sections 15–16 — Construction progress and project timeline.
class HomeConstructionSection extends StatelessWidget {
  const HomeConstructionSection({super.key, required this.projects});

  final List<HomeConstructionItem> projects;

  static const _phases = [
    'Planning',
    'Foundation',
    'Structure',
    'Roofing',
    'Finishing',
    'Completed',
  ];

  @override
  Widget build(BuildContext context) {
    return SectionWrapper(
      child: Column(
        children: [
          const AnimatedSectionTitle(
            overline: 'ON-SITE PROGRESS',
            title: 'Construction updates',
            subtitle: 'Transparent progress tracking across active developments.',
          ),
          const SizedBox(height: AppSpacing.xxl),
          for (final project in projects) ...[
            _ProjectCard(project: project, phases: _phases),
            const SizedBox(height: AppSpacing.lg),
          ],
        ],
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project, required this.phases});

  final HomeConstructionItem project;
  final List<String> phases;

  @override
  Widget build(BuildContext context) {
    final activePhase = (project.progress * phases.length).floor().clamp(0, phases.length - 1);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: AppRadius.cardBorder,
        boxShadow: AppShadows.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(project.name, style: Theme.of(context).textTheme.titleMedium),
              ),
              Text(
                '${(project.progress * 100).round()}%',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.gold),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          LinearProgressIndicator(
            value: project.progress,
            minHeight: 6,
            borderRadius: AppRadius.buttonBorder,
            backgroundColor: AppColors.neutral200,
            color: AppColors.gold,
          ),
          const SizedBox(height: AppSpacing.base),
          Text(project.update, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Expected completion: ${project.completionDate}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < phases.length; i++)
                  _PhaseChip(
                    label: phases[i],
                    active: i <= activePhase,
                    current: i == activePhase,
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          PrimaryButton(
            label: 'View Progress',
            variant: ButtonVariant.ghost,
            onPressed: () => context.go(project.route),
          ),
        ],
      ),
    );
  }
}

class _PhaseChip extends StatelessWidget {
  const _PhaseChip({
    required this.label,
    required this.active,
    required this.current,
  });

  final String label;
  final bool active;
  final bool current;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: active ? AppColors.gold.withValues(alpha: current ? 1 : 0.3) : AppColors.neutral100,
        borderRadius: AppRadius.buttonBorder,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: current ? FontWeight.w700 : FontWeight.w500,
          color: active ? AppColors.deepBlack : AppColors.neutral600,
        ),
      ),
    );
  }
}
