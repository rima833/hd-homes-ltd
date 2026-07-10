import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/features/careers/data/models/careers_hub_content.dart';

final careersHubCmsProvider = Provider<CareersHubCms>((ref) => _cms);

final _cms = CareersHubCms(
  heroHeadline: 'Build the Future of Nigerian Housing.',
  heroSubheadline:
      'Join HD Homes — a premium PropTech developer shaping estates, communities, '
      'and careers across Lagos, Abuja, and Port Harcourt.',
  openPositionsCount: 8,
  cultureSummary:
      'We foster innovation, collaboration, and excellence — building careers alongside communities. '
      'Our teams blend construction craftsmanship with digital product thinking.',
  values: const [
    CareerValue(
      title: 'Excellence',
      description: 'We deliver premium quality in every home, estate, and client interaction.',
      iconName: 'award',
    ),
    CareerValue(
      title: 'Transparency',
      description: 'Open communication with clients, investors, and teammates.',
      iconName: 'eye',
    ),
    CareerValue(
      title: 'Innovation',
      description: 'PropTech tools, AI, and modern construction methods drive how we work.',
      iconName: 'sparkles',
    ),
    CareerValue(
      title: 'Impact',
      description: 'Every project improves housing access and community outcomes.',
      iconName: 'heart',
    ),
  ],
  benefits: const [
    CareerBenefit(title: 'Health insurance', description: 'Comprehensive medical cover for you and dependents.'),
    CareerBenefit(title: 'Performance bonuses', description: 'Reward tied to delivery, sales, and project milestones.'),
    CareerBenefit(title: 'Training programs', description: 'Professional development, certifications, and mentorship.'),
    CareerBenefit(title: 'Flexible arrangements', description: 'Hybrid options for eligible roles.'),
    CareerBenefit(title: 'Staff housing support', description: 'Preferential access to HD Homes products.'),
    CareerBenefit(title: 'Career pathways', description: 'Clear progression across sales, construction, and tech.'),
  ],
  jobs: const [
    CareerJob(
      id: 'job-sales-exec',
      title: 'Sales Executive — Lekki Corridor',
      department: CareerDepartment.sales,
      location: 'Lagos',
      employmentType: CareerEmploymentType.fullTime,
      salaryRange: 'Competitive + commission',
      featured: true,
      summary: 'Drive property sales across flagship estates with CRM-backed lead pipelines.',
      responsibilities: [
        'Qualify and convert inbound leads from the website and CRM',
        'Conduct site inspections and client consultations',
        'Maintain accurate pipeline records and follow-ups',
      ],
      requirements: [
        '2+ years real estate or luxury sales experience',
        'Strong communication and negotiation skills',
        'Familiarity with CRM tools preferred',
      ],
    ),
    CareerJob(
      id: 'job-site-eng',
      title: 'Site Engineer',
      department: CareerDepartment.construction,
      location: 'Abuja',
      employmentType: CareerEmploymentType.fullTime,
      salaryRange: '₦4.5M–₦7M / year',
      featured: true,
      summary: 'Oversee construction quality and progress on Emerald Heights and related projects.',
      responsibilities: [
        'Supervise daily site activities and subcontractors',
        'Enforce HSE and quality standards',
        'Report milestones into construction dashboards',
      ],
      requirements: [
        'B.Eng Civil / Building or equivalent',
        '3+ years site experience on residential estates',
        'COREN registration preferred',
      ],
    ),
    CareerJob(
      id: 'job-ux',
      title: 'Product Designer (PropTech)',
      department: CareerDepartment.design,
      location: 'Lagos / Hybrid',
      employmentType: CareerEmploymentType.fullTime,
      featured: true,
      summary: 'Design client and investor portal experiences for the HD Homes digital ecosystem.',
      responsibilities: [
        'Own UX flows for public website and portals',
        'Collaborate with Flutter engineers on design systems',
        'Run usability reviews with sales and investor relations',
      ],
      requirements: [
        'Portfolio of web/mobile product design',
        'Figma proficiency',
        'Interest in real estate or fintech a plus',
      ],
    ),
    CareerJob(
      id: 'job-flutter',
      title: 'Senior Flutter Engineer',
      department: CareerDepartment.technology,
      location: 'Lagos / Remote',
      employmentType: CareerEmploymentType.fullTime,
      salaryRange: 'Competitive',
      featured: true,
      summary: 'Build enterprise Flutter experiences across website, client, and investor portals.',
      responsibilities: [
        'Ship features across Volume 2–3 modules',
        'Uphold architecture, testing, and design-token standards',
        'Integrate Supabase, Riverpod, and GoRouter patterns',
      ],
      requirements: [
        '4+ years Flutter / Dart',
        'Experience with Riverpod and GoRouter',
        'Strong UI craft and performance awareness',
      ],
    ),
    CareerJob(
      id: 'job-mkt',
      title: 'Digital Marketing Specialist',
      department: CareerDepartment.marketing,
      location: 'Lagos',
      employmentType: CareerEmploymentType.fullTime,
      summary: 'Grow qualified traffic and leads across SEO, content, and paid channels.',
      responsibilities: [
        'Own campaign performance for estates and investment products',
        'Partner with Knowledge Center editors on content SEO',
        'Report funnel metrics into Growth Engine dashboards',
      ],
      requirements: [
        '2+ years digital marketing',
        'SEO and analytics fluency',
        'Real estate marketing experience preferred',
      ],
    ),
    CareerJob(
      id: 'job-finance',
      title: 'Finance Analyst — Installments',
      department: CareerDepartment.finance,
      location: 'Lagos',
      employmentType: CareerEmploymentType.fullTime,
      summary: 'Support payment plans, receipts, and investor reporting workflows.',
      responsibilities: [
        'Reconcile installment schedules and receipts',
        'Prepare investor and management reports',
        'Support escrow and milestone payment processes',
      ],
      requirements: [
        'Degree in Accounting / Finance',
        'ICAN or ACCA progress preferred',
        'Excel and ERP familiarity',
      ],
    ),
    CareerJob(
      id: 'job-ops',
      title: 'Estate Operations Coordinator',
      department: CareerDepartment.operations,
      location: 'Port Harcourt',
      employmentType: CareerEmploymentType.fullTime,
      summary: 'Coordinate amenities, facilities, and resident experience at Green Valley.',
      responsibilities: [
        'Manage vendor SLAs and facility schedules',
        'Support resident onboarding and service tickets',
        'Report estate KPIs to operations leadership',
      ],
      requirements: [
        '2+ years facilities or estate operations',
        'Strong stakeholder management',
        'Willingness to be on-site',
      ],
    ),
    CareerJob(
      id: 'job-intern',
      title: 'Legal Intern — Documentation',
      department: CareerDepartment.legal,
      location: 'Lagos',
      employmentType: CareerEmploymentType.internship,
      summary: 'Support title documentation, agreements, and Trust Center content workflows.',
      responsibilities: [
        'Assist with document preparation and filing',
        'Research regulatory requirements',
        'Support due diligence room packaging',
      ],
      requirements: [
        'Law student or recent graduate',
        'Strong attention to detail',
        'Interest in property law',
      ],
    ),
  ],
  testimonials: const [
    CareerTestimonial(
      name: 'Tunde Adebayo',
      role: 'Sales Lead · Lagos',
      quote:
          'HD Homes gives sales the tools and transparency to close with confidence — CRM, inspections, and estate storytelling all connect.',
    ),
    CareerTestimonial(
      name: 'Ngozi Eze',
      role: 'Site Engineer · Abuja',
      quote:
          'Construction reporting is taken seriously here. Progress updates reach clients and investors the same week we hit milestones.',
    ),
    CareerTestimonial(
      name: 'Ibrahim Musa',
      role: 'Flutter Engineer',
      quote:
          'We ship enterprise PropTech with real design tokens and architecture — not throwaway marketing pages.',
    ),
  ],
  faqs: const [
    CareerFaq(
      question: 'How do I apply?',
      answer:
          'Browse open roles below, then submit an application with your CV. Applications route to Careers & HR via our CRM.',
    ),
    CareerFaq(
      question: 'Do you hire remotely?',
      answer:
          'Selected technology and design roles support hybrid or remote arrangements. Site and sales roles are location-based.',
    ),
    CareerFaq(
      question: 'What is the interview process?',
      answer:
          'Typically: application review → HR screen → hiring manager interview → practical assessment → offer. Timeline varies by role.',
    ),
    CareerFaq(
      question: 'Can I submit a general application?',
      answer:
          'Yes. Use the general application form if no role matches — we keep strong candidates in our talent pool.',
    ),
    CareerFaq(
      question: 'Do you offer internships?',
      answer:
          'Yes. Legal, marketing, and technology internships open periodically. Check listings for Internship employment type.',
    ),
  ],
);
