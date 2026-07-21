/// SEO metadata model for public pages (wired to CMS in later volumes).
class SeoMetadata {
  const SeoMetadata({
    required this.title,
    required this.description,
    this.canonicalUrl,
    this.ogImageUrl,
    this.keywords = const [],
    this.robots = 'index, follow',
    this.structuredData,
  });

  final String title;
  final String description;
  final String? canonicalUrl;
  final String? ogImageUrl;
  final List<String> keywords;
  final String robots;
  final Map<String, dynamic>? structuredData;

  static const home = SeoMetadata(
    title: 'HD Homes Limited | Making Quality Housing Accessible',
    description:
        'Premium real estate and property development in Nigeria. '
        'Discover luxury homes, estates, and investment opportunities with HD Homes.',
    keywords: ['real estate', 'property', 'Nigeria', 'HD Homes', 'estates'],
  );

  static const about = SeoMetadata(
    title: 'About HD Homes | Trusted Nigerian Property Developer',
    description:
        'Discover the HD Homes story — our vision, leadership, achievements, '
        'and commitment to quality housing and transparent real estate investment.',
    keywords: [
      'about HD Homes',
      'property developer Nigeria',
      'real estate company',
      'housing developer',
    ],
    structuredData: {
      '@context': 'https://schema.org',
      '@type': 'AboutPage',
      'name': 'About HD Homes Limited',
      'description': 'Corporate profile of HD Homes Ltd, a premium Nigerian property developer.',
    },
  );

  static const marketplace = SeoMetadata(
    title: 'Properties for Sale & Investment | HD Homes Marketplace',
    description:
        'Browse premium residential, commercial, and land properties across Nigeria. '
        'AI-powered search, filters, and investment scores.',
    keywords: [
      'properties Nigeria',
      'homes for sale',
      'real estate marketplace',
      'HD Homes properties',
    ],
    structuredData: {
      '@context': 'https://schema.org',
      '@type': 'CollectionPage',
      'name': 'HD Homes Property Marketplace',
    },
  );

  static SeoMetadata propertyDetail(String title, String description) => SeoMetadata(
        title: '$title | HD Homes',
        description: description,
        structuredData: {
          '@context': 'https://schema.org',
          '@type': 'RealEstateListing',
          'name': title,
          'description': description,
        },
      );

  static const estates = SeoMetadata(
    title: 'Flagship Estates & Developments | HD Homes',
    description:
        'Explore premium HD Homes estates across Nigeria — master plans, amenities, '
        'available units, and investment opportunities.',
    keywords: [
      'estates Nigeria',
      'property developments',
      'HD Homes estates',
      'gated communities',
    ],
    structuredData: {
      '@context': 'https://schema.org',
      '@type': 'CollectionPage',
      'name': 'HD Homes Estates',
    },
  );

  static SeoMetadata estateDetail(String name, String description) => SeoMetadata(
        title: '$name Estate | HD Homes',
        description: description,
        structuredData: {
          '@context': 'https://schema.org',
          '@type': 'Residence',
          'name': name,
          'description': description,
        },
      );

  static const servicesHub = SeoMetadata(
    title: 'Premium Real Estate & Construction Services | HD Homes',
    description:
        'Full-service property solutions — sales, construction, design, management, '
        'valuation, and advisory. Book a consultation today.',
    keywords: [
      'real estate services Nigeria',
      'construction company',
      'property management',
      'HD Homes services',
    ],
    structuredData: {
      '@context': 'https://schema.org',
      '@type': 'CollectionPage',
      'name': 'HD Homes Services',
    },
  );

  static SeoMetadata serviceDetail(String name, String description) => SeoMetadata(
        title: '$name | HD Homes Services',
        description: description,
        structuredData: {
          '@context': 'https://schema.org',
          '@type': 'Service',
          'name': name,
          'description': description,
          'provider': {'@type': 'Organization', 'name': 'HD Homes Limited'},
        },
      );

  static const blogHub = SeoMetadata(
    title: 'Knowledge Center | Blog, News & Market Insights | HD Homes',
    description:
        'Expert guides on buying, investing, construction, and property development in Nigeria. '
        'Market reports, academy lessons, research, and company news.',
    keywords: [
      'real estate blog Nigeria',
      'property investment guides',
      'HD Homes news',
      'market reports',
      'knowledge center',
    ],
    structuredData: {
      '@context': 'https://schema.org',
      '@type': 'CollectionPage',
      'name': 'HD Homes Knowledge Center',
    },
  );

  static SeoMetadata articleDetail(
    String title,
    String description, {
    List<String> tags = const [],
    String? authorName,
    DateTime? publishedAt,
  }) =>
      SeoMetadata(
        title: '$title | HD Homes Knowledge Center',
        description: description,
        keywords: tags,
        structuredData: {
          '@context': 'https://schema.org',
          '@type': 'NewsArticle',
          'headline': title,
          'description': description,
          if (authorName != null) 'author': {'@type': 'Person', 'name': authorName},
          if (publishedAt != null) 'datePublished': publishedAt.toIso8601String(),
          'publisher': {
            '@type': 'Organization',
            'name': 'HD Homes Limited',
          },
        },
      );

  static const contactHub = SeoMetadata(
    title: 'Contact HD Homes | Book Inspections & Consultations',
    description:
        'Reach HD Homes by phone, WhatsApp, email, or book a property inspection or consultation. '
        'Every inquiry flows into our CRM for fast follow-up.',
    keywords: [
      'contact HD Homes',
      'book property inspection Lagos',
      'real estate consultation Nigeria',
      'HD Homes offices',
    ],
    structuredData: {
      '@context': 'https://schema.org',
      '@type': 'ContactPage',
      'name': 'Contact HD Homes Limited',
      'description': 'Customer engagement and lead generation hub for HD Homes Ltd.',
    },
  );

  static const mediaHub = SeoMetadata(
    title: 'Media Center & Virtual Experiences | HD Homes',
    description:
        'Immersive digital showrooms with HD galleries, 360° virtual tours, drone footage, '
        'floor plans, construction progress, and virtual open houses.',
    keywords: [
      'property virtual tour Nigeria',
      'real estate media center',
      '360 property tour',
      'drone estate footage',
      'HD Homes gallery',
    ],
    structuredData: {
      '@context': 'https://schema.org',
      '@type': 'CollectionPage',
      'name': 'HD Homes Media Center',
      'description': 'Digital showroom for luxury property exploration.',
    },
  );

  static SeoMetadata mediaExperience(String name, String description) => SeoMetadata(
        title: '$name — Media Experience | HD Homes',
        description: description,
        keywords: [
          'virtual property tour',
          'property gallery',
          'floor plans',
          'construction progress',
          name,
        ],
        structuredData: {
          '@context': 'https://schema.org',
          '@type': 'MediaObject',
          'name': name,
          'description': description,
        },
      );

  static const trustHub = SeoMetadata(
    title: 'Trust Center | Legal, Compliance & Corporate Transparency | HD Homes',
    description:
        'Enterprise Trust Center showcasing licenses, certifications, governance, investor protection, '
        'legal documents, ESG, CSR, transparency reports, and document verification.',
    keywords: [
      'HD Homes trust',
      'real estate compliance Nigeria',
      'property legal documents',
      'investor protection',
      'corporate governance',
      'CAC registered developer',
    ],
    structuredData: {
      '@context': 'https://schema.org',
      '@type': 'Organization',
      'name': 'HD Homes Limited',
      'description': 'Trusted Nigerian property developer with enterprise transparency and compliance.',
      'url': 'https://hdhomes.ng/trust',
    },
  );

  static const careersHub = SeoMetadata(
    title: 'Careers at HD Homes | Join Our PropTech Team',
    description:
        'Explore open roles at HD Homes — sales, construction, design, technology, finance, and more. '
        'Build the future of Nigerian housing with a premium PropTech developer.',
    keywords: [
      'HD Homes careers',
      'real estate jobs Nigeria',
      'PropTech jobs Lagos',
      'construction careers Abuja',
      'Flutter jobs Nigeria',
    ],
    structuredData: {
      '@context': 'https://schema.org',
      '@type': 'CollectionPage',
      'name': 'HD Homes Careers',
      'description': 'Open positions and career opportunities at HD Homes Limited.',
    },
  );

  static const investmentHub = SeoMetadata(
    title: 'Investment Opportunities & ROI | HD Homes',
    description:
        'Structured Nigerian real estate investments — off-plan, rental income, land banking, '
        'and commercial products with escrow protection, transparent reporting, and AI insights.',
    keywords: [
      'property investment Nigeria',
      'real estate ROI Lagos',
      'off-plan investment',
      'HD Homes investor',
      'diaspora property investment',
    ],
    structuredData: {
      '@context': 'https://schema.org',
      '@type': 'WebPage',
      'name': 'HD Homes Investment Hub',
      'description': 'Investment products and investor resources for Nigerian real estate.',
    },
  );

  static const searchHub = SeoMetadata(
    title: 'Property Search Intelligence | AI-Powered Discovery | HD Homes',
    description:
        'Intelligent property search with AI recommendations, lifestyle matching, map exploration, '
        'saved searches, alerts, and personalized discovery.',
    keywords: [
      'property search Nigeria',
      'AI property search',
      'Lekki homes search',
      'real estate filters',
      'HD Homes search',
    ],
    structuredData: {
      '@context': 'https://schema.org',
      '@type': 'WebPage',
      'name': 'HD Homes Property Search Intelligence',
    },
  );

  // Auth surfaces — indexable register; transactional handoffs stay noindex.
  static const register = SeoMetadata(
    title: 'Create Your HD Homes Account | Client & Investor Registration',
    description:
        'Register as a client or investor with HD Homes. Progressive onboarding, '
        'secure credentials, and access to portals after email verification.',
    keywords: [
      'HD Homes register',
      'create account',
      'investor registration Nigeria',
      'property client signup',
    ],
    robots: 'index, follow',
  );

  static const login = SeoMetadata(
    title: 'Sign In | HD Homes',
    description: 'Secure sign-in to your HD Homes client, investor, or staff account.',
    robots: 'noindex, nofollow',
  );

  static const verifyEmail = SeoMetadata(
    title: 'Verify Your Email | HD Homes',
    description: 'Confirm your email address to activate your HD Homes account.',
    robots: 'noindex, nofollow',
  );

  static const welcome = SeoMetadata(
    title: 'Welcome to HD Homes',
    description: 'Your account is ready — continue to your personalized portal.',
    robots: 'noindex, nofollow',
  );

  static const forgotPassword = SeoMetadata(
    title: 'Reset Password | HD Homes',
    description: 'Request a secure password reset link for your HD Homes account.',
    robots: 'noindex, nofollow',
  );

  static const resetPassword = SeoMetadata(
    title: 'Create New Password | HD Homes',
    description: 'Set a new secure password for your HD Homes account.',
    robots: 'noindex, nofollow',
  );
}
