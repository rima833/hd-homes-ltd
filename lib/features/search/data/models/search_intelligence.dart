// Property Search Intelligence models (Supabase wired in Volume 1.5).

import 'package:hdhomesproject/features/properties/data/models/marketplace_filters.dart';

class QuickFilterChip {
  const QuickFilterChip({
    required this.label,
    required this.iconName,
    required this.description,
  });

  final String label;
  final String iconName;
  final String description;
}

class LifestyleSearchOption {
  const LifestyleSearchOption({
    required this.id,
    required this.title,
    required this.description,
    required this.filterTag,
    required this.iconName,
  });

  final String id;
  final String title;
  final String description;
  final String filterTag;
  final String iconName;
}

class CommuteSearchPreset {
  const CommuteSearchPreset({
    required this.label,
    required this.minutes,
    required this.destination,
  });

  final String label;
  final int minutes;
  final String destination;
}

class NeighborhoodMatch {
  const NeighborhoodMatch({
    required this.name,
    required this.city,
    required this.lifestyleScore,
    required this.summary,
    required this.propertyCount,
  });

  final String name;
  final String city;
  final int lifestyleScore;
  final String summary;
  final int propertyCount;
}

class SavedSearch {
  const SavedSearch({
    required this.id,
    required this.name,
    required this.filters,
    required this.createdAt,
  });

  final String id;
  final String name;
  final MarketplaceFilters filters;
  final DateTime createdAt;
}

class PropertyAlert {
  const PropertyAlert({
    required this.id,
    required this.label,
    required this.trigger,
    required this.channel,
    required this.active,
  });

  final String id;
  final String label;
  final String trigger;
  final String channel;
  final bool active;
}

class SearchHistoryEntry {
  const SearchHistoryEntry({
    required this.id,
    required this.query,
    required this.filterSummary,
    required this.searchedAt,
    required this.resultsCount,
  });

  final String id;
  final String query;
  final String filterSummary;
  final DateTime searchedAt;
  final int resultsCount;
}

class SearchAnalyticsSummary {
  const SearchAnalyticsSummary({
    required this.searchesPerformed,
    required this.savedSearches,
    required this.favoriteLocations,
    required this.propertiesViewed,
    required this.suggestedImprovement,
  });

  final int searchesPerformed;
  final int savedSearches;
  final List<String> favoriteLocations;
  final int propertiesViewed;
  final String suggestedImprovement;
}

class AffordabilityResult {
  const AffordabilityResult({
    required this.comfortableBudget,
    required this.mortgageEligible,
    required this.installmentAffordable,
    required this.recommendedPlan,
  });

  final String comfortableBudget;
  final bool mortgageEligible;
  final String installmentAffordable;
  final String recommendedPlan;
}

class DreamHomeAnswer {
  const DreamHomeAnswer({
    required this.question,
    required this.answer,
  });

  final String question;
  final String answer;
}

class DiscoveryFeedItem {
  const DiscoveryFeedItem({
    required this.type,
    required this.title,
    required this.subtitle,
  });

  final String type;
  final String title;
  final String subtitle;
}

class SearchHubCms {
  const SearchHubCms({
    required this.heroHeadline,
    required this.heroSubheadline,
    required this.popularSearches,
    required this.recentSearches,
    required this.quickFilters,
    required this.lifestyleOptions,
    required this.commutePresets,
    required this.amenityFilters,
    required this.investmentFilters,
    required this.neighborhoods,
    required this.aiExampleQueries,
    required this.dreamHomeQuestions,
    required this.discoveryFeed,
  });

  final String heroHeadline;
  final String heroSubheadline;
  final List<String> popularSearches;
  final List<String> recentSearches;
  final List<QuickFilterChip> quickFilters;
  final List<LifestyleSearchOption> lifestyleOptions;
  final List<CommuteSearchPreset> commutePresets;
  final List<String> amenityFilters;
  final List<String> investmentFilters;
  final List<NeighborhoodMatch> neighborhoods;
  final List<String> aiExampleQueries;
  final List<String> dreamHomeQuestions;
  final List<DiscoveryFeedItem> discoveryFeed;
}

class AiSearchParseResult {
  const AiSearchParseResult({
    required this.filters,
    required this.extractedCriteria,
    required this.confidence,
  });

  final MarketplaceFilters filters;
  final List<String> extractedCriteria;
  final int confidence;
}
