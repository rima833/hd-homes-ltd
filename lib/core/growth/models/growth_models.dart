// Growth Engine models — Volume 2 Part 15.

enum LeadTemperature { cold, warm, hot, qualified, readyToBuy }

enum CustomerJourneyStage {
  anonymousVisitor,
  registeredUser,
  qualifiedLead,
  propertyInquiry,
  inspection,
  reservation,
  payment,
  customer,
  propertyOwner,
  repeatBuyer,
}

enum AbTestVariant { control, variantA, variantB }

enum IntegrationStatus { disconnected, configured, active }

class VisitorProfile {
  const VisitorProfile({
    this.pagesViewed = const [],
    this.propertyIdsViewed = const [],
    this.searchQueries = const [],
    this.downloadCount = 0,
    this.chatInteractions = 0,
    this.sessionCount = 1,
    this.interests = const [],
    this.preferredLocations = const [],
    this.budgetHint,
    this.utmSource,
    this.utmCampaign,
    this.firstSeen,
    this.lastSeen,
  });

  final List<String> pagesViewed;
  final List<String> propertyIdsViewed;
  final List<String> searchQueries;
  final int downloadCount;
  final int chatInteractions;
  final int sessionCount;
  final List<String> interests;
  final List<String> preferredLocations;
  final String? budgetHint;
  final String? utmSource;
  final String? utmCampaign;
  final DateTime? firstSeen;
  final DateTime? lastSeen;

  VisitorProfile copyWith({
    List<String>? pagesViewed,
    List<String>? propertyIdsViewed,
    List<String>? searchQueries,
    int? downloadCount,
    int? chatInteractions,
    int? sessionCount,
    List<String>? interests,
    List<String>? preferredLocations,
    String? budgetHint,
    String? utmSource,
    String? utmCampaign,
    DateTime? firstSeen,
    DateTime? lastSeen,
  }) =>
      VisitorProfile(
        pagesViewed: pagesViewed ?? this.pagesViewed,
        propertyIdsViewed: propertyIdsViewed ?? this.propertyIdsViewed,
        searchQueries: searchQueries ?? this.searchQueries,
        downloadCount: downloadCount ?? this.downloadCount,
        chatInteractions: chatInteractions ?? this.chatInteractions,
        sessionCount: sessionCount ?? this.sessionCount,
        interests: interests ?? this.interests,
        preferredLocations: preferredLocations ?? this.preferredLocations,
        budgetHint: budgetHint ?? this.budgetHint,
        utmSource: utmSource ?? this.utmSource,
        utmCampaign: utmCampaign ?? this.utmCampaign,
        firstSeen: firstSeen ?? this.firstSeen,
        lastSeen: lastSeen ?? this.lastSeen,
      );
}

class SmartLeadScore {
  const SmartLeadScore({
    required this.score,
    required this.temperature,
    required this.recommendedChannel,
    required this.recommendedContactTime,
    required this.recommendedExecutive,
    required this.followUpAction,
  });

  final int score;
  final LeadTemperature temperature;
  final String recommendedChannel;
  final String recommendedContactTime;
  final String recommendedExecutive;
  final String followUpAction;
}

class PropertyRecommendation {
  const PropertyRecommendation({
    required this.propertyId,
    required this.reason,
    required this.score,
    required this.label,
  });

  final String propertyId;
  final String reason;
  final int score;
  final String label;
}

class InvestmentInsight {
  const InvestmentInsight({
    required this.title,
    required this.value,
    required this.trend,
    required this.riskLevel,
    required this.summary,
  });

  final String title;
  final String value;
  final String trend;
  final String riskLevel;
  final String summary;
}

class AutomationRule {
  const AutomationRule({
    required this.id,
    required this.name,
    required this.trigger,
    required this.actions,
    required this.enabled,
  });

  final String id;
  final String name;
  final String trigger;
  final List<String> actions;
  final bool enabled;
}

class AbTestExperiment {
  const AbTestExperiment({
    required this.id,
    required this.name,
    required this.variants,
    required this.metric,
    this.winner,
  });

  final String id;
  final String name;
  final List<String> variants;
  final String metric;
  final String? winner;
}

class NewsletterSubscriber {
  const NewsletterSubscriber({
    required this.email,
    required this.subscribedAt,
    required this.topics,
  });

  final String email;
  final DateTime subscribedAt;
  final List<String> topics;
}

class ReferralLink {
  const ReferralLink({
    required this.code,
    required this.url,
    required this.clicks,
    required this.conversions,
  });

  final String code;
  final String url;
  final int clicks;
  final int conversions;
}

class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
  });

  final String role;
  final String content;
  final DateTime timestamp;
}

class PredictiveInsight {
  const PredictiveInsight({
    required this.title,
    required this.prediction,
    required this.confidence,
    required this.category,
  });

  final String title;
  final String prediction;
  final int confidence;
  final String category;
}

class ExecutiveGrowthSnapshot {
  const ExecutiveGrowthSnapshot({
    required this.liveVisitors,
    required this.activeLeads,
    required this.pipelineValue,
    required this.conversionRate,
    required this.marketingRoi,
    required this.topProperty,
    required this.regionalDemand,
  });

  final int liveVisitors;
  final int activeLeads;
  final String pipelineValue;
  final String conversionRate;
  final String marketingRoi;
  final String topProperty;
  final String regionalDemand;
}

class ThirdPartyIntegration {
  const ThirdPartyIntegration({
    required this.id,
    required this.name,
    required this.category,
    required this.status,
    required this.description,
  });

  final String id;
  final String name;
  final String category;
  final IntegrationStatus status;
  final String description;
}

class GrowthHubCms {
  const GrowthHubCms({
    required this.personalizationEnabled,
    required this.leadScoringRules,
    required this.seoDefaults,
    required this.automationRules,
    required this.abTests,
    required this.integrations,
    required this.campaigns,
  });

  final bool personalizationEnabled;
  final List<String> leadScoringRules;
  final Map<String, String> seoDefaults;
  final List<AutomationRule> automationRules;
  final List<AbTestExperiment> abTests;
  final List<ThirdPartyIntegration> integrations;
  final List<String> campaigns;
}

extension LeadTemperatureLabel on LeadTemperature {
  String get label => switch (this) {
        LeadTemperature.cold => 'Cold',
        LeadTemperature.warm => 'Warm',
        LeadTemperature.hot => 'Hot',
        LeadTemperature.qualified => 'Qualified',
        LeadTemperature.readyToBuy => 'Ready to Buy',
      };
}
