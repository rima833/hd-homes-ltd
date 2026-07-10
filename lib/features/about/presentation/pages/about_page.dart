import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/features/about/data/providers/about_content_provider.dart';
import 'package:hdhomesproject/features/about/presentation/sections/about_enterprise_section.dart';
import 'package:hdhomesproject/features/about/presentation/sections/about_hero_section.dart';
import 'package:hdhomesproject/features/about/presentation/sections/about_impact_section.dart';
import 'package:hdhomesproject/features/about/presentation/sections/about_intro_section.dart';
import 'package:hdhomesproject/features/about/presentation/sections/about_leadership_section.dart';
import 'package:hdhomesproject/features/about/presentation/sections/about_operations_section.dart';
import 'package:hdhomesproject/features/about/presentation/sections/about_services_section.dart';
import 'package:hdhomesproject/features/about/presentation/sections/about_story_section.dart';
import 'package:hdhomesproject/features/about/presentation/sections/about_timeline_section.dart';
import 'package:hdhomesproject/features/about/presentation/sections/about_vision_values_section.dart';

/// Premium corporate About page — trust-building flagship experience.
class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(aboutContentProvider);

    return Column(
      children: [
        AboutHeroSection(content: content.hero),
        AboutIntroSection(content: content.intro),
        AboutStorySection(chapters: content.story),
        AboutVisionValuesSection(
          vision: content.vision,
          mission: content.mission,
          values: content.values,
        ),
        AboutTimelineSection(items: content.timeline),
        AboutLeadershipSection(leaders: content.leadership),
        AboutServicesSection(
          whyChoose: content.whyChoose,
          services: content.services,
        ),
        AboutImpactSection(
          awards: content.awards,
          partners: content.partners,
          csr: content.csr,
          sustainability: content.sustainability,
          process: content.process,
        ),
        AboutOperationsSection(
          stats: content.stats,
          offices: content.offices,
          careers: content.careers,
        ),
        AboutEnterpriseSection(
          executiveVideo: content.executiveVideo,
          milestoneMap: content.milestoneMap,
          companyProfile: content.companyProfile,
          trustCenter: content.trustCenter,
          testimonials: content.testimonials,
          cta: content.cta,
        ),
      ],
    );
  }
}
