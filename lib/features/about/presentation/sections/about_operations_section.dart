import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/about/data/models/about_cms_content.dart';
import 'package:hdhomesproject/features/home/presentation/widgets/animated_statistic.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

/// Sections 15–17 — Statistics, offices, careers preview.
class AboutOperationsSection extends StatelessWidget {
  const AboutOperationsSection({
    super.key,
    required this.stats,
    required this.offices,
    required this.careers,
  });

  final List<AboutStatItem> stats;
  final List<AboutOfficeLocation> offices;
  final AboutCareersPreview careers;

  @override
  Widget build(BuildContext context) {
    final columns = context.isMobile ? 2 : 3;

    return Column(
      children: [
        SectionWrapper(
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'BY THE NUMBERS',
                title: 'Company statistics',
              ),
              const SizedBox(height: AppSpacing.xxl),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width =
                      (constraints.maxWidth - (columns - 1) * AppSpacing.lg) /
                          columns;
                  return Wrap(
                    spacing: AppSpacing.lg,
                    runSpacing: AppSpacing.xl,
                    children: stats
                        .map(
                          (s) => SizedBox(
                            width: width,
                            child: AnimatedStatistic(
                              value: s.value,
                              label: s.label,
                              suffix: s.suffix,
                            ),
                          ),
                        )
                        .toList(),
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
                overline: 'VISIT US',
                title: 'Office locations',
              ),
              const SizedBox(height: AppSpacing.xxl),
              Wrap(
                spacing: AppSpacing.base,
                runSpacing: AppSpacing.base,
                children: offices
                    .map(
                      (o) => SizedBox(
                        width: context.isMobile ? double.infinity : 320,
                        child: _OfficeCard(office: o),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        SectionWrapper(
          child: context.isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _careersContent(context),
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _careersContent(context),
                    )),
                    const SizedBox(width: AppSpacing.xxl),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        decoration: BoxDecoration(
                          gradient: AppColors.goldGradient,
                          borderRadius: AppRadius.cardBorder,
                        ),
                        child: Column(
                          children: [
                            Text(
                              '${careers.openPositions}',
                              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                    color: AppColors.deepBlack,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const Text('Open positions'),
                            const SizedBox(height: AppSpacing.lg),
                            PrimaryButton(
                              label: careers.ctaLabel,
                              onPressed: () => context.go(careers.ctaPath),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  List<Widget> _careersContent(BuildContext context) => [
        const AnimatedSectionTitle(
          overline: 'CAREERS',
          title: 'Join the HD Homes team',
          subtitle: 'Build your career while building communities.',
          alignment: TextAlign.start,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(careers.culture, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: AppSpacing.lg),
        Text('Why work with us', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        for (final item in careers.whyWorkWithUs)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              children: [
                const Icon(Icons.check_rounded, color: AppColors.gold, size: 16),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(item)),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        Text('Benefits', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: careers.benefits.map((b) => Chip(label: Text(b))).toList(),
        ),
        if (context.isMobile) ...[
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: careers.ctaLabel,
            onPressed: () => context.go(careers.ctaPath),
          ),
        ],
      ];
}

class _OfficeCard extends StatelessWidget {
  const _OfficeCard({required this.office});

  final AboutOfficeLocation office;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.neutral200),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Chip(label: Text(office.type)),
          const SizedBox(height: AppSpacing.sm),
          Text(office.name, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          _OfficeRow(icon: LucideIcons.mapPin, text: office.address),
          _OfficeRow(icon: LucideIcons.phone, text: office.phone),
          _OfficeRow(icon: LucideIcons.mail, text: office.email),
          _OfficeRow(icon: LucideIcons.clock, text: office.hours),
          const SizedBox(height: AppSpacing.base),
          Row(
            children: [
              TextButton(
                onPressed: () => launchUrl(Uri.parse(office.mapUrl)),
                child: const Text('View Map'),
              ),
              const SizedBox(width: AppSpacing.sm),
              PrimaryButton(
                label: 'Book Appointment',
                onPressed: () => context.go(RoutePaths.bookInspection),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OfficeRow extends StatelessWidget {
  const _OfficeRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppColors.gold),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
        ],
      ),
    );
  }
}
