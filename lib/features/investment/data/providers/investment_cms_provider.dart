import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/cms/domain/data/hub_page_cms.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/investment/data/models/investment_hub_content.dart';

final investmentHubCmsProvider = Provider<InvestmentHubCms>((ref) {
  final base = _cms;
  if (!ref.watch(supabaseConfiguredProvider)) return base;
  final overlay = hubHeroFromPage(
    ref.watch(publishedPageBySlugProvider('investment')).valueOrNull,
  );
  return InvestmentHubCms(
    heroHeadline: overlay.headline ?? base.heroHeadline,
    heroSubheadline: overlay.subheadline ?? base.heroSubheadline,
    backgroundImageUrl: overlay.backgroundImageUrl ?? base.backgroundImageUrl,
    backgroundVideoUrl: overlay.backgroundVideoUrl ?? base.backgroundVideoUrl,
    pillars: base.pillars,
    statistics: const [],
    processSteps: base.processSteps,
    testimonials: const [],
    protectionSummary: base.protectionSummary,
    faqs: base.faqs,
  );
});

final _cms = InvestmentHubCms(
  heroHeadline: 'Grow Your Wealth Through Nigerian Real Estate.',
  heroSubheadline:
      'Structured investment products, transparent reporting, escrow protection, '
      'and institutional-grade developments — built for local and diaspora investors.',
  pillars: const [
    InvestmentPillar(
      title: 'Proven Track Record',
      description:
          'Estate developments across Lagos, Abuja, and Port Harcourt.',
      iconName: 'trendingUp',
      imageUrl: '',
    ),
    InvestmentPillar(
      title: 'Transparent Reporting',
      description:
          'Quarterly updates, construction milestones, and audited financial summaries.',
      iconName: 'fileBarChart',
      imageUrl: '',
    ),
    InvestmentPillar(
      title: 'Escrow Protection',
      description:
          'Milestone-linked payments through regulated banking partners.',
      iconName: 'shield',
      imageUrl: '',
    ),
    InvestmentPillar(
      title: 'Strong ROI Potential',
      description:
          'Each product has its own offering. Returns are not guaranteed.',
      iconName: 'percent',
      imageUrl: '',
    ),
    InvestmentPillar(
      title: 'Diversified Portfolio',
      description:
          'Residential, commercial, land banking, and fractional opportunities.',
      iconName: 'pieChart',
      imageUrl: '',
    ),
    InvestmentPillar(
      title: 'Investor Support',
      description:
          'Dedicated investor relations team and digital portfolio access.',
      iconName: 'headphones',
      imageUrl: '',
    ),
  ],
  statistics: const [
    InvestmentStatistic(
      value: '₦45B',
      suffix: '+',
      label: 'Assets Under Management',
    ),
    InvestmentStatistic(value: '850', suffix: '+', label: 'Active Investors'),
    InvestmentStatistic(value: '18', label: 'Investment Products'),
    InvestmentStatistic(
      value: '96',
      suffix: '%',
      label: 'Investor Satisfaction',
    ),
    InvestmentStatistic(value: '15', suffix: '+', label: 'Years Track Record'),
  ],
  processSteps: const [
    InvestmentProcessStep(
      step: 1,
      title: 'Discover & Research',
      description:
          'Explore opportunities, review live market insights, and use ROI tools to make informed decisions.',
      iconName: 'search',
    ),
    InvestmentProcessStep(
      step: 2,
      title: 'Consultation',
      description:
          'Book a session with Investor Relations to align your goals and risk appetite.',
      iconName: 'users',
    ),
    InvestmentProcessStep(
      step: 3,
      title: 'Due Diligence',
      description:
          'Review title documents, feasibility studies, and legal agreements for complete clarity.',
      iconName: 'fileCheck',
    ),
    InvestmentProcessStep(
      step: 4,
      title: 'Investment & Escrow',
      description:
          'Sign agreements and fund through regulated escrow accounts for maximum security.',
      iconName: 'shieldLock',
    ),
    InvestmentProcessStep(
      step: 5,
      title: 'Monitor & Report',
      description:
          'Track construction progress, receive quarterly reports, and access your Investor Portal.',
      iconName: 'lineChart',
    ),
    InvestmentProcessStep(
      step: 6,
      title: 'Returns & Exit',
      description:
          'Receive distributions, resale support, or handover upon project completion.',
      iconName: 'returns',
    ),
  ],
  testimonials: const [
    InvestmentTestimonial(
      name: 'Chidi Okafor',
      role: 'Diaspora Investor · UK',
      quote:
          'HD Homes gives me quarterly transparency I never got elsewhere. My Horizon Gardens allocation is tracking above forecast.',
      portfolio: '₦48M across 2 estates',
    ),
    InvestmentTestimonial(
      name: 'Amina Bello',
      role: 'Portfolio Investor · Abuja',
      quote:
          'The escrow structure and legal documentation gave me confidence to diversify into off-plan and rental income products.',
      portfolio: '₦120M diversified portfolio',
    ),
    InvestmentTestimonial(
      name: 'James Okonkwo',
      role: 'Institutional Partner',
      quote:
          'Construction reporting, audited summaries, and direct IR access make HD Homes a credible PropTech investment partner.',
      portfolio: '₦350M co-investment',
    ),
  ],
  protectionSummary:
      'HD Homes investor protection includes due diligence, segregated escrow accounts, contractual investor rights, '
      'quarterly transparency reporting, and dispute resolution. Full details in our Trust Center.',
  faqs: const [
    InvestmentFaq(
      question: 'What is the minimum investment amount?',
      answer:
          'Minimums are set on each product. The listing and the offering documents state the amount for that opportunity.',
    ),
    InvestmentFaq(
      question: 'How are my funds protected?',
      answer:
          'Payments flow through regulated escrow accounts with milestone-based release. See our Trust Center for full safeguards.',
    ),
    InvestmentFaq(
      question: 'Can diaspora investors participate?',
      answer:
          'Yes. We support international transfers, virtual consultations, and digital document signing with dedicated IR support.',
    ),
    InvestmentFaq(
      question: 'How do I track my investment?',
      answer:
          'Signed-in investors use the Investor Portal for documents, reports, and payment history.',
    ),
    InvestmentFaq(
      question: 'What returns can I expect?',
      answer:
          'Returns depend on the product, the project, and the market. HD Homes does not guarantee a return. Read the offering documents before you commit.',
    ),
    InvestmentFaq(
      question: 'How do I book an investor consultation?',
      answer:
          'Use the consultation form below or contact Investor Relations via the Contact Hub.',
    ),
  ],
);
