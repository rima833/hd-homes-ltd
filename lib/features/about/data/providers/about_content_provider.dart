import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/features/about/data/models/about_cms_content.dart';

final aboutContentProvider = Provider<AboutCmsContent>((ref) {
  return const AboutCmsContent(
    hero: AboutHeroContent(
      headline: 'Building Homes.\nCreating Communities.\nInspiring Futures.',
      subheadline:
          'HD Homes Ltd is a premium Nigerian property developer delivering trusted homes, estates, and investment opportunities with transparency and excellence.',
      primaryCtaLabel: 'Our Projects',
      primaryCtaPath: RoutePaths.properties,
      secondaryCtaLabel: 'Contact Us',
      secondaryCtaPath: RoutePaths.contact,
      tertiaryCtaLabel: 'Book Consultation',
      tertiaryCtaPath: RoutePaths.bookInspection,
    ),
    intro: AboutIntroContent(
      description:
          'Founded to make quality housing accessible, HD Homes combines development expertise, construction excellence, and investor-grade transparency across Nigeria\'s fastest-growing corridors.',
      yearsOperating: 15,
      specializations: [
        'Residential Development',
        'Estate Planning',
        'Real Estate Investment',
        'Construction Management',
      ],
      geographicPresence: ['Lagos', 'Abuja', 'Port Harcourt', 'Enugu'],
      achievements: [
        '48+ completed projects',
        '12 flagship estates',
        '850+ active investors',
        'CAC-registered developer',
      ],
      philosophy:
          'We believe every family deserves a home built with integrity, and every investor deserves clarity from day one.',
    ),
    story: [
      AboutStoryChapter(
        year: '2011',
        title: 'The Beginning',
        body:
            'HD Homes was founded with a mission to bridge Nigeria\'s housing gap through quality, affordable developments.',
      ),
      AboutStoryChapter(
        year: '2015',
        title: 'First Flagship Estate',
        body:
            'Delivered our first master-planned estate, establishing our reputation for transparent delivery and premium finishes.',
      ),
      AboutStoryChapter(
        year: '2019',
        title: 'National Expansion',
        body:
            'Expanded operations to Abuja and Port Harcourt, partnering with leading financial institutions.',
      ),
      AboutStoryChapter(
        year: '2024',
        title: 'PropTech Innovation',
        body:
            'Launched digital client and investor portals, setting a new standard for transparency in Nigerian real estate.',
      ),
      AboutStoryChapter(
        year: '2026',
        title: 'Looking Ahead',
        body:
            'Scaling sustainable developments and smart-home communities across West Africa.',
      ),
    ],
    vision: 'To be Africa\'s most trusted PropTech-led property developer.',
    mission:
        'Deliver exceptional homes and investment opportunities through innovation, quality construction, and transparent client partnerships.',
    values: [
      AboutValueItem(
        title: 'Integrity',
        description: 'We do what we say and document what we do.',
        iconName: 'shield',
      ),
      AboutValueItem(
        title: 'Innovation',
        description: 'Technology and design drive every decision.',
        iconName: 'sparkles',
      ),
      AboutValueItem(
        title: 'Quality',
        description: 'Premium materials and rigorous standards.',
        iconName: 'award',
      ),
      AboutValueItem(
        title: 'Customer First',
        description: 'Clients and investors at the centre of everything.',
        iconName: 'heart',
      ),
      AboutValueItem(
        title: 'Transparency',
        description: 'Open processes, clear documentation, honest communication.',
        iconName: 'eye',
      ),
      AboutValueItem(
        title: 'Excellence',
        description: 'Continuous improvement in every project.',
        iconName: 'star',
      ),
      AboutValueItem(
        title: 'Sustainability',
        description: 'Responsible building for future generations.',
        iconName: 'leaf',
      ),
      AboutValueItem(
        title: 'Community',
        description: 'Developments that strengthen neighbourhoods.',
        iconName: 'users',
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
    leadership: [
      AboutLeaderProfile(
        name: 'Managing Director',
        position: 'Chief Executive Officer',
        bio:
            'Leads HD Homes with a vision for transparent, technology-driven property development across Nigeria.',
        qualifications: ['MBA', 'NIESV Member', '15+ years real estate'],
        yearsExperience: 18,
      ),
      AboutLeaderProfile(
        name: 'General Manager',
        position: 'Operations',
        bio:
            'Oversees project delivery, construction quality, and client satisfaction across all developments.',
        qualifications: ['B.Eng Civil Engineering', 'PMP'],
        yearsExperience: 14,
      ),
      AboutLeaderProfile(
        name: 'Director of Finance',
        position: 'Finance & Investment',
        bio:
            'Manages investor relations, payment structures, and financial compliance.',
        qualifications: ['ACA', 'CFA Level II'],
        yearsExperience: 12,
      ),
      AboutLeaderProfile(
        name: 'Head of Construction',
        position: 'Construction',
        bio:
            'Ensures on-site excellence, safety standards, and milestone delivery.',
        qualifications: ['B.Sc Building Technology', 'COREN'],
        yearsExperience: 16,
      ),
    ],
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
    awards: [
      AboutAwardItem(
        title: 'Excellence in Housing Development',
        year: '2025',
        description: 'Recognised for quality delivery and client satisfaction.',
        issuer: 'Nigeria Property Awards',
      ),
      AboutAwardItem(
        title: 'Best Customer Experience',
        year: '2024',
        description: 'PropTech innovation in client engagement.',
        issuer: 'PropTech Nigeria',
      ),
      AboutAwardItem(
        title: 'CAC Corporate Registration',
        year: '2011',
        description: 'Fully registered corporate entity.',
        issuer: 'Corporate Affairs Commission',
      ),
    ],
    partners: [
      AboutPartnerItem(name: 'First Bank', category: 'Banking'),
      AboutPartnerItem(name: 'GTBank', category: 'Banking'),
      AboutPartnerItem(name: 'BuildRight Contractors', category: 'Construction'),
      AboutPartnerItem(name: 'NIESV', category: 'Professional Body'),
      AboutPartnerItem(name: 'Lagos State Ministry', category: 'Government'),
      AboutPartnerItem(name: 'SurveyPro Ltd', category: 'Surveying'),
    ],
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
        iconName: 'hard_hat',
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
    stats: [
      AboutStatItem(value: 15, label: 'Years in Business', suffix: '+'),
      AboutStatItem(value: 3200, label: 'Homes Delivered', suffix: '+'),
      AboutStatItem(value: 48, label: 'Projects Completed'),
      AboutStatItem(value: 12000, label: 'Happy Clients', suffix: '+'),
      AboutStatItem(value: 850, label: 'Investors'),
      AboutStatItem(value: 18, label: 'Active Construction'),
      AboutStatItem(value: 120, label: 'Employees'),
      AboutStatItem(value: 35, label: 'Partner Organizations'),
      AboutStatItem(value: 12, label: 'Industry Awards'),
    ],
    offices: [
      AboutOfficeLocation(
        name: 'Head Office',
        type: 'Head Office',
        address: 'Lekki Phase 1, Lagos, Nigeria',
        phone: '+234 800 HD HOMES',
        email: 'info@hdhomes.ng',
        hours: 'Mon–Fri 8:00–18:00',
        mapUrl: 'https://maps.google.com',
      ),
      AboutOfficeLocation(
        name: 'Abuja Regional Office',
        type: 'Regional Office',
        address: 'Central Business District, Abuja',
        phone: '+234 800 HD HOMES',
        email: 'abuja@hdhomes.ng',
        hours: 'Mon–Fri 8:00–17:00',
        mapUrl: 'https://maps.google.com',
      ),
      AboutOfficeLocation(
        name: 'Port Harcourt Sales Office',
        type: 'Sales Office',
        address: 'GRA Phase 2, Port Harcourt',
        phone: '+234 800 HD HOMES',
        email: 'ph@hdhomes.ng',
        hours: 'Mon–Sat 9:00–17:00',
        mapUrl: 'https://maps.google.com',
      ),
    ],
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
      openPositions: 8,
      ctaLabel: 'View Careers',
      ctaPath: RoutePaths.careers,
    ),
    testimonials: [
      AboutTestimonialItem(
        name: 'Adaeze O.',
        role: 'Homeowner',
        quote:
            'HD Homes made our dream home a reality with complete transparency throughout.',
        rating: 5,
        verified: true,
        type: 'buyer',
      ),
      AboutTestimonialItem(
        name: 'Chukwuemeka I.',
        role: 'Investor',
        quote:
            'Their investor portal and regular updates gave me confidence to diversify.',
        rating: 5,
        verified: true,
        type: 'investor',
      ),
      AboutTestimonialItem(
        name: 'Fatima B.',
        role: 'Partner Architect',
        quote:
            'A professional team that values quality and timely collaboration.',
        rating: 5,
        verified: true,
        type: 'partner',
      ),
    ],
    executiveVideo: AboutExecutiveVideo(
      speakerName: 'Managing Director',
      speakerTitle: 'Chief Executive Officer',
      message:
          'Welcome to HD Homes. Our commitment is simple: build with integrity, deliver with excellence, and earn your trust every single day.',
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
      title: 'HD Homes Company Profile',
      description:
          'Interactive overview of our history, projects, leadership, and investment opportunities.',
      downloadUrl: '#',
      viewUrl: '#',
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
        ),
        AboutCtaAction(
          label: 'Book Site Inspection',
          path: RoutePaths.bookInspection,
          isPrimary: false,
        ),
        AboutCtaAction(
          label: 'Download Company Profile',
          path: RoutePaths.about,
          isPrimary: false,
        ),
      ],
    ),
  );
});
