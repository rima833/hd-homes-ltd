import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/growth/ai/investment_advisor.dart';
import 'package:hdhomesproject/core/growth/models/growth_models.dart';
import 'package:hdhomesproject/core/growth/personalization/visitor_profile.dart';
import 'package:hdhomesproject/core/growth/recommendations/recommendation_engine.dart';
import 'package:hdhomesproject/features/search/data/providers/search_intelligence_provider.dart';

/// HD Homes AI Concierge™ — unified virtual property consultant.
class AiConciergeNotifier extends Notifier<List<ChatMessage>> {
  @override
  List<ChatMessage> build() => [
        ChatMessage(
          role: 'assistant',
          content:
              'Welcome to HD Homes AI Concierge™. I can help with properties, investments, '
              'payment plans, inspections, and FAQs. How can I assist you today?',
          timestamp: DateTime.now(),
        ),
      ];

  String sendMessage(String userMessage) {
    ref.read(visitorProfileProvider.notifier).recordChatInteraction();

    final userMsg = ChatMessage(role: 'user', content: userMessage, timestamp: DateTime.now());
    state = [...state, userMsg];

    final reply = _generateReply(userMessage);
    final assistantMsg = ChatMessage(role: 'assistant', content: reply, timestamp: DateTime.now());
    state = [...state, assistantMsg];
    return reply;
  }

  String _generateReply(String input) {
    final q = input.toLowerCase();

    if (q.contains('inspect') || q.contains('visit') || q.contains('book')) {
      return 'I can help you book an inspection. Visit ${RoutePaths.bookInspection} or tell me '
          'your preferred property and date — I\'ll route this to our sales team.';
    }

    if (q.contains('payment') || q.contains('installment') || q.contains('mortgage')) {
      return 'HD Homes offers flexible installment plans, mortgage partnerships, and escrow-protected '
          'milestone payments. Typical plans range from 12–36 months with competitive terms.';
    }

    if (q.contains('invest') || q.contains('roi') || q.contains('yield')) {
      final insights = ref.read(investmentInsightsProvider);
      if (insights.isNotEmpty) {
        final top = insights.first;
        return '${top.title}: expected ${top.value}, ${top.trend}. Risk: ${top.riskLevel}. '
            'Would you like the full investment pack?';
      }
      return 'Our investment properties target 15–22% ROI with structured investor protections. '
          'Visit ${RoutePaths.investment} for opportunities.';
    }

    if (q.contains('recommend') || q.contains('show me') || q.contains('find')) {
      final parse = parseAiSearchQuery(input);
      final recs = ref.read(recommendedForYouProvider);
      if (recs.isNotEmpty) {
        return 'Based on your interests: ${parse.extractedCriteria.join(', ')}. '
            'I recommend exploring property ${recs.first.propertyId} — ${recs.first.reason}. '
            'View all at ${RoutePaths.search}.';
      }
    }

    if (q.contains('hello') || q.contains('hi') || q.contains('hey')) {
      return 'Hello! I\'m your HD Homes AI Concierge. Ask me about properties, investments, '
          'payment plans, or book an inspection.';
    }

    return 'I understand you\'re asking about "$input". For detailed assistance, our consultants '
        'are available at ${RoutePaths.contact}. I can also help you search properties at ${RoutePaths.search}.';
  }
}

final aiConciergeProvider = NotifierProvider<AiConciergeNotifier, List<ChatMessage>>(AiConciergeNotifier.new);
