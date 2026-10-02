import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/awards_recognitions_section.dart';
import 'package:hdhomesproject/core/website/components/company_statistics_section.dart';
import 'package:hdhomesproject/core/website/components/partners_affiliations_section.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/features/about/data/providers/about_content_provider.dart';
import 'package:hdhomesproject/features/about/presentation/sections/about_digital_company_profile_section.dart';
import 'package:hdhomesproject/features/about/presentation/sections/about_leadership_section.dart';
import 'package:hdhomesproject/features/about/presentation/sections/about_vision_values_section.dart';
import 'package:hdhomesproject/features/trust/data/models/trust_center_content.dart';
import 'package:hdhomesproject/features/trust/data/providers/trust_cms_provider.dart';
import 'package:hdhomesproject/features/trust/presentation/widgets/trust_enterprise_widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Live Trust hub: why-trust, stats, profile, awards, leadership, legal, partners.
class TrustHubSections extends HookConsumerWidget {
  const TrustHubSections({
    super.key,
    this.certificationsKey,
    this.legalKey,
  });

  final GlobalKey? certificationsKey;
  final GlobalKey? legalKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cms = ref.watch(trustHubCmsProvider);
    final about = ref.watch(aboutContentProvider);
    final docQuery = useState('');

    final filteredDocs = docQuery.value.isEmpty
        ? cms.legalDocuments
        : cms.legalDocuments
            .where(
              (d) =>
                  d.title.toLowerCase().contains(docQuery.value.toLowerCase()) ||
                  d.category
                      .toLowerCase()
                      .contains(docQuery.value.toLowerCase()),
            )
            .toList();

    return Column(
      children: [
        SectionWrapper(
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'WHY TRUST US',
                title: 'Why trust HD Homes',
                subtitle:
                    'Integrity, transparency, and regulatory compliance at every stage.',
              ),
              const SizedBox(height: AppSpacing.xl),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cross = context.isMobile ? 2 : 4;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cross,
                      mainAxisSpacing: AppSpacing.base,
                      crossAxisSpacing: AppSpacing.base,
                      childAspectRatio: context.isMobile ? 0.95 : 1.12,
                    ),
                    itemCount: cms.pillars.length,
                    itemBuilder: (_, i) =>
                        TrustPillarCard(pillar: cms.pillars[i]),
                  );
                },
              ),
            ],
          ),
        ),
        CompanyStatisticsSection(
          overline: 'BY THE NUMBERS',
          title: 'Company statistics',
          stats: [
            for (final s in about.stats)
              CompanyStatItem(
                value: s.value,
                label: s.label,
                suffix: s.suffix ?? '',
                description: s.description,
                iconName: s.iconName,
                logoUrl: s.logoUrl,
                placement: s.placement,
              ),
          ],
        ),
        SectionWrapper(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AnimatedSectionTitle(
                overline: 'PROFILE',
                title: 'Company profile',
                subtitle:
                    'Overview, vision, mission, and values stay in sync with About and the homepage.',
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                cms.companyOverview,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
        AboutVisionValuesSection(
          vision: about.vision,
          mission: about.mission,
          values: about.values,
        ),
        AboutDigitalCompanyProfileSection(fallback: about.companyProfile),
        KeyedSubtree(
          key: certificationsKey,
          child: AwardsRecognitionsSection(
            title: 'Licenses & certifications',
            subtitle:
                'Official recognitions and memberships — the same live records shown on Home and About.',
            awards: [
              for (final award in about.awards)
                AwardRecognitionItem(
                  title: award.title,
                  year: award.year,
                  issuer: award.issuer,
                  description: award.description,
                ),
            ],
          ),
        ),
        AboutLeadershipSection(leaders: about.leadership),
        SectionWrapper(
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'INVESTOR PROTECTION',
                title: 'Investor protection',
                subtitle: 'Safeguards for local and international investors.',
              ),
              const SizedBox(height: AppSpacing.lg),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cross = context.isMobile ? 1 : 2;
                  final width =
                      (constraints.maxWidth - (cross - 1) * AppSpacing.base) /
                          cross;
                  return Wrap(
                    spacing: AppSpacing.base,
                    runSpacing: AppSpacing.base,
                    children: [
                      for (final item in cms.investorProtection)
                        SizedBox(
                          width: width,
                          child: _ProtectionCard(item: item),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              TextButton.icon(
                onPressed: () => context.go(RoutePaths.investment),
                icon: const Icon(LucideIcons.arrowRight, size: 16),
                label: const Text('Explore investment opportunities'),
              ),
            ],
          ),
        ),
        SectionWrapper(
          key: legalKey,
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AnimatedSectionTitle(
                overline: 'LEGAL',
                title: 'Legal document center',
                subtitle:
                    'Published policies from Admin → Website → Pages. Open any document to read the live copy.',
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search documents…',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => docQuery.value = v,
              ),
              const SizedBox(height: AppSpacing.lg),
              ...filteredDocs.map(
                (d) => _LegalDocTile(
                  document: d,
                  onOpen: () {
                    final slug = d.slug;
                    if (slug == null || slug.isEmpty) return;
                    context.go(RoutePaths.cmsPagePath(slug));
                  },
                ),
              ),
            ],
          ),
        ),
        PartnersAffiliationsSection(
          title: 'Partners & affiliations',
          subtitle:
              'Banking, legal, and institutional partners — the same live directory as Home and About.',
          partners: [
            for (final partner in about.partners)
              PartnerAffiliationItem(
                name: partner.name,
                category: partner.category,
                tagline: partner.tagline,
                logoUrl: partner.logoUrl,
                iconName: partner.iconName,
              ),
          ],
        ),
      ],
    );
  }
}

class _ProtectionCard extends StatelessWidget {
  const _ProtectionCard({required this.item});

  final TrustInvestorProtectionItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.shieldCheck, color: AppColors.gold, size: 22),
          const SizedBox(height: AppSpacing.sm),
          Text(item.title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(item.description, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _LegalDocTile extends StatefulWidget {
  const _LegalDocTile({required this.document, required this.onOpen});

  final TrustLegalDocument document;
  final VoidCallback onOpen;

  @override
  State<_LegalDocTile> createState() => _LegalDocTileState();
}

class _LegalDocTileState extends State<_LegalDocTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.document;
    final meta = [
      d.category,
      if (d.updatedAt.isNotEmpty) 'Updated ${d.updatedAt}',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: AppRadius.cardBorder,
          child: InkWell(
            onTap: widget.onOpen,
            borderRadius: AppRadius.cardBorder,
            child: AnimatedContainer(
              duration: AppDurations.fast,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.base,
              ),
              decoration: BoxDecoration(
                borderRadius: AppRadius.cardBorder,
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: _hovered ? 0.4 : 0.14),
                ),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.fileText, color: AppColors.gold, size: 20),
                  const SizedBox(width: AppSpacing.base),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.title, style: Theme.of(context).textTheme.titleSmall),
                        if (meta.isNotEmpty)
                          Text(meta, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  Icon(
                    LucideIcons.arrowRight,
                    size: 16,
                    color: AppColors.gold.withValues(alpha: 0.85),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
