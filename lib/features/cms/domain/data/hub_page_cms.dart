import 'package:hdhomesproject/core/constants/brand_copy.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';

/// Shared helpers for overlaying published `pages` content onto public hubs.
class HubPageHeroOverlay {
  const HubPageHeroOverlay({
    this.headline,
    this.subheadline,
    this.primaryCtaLabel,
    this.secondaryCtaLabel,
    this.body,
    this.backgroundImageUrl,
    this.backgroundVideoUrl,
  });

  final String? headline;
  final String? subheadline;
  final String? primaryCtaLabel;
  final String? secondaryCtaLabel;
  final String? body;
  final String? backgroundImageUrl;
  final String? backgroundVideoUrl;

  bool get isEmpty =>
      headline == null &&
      subheadline == null &&
      primaryCtaLabel == null &&
      secondaryCtaLabel == null &&
      body == null &&
      backgroundImageUrl == null &&
      backgroundVideoUrl == null;
}

/// Reads hero / body fields from a published CMS page (flat or nested `hero`).
HubPageHeroOverlay hubHeroFromPage(CmsPageRecord? page) {
  if (page == null) return const HubPageHeroOverlay();
  final content = page.content;
  final heroMap = content['hero'] is Map
      ? Map<String, dynamic>.from(content['hero'] as Map)
      : const <String, dynamic>{};

  String? pick(List<String> keys) {
    for (final key in keys) {
      final fromHero = heroMap[key];
      if (fromHero is String && fromHero.trim().isNotEmpty) {
        return fromHero.trim();
      }
      final fromRoot = content[key];
      if (fromRoot is String && fromRoot.trim().isNotEmpty) {
        return fromRoot.trim();
      }
    }
    return null;
  }

  final body = pick(const ['body', 'html', 'description']);
  // Do not fall back to page.title / meta — hubs keep curated copy unless
  // explicit hero fields are stored in content.
  final headline = pick(const ['heroHeadline', 'headline']);
  final subheadline =
      pick(const ['heroSubheadline', 'subheadline', 'subtitle']);

  return HubPageHeroOverlay(
    headline: headline,
    subheadline: subheadline,
    primaryCtaLabel: pick(const ['primaryCtaLabel', 'ctaLabel', 'cta_label']),
    secondaryCtaLabel:
        pick(const ['secondaryCtaLabel', 'secondary_label']),
    body: body,
    backgroundImageUrl: pick(const [
      'backgroundImageUrl',
      'background_image_url',
      'background_url',
    ]),
    backgroundVideoUrl: pick(const [
      'backgroundVideoUrl',
      'background_video_url',
      'video_url',
      'videoUrl',
    ]),
  );
}

/// Slugs that drive public hub heroes (Admin → Website → Pages).
const kPublicHubSlugs = <String>{
  'properties',
  'estates',
  'services',
  'contact',
  'gallery',
  'trust',
  'investment',
  'careers',
  'search',
  'about',
  'blog',
};

/// Default published hub pages seeded for Admin → Website → Pages.
const kPublicHubPageSeeds = <Map<String, dynamic>>[
  {
    'title': 'Properties Marketplace',
    'slug': 'properties',
    'meta_title': 'Properties | HD Homes',
    'meta_description': 'Browse premium properties across Nigeria.',
    'content': {
      'heroHeadline': 'Find Your Perfect Property',
      'heroSubheadline':
          'Discover premium homes, commercial spaces, land, and investment opportunities across Nigeria.',
      'primaryCtaLabel': 'Browse All',
      'secondaryCtaLabel': 'Investment Properties',
    },
  },
  {
    'title': 'Estates',
    'slug': 'estates',
    'meta_title': 'Estates | HD Homes',
    'meta_description': 'Explore HD Homes estates across Nigeria.',
    'content': {
      'heroHeadline': 'Explore Our Estates',
      'heroSubheadline':
          'Master-planned communities designed for lifestyle, growth, and lasting value.',
      'primaryCtaLabel': 'View Estates',
    },
  },
  {
    'title': 'Services',
    'slug': 'services',
    'meta_title': 'Services | HD Homes',
    'meta_description': 'HD Homes real estate services.',
    'content': {
      'heroHeadline': 'Building Exceptional Spaces. Delivering Enduring Value.',
      'heroSubheadline':
          'From property sales and estate development to construction, investment advisory, and after-sales care — one premium team.',
      'primaryCtaLabel': 'Explore Services',
      'secondaryCtaLabel': 'Book Consultation',
      'backgroundImageUrl':
          '',
    },
  },
  {
    'title': 'Contact',
    'slug': 'contact',
    'meta_title': 'Contact | HD Homes',
    'meta_description': 'Contact HD Homes.',
    'content': {
      'heroHeadline': "We're Here to Help You Build Your Future.",
      'heroSubheadline':
          'Reach HD Homes through any channel — sales, inspections, investments, partnerships, and support.',
      'primaryCtaLabel': 'Book Inspection',
    },
  },
  {
    'title': 'Gallery',
    'slug': 'gallery',
    'meta_title': 'Gallery | HD Homes',
    'meta_description': 'HD Homes media gallery.',
    'content': {
      'heroHeadline': 'Experience Properties Before You Visit.',
      'heroSubheadline':
          'Immersive galleries, 360° tours, drone footage, floor plans, and virtual open houses.',
      'primaryCtaLabel': 'View Gallery',
    },
  },
  {
    'title': 'Trust Center',
    'slug': 'trust',
    'meta_title': 'Trust | HD Homes',
    'meta_description': 'HD Homes trust and compliance center.',
    'content': {
      'heroHeadline': 'Built on Trust. Driven by Integrity.',
      'heroSubheadline':
          'Transparency, compliance, and investor protection — centralized.',
      'primaryCtaLabel': 'Learn More',
    },
  },
  {
    'title': 'Investment',
    'slug': 'investment',
    'meta_title': 'Investment | HD Homes',
    'meta_description': 'Invest with HD Homes.',
    'content': {
      'heroHeadline': 'Grow Your Wealth Through Nigerian Real Estate.',
      'heroSubheadline':
          'Structured products, transparent reporting, and institutional-grade developments.',
      'primaryCtaLabel': 'Invest With Us',
      'opportunitiesOverline': 'OPPORTUNITIES',
      'opportunitiesTitle': 'Current investment opportunities',
      'opportunitiesSubtitle':
          'Off-plan, rental income, land banking, commercial, and fractional products.',
      'marketInsightsOverline': 'MARKET',
      'marketInsightsTitle': 'Market insights',
      'marketInsightsSubtitle':
          'Data-driven outlook across key Nigerian corridors.',
    },
  },
  {
    'title': 'Careers',
    'slug': 'careers',
    'meta_title': 'Careers | HD Homes',
    'meta_description': 'Careers at HD Homes.',
    'content': {
      'heroHeadline': 'Build the Future of Nigerian Housing.',
      'heroSubheadline':
          'Join HD Homes — a premium PropTech developer shaping estates, communities, and careers.',
      'primaryCtaLabel': 'View Openings',
    },
  },
  {
    'title': 'Search',
    'slug': 'search',
    'meta_title': 'Search | HD Homes',
    'meta_description': 'Search HD Homes.',
    'content': {
      'heroHeadline': 'Find Your Perfect Property — Intelligently.',
      'heroSubheadline':
          'AI-powered search, lifestyle matching, map exploration, and personalized recommendations.',
      'primaryCtaLabel': 'Search',
    },
  },
  {
    'title': 'Blog',
    'slug': 'blog',
    'meta_title': 'Blog | HD Homes',
    'meta_description':
        'HD Homes knowledge hub — buying guides, investment insights, and company news.',
    'content': {
      'heroHeadline': 'Insights That Build Better Decisions.',
      'heroSubheadline':
          'Guides, market notes, and company news from the HD Homes team.',
      'primaryCtaLabel': 'Browse Articles',
      'secondaryCtaLabel': 'Talk to an Advisor',
      'backgroundImageUrl':
          '',
    },
  },
  {
    'title': 'About',
    'slug': 'about',
    'meta_title': 'About | HD Homes',
    'meta_description': 'About HD Homes.',
    'content': {
      'heroHeadline': BrandCopy.heroHeadlineFlat,
      'heroSubheadline': BrandCopy.heroSubheadline,
      'mission': BrandCopy.mission,
      'vision': BrandCopy.vision,
      'body': BrandCopy.story,
      'philosophy': BrandCopy.philosophy,
      'yearsOperating': 15,
      'introImageUrl':
          '',
      'intro': kDefaultAboutIntro,
      'story': kDefaultAboutStoryChapters,
      'executiveVideo': kDefaultAboutExecutiveVideo,
    },
  },
];

/// Legal / policy pages shown in Trust → Legal document center (`/pages/:slug`).
const kLegalPageSeeds = <Map<String, dynamic>>[
  {
    'title': 'Terms & Conditions',
    'slug': 'terms',
    'meta_title': 'Terms & Conditions | HD Homes',
    'meta_description': 'HD Homes terms of use and conditions of sale.',
    'content': {
      'heroHeadline': 'Terms & Conditions',
      'heroSubheadline':
          'The terms that govern use of HD Homes websites, products, and services.',
      'category': 'Legal',
      'body':
          'These terms apply to visitors, buyers, and investors using HD Homes digital channels. '
          'Contact legal@hdhomes.ng for the latest executed agreements.',
    },
  },
  {
    'title': 'Privacy Policy',
    'slug': 'privacy',
    'meta_title': 'Privacy Policy | HD Homes',
    'meta_description': 'How HD Homes collects, uses, and protects personal data.',
    'content': {
      'heroHeadline': 'Privacy Policy',
      'heroSubheadline': 'NDPR-aligned handling of personal information.',
      'category': 'Legal',
      'body':
          'HD Homes processes personal data to serve buyers, investors, and partners. '
          'We apply access controls, encryption, and documented retention practices.',
    },
  },
  {
    'title': 'Cookie Policy',
    'slug': 'cookies',
    'meta_title': 'Cookie Policy | HD Homes',
    'meta_description': 'How HD Homes uses cookies and similar technologies.',
    'content': {
      'heroHeadline': 'Cookie Policy',
      'heroSubheadline': 'How we use cookies to improve your experience.',
      'category': 'Legal',
      'body':
          'We use essential cookies to run the site and optional analytics cookies to improve performance. '
          'You can manage consent from the cookie banner.',
    },
  },
  {
    'title': 'Refund Policy',
    'slug': 'refund-policy',
    'meta_title': 'Refund Policy | HD Homes',
    'meta_description': 'HD Homes refund and cancellation policy.',
    'content': {
      'heroHeadline': 'Refund Policy',
      'heroSubheadline': 'How cancellations, refunds, and milestone payments are handled.',
      'category': 'Policy',
      'body':
          'Refund eligibility depends on the executed purchase or investment agreement and the payment milestone reached. '
          'Write to legal@hdhomes.ng with your contract reference.',
    },
  },
];

/// Default MD video message for About + Admin → Pages.
const kDefaultAboutExecutiveVideo = <String, dynamic>{
  'speakerName': 'Managing Director',
  'speakerTitle': 'Chief Executive Officer',
  'message':
      'Welcome to HD Homes. Our commitment is simple: build with integrity, deliver with excellence, and earn your trust every single day.',
  'videoUrl': null,
};

/// Default Company overview block for Home + Admin → Pages.
const kDefaultAboutIntro = <String, dynamic>{
  'description': BrandCopy.story,
  'yearsOperating': 15,
  'philosophy': BrandCopy.philosophy,
  'imageUrl':
      '',
  'specializations': [
    {'label': 'Residential Development', 'iconName': 'home'},
    {'label': 'Estate Planning', 'iconName': 'pen_tool'},
    {'label': 'Real Estate Investment', 'iconName': 'building'},
    {'label': 'Construction Management', 'iconName': 'hard_hat'},
  ],
  'geographicPresence': ['Lagos', 'Abuja', 'Port Harcourt', 'Enugu'],
  'achievements': [
    {'value': '48+', 'label': 'completed projects', 'iconName': 'building'},
    {'value': '12', 'label': 'flagship estates', 'iconName': 'award'},
    {'value': '850+', 'label': 'active investors', 'iconName': 'users'},
    {
      'value': 'CAC-registered',
      'label': 'developer',
      'iconName': 'badge',
    },
  ],
};

/// Default Our Story timeline used by public About + Admin → Pages editor.
const kDefaultAboutStoryChapters = <Map<String, dynamic>>[
  {
    'year': '2011',
    'title': 'The beginning',
    'summary': 'HD Homes was founded on a clear vision.',
    'body':
        'HD Homes was founded with a mission to bridge Nigeria\'s housing gap through quality, affordable developments.',
    'imageUrl':
        '',
    'features': [
      {
        'title': 'Clear Vision',
        'description': 'A founding brief to close Nigeria\'s housing gap.',
        'iconName': 'eye',
      },
      {
        'title': 'Quality First',
        'description': 'Homes built with integrity from day one.',
        'iconName': 'award',
      },
      {
        'title': 'Trusted Start',
        'description': 'Registered developer ready for delivery.',
        'iconName': 'shield',
      },
    ],
  },
  {
    'year': '2015',
    'title': 'First developments',
    'summary': 'Our first projects set the foundation for growth.',
    'body':
        'Delivered our first master-planned estate, establishing our reputation for transparent delivery and premium finishes.',
    'imageUrl':
        '',
    'features': [
      {
        'title': 'First Estate',
        'description': 'Master-planned community delivered with care.',
        'iconName': 'building',
      },
      {
        'title': 'Transparent Delivery',
        'description': 'Clear timelines, titles, and communication.',
        'iconName': 'file_check',
      },
      {
        'title': 'Premium Finishes',
        'description': 'Standards that set HD Homes apart.',
        'iconName': 'home',
      },
    ],
  },
  {
    'year': '2019',
    'title': 'Expanding Impact',
    'summary': 'More communities, more families, more value.',
    'body':
        'Expanded operations to Abuja and Port Harcourt, partnering with leading financial institutions.',
    'imageUrl':
        '',
    'features': [
      {
        'title': 'Multi-City Reach',
        'description': 'Lagos, Abuja, and Port Harcourt corridors.',
        'iconName': 'map',
      },
      {
        'title': 'More Families',
        'description': 'Broader access to quality housing.',
        'iconName': 'users',
      },
      {
        'title': 'Institutional Partners',
        'description': 'Finance partners that accelerate delivery.',
        'iconName': 'handshake',
      },
    ],
  },
  {
    'year': '2024',
    'title': 'Innovation & Growth',
    'summary': 'Embracing technology, raising new standards.',
    'body':
        'Launched digital client and investor portals, setting a new standard for transparency in Nigerian real estate.',
    'imageUrl':
        '',
    'features': [
      {
        'title': 'Client Portal',
        'description': 'Digital access to projects and payments.',
        'iconName': 'cpu',
      },
      {
        'title': 'Investor Tools',
        'description': 'Visibility into portfolio performance.',
        'iconName': 'trending_up',
      },
      {
        'title': 'Higher Standards',
        'description': 'PropTech transparency as the default.',
        'iconName': 'sparkles',
      },
    ],
  },
  {
    'year': '2026',
    'title': 'Looking Ahead',
    'summary': 'Building the future of sustainable living.',
    'body':
        'Scaling sustainable developments and smart-home communities across West Africa.',
    'imageUrl':
        '',
    'features': [
      {
        'title': 'More Communities',
        'description': 'Expanding to key cities across Africa.',
        'iconName': 'building',
      },
      {
        'title': 'Sustainable Living',
        'description': 'Eco-friendly builds for a better tomorrow.',
        'iconName': 'leaf',
      },
      {
        'title': 'Smart Homes',
        'description': 'Technology-driven living experiences.',
        'iconName': 'cpu',
      },
    ],
  },
];
