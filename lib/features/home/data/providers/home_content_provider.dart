import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/constants/brand_copy.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/home/data/mappers/home_cms_section_mapper.dart';
import 'package:hdhomesproject/features/home/data/models/home_cms_content.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Homepage CMS content. Published Supabase rows are the public source.
/// Local fallbacks stay empty for articles, events, downloads, and leadership
/// quotes so unpublished modules do not invent people or activity.
///
/// When Supabase is configured, featured estates/properties never fall back
/// to demo cards — admin edits are the source of truth for the public site.
final homeContentProvider = Provider<HomeCmsContent>((ref) {
  ref.watch(homepageHeroRealtimeProvider);
  ref.watch(homepageFeaturedRealtimeProvider);
  ref.watch(homepageContentRealtimeProvider);
  ref.watch(partnersRealtimeProvider);
  ref.watch(companyStatsRealtimeProvider);
  final base = fallbackHomeCmsContent;
  final configured = ref.watch(supabaseConfiguredProvider);
  final published = ref.watch(publishedHomepageHeroProvider).valueOrNull;
  final featuredEstatesAsync = ref.watch(publishedFeaturedEstatesProvider);
  final featuredPropertiesAsync = ref.watch(
    publishedFeaturedPropertiesProvider,
  );
  final testimonialsAsync = ref.watch(publishedTestimonialsProvider);
  final awardsAsync = ref.watch(publishedAwardsProvider);
  final partnersHomeAsync = ref.watch(publishedPartnersHomeProvider);
  final companyStatsHomeAsync = ref.watch(publishedCompanyStatsHomeProvider);
  final faqsAsync = ref.watch(publishedFaqsProvider);
  final blogsAsync = ref.watch(publishedBlogsProvider);
  final bannersAsync = ref.watch(publishedActiveBannersProvider);
  final sectionsAsync = ref.watch(publishedHomepageSectionsProvider);

  String pathOr(String? value, String fallback) {
    final v = value?.trim();
    if (v == null || v.isEmpty) return fallback;
    return v;
  }

  final hero = published == null
      ? base.hero
      : base.hero.copyWith(
          headline: published.headline.trim().isEmpty
              ? base.hero.headline
              : published.headline.trim(),
          subheadline: (published.subheadline ?? '').trim().isEmpty
              ? base.hero.subheadline
              : published.subheadline!.trim(),
          primaryCtaLabel: pathOr(
            published.ctaLabel,
            base.hero.primaryCtaLabel,
          ),
          primaryCtaPath: pathOr(published.ctaUrl, base.hero.primaryCtaPath),
          secondaryCtaLabel: pathOr(
            published.secondaryCtaLabel,
            base.hero.secondaryCtaLabel,
          ),
          secondaryCtaPath: pathOr(
            published.secondaryCtaUrl,
            base.hero.secondaryCtaPath,
          ),
          backgroundImageUrl: published.backgroundUrl,
          backgroundVideoUrl: published.videoUrl,
          overlayOpacity: published.overlayOpacity,
          clearImage: (published.backgroundUrl ?? '').isEmpty,
          clearVideo: (published.videoUrl ?? '').isEmpty,
        );

  final List<HomeEstateItem> estates;
  if (!configured) {
    estates = base.estates;
  } else if (featuredEstatesAsync.hasValue) {
    estates = featuredEstatesAsync.requireValue.map(_mapEstate).toList();
  } else {
    estates = const [];
  }

  final List<HomePropertyItem> properties;
  if (!configured) {
    properties = base.properties;
  } else if (featuredPropertiesAsync.hasValue) {
    properties = featuredPropertiesAsync.requireValue
        .map(_mapProperty)
        .toList();
  } else {
    properties = const [];
  }

  final List<HomeTestimonialItem> testimonials;
  if (!configured) {
    testimonials = base.testimonials;
  } else if (testimonialsAsync.hasValue) {
    testimonials = testimonialsAsync.requireValue.map(_mapTestimonial).toList();
  } else {
    testimonials = const [];
  }

  final List<HomeAwardItem> awards;
  if (!configured) {
    awards = base.awards;
  } else if (awardsAsync.hasValue && awardsAsync.requireValue.isNotEmpty) {
    awards = awardsAsync.requireValue.map(_mapAward).toList();
  } else {
    awards = const [];
  }

  final List<HomePartnerItem> partners;
  if (!configured) {
    partners = base.partners;
  } else if (partnersHomeAsync.hasValue &&
      partnersHomeAsync.requireValue.isNotEmpty) {
    partners = partnersHomeAsync.requireValue.map(_mapPartner).toList();
  } else {
    partners = const [];
  }

  final List<HomeStatItem> stats;
  if (!configured) {
    stats = base.stats;
  } else if (companyStatsHomeAsync.hasValue &&
      companyStatsHomeAsync.requireValue.isNotEmpty) {
    stats = companyStatsHomeAsync.requireValue.map(_mapCompanyStat).toList();
  } else {
    stats = const [];
  }

  final List<HomeFaqItem> faqs;
  if (!configured) {
    faqs = base.faqs;
  } else if (faqsAsync.hasValue) {
    faqs = faqsAsync.requireValue.map(_mapFaq).toList();
  } else {
    faqs = const [];
  }

  final List<HomeBlogItem> blogPosts;
  if (!configured) {
    blogPosts = base.blogPosts;
  } else if (blogsAsync.hasValue) {
    blogPosts = blogsAsync.requireValue.map(_mapBlog).toList();
  } else {
    blogPosts = const [];
  }

  final announcement = (!configured || !bannersAsync.hasValue)
      ? base.announcement
      : (bannersAsync.requireValue.isEmpty
            ? ''
            : bannersAsync.requireValue.first.title);

  // Section visibility + order from cms_sections.
  // Public RLS returns all homepage_* rows (incl. hidden) so we can honor toggles.
  final visibility = <String, bool>{};
  var sectionOrder = const <String>[];
  var sections = const <CmsSectionRecord>[];
  if (configured && sectionsAsync.hasValue) {
    sections = sectionsAsync.requireValue;
    for (final s in sections) {
      visibility[s.sectionKey] = s.isVisible;
    }
    sectionOrder = [
      for (final s in sections)
        if (s.sectionKey.startsWith('homepage_')) s.sectionKey,
    ];
  }

  final mergedBase = HomeCmsContent(
    announcement: announcement,
    hero: hero,
    stats: stats,
    about: base.about,
    whyChoose: base.whyChoose,
    lifestyles: base.lifestyles,
    estates: estates,
    properties: properties,
    investments: base.investments,
    testimonials: testimonials,
    partners: partners,
    awards: awards,
    blogPosts: blogPosts,
    marketInsights: base.marketInsights,
    events: base.events,
    faqs: faqs,
    downloads: base.downloads,
    liveActivities: base.liveActivities,
    executiveWelcome: configured
        ? const HomeExecutiveWelcome(
            name: '',
            title: '',
            message: '',
            videoUrl: null,
          )
        : base.executiveWelcome,
    cta: base.cta,
    sectionVisibility: visibility,
    sectionOrder: sectionOrder,
  );

  return mergeHomepageSectionContent(base: mergedBase, sections: sections);
});

HomeEstateItem _mapEstate(CmsEstateSummary e) => HomeEstateItem(
  id: e.id,
  name: e.name,
  location: e.location.isNotEmpty ? e.location : 'Nigeria',
  propertyCount: e.propertyCount,
  priceFrom: (e.priceFromLabel?.trim().isNotEmpty ?? false)
      ? e.priceFromLabel!.trim()
      : 'Price on request',
  status: e.displayStatus,
  imageUrl: e.coverImageUrl,
  route: '${RoutePaths.estates}/${e.slug}',
);

HomePropertyItem _mapProperty(CmsPropertyFeatured p) => HomePropertyItem(
  id: p.id,
  title: p.title,
  price: p.displayPrice,
  location: p.location.isNotEmpty ? p.location : 'Nigeria',
  bedrooms: p.bedrooms?.round() ?? 0,
  bathrooms: p.bathrooms?.round() ?? 0,
  landSize: p.landSizeLabel,
  type: p.propertyType ?? 'Property',
  status: p.displayStatus,
  imageUrl: p.coverImageUrl,
  route: '${RoutePaths.properties}/${p.slug}',
);

HomeTestimonialItem _mapTestimonial(CmsTestimonial t) => HomeTestimonialItem(
  name: t.clientName,
  role: t.clientTitle ?? 'Client',
  quote: t.content,
  rating: (t.rating ?? 5).toDouble(),
  verified: true,
  avatarUrl: t.avatarUrl,
);

HomeAwardItem _mapAward(CmsAward a) => HomeAwardItem(
  title: a.title,
  year: a.year,
  issuer: a.issuer,
  description: a.description,
  iconName: a.iconName,
);

HomePartnerItem _mapPartner(CmsPartner p) => HomePartnerItem(
  name: p.name,
  category: p.category,
  tagline: p.tagline,
  logoUrl: p.logoUrl,
  iconName: p.iconName,
);

HomeStatItem _mapCompanyStat(CmsCompanyStat s) => HomeStatItem(
  value: s.value,
  label: s.label,
  suffix: s.suffix.isEmpty ? null : s.suffix,
  caption: s.description.isEmpty ? null : s.description,
  description: s.description,
  iconName: s.iconName,
  logoUrl: s.logoUrl,
  placement: s.placement,
);

HomeFaqItem _mapFaq(CmsFaq f) =>
    HomeFaqItem(question: f.question, answer: f.answer);

HomeBlogItem _mapBlog(CmsBlogPost b) => HomeBlogItem(
  title: b.title,
  category: b.featured ? 'Featured' : 'Blog',
  excerpt: b.excerpt ?? '',
  route: '${RoutePaths.blog}/${b.slug}',
  date: b.publishedAt == null
      ? ''
      : '${b.publishedAt!.year}-${b.publishedAt!.month.toString().padLeft(2, '0')}',
  coverImageUrl: b.coverImageUrl,
  featured: b.featured,
);

void _invalidateLater(Ref ref, List<ProviderOrFamily> providers) {
  Future.microtask(() {
    try {
      for (final provider in providers) {
        ref.invalidate(provider);
      }
    } catch (_) {}
  });
}

/// Soft realtime: when Supabase is configured, keep published hero fresh.
final homepageHeroRealtimeProvider = Provider<void>((ref) {
  ref.keepAlive();
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = ref.watch(supabaseClientProvider);
  final channel = client.channel('public-homepage-hero');
  channel.onPostgresChanges(
    event: PostgresChangeEvent.all,
    schema: 'public',
    table: 'hero_sections',
    callback: (_) =>
        _invalidateLater(ref, [publishedHomepageHeroProvider, cmsHeroProvider]),
  );
  channel.subscribe();
  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

/// Soft realtime for featured estates/properties (+ their cover images).
final homepageFeaturedRealtimeProvider = Provider<void>((ref) {
  ref.keepAlive();
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = ref.watch(supabaseClientProvider);
  final channel = client.channel('public-homepage-featured');

  void refresh() {
    _invalidateLater(ref, [
      publishedFeaturedEstatesProvider,
      publishedFeaturedPropertiesProvider,
    ]);
  }

  for (final table in const [
    'estates',
    'estate_images',
    'properties',
    'property_images',
    'property_pricing',
    'property_locations',
  ]) {
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: table,
      callback: (_) => refresh(),
    );
  }
  channel.subscribe();
  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

/// Soft realtime for testimonials, FAQs, banners, homepage sections.
/// Blog rows are owned by [blogCmsRealtimeProvider] (tick, not invalidate).
final homepageContentRealtimeProvider = Provider<void>((ref) {
  ref.keepAlive();
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = ref.watch(supabaseClientProvider);
  final channel = client.channel('public-homepage-content');

  void refresh() {
    _invalidateLater(ref, [
      publishedTestimonialsProvider,
      publishedAwardsProvider,
      publishedPartnersHomeProvider,
      publishedCompanyStatsHomeProvider,
      publishedFaqsProvider,
      publishedActiveBannersProvider,
      publishedMenuSectionsProvider,
      publishedFooterSectionsProvider,
      publishedHomepageSectionsProvider,
      cmsHomepageSectionsProvider,
      cmsMenuSectionsProvider,
      cmsFooterSectionsProvider,
      cmsTestimonialsProvider,
      cmsAwardsProvider,
      cmsPartnersProvider,
      cmsCompanyStatsProvider,
      cmsFaqsProvider,
      cmsBannersProvider,
    ]);
  }

  for (final table in const [
    'testimonials',
    'awards',
    'partners',
    'company_statistics',
    'faqs',
    'banners',
    'cms_sections',
  ]) {
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: table,
      callback: (_) => refresh(),
    );
  }
  channel.subscribe();
  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

const fallbackHomeCmsContent = HomeCmsContent(
  announcement:
      'New estate launch — Horizon Gardens. Limited units with flexible payment plans.',
  hero: HomeHeroContent(
    headline: 'Building Exceptional Homes.\nCreating Lasting Value.',
    subheadline:
        'Premium real estate development and investment opportunities across Nigeria.',
    primaryCtaLabel: 'Explore Properties',
    primaryCtaPath: RoutePaths.properties,
    secondaryCtaLabel: 'Contact Hub',
    secondaryCtaPath: RoutePaths.contact,
    tertiaryCtaLabel: 'Become an Investor',
    tertiaryCtaPath: RoutePaths.investment,
  ),
  stats: [
    HomeStatItem(
      value: 15,
      label: 'Years of Excellence',
      suffix: '+',
      caption: 'Proven track record',
      iconName: 'calendar',
    ),
    HomeStatItem(
      value: 3200,
      label: 'Homes Delivered',
      suffix: '+',
      caption: 'Across prime locations',
      iconName: 'home',
    ),
    HomeStatItem(
      value: 250,
      label: 'Investment Portfolio',
      suffix: 'B+',
      caption: 'Assets under development',
      iconName: 'coins',
    ),
    HomeStatItem(
      value: 12000,
      label: 'Happy Clients',
      suffix: '+',
      caption: 'And growing every day',
      iconName: 'users',
    ),
    HomeStatItem(
      value: 850,
      label: 'Investors',
      suffix: '+',
      caption: 'Growing with us',
      iconName: 'user',
    ),
    HomeStatItem(
      value: 18,
      label: 'Active Construction',
      suffix: '+',
      caption: 'Ongoing projects',
      iconName: 'crane',
    ),
    HomeStatItem(
      value: 98,
      label: 'Customer Satisfaction',
      suffix: '%',
      caption: 'We care about you',
      iconName: 'star',
    ),
    HomeStatItem(
      value: 12,
      label: 'Estates Developed',
      suffix: '+',
      caption: 'Prime locations',
      iconName: 'globe',
    ),
  ],
  about: HomeAboutContent(
    title: BrandCopy.aboutTitle,
    titleAccent: BrandCopy.aboutTitleAccent,
    story: BrandCopy.story,
    mission: BrandCopy.mission,
    vision: BrandCopy.vision,
    values: BrandCopy.coreValueLabels,
    highlights: [
      HomeAboutHighlight(
        title: 'Registered Corporate Developer',
        description:
            'Legally registered and fully compliant real estate development company.',
        iconName: 'badge',
      ),
      HomeAboutHighlight(
        title: 'Strategic Locations Nationwide',
        description:
            'Our projects are located in high-growth areas across Nigeria.',
        iconName: 'map_pin',
      ),
      HomeAboutHighlight(
        title: 'Flexible Payment Structures',
        description:
            'We offer convenient and affordable payment plans for everyone.',
        iconName: 'wallet',
      ),
      HomeAboutHighlight(
        title: 'Investor-Grade Project Delivery',
        description:
            'We deliver high-value projects that guarantee excellent returns on investment.',
        iconName: 'hard_hat',
      ),
    ],
    ctaLabel: 'Learn More',
    ctaPath: RoutePaths.about,
    backgroundImageUrl: '',
  ),
  whyChoose: [
    HomeWhyChooseItem(
      title: 'Trusted Developer',
      description: 'Verified track record with transparent delivery.',
      iconName: 'shield',
    ),
    HomeWhyChooseItem(
      title: 'Quality Construction',
      description: 'Premium materials and rigorous quality control.',
      iconName: 'hard_hat',
    ),
    HomeWhyChooseItem(
      title: 'Flexible Payment Plans',
      description: 'Structured plans designed for every budget.',
      iconName: 'wallet',
    ),
    HomeWhyChooseItem(
      title: 'Strategic Locations',
      description: 'Developments in high-growth corridors.',
      iconName: 'map_pin',
    ),
    HomeWhyChooseItem(
      title: 'Excellent ROI',
      description: 'Investment products with strong appreciation.',
      iconName: 'trending_up',
    ),
    HomeWhyChooseItem(
      title: 'Dedicated Support',
      description: 'End-to-end client and investor care.',
      iconName: 'headphones',
    ),
  ],
  lifestyles: [
    HomeLifestyleItem(
      label: 'Family Living',
      description: 'Spacious homes for growing families',
      route: RoutePaths.properties,
    ),
    HomeLifestyleItem(
      label: 'Luxury Living',
      description: 'Premium finishes and exclusive addresses',
      route: RoutePaths.properties,
    ),
    HomeLifestyleItem(
      label: 'Waterfront Living',
      description: 'Scenic coastal and lakeside estates',
      route: RoutePaths.estates,
    ),
    HomeLifestyleItem(
      label: 'Investment',
      description: 'High-yield opportunities',
      route: RoutePaths.investment,
    ),
    HomeLifestyleItem(
      label: 'Retirement',
      description: 'Peaceful, secure communities',
      route: RoutePaths.properties,
    ),
  ],
  estates: [
    HomeEstateItem(
      id: '1',
      name: 'Horizon Gardens',
      location: 'Lekki, Lagos',
      propertyCount: 240,
      priceFrom: '₦45M',
      status: 'Selling Fast',
      imageUrl: null,
      route: RoutePaths.estates,
    ),
    HomeEstateItem(
      id: '2',
      name: 'Emerald Heights',
      location: 'Abuja',
      propertyCount: 180,
      priceFrom: '₦38M',
      status: 'New Launch',
      imageUrl: null,
      route: RoutePaths.estates,
    ),
    HomeEstateItem(
      id: '3',
      name: 'Palm Grove Estate',
      location: 'Port Harcourt',
      propertyCount: 96,
      priceFrom: '₦28M',
      status: 'Ready to Move',
      imageUrl: null,
      route: RoutePaths.estates,
    ),
  ],
  properties: [
    HomePropertyItem(
      id: '1',
      title: '4-Bedroom Duplex',
      price: '₦68M',
      location: 'Horizon Gardens, Lekki',
      bedrooms: 4,
      bathrooms: 5,
      landSize: '450 sqm',
      type: 'Duplex',
      status: 'Available',
      imageUrl: null,
      route: RoutePaths.properties,
    ),
    HomePropertyItem(
      id: '2',
      title: '3-Bedroom Terrace',
      price: '₦42M',
      location: 'Emerald Heights, Abuja',
      bedrooms: 3,
      bathrooms: 4,
      landSize: '320 sqm',
      type: 'Terrace',
      status: 'New',
      imageUrl: null,
      route: RoutePaths.properties,
    ),
    HomePropertyItem(
      id: '3',
      title: 'Luxury Penthouse',
      price: '₦125M',
      location: 'Victoria Island, Lagos',
      bedrooms: 5,
      bathrooms: 6,
      landSize: '580 sqm',
      type: 'Penthouse',
      status: 'Premium',
      imageUrl: null,
      route: RoutePaths.properties,
    ),
  ],
  investments: [
    HomeInvestmentItem(
      title: 'Horizon Gardens Fund',
      roi: '18–22%',
      type: 'Estate Development',
      duration: '24 months',
      risk: 'Moderate',
      growth: 'High',
      route: RoutePaths.investment,
    ),
    HomeInvestmentItem(
      title: 'Commercial Yield Portfolio',
      roi: '14–16%',
      type: 'Commercial',
      duration: '36 months',
      risk: 'Low',
      growth: 'Stable',
      route: RoutePaths.investment,
    ),
  ],
  testimonials: [
    HomeTestimonialItem(
      name: 'Adaeze O.',
      role: 'Homeowner',
      quote:
          'HD Homes made our dream home a reality with complete transparency throughout.',
      rating: 5,
      verified: true,
    ),
    HomeTestimonialItem(
      name: 'Chukwuemeka I.',
      role: 'Investor',
      quote:
          'Their investor portal and regular updates gave me confidence to diversify.',
      rating: 5,
      verified: true,
    ),
    HomeTestimonialItem(
      name: 'Fatima B.',
      role: 'Partner Architect',
      quote:
          'A professional team that values quality and timely collaboration.',
      rating: 5,
      verified: true,
    ),
    HomeTestimonialItem(
      name: 'Tunde A.',
      role: 'Diaspora Buyer',
      quote:
          'From London I tracked every milestone. Delivery matched the promise.',
      rating: 5,
      verified: true,
    ),
    HomeTestimonialItem(
      name: 'Ngozi E.',
      role: 'Homeowner',
      quote:
          'The documentation, site visits, and aftercare felt premium end to end.',
      rating: 5,
      verified: true,
    ),
  ],
  partners: [
    HomePartnerItem(
      name: 'FirstBank',
      category: 'Banking',
      tagline: 'Since 1894',
      iconName: 'landmark',
    ),
    HomePartnerItem(name: 'GTBank', category: 'Banking', iconName: 'landmark'),
    HomePartnerItem(
      name: 'BuildRight Contractors',
      category: 'Construction',
      iconName: 'hardHat',
    ),
    HomePartnerItem(
      name: 'NIESV',
      category: 'Professional Body',
      iconName: 'shield',
    ),
    HomePartnerItem(
      name: 'Lagos State Ministry',
      category: 'Government',
      iconName: 'badge',
    ),
    HomePartnerItem(
      name: 'SurveyPro Ltd',
      category: 'Surveying',
      iconName: 'compass',
    ),
  ],
  awards: [
    HomeAwardItem(
      title: 'Excellence in Housing Development',
      year: '2025',
      issuer: 'Nigeria Property Awards',
      description: 'Recognised for quality delivery and client satisfaction.',
      iconName: 'award',
    ),
    HomeAwardItem(
      title: 'Best Customer Experience',
      year: '2024',
      issuer: 'PropTech Nigeria',
      description: 'PropTech innovation in client engagement.',
      iconName: 'star',
    ),
    HomeAwardItem(
      title: 'CAC Corporate Registration',
      year: '2011',
      issuer: 'Corporate Affairs Commission',
      description: 'Fully registered corporate entity.',
      iconName: 'badge',
    ),
  ],
  blogPosts: [],
  marketInsights: [],
  events: [],
  faqs: [],
  downloads: [],
  liveActivities: [],
  executiveWelcome: HomeExecutiveWelcome(
    name: '',
    title: '',
    message: '',
    videoUrl: null,
  ),
);
