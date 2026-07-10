import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/cta_banner.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/about/data/models/about_cms_content.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

/// Enterprise enhancements + sections 18–19.
class AboutEnterpriseSection extends StatelessWidget {
  const AboutEnterpriseSection({
    super.key,
    required this.executiveVideo,
    required this.milestoneMap,
    required this.companyProfile,
    required this.trustCenter,
    required this.testimonials,
    required this.cta,
  });

  final AboutExecutiveVideo executiveVideo;
  final List<AboutMilestoneMarker> milestoneMap;
  final AboutCompanyProfile companyProfile;
  final List<AboutTrustItem> trustCenter;
  final List<AboutTestimonialItem> testimonials;
  final AboutCtaContent cta;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SectionWrapper(
          backgroundColor: AppColors.charcoal,
          child: context.isMobile
              ? Column(children: _executiveContent(context))
              : Row(
                  children: [
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _executiveContent(context),
                    )),
                    const SizedBox(width: AppSpacing.xl),
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.darkSurface,
                            borderRadius: AppRadius.cardBorder,
                            border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                          ),
                          child: const Center(
                            child: Icon(LucideIcons.playCircle, size: 64, color: AppColors.gold),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
        SectionWrapper(
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'EXPANSION MAP',
                title: 'Interactive milestone map',
                subtitle: 'HD Homes presence across Nigeria — GIS integration ready.',
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
                child: Stack(
                  children: [
                    for (final marker in milestoneMap)
                      Align(
                        alignment: _alignmentFor(marker),
                        child: _MapMarker(marker: marker),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SectionWrapper(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'COMPANY PROFILE',
                title: 'Digital company profile',
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(companyProfile.description, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.base,
                alignment: WrapAlignment.center,
                children: [
                  PrimaryButton(
                    label: 'View Profile',
                    icon: LucideIcons.eye,
                    onPressed: () => launchUrl(Uri.parse(companyProfile.viewUrl)),
                  ),
                  PrimaryButton(
                    label: 'Download PDF',
                    variant: ButtonVariant.secondary,
                    icon: LucideIcons.download,
                    onPressed: () => launchUrl(Uri.parse(companyProfile.downloadUrl)),
                  ),
                ],
              ),
            ],
          ),
        ),
        SectionWrapper(
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'TRUST & COMPLIANCE',
                title: 'Trust & compliance center',
                subtitle: 'Verified credentials for your peace of mind.',
              ),
              const SizedBox(height: AppSpacing.xl),
              Wrap(
                spacing: AppSpacing.base,
                runSpacing: AppSpacing.base,
                children: trustCenter
                    .map(
                      (t) => SizedBox(
                        width: context.isMobile ? double.infinity : 280,
                        child: _TrustCard(item: t),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        SectionWrapper(
          backgroundColor: AppColors.charcoal,
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'TESTIMONIALS',
                title: 'What our clients say',
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                height: 220,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: testimonials.length,
                  separatorBuilder: (_, index) => const SizedBox(width: AppSpacing.base),
                  itemBuilder: (context, index) {
                    final t = testimonials[index];
                    return SizedBox(
                      width: 340,
                      child: _TestimonialCard(item: t),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.pagePadding,
            vertical: AppSpacing.section,
          ),
          child: CtaBanner(
            title: cta.title,
            subtitle: cta.subtitle,
            primaryLabel: cta.actions.firstWhere((a) => a.isPrimary).label,
            primaryPath: cta.actions.firstWhere((a) => a.isPrimary).path,
            secondaryLabel: cta.actions.length > 1 ? cta.actions[1].label : null,
            secondaryPath: cta.actions.length > 1 ? cta.actions[1].path : null,
          ),
        ),
        SectionWrapper(
          child: Wrap(
            spacing: AppSpacing.base,
            runSpacing: AppSpacing.base,
            alignment: WrapAlignment.center,
            children: cta.actions
                .where((a) => !a.isPrimary)
                .map(
                  (a) => PrimaryButton(
                    label: a.label,
                    variant: ButtonVariant.ghost,
                    onPressed: () => context.go(a.path),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  List<Widget> _executiveContent(BuildContext context) => [
        const AnimatedSectionTitle(
          overline: 'FROM THE MD',
          title: 'Executive video message',
          alignment: TextAlign.start,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          executiveVideo.message,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.white),
        ),
        const SizedBox(height: AppSpacing.base),
        Text(
          '${executiveVideo.speakerName} · ${executiveVideo.speakerTitle}',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.gold),
        ),
        if (context.isMobile) ...[
          const SizedBox(height: AppSpacing.lg),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.darkSurface,
                borderRadius: AppRadius.cardBorder,
              ),
              child: const Center(
                child: Icon(LucideIcons.playCircle, size: 48, color: AppColors.gold),
              ),
            ),
          ),
        ],
      ];

  Alignment _alignmentFor(AboutMilestoneMarker marker) {
    return switch (marker.city) {
      'Lagos' => const Alignment(-0.6, 0.5),
      'Abuja' => const Alignment(0.1, -0.2),
      'Port Harcourt' => const Alignment(0.5, 0.6),
      _ => const Alignment(0.3, 0.0),
    };
  }
}

class _MapMarker extends StatelessWidget {
  const _MapMarker({required this.marker});

  final AboutMilestoneMarker marker;

  @override
  Widget build(BuildContext context) {
    final color = switch (marker.type) {
      'completed' => AppColors.success,
      'ongoing' => AppColors.gold,
      _ => AppColors.info,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.location_on_rounded, color: color, size: 28),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.deepBlack.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(AppRadius.badge),
          ),
          child: Text(
            marker.label,
            style: const TextStyle(color: AppColors.white, fontSize: 11),
          ),
        ),
      ],
    );
  }
}

class _TrustCard extends StatelessWidget {
  const _TrustCard({required this.item});

  final AboutTrustItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.shieldCheck, color: AppColors.gold, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(item.title, style: Theme.of(context).textTheme.titleSmall)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(item.detail, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            item.reference,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.gold),
          ),
        ],
      ),
    );
  }
}

class _TestimonialCard extends StatelessWidget {
  const _TestimonialCard({required this.item});

  final AboutTestimonialItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
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
                  i < item.rating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: AppColors.gold,
                  size: 16,
                ),
              ),
              const Spacer(),
              if (item.verified)
                const Text('Verified', style: TextStyle(fontSize: 11, color: AppColors.gold)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(child: Text('"${item.quote}"', style: const TextStyle(color: AppColors.white))),
          Text(item.name, style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w600)),
          Text(item.role, style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 12)),
        ],
      ),
    );
  }
}
