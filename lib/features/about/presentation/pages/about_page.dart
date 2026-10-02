import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/features/about/data/providers/about_content_provider.dart';
import 'package:hdhomesproject/features/about/presentation/sections/about_careers_section.dart';
import 'package:hdhomesproject/features/about/presentation/sections/about_client_journey_section.dart';
import 'package:hdhomesproject/features/about/presentation/sections/about_enterprise_section.dart';
import 'package:hdhomesproject/features/about/presentation/sections/about_executive_video_section.dart';
import 'package:hdhomesproject/features/about/presentation/sections/about_hero_section.dart';
import 'package:hdhomesproject/features/about/presentation/sections/about_impact_section.dart';
import 'package:hdhomesproject/features/about/presentation/sections/about_leadership_section.dart';
import 'package:hdhomesproject/features/about/presentation/sections/about_operations_section.dart';
import 'package:hdhomesproject/features/about/presentation/sections/about_services_section.dart';
import 'package:hdhomesproject/features/about/presentation/sections/about_story_section.dart';
import 'package:hdhomesproject/features/about/presentation/sections/about_vision_values_section.dart';
import 'package:hdhomesproject/features/home/data/providers/home_content_provider.dart';
import 'package:hdhomesproject/features/home/presentation/sections/home_about_section.dart';

/// Premium corporate About page — trust-building flagship experience.
class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(aboutContentProvider);
    final homeAbout = ref.watch(homeContentProvider).about;

    return Column(
      children: [
        AboutHeroSection(content: content.hero),
        AboutExecutiveVideoSection(executiveVideo: content.executiveVideo),
        // About HD Homes (mission/vision/highlights) moved here from Home.
        HomeAboutSection(content: homeAbout),
        AboutStorySection(chapters: content.story),
        AboutVisionValuesSection(
          vision: content.vision,
          mission: content.mission,
          values: content.values,
        ),
        if (content.leadership.isNotEmpty)
          AboutLeadershipSection(leaders: content.leadership),
        AboutServicesSection(
          whyChoose: content.whyChoose,
          services: content.services,
        ),
        AboutImpactSection(
          awards: content.awards,
          partners: content.partners,
        ),
        AboutClientJourneySection(fallbackSteps: content.process),
        AboutOperationsSection(stats: content.stats),
        AboutCareersSection(fallback: content.careers),
        AboutEnterpriseSection(
          companyProfile: content.companyProfile,
          cta: content.cta,
        ),
      ],
    );
  }
}
