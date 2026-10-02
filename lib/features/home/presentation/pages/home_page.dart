import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/features/home/data/mappers/home_cms_section_mapper.dart';
import 'package:hdhomesproject/features/home/data/models/home_cms_content.dart';
import 'package:hdhomesproject/features/home/data/providers/home_content_provider.dart';
import 'package:hdhomesproject/features/home/presentation/sections/home_about_section.dart';
import 'package:hdhomesproject/features/home/presentation/sections/home_closing_sections.dart';
import 'package:hdhomesproject/features/home/presentation/sections/home_content_hub_section.dart';
import 'package:hdhomesproject/features/home/presentation/sections/home_featured_estates_section.dart';
import 'package:hdhomesproject/features/home/presentation/sections/home_featured_properties_section.dart';
import 'package:hdhomesproject/core/website/components/published_testimonials_section.dart';
import 'package:hdhomesproject/features/home/presentation/sections/home_hero_section.dart';
import 'package:hdhomesproject/features/settings/domain/entities/public_website_gates.dart';
import 'package:hdhomesproject/features/settings/presentation/providers/platform_settings_providers.dart';
import 'package:hdhomesproject/features/home/presentation/sections/home_property_search_section.dart';
import 'package:hdhomesproject/features/home/presentation/sections/home_social_proof_sections.dart';
import 'package:hdhomesproject/features/home/presentation/sections/home_splash_overlay.dart';
import 'package:hdhomesproject/features/home/presentation/sections/home_stats_section.dart';
import 'package:hdhomesproject/features/home/presentation/sections/home_why_choose_section.dart';

/// Digital flagship homepage — sections composed from CMS content.
/// Order is always the canonical public layout; CMS controls visibility/content.
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
    // Always render in the designed top→bottom sequence. Scrambled CMS
    // sort_order values must never put hero/CTA/closing in the wrong place.
    final order = reconcileHomeSectionOrder(content.sectionOrder);
    final children = <Widget>[];

    for (final key in order) {
      final section = _buildSection(key, content);
      if (section != null) children.add(section);
    }

    return Stack(
      children: [
        Column(children: children),
        if (_showSplash)
          Positioned.fill(
            child: HomeSplashOverlay(
              onComplete: () => setState(() => _showSplash = false),
            ),
          ),
      ],
    );
  }

  Widget? _buildSection(String key, HomeCmsContent content) {
    bool vis(String k) => content.isSectionVisible(k);
    final settings = ref.watch(publishedPlatformSettingsProvider).valueOrNull;
    final allowFaq = settings?.allowFaq ?? true;

    switch (key) {
      case 'homepage_hero':
        return vis(key) ? HomeHeroSection(content: content.hero) : null;
      case 'homepage_search':
        return vis(key) ? const HomePropertySearchSection() : null;
      case 'homepage_stats':
        return vis(key) ? HomeStatsSection(stats: content.stats) : null;
      case 'homepage_about':
        return vis(key) ? HomeAboutSection(content: content.about) : null;
      case 'homepage_why_choose':
        return vis(key)
            ? HomeWhyChooseSection(
                items: content.whyChoose,
                stats: content.stats,
                about: content.about,
                executiveWelcome: vis('homepage_executive_welcome')
                    ? content.executiveWelcome
                    : const HomeExecutiveWelcome(
                        name: '',
                        title: '',
                        message: '',
                        videoUrl: null,
                      ),
              )
            : null;
      case 'homepage_featured_estates':
        return vis(key)
            ? HomeFeaturedEstatesSection(estates: content.estates)
            : null;
      case 'homepage_featured_properties':
        return vis(key)
            ? HomeFeaturedPropertiesSection(properties: content.properties)
            : null;
      case 'homepage_testimonials':
        return vis(key) ? const PublishedTestimonialsSection() : null;
      case 'homepage_partners':
        return vis(key)
            ? HomePartnersSection(partners: content.partners)
            : null;
      case 'homepage_trust':
        return vis(key) ? const HomeTrustCenterSection() : null;
      case 'homepage_awards':
        return vis(key) ? HomeAwardsSection(awards: content.awards) : null;

      // Visibility-only keys — rendered inside the content hub band.
      case 'homepage_blog':
      case 'homepage_faq':
        return null;
      case 'homepage_content_hub':
        final showBlog = vis('homepage_blog');
        final showFaq = vis('homepage_faq');
        if (!vis(key) && !showBlog && !showFaq) {
          return null;
        }
        return HomeContentHubSection(
          blogPosts: showBlog ? content.blogPosts : const [],
          faqs: showFaq && allowFaq ? content.faqs : const [],
        );

      // Quote is drawn inside Why Choose. CTA is drawn inside Closing.
      case 'homepage_executive_welcome':
      case 'homepage_cta':
        return null;
      case 'homepage_closing':
        if (!vis(key) && !vis('homepage_cta')) {
          return null;
        }
        return HomeClosingSections(
          cta: content.cta,
          showCta: vis('homepage_cta'),
        );
      default:
        return null;
    }
  }
}
