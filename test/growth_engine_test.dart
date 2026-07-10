import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/core/growth/ai/investment_advisor.dart';
import 'package:hdhomesproject/core/growth/lead_scoring/smart_lead_scoring.dart';
import 'package:hdhomesproject/core/growth/models/growth_models.dart';
import 'package:hdhomesproject/core/growth/personalization/visitor_profile.dart';
import 'package:hdhomesproject/core/growth/seo/seo_engine.dart';
import 'package:hdhomesproject/features/contact/data/models/contact_content.dart';
import 'package:hdhomesproject/features/search/data/providers/search_intelligence_provider.dart';

void main() {
  test('parseAiSearchQuery extracts location and bedrooms', () {
    final result = parseAiSearchQuery('affordable 3-bedroom homes in Abuja with installment');
    expect(result.extractedCriteria.any((c) => c.contains('Abuja')), isTrue);
    expect(result.extractedCriteria.any((c) => c.contains('Bedrooms')), isTrue);
    expect(result.confidence, greaterThan(50));
  });

  test('computeSmartLeadScore elevates engaged visitors', () {
    const routing = LeadRoutingResult(
      score: 55,
      department: 'Sales',
      assignedTo: 'Property Advisor',
      priority: LeadPriority.normal,
      pipelineStage: CrmPipelineStage.newLead,
      summary: 'test',
    );
    const profile = VisitorProfile(
      propertyIdsViewed: ['h001', 'h002', 'h003'],
      pagesViewed: ['/properties', '/search', '/contact'],
      downloadCount: 1,
    );

    final smart = computeSmartLeadScore(baseRouting: routing, profile: profile);
    expect(smart.score, greaterThan(55));
    expect(smart.temperature, isNot(LeadTemperature.cold));
  });

  test('SeoEngine generates sitemap with trust route', () {
    final xml = SeoEngine.sitemapXml();
    expect(xml, contains('/trust'));
    expect(xml, contains('<?xml'));
  });

  test('generateContentDrafts returns pending approval drafts', () {
    final drafts = generateContentDrafts(subject: 'Test Estate', context: 'Lekki premium homes');
    expect(drafts.length, greaterThan(1));
    expect(drafts.every((d) => d.status == 'Pending approval'), isTrue);
  });
}
