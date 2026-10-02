/// Phase 2 AI extension points.
///
/// Every future AI module plugs in behind one of these interfaces without
/// changing existing business logic. Version 1 ships the rule-based
/// defaults below; Version 2 swaps in AI-backed implementations.
library;

/// Ranks or selects items for a user (property recommendations,
/// service suggestions, featured content).
abstract class RecommendationEngine {
  List<T> recommend<T>(List<T> candidates, {int limit = 10});
}

/// Resolves a query against a corpus (keyword today, semantic in Phase 2).
abstract class SearchEngine {
  List<T> search<T>(String query, List<T> corpus, bool Function(T, String) matches);
}

/// Produces forward-looking projections (revenue, sales, cash flow).
abstract class ForecastEngine {
  double projectNext(List<double> history);
}

/// Generates content drafts (blogs, emails, property descriptions).
abstract class ContentGenerator {
  String draft(String template, Map<String, String> fields);
}

/// Extracts or verifies information from documents (OCR/contract
/// analysis in Phase 2; manual review today).
abstract class DocumentAnalyzer {
  bool requiresManualReview(String documentType);
}

/// Supplies decision options with supporting evidence.
abstract class DecisionSupport {
  List<String> options(String context);
}

/// Conversational assistant entry point (disabled in Version 1).
abstract class AssistantEngine {
  bool get available;
}

/// Dispatches notifications (standard channels today, intelligent
/// prioritization in Phase 2).
abstract class NotificationEngine {
  List<String> channels();
}

/// Routes work items through approvals (manual/role-based today).
abstract class WorkflowEngine {
  String nextStep(String currentStep);
}

// ── Version 1 rule-based defaults ─────────────────────────────────────────

class RuleBasedRecommendationEngine implements RecommendationEngine {
  const RuleBasedRecommendationEngine();
  @override
  List<T> recommend<T>(List<T> candidates, {int limit = 10}) =>
      candidates.take(limit).toList();
}

class KeywordSearchEngine implements SearchEngine {
  const KeywordSearchEngine();
  @override
  List<T> search<T>(
    String query,
    List<T> corpus,
    bool Function(T, String) matches,
  ) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return corpus;
    return corpus.where((item) => matches(item, q)).toList();
  }
}

class TrendForecastEngine implements ForecastEngine {
  const TrendForecastEngine();
  @override
  double projectNext(List<double> history) {
    if (history.isEmpty) return 0;
    if (history.length == 1) return history.first;
    final delta = history.last - history[history.length - 2];
    return history.last + delta;
  }
}

class StandardReportGenerator implements ContentGenerator {
  const StandardReportGenerator();
  @override
  String draft(String template, Map<String, String> fields) {
    var output = template;
    fields.forEach((key, value) => output = output.replaceAll('{$key}', value));
    return output;
  }
}

class ManualDocumentReview implements DocumentAnalyzer {
  const ManualDocumentReview();
  @override
  bool requiresManualReview(String documentType) => true;
}

class RuleBasedDecisionSupport implements DecisionSupport {
  const RuleBasedDecisionSupport();
  @override
  List<String> options(String context) => const [];
}

class DisabledAssistantEngine implements AssistantEngine {
  const DisabledAssistantEngine();
  @override
  bool get available => false;
}

class StandardNotificationEngine implements NotificationEngine {
  const StandardNotificationEngine();
  @override
  List<String> channels() => const ['in_app', 'email', 'sms', 'push'];
}

class ManualWorkflowEngine implements WorkflowEngine {
  const ManualWorkflowEngine();
  @override
  String nextStep(String currentStep) => 'manual_review';
}
