import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/features/blog/data/models/blog_content.dart';

final blogCatalogProvider = Provider<List<BlogArticleSummary>>((ref) => _articles);

final blogHubCmsProvider = Provider<BlogHubCms>((ref) => _hubCms);

final blogCategoriesProvider = Provider<List<BlogCategory>>((ref) => _hubCms.categories);

final blogAuthorsProvider = Provider<List<BlogAuthor>>((ref) => _hubCms.authors);

final featuredArticlesProvider = Provider<List<BlogArticleSummary>>((ref) {
  return ref.watch(blogCatalogProvider).where((a) => a.isFeatured).toList();
});

final trendingArticlesProvider = Provider<List<BlogArticleSummary>>((ref) {
  return ref.watch(blogCatalogProvider).where((a) => a.isTrending).toList();
});

final articlesByCategoryProvider =
    Provider.family<List<BlogArticleSummary>, String>((ref, categoryId) {
  return ref.watch(blogCatalogProvider).where((a) => a.categoryId == categoryId).toList();
});

final _authors = [
  const BlogAuthor(
    id: 'a1',
    name: 'Dr. Amaka Nwosu',
    role: 'Head of Market Intelligence',
    bio: '15 years in Nigerian real estate research and investment analysis.',
    articleCount: 42,
    expertise: ['Investment', 'Market Trends', 'ROI Analysis'],
    verified: true,
  ),
  const BlogAuthor(
    id: 'a2',
    name: 'Tunde Bakare',
    role: 'Senior Property Advisor',
    bio: 'Helps families and diaspora buyers navigate Lagos property markets.',
    articleCount: 28,
    expertise: ['Buying Guides', 'Lekki Corridor', 'Due Diligence'],
    verified: true,
  ),
  const BlogAuthor(
    id: 'a3',
    name: 'Grace Okonkwo',
    role: 'Legal & Compliance Editor',
    bio: 'Specialist in land documentation, titles, and regulatory compliance.',
    articleCount: 19,
    expertise: ['Land Law', 'C of O', 'Governor\'s Consent'],
    verified: true,
  ),
];

final _categories = [
  const BlogCategory(
    id: 'cat-buying',
    group: BlogCategoryGroup.realEstate,
    name: 'Buying Guides',
    description: 'First-time buyer guides and home ownership tips.',
  ),
  const BlogCategory(
    id: 'cat-invest',
    group: BlogCategoryGroup.investment,
    name: 'Investment Strategies',
    description: 'ROI, rental yield, and portfolio building.',
  ),
  const BlogCategory(
    id: 'cat-construction',
    group: BlogCategoryGroup.construction,
    name: 'Building Process',
    description: 'Construction updates, materials, and engineering.',
  ),
  const BlogCategory(
    id: 'cat-legal',
    group: BlogCategoryGroup.legal,
    name: 'Land Documentation',
    description: 'Titles, surveys, and compliance explained.',
  ),
  const BlogCategory(
    id: 'cat-finance',
    group: BlogCategoryGroup.finance,
    name: 'Mortgages & Finance',
    description: 'Financing, installments, and budgeting.',
  ),
  const BlogCategory(
    id: 'cat-lifestyle',
    group: BlogCategoryGroup.lifestyle,
    name: 'Smart Homes & Design',
    description: 'Interior design, architecture, and community living.',
  ),
  const BlogCategory(
    id: 'cat-news',
    group: BlogCategoryGroup.companyNews,
    name: 'Company News',
    description: 'Press releases, awards, and HD Homes updates.',
  ),
  const BlogCategory(
    id: 'cat-dev',
    group: BlogCategoryGroup.propertyDevelopment,
    name: 'Estate Launches',
    description: 'New developments, infrastructure, and sustainability.',
  ),
];

final _articles = [
  BlogArticleSummary(
    id: 'b001',
    slug: 'first-time-buyers-guide-nigeria-2026',
    title: 'The Complete First-Time Buyer\'s Guide to Property in Nigeria (2026)',
    excerpt:
        'Everything you need to know before purchasing your first home — from budgeting to handover.',
    categoryId: 'cat-buying',
    authorId: 'a2',
    publishedAt: DateTime(2026, 3, 15),
    readMinutes: 12,
    views: 18420,
    likes: 342,
    comments: 28,
    tags: ['buying', 'first-time', 'guide'],
    contentType: BlogContentType.guide,
    isFeatured: true,
    isTrending: true,
    isEditorsPick: true,
  ),
  BlogArticleSummary(
    id: 'b002',
    slug: 'lekki-property-market-report-q1-2026',
    title: 'Lekki Property Market Report — Q1 2026',
    excerpt: 'Price trends, demand index, and investment hotspots across the Lekki corridor.',
    categoryId: 'cat-invest',
    authorId: 'a1',
    publishedAt: DateTime(2026, 4, 1),
    readMinutes: 15,
    views: 22100,
    likes: 410,
    comments: 45,
    tags: ['market report', 'Lekki', 'investment'],
    contentType: BlogContentType.report,
    isFeatured: true,
    isTrending: true,
  ),
  BlogArticleSummary(
    id: 'b003',
    slug: 'understanding-certificate-of-occupancy',
    title: 'Understanding Certificate of Occupancy in Lagos',
    excerpt: 'A plain-language guide to C of O, Governor\'s Consent, and title verification.',
    categoryId: 'cat-legal',
    authorId: 'a3',
    publishedAt: DateTime(2026, 2, 20),
    readMinutes: 10,
    views: 15600,
    likes: 289,
    comments: 34,
    tags: ['legal', 'C of O', 'documentation'],
    contentType: BlogContentType.article,
    isFeatured: true,
    isEditorsPick: true,
  ),
  BlogArticleSummary(
    id: 'b004',
    slug: 'horizon-gardens-estate-launch',
    title: 'Horizon Gardens Estate Launch — What Buyers Need to Know',
    excerpt: 'HD Homes unveils Phase 1 of its flagship Lekki lifestyle estate.',
    categoryId: 'cat-dev',
    authorId: 'a2',
    publishedAt: DateTime(2026, 3, 28),
    readMinutes: 6,
    views: 9800,
    likes: 156,
    comments: 12,
    tags: ['estate launch', 'Horizon Gardens', 'news'],
    contentType: BlogContentType.news,
    isTrending: true,
  ),
  BlogArticleSummary(
    id: 'b005',
    slug: 'mortgage-vs-installment-plans',
    title: 'Mortgage vs Installment Plans: Which Is Right for You?',
    excerpt: 'Compare bank mortgages with developer installment plans for Nigerian property buyers.',
    categoryId: 'cat-finance',
    authorId: 'a1',
    publishedAt: DateTime(2026, 1, 10),
    readMinutes: 8,
    views: 12300,
    likes: 198,
    comments: 19,
    tags: ['mortgage', 'finance', 'installment'],
    contentType: BlogContentType.guide,
    isEditorsPick: true,
  ),
  BlogArticleSummary(
    id: 'b006',
    slug: 'smart-home-features-worth-investing',
    title: 'Smart Home Features Worth Investing In',
    excerpt: 'From security to energy savings — the smart features that add real value.',
    categoryId: 'cat-lifestyle',
    authorId: 'a2',
    publishedAt: DateTime(2026, 2, 5),
    readMinutes: 7,
    views: 8700,
    likes: 134,
    comments: 8,
    tags: ['smart home', 'technology', 'lifestyle'],
    contentType: BlogContentType.article,
  ),
  BlogArticleSummary(
    id: 'b007',
    slug: 'construction-timeline-what-to-expect',
    title: 'Construction Timeline: What to Expect When Building with HD Homes',
    excerpt: 'From foundation to handover — a transparent look at the build process.',
    categoryId: 'cat-construction',
    authorId: 'a2',
    publishedAt: DateTime(2025, 12, 18),
    readMinutes: 11,
    views: 6500,
    likes: 98,
    comments: 6,
    tags: ['construction', 'timeline', 'build'],
    contentType: BlogContentType.guide,
    isTrending: true,
  ),
  BlogArticleSummary(
    id: 'b008',
    slug: 'hd-homes-wins-excellence-award-2025',
    title: 'HD Homes Wins Real Estate Excellence Award 2025',
    excerpt: 'Recognized for transparency, quality delivery, and customer satisfaction.',
    categoryId: 'cat-news',
    authorId: 'a1',
    publishedAt: DateTime(2025, 11, 30),
    readMinutes: 4,
    views: 5200,
    likes: 210,
    comments: 15,
    tags: ['award', 'press', 'company'],
    contentType: BlogContentType.pressRelease,
  ),
  BlogArticleSummary(
    id: 'b009',
    slug: 'rental-yield-calculator-guide',
    title: 'How to Calculate Rental Yield on Nigerian Property',
    excerpt: 'Step-by-step guide to evaluating rental income potential.',
    categoryId: 'cat-invest',
    authorId: 'a1',
    publishedAt: DateTime(2026, 1, 22),
    readMinutes: 9,
    views: 11200,
    likes: 245,
    comments: 22,
    tags: ['rental yield', 'investment', 'calculator'],
    contentType: BlogContentType.guide,
  ),
  BlogArticleSummary(
    id: 'b010',
    slug: 'land-survey-beaconing-explained',
    title: 'Land Survey & Beaconing Explained',
    excerpt: 'Why surveys matter and how to verify boundaries before purchase.',
    categoryId: 'cat-legal',
    authorId: 'a3',
    publishedAt: DateTime(2026, 3, 5),
    readMinutes: 8,
    views: 7400,
    likes: 112,
    comments: 9,
    tags: ['survey', 'land', 'legal'],
    contentType: BlogContentType.article,
  ),
];

final _hubCms = BlogHubCms(
  heroHeadline: 'Insights That Build Better Decisions.',
  heroSubheadline:
      'Your knowledge hub for real estate, construction, investment, and property development in Nigeria.',
  categories: _categories,
  authors: _authors,
  marketInsights: const [
    MarketInsight(title: 'Lagos Avg. Price/sqm', value: '₦185,000', change: '+12%', period: 'YoY'),
    MarketInsight(title: 'Abuja Demand Index', value: '87/100', change: '+5%', period: 'Q1 2026'),
    MarketInsight(title: 'Rental Yield (Lekki)', value: '8.2%', change: '+0.4%', period: 'Q1 2026'),
    MarketInsight(title: 'Construction Activity', value: 'High', change: '↑', period: 'Lagos'),
  ],
  academyTracks: const [
    AcademyTrack(
      level: 'Beginner',
      title: 'Home Buying Fundamentals',
      description: 'Land titles, budgeting, and your first property purchase.',
      lessonCount: 6,
      articleSlugs: ['first-time-buyers-guide-nigeria-2026', 'understanding-certificate-of-occupancy'],
    ),
    AcademyTrack(
      level: 'Intermediate',
      title: 'Property Investment',
      description: 'ROI analysis, rental yield, and portfolio strategies.',
      lessonCount: 8,
      articleSlugs: ['rental-yield-calculator-guide', 'mortgage-vs-installment-plans'],
    ),
    AcademyTrack(
      level: 'Advanced',
      title: 'Development Finance',
      description: 'Commercial investing and development partnerships.',
      lessonCount: 5,
      articleSlugs: ['lekki-property-market-report-q1-2026'],
    ),
  ],
  researchReports: const [
    ResearchReport(
      title: 'Nigeria Real Estate Outlook 2026',
      description: 'Annual market forecast across major cities.',
      publishedAt: 'Jan 2026',
      downloadType: 'PDF',
    ),
    ResearchReport(
      title: 'Lekki Corridor Investment Guide',
      description: 'Infrastructure impact and appreciation forecasts.',
      publishedAt: 'Mar 2026',
      downloadType: 'PDF',
    ),
    ResearchReport(
      title: 'Construction Cost Index Q1 2026',
      description: 'Material prices and labour cost benchmarks.',
      publishedAt: 'Apr 2026',
      downloadType: 'PDF',
    ),
  ],
  videos: const [
    BlogVideo(title: 'Horizon Gardens Drone Tour', category: 'Estate Launch', duration: '4:32'),
    BlogVideo(title: 'Customer Testimonial — The Okafor Family', category: 'Testimonial', duration: '2:15'),
    BlogVideo(title: 'Investment Webinar: Lekki 2026', category: 'Webinar', duration: '45:00'),
    BlogVideo(title: 'Construction Update — Emerald Heights', category: 'Construction', duration: '3:48'),
  ],
  downloads: const [
    BlogDownload(title: 'HD Homes Company Profile', type: 'PDF', size: '2.4 MB'),
    BlogDownload(title: 'First-Time Buyer Checklist', type: 'PDF', size: '890 KB'),
    BlogDownload(title: 'Investment Planning Template', type: 'XLSX', size: '450 KB'),
    BlogDownload(title: 'Land Documentation Guide', type: 'PDF', size: '1.2 MB'),
  ],
  events: const [
    BlogEvent(
      title: 'Horizon Gardens Open House',
      date: 'Sat, 18 Apr 2026 · 10:00 AM',
      location: 'Lekki, Lagos',
      type: 'Open House',
    ),
    BlogEvent(
      title: 'Investor Seminar — Lekki Corridor 2026',
      date: 'Thu, 30 Apr 2026 · 6:00 PM',
      location: 'Online Webinar',
      type: 'Webinar',
    ),
    BlogEvent(
      title: 'Construction Site Tour — Emerald Heights',
      date: 'Sat, 9 May 2026 · 9:00 AM',
      location: 'Abuja',
      type: 'Site Tour',
    ),
  ],
  pressReleases: const [
    PressRelease(
      title: 'HD Homes Launches Horizon Gardens Phase 1',
      date: '28 Mar 2026',
      excerpt: '240-unit lifestyle estate opens for sales in Lekki.',
      slug: 'horizon-gardens-estate-launch',
    ),
    PressRelease(
      title: 'HD Homes Wins Real Estate Excellence Award 2025',
      date: '30 Nov 2025',
      excerpt: 'National recognition for quality and transparency.',
      slug: 'hd-homes-wins-excellence-award-2025',
    ),
  ],
  glossary: const [
    GlossaryTerm(
      term: 'Certificate of Occupancy (C of O)',
      definition: 'A legal document issued by the state government confirming land ownership rights.',
      letter: 'C',
      relatedArticleSlugs: ['understanding-certificate-of-occupancy'],
    ),
    GlossaryTerm(
      term: 'Governor\'s Consent',
      definition: 'Approval required to transfer land rights on properties with existing C of O.',
      letter: 'G',
      relatedArticleSlugs: ['understanding-certificate-of-occupancy'],
    ),
    GlossaryTerm(
      term: 'Rental Yield',
      definition: 'Annual rental income as a percentage of property value.',
      letter: 'R',
      relatedArticleSlugs: ['rental-yield-calculator-guide'],
    ),
    GlossaryTerm(
      term: 'ROI',
      definition: 'Return on Investment — profit relative to cost over a period.',
      letter: 'R',
      relatedArticleSlugs: ['lekki-property-market-report-q1-2026'],
    ),
  ],
  faqs: const [
    BlogFaqItem(
      question: 'How often is content published?',
      answer: 'We publish new articles, reports, and news weekly. Market reports are released quarterly.',
    ),
    BlogFaqItem(
      question: 'Can I download research reports?',
      answer: 'Yes. Registered users can download reports from the Research Library. Downloads are tracked for analytics.',
    ),
    BlogFaqItem(
      question: 'Is the Learning Academy free?',
      answer: 'All academy content is free. Future certification tracks may offer premium modules.',
    ),
  ],
  popularSearches: const [
    'first time buyer',
    'C of O',
    'Lekki property',
    'rental yield',
    'mortgage Nigeria',
    'estate launch',
  ],
);
