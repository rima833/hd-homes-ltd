import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/awards_recognitions_section.dart';
import 'package:hdhomesproject/core/website/components/partners_affiliations_section.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/features/home/data/models/home_cms_content.dart';
import 'package:lucide_icons/lucide_icons.dart';

export 'package:hdhomesproject/features/home/presentation/sections/home_testimonials_section.dart';

/// Section 19 — Partners & affiliations (mockup).
class HomePartnersSection extends StatelessWidget {
  const HomePartnersSection({super.key, required this.partners});

  final List<HomePartnerItem> partners;

  @override
  Widget build(BuildContext context) {
    return PartnersAffiliationsSection(
      partners: [
        for (final p in partners)
          PartnerAffiliationItem(
            name: p.name,
            category: p.category,
            tagline: p.tagline,
            logoUrl: p.logoUrl,
            iconName: p.iconName,
          ),
      ],
    );
  }
}

/// Section 19b — Trust Center grid (mockup).
class HomeTrustCenterSection extends StatelessWidget {
  const HomeTrustCenterSection({super.key});

  static const _items = [
    (
      LucideIcons.shieldCheck,
      'Registered Developer',
      'Corporate Affairs Commission verified',
    ),
    (
      LucideIcons.shield,
      'Licensed & Insured',
      'Full regulatory compliance',
    ),
    (
      LucideIcons.award,
      'Industry Awards',
      'Recognized excellence in development',
    ),
    (
      LucideIcons.hardHat,
      'Construction Milestones',
      'Transparent project delivery',
    ),
    (
      LucideIcons.quote,
      'Verified Testimonials',
      'Real clients, real results',
    ),
    (
      LucideIcons.heartHandshake,
      'Partner Network',
      'Trusted institutional partners',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SectionWrapper(
      backgroundColor: AppColors.deepBlack,
      child: Column(
        children: [
          Text(
            'TRUST CENTER',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.gold,
                  letterSpacing: 2.4,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Built on transparency and proven delivery',
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              fontSize: context.isMobile ? 26 : 36,
              fontWeight: FontWeight.w700,
              color: AppColors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Text(
              'Every HD Homes project is backed by verifiable credentials, milestones, and partnerships.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondaryDark,
                    height: 1.55,
                  ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(
                color: AppColors.white.withValues(alpha: 0.1),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = context.isMobile
                    ? 1
                    : context.isTablet
                        ? 2
                        : 3;
                return Table(
                  border: TableBorder.symmetric(
                    inside: BorderSide(
                      color: AppColors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  children: [
                    for (var row = 0; row < (_items.length / columns).ceil(); row++)
                      TableRow(
                        children: [
                          for (var col = 0; col < columns; col++)
                            _TrustCell(
                              item: row * columns + col < _items.length
                                  ? _items[row * columns + col]
                                  : null,
                            ),
                        ],
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustCell extends StatelessWidget {
  const _TrustCell({required this.item});

  final (IconData, String, String)? item;

  @override
  Widget build(BuildContext context) {
    if (item == null) {
      return const SizedBox.shrink();
    }

    final (icon, title, subtitle) = item!;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.gold, size: 22),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle,
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

/// Section 20 — Awards & recognition (mockup).
class HomeAwardsSection extends StatelessWidget {
  const HomeAwardsSection({super.key, required this.awards});

  final List<HomeAwardItem> awards;

  @override
  Widget build(BuildContext context) {
    return AwardsRecognitionsSection(
      awards: [
        for (final a in awards)
          AwardRecognitionItem(
            title: a.title,
            year: a.year,
            issuer: a.issuer,
            description: a.description,
            iconName: a.iconName,
          ),
      ],
    );
  }
}
