import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/core/config/ai_features.dart';
import 'package:hdhomesproject/core/engines/engines.dart';

void main() {
  group('AI deferment — feature flag', () {
    test('AI features are disabled for pre-launch', () {
      expect(kAiFeaturesEnabled, isFalse);
    });
  });

  group('AI-ready engines — Version 1 defaults', () {
    test('RuleBasedRecommendationEngine returns first N candidates', () {
      const engine = RuleBasedRecommendationEngine();
      expect(engine.recommend([1, 2, 3, 4, 5], limit: 3), [1, 2, 3]);
    });

    test('KeywordSearchEngine filters by matcher', () {
      const engine = KeywordSearchEngine();
      final result = engine.search(
        'lagos',
        ['Lagos Estate', 'Abuja Heights', 'Lagos Island'],
        (item, q) => item.toLowerCase().contains(q),
      );
      expect(result, ['Lagos Estate', 'Lagos Island']);
    });

    test('TrendForecastEngine projects next from last delta', () {
      const engine = TrendForecastEngine();
      expect(engine.projectNext([10, 20, 30]), 40);
      expect(engine.projectNext([]), 0);
      expect(engine.projectNext([7]), 7);
    });

    test('StandardReportGenerator substitutes fields', () {
      const engine = StandardReportGenerator();
      expect(
        engine.draft('Hello {name}', {'name': 'HD Homes'}),
        'Hello HD Homes',
      );
    });

    test('ManualDocumentReview always requires human review', () {
      const engine = ManualDocumentReview();
      expect(engine.requiresManualReview('contract'), isTrue);
      expect(engine.requiresManualReview('kyc'), isTrue);
    });

    test('DisabledAssistantEngine is unavailable', () {
      const engine = DisabledAssistantEngine();
      expect(engine.available, isFalse);
    });

    test('StandardNotificationEngine keeps standard channels', () {
      const engine = StandardNotificationEngine();
      expect(
        engine.channels(),
        containsAll(['in_app', 'email', 'sms', 'push']),
      );
    });

    test('ManualWorkflowEngine routes to manual review', () {
      const engine = ManualWorkflowEngine();
      expect(engine.nextStep('submitted'), 'manual_review');
    });
  });
}
