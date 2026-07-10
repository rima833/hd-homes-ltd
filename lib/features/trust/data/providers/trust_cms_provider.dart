import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/features/trust/data/models/trust_center_content.dart';

final trustHubCmsProvider = Provider<TrustHubCms>((ref) => _hubCms);

final _hubCms = TrustHubCms(
  heroHeadline: 'Built on Trust. Driven by Integrity.',
  heroSubheadline:
      'Transparency, regulatory compliance, investor protection, and corporate governance — '
      'centralized for buyers, investors, banks, and partners.',
  pillars: const [
    TrustPillar(title: 'Registered Company', description: 'Fully incorporated and compliant with CAC requirements.', iconName: 'building'),
    TrustPillar(title: 'Experienced Team', description: 'Seasoned professionals across development, finance, and legal.', iconName: 'users'),
    TrustPillar(title: 'Transparent Processes', description: 'Clear documentation and milestone-based delivery.', iconName: 'eye'),
    TrustPillar(title: 'Verified Property Titles', description: 'Title verification and due diligence on every project.', iconName: 'shieldCheck'),
    TrustPillar(title: 'Ethical Business Practices', description: 'Code of conduct enforced across all operations.', iconName: 'scale'),
    TrustPillar(title: 'Customer-Centric Service', description: 'Dedicated support from inquiry through handover.', iconName: 'heart'),
    TrustPillar(title: 'Secure Transactions', description: 'Escrow, banking partners, and payment safeguards.', iconName: 'lock'),
    TrustPillar(title: 'Regulatory Compliance', description: 'AML, KYC, tax, and construction standards adherence.', iconName: 'badgeCheck'),
  ],
  statistics: const [
    TrustStatistic(value: '12', suffix: '+', label: 'Years in Business'),
    TrustStatistic(value: '18', label: 'Projects Completed'),
    TrustStatistic(value: '2,400', suffix: '+', label: 'Clients Served'),
    TrustStatistic(value: '₦45B', suffix: '+', label: 'Investment Value Managed'),
    TrustStatistic(value: '96', suffix: '%', label: 'Customer Satisfaction'),
  ],
  companyOverview:
      'HD Homes Ltd is a premium Nigerian property developer delivering trusted homes, estates, and investment '
      'opportunities with transparency, governance, and long-term value creation.',
  vision: 'To be Africa\'s most trusted PropTech-led property developer.',
  mission: 'To deliver exceptional homes and estates through integrity, innovation, and customer-first service.',
  coreValues: const [
    'Integrity',
    'Excellence',
    'Transparency',
    'Innovation',
    'Customer Focus',
    'Sustainability',
  ],
  profileDownloads: const [
    TrustDownload(title: 'Company Profile', type: 'PDF', size: '3.8 MB'),
    TrustDownload(title: 'Corporate Brochure', type: 'PDF', size: '5.2 MB'),
    TrustDownload(title: 'Annual Overview', type: 'PDF', size: '2.1 MB'),
  ],
  certifications: const [
    TrustCertification(
      title: 'Corporate Affairs Commission Registration',
      issuer: 'CAC Nigeria',
      certificateNumber: 'RC-XXXXXXX',
      issueDate: 'Mar 2014',
      verificationUrl: 'https://search.cac.gov.ng',
    ),
    TrustCertification(
      title: 'Real Estate Developers Association Membership',
      issuer: 'REDAN',
      certificateNumber: 'REDAN-2018-042',
      issueDate: 'Jun 2018',
      expiryDate: 'Jun 2026',
    ),
    TrustCertification(
      title: 'ISO 9001 Quality Management',
      issuer: 'International Standards Organization',
      certificateNumber: 'ISO-9001-2024-HDH',
      issueDate: 'Jan 2024',
      expiryDate: 'Jan 2027',
    ),
    TrustCertification(
      title: 'Health & Safety Certification',
      issuer: 'Nigeria Safety Council',
      certificateNumber: 'NSC-HSE-2025-118',
      issueDate: 'Feb 2025',
      expiryDate: 'Feb 2026',
    ),
  ],
  boardMembers: const [
    TrustGovernanceMember(
      name: 'Dr. Adaeze Okonkwo',
      role: 'Chairperson, Board of Directors',
      bio: 'Corporate governance and finance leadership with 20+ years in real estate.',
    ),
    TrustGovernanceMember(
      name: 'Emeka Nwosu',
      role: 'Chief Executive Officer',
      bio: 'Founder and CEO driving HD Homes\' national expansion strategy.',
    ),
    TrustGovernanceMember(
      name: 'Fatima Bello',
      role: 'Chief Financial Officer',
      bio: 'Oversees financial controls, investor reporting, and audit compliance.',
    ),
    TrustGovernanceMember(
      name: 'Tunde Bakare',
      role: 'Chief Legal & Compliance Officer',
      bio: 'Leads legal affairs, regulatory compliance, and risk management.',
    ),
  ],
  policies: const [
    TrustPolicy(title: 'Code of Conduct', summary: 'Ethical standards for all employees and partners.'),
    TrustPolicy(title: 'Conflict of Interest Policy', summary: 'Disclosure and management of conflicts.'),
    TrustPolicy(title: 'Whistleblower Policy', summary: 'Protected reporting channels for concerns.'),
    TrustPolicy(title: 'Anti-Fraud Policy', summary: 'Zero tolerance for fraud and misrepresentation.'),
    TrustPolicy(title: 'Data Protection Policy', summary: 'NDPR-aligned personal data handling.'),
  ],
  investorProtection: const [
    TrustInvestorProtectionItem(
      title: 'Investment Process',
      description: 'Structured onboarding with documented milestones and transparent communication.',
    ),
    TrustInvestorProtectionItem(
      title: 'Due Diligence',
      description: 'Title verification, feasibility studies, and independent audits before launch.',
    ),
    TrustInvestorProtectionItem(
      title: 'Escrow Process',
      description: 'Milestone-linked payments through regulated banking partners.',
    ),
    TrustInvestorProtectionItem(
      title: 'Payment Security',
      description: 'Multi-layer verification, receipts, and CRM-tracked transactions.',
    ),
    TrustInvestorProtectionItem(
      title: 'Fund Protection',
      description: 'Segregated project accounts and independent monitoring.',
    ),
    TrustInvestorProtectionItem(
      title: 'Investor Rights',
      description: 'Clear contractual rights, reporting access, and dispute resolution.',
    ),
  ],
  legalDocuments: const [
    TrustLegalDocument(title: 'Terms & Conditions', category: 'Legal', version: 'v3.2', updatedAt: 'Jan 2026', size: '420 KB'),
    TrustLegalDocument(title: 'Privacy Policy', category: 'Legal', version: 'v2.8', updatedAt: 'Jan 2026', size: '380 KB'),
    TrustLegalDocument(title: 'Cookie Policy', category: 'Legal', version: 'v1.4', updatedAt: 'Dec 2025', size: '180 KB'),
    TrustLegalDocument(title: 'Purchase Agreement Template', category: 'Sales', version: 'v4.1', updatedAt: 'Mar 2026', size: '1.2 MB'),
    TrustLegalDocument(title: 'Investment Agreement Template', category: 'Investment', version: 'v2.6', updatedAt: 'Feb 2026', size: '980 KB'),
    TrustLegalDocument(title: 'Refund Policy', category: 'Policy', version: 'v1.9', updatedAt: 'Nov 2025', size: '240 KB'),
  ],
  complianceItems: const [
    TrustComplianceItem(title: 'AML Policy', status: 'Compliant', lastReviewed: 'Mar 2026'),
    TrustComplianceItem(title: 'KYC Policy', status: 'Compliant', lastReviewed: 'Mar 2026'),
    TrustComplianceItem(title: 'Anti-Bribery Policy', status: 'Compliant', lastReviewed: 'Feb 2026'),
    TrustComplianceItem(title: 'Tax Compliance', status: 'Compliant', lastReviewed: 'Q1 2026'),
    TrustComplianceItem(title: 'NDPR Data Protection', status: 'Compliant', lastReviewed: 'Jan 2026'),
    TrustComplianceItem(title: 'Construction Standards', status: 'Compliant', lastReviewed: 'Apr 2026'),
  ],
  partners: const [
    TrustPartner(name: 'First Bank of Nigeria', category: 'Banking', description: 'Escrow and mortgage partner.', scope: 'Payment & escrow'),
    TrustPartner(name: 'Leadway Assurance', category: 'Insurance', description: 'Construction and liability coverage.', scope: 'Project insurance'),
    TrustPartner(name: 'Aluko & Oyebode', category: 'Legal', description: 'Corporate and property law counsel.', scope: 'Legal advisory'),
    TrustPartner(name: 'GeoSurvey Nigeria', category: 'Survey', description: 'Land surveying and title verification.', scope: 'Due diligence'),
    TrustPartner(name: 'Lagos State Building Control Agency', category: 'Government', description: 'Building approvals and inspections.', scope: 'Regulatory'),
  ],
  awards: const [
    TrustAward(title: 'Best Luxury Developer — Nigeria Property Awards', year: '2025', issuer: 'NPA'),
    TrustAward(title: 'Excellence in Customer Service', year: '2024', issuer: 'REDAN'),
    TrustAward(title: 'Innovation in PropTech', year: '2024', issuer: 'Africa PropTech Summit'),
    TrustAward(title: 'Sustainable Development Recognition', year: '2023', issuer: 'Green Building Council'),
  ],
  csrInitiatives: const [
    TrustCsrInitiative(
      title: 'HD Homes Scholarship Fund',
      category: 'Education',
      impact: '120 scholarships awarded',
      description: 'Supporting tertiary education for underprivileged youth.',
    ),
    TrustCsrInitiative(
      title: 'Community Health Outreach',
      category: 'Healthcare',
      impact: '8 communities served',
      description: 'Free medical screenings in host communities.',
    ),
    TrustCsrInitiative(
      title: 'Affordable Housing Initiative',
      category: 'Housing',
      impact: '200 units planned',
      description: 'Partnering with government on affordable housing delivery.',
    ),
  ],
  esgMetrics: const [
    TrustEsgMetric(label: 'Solar-powered estates', value: '3', category: 'Environmental'),
    TrustEsgMetric(label: 'Waste recycling rate', value: '72%', category: 'Environmental'),
    TrustEsgMetric(label: 'Women in leadership', value: '42%', category: 'Social'),
    TrustEsgMetric(label: 'Community investment', value: '₦180M', category: 'Social'),
    TrustEsgMetric(label: 'Board independence', value: '60%', category: 'Governance'),
    TrustEsgMetric(label: 'ESG policy compliance', value: '100%', category: 'Governance'),
  ],
  riskItems: const [
    TrustRiskItem(title: 'Construction delays', mitigation: 'Phased delivery, contingency buffers, and weekly monitoring.'),
    TrustRiskItem(title: 'Market fluctuations', mitigation: 'Diversified portfolio and conservative financial planning.'),
    TrustRiskItem(title: 'Regulatory changes', mitigation: 'Proactive compliance team and government liaison.'),
    TrustRiskItem(title: 'Cybersecurity threats', mitigation: 'Encrypted systems, access controls, and regular audits.'),
  ],
  transparencyReports: const [
    TrustTransparencyReport(title: 'Annual Report 2025', period: 'FY 2025', type: 'PDF', size: '6.4 MB'),
    TrustTransparencyReport(title: 'Q1 2026 Investor Update', period: 'Q1 2026', type: 'PDF', size: '2.8 MB'),
    TrustTransparencyReport(title: 'Construction Progress Summary', period: 'Apr 2026', type: 'PDF', size: '4.1 MB'),
    TrustTransparencyReport(title: 'Audit Summary 2025', period: 'FY 2025', type: 'PDF', size: '1.6 MB'),
  ],
  faqs: const [
    TrustFaq(
      category: 'Property Ownership',
      question: 'How does HD Homes verify property titles?',
      answer: 'Every project undergoes independent survey, legal search, and CAC-verified documentation before sales commence.',
    ),
    TrustFaq(
      category: 'Payment Security',
      question: 'Are my payments protected?',
      answer: 'Yes. Payments are processed through regulated banking partners with escrow and milestone-based release.',
    ),
    TrustFaq(
      category: 'Investment Safety',
      question: 'What safeguards exist for investors?',
      answer: 'Due diligence reports, segregated accounts, contractual investor rights, and regular transparency reporting.',
    ),
    TrustFaq(
      category: 'Legal Compliance',
      question: 'Is HD Homes registered with regulators?',
      answer: 'HD Homes is CAC-registered and maintains memberships with REDAN and applicable industry bodies.',
    ),
    TrustFaq(
      category: 'Escrow',
      question: 'How does the escrow process work?',
      answer: 'Funds are held in designated escrow accounts and released upon verified construction milestones.',
    ),
    TrustFaq(
      category: 'Privacy',
      question: 'How is my personal data protected?',
      answer: 'We comply with NDPR requirements with encryption, access controls, and a published privacy policy.',
    ),
  ],
  timeline: const [
    TrustTimelineEvent(year: '2014', title: 'Company Founded', description: 'HD Homes Ltd incorporated in Lagos, Nigeria.'),
    TrustTimelineEvent(year: '2018', title: 'REDAN Membership', description: 'Joined the Real Estate Developers Association of Nigeria.'),
    TrustTimelineEvent(year: '2020', title: 'Horizon Gardens Launch', description: 'Flagship Lekki estate groundbreaking ceremony.'),
    TrustTimelineEvent(year: '2023', title: 'PropTech Platform', description: 'Digital platform launch for buyers and investors.'),
    TrustTimelineEvent(year: '2025', title: 'National Expansion', description: 'Abuja and Port Harcourt developments announced.'),
    TrustTimelineEvent(year: '2026', title: 'Trust Center Launch', description: 'Enterprise transparency hub goes live.'),
  ],
  trustScore: 94,
  trustScoreBreakdown: const [
    TrustScoreBreakdown(label: 'Regulatory compliance', score: 96, maxScore: 100),
    TrustScoreBreakdown(label: 'Customer satisfaction', score: 96, maxScore: 100),
    TrustScoreBreakdown(label: 'Project delivery', score: 92, maxScore: 100),
    TrustScoreBreakdown(label: 'Transparency', score: 95, maxScore: 100),
    TrustScoreBreakdown(label: 'Corporate governance', score: 93, maxScore: 100),
    TrustScoreBreakdown(label: 'ESG commitment', score: 90, maxScore: 100),
  ],
  dashboardMetrics: const [
    TrustDashboardMetric(label: 'Active developments', value: '6'),
    TrustDashboardMetric(label: 'Projects delivered', value: '18'),
    TrustDashboardMetric(label: 'Customer satisfaction', value: '96%'),
    TrustDashboardMetric(label: 'Avg response time', value: '2.4 hrs'),
    TrustDashboardMetric(label: 'Compliance status', value: 'Green'),
    TrustDashboardMetric(label: 'ESG initiatives', value: '12 active'),
  ],
  complianceDeadlines: const [
    TrustComplianceDeadline(item: 'REDAN membership renewal', dueDate: 'Jun 2026', status: 'On track'),
    TrustComplianceDeadline(item: 'ISO 9001 surveillance audit', dueDate: 'Sep 2026', status: 'Scheduled'),
    TrustComplianceDeadline(item: 'Annual tax filing', dueDate: 'Jun 2026', status: 'In progress'),
    TrustComplianceDeadline(item: 'HSE certification renewal', dueDate: 'Feb 2027', status: 'On track'),
  ],
);
