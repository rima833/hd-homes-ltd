import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/growth/models/growth_models.dart';
import 'package:hdhomesproject/core/growth/personalization/visitor_profile.dart';
import 'package:hdhomesproject/features/properties/data/models/marketplace_property.dart';
import 'package:hdhomesproject/features/properties/data/providers/marketplace_listings_provider.dart';

/// AI-generated investment insights (ML integration in future volumes).
final investmentInsightsProvider = Provider<List<InvestmentInsight>>((ref) {
  final properties = ref.watch(marketplaceListingsProvider);
  final profile = ref.watch(visitorProfileProvider);

  final investProps = properties.where((p) => p.purpose == PropertyPurpose.invest).take(3);
  if (investProps.isEmpty) {
    return _defaultInsights();
  }

  return investProps.map((p) {
    return InvestmentInsight(
      title: p.title,
      value: p.roiEstimate,
      trend: p.capitalAppreciation,
      riskLevel: p.riskLevel,
      summary:
          'Rental yield ${p.rentalYield}. ${profile.preferredLocations.isNotEmpty ? 'Aligned with interest in ${profile.preferredLocations.first}.' : 'Strong fundamentals for Nigerian real estate investors.'}',
    );
  }).toList();
});

List<InvestmentInsight> _defaultInsights() => const [
      InvestmentInsight(
        title: 'Horizon Gardens Estate',
        value: '18–22% ROI',
        trend: '+12% YoY appreciation',
        riskLevel: 'Moderate',
        summary: 'Flagship Lekki development with strong rental demand and phased delivery.',
      ),
      InvestmentInsight(
        title: 'Emerald Heights Abuja',
        value: '15–18% ROI',
        trend: '+9% YoY appreciation',
        riskLevel: 'Low–Moderate',
        summary: 'Government corridor growth with premium finish and investor protections.',
      ),
    ];

/// Draft AI content suggestions (requires human approval before publish).
class ContentDraft {
  const ContentDraft({
    required this.type,
    required this.title,
    required this.body,
    required this.status,
  });

  final String type;
  final String title;
  final String body;
  final String status;
}

List<ContentDraft> generateContentDrafts({required String subject, required String context}) {
  return [
    ContentDraft(
      type: 'Meta description',
      title: 'SEO — $subject',
      body: 'Discover $subject with HD Homes — $context. Book an inspection or explore flexible payment plans.',
      status: 'Pending approval',
    ),
    ContentDraft(
      type: 'Social caption',
      title: 'Instagram — $subject',
      body: '✨ $subject\n$context\n#HDHomes #NigerianRealEstate #LuxuryLiving',
      status: 'Pending approval',
    ),
    ContentDraft(
      type: 'Email subject',
      title: 'Campaign — $subject',
      body: 'Your next home awaits: $subject',
      status: 'Pending approval',
    ),
  ];
}

final contentDraftsProvider = Provider<List<ContentDraft>>((ref) {
  return generateContentDrafts(
    subject: 'Horizon Gardens 3BR Terrace',
    context: 'Premium terrace homes in Lekki with flexible installment plans.',
  );
});
