import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/growth/models/growth_models.dart';
import 'package:hdhomesproject/core/growth/personalization/visitor_profile.dart';
import 'package:hdhomesproject/core/growth/providers/growth_cms_provider.dart';
import 'package:hdhomesproject/features/blog/data/providers/blog_catalog_provider.dart';
import 'package:hdhomesproject/features/home/data/providers/home_content_provider.dart';
import 'package:hdhomesproject/features/properties/data/models/marketplace_property.dart';
import 'package:hdhomesproject/features/properties/data/providers/marketplace_listings_provider.dart';

/// Personalized content slices for homepage and global surfaces.
class PersonalizedContent {
  const PersonalizedContent({
    required this.headline,
    required this.subheadline,
    required this.featuredPropertyIds,
    required this.recommendedEstateSlugs,
    required this.blogSlugs,
    required this.primaryCta,
  });

  final String headline;
  final String subheadline;
  final List<String> featuredPropertyIds;
  final List<String> recommendedEstateSlugs;
  final List<String> blogSlugs;
  final String primaryCta;
}

final personalizedContentProvider = Provider<PersonalizedContent>((ref) {
  final cms = ref.watch(growthHubCmsProvider);
  final profile = ref.watch(visitorProfileProvider);
  final home = ref.watch(homeContentProvider);
  final properties = ref.watch(marketplaceListingsProvider);
  final articles = ref.watch(blogCatalogProvider);

  if (!cms.personalizationEnabled) {
    return PersonalizedContent(
      headline: home.hero.headline,
      subheadline: home.hero.subheadline,
      featuredPropertyIds: home.properties.map((p) => p.id).toList(),
      recommendedEstateSlugs: home.estates.map((e) => e.id).toList(),
      blogSlugs: articles.take(3).map((a) => a.slug).toList(),
      primaryCta: home.hero.primaryCtaLabel,
    );
  }

  final hasInvestmentInterest = profile.interests.contains('investment');
  final hasPropertyInterest = profile.interests.contains('property-buying');

  final headline = hasInvestmentInterest
      ? 'Investment opportunities tailored for you'
      : hasPropertyInterest
          ? 'Homes matching your recent browsing'
          : home.hero.headline;

  final subheadline = profile.preferredLocations.isNotEmpty
      ? 'Curated for ${profile.preferredLocations.join(', ')} and your browsing history.'
      : home.hero.subheadline;

  final sortedProps = _sortByProfile(properties, profile);
  final propertyIds = sortedProps.take(6).map((p) => p.id).toList();

  final estateSlugs = home.estates.map((e) => e.id).toList();

  final blogSlugs = hasInvestmentInterest
      ? articles.where((a) => a.tags.any((t) => t.toLowerCase().contains('invest'))).take(3).map((a) => a.slug).toList()
      : articles.take(3).map((a) => a.slug).toList();

  final cta = profile.propertyIdsViewed.isNotEmpty ? 'Continue Browsing' : home.hero.primaryCtaLabel;

  return PersonalizedContent(
    headline: headline,
    subheadline: subheadline,
    featuredPropertyIds: propertyIds,
    recommendedEstateSlugs: estateSlugs,
    blogSlugs: blogSlugs.isEmpty ? articles.take(3).map((a) => a.slug).toList() : blogSlugs,
    primaryCta: cta,
  );
});

List<MarketplaceProperty> _sortByProfile(List<MarketplaceProperty> all, VisitorProfile profile) {
  final viewed = profile.propertyIdsViewed.toSet();
  final locations = profile.preferredLocations.map((l) => l.toLowerCase()).toSet();

  int score(MarketplaceProperty p) {
    var s = p.matchScore;
    if (viewed.contains(p.id)) s += 15;
    if (locations.any((l) => p.location.toLowerCase().contains(l))) s += 20;
    if (profile.interests.contains('investment') && p.purpose == PropertyPurpose.invest) s += 25;
    return s;
  }

  final sorted = [...all]..sort((a, b) => score(b).compareTo(score(a)));
  return sorted;
}
