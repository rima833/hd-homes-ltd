import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/features/investment/data/models/investment_hub_content.dart';

final investmentHubCmsProvider = Provider<InvestmentHubCms>((ref) => _cms);

final _cms = InvestmentHubCms(
  heroHeadline: 'Grow Your Wealth Through Nigerian Real Estate.',
  heroSubheadline:
      'Structured investment products, transparent reporting, escrow protection, '
      'and institutional-grade developments — built for local and diaspora investors.',
  pillars: const [
    InvestmentPillar(
      title: 'Proven Track Record',
      description: '15+ years delivering premium estates across Lagos, Abuja, and Port Harcourt.',
      iconName: 'trendingUp',
    ),
    InvestmentPillar(
      title: 'Transparent Reporting',
      description: 'Quarterly updates, construction milestones, and audited financial summaries.',
      iconName: 'fileBarChart',
    ),
    InvestmentPillar(
      title: 'Escrow Protection',
      description: 'Milestone-linked payments through regulated banking partners.',
      iconName: 'shield',
    ),
    InvestmentPillar(
      title: 'Strong ROI Potential',
      description: 'Target 15–22% returns across off-plan and rental income products.',
      iconName: 'percent',
    ),
    InvestmentPillar(
      title: 'Diversified Portfolio',
      description: 'Residential, commercial, land banking, and fractional opportunities.',
      iconName: 'pieChart',
    ),
    InvestmentPillar(
      title: 'Investor Support',
      description: 'Dedicated investor relations team and digital portfolio access.',
      iconName: 'headphones',
    ),
  ],
  statistics: const [
    InvestmentStatistic(value: '₦45B', suffix: '+', label: 'Assets Under Management'),
    InvestmentStatistic(value: '850', suffix: '+', label: 'Active Investors'),
    InvestmentStatistic(value: '18', label: 'Investment Products'),
    InvestmentStatistic(value: '96', suffix: '%', label: 'Investor Satisfaction'),
    InvestmentStatistic(value: '15', suffix: '+', label: 'Years Track Record'),
  ],
  opportunities: const [
    InvestmentOpportunity(
      id: 'inv-hg',
      title: 'Horizon Gardens — Phase 1',
      location: 'Lekki, Lagos',
      type: InvestmentProductType.offPlan,
      roi: '18–22%',
      duration: '3–5 years',
      risk: 'Moderate',
      minInvestment: '₦15M',
      status: 'Open',
      summary: 'Flagship lifestyle estate with strong rental demand and capital appreciation.',
      estateSlug: 'horizon-gardens',
    ),
    InvestmentOpportunity(
      id: 'inv-eh',
      title: 'Emerald Heights Estate',
      location: 'Abuja, FCT',
      type: InvestmentProductType.capitalGrowth,
      roi: '15–18%',
      duration: '4–6 years',
      risk: 'Low–Moderate',
      minInvestment: '₦20M',
      status: 'Open',
      summary: 'Premium Abuja development in a high-growth government corridor.',
      estateSlug: 'emerald-heights',
    ),
    InvestmentOpportunity(
      id: 'inv-rental',
      title: 'Lekki Rental Income Fund',
      location: 'Lekki Corridor',
      type: InvestmentProductType.rentalIncome,
      roi: '12–14% yield',
      duration: 'Ongoing',
      risk: 'Low',
      minInvestment: '₦10M',
      status: 'Limited',
      summary: 'Stabilized rental portfolio with quarterly distributions.',
    ),
    InvestmentOpportunity(
      id: 'inv-land',
      title: 'Green Valley Land Banking',
      location: 'Port Harcourt',
      type: InvestmentProductType.landBanking,
      roi: '20–25%',
      duration: '2–4 years',
      risk: 'Moderate–High',
      minInvestment: '₦8M',
      status: 'Open',
      summary: 'Strategic land parcels in emerging growth corridors.',
      estateSlug: 'green-valley',
    ),
    InvestmentOpportunity(
      id: 'inv-commercial',
      title: 'Chevron Commercial Plots',
      location: 'Lekki, Lagos',
      type: InvestmentProductType.commercial,
      roi: '16–20%',
      duration: '5+ years',
      risk: 'Moderate',
      minInvestment: '₦25M',
      status: 'Waitlist',
      summary: 'Commercial plots within HD Homes mixed-use developments.',
    ),
    InvestmentOpportunity(
      id: 'inv-fractional',
      title: 'Fractional Estate Shares',
      location: 'Nationwide',
      type: InvestmentProductType.fractional,
      roi: '14–16%',
      duration: 'Flexible',
      risk: 'Moderate',
      minInvestment: '₦2M',
      status: 'Coming Soon',
      summary: 'Lower entry point into premium developments — Investor Portal integration.',
    ),
  ],
  processSteps: const [
    InvestmentProcessStep(
      step: 1,
      title: 'Discover & Research',
      description: 'Explore opportunities, download investment packs, and use ROI tools.',
    ),
    InvestmentProcessStep(
      step: 2,
      title: 'Consultation',
      description: 'Book a session with Investor Relations to align goals and risk appetite.',
    ),
    InvestmentProcessStep(
      step: 3,
      title: 'Due Diligence',
      description: 'Review title documents, feasibility studies, and legal agreements.',
    ),
    InvestmentProcessStep(
      step: 4,
      title: 'Investment & Escrow',
      description: 'Sign agreements and fund through regulated escrow accounts.',
    ),
    InvestmentProcessStep(
      step: 5,
      title: 'Monitor & Report',
      description: 'Track construction, receive quarterly reports, and access Investor Portal.',
    ),
    InvestmentProcessStep(
      step: 6,
      title: 'Returns & Exit',
      description: 'Receive distributions, resale support, or handover upon completion.',
    ),
  ],
  marketInsights: const [
    InvestmentMarketInsight(
      title: 'Lekki corridor demand',
      value: '+18% YoY',
      trend: 'Rising',
      summary: 'Strong buyer and rental demand driven by infrastructure expansion.',
    ),
    InvestmentMarketInsight(
      title: 'Abuja premium segment',
      value: '+12% YoY',
      trend: 'Stable growth',
      summary: 'Government relocation and diaspora investment sustaining prices.',
    ),
    InvestmentMarketInsight(
      title: 'Off-plan premium',
      value: '22% avg uplift',
      trend: 'At completion',
      summary: 'Early investors in HD Homes estates historically outperform market.',
    ),
    InvestmentMarketInsight(
      title: 'Rental yield — Lagos',
      value: '8–12%',
      trend: 'Stable',
      summary: 'Institutional rental demand in gated estates remains strong.',
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
  downloads: const [
    InvestmentDownload(title: 'Investment Overview Pack', type: 'PDF', size: '4.8 MB'),
    InvestmentDownload(title: 'Horizon Gardens Investment Brief', type: 'PDF', size: '2.4 MB'),
    InvestmentDownload(title: 'Risk Disclosure Statement', type: 'PDF', size: '680 KB'),
    InvestmentDownload(title: 'Sample Investment Agreement', type: 'PDF', size: '1.1 MB'),
  ],
  faqs: const [
    InvestmentFaq(
      question: 'What is the minimum investment amount?',
      answer: 'Minimums vary by product — from ₦2M (fractional, coming soon) to ₦25M for commercial plots. Most estates start at ₦15M.',
    ),
    InvestmentFaq(
      question: 'How are my funds protected?',
      answer: 'Payments flow through regulated escrow accounts with milestone-based release. See our Trust Center for full safeguards.',
    ),
    InvestmentFaq(
      question: 'Can diaspora investors participate?',
      answer: 'Yes. We support international transfers, virtual consultations, and digital document signing with dedicated IR support.',
    ),
    InvestmentFaq(
      question: 'How do I track my investment?',
      answer: 'Investors receive quarterly reports and will access the Investor Portal (Volume 3) for live construction and financial updates.',
    ),
    InvestmentFaq(
      question: 'What returns can I expect?',
      answer: 'Returns vary by product and market. Off-plan targets 18–22% ROI; rental income 12–14% yield. Past performance is not a guarantee.',
    ),
    InvestmentFaq(
      question: 'How do I book an investor consultation?',
      answer: 'Use the consultation form below or contact Investor Relations via the Contact Hub.',
    ),
  ],
);
