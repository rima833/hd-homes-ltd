import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/cta_banner.dart';
import 'package:hdhomesproject/core/website/components/page_container.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/services/data/models/service_models.dart';
import 'package:hdhomesproject/features/services/data/providers/service_detail_provider.dart';
import 'package:hdhomesproject/features/services/data/providers/services_catalog_provider.dart';
import 'package:hdhomesproject/features/services/presentation/widgets/consultation_form.dart';
import 'package:hdhomesproject/features/services/presentation/widgets/service_icons.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Sections 5–12 + enterprise — Why choose, process, case studies, consultation.
class ServicesClosingSections extends HookConsumerWidget {
  const ServicesClosingSections({super.key, this.consultationKey});

  final GlobalKey? consultationKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cms = ref.watch(servicesCmsProvider);
    final faqQuery = useState('');
    final projectType = useState('Residential Build');
    final sizeSqm = useState(250.0);
    final budget = useState(50);
    final location = useState('Lagos');
    final timeline = useState('Standard (12–24 months)');

    final estimate = estimateProject(
      projectType: projectType.value,
      sizeSqm: sizeSqm.value,
      budgetMillions: budget.value,
      location: location.value,
      timeline: timeline.value,
    );

    final filteredFaqs = cms.faqs
        .where(
          (f) =>
              faqQuery.value.isEmpty ||
              f.question.toLowerCase().contains(faqQuery.value.toLowerCase()) ||
              f.answer.toLowerCase().contains(faqQuery.value.toLowerCase()),
        )
        .toList();

    return Column(
      children: [
        SectionWrapper(
          child: PageContainer(
            child: Column(
              children: [
                const AnimatedSectionTitle(
                  overline: 'WHY HD HOMES',
                  title: 'Why choose HD Homes',
                ),
                const SizedBox(height: AppSpacing.xl),
                Wrap(
                  spacing: AppSpacing.base,
                  runSpacing: AppSpacing.base,
                  children: cms.whyChoose
                      .map(
                        (w) => SizedBox(
                          width: context.isMobile ? double.infinity : 280,
                          child: _WhyCard(item: w),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ),
        SectionWrapper(
          backgroundColor: AppColors.charcoal,
          child: PageContainer(
            child: Column(
              children: [
                const AnimatedSectionTitle(
                  overline: 'PROCESS',
                  title: 'Our process',
                  subtitle: 'A transparent workflow from inquiry to after-sales support.',
                ),
                const SizedBox(height: AppSpacing.xl),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  alignment: WrapAlignment.center,
                  children: [
                    for (var i = 0; i < cms.processSteps.length; i++) ...[
                      _ProcessChip(step: cms.processSteps[i], index: i + 1),
                      if (i < cms.processSteps.length - 1)
                        Icon(
                          LucideIcons.arrowRight,
                          size: 16,
                          color: AppColors.gold.withValues(alpha: 0.6),
                        ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        SectionWrapper(
          child: PageContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AnimatedSectionTitle(
                  overline: 'CASE STUDIES',
                  title: 'Proven results',
                  alignment: TextAlign.start,
                ),
                const SizedBox(height: AppSpacing.xl),
                for (final cs in cms.caseStudies)
                  Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.base),
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      borderRadius: AppRadius.cardBorder,
                      border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cs.client, style: Theme.of(context).textTheme.titleMedium),
                        Text(cs.service, style: const TextStyle(color: AppColors.gold)),
                        const SizedBox(height: AppSpacing.sm),
                        Text('Challenge: ${cs.challenge}'),
                        Text('Solution: ${cs.solution}'),
                        Text('Results: ${cs.results}', style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: AppSpacing.sm),
                        TextButton(
                          onPressed: () => context.go('/services/${cs.serviceSlug}'),
                          child: const Text('View service →'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        SectionWrapper(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: PageContainer(
            child: Column(
              children: [
                const AnimatedSectionTitle(
                  overline: 'TECHNOLOGY',
                  title: 'Technology & innovation',
                ),
                const SizedBox(height: AppSpacing.xl),
                Wrap(
                  spacing: AppSpacing.base,
                  runSpacing: AppSpacing.base,
                  children: cms.technologies
                      .map(
                        (t) => SizedBox(
                          width: context.isMobile ? double.infinity : 200,
                          child: _TechTile(tech: t),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ),
        SectionWrapper(
          child: PageContainer(
            child: Column(
              children: [
                const AnimatedSectionTitle(
                  overline: 'INDUSTRIES',
                  title: 'Industries we serve',
                ),
                const SizedBox(height: AppSpacing.xl),
                Wrap(
                  spacing: AppSpacing.base,
                  runSpacing: AppSpacing.base,
                  children: cms.industries
                      .map(
                        (ind) => Chip(
                          avatar: Icon(ServiceIcons.resolve(ind.iconName), size: 16, color: AppColors.gold),
                          label: Text(ind.name),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ),
        SectionWrapper(
          backgroundColor: AppColors.charcoal,
          child: PageContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AnimatedSectionTitle(
                  overline: 'TESTIMONIALS',
                  title: 'Client testimonials',
                  alignment: TextAlign.start,
                ),
                const SizedBox(height: AppSpacing.lg),
                for (final t in cms.testimonials)
                  Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.base),
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.darkSurface,
                      borderRadius: AppRadius.cardBorder,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ...List.generate(
                              5,
                              (i) => Icon(
                                i < t.rating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                                color: AppColors.gold,
                                size: 16,
                              ),
                            ),
                            if (t.verified) ...[
                              const Spacer(),
                              const Text('Verified', style: TextStyle(fontSize: 11, color: AppColors.gold)),
                            ],
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text('"${t.comment}"', style: const TextStyle(color: AppColors.white)),
                        Text('${t.name} · ${t.role}'),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        SectionWrapper(
          child: PageContainer(
            child: Column(
              children: [
                const AnimatedSectionTitle(
                  overline: 'KNOWLEDGE CENTER',
                  title: 'Service knowledge hub',
                  subtitle: 'Guides, checklists, and resources — optimized for SEO.',
                ),
                const SizedBox(height: AppSpacing.lg),
                for (final article in cms.knowledgeArticles)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(LucideIcons.bookOpen, color: AppColors.gold),
                    title: Text(article.title),
                    subtitle: Text('${article.category} · ${article.readMinutes} min read'),
                    trailing: const Icon(Icons.arrow_forward_rounded),
                  ),
              ],
            ),
          ),
        ),
        SectionWrapper(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: PageContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AnimatedSectionTitle(
                  overline: 'ESTIMATOR',
                  title: 'Smart project estimator',
                  alignment: TextAlign.start,
                ),
                const SizedBox(height: AppSpacing.lg),
                DropdownMenu<String>(
                  initialSelection: projectType.value,
                  dropdownMenuEntries: const [
                    DropdownMenuEntry(value: 'Residential Build', label: 'Residential Build'),
                    DropdownMenuEntry(value: 'Commercial Build', label: 'Commercial Build'),
                    DropdownMenuEntry(value: 'Buy Property', label: 'Buy Property'),
                  ],
                  onSelected: (v) => projectType.value = v ?? projectType.value,
                ),
                Slider(
                  value: sizeSqm.value,
                  min: 50,
                  max: 2000,
                  label: '${sizeSqm.value.round()} sqm',
                  onChanged: (v) => sizeSqm.value = v,
                ),
                Slider(
                  value: budget.value.toDouble(),
                  min: 10,
                  max: 500,
                  divisions: 49,
                  label: '₦${budget.value}M',
                  onChanged: (v) => budget.value = v.round(),
                ),
                Text('Estimated cost: ${estimate.costRange}'),
                Text('Duration: ${estimate.duration}'),
                Text('Suggested: ${estimate.suggestedServices.join(', ')}'),
                Text(estimate.consultationNote, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
        SectionWrapper(
          backgroundColor: AppColors.charcoal,
          child: PageContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AnimatedSectionTitle(
                  overline: 'EXPERTS',
                  title: 'Live expert availability',
                  subtitle: 'Realtime consultant status via Supabase (placeholder).',
                  alignment: TextAlign.start,
                ),
                const SizedBox(height: AppSpacing.lg),
                for (final expert in cms.experts)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: expert.isOnline ? AppColors.success : AppColors.neutral500,
                      radius: 6,
                    ),
                    title: Text(expert.name, style: const TextStyle(color: AppColors.white)),
                    subtitle: Text('${expert.department} · ${expert.responseTime}'),
                    trailing: PrimaryButton(
                      label: 'Book',
                      onPressed: () => context.go(RoutePaths.contact),
                    ),
                  ),
              ],
            ),
          ),
        ),
        SectionWrapper(
          child: PageContainer(
            child: Column(
              children: [
                const AnimatedSectionTitle(overline: 'FAQ', title: 'Frequently asked questions'),
                const SizedBox(height: AppSpacing.base),
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search FAQs…',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: (v) => faqQuery.value = v,
                ),
                const SizedBox(height: AppSpacing.lg),
                for (final faq in filteredFaqs)
                  ExpansionTile(title: Text(faq.question), children: [Text(faq.answer)]),
              ],
            ),
          ),
        ),
        KeyedSubtree(
          key: consultationKey,
          child: SectionWrapper(
            backgroundColor: Theme.of(context).colorScheme.surface,
            child: PageContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AnimatedSectionTitle(
                    overline: 'CONSULTATION',
                    title: 'Request a consultation',
                    subtitle: 'Book a call, request a proposal, or schedule a site visit.',
                    alignment: TextAlign.start,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const ConsultationForm(),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.pagePadding,
            vertical: AppSpacing.section,
          ),
          child: CtaBanner(
            title: 'Ready to start your project?',
            subtitle: 'Speak with our experts and receive a tailored proposal within 48 hours.',
            primaryLabel: 'Book Consultation',
            primaryPath: RoutePaths.contact,
            secondaryLabel: 'Browse Services',
            secondaryPath: RoutePaths.services,
          ),
        ),
      ],
    );
  }
}

class _WhyCard extends StatelessWidget {
  const _WhyCard({required this.item});

  final ServiceWhyChooseItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.neutral200.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ServiceIcons.resolve(item.iconName), color: AppColors.gold),
          const SizedBox(height: AppSpacing.sm),
          Text(item.title, style: Theme.of(context).textTheme.titleSmall),
          Text(item.description, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ProcessChip extends StatelessWidget {
  const _ProcessChip({required this.step, required this.index});

  final String step;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: CircleAvatar(
        backgroundColor: AppColors.gold,
        child: Text('$index', style: const TextStyle(fontSize: 11, color: AppColors.deepBlack)),
      ),
      label: Text(step),
    );
  }
}

class _TechTile extends StatelessWidget {
  const _TechTile({required this.tech});

  final ServiceTechnology tech;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardBorder,
      ),
      child: Row(
        children: [
          Icon(ServiceIcons.resolve(tech.iconName), color: AppColors.gold),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tech.name, style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w600)),
                Text(tech.description, style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryDark)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
