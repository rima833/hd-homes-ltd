import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/features/home/data/models/home_cms_content.dart';

/// CMS placeholder content until Volume 1.5 Part 5 marketing tables are live.
final homeContentProvider = Provider<HomeCmsContent>((ref) {
  return const HomeCmsContent(
    announcement:
        'New estate launch — Horizon Gardens. Limited units with flexible payment plans.',
    hero: HomeHeroContent(
      headline: 'Building Exceptional Homes.\nCreating Lasting Value.',
      subheadline:
          'Premium real estate development and investment opportunities across Nigeria.',
      primaryCtaLabel: 'Explore Properties',
      primaryCtaPath: RoutePaths.properties,
      secondaryCtaLabel: 'Book Inspection',
      secondaryCtaPath: RoutePaths.bookInspection,
      tertiaryCtaLabel: 'Become an Investor',
      tertiaryCtaPath: RoutePaths.investment,
    ),
    stats: [
      HomeStatItem(value: 15, label: 'Years in Business', suffix: '+'),
      HomeStatItem(value: 48, label: 'Completed Projects', suffix: '+'),
      HomeStatItem(value: 320, label: 'Available Properties'),
      HomeStatItem(value: 12000, label: 'Happy Clients', suffix: '+'),
      HomeStatItem(value: 12, label: 'Estates Developed'),
      HomeStatItem(value: 850, label: 'Investors'),
      HomeStatItem(value: 18, label: 'Active Construction'),
      HomeStatItem(value: 98, label: 'Customer Satisfaction', suffix: '%'),
    ],
    about: HomeAboutContent(
      title: 'Who We Are',
      story:
          'HD Homes Ltd is a premium property developer committed to making quality housing accessible through innovation, transparency, and world-class construction.',
      mission: 'Deliver exceptional homes that elevate communities.',
      vision: 'To be Africa\'s most trusted PropTech-led developer.',
      values: ['Integrity', 'Quality', 'Innovation', 'Transparency'],
      highlights: [
        'Registered corporate developer',
        'Strategic locations nationwide',
        'Flexible payment structures',
        'Investor-grade project delivery',
      ],
      ctaLabel: 'Learn More',
      ctaPath: RoutePaths.about,
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
      HomeLifestyleItem(
        label: 'Commercial',
        description: 'Office and retail developments',
        route: RoutePaths.services,
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
    constructionProjects: [
      HomeConstructionItem(
        name: 'Horizon Gardens Phase II',
        progress: 0.72,
        completionDate: 'Q4 2026',
        update: 'Roofing and external finishes in progress',
        route: RoutePaths.gallery,
      ),
      HomeConstructionItem(
        name: 'Emerald Heights',
        progress: 0.45,
        completionDate: 'Q2 2027',
        update: 'Structural work completed on Block C',
        route: RoutePaths.gallery,
      ),
    ],
    testimonials: [
      HomeTestimonialItem(
        name: 'Adaeze O.',
        role: 'Homeowner, Horizon Gardens',
        quote:
            'HD Homes delivered exactly what they promised. The quality and transparency throughout the process were exceptional.',
        rating: 5,
        verified: true,
      ),
      HomeTestimonialItem(
        name: 'Chukwuemeka I.',
        role: 'Investor',
        quote:
            'Their investment products offer clarity and consistent updates. I\'ve diversified two portfolios with HD Homes.',
        rating: 5,
        verified: true,
      ),
    ],
    partners: [
      HomePartnerItem(name: 'First Bank', category: 'Banking Partner'),
      HomePartnerItem(name: 'CAC Registered', category: 'Government'),
      HomePartnerItem(name: 'NIESV', category: 'Professional Body'),
      HomePartnerItem(name: 'BuildRight Contractors', category: 'Construction'),
    ],
    awards: [
      HomeAwardItem(
        title: 'Excellence in Housing Development',
        year: '2025',
        issuer: 'Nigeria Property Awards',
      ),
      HomeAwardItem(
        title: 'Best Customer Experience',
        year: '2024',
        issuer: 'PropTech Nigeria',
      ),
    ],
    blogPosts: [
      HomeBlogItem(
        title: '5 Reasons to Invest in Lagos Real Estate in 2026',
        category: 'Investment',
        excerpt: 'Market trends and growth corridors worth watching.',
        route: RoutePaths.blog,
        date: 'Mar 2026',
      ),
      HomeBlogItem(
        title: 'Understanding Off-Plan Property Purchases',
        category: 'Real Estate Tips',
        excerpt: 'A buyer\'s guide to off-plan investments.',
        route: RoutePaths.blog,
        date: 'Feb 2026',
      ),
    ],
    marketInsights: [
      HomeMarketInsightItem(
        title: 'Lagos Prime Corridor',
        trend: 'Upward',
        change: '+12.4%',
        summary: 'Strong demand in Lekki and Ibeju-Lekki corridors.',
      ),
      HomeMarketInsightItem(
        title: 'Abuja Residential',
        trend: 'Stable',
        change: '+6.8%',
        summary: 'Steady appreciation in satellite towns.',
      ),
    ],
    events: [
      HomeEventItem(
        title: 'Horizon Gardens Open House',
        date: '15 Jul 2026',
        location: 'Lekki, Lagos',
        type: 'Open House',
      ),
      HomeEventItem(
        title: 'Investor Seminar 2026',
        date: '28 Jul 2026',
        location: 'Abuja',
        type: 'Investor Seminar',
      ),
    ],
    faqs: [
      HomeFaqItem(
        question: 'What payment plans do you offer?',
        answer:
            'We offer flexible installment plans with competitive terms tailored to your budget.',
      ),
      HomeFaqItem(
        question: 'Can I inspect properties before buying?',
        answer:
            'Yes. Book an inspection online or contact our sales team to schedule a visit.',
      ),
      HomeFaqItem(
        question: 'Are your developments legally documented?',
        answer:
            'All estates include verified titles and transparent documentation.',
      ),
    ],
    downloads: [
      HomeDownloadItem(
        title: 'Company Profile',
        fileType: 'PDF',
        url: '#',
      ),
      HomeDownloadItem(
        title: 'Investment Brochure',
        fileType: 'PDF',
        url: '#',
      ),
      HomeDownloadItem(
        title: 'Horizon Gardens Brochure',
        fileType: 'PDF',
        url: '#',
      ),
    ],
    liveActivities: [
      HomeLiveActivityItem(
        message: '3-bedroom terrace listed in Emerald Heights',
        timeAgo: '2 min ago',
        type: 'listing',
      ),
      HomeLiveActivityItem(
        message: 'Horizon Gardens Phase II reached 72% completion',
        timeAgo: '15 min ago',
        type: 'construction',
      ),
      HomeLiveActivityItem(
        message: '5 inspection slots available this weekend',
        timeAgo: '1 hr ago',
        type: 'inspection',
      ),
    ],
    executiveWelcome: HomeExecutiveWelcome(
      name: 'Managing Director',
      title: 'A message from leadership',
      message:
          'At HD Homes, we believe every family deserves a home built with integrity and every investor deserves transparency. Welcome to a new standard in Nigerian real estate.',
      videoUrl: null,
    ),
  );
});
