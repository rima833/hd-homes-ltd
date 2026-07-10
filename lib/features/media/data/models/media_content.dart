// Media Center CMS models (Supabase Storage wired in Volume 1.5).

enum MediaAssetType {
  photo,
  video,
  virtualTour,
  drone,
  floorPlan,
  masterplan,
  construction,
  brochure,
}

enum MediaGalleryCategory {
  exterior,
  interior,
  livingRoom,
  kitchen,
  bedrooms,
  bathrooms,
  amenities,
  neighborhood,
  construction,
  landscape,
}

enum ConstructionPhase {
  planning,
  foundation,
  structure,
  roofing,
  finishing,
  inspection,
  completed,
}

class MediaFeaturedCard {
  const MediaFeaturedCard({
    required this.type,
    required this.title,
    required this.iconName,
    required this.count,
    required this.lastUpdated,
    required this.cta,
  });

  final MediaAssetType type;
  final String title;
  final String iconName;
  final int count;
  final String lastUpdated;
  final String cta;
}

class MediaGalleryImage {
  const MediaGalleryImage({
    required this.id,
    required this.category,
    required this.caption,
    required this.alt,
  });

  final String id;
  final MediaGalleryCategory category;
  final String caption;
  final String alt;
}

class VirtualTourRoom {
  const VirtualTourRoom({
    required this.name,
    required this.description,
    required this.hotspots,
  });

  final String name;
  final String description;
  final List<String> hotspots;
}

class DroneChapter {
  const DroneChapter({
    required this.title,
    required this.duration,
  });

  final String title;
  final String duration;
}

class MediaVideoItem {
  const MediaVideoItem({
    required this.title,
    required this.category,
    required this.duration,
    required this.quality,
  });

  final String title;
  final String category;
  final String duration;
  final String quality;
}

class FloorPlanItem {
  const FloorPlanItem({
    required this.label,
    required this.floor,
    required this.dimensions,
    required this.rooms,
  });

  final String label;
  final String floor;
  final String dimensions;
  final List<String> rooms;
}

class ConstructionMilestone {
  const ConstructionMilestone({
    required this.phase,
    required this.label,
    required this.completionPercent,
    required this.date,
    required this.completed,
  });

  final ConstructionPhase phase;
  final String label;
  final int completionPercent;
  final String date;
  final bool completed;
}

class MediaDownloadItem {
  const MediaDownloadItem({
    required this.title,
    required this.type,
    required this.size,
    required this.category,
  });

  final String title;
  final String type;
  final String size;
  final String category;
}

class VirtualOpenHouse {
  const VirtualOpenHouse({
    required this.title,
    required this.date,
    required this.host,
    required this.registeredCount,
    required this.status,
  });

  final String title;
  final String date;
  final String host;
  final int registeredCount;
  final String status;
}

class MediaTimelineEvent {
  const MediaTimelineEvent({
    required this.date,
    required this.title,
    required this.type,
    required this.description,
  });

  final String date;
  final String title;
  final String type;
  final String description;
}

class MediaAnalyticsSnapshot {
  const MediaAnalyticsSnapshot({
    required this.topPhoto,
    required this.topVideo,
    required this.avgViewDuration,
    required this.tourCompletionRate,
    required this.downloadCount,
    required this.shareCount,
  });

  final String topPhoto;
  final String topVideo;
  final String avgViewDuration;
  final String tourCompletionRate;
  final int downloadCount;
  final int shareCount;
}

class MediaExperience {
  const MediaExperience({
    required this.slug,
    required this.propertyName,
    required this.estateName,
    required this.mediaCount,
    required this.heroHeadline,
    required this.featuredCards,
    required this.galleryImages,
    required this.virtualTourRooms,
    required this.droneChapters,
    required this.videos,
    required this.floorPlans,
    required this.masterplanDescription,
    required this.masterplanLegend,
    required this.constructionMilestones,
    required this.completionPercent,
    required this.expectedCompletion,
    required this.downloads,
    required this.openHouses,
    required this.timeline,
    required this.relatedSlugs,
  });

  final String slug;
  final String propertyName;
  final String estateName;
  final int mediaCount;
  final String heroHeadline;
  final List<MediaFeaturedCard> featuredCards;
  final List<MediaGalleryImage> galleryImages;
  final List<VirtualTourRoom> virtualTourRooms;
  final List<DroneChapter> droneChapters;
  final List<MediaVideoItem> videos;
  final List<FloorPlanItem> floorPlans;
  final String masterplanDescription;
  final List<String> masterplanLegend;
  final List<ConstructionMilestone> constructionMilestones;
  final int completionPercent;
  final String expectedCompletion;
  final List<MediaDownloadItem> downloads;
  final List<VirtualOpenHouse> openHouses;
  final List<MediaTimelineEvent> timeline;
  final List<String> relatedSlugs;
}

class MediaHubCms {
  const MediaHubCms({
    required this.heroHeadline,
    required this.heroSubheadline,
    required this.featuredExperiences,
    required this.pressKitItems,
    required this.brandAssets,
    required this.analytics,
  });

  final String heroHeadline;
  final String heroSubheadline;
  final List<MediaExperienceSummary> featuredExperiences;
  final List<String> pressKitItems;
  final List<String> brandAssets;
  final MediaAnalyticsSnapshot analytics;
}

class MediaExperienceSummary {
  const MediaExperienceSummary({
    required this.slug,
    required this.title,
    required this.estateName,
    required this.thumbnailLabel,
    required this.mediaCount,
  });

  final String slug;
  final String title;
  final String estateName;
  final String thumbnailLabel;
  final int mediaCount;
}

extension MediaGalleryCategoryLabel on MediaGalleryCategory {
  String get label => switch (this) {
        MediaGalleryCategory.exterior => 'Exterior',
        MediaGalleryCategory.interior => 'Interior',
        MediaGalleryCategory.livingRoom => 'Living Room',
        MediaGalleryCategory.kitchen => 'Kitchen',
        MediaGalleryCategory.bedrooms => 'Bedrooms',
        MediaGalleryCategory.bathrooms => 'Bathrooms',
        MediaGalleryCategory.amenities => 'Amenities',
        MediaGalleryCategory.neighborhood => 'Neighborhood',
        MediaGalleryCategory.construction => 'Construction',
        MediaGalleryCategory.landscape => 'Landscape',
      };
}

extension ConstructionPhaseLabel on ConstructionPhase {
  String get label => switch (this) {
        ConstructionPhase.planning => 'Planning',
        ConstructionPhase.foundation => 'Foundation',
        ConstructionPhase.structure => 'Structure',
        ConstructionPhase.roofing => 'Roofing',
        ConstructionPhase.finishing => 'Finishing',
        ConstructionPhase.inspection => 'Inspection',
        ConstructionPhase.completed => 'Completed',
      };
}
