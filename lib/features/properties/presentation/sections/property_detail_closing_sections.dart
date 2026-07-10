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
import 'package:hdhomesproject/features/properties/data/models/property_detail_content.dart';
import 'package:hdhomesproject/features/properties/data/providers/property_detail_provider.dart';
import 'package:hdhomesproject/features/properties/presentation/widgets/marketplace_property_card.dart';
import 'package:hdhomesproject/features/properties/data/providers/marketplace_controller.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Sections 17–20 + enterprise — Reviews, FAQ, related, CTA, availability, AI.
class PropertyDetailClosingSections extends ConsumerWidget {
  const PropertyDetailClosingSections({super.key, required this.detail});

  final PropertyDetailContent detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final related = ref.watch(relatedPropertiesProvider(detail.listing.id));
    final favorites = ref.watch(marketplaceFavoritesProvider);
    final compare = ref.watch(marketplaceCompareProvider);

    return Column(
      children: [
        SectionWrapper(
          backgroundColor: AppColors.charcoal,
          child: PageContainer(child: _Availability(dashboard: detail.availability)),
        ),
        SectionWrapper(
          child: PageContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AnimatedSectionTitle(
                  overline: 'INSPECTION',
                  title: 'Book an inspection slot',
                  alignment: TextAlign.start,
                ),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: detail.inspectionSlots
                      .where((s) => s.available)
                      .map(
                        (s) => ActionChip(
                          label: Text('${s.date} · ${s.time}'),
                          onPressed: () => context.go(RoutePaths.bookInspection),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ),
        SectionWrapper(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: PageContainer(child: _Neighborhood(intel: detail.neighborhood)),
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
                      const Icon(LucideIcons.sparkles, color: AppColors.gold),
                      const SizedBox(width: AppSpacing.sm),
                      Text('AI Decision Assistant', style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.base),
                  Text(detail.aiInsight.matchSummary),
                  const SizedBox(height: AppSpacing.sm),
                  for (final action in detail.aiInsight.suggestedActions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Row(
                        children: [
                          const Icon(Icons.arrow_right_rounded, color: AppColors.gold, size: 18),
                          Expanded(child: Text(action)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        SectionWrapper(
          backgroundColor: AppColors.charcoal,
          child: PageContainer(child: _Reviews(reviews: detail.reviews)),
        ),
        SectionWrapper(
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
                    children: [Align(alignment: Alignment.centerLeft, child: Text(faq.answer))],
                  ),
              ],
            ),
          ),
        ),
        if (related.isNotEmpty)
          SectionWrapper(
            backgroundColor: Theme.of(context).colorScheme.surface,
            child: PageContainer(
              child: Column(
                children: [
                  const AnimatedSectionTitle(
                    overline: 'SIMILAR',
                    title: 'Related properties',
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SizedBox(
                    height: 480,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: related.length,
                      separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.base),
                      itemBuilder: (context, index) {
                        final p = related[index];
                        return SizedBox(
                          width: context.isMobile ? 300 : 340,
                          child: MarketplacePropertyCard(
                            property: p,
                            isFavorite: favorites.contains(p.id),
                            isCompared: compare.contains(p.id),
                            onTap: () => context.go('/properties/${p.id}'),
                            onFavorite: () {},
                            showMatchScore: false,
                          ),
                        );
                      },
                    ),
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
            title: 'Ready to take the next step?',
            subtitle: 'Book an inspection, reserve this property, or speak with our team.',
            primaryLabel: 'Book Inspection',
            primaryPath: RoutePaths.bookInspection,
            secondaryLabel: 'Reserve Property',
            secondaryPath: RoutePaths.contact,
          ),
        ),
        SectionWrapper(
          child: Wrap(
            spacing: AppSpacing.base,
            alignment: WrapAlignment.center,
            children: [
              PrimaryButton(
                label: 'Request Callback',
                onPressed: () => context.go(RoutePaths.contact),
              ),
              PrimaryButton(
                label: 'Become an Investor',
                variant: ButtonVariant.secondary,
                onPressed: () => context.go(RoutePaths.investment),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Availability extends StatelessWidget {
  const _Availability({required this.dashboard});

  final PropertyAvailabilityDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AnimatedSectionTitle(
          overline: 'LIVE AVAILABILITY',
          title: 'Unit availability dashboard',
          subtitle: 'Realtime updates via Supabase (placeholder).',
          alignment: TextAlign.start,
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.xl,
          children: [
            _stat('Total', dashboard.totalUnits),
            _stat('Available', dashboard.availableUnits, AppColors.success),
            _stat('Reserved', dashboard.reservedUnits, AppColors.warning),
            _stat('Sold', dashboard.soldUnits, AppColors.neutral500),
          ],
        ),
      ],
    );
  }

  Widget _stat(String label, int value, [Color? color]) {
    return Column(
      children: [
        Text(
          '$value',
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

class _Neighborhood extends StatelessWidget {
  const _Neighborhood({required this.intel});

  final NeighborhoodIntelligence intel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AnimatedSectionTitle(
          overline: 'NEIGHBORHOOD',
          title: 'Neighborhood intelligence',
          alignment: TextAlign.start,
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.xl,
          runSpacing: AppSpacing.base,
          children: [
            _n('Safety', '${intel.safetyScore}/100'),
            _n('Walkability', '${intel.walkabilityScore}/100'),
            _n('Lifestyle', '${intel.lifestyleScore}/100'),
            _n('Appreciation', intel.appreciationEstimate),
            _n('Traffic', intel.trafficConditions),
            _n('Infrastructure', intel.plannedInfrastructure),
          ],
        ),
      ],
    );
  }

  Widget _n(String label, String value) {
    return SizedBox(
      width: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Reviews extends StatelessWidget {
  const _Reviews({required this.reviews});

  final List<PropertyReview> reviews;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AnimatedSectionTitle(
          overline: 'REVIEWS',
          title: 'Customer reviews',
          alignment: TextAlign.start,
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final r in reviews)
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
                        i < r.rating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: AppColors.gold,
                        size: 16,
                      ),
                    ),
                    if (r.verified) ...[
                      const Spacer(),
                      const Text('Verified', style: TextStyle(fontSize: 11, color: AppColors.gold)),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text('"${r.comment}"', style: const TextStyle(color: AppColors.white)),
                Text('${r.name} · ${r.role}', style: const TextStyle(color: AppColors.gold)),
              ],
            ),
          ),
      ],
    );
  }
}
