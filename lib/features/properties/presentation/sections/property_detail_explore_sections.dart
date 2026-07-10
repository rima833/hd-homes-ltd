import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/page_container.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/features/properties/data/models/marketplace_property.dart';
import 'package:hdhomesproject/features/properties/data/models/property_detail_content.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Sections 9–16 — Tours, floor plans, map, amenities, construction, documents, nearby.
class PropertyDetailExploreSections extends StatelessWidget {
  const PropertyDetailExploreSections({super.key, required this.detail});

  final PropertyDetailContent detail;

  @override
  Widget build(BuildContext context) {
    final p = detail.listing;

    return Column(
      children: [
        SectionWrapper(
          backgroundColor: AppColors.charcoal,
          child: PageContainer(
            child: Column(
              children: [
                const AnimatedSectionTitle(
                  overline: 'VIRTUAL TOUR',
                  title: 'Explore in 360°',
                ),
                const SizedBox(height: AppSpacing.xl),
                Wrap(
                  spacing: AppSpacing.base,
                  children: [
                    _TourTile(icon: LucideIcons.rotate3d, label: '360° Walkthrough'),
                    _TourTile(icon: LucideIcons.video, label: 'Video Tour'),
                    _TourTile(icon: LucideIcons.plane, label: 'Drone Tour'),
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
                  overline: 'FLOOR PLANS',
                  title: 'Interactive floor plans',
                  alignment: TextAlign.start,
                ),
                const SizedBox(height: AppSpacing.lg),
                for (final plan in detail.floorPlans)
                  ListTile(
                    leading: const Icon(LucideIcons.layout, color: AppColors.gold),
                    title: Text(plan.label),
                    subtitle: Text(plan.dimensions),
                    trailing: const Icon(Icons.download_rounded),
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
                  overline: 'MASTER PLAN',
                  title: 'Estate master plan',
                  alignment: TextAlign.start,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(detail.masterPlan.description),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: detail.masterPlan.legend
                      .map((l) => Chip(label: Text(l)))
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
                  overline: 'LOCATION',
                  title: 'Location & map',
                ),
                const SizedBox(height: AppSpacing.xl),
                Container(
                  height: context.isMobile ? 280 : 360,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.cardBorder,
                    gradient: LinearGradient(
                      colors: [AppColors.charcoal, AppColors.gold.withValues(alpha: 0.15)],
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.mapPin, color: AppColors.gold, size: 40),
                        const SizedBox(height: AppSpacing.sm),
                        Text(p.location, style: const TextStyle(color: AppColors.white)),
                        Text('Google Maps integration ready',
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
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
                  overline: 'AMENITIES',
                  title: 'Premium amenities',
                  alignment: TextAlign.start,
                ),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.base,
                  runSpacing: AppSpacing.base,
                  children: p.amenities
                      .map(
                        (a) => SizedBox(
                          width: context.isMobile ? double.infinity : 220,
                          child: _AmenityCard(name: a),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ),
        if (p.completionStatus != CompletionStatus.readyToMove)
          SectionWrapper(
            child: PageContainer(child: _Construction(detail: detail.construction)),
          ),
        SectionWrapper(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: PageContainer(child: _Documents(documents: detail.documents)),
        ),
        SectionWrapper(
          child: PageContainer(child: _Nearby(places: detail.nearbyPlaces)),
        ),
      ],
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

class _AmenityCard extends StatelessWidget {
  const _AmenityCard({required this.name});

  final String name;

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
          const Icon(Icons.check_circle_rounded, color: AppColors.gold, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(name, style: const TextStyle(color: AppColors.white))),
        ],
      ),
    );
  }
}

class _Construction extends StatelessWidget {
  const _Construction({required this.detail});

  final PropertyConstructionDetail detail;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AnimatedSectionTitle(
          overline: 'CONSTRUCTION',
          title: 'Construction progress',
          alignment: TextAlign.start,
        ),
        const SizedBox(height: AppSpacing.lg),
        LinearProgressIndicator(
          value: detail.progress,
          minHeight: 8,
          color: AppColors.gold,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text('${(detail.progress * 100).round()}% complete · ${detail.completionForecast}'),
        const SizedBox(height: AppSpacing.base),
        Text(detail.weeklyUpdate),
      ],
    );
  }
}

class _Documents extends StatelessWidget {
  const _Documents({required this.documents});

  final List<PropertyDocument> documents;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AnimatedSectionTitle(
          overline: 'DOCUMENT VAULT',
          title: 'Smart document vault',
          subtitle: 'Secure previews and downloads — tracked for analytics.',
          alignment: TextAlign.start,
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final doc in documents)
          ListTile(
            leading: const Icon(LucideIcons.fileText, color: AppColors.gold),
            title: Text(doc.title),
            subtitle: Text(doc.type),
            trailing: const Icon(Icons.download_rounded),
          ),
      ],
    );
  }
}

class _Nearby extends StatelessWidget {
  const _Nearby({required this.places});

  final List<NearbyPlace> places;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AnimatedSectionTitle(
          overline: 'NEARBY',
          title: 'Nearby places',
          alignment: TextAlign.start,
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final place in places)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: AppColors.gold.withValues(alpha: 0.15),
              child: Text(place.category[0]),
            ),
            title: Text(place.name),
            subtitle: Text('${place.distance} · ${place.travelTime}'),
          ),
      ],
    );
  }
}
