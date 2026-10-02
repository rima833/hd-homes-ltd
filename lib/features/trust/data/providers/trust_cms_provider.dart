import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/constants/brand_copy.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/cms/domain/data/hub_page_cms.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/home/data/providers/home_content_provider.dart';
import 'package:hdhomesproject/features/trust/data/models/trust_center_content.dart';
import 'package:intl/intl.dart';

final trustHubCmsProvider = Provider<TrustHubCms>((ref) {
  final base = _hubCms;
  final home = ref.watch(homeContentProvider);
  final profile = ref.watch(publishedDigitalCompanyProfileProvider).valueOrNull;
  final liveLegal = ref.watch(publishedLegalPagesProvider).valueOrNull ??
      const <CmsPageRecord>[];

  var overlay = const HubPageHeroOverlay();
  if (ref.watch(supabaseConfiguredProvider)) {
    overlay = hubHeroFromPage(
      ref.watch(publishedPageBySlugProvider('trust')).valueOrNull,
    );
  }

  final livePillars = [
    for (final item in home.whyChoose)
      TrustPillar(
        title: item.title,
        description: item.description,
        iconName: item.iconName,
      ),
  ];

  final liveDocs = [
    for (final page in liveLegal)
      TrustLegalDocument(
        title: page.title,
        category: _legalCategory(page),
        updatedAt: page.updatedAt == null
            ? ''
            : DateFormat('MMM yyyy').format(page.updatedAt!),
        slug: page.slug,
      ),
  ];

  return TrustHubCms(
    heroHeadline: overlay.headline ?? base.heroHeadline,
    heroSubheadline: overlay.subheadline ?? base.heroSubheadline,
    backgroundImageUrl: overlay.backgroundImageUrl ?? base.backgroundImageUrl,
    backgroundVideoUrl: overlay.backgroundVideoUrl ?? base.backgroundVideoUrl,
    pillars: livePillars.isNotEmpty ? livePillars : base.pillars,
    companyOverview: overlay.body ?? base.companyOverview,
    investorProtection: base.investorProtection,
    legalDocuments: liveDocs.isNotEmpty ? liveDocs : base.legalDocuments,
    profilePdfUrl: _usableUrl(profile?.pdfUrl) ?? base.profilePdfUrl,
    profileBrochureUrl:
        _usableUrl(profile?.brochureUrl) ?? base.profileBrochureUrl,
    profileViewUrl: _usableUrl(profile?.viewUrl) ?? base.profileViewUrl,
  );
});

String _legalCategory(CmsPageRecord page) {
  final fromContent = page.content['category'];
  if (fromContent is String && fromContent.trim().isNotEmpty) {
    return fromContent.trim();
  }
  final slug = page.slug.toLowerCase();
  if (slug.contains('privacy') ||
      slug.contains('terms') ||
      slug.contains('cookie')) {
    return 'Legal';
  }
  if (slug.contains('refund') || slug.contains('policy')) return 'Policy';
  return 'Document';
}

String? _usableUrl(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty || trimmed == '#') return null;
  return trimmed;
}

final _hubCms = TrustHubCms(
  heroHeadline: 'Built on Trust. Driven by Integrity.',
  heroSubheadline:
      'Transparency, regulatory compliance, investor protection, and corporate governance — '
      'centralized for buyers, investors, banks, and partners.',
  pillars: const [
    TrustPillar(
      title: 'Registered Company',
      description: 'Fully incorporated and compliant with CAC requirements.',
      iconName: 'building',
    ),
    TrustPillar(
      title: 'Experienced Team',
      description: 'Seasoned professionals across development, finance, and legal.',
      iconName: 'users',
    ),
    TrustPillar(
      title: 'Transparent Processes',
      description: 'Clear documentation and milestone-based delivery.',
      iconName: 'eye',
    ),
    TrustPillar(
      title: 'Verified Property Titles',
      description: 'Title verification and due diligence on every project.',
      iconName: 'shieldCheck',
    ),
    TrustPillar(
      title: 'Ethical Business Practices',
      description: 'Code of conduct enforced across all operations.',
      iconName: 'scale',
    ),
    TrustPillar(
      title: 'Customer-Centric Service',
      description: 'Dedicated support from inquiry through handover.',
      iconName: 'heart',
    ),
    TrustPillar(
      title: 'Secure Transactions',
      description: 'Escrow, banking partners, and payment safeguards.',
      iconName: 'lock',
    ),
    TrustPillar(
      title: 'Regulatory Compliance',
      description: 'AML, KYC, tax, and construction standards adherence.',
      iconName: 'badgeCheck',
    ),
  ],
  companyOverview: BrandCopy.story,
  investorProtection: const [
    TrustInvestorProtectionItem(
      title: 'Investment process',
      description:
          'Structured onboarding with documented milestones and transparent communication.',
    ),
    TrustInvestorProtectionItem(
      title: 'Due diligence',
      description:
          'Title verification, feasibility studies, and independent reviews before launch.',
    ),
    TrustInvestorProtectionItem(
      title: 'Escrow & payment security',
      description:
          'Milestone-linked payments through regulated banking partners with receipts in CRM.',
    ),
    TrustInvestorProtectionItem(
      title: 'Investor rights',
      description:
          'Clear contractual rights, reporting access, and a defined dispute path.',
    ),
  ],
  legalDocuments: const [
    TrustLegalDocument(
      title: 'Terms & Conditions',
      category: 'Legal',
      slug: 'terms',
    ),
    TrustLegalDocument(
      title: 'Privacy Policy',
      category: 'Legal',
      slug: 'privacy',
    ),
    TrustLegalDocument(
      title: 'Cookie Policy',
      category: 'Legal',
      slug: 'cookies',
    ),
    TrustLegalDocument(
      title: 'Refund Policy',
      category: 'Policy',
      slug: 'refund-policy',
    ),
  ],
);
