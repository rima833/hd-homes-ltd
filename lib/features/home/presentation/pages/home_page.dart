import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/features/home/data/providers/home_content_provider.dart';
import 'package:hdhomesproject/features/home/presentation/sections/home_about_section.dart';
import 'package:hdhomesproject/features/home/presentation/sections/home_closing_sections.dart';
import 'package:hdhomesproject/features/home/presentation/sections/home_construction_section.dart';
import 'package:hdhomesproject/features/home/presentation/sections/home_content_hub_section.dart';
import 'package:hdhomesproject/features/home/presentation/sections/home_featured_estates_section.dart';
import 'package:hdhomesproject/features/home/presentation/sections/home_featured_properties_section.dart';
import 'package:hdhomesproject/features/home/presentation/sections/home_hero_section.dart';
import 'package:hdhomesproject/features/home/presentation/sections/home_investment_section.dart';
import 'package:hdhomesproject/features/home/presentation/sections/home_lifestyle_explorer_section.dart';
import 'package:hdhomesproject/features/home/presentation/sections/home_map_section.dart';
import 'package:hdhomesproject/features/home/presentation/sections/home_payment_calculator_section.dart';
import 'package:hdhomesproject/features/home/presentation/sections/home_property_search_section.dart';
import 'package:hdhomesproject/features/home/presentation/sections/home_roi_calculator_section.dart';
import 'package:hdhomesproject/features/home/presentation/sections/home_social_proof_sections.dart';
import 'package:hdhomesproject/features/home/presentation/sections/home_splash_overlay.dart';
import 'package:hdhomesproject/features/home/presentation/sections/home_stats_section.dart';
import 'package:hdhomesproject/features/home/presentation/sections/home_virtual_tours_section.dart';
import 'package:hdhomesproject/features/home/presentation/sections/home_why_choose_section.dart';

/// Digital flagship homepage — sections 1–30 composed from CMS content.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    final content = ref.watch(homeContentProvider);

    return Stack(
      children: [
        Column(
          children: [
            HomeHeroSection(content: content.hero),
            const HomePropertySearchSection(),
            HomeStatsSection(stats: content.stats),
            HomeAboutSection(content: content.about),
            HomeWhyChooseSection(items: content.whyChoose),
            HomeLifestyleExplorerSection(items: content.lifestyles),
            HomeFeaturedEstatesSection(estates: content.estates),
            HomeFeaturedPropertiesSection(properties: content.properties),
            const HomeMapSection(),
            HomeInvestmentSection(items: content.investments),
            const HomePaymentCalculatorSection(),
            const HomeRoiCalculatorSection(),
            HomeConstructionSection(projects: content.constructionProjects),
            const HomeVirtualToursSection(),
            HomeTestimonialsSection(items: content.testimonials),
            HomePartnersSection(partners: content.partners),
            HomeAwardsSection(awards: content.awards),
            HomeContentHubSection(
              blogPosts: content.blogPosts,
              insights: content.marketInsights,
              events: content.events,
              faqs: content.faqs,
            ),
            HomeClosingSections(
              downloads: content.downloads,
              liveActivities: content.liveActivities,
              executive: content.executiveWelcome,
              estates: content.estates,
            ),
          ],
        ),
        if (_showSplash)
          Positioned.fill(
            child: HomeSplashOverlay(
              onComplete: () => setState(() => _showSplash = false),
            ),
          ),
      ],
    );
  }
}
