import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/website/components/awards_recognitions_section.dart';
import 'package:hdhomesproject/core/website/components/partners_affiliations_section.dart';
import 'package:hdhomesproject/features/about/data/models/about_cms_content.dart';

/// Awards and partners blocks on About.
class AboutImpactSection extends StatelessWidget {
  const AboutImpactSection({
    super.key,
    required this.awards,
    required this.partners,
  });

  final List<AboutAwardItem> awards;
  final List<AboutPartnerItem> partners;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AwardsRecognitionsSection(
          awards: [
            for (final award in awards)
              AwardRecognitionItem(
                title: award.title,
                year: award.year,
                issuer: award.issuer,
                description: award.description,
              ),
          ],
        ),
        PartnersAffiliationsSection(
          partners: [
            for (final partner in partners)
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
