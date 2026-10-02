import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/constants/brand_copy.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/about/data/models/about_cms_content.dart';
import 'package:hdhomesproject/features/cms/domain/data/hub_page_cms.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/home/data/providers/home_content_provider.dart';

final aboutContentProvider = Provider<AboutCmsContent>((ref) {
  final supabaseReady = ref.watch(supabaseConfiguredProvider);

  // Only attach realtime / remote CMS when Supabase is actually usable.
  // Watching these while configured-but-uninitialized crashes web/tests and
  // can blank the public shell until a hard refresh.
  List<AboutLeaderProfile> leadership = const [];
  if (supabaseReady) {
  ref.watch(publishedPagesRealtimeProvider);
  ref.watch(homepageContentRealtimeProvider);
  ref.watch(partnersRealtimeProvider);
  ref.watch(companyStatsRealtimeProvider);
  ref.watch(teamRealtimeProvider);
  ref.watch(digitalCompanyProfileRealtimeProvider);
  final publishedTeam = ref.watch(publishedTeamProvider);
    leadership = publishedTeam.maybeWhen(
      data: (team) => team.isNotEmpty
          ? team
              .map(
                (member) => AboutLeaderProfile(
                  name: member.fullName,
                  position: member.jobTitle ?? 'Team',
                  bio: member.bio ?? '',
                  qualifications: const [],
                  yearsExperience: 0,
                  photoUrl: member.avatarUrl,
                  email: member.email,
                ),
              )
              .toList()
          : const [],
      orElse: () => const [],
    );
  }

  final base = AboutCmsContent(
    hero: AboutHeroContent(
      headline: BrandCopy.heroHeadline,
      subheadline: BrandCopy.heroSubheadline,
      primaryCtaLabel: 'Our Projects',
      primaryCtaPath: RoutePaths.properties,
      secondaryCtaLabel: 'Contact Us',
      secondaryCtaPath: RoutePaths.contact,
      tertiaryCtaLabel: 'Book Consultation',
      tertiaryCtaPath: RoutePaths.bookInspection,
    ),
    intro: AboutIntroContent(
      description: BrandCopy.story,
      yearsOperating: 15,
      specializations: const [
        AboutIntroTag(label: 'Residential Development', iconName: 'home'),
        AboutIntroTag(label: 'Estate Planning', iconName: 'pen_tool'),
        AboutIntroTag(label: 'Real Estate Investment', iconName: 'building'),
        AboutIntroTag(label: 'Construction Management', iconName: 'hard_hat'),
      ],
      geographicPresence: const ['Lagos', 'Abuja', 'Port Harcourt', 'Enugu'],
      achievements: const [],
      philosophy: BrandCopy.philosophy,
      imageUrl:
          '',
    ),
    story: [
      AboutStoryChapter(
        year: '2011',
        title: 'The beginning',
        summary: 'HD Homes was founded on a clear vision.',
        body:
            'HD Homes was founded with a mission to bridge Nigeria\'s housing gap through quality, affordable developments.',
        imageUrl:
            '',
        features: const [
          AboutStoryFeature(
            title: 'Clear Vision',
            description: 'A founding brief to close Nigeria\'s housing gap.',
            iconName: 'eye',
          ),
          AboutStoryFeature(
            title: 'Quality First',
            description: 'Homes built with integrity from day one.',
            iconName: 'award',
          ),
          AboutStoryFeature(
            title: 'Trusted Start',
            description: 'Registered developer ready for delivery.',
            iconName: 'shield',
          ),
        ],
      ),
      AboutStoryChapter(
        year: '2015',
        title: 'First developments',
        summary: 'Our first projects set the foundation for growth.',
        body:
            'Delivered our first master-planned estate, establishing our reputation for transparent delivery and premium finishes.',
        imageUrl:
            '',
        features: const [
          AboutStoryFeature(
            title: 'First Estate',
            description: 'Master-planned community delivered with care.',
            iconName: 'building',
          ),
          AboutStoryFeature(
            title: 'Transparent Delivery',
            description: 'Clear timelines, titles, and communication.',
            iconName: 'file_check',
          ),
          AboutStoryFeature(
            title: 'Premium Finishes',
            description: 'Standards that set HD Homes apart.',
            iconName: 'home',
          ),
        ],
      ),
      AboutStoryChapter(
        year: '2019',
        title: 'Expanding Impact',
        summary: 'More communities, more families, more value.',
        body:
            'Expanded operations to Abuja and Port Harcourt, partnering with leading financial institutions.',
        imageUrl:
            '',
        features: const [
          AboutStoryFeature(
            title: 'Multi-City Reach',
            description: 'Lagos, Abuja, and Port Harcourt corridors.',
            iconName: 'map',
          ),
          AboutStoryFeature(
            title: 'More Families',
            description: 'Broader access to quality housing.',
            iconName: 'users',
          ),
          AboutStoryFeature(
            title: 'Institutional Partners',
            description: 'Finance partners that accelerate delivery.',
            iconName: 'handshake',
          ),
        ],
      ),
      AboutStoryChapter(
        year: '2024',
        title: 'Innovation & Growth',
        summary: 'Embracing technology, raising new standards.',
        body:
            'Launched digital client and investor portals, setting a new standard for transparency in Nigerian real estate.',
        imageUrl:
            '',
        features: const [
          AboutStoryFeature(
            title: 'Client Portal',
            description: 'Digital access to projects and payments.',
            iconName: 'cpu',
          ),
          AboutStoryFeature(
            title: 'Investor Tools',
            description: 'Visibility into portfolio performance.',
            iconName: 'trending_up',
          ),
          AboutStoryFeature(
            title: 'Higher Standards',
            description: 'PropTech transparency as the default.',
            iconName: 'sparkles',
          ),
        ],
      ),
      AboutStoryChapter(
        year: '2026',
        title: 'Looking Ahead',
        summary: 'Building the future of sustainable living.',
        body:
            'Scaling sustainable developments and smart-home communities across West Africa.',
        imageUrl:
            '',
        features: const [
          AboutStoryFeature(
            title: 'More Communities',
            description: 'Expanding to key cities across Africa.',
            iconName: 'building',
          ),
          AboutStoryFeature(
            title: 'Sustainable Living',
            description: 'Eco-friendly builds for a better tomorrow.',
            iconName: 'leaf',
          ),
          AboutStoryFeature(
            title: 'Smart Homes',
            description: 'Technology-driven living experiences.',
            iconName: 'cpu',
          ),
        ],
      ),
    ],
    vision: BrandCopy.vision,
    mission: BrandCopy.mission,
    values: [
      for (final value in BrandCopy.coreValues)
        AboutValueItem(
          title: value.title,
          subtitle: value.subtitle,
          description: value.description,
          iconName: value.iconName,
        ),
    ],
    timeline: [
      AboutTimelineItem(
        date: '2011',
        title: 'Company Founded',
        description: 'HD Homes Ltd incorporated in Nigeria.',
      ),
      AboutTimelineItem(
        date: '2015',
        title: 'First Estate Delivered',
        description: 'Flagship residential estate completed in Lagos.',
      ),
      AboutTimelineItem(
        date: '2018',
        title: '100th Home Handed Over',
        description: 'Milestone delivery to happy homeowners.',
      ),
      AboutTimelineItem(
        date: '2020',
        title: 'Abuja Expansion',
        description: 'Regional office and Emerald Heights launch.',
      ),
      AboutTimelineItem(
        date: '2023',
        title: 'Industry Award',
        description: 'Excellence in Housing Development recognition.',
      ),
      AboutTimelineItem(
        date: '2025',
        title: 'Strategic Bank Partnerships',
        description: 'Mortgage and investment partnerships formalised.',
      ),
      AboutTimelineItem(
        date: '2026',
        title: 'Horizon Gardens Launch',
        description: 'Next-generation smart estate development.',
      ),
    ],
    leadership: leadership,
    whyChoose: [
      AboutWhyChooseItem(
        title: 'Trusted Developer',
        description: 'Verified track record with documented deliveries.',
        iconName: 'shield',
      ),
      AboutWhyChooseItem(
        title: 'Transparent Processes',
        description: 'Clear timelines, titles, and payment schedules.',
        iconName: 'eye',
      ),
      AboutWhyChooseItem(
        title: 'Quality Construction',
        description: 'Premium materials and supervised workmanship.',
        iconName: 'hard_hat',
      ),
      AboutWhyChooseItem(
        title: 'Prime Locations',
        description: 'Strategic corridors with strong appreciation.',
        iconName: 'map_pin',
      ),
      AboutWhyChooseItem(
        title: 'Flexible Payment Plans',
        description: 'Structured plans for buyers and investors.',
        iconName: 'wallet',
      ),
      AboutWhyChooseItem(
        title: 'Strong Investment Returns',
        description: 'Products designed for capital growth.',
        iconName: 'trending_up',
      ),
      AboutWhyChooseItem(
        title: 'Customer Support',
        description: 'Dedicated teams from inquiry to handover.',
        iconName: 'headphones',
      ),
      AboutWhyChooseItem(
        title: 'Legal Compliance',
        description: 'Full regulatory and documentation compliance.',
        iconName: 'file_check',
      ),
    ],
    services: [
      AboutServiceItem(
        title: 'Property Development',
        description: 'Master-planned estates and residential communities.',
        route: RoutePaths.estates,
        iconName: 'building',
      ),
      AboutServiceItem(
        title: 'Property Sales',
        description: 'Ready and off-plan homes for every budget.',
        route: RoutePaths.properties,
        iconName: 'home',
      ),
      AboutServiceItem(
        title: 'Real Estate Investment',
        description: 'Structured investment products and portfolios.',
        route: RoutePaths.investment,
        iconName: 'trending_up',
      ),
      AboutServiceItem(
        title: 'Construction',
        description: 'End-to-end construction management.',
        route: RoutePaths.services,
        iconName: 'hard_hat',
      ),
      AboutServiceItem(
        title: 'Architectural Design',
        description: 'Premium design tailored to lifestyle needs.',
        route: RoutePaths.services,
        iconName: 'pen_tool',
      ),
      AboutServiceItem(
        title: 'Project Management',
        description: 'On-time, on-budget delivery oversight.',
        route: RoutePaths.services,
        iconName: 'clipboard',
      ),
      AboutServiceItem(
        title: 'Land Acquisition',
        description: 'Verified plots and estate parcels.',
        route: RoutePaths.services,
        iconName: 'map',
      ),
      AboutServiceItem(
        title: 'Property Consultancy',
        description: 'Expert guidance for buyers and investors.',
        route: RoutePaths.contact,
        iconName: 'message_circle',
      ),
    ],
    awards: const [],
    partners: const [],
    csr: AboutCsrContent(
      intro:
          'HD Homes invests in communities beyond construction — creating lasting social impact across Nigeria.',
      initiatives: [
        AboutCsrInitiative(
          title: 'Affordable Housing Initiatives',
          description: 'Subsidised units for first-time buyers in select estates.',
        ),
        AboutCsrInitiative(
          title: 'Youth Empowerment',
          description: 'Skills training and apprenticeships in construction trades.',
        ),
        AboutCsrInitiative(
          title: 'Education Programs',
          description: 'Scholarships and school infrastructure support.',
        ),
        AboutCsrInitiative(
          title: 'Community Development',
          description: 'Roads, drainage, and public space improvements.',
        ),
      ],
      impactStats: [
        AboutStatItem(value: 500, label: 'Families Supported', suffix: '+'),
        AboutStatItem(value: 120, label: 'Scholarships Awarded'),
        AboutStatItem(value: 25, label: 'Community Projects'),
      ],
    ),
    sustainability: [
      AboutSustainabilityItem(
        title: 'Energy-Efficient Buildings',
        description: 'Solar-ready designs and LED lighting standards.',
        iconName: 'zap',
      ),
      AboutSustainabilityItem(
        title: 'Water Conservation',
        description: 'Rainwater harvesting and efficient plumbing.',
        iconName: 'droplet',
      ),
      AboutSustainabilityItem(
        title: 'Green Spaces',
        description: 'Parks, landscaping, and biodiversity corridors.',
        iconName: 'tree',
      ),
      AboutSustainabilityItem(
        title: 'Smart Home Technology',
        description: 'IoT-ready homes for modern living.',
        iconName: 'cpu',
      ),
    ],
    process: [
      AboutProcessStep(
        title: 'Inquiry',
        description: 'Reach out via web, phone, or visit our sales office.',
        timeline: 'Day 1',
        iconName: 'message',
      ),
      AboutProcessStep(
        title: 'Consultation',
        description: 'Personalised needs assessment with our advisors.',
        timeline: '1–3 days',
        iconName: 'users',
      ),
      AboutProcessStep(
        title: 'Property Selection',
        description: 'Choose from available units, estates, or investment products.',
        timeline: '1–2 weeks',
        iconName: 'search',
      ),
      AboutProcessStep(
        title: 'Site Inspection',
        description: 'Tour the property or development site.',
        timeline: 'Scheduled',
        iconName: 'map_pin',
      ),
      AboutProcessStep(
        title: 'Documentation',
        description: 'Transparent contracts and verified title documents.',
        timeline: '1–2 weeks',
        iconName: 'file',
      ),
      AboutProcessStep(
        title: 'Payment',
        description: 'Flexible plans aligned to your budget.',
        timeline: 'Ongoing',
        iconName: 'wallet',
      ),
      AboutProcessStep(
        title: 'Construction',
        description: 'Regular progress updates and milestone tracking.',
        timeline: 'Project-dependent',
        iconName: 'crane',
      ),
      AboutProcessStep(
        title: 'Handover',
        description: 'Quality-checked delivery with full documentation.',
        timeline: 'On completion',
        iconName: 'key',
      ),
      AboutProcessStep(
        title: 'After-Sales Support',
        description: 'Dedicated support for maintenance and referrals.',
        timeline: 'Lifetime',
        iconName: 'headphones',
      ),
    ],
    stats: const [],
    offices: const [],
    careers: AboutCareersPreview(
      whyWorkWithUs: [
        'Growth-oriented culture',
        'Competitive compensation',
        'Professional development',
        'Impact-driven work',
      ],
      culture:
          'We foster innovation, collaboration, and excellence — building careers alongside communities.',
      benefits: [
        'Health insurance',
        'Performance bonuses',
        'Training programs',
        'Flexible arrangements',
      ],
      openPositions: 0,
      ctaLabel: 'View Careers',
      ctaPath: RoutePaths.careers,
    ),
    testimonials: const [],
    executiveVideo: const AboutExecutiveVideo(
      speakerName: '',
      speakerTitle: '',
      message: '',
    ),
    milestoneMap: [
      AboutMilestoneMarker(
        city: 'Lagos',
        label: 'Horizon Gardens',
        type: 'completed',
        lat: 6.44,
        lng: 3.47,
      ),
      AboutMilestoneMarker(
        city: 'Abuja',
        label: 'Emerald Heights',
        type: 'ongoing',
        lat: 9.08,
        lng: 7.49,
      ),
      AboutMilestoneMarker(
        city: 'Port Harcourt',
        label: 'Palm Grove Estate',
        type: 'completed',
        lat: 4.82,
        lng: 7.03,
      ),
      AboutMilestoneMarker(
        city: 'Enugu',
        label: 'Future Development',
        type: 'upcoming',
        lat: 6.45,
        lng: 7.51,
      ),
    ],
    companyProfile: AboutCompanyProfile(
      overline: 'COMPANY PROFILE',
      title: 'Digital company profile',
      description:
          'Interactive overview of our history, projects, leadership, and investment opportunities.',
      cardTitle: 'Interactive Company Profile',
      cardDescription:
          'Explore who we are, what we do, and the impact we create through innovation and excellence.',
      features: const [
        'Company History',
        'Investment Portfolio',
        'Completed Projects',
        'Certifications',
        'Executive Leadership',
        'Core Values',
      ],
      ctaLabel: 'View Digital Profile',
      downloadUrl: '#',
      viewUrl: '#',
      pdfLabel: 'Download PDF',
      pdfMeta: '18 MB | Updated May 20, 2025',
      brochureLabel: 'Download Brochure',
      brochureUrl: '#',
      brochureMeta: '12 MB | Updated May 20, 2025',
      trustMessage:
          'Trusted by thousands of clients and investors across Nigeria and beyond.',
      trustStats: const [
        AboutProfileTrustStat(value: '15+', label: 'Years Experience'),
        AboutProfileTrustStat(value: '3200+', label: 'Homes Delivered'),
        AboutProfileTrustStat(value: '12000+', label: 'Happy Clients'),
        AboutProfileTrustStat(value: '48', label: 'Projects Completed'),
      ],
    ),
    trustCenter: [
      AboutTrustItem(
        title: 'CAC Registration',
        detail: 'Registered with Corporate Affairs Commission',
        reference: 'RC-XXXXXXX',
      ),
      AboutTrustItem(
        title: 'NIESV Membership',
        detail: 'Nigerian Institution of Estate Surveyors and Valuers',
        reference: 'Member #XXXX',
      ),
      AboutTrustItem(
        title: 'Insurance Coverage',
        detail: 'Comprehensive project and liability insurance',
        reference: 'Policy #XXXX',
      ),
      AboutTrustItem(
        title: 'Building Permits',
        detail: 'All developments fully permitted and approved',
        reference: 'State-approved',
      ),
    ],
    cta: AboutCtaContent(
      title: 'Ready to build your future with HD Homes?',
      subtitle:
          'Explore properties, investment opportunities, or schedule a consultation with our team.',
      actions: [
        AboutCtaAction(
          label: 'Browse Properties',
          path: RoutePaths.properties,
          isPrimary: true,
        ),
        AboutCtaAction(
          label: 'Become an Investor',
          path: RoutePaths.investment,
          isPrimary: false,
          description: 'Join our growing network of investors.',
          iconName: 'investor',
        ),
        AboutCtaAction(
          label: 'Book Site Inspection',
          path: RoutePaths.bookInspection,
          isPrimary: false,
          description:
              'Schedule a visit and experience our developments firsthand.',
          iconName: 'calendar',
        ),
        AboutCtaAction(
          label: 'Download Company Profile',
          path: RoutePaths.about,
          isPrimary: false,
          description:
              'Get insights into our projects, values, and track record.',
          iconName: 'document',
        ),
      ],
    ),
  );

  if (!supabaseReady) return base;

  final publishedAwards =
      ref.watch(publishedAwardsProvider).valueOrNull ?? const <CmsAward>[];
  final awardsResolved = publishedAwards.isEmpty
      ? base.awards
      : [
          for (final a in publishedAwards)
            AboutAwardItem(
              title: a.title,
              year: a.year,
              issuer: a.issuer,
              description: a.description,
              verificationUrl: a.verificationUrl,
            ),
        ];

  final publishedPartners =
      ref.watch(publishedPartnersAboutProvider).valueOrNull ??
          const <CmsPartner>[];
  final partnersResolved = publishedPartners.isEmpty
      ? base.partners
      : [
          for (final p in publishedPartners)
            AboutPartnerItem(
              name: p.name,
              category: p.category,
              tagline: p.tagline,
              logoUrl: p.logoUrl,
              iconName: p.iconName,
            ),
        ];

  final publishedStats =
      ref.watch(publishedCompanyStatsAboutProvider).valueOrNull ??
          const <CmsCompanyStat>[];
  final statsResolved = publishedStats.isEmpty
      ? base.stats
      : [
          for (final s in publishedStats)
            AboutStatItem(
              value: s.value,
              label: s.label,
              suffix: s.suffix.isEmpty ? null : s.suffix,
              description: s.description,
              iconName: s.iconName,
              logoUrl: s.logoUrl,
              placement: s.placement,
            ),
        ];

  final publishedTestimonials =
      ref.watch(publishedTestimonialsProvider).valueOrNull ??
          const <CmsTestimonial>[];
  final testimonialsResolved = publishedTestimonials.isEmpty
      ? base.testimonials
      : [
          for (final t in publishedTestimonials)
            AboutTestimonialItem(
              name: t.clientName,
              role: t.clientTitle ?? 'Client',
              quote: t.content,
              rating: (t.rating ?? 5).toDouble(),
              verified: true,
              type: 'client',
              avatarUrl: t.avatarUrl,
            ),
        ];

  // Prefer homepage About mission/vision so Home teaser and /about never drift.
  final homepageSections =
      ref.watch(publishedHomepageSectionsProvider).valueOrNull ?? const [];
  AboutCmsContent synced = AboutCmsContent(
    hero: base.hero,
    intro: base.intro,
    story: const [],
    vision: base.vision,
    mission: base.mission,
    values: base.values,
    timeline: base.timeline,
    leadership: base.leadership,
    whyChoose: base.whyChoose,
    services: base.services,
    awards: awardsResolved,
    partners: partnersResolved,
    csr: base.csr,
    sustainability: base.sustainability,
    process: base.process,
    stats: statsResolved,
    offices: base.offices,
    careers: base.careers,
    testimonials: testimonialsResolved,
    executiveVideo: base.executiveVideo,
    milestoneMap: const [],
    companyProfile: base.companyProfile,
    trustCenter: base.trustCenter,
    cta: base.cta,
  );
  for (final section in homepageSections) {
    if (section.sectionKey != 'homepage_about') continue;
    final c = section.content;
    final mission = (c['mission'] as String?)?.trim();
    final vision = (c['vision'] as String?)?.trim();
    final story = (c['story'] as String?)?.trim();
    synced = AboutCmsContent(
      hero: base.hero,
      intro: AboutIntroContent(
        description: (story != null && story.isNotEmpty)
            ? story
            : base.intro.description,
        yearsOperating: base.intro.yearsOperating,
        specializations: base.intro.specializations,
        geographicPresence: base.intro.geographicPresence,
        achievements: base.intro.achievements,
        philosophy: base.intro.philosophy,
        imageUrl: base.intro.imageUrl,
      ),
      story: const [],
      vision: (vision != null && vision.isNotEmpty) ? vision : base.vision,
      mission: (mission != null && mission.isNotEmpty) ? mission : base.mission,
      values: base.values,
      timeline: base.timeline,
      leadership: base.leadership,
      whyChoose: base.whyChoose,
      services: base.services,
      awards: awardsResolved,
      partners: partnersResolved,
      csr: base.csr,
      sustainability: base.sustainability,
      process: base.process,
      stats: statsResolved,
      offices: base.offices,
      careers: base.careers,
      testimonials: testimonialsResolved,
      executiveVideo: base.executiveVideo,
      milestoneMap: const [],
      companyProfile: base.companyProfile,
      trustCenter: base.trustCenter,
      cta: base.cta,
    );
    break;
  }

  final page = ref.watch(publishedPageBySlugProvider('about')).valueOrNull;
  if (page == null) return synced;
  return _overlayAboutFromCmsPage(synced, page);
});

AboutCmsContent _overlayAboutFromCmsPage(
  AboutCmsContent base,
  CmsPageRecord page,
) {
  final content = page.content;
  final overlay = hubHeroFromPage(page);
  final heroMap = content['hero'] is Map
      ? Map<String, dynamic>.from(content['hero'] as Map)
      : const <String, dynamic>{};
  final introMap = content['intro'] is Map
      ? Map<String, dynamic>.from(content['intro'] as Map)
      : const <String, dynamic>{};

  // Prefer explicit CMS hero fields (flat heroHeadline / nested hero).
  // Never fall back to page.title / metaDescription — those produce a
  // broken "About / About HD Homes." hero when hub seeds are sparse.
  final hero = AboutHeroContent(
    headline: overlay.headline ?? base.hero.headline,
    subheadline: overlay.subheadline ?? base.hero.subheadline,
    primaryCtaLabel: overlay.primaryCtaLabel ??
        heroMap['primaryCtaLabel'] as String? ??
        base.hero.primaryCtaLabel,
    primaryCtaPath: heroMap['primaryCtaPath'] as String? ??
        base.hero.primaryCtaPath,
    secondaryCtaLabel: overlay.secondaryCtaLabel ??
        heroMap['secondaryCtaLabel'] as String? ??
        base.hero.secondaryCtaLabel,
    secondaryCtaPath: heroMap['secondaryCtaPath'] as String? ??
        base.hero.secondaryCtaPath,
    tertiaryCtaLabel: heroMap['tertiaryCtaLabel'] as String? ??
        base.hero.tertiaryCtaLabel,
    tertiaryCtaPath: heroMap['tertiaryCtaPath'] as String? ??
        base.hero.tertiaryCtaPath,
    backgroundImageUrl: heroMap['backgroundImageUrl'] as String? ??
        heroMap['background_image_url'] as String? ??
        content['backgroundImageUrl'] as String? ??
        content['background_image_url'] as String? ??
        overlay.backgroundImageUrl ??
        base.hero.backgroundImageUrl,
    backgroundVideoUrl: heroMap['backgroundVideoUrl'] as String? ??
        heroMap['background_video_url'] as String? ??
        content['backgroundVideoUrl'] as String? ??
        content['background_video_url'] as String? ??
        overlay.backgroundVideoUrl ??
        base.hero.backgroundVideoUrl,
  );

  final body = overlay.body?.trim();
  final introDescription = (introMap['description'] as String?)?.trim() ??
      ((body != null && body.isNotEmpty) ? body : null);
  final intro = AboutIntroContent(
    description: (introDescription != null && introDescription.isNotEmpty)
        ? introDescription
        : base.intro.description,
    yearsOperating: (introMap['yearsOperating'] as num?)?.toInt() ??
        (content['yearsOperating'] as num?)?.toInt() ??
        base.intro.yearsOperating,
    specializations: _parseIntroTags(
          introMap['specializations'] ?? content['specializations'],
        ) ??
        base.intro.specializations,
    geographicPresence: _stringList(
          introMap['geographicPresence'] ?? content['geographicPresence'],
        ) ??
        base.intro.geographicPresence,
    achievements: _parseIntroStats(
          introMap['achievements'] ?? content['achievements'],
        ) ??
        base.intro.achievements,
    philosophy: (introMap['philosophy'] as String?)?.trim().isNotEmpty == true
        ? introMap['philosophy'] as String
        : ((content['philosophy'] as String?)?.trim().isNotEmpty == true
            ? content['philosophy'] as String
            : base.intro.philosophy),
    imageUrl: (introMap['imageUrl'] as String?)?.trim().isNotEmpty == true
        ? introMap['imageUrl'] as String
        : ((content['introImageUrl'] as String?)?.trim().isNotEmpty == true
            ? content['introImageUrl'] as String
            : base.intro.imageUrl),
  );

  final mission = (content['mission'] as String?)?.trim();
  final vision = (content['vision'] as String?)?.trim();

  final storyRaw = content['story'];
  List<AboutStoryChapter>? story;
  if (storyRaw is List && storyRaw.isNotEmpty) {
    story = [
      for (final raw in storyRaw)
        if (raw is Map)
          AboutStoryChapter(
            year: '${raw['year'] ?? ''}',
            title: '${raw['title'] ?? ''}',
            body: '${raw['body'] ?? raw['description'] ?? ''}',
            summary: (raw['summary'] as String?)?.trim(),
            imageUrl: (raw['imageUrl'] as String?)?.trim() ??
                (raw['image_url'] as String?)?.trim(),
            highlights: raw['highlights'] is List
                ? (raw['highlights'] as List)
                    .map((e) => '$e'.trim())
                    .where((e) => e.isNotEmpty)
                    .toList()
                : const [],
            features: _parseStoryFeatures(raw['features']),
          ),
    ];
  }

  final executive = _parseExecutiveVideo(
        content['executiveVideo'] ?? content['executive_video'],
      ) ??
      base.executiveVideo;

  return AboutCmsContent(
    hero: hero,
    intro: intro,
    story: story ?? const [],
    vision: (vision != null && vision.isNotEmpty) ? vision : base.vision,
    mission: (mission != null && mission.isNotEmpty) ? mission : base.mission,
    values: base.values,
    timeline: base.timeline,
    leadership: base.leadership,
    whyChoose: base.whyChoose,
    services: base.services,
    awards: base.awards,
    partners: base.partners,
    csr: base.csr,
    sustainability: base.sustainability,
    process: base.process,
    stats: base.stats,
    offices: base.offices,
    careers: base.careers,
    testimonials: base.testimonials,
    executiveVideo: executive,
    milestoneMap: const [],
    companyProfile: base.companyProfile,
    trustCenter: base.trustCenter,
    cta: base.cta,
  );
}

AboutExecutiveVideo? _parseExecutiveVideo(dynamic raw) {
  if (raw is! Map) return null;
  final map = Map<String, dynamic>.from(raw);
  final message = '${map['message'] ?? ''}'.trim();
  final name =
      '${map['speakerName'] ?? map['name'] ?? ''}'.trim();
  final title =
      '${map['speakerTitle'] ?? map['title'] ?? ''}'.trim();
  final videoUrl =
      (map['videoUrl'] ?? map['video_url'])?.toString().trim();
  final thumbnailUrl =
      (map['thumbnailUrl'] ?? map['thumbnail_url'])?.toString().trim();
  if (message.isEmpty && name.isEmpty && (videoUrl == null || videoUrl.isEmpty)) {
    return null;
  }
  return AboutExecutiveVideo(
    speakerName: name,
    speakerTitle: title,
    message: message,
    videoUrl: (videoUrl == null || videoUrl.isEmpty) ? null : videoUrl,
    thumbnailUrl:
        (thumbnailUrl == null || thumbnailUrl.isEmpty) ? null : thumbnailUrl,
  );
}

List<String>? _stringList(dynamic raw) {
  if (raw is! List || raw.isEmpty) return null;
  return raw.map((e) => '$e').where((e) => e.trim().isNotEmpty).toList();
}

List<AboutIntroTag>? _parseIntroTags(dynamic raw) {
  if (raw is! List || raw.isEmpty) return null;
  final tags = <AboutIntroTag>[];
  for (final item in raw) {
    if (item is Map) {
      final label = '${item['label'] ?? item['title'] ?? ''}'.trim();
      if (label.isEmpty) continue;
      tags.add(
        AboutIntroTag(
          label: label,
          iconName: '${item['iconName'] ?? item['icon'] ?? 'home'}'.trim(),
        ),
      );
    } else {
      final label = '$item'.trim();
      if (label.isEmpty) continue;
      tags.add(AboutIntroTag(label: label, iconName: _defaultSpecIcon(label)));
    }
  }
  return tags.isEmpty ? null : tags;
}

List<AboutIntroStat>? _parseIntroStats(dynamic raw) {
  if (raw is! List || raw.isEmpty) return null;
  final stats = <AboutIntroStat>[];
  for (final item in raw) {
    if (item is Map) {
      final value = '${item['value'] ?? ''}'.trim();
      final label = '${item['label'] ?? item['title'] ?? ''}'.trim();
      if (value.isEmpty && label.isEmpty) continue;
      stats.add(
        AboutIntroStat(
          value: value.isNotEmpty ? value : label,
          label: value.isNotEmpty ? label : '',
          iconName: '${item['iconName'] ?? item['icon'] ?? 'building'}'.trim(),
        ),
      );
    } else {
      final text = '$item'.trim();
      if (text.isEmpty) continue;
      final parts = text.split(RegExp(r'\s+'));
      if (parts.length >= 2 && RegExp(r'[\d+]').hasMatch(parts.first)) {
        stats.add(
          AboutIntroStat(
            value: parts.first,
            label: parts.skip(1).join(' '),
            iconName: 'building',
          ),
        );
      } else {
        stats.add(
          AboutIntroStat(value: text, label: '', iconName: 'building'),
        );
      }
    }
  }
  return stats.isEmpty ? null : stats;
}

String _defaultSpecIcon(String label) {
  final lower = label.toLowerCase();
  if (lower.contains('residential') || lower.contains('home')) return 'home';
  if (lower.contains('estate plan') || lower.contains('blueprint')) {
    return 'pen_tool';
  }
  if (lower.contains('investment')) return 'building';
  if (lower.contains('construction')) return 'hard_hat';
  return 'home';
}

List<AboutStoryFeature> _parseStoryFeatures(dynamic raw) {
  if (raw is! List || raw.isEmpty) return const [];
  return [
    for (final item in raw)
      if (item is Map)
        AboutStoryFeature(
          title: '${item['title'] ?? ''}'.trim(),
          description: '${item['description'] ?? item['body'] ?? ''}'.trim(),
          iconName: '${item['iconName'] ?? item['icon'] ?? 'star'}'.trim(),
        )
      else if ('$item'.trim().isNotEmpty)
        AboutStoryFeature(
          title: '$item'.trim(),
          description: '',
          iconName: 'star',
        ),
  ].where((f) => f.title.isNotEmpty).toList();
}
