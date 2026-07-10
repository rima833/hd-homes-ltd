import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/growth/models/growth_models.dart';

/// Tracks anonymous visitor behavior for personalization and lead scoring.
class VisitorProfileNotifier extends Notifier<VisitorProfile> {
  @override
  VisitorProfile build() {
    final now = DateTime.now();
    return VisitorProfile(firstSeen: now, lastSeen: now);
  }

  void recordPageView(String path, {Map<String, String>? utm}) {
    final pages = [...state.pagesViewed, path];
    final interests = _inferInterests(path, state.interests);
    final locations = _inferLocations(path, state.preferredLocations);

    state = state.copyWith(
      pagesViewed: pages.take(50).toList(),
      interests: interests,
      preferredLocations: locations,
      utmSource: utm?['utm_source'] ?? state.utmSource,
      utmCampaign: utm?['utm_campaign'] ?? state.utmCampaign,
      lastSeen: DateTime.now(),
    );
  }

  void recordPropertyView(String propertyId) {
    final ids = [propertyId, ...state.propertyIdsViewed.where((id) => id != propertyId)];
    state = state.copyWith(
      propertyIdsViewed: ids.take(20).toList(),
      interests: _addInterest(state.interests, 'property-buying'),
      lastSeen: DateTime.now(),
    );
  }

  void recordSearch(String query) {
    final queries = [query, ...state.searchQueries];
    state = state.copyWith(
      searchQueries: queries.take(20).toList(),
      lastSeen: DateTime.now(),
    );
  }

  void recordDownload() {
    state = state.copyWith(
      downloadCount: state.downloadCount + 1,
      lastSeen: DateTime.now(),
    );
  }

  void recordChatInteraction() {
    state = state.copyWith(
      chatInteractions: state.chatInteractions + 1,
      lastSeen: DateTime.now(),
    );
  }

  void setBudgetHint(String hint) {
    state = state.copyWith(budgetHint: hint, lastSeen: DateTime.now());
  }
}

List<String> _inferInterests(String path, List<String> existing) {
  final interests = [...existing];
  if (path.contains('/investment')) _addUnique(interests, 'investment');
  if (path.contains('/properties')) _addUnique(interests, 'property-buying');
  if (path.contains('/estates')) _addUnique(interests, 'estate-living');
  if (path.contains('/services')) _addUnique(interests, 'construction-services');
  if (path.contains('/blog')) _addUnique(interests, 'market-insights');
  if (path.contains('/trust')) _addUnique(interests, 'due-diligence');
  return interests;
}

List<String> _inferLocations(String path, List<String> existing) {
  final locations = [...existing];
  if (path.contains('lekki') || path.contains('lagos')) _addUnique(locations, 'Lagos');
  if (path.contains('abuja')) _addUnique(locations, 'Abuja');
  if (path.contains('ph') || path.contains('port-harcourt')) _addUnique(locations, 'Port Harcourt');
  return locations;
}

List<String> _addInterest(List<String> interests, String interest) {
  final next = [...interests];
  _addUnique(next, interest);
  return next;
}

void _addUnique(List<String> list, String value) {
  if (!list.contains(value)) list.add(value);
}

final visitorProfileProvider =
    NotifierProvider<VisitorProfileNotifier, VisitorProfile>(VisitorProfileNotifier.new);
