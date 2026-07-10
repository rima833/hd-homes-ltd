import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/cta_banner.dart';
import 'package:hdhomesproject/core/website/components/page_container.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/estates/data/models/estate_detail_content.dart';
import 'package:hdhomesproject/features/estates/data/providers/estate_detail_provider.dart';
import 'package:hdhomesproject/features/estates/presentation/widgets/estate_summary_card.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Sections 14–19 + enterprise — Tours, lifestyle, FAQ, related, CTA, dashboards.
class EstateClosingSections extends ConsumerWidget {
  const EstateClosingSections({super.key, required this.detail});

  final EstateDetailContent detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final related = ref.watch(relatedEstatesProvider(detail.summary.slug));

    return Column(
      children: [
        SectionWrapper(
          backgroundColor: AppColors.charcoal,
          child: PageContainer(child: _LiveDashboard(dashboard: detail.liveDashboard)),
        ),
        SectionWrapper(
          child: PageContainer(
            child: Column(
              children: [
                const AnimatedSectionTitle(
                  overline: 'VIRTUAL TOUR',
                  title: 'Virtual estate tour',
                ),
                const SizedBox(height: AppSpacing.xl),
                Wrap(
                  spacing: AppSpacing.base,
                  runSpacing: AppSpacing.base,
                  children: [
                    if (detail.virtualTour.hasWalkthrough)
                      _TourTile(icon: LucideIcons.rotate3d, label: '360° Walkthrough'),
                    if (detail.virtualTour.hasDroneTour)
                      _TourTile(icon: LucideIcons.plane, label: 'Drone Tour'),
                    if (detail.virtualTour.hasInteractiveMap)
                      _TourTile(icon: LucideIcons.map, label: 'Interactive Map'),
                    if (detail.virtualTour.hasVideoNarration)
                      _TourTile(icon: LucideIcons.video, label: 'Video Narration'),
                  ],
                ),
              ],
            ),
          ),
        ),
        SectionWrapper(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: PageContainer(child: _Nearby(attractions: detail.nearbyAttractions)),
        ),
        SectionWrapper(
          child: PageContainer(child: _Lifestyle(lifestyle: detail.lifestyle)),
        ),
        SectionWrapper(
          backgroundColor: AppColors.charcoal,
          child: PageContainer(child: _CommunitySimulator(simulator: detail.communitySimulator)),
        ),
        SectionWrapper(
          child: PageContainer(
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                borderRadius: AppRadius.cardBorder,
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.trendingUp, color: AppColors.gold),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Estate Investment Intelligence',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.base),
                  Text(detail.investmentIntelligence.summary),
                  const SizedBox(height: AppSpacing.lg),
                  Wrap(
                    spacing: AppSpacing.xl,
                    runSpacing: AppSpacing.base,
                    children: [
                      _intel('Growth Index', '${detail.investmentIntelligence.growthIndex}/100'),
                      _intel('Risk Score', '${detail.investmentIntelligence.riskScore}/100'),
                      _intel('Appreciation', detail.investmentIntelligence.appreciationForecast),
                      _intel('Rental Demand', detail.investmentIntelligence.rentalDemand),
                      _intel('Market', detail.investmentIntelligence.marketTrends),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.base),
                  Text('Comparable: ${detail.investmentIntelligence.comparableEstates.join(', ')}'),
                ],
              ),
            ),
          ),
        ),
        SectionWrapper(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: PageContainer(
            child: Column(
              children: [
                const AnimatedSectionTitle(
                  overline: 'FAQ',
                  title: 'Frequently asked questions',
                ),
                const SizedBox(height: AppSpacing.lg),
                for (final faq in detail.faqs)
                  ExpansionTile(
                    title: Text(faq.question),
                    children: [
                      Align(alignment: Alignment.centerLeft, child: Text(faq.answer)),
                    ],
                  ),
              ],
            ),
          ),
        ),
        if (related.isNotEmpty)
          SectionWrapper(
            child: PageContainer(
              child: Column(
                children: [
                  const AnimatedSectionTitle(
                    overline: 'DISCOVER MORE',
                    title: 'Related estates',
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cols = context.gridColumns.clamp(1, 3);
                      final w = (constraints.maxWidth - (cols - 1) * AppSpacing.base) / cols;
                      return Wrap(
                        spacing: AppSpacing.base,
                        runSpacing: AppSpacing.base,
                        children: related
                            .map((e) => SizedBox(width: w, child: EstateSummaryCard(estate: e)))
                            .toList(),
                      );
                    },
                  ),
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
            title: 'Experience ${detail.summary.name}',
            subtitle: 'Book a guided estate tour, reserve a unit, or speak with our sales team.',
            primaryLabel: 'Book Estate Tour',
            primaryPath: RoutePaths.bookInspection,
            secondaryLabel: 'Reserve a Unit',
            secondaryPath: RoutePaths.contact,
          ),
        ),
        SectionWrapper(
          child: Wrap(
            spacing: AppSpacing.base,
            alignment: WrapAlignment.center,
            children: [
              PrimaryButton(
                label: 'Contact Sales',
                onPressed: () => context.go(RoutePaths.contact),
              ),
              PrimaryButton(
                label: 'Become an Investor',
                variant: ButtonVariant.secondary,
                onPressed: () => context.go(RoutePaths.investment),
              ),
              PrimaryButton(
                label: 'Schedule Consultation',
                variant: ButtonVariant.ghost,
                onPressed: () => context.go(RoutePaths.contact),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _intel(String label, String value) {
    return SizedBox(
      width: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.gold)),
        ],
      ),
    );
  }
}

class _TourTile extends StatelessWidget {
  const _TourTile({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardBorder,
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.gold, size: 32),
          const SizedBox(height: AppSpacing.sm),
          Text(label, style: const TextStyle(color: AppColors.white)),
        ],
      ),
    );
  }
}

class _LiveDashboard extends StatelessWidget {
  const _LiveDashboard({required this.dashboard});

  final EstateLiveDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AnimatedSectionTitle(
          overline: 'LIVE DASHBOARD',
          title: 'Estate availability & progress',
          subtitle: 'Realtime updates via Supabase (placeholder).',
          alignment: TextAlign.start,
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.xl,
          runSpacing: AppSpacing.base,
          children: [
            _stat('Available', dashboard.availableUnits, AppColors.success),
            _stat('Reserved', dashboard.reservedUnits, AppColors.warning),
            _stat('Sold', dashboard.soldUnits),
            _stat('Progress', (dashboard.constructionProgress * 100).round(), null, '%'),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Next milestone: ${dashboard.nextMilestone}'),
        Text('Site inspections: ${dashboard.nextInspectionDate}'),
        Text('Weather: ${dashboard.weatherConditions}'),
        Text('Estimated completion: ${dashboard.estimatedCompletion}'),
      ],
    );
  }

  Widget _stat(String label, int value, [Color? color, String suffix = '']) {
    return Column(
      children: [
        Text(
          '$value$suffix',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: color ?? AppColors.gold,
          ),
        ),
        Text(label, style: const TextStyle(color: AppColors.textSecondaryDark)),
      ],
    );
  }
}

class _Nearby extends StatelessWidget {
  const _Nearby({required this.attractions});

  final List<EstateNearbyAttraction> attractions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AnimatedSectionTitle(
          overline: 'NEARBY',
          title: 'Nearby attractions',
          alignment: TextAlign.start,
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final a in attractions)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: AppColors.gold.withValues(alpha: 0.15),
              child: Text(a.category[0]),
            ),
            title: Text(a.name),
            subtitle: Text(a.category),
            trailing: Text('${a.distance} · ${a.travelTime}'),
          ),
      ],
    );
  }
}

class _Lifestyle extends StatelessWidget {
  const _Lifestyle({required this.lifestyle});

  final EstateLifestyle lifestyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSectionTitle(
          overline: 'LIFESTYLE',
          title: lifestyle.headline,
          alignment: TextAlign.start,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(lifestyle.story, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: AppSpacing.lg),
        Text('Community features', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        for (final f in lifestyle.features)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              children: [
                const Icon(Icons.check_rounded, color: AppColors.gold, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(f)),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        Text('Sustainability', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        for (final s in lifestyle.sustainability)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              children: [
                const Icon(Icons.eco_rounded, color: AppColors.gold, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(s)),
              ],
            ),
          ),
      ],
    );
  }
}

class _CommunitySimulator extends StatelessWidget {
  const _CommunitySimulator({required this.simulator});

  final EstateCommunitySimulator simulator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AnimatedSectionTitle(
          overline: 'COMMUNITY SIMULATOR',
          title: 'Experience daily life',
          subtitle: 'Explore walking routes, parks, schools, and community events.',
          alignment: TextAlign.start,
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.xl,
          runSpacing: AppSpacing.xl,
          children: [
            _zone('Walking Routes', simulator.walkingRoutes),
            _zone('Parks', simulator.parks),
            _zone('Schools', simulator.schools),
            _zone('Fitness', simulator.fitnessAreas),
            _zone('Retail', simulator.retailZones),
            _zone('Events', simulator.events),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Security: ${simulator.securityCoverage}'),
        Text('Green spaces: ${simulator.greenSpaces}'),
      ],
    );
  }

  Widget _zone(String title, List<String> items) {
    return SizedBox(
      width: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.gold)),
          ...items.map((i) => Text('· $i', style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
