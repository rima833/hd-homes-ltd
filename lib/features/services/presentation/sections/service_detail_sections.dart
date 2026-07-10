import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
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
import 'package:hdhomesproject/features/services/presentation/widgets/consultation_form.dart';
import 'package:hdhomesproject/features/services/presentation/widgets/service_card.dart';
import 'package:hdhomesproject/features/services/presentation/widgets/service_icons.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Service detail landing page sections.
class ServiceDetailSections extends HookConsumerWidget {
  const ServiceDetailSections({super.key, required this.detail});

  final ServiceDetailContent detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = detail.summary;
    final related = ref.watch(relatedServicesProvider(s.slug));
    final aiRecs = ref.watch(aiServiceRecommendationsProvider(s.slug));
    final galleryIndex = useState(0);
    final eligibilityAnswers = useState<Map<int, String>>({});
    final eligibilityResult = useState<EligibilityResult?>(null);

    return Column(
      children: [
        _ServiceHero(summary: s),
        PageContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.lg),
              AnimatedSectionTitle(
                overline: 'OVERVIEW',
                title: s.name,
                alignment: TextAlign.start,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(detail.overview, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: AppSpacing.base),
              ExpansionTile(title: const Text('Who is this for?'), children: [Text(detail.audience)]),
              ExpansionTile(title: const Text('Business value'), children: [Text(detail.businessValue)]),
            ],
          ),
        ),
        SectionWrapper(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: PageContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AnimatedSectionTitle(
                  overline: 'BENEFITS',
                  title: 'Key benefits',
                  alignment: TextAlign.start,
                ),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.base,
                  runSpacing: AppSpacing.base,
                  children: detail.benefits
                      .map(
                        (b) => Chip(
                          avatar: const Icon(Icons.check_rounded, color: AppColors.gold, size: 16),
                          label: Text(b),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AnimatedSectionTitle(
                  overline: 'PROCESS',
                  title: 'How we deliver',
                  alignment: TextAlign.start,
                ),
                const SizedBox(height: AppSpacing.lg),
                for (var i = 0; i < detail.processSteps.length; i++)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.gold,
                      child: Text('${i + 1}', style: const TextStyle(color: AppColors.deepBlack)),
                    ),
                    title: Text(detail.processSteps[i].title),
                    subtitle: Text(detail.processSteps[i].description),
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
                  overline: 'DELIVERABLES',
                  title: 'What you receive',
                  alignment: TextAlign.start,
                ),
                const SizedBox(height: AppSpacing.lg),
                for (final d in detail.deliverables)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.package, color: AppColors.gold, size: 18),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: Text(d, style: const TextStyle(color: AppColors.white))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (detail.pricing != null)
          SectionWrapper(
            child: PageContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AnimatedSectionTitle(
                    overline: 'PRICING',
                    title: 'Investment',
                    alignment: TextAlign.start,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    '${detail.pricing!.label}: ${detail.pricing!.startingPrice}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppColors.gold),
                  ),
                  Text('${detail.pricing!.pricingType} · ${detail.pricing!.note}'),
                  const SizedBox(height: AppSpacing.base),
                  PrimaryButton(
                    label: 'Request Custom Quote',
                    onPressed: () => context.go(RoutePaths.contact),
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
                const AnimatedSectionTitle(overline: 'GALLERY', title: 'Project gallery'),
                const SizedBox(height: AppSpacing.xl),
                CarouselSlider.builder(
                  itemCount: detail.gallery.images.length,
                  options: CarouselOptions(
                    height: context.isMobile ? 240 : 360,
                    viewportFraction: 1,
                    onPageChanged: (i, _) => galleryIndex.value = i,
                  ),
                  itemBuilder: (_, index, __) => Container(
                    decoration: BoxDecoration(
                      borderRadius: AppRadius.cardBorder,
                      gradient: LinearGradient(
                        colors: [AppColors.charcoal, AppColors.gold.withValues(alpha: 0.12)],
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        index.isEven ? LucideIcons.image : LucideIcons.video,
                        color: AppColors.gold,
                        size: 40,
                      ),
                    ),
                  ),
                ),
                Text('${galleryIndex.value + 1} / ${detail.gallery.images.length}'),
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
                  overline: 'PROJECTS',
                  title: 'Related projects',
                  alignment: TextAlign.start,
                ),
                const SizedBox(height: AppSpacing.lg),
                for (final p in detail.relatedProjects)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(LucideIcons.building2, color: AppColors.gold),
                    title: Text(p.name),
                    subtitle: Text('${p.location} · ${p.outcome}'),
                  ),
              ],
            ),
          ),
        ),
        if (aiRecs.isNotEmpty)
          SectionWrapper(
            backgroundColor: AppColors.charcoal,
            child: PageContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AnimatedSectionTitle(
                    overline: 'AI RECOMMENDATIONS',
                    title: 'You may also need',
                    subtitle: 'Suggested services based on your interests.',
                    alignment: TextAlign.start,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Wrap(
                    spacing: AppSpacing.base,
                    children: aiRecs
                        .map((r) => ActionChip(
                              label: Text(r.name),
                              onPressed: () => context.go('/services/${r.slug}'),
                            ))
                        .toList(),
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
                  overline: 'ELIGIBILITY',
                  title: 'Project eligibility checker',
                  alignment: TextAlign.start,
                ),
                const SizedBox(height: AppSpacing.lg),
                for (var i = 0; i < detail.eligibilityQuestions.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.base),
                    child: DropdownMenu<String>(
                      label: Text(detail.eligibilityQuestions[i].question),
                      dropdownMenuEntries: detail.eligibilityQuestions[i].options
                          .map((o) => DropdownMenuEntry(value: o, label: o))
                          .toList(),
                      onSelected: (v) {
                        if (v == null) return;
                        eligibilityAnswers.value = {...eligibilityAnswers.value, i: v};
                      },
                    ),
                  ),
                PrimaryButton(
                  label: 'Check Eligibility',
                  onPressed: () {
                    final slugs = <String>{};
                    for (var i = 0; i < detail.eligibilityQuestions.length; i++) {
                      final answer = eligibilityAnswers.value[i];
                      if (answer != null) {
                        slugs.addAll(
                          detail.eligibilityQuestions[i].recommendedServiceSlugs[answer] ?? [],
                        );
                      }
                    }
                    eligibilityResult.value = EligibilityResult(
                      suitableServices: slugs.isEmpty ? [s.name] : slugs.toList(),
                      readiness: slugs.length >= 2 ? 'High' : 'Moderate — consultation recommended',
                      documentsRequired: const ['Valid ID', 'Proof of funds', 'Site survey (if applicable)'],
                      budgetFit: 'Assessed during consultation',
                      nextSteps: const [
                        'Book a consultation',
                        'Prepare required documents',
                        'Receive digital proposal',
                      ],
                    );
                  },
                ),
                if (eligibilityResult.value != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text('Suitable services: ${eligibilityResult.value!.suitableServices.join(', ')}'),
                  Text('Readiness: ${eligibilityResult.value!.readiness}'),
                  Text('Next steps: ${eligibilityResult.value!.nextSteps.join(' · ')}'),
                ],
              ],
            ),
          ),
        ),
        SectionWrapper(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: PageContainer(
            child: Column(
              children: [
                const AnimatedSectionTitle(overline: 'FAQ', title: 'Service FAQs'),
                const SizedBox(height: AppSpacing.lg),
                for (final faq in detail.faqs)
                  ExpansionTile(title: Text(faq.question), children: [Text(faq.answer)]),
              ],
            ),
          ),
        ),
        if (related.isNotEmpty)
          SectionWrapper(
            child: PageContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AnimatedSectionTitle(
                    overline: 'RELATED',
                    title: 'Related services',
                    alignment: TextAlign.start,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Wrap(
                    spacing: AppSpacing.base,
                    runSpacing: AppSpacing.base,
                    children: related.map((r) => SizedBox(width: 300, child: ServiceCard(service: r))).toList(),
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
                  overline: 'GET STARTED',
                  title: 'Request consultation',
                  alignment: TextAlign.start,
                ),
                const SizedBox(height: AppSpacing.xl),
                ConsultationForm(preselectedService: s.name),
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
            title: 'Start with ${s.name}',
            subtitle: 'Book a consultation or request a tailored proposal today.',
            primaryLabel: 'Book Consultation',
            primaryPath: RoutePaths.contact,
            secondaryLabel: 'Contact Expert',
            secondaryPath: RoutePaths.contact,
          ),
        ),
      ],
    );
  }
}

class _ServiceHero extends StatelessWidget {
  const _ServiceHero({required this.summary});

  final ServiceSummary summary;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: context.isMobile ? 360 : 420,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.charcoal, AppColors.gold.withValues(alpha: 0.2)],
              ),
            ),
            child: Center(
              child: Icon(ServiceIcons.resolve(summary.iconName), size: 64, color: AppColors.gold.withValues(alpha: 0.5)),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, AppColors.deepBlack.withValues(alpha: 0.9)],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.pagePadding, vertical: AppSpacing.xxl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary.name,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(summary.shortDescription, style: const TextStyle(color: AppColors.textSecondaryDark)),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    PrimaryButton(
                      label: 'Book Consultation',
                      onPressed: () => context.go(RoutePaths.contact),
                    ),
                    PrimaryButton(
                      label: 'Request Proposal',
                      variant: ButtonVariant.secondary,
                      onPressed: () => context.go(RoutePaths.contact),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
