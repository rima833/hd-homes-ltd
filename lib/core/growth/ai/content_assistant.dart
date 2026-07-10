import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/features/search/data/providers/search_intelligence_provider.dart';

/// AI content assistant — drafts for human approval (Volume 1.5 CMS integration).
String generatePropertySummary(String title, String location, int bedrooms) =>
    '$title in $location offers $bedrooms bedrooms with premium HD Homes finishes, '
    'flexible payment plans, and verified title documentation.';

String generateMetaDescription(String pageTitle, String highlight) =>
    '$pageTitle — $highlight. HD Homes Ltd — trusted Nigerian property developer.';

List<String> suggestFaqs(String topic) => [
      'How do I verify the title for $topic?',
      'What payment plans are available for $topic?',
      'Can I schedule a virtual inspection for $topic?',
    ];

final aiSearchAssistantProvider = Provider<String Function(String)>((ref) {
  return (query) {
    final result = parseAiSearchQuery(query);
    if (result.extractedCriteria.isEmpty) {
      return 'I parsed your query. Try adding location, bedrooms, or budget for better results.';
    }
    return 'I found: ${result.extractedCriteria.join(' · ')} (${result.confidence}% confidence)';
  };
});
