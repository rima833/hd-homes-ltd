import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/website/components/awards_recognitions_section.dart';
import 'package:hdhomesproject/core/website/components/partners_affiliations_section.dart';
import 'package:hdhomesproject/features/home/data/models/home_cms_content.dart';

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
