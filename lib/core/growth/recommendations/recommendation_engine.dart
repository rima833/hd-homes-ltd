import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/growth/models/growth_models.dart';
import 'package:hdhomesproject/core/growth/personalization/visitor_profile.dart';
import 'package:hdhomesproject/features/properties/data/models/marketplace_property.dart';
import 'package:hdhomesproject/features/properties/data/providers/marketplace_controller.dart';
import 'package:hdhomesproject/features/properties/data/providers/marketplace_listings_provider.dart';

final recommendedForYouProvider = Provider<List<PropertyRecommendation>>((ref) {
  final all = ref.watch(marketplaceListingsProvider);
  final profile = ref.watch(visitorProfileProvider);
  final recentIds = ref.watch(marketplaceRecentProvider);

  return _buildRecommendations(
    all: all,
    profile: profile,
    recentIds: recentIds,
    label: 'Recommended for You',
    limit: 6,
  );
});

final similarPropertiesProvider = Provider.family<List<PropertyRecommendation>, String>((ref, propertyId) {
  final all = ref.watch(marketplaceListingsProvider);
  final source = all.where((p) => p.id == propertyId).firstOrNull;
  if (source == null) return [];

  final similar = all.where((p) => p.id != propertyId).where((p) {
    return p.type == source.type || p.estate == source.estate || p.state == source.state;
  }).toList()
    ..sort((a, b) => b.matchScore.compareTo(a.matchScore));

  return similar.take(4).map((p) {
    return PropertyRecommendation(
      propertyId: p.id,
      reason: '${p.type} in ${p.location}',
      score: p.matchScore,
      label: 'Similar Properties',
    );
  }).toList();
});

final trendingNearYouProvider = Provider<List<PropertyRecommendation>>((ref) {
  final all = ref.watch(marketplaceListingsProvider);
  final profile = ref.watch(visitorProfileProvider);
  final locations = profile.preferredLocations;

  final filtered = locations.isEmpty
      ? [...all]
      : all.where((p) => locations.any((l) => p.location.toLowerCase().contains(l.toLowerCase()))).toList();

  filtered.sort((a, b) => b.popularity.compareTo(a.popularity));

  return filtered.take(4).map((p) {
    return PropertyRecommendation(
      propertyId: p.id,
      reason: 'Trending in ${p.location}',
      score: p.popularity,
      label: 'Trending Near You',
    );
  }).toList();
});

List<PropertyRecommendation> _buildRecommendations({
  required List<MarketplaceProperty> all,
  required VisitorProfile profile,
  required List<String> recentIds,
  required String label,
  required int limit,
}) {
  final viewed = {...profile.propertyIdsViewed, ...recentIds};
  final locations = profile.preferredLocations;

  int score(MarketplaceProperty p) {
    var s = p.matchScore + p.popularity ~/ 10;
    if (viewed.contains(p.id)) s -= 30;
    if (locations.any((l) => p.location.toLowerCase().contains(l.toLowerCase()))) s += 25;
    if (profile.interests.contains('investment') && p.lifestyleTags.any((t) => t.toLowerCase().contains('invest'))) s += 20;
    return s;
  }

  final sorted = [...all]..sort((a, b) => score(b).compareTo(score(a)));

  return sorted.take(limit).map((p) {
    return PropertyRecommendation(
      propertyId: p.id,
      reason: _reasonFor(p, profile),
      score: score(p),
      label: label,
    );
  }).toList();
}

String _reasonFor(MarketplaceProperty p, VisitorProfile profile) {
  if (profile.preferredLocations.any((l) => p.location.contains(l))) {
    return 'Matches your preferred location';
  }
  if (profile.interests.contains('investment')) {
    return 'Strong investment potential';
  }
  if (p.matchScore >= 90) return 'High lifestyle match';
  return 'Popular with similar buyers';
}
