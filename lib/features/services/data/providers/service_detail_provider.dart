import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/features/services/data/models/service_models.dart';
import 'package:hdhomesproject/features/services/data/providers/services_catalog_provider.dart';

final serviceDetailProvider =
    Provider.family<ServiceDetailContent?, String>((ref, slug) {
  final catalog = ref.watch(servicesCatalogProvider);
  final summary = catalog.cast<ServiceSummary?>().firstWhere(
        (s) => s?.slug == slug,
        orElse: () => null,
      );
  if (summary == null) return null;
  return _buildDetail(summary, catalog);
});

final relatedServicesProvider =
    Provider.family<List<ServiceSummary>, String>((ref, slug) {
  final detail = ref.watch(serviceDetailProvider(slug));
  if (detail == null) return [];
  final catalog = ref.watch(servicesCatalogProvider);
  return catalog
      .where(
        (s) =>
            s.slug != slug &&
            s.categoryId == detail.summary.categoryId,
      )
      .take(3)
      .toList();
});

/// AI recommendations based on service category (placeholder for behavior tracking).
final aiServiceRecommendationsProvider =
    Provider.family<List<ServiceSummary>, String>((ref, slug) {
  final detail = ref.watch(serviceDetailProvider(slug));
  if (detail == null) return [];
  final catalog = ref.watch(servicesCatalogProvider);
  final recSlugs = detail.aiRecommendations;
  return catalog.where((s) => recSlugs.contains(s.slug)).toList();
});

ServiceDetailContent _buildDetail(ServiceSummary s, List<ServiceSummary> catalog) {
  final recommendations = _recommendationsFor(s);

  return ServiceDetailContent(
    summary: s,
    overview:
        '${s.name} is a flagship HD Homes offering designed for clients who demand professionalism, '
        'transparency, and measurable outcomes. ${s.shortDescription}',
    audience: _audienceFor(s.categoryId),
    businessValue:
        'Reduce risk, accelerate delivery, and maximize long-term value through HD Homes\' integrated approach.',
    benefits: s.keyBenefits.isNotEmpty
        ? s.keyBenefits
        : const [
            'Professional expertise',
            'Quality assurance',
            'Transparent communication',
            'Regulatory compliance',
            'Long-term value',
          ],
    processSteps: const [
      ServiceProcessStep(title: 'Consultation', description: 'Understand your goals, budget, and timeline.'),
      ServiceProcessStep(title: 'Planning', description: 'Site assessment, scope definition, and feasibility.'),
      ServiceProcessStep(title: 'Proposal', description: 'Detailed scope, timeline, and transparent pricing.'),
      ServiceProcessStep(title: 'Execution', description: 'Managed delivery with milestone reporting.'),
      ServiceProcessStep(title: 'Quality Review', description: 'Inspections and compliance checkpoints.'),
      ServiceProcessStep(title: 'Delivery', description: 'Handover with documentation and warranties.'),
      ServiceProcessStep(title: 'Support', description: 'After-sales support and ongoing partnership.'),
    ],
    deliverables: _deliverablesFor(s.categoryId),
    pricing: _pricingFor(s),
    gallery: ServiceGallery(
      images: List.generate(6, (i) => 'gallery_${s.slug}_$i'),
      hasVideo: true,
      hasBeforeAfter: s.categoryId == ServiceCategoryId.construction,
    ),
    relatedProjects: [
      ServiceRelatedProject(
        name: 'Horizon Gardens',
        location: 'Lekki, Lagos',
        outcome: '240-unit estate · Phase 1 at 78%',
      ),
      ServiceRelatedProject(
        name: 'Emerald Heights',
        location: 'Abuja',
        outcome: '180-unit mixed development',
      ),
    ],
    faqs: [
      ServiceFaqItem(
        question: 'Who is ${s.name} best suited for?',
        answer: _audienceFor(s.categoryId),
      ),
      ServiceFaqItem(
        question: 'How long does a typical engagement take?',
        answer: 'Timelines vary by scope — from 2 weeks for valuations to 18–36 months for developments.',
      ),
      ServiceFaqItem(
        question: 'Can I get a custom quote?',
        answer: 'Yes. Every engagement begins with a free consultation and tailored proposal.',
      ),
    ],
    aiRecommendations: recommendations,
    eligibilityQuestions: _eligibilityFor(s),
  );
}

List<String> _recommendationsFor(ServiceSummary s) => switch (s.categoryId) {
      ServiceCategoryId.realEstate => ['property-valuation', 'investment-advisory', 'land-documentation'],
      ServiceCategoryId.construction => ['architectural-design', 'project-management', 'property-valuation'],
      ServiceCategoryId.designPlanning => ['residential-construction', 'structural-engineering', 'project-management'],
      ServiceCategoryId.propertyManagement => ['rental-management', 'property-valuation', 'legal-advisory'],
      ServiceCategoryId.professionalServices => switch (s.slug) {
          'property-valuation' => ['investment-advisory', 'surveying', 'legal-advisory'],
          'surveying' => ['land-documentation', 'architectural-design', 'civil-engineering'],
          'investment-advisory' => ['property-investment', 'property-valuation', 'rental-management'],
          _ => ['consultancy', 'project-management', 'legal-advisory'],
        },
    };

String _audienceFor(ServiceCategoryId id) => switch (id) {
      ServiceCategoryId.realEstate =>
        'Homebuyers, investors, developers, and diaspora clients seeking verified property solutions.',
      ServiceCategoryId.construction =>
        'Landowners, developers, and corporates planning new builds or renovations.',
      ServiceCategoryId.designPlanning =>
        'Clients who need professional design before construction or renovation.',
      ServiceCategoryId.propertyManagement =>
        'Property owners, estate associations, and investors with rental portfolios.',
      ServiceCategoryId.professionalServices =>
        'Individuals and businesses requiring certified advisory, documentation, or valuation.',
    };

List<String> _deliverablesFor(ServiceCategoryId id) => switch (id) {
      ServiceCategoryId.realEstate => const [
          'Property listings or acquisition reports',
          'Transaction documentation',
          'Investment analysis',
          'Handover certificates',
        ],
      ServiceCategoryId.construction => const [
          'Construction drawings',
          'Progress reports',
          'Quality inspection certificates',
          'Final handover package',
        ],
      ServiceCategoryId.designPlanning => const [
          'Architectural drawings',
          '3D renders',
          'BOQ and specifications',
          'Regulatory approval support',
        ],
      ServiceCategoryId.propertyManagement => const [
          'Management agreements',
          'Monthly reports',
          'Maintenance logs',
          'Financial statements',
        ],
      ServiceCategoryId.professionalServices => const [
          'Certified reports',
          'Legal opinions',
          'Survey plans',
          'Advisory memoranda',
        ],
    };

ServicePricing? _pricingFor(ServiceSummary s) {
  if (s.categoryId == ServiceCategoryId.professionalServices) {
    return const ServicePricing(
      label: 'Starting from',
      startingPrice: '₦150,000',
      pricingType: 'Custom quote',
      note: 'Final pricing depends on scope, location, and urgency.',
    );
  }
  if (s.categoryId == ServiceCategoryId.construction) {
    return const ServicePricing(
      label: 'Starting from',
      startingPrice: '₦8M',
      pricingType: 'Per project',
      note: 'Turnkey packages available — request a detailed proposal.',
    );
  }
  return null;
}

List<ServiceEligibilityQuestion> _eligibilityFor(ServiceSummary s) => [
      ServiceEligibilityQuestion(
        question: 'What is your primary goal?',
        options: const ['Buy property', 'Build/develop', 'Invest', 'Manage existing property'],
        recommendedServiceSlugs: {
          'Buy property': ['property-sales', 'property-valuation'],
          'Build/develop': ['turnkey-construction', 'architectural-design'],
          'Invest': ['investment-advisory', 'property-investment'],
          'Manage existing property': ['estate-management', 'rental-management'],
        },
      ),
      ServiceEligibilityQuestion(
        question: 'Do you have land or property already?',
        options: const ['Yes — documented', 'Yes — pending docs', 'No — need acquisition'],
        recommendedServiceSlugs: {
          'Yes — documented': [s.slug],
          'Yes — pending docs': ['land-documentation', 'surveying', s.slug],
          'No — need acquisition': ['property-acquisition', 'consultancy'],
        },
      ),
    ];

ProjectEstimateResult estimateProject({
  required String projectType,
  required double sizeSqm,
  required int budgetMillions,
  required String location,
  required String timeline,
}) {
  final baseCost = sizeSqm * (projectType.contains('Commercial') ? 85000 : 65000);
  final locationFactor = location.contains('Lagos') ? 1.15 : 1.0;
  final low = (baseCost * locationFactor * 0.9 / 1000000).round();
  final high = (baseCost * locationFactor * 1.2 / 1000000).round();

  return ProjectEstimateResult(
    costRange: '₦${low}M – ₦${high}M',
    duration: timeline == 'Urgent (< 6 months)' ? '6–12 months' : '12–24 months',
    suggestedServices: projectType.contains('Build')
        ? ['architectural-design', 'turnkey-construction', 'project-management']
        : ['property-sales', 'property-valuation', 'legal-advisory'],
    consultationNote: budgetMillions < low
        ? 'Your budget may need adjustment — book a consultation for optimization strategies.'
        : 'Your budget aligns with typical project ranges. Book a consultation for a precise quote.',
  );
}
