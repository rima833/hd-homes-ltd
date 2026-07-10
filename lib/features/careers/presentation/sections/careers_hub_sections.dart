import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/features/careers/data/models/careers_hub_content.dart';
import 'package:hdhomesproject/features/careers/data/providers/careers_cms_provider.dart';
import 'package:hdhomesproject/features/careers/presentation/widgets/career_icons.dart';
import 'package:hdhomesproject/features/careers/presentation/widgets/career_job_card.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Hub sections — culture, values, benefits, open roles.
class CareersHubSections extends HookConsumerWidget {
  const CareersHubSections({
    super.key,
    this.rolesKey,
    this.onApply,
  });

  final GlobalKey? rolesKey;
  final ValueChanged<CareerJob>? onApply;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cms = ref.watch(careersHubCmsProvider);
    final departmentFilter = useState<CareerDepartment?>(null);
    final typeFilter = useState<CareerEmploymentType?>(null);

    final filtered = cms.jobs.where((job) {
      if (departmentFilter.value != null && job.department != departmentFilter.value) return false;
      if (typeFilter.value != null && job.employmentType != typeFilter.value) return false;
      return true;
    }).toList();

    return Column(
      children: [
        SectionWrapper(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AnimatedSectionTitle(
                overline: 'CULTURE',
                title: 'Life at HD Homes',
                subtitle: 'A growth-oriented culture building careers alongside communities.',
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(cms.cultureSummary, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: AppSpacing.xl),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cross = context.isMobile ? 2 : 4;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cross,
                      mainAxisSpacing: AppSpacing.base,
                      crossAxisSpacing: AppSpacing.base,
                      childAspectRatio: context.isMobile ? 0.9 : 1.05,
                    ),
                    itemCount: cms.values.length,
                    itemBuilder: (_, i) {
                      final value = cms.values[i];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(CareerIcons.resolve(value.iconName), color: AppColors.gold),
                              const SizedBox(height: AppSpacing.sm),
                              Text(value.title, style: Theme.of(context).textTheme.titleSmall),
                              const SizedBox(height: AppSpacing.xs),
                              Expanded(
                                child: Text(value.description, style: Theme.of(context).textTheme.bodySmall),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
        SectionWrapper(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'BENEFITS',
                title: 'Why work with us',
                subtitle: 'Competitive compensation, development, and meaningful impact.',
              ),
              const SizedBox(height: AppSpacing.lg),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cross = context.isMobile ? 1 : 3;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cross,
                      mainAxisSpacing: AppSpacing.base,
                      crossAxisSpacing: AppSpacing.base,
                      childAspectRatio: context.isMobile ? 2.4 : 1.8,
                    ),
                    itemCount: cms.benefits.length,
                    itemBuilder: (_, i) {
                      final benefit = cms.benefits[i];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(benefit.title, style: Theme.of(context).textTheme.titleSmall),
                              const SizedBox(height: AppSpacing.xs),
                              Text(benefit.description, style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
        SectionWrapper(
          key: rolesKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AnimatedSectionTitle(
                overline: 'OPEN ROLES',
                title: 'Current opportunities',
                subtitle: 'Filter by department or employment type.',
              ),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  FilterChip(
                    label: const Text('All departments'),
                    selected: departmentFilter.value == null,
                    onSelected: (_) => departmentFilter.value = null,
                  ),
                  ...CareerDepartment.values.map(
                    (d) => FilterChip(
                      label: Text(d.label),
                      selected: departmentFilter.value == d,
                      onSelected: (selected) => departmentFilter.value = selected ? d : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  FilterChip(
                    label: const Text('All types'),
                    selected: typeFilter.value == null,
                    onSelected: (_) => typeFilter.value = null,
                  ),
                  ...CareerEmploymentType.values.map(
                    (t) => FilterChip(
                      label: Text(t.label),
                      selected: typeFilter.value == t,
                      onSelected: (selected) => typeFilter.value = selected ? t : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Center(child: Text('No roles match these filters. Try clearing filters or submit a general application.')),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cross = context.isMobile ? 1 : 2;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cross,
                        mainAxisSpacing: AppSpacing.base,
                        crossAxisSpacing: AppSpacing.base,
                        childAspectRatio: context.isMobile ? 0.95 : 1.2,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) => CareerJobCard(
                        job: filtered[i],
                        onApply: () => onApply?.call(filtered[i]),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}
