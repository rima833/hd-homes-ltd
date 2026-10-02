import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/published_testimonials_section.dart';
import 'package:hdhomesproject/features/about/data/models/about_cms_content.dart';
import 'package:hdhomesproject/features/about/presentation/sections/about_digital_company_profile_section.dart';
import 'package:hdhomesproject/features/about/presentation/sections/about_premium_cta_section.dart';

/// Enterprise enhancements + closing sections (company profile, testimonials, CTA).
class AboutEnterpriseSection extends StatelessWidget {
  const AboutEnterpriseSection({
    super.key,
    required this.companyProfile,
    required this.cta,
  });

  final AboutCompanyProfile companyProfile;
  final AboutCtaContent cta;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AboutDigitalCompanyProfileSection(fallback: companyProfile),
        const PublishedTestimonialsSection(
          backgroundColor: AppColors.charcoal,
        ),
        AboutPremiumCtaSection(cta: cta),
      ],
    );
  }
}
