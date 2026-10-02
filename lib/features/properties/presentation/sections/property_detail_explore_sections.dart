import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/features/properties/data/models/property_detail_content.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> _openAssetUrl(String? raw) async {
  final value = raw?.trim() ?? '';
  if (value.isEmpty || value == '#') return;
  final uri = Uri.tryParse(value);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Sections 9–16 — Tours, floor plans, map, amenities, construction, documents, nearby.
class PropertyDetailExploreSections extends StatelessWidget {
  const PropertyDetailExploreSections({super.key, required this.detail});

  final PropertyDetailContent detail;

  @override
  Widget build(BuildContext context) {
    final p = detail.listing;
    final hasTour =
        (detail.media.tour360Url?.trim().isNotEmpty ?? false) ||
        (detail.media.videoTourUrl?.trim().isNotEmpty ?? false) ||
        (detail.media.droneTourUrl?.trim().isNotEmpty ?? false);

    return Column(
      children: [
        if (hasTour)
        SectionWrapper(
          backgroundColor: AppColors.deepBlack,
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'VIRTUAL TOUR',
                title: 'Explore in 360°',
              ),
              const SizedBox(height: AppSpacing.xl),
              Wrap(
                spacing: AppSpacing.base,
                runSpacing: AppSpacing.base,
                alignment: WrapAlignment.center,
                children: [
                  if ((detail.media.tour360Url ?? '').trim().isNotEmpty)
                    _TourTile(
                      icon: LucideIcons.rotate3d,
                      label: '360° Walkthrough',
                      url: detail.media.tour360Url,
                    ),
                  if ((detail.media.videoTourUrl ?? '').trim().isNotEmpty)
                    _TourTile(
                      icon: LucideIcons.video,
                      label: 'Video Tour',
                      url: detail.media.videoTourUrl,
                    ),
                  if ((detail.media.droneTourUrl ?? '').trim().isNotEmpty)
                    _TourTile(
                      icon: LucideIcons.plane,
                      label: 'Drone Tour',
                      url: detail.media.droneTourUrl,
                    ),
                ],
              ),
            ],
          ),
        ),
        if (detail.floorPlans.isNotEmpty)
        SectionWrapper(
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
                _AssetRow(
                  icon: LucideIcons.layout,
                  title: plan.label,
                  subtitle: plan.dimensions,
                  actionLabel: 'Download',
                  onTap: () => _openAssetUrl(plan.downloadUrl),
                  enabled: plan.downloadUrl.trim().isNotEmpty &&
                      plan.downloadUrl != '#',
                ),
            ],
          ),
        ),
        if (detail.masterPlan.description.trim().isNotEmpty ||
            detail.masterPlan.legend.isNotEmpty)
        SectionWrapper(
          backgroundColor: AppColors.charcoal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AnimatedSectionTitle(
                overline: 'MASTER PLAN',
                title: 'Estate master plan',
                alignment: TextAlign.start,
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  borderRadius: AppRadius.cardBorder,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.darkSurface,
                      AppColors.gold.withValues(alpha: 0.12),
                    ],
                  ),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.28),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      detail.masterPlan.description,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.white,
                            height: 1.55,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.base),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: detail.masterPlan.legend
                          .map(
                            (l) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: AppColors.white.withValues(alpha: 0.06),
                                border: Border.all(
                                  color: AppColors.gold.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Text(
                                l,
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (p.location.trim().isNotEmpty && p.location.trim() != '—')
        SectionWrapper(
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'LOCATION',
                title: 'Location',
              ),
              const SizedBox(height: AppSpacing.xl),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  borderRadius: AppRadius.cardBorder,
                  color: AppColors.darkSurface,
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.gold.withValues(alpha: 0.15),
                        border: Border.all(color: AppColors.gold),
                      ),
                      child: const Icon(
                        LucideIcons.mapPin,
                        color: AppColors.gold,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.base),
                    Expanded(
                      child: Text(
                        p.location,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (p.amenities.isNotEmpty)
        SectionWrapper(
          backgroundColor: AppColors.deepBlack,
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
        if (detail.documents.isNotEmpty)
          SectionWrapper(
            backgroundColor: AppColors.charcoal,
            child: _Documents(documents: detail.documents),
          ),
        if (detail.nearbyPlaces.isNotEmpty)
          SectionWrapper(
            child: _Nearby(places: detail.nearbyPlaces),
          ),
      ],
    );
  }
}

class _TourTile extends StatelessWidget {
  const _TourTile({
    required this.icon,
    required this.label,
    this.url,
  });

  final IconData icon;
  final String label;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final hasUrl = url != null && url!.trim().isNotEmpty;
    if (!hasUrl) return const SizedBox.shrink();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: hasUrl ? () => _openAssetUrl(url) : null,
        borderRadius: AppRadius.cardBorder,
        child: Ink(
          width: 170,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardBorder,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.darkElevated,
                hasUrl
                    ? AppColors.gold.withValues(alpha: 0.18)
                    : AppColors.darkSurface,
              ],
            ),
            border: Border.all(
              color: AppColors.gold.withValues(alpha: hasUrl ? 0.55 : 0.2),
            ),
            boxShadow: hasUrl
                ? [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Icon(icon, color: AppColors.gold, size: 32),
              const SizedBox(height: AppSpacing.sm),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Open tour',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.goldLight,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssetRow extends StatelessWidget {
  const _AssetRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onTap,
    required this.enabled,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
      ),
      child: ListTile(
        onTap: enabled ? onTap : null,
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: AppColors.gold.withValues(alpha: 0.12),
          ),
          child: Icon(icon, color: AppColors.gold, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: Icon(
          enabled ? LucideIcons.download : LucideIcons.lock,
          color: enabled ? AppColors.gold : AppColors.neutral400,
          size: 18,
        ),
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
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.gold,
            size: 18,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(color: AppColors.white),
            ),
          ),
        ],
      ),
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
          _AssetRow(
            icon: LucideIcons.fileText,
            title: doc.title,
            subtitle: doc.type,
            actionLabel: 'Download',
            onTap: () => _openAssetUrl(doc.url),
            enabled: doc.url.trim().isNotEmpty && doc.url != '#',
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
        Wrap(
          spacing: AppSpacing.base,
          runSpacing: AppSpacing.base,
          children: places
              .map(
                (place) => SizedBox(
                  width: context.isMobile ? double.infinity : 280,
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.base),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.2),
                      ),
                      color: Theme.of(context).colorScheme.surface,
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor:
                              AppColors.gold.withValues(alpha: 0.15),
                          child: Text(
                            place.category.isNotEmpty
                                ? place.category[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: AppColors.gold,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                place.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${place.distance} · ${place.travelTime}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
