import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/cta_banner.dart';
import 'package:hdhomesproject/core/website/components/published_faq_section.dart';
import 'package:hdhomesproject/core/website/components/published_testimonials_section.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/features/services/data/models/service_models.dart';
import 'package:hdhomesproject/features/services/data/providers/services_catalog_provider.dart';
import 'package:hdhomesproject/features/services/presentation/widgets/consultation_form.dart';
import 'package:hdhomesproject/features/services/presentation/widgets/service_cta.dart';
import 'package:hdhomesproject/features/services/presentation/widgets/service_icons.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Closing sections for the Services hub — lean, polished, conversion-focused.
class ServicesClosingSections extends ConsumerWidget {
  const ServicesClosingSections({super.key, this.consultationKey});

  final GlobalKey? consultationKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cms = ref.watch(servicesCmsProvider);

    return Column(
      children: [
        SectionWrapper(
          child: Column(
              children: [
                const AnimatedSectionTitle(
                  overline: 'WHY HD HOMES',
                  title: 'Why choose HD Homes',
                subtitle:
                    'Premium delivery, transparent process, and lasting client partnerships.',
                ),
                const SizedBox(height: AppSpacing.xl),
              LayoutBuilder(
                builder: (context, constraints) {
                  final maxW = constraints.maxWidth;
                  final cols = maxW >= 1100
                      ? 3
                      : maxW >= 700
                          ? 2
                          : 1;
                  final gap = AppSpacing.base;
                  final cardW = cols == 1
                      ? maxW
                      : (maxW - gap * (cols - 1)) / cols;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final w in cms.whyChoose)
                        SizedBox(width: cardW, child: _WhyCard(item: w)),
                    ],
                  );
                },
                ),
              ],
            ),
        ),
        SectionWrapper(
          backgroundColor: AppColors.charcoal,
          child: Column(
              children: [
                const AnimatedSectionTitle(
                  overline: 'PROCESS',
                title: 'How we deliver',
                subtitle:
                    'A clear path from first inquiry to after-sales support.',
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
        SectionWrapper(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AnimatedSectionTitle(
                  overline: 'CASE STUDIES',
                  title: 'Proven results',
                subtitle: 'Outcomes from real HD Homes engagements.',
                  alignment: TextAlign.start,
                ),
                const SizedBox(height: AppSpacing.xl),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 900;
                  if (!wide) {
                    return Column(
                      children: [
                        for (final cs in cms.caseStudies) ...[
                          _CaseStudyCard(study: cs),
                          const SizedBox(height: AppSpacing.base),
                        ],
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < cms.caseStudies.length; i++) ...[
                        if (i > 0) const SizedBox(width: AppSpacing.base),
                        Expanded(child: _CaseStudyCard(study: cms.caseStudies[i])),
                      ],
                    ],
                  );
                },
                ),
              ],
            ),
        ),
        const PublishedTestimonialsSection(
          backgroundColor: AppColors.charcoal,
          title: 'What clients say',
          subtitle:
              'Verified feedback across advisory, construction, and property services.',
        ),
        const PublishedFaqSection(
          title: 'Frequently asked questions',
          subtitle: 'Answers published from the website FAQ desk.',
        ),
        KeyedSubtree(
          key: consultationKey,
          child: SectionWrapper(
            backgroundColor: Theme.of(context).colorScheme.surface,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AnimatedSectionTitle(
                    overline: 'CONSULTATION',
                  title: 'Talk to a specialist',
                  subtitle:
                      'Book a live consultation — phone, video, or on-site — with the right department.',
                    alignment: TextAlign.start,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const ConsultationForm(),
                ],
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
            subtitle:
                'Speak with our experts and receive a tailored proposal within 48 hours.',
            primaryLabel: 'Book Consultation',
            primaryPath: RoutePaths.bookConsultation,
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.22)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.darkSurface.withValues(alpha: 0.9),
            AppColors.charcoal.withValues(alpha: 0.55),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.gold.withValues(alpha: 0.14),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
            ),
            child: Icon(
              ServiceIcons.resolve(item.iconName),
              color: AppColors.gold,
              size: 20,
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          Text(
            item.title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            item.description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondaryDark,
                  height: 1.45,
                ),
          ),
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
        child: Text(
          '$index',
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.deepBlack,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      label: Text(step),
      backgroundColor: AppColors.darkSurface.withValues(alpha: 0.65),
      side: BorderSide(color: AppColors.gold.withValues(alpha: 0.25)),
    );
  }
}

class _CaseStudyCard extends ConsumerWidget {
  const _CaseStudyCard({required this.study});

  final ServiceCaseStudy study;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(servicesCatalogProvider);
    final slug = study.serviceSlug.trim();
    final target = slug.isEmpty
        ? null
        : catalog.cast<ServiceSummary?>().firstWhere(
              (s) => s?.slug == slug,
              orElse: () => null,
            );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.28)),
        color: AppColors.darkSurface.withValues(alpha: 0.55),
      ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          Text(
            study.client,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            study.service,
            style: const TextStyle(
              color: AppColors.gold,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          _meta('Challenge', study.challenge),
          _meta('Solution', study.solution),
          _meta('Results', study.results, emphasize: true),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: target == null
                  ? null
                  : () => openServiceLearnMore(context, target),
              child: Text(
                target == null ? 'Service unavailable' : 'View service →',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _meta(String label, String value, {bool emphasize = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            color: AppColors.textSecondaryDark,
            height: 1.4,
            fontSize: 13,
            fontWeight: emphasize ? FontWeight.w600 : FontWeight.w400,
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
