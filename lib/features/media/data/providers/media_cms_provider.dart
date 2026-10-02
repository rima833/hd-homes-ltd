import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/cms/domain/data/hub_page_cms.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/media/data/models/media_content.dart';

const _hubFallback = MediaHubCms(
  heroHeadline: 'Experience Properties Before You Visit.',
  heroSubheadline:
      'Immersive galleries from published estates and properties — photos update live as the team publishes media.',
  featuredExperiences: [],
  pressKitItems: [],
  brandAssets: [],
  analytics: MediaAnalyticsSnapshot(
    topPhoto: '—',
    topVideo: '—',
    avgViewDuration: '—',
    tourCompletionRate: '—',
    downloadCount: 0,
    shareCount: 0,
  ),
);

final mediaGalleryCatalogProvider = Provider<List<MediaExperience>>((ref) {
  ref.watch(publishedPropertiesRealtimeProvider);
  ref.watch(publishedEstatesRealtimeProvider);

  final estates =
      ref.watch(publishedEstatesCatalogProvider).valueOrNull ?? const [];
  final properties =
      ref.watch(publishedPropertiesCatalogProvider).valueOrNull ?? const [];
  return buildMediaGalleryCatalog(
    estates: estates,
    properties: properties,
  );
});

final mediaHubCmsProvider = Provider<MediaHubCms>((ref) {
  final catalog = ref.watch(mediaGalleryCatalogProvider);
  var heroHeadline = _hubFallback.heroHeadline;
  var heroSubheadline = _hubFallback.heroSubheadline;
  String? backgroundImageUrl = _hubFallback.backgroundImageUrl;
  String? backgroundVideoUrl = _hubFallback.backgroundVideoUrl;

  if (ref.watch(supabaseConfiguredProvider)) {
    final overlay = hubHeroFromPage(
      ref.watch(publishedPageBySlugProvider('gallery')).valueOrNull,
    );
    heroHeadline = overlay.headline ?? heroHeadline;
    heroSubheadline = overlay.subheadline ?? heroSubheadline;
    backgroundImageUrl = overlay.backgroundImageUrl ?? backgroundImageUrl;
    backgroundVideoUrl = overlay.backgroundVideoUrl ?? backgroundVideoUrl;
  }

  final photoCount = catalog.fold<int>(0, (sum, e) => sum + e.galleryImages.length);
  final estateCount = catalog.where((e) => e.slug.startsWith('estate-')).length;
  final propertyCount = catalog.where((e) => e.slug.startsWith('property-')).length;

  return MediaHubCms(
    heroHeadline: heroHeadline,
    heroSubheadline: heroSubheadline,
    backgroundImageUrl: backgroundImageUrl,
    backgroundVideoUrl: backgroundVideoUrl,
    featuredExperiences: [
      for (final item in catalog)
        MediaExperienceSummary(
          slug: item.slug,
          title: item.propertyName,
          estateName: item.estateName,
          thumbnailLabel: item.slug.startsWith('estate-') ? 'Estate' : 'Property',
          mediaCount: item.mediaCount,
          imageUrl: item.imageUrl,
        ),
    ],
    pressKitItems: const [],
    brandAssets: const [],
    analytics: MediaAnalyticsSnapshot(
      topPhoto: photoCount == 0 ? 'No published photos yet' : '$photoCount published photos',
      topVideo: '—',
      avgViewDuration: '—',
      tourCompletionRate: '—',
      downloadCount: estateCount,
      shareCount: propertyCount,
    ),
  );
});

final mediaExperienceProvider =
    Provider.family<MediaExperience?, String>((ref, slug) {
  final catalog = ref.watch(mediaGalleryCatalogProvider);
  final key = slug.trim().toLowerCase();
  for (final item in catalog) {
    if (item.slug.toLowerCase() == key) return item;
  }
  for (final item in catalog) {
    final raw = item.slug.contains('-')
        ? item.slug.substring(item.slug.indexOf('-') + 1)
        : item.slug;
    if (raw.toLowerCase() == key) return item;
  }
  return null;
});

final mediaExperiencesProvider = Provider<List<MediaExperience>>(
  (ref) => ref.watch(mediaGalleryCatalogProvider),
);

List<MediaExperience> buildMediaGalleryCatalog({
  required List<CmsEstateSummary> estates,
  required List<CmsPropertyFeatured> properties,
}) {
  final out = <MediaExperience>[];
  final used = <String>{};

  final propertiesByEstate = <String, List<CmsPropertyFeatured>>{};
  for (final property in properties) {
    final estateKey = (property.estateName ?? '').trim().toLowerCase();
    if (estateKey.isEmpty) continue;
    propertiesByEstate.putIfAbsent(estateKey, () => []).add(property);
  }

  final featuredEstates = [...estates]
    ..sort((a, b) {
      if (a.isFeatured != b.isFeatured) return a.isFeatured ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

  for (final estate in featuredEstates) {
    final linked = propertiesByEstate[estate.name.trim().toLowerCase()] ?? const [];
    final urls = _uniqueUrls([
      ...estate.galleryUrls,
      if (estate.coverImageUrl != null) estate.coverImageUrl!,
      for (final property in linked) ...[
        ...property.galleryUrls,
        if (property.coverImageUrl != null) property.coverImageUrl!,
      ],
    ]);
    if (urls.isEmpty) continue;
    final slug = 'estate-${_slugOrId(estate.slug, estate.id)}';
    if (!used.add(slug)) continue;
    out.add(
      _experience(
        slug: slug,
        title: estate.name,
        estateName: estate.location.isEmpty ? estate.name : estate.location,
        urls: urls,
        cover: estate.coverImageUrl ?? urls.first,
        listingPath: estate.slug.isEmpty
            ? RoutePaths.estates
            : '${RoutePaths.estates}/${estate.slug}',
        description: estate.description ?? estate.tagline ?? '',
        related: [
          for (final property in linked.take(4))
            'property-${_slugOrId(property.slug, property.id)}',
        ],
      ),
    );
  }

  final featuredProperties = [...properties]
    ..sort((a, b) {
      if (a.isFeatured != b.isFeatured) return a.isFeatured ? -1 : 1;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });

  for (final property in featuredProperties) {
    final urls = _uniqueUrls([
      ...property.galleryUrls,
      if (property.coverImageUrl != null) property.coverImageUrl!,
    ]);
    if (urls.isEmpty) continue;
    final slug = 'property-${_slugOrId(property.slug, property.id)}';
    if (!used.add(slug)) continue;
    out.add(
      _experience(
        slug: slug,
        title: property.title,
        estateName: (property.estateName?.trim().isNotEmpty ?? false)
            ? property.estateName!.trim()
            : [
                property.city,
                property.state,
              ].whereType<String>().where((s) => s.trim().isNotEmpty).join(', '),
        urls: urls,
        cover: property.coverImageUrl ?? urls.first,
        listingPath: '/properties/${property.slug.isNotEmpty ? property.slug : property.id}',
        description: property.summary ?? property.description ?? '',
        related: [
          for (final other in featuredProperties)
            if (other.id != property.id &&
                (other.estateName ?? '').trim().toLowerCase() ==
                    (property.estateName ?? '').trim().toLowerCase())
              'property-${_slugOrId(other.slug, other.id)}',
        ].take(4).toList(),
      ),
    );
  }

  return out;
}

MediaExperience _experience({
  required String slug,
  required String title,
  required String estateName,
  required List<String> urls,
  required String cover,
  required String listingPath,
  required String description,
  required List<String> related,
}) {
  final images = [
    for (var i = 0; i < urls.length; i++)
      MediaGalleryImage(
        id: '$slug-$i',
        category: MediaGalleryCategory.exterior,
        caption: i == 0 ? title : '$title · ${i + 1}',
        alt: title,
        imageUrl: urls[i],
      ),
  ];

  return MediaExperience(
    slug: slug,
    propertyName: title,
    estateName: estateName.isEmpty ? title : estateName,
    mediaCount: images.length,
    heroHeadline: title,
    featuredCards: [
      MediaFeaturedCard(
        type: MediaAssetType.photo,
        title: 'Photos',
        iconName: 'image',
        count: images.length,
        lastUpdated: 'Ready',
        cta: 'View gallery',
      ),
    ],
    galleryImages: images,
    virtualTourRooms: const [],
    droneChapters: const [],
    videos: const [],
    floorPlans: const [],
    masterplanDescription: description,
    masterplanLegend: const [],
    constructionMilestones: const [],
    completionPercent: 0,
    expectedCompletion: '',
    downloads: const [],
    openHouses: const [],
    timeline: const [],
    relatedSlugs: related,
    imageUrl: cover,
    listingPath: listingPath,
  );
}

List<String> _uniqueUrls(List<String> raw) {
  final out = <String>[];
  final seen = <String>{};
  for (final value in raw) {
    final url = value.trim();
    if (url.isEmpty || !seen.add(url)) continue;
    out.add(url);
  }
  return out;
}

String _slugOrId(String slug, String id) {
  final trimmed = slug.trim();
  return trimmed.isEmpty ? id : trimmed;
}
