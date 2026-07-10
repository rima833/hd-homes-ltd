import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/features/media/data/models/media_content.dart';

final mediaHubCmsProvider = Provider<MediaHubCms>((ref) => _hubCms);

final mediaExperienceProvider = Provider.family<MediaExperience?, String>((ref, slug) {
  return _experiences[slug];
});

final mediaExperiencesProvider = Provider<List<MediaExperience>>((ref) => _experiences.values.toList());

final _hubCms = MediaHubCms(
  heroHeadline: 'Experience Properties Before You Visit.',
  heroSubheadline:
      'Immersive galleries, 360° tours, drone footage, floor plans, construction progress, and virtual open houses.',
  featuredExperiences: const [
    MediaExperienceSummary(
      slug: 'horizon-gardens',
      title: 'Horizon Gardens Estate',
      estateName: 'Horizon Gardens',
      thumbnailLabel: 'Estate Showcase',
      mediaCount: 142,
    ),
    MediaExperienceSummary(
      slug: 'h001',
      title: 'Horizon Gardens 3BR Terrace',
      estateName: 'Horizon Gardens',
      thumbnailLabel: 'Property Tour',
      mediaCount: 48,
    ),
    MediaExperienceSummary(
      slug: 'emerald-heights',
      title: 'Emerald Heights',
      estateName: 'Emerald Heights',
      thumbnailLabel: 'Construction Progress',
      mediaCount: 86,
    ),
  ],
  pressKitItems: const [
    'HD Homes logo pack (PNG, SVG)',
    'Brand guidelines PDF',
    'Executive headshots',
    'Award certificates',
    'Press releases archive',
    'Media contact directory',
  ],
  brandAssets: const [
    'Primary logo — dark',
    'Primary logo — light',
    'Wordmark',
    'Brand colors',
    'Typography guide',
  ],
  analytics: const MediaAnalyticsSnapshot(
    topPhoto: 'Horizon Gardens aerial dusk',
    topVideo: 'Estate launch drone tour',
    avgViewDuration: '4m 32s',
    tourCompletionRate: '68%',
    downloadCount: 1240,
    shareCount: 890,
  ),
);

final _experiences = <String, MediaExperience>{
  'horizon-gardens': _horizonGardens,
  'h001': _horizonTerrace,
  'emerald-heights': _emeraldHeights,
};

MediaExperience get defaultMediaExperience => _horizonGardens;

final _horizonGardens = MediaExperience(
  slug: 'horizon-gardens',
  propertyName: 'Horizon Gardens Estate',
  estateName: 'Horizon Gardens',
  mediaCount: 142,
  heroHeadline: 'Horizon Gardens — Digital Showroom',
  featuredCards: const [
    MediaFeaturedCard(type: MediaAssetType.photo, title: 'Photos', iconName: 'image', count: 64, lastUpdated: 'Apr 2026', cta: 'View gallery'),
    MediaFeaturedCard(type: MediaAssetType.video, title: 'Videos', iconName: 'video', count: 12, lastUpdated: 'Mar 2026', cta: 'Watch'),
    MediaFeaturedCard(type: MediaAssetType.virtualTour, title: '360° Tour', iconName: 'rotate3d', count: 1, lastUpdated: 'Feb 2026', cta: 'Start tour'),
    MediaFeaturedCard(type: MediaAssetType.drone, title: 'Drone Tour', iconName: 'plane', count: 4, lastUpdated: 'Apr 2026', cta: 'Fly over'),
    MediaFeaturedCard(type: MediaAssetType.floorPlan, title: 'Floor Plans', iconName: 'layout', count: 8, lastUpdated: 'Jan 2026', cta: 'Explore'),
    MediaFeaturedCard(type: MediaAssetType.construction, title: 'Construction', iconName: 'hardHat', count: 24, lastUpdated: 'Weekly', cta: 'View progress'),
    MediaFeaturedCard(type: MediaAssetType.brochure, title: 'Brochures', iconName: 'fileText', count: 3, lastUpdated: 'Mar 2026', cta: 'Download'),
    MediaFeaturedCard(type: MediaAssetType.masterplan, title: 'Masterplan', iconName: 'map', count: 1, lastUpdated: 'Dec 2025', cta: 'View plan'),
  ],
  galleryImages: const [
    MediaGalleryImage(id: 'g1', category: MediaGalleryCategory.exterior, caption: 'Main entrance at dusk', alt: 'Horizon Gardens entrance'),
    MediaGalleryImage(id: 'g2', category: MediaGalleryCategory.landscape, caption: 'Central park and water feature', alt: 'Estate park'),
    MediaGalleryImage(id: 'g3', category: MediaGalleryCategory.amenities, caption: 'Clubhouse and pool', alt: 'Clubhouse'),
    MediaGalleryImage(id: 'g4', category: MediaGalleryCategory.construction, caption: 'Phase 1 structure progress', alt: 'Construction'),
    MediaGalleryImage(id: 'g5', category: MediaGalleryCategory.neighborhood, caption: 'Lekki corridor aerial', alt: 'Neighborhood'),
    MediaGalleryImage(id: 'g6', category: MediaGalleryCategory.interior, caption: 'Show unit living area', alt: 'Interior'),
  ],
  virtualTourRooms: const [
    VirtualTourRoom(name: 'Living Room', description: 'Open-plan living with premium finishes.', hotspots: ['Kitchen', 'Balcony', 'Dining']),
    VirtualTourRoom(name: 'Master Bedroom', description: 'En-suite with walk-in closet.', hotspots: ['Bathroom', 'Closet']),
    VirtualTourRoom(name: 'Kitchen', description: 'Fitted kitchen with island.', hotspots: ['Living Room', 'Utility']),
  ],
  droneChapters: const [
    DroneChapter(title: 'Estate overview', duration: '2:15'),
    DroneChapter(title: 'Infrastructure & roads', duration: '1:40'),
    DroneChapter(title: 'Amenities flyover', duration: '1:55'),
    DroneChapter(title: 'Neighborhood context', duration: '2:30'),
  ],
  videos: const [
    MediaVideoItem(title: 'Horizon Gardens launch film', category: 'Marketing', duration: '3:42', quality: '4K'),
    MediaVideoItem(title: 'Construction update — Week 14', category: 'Construction', duration: '4:10', quality: '1080p'),
    MediaVideoItem(title: 'Customer testimonial — The Okafor Family', category: 'Testimonial', duration: '2:08', quality: '1080p'),
  ],
  floorPlans: const [
    FloorPlanItem(label: '3BR Terrace', floor: 'Ground', dimensions: '180 sqm', rooms: ['Living', 'Kitchen', '3 Beds', '3 Baths']),
    FloorPlanItem(label: '4BR Duplex', floor: 'Ground + First', dimensions: '320 sqm', rooms: ['Living', 'Dining', '4 Beds', '4 Baths', 'Study']),
  ],
  masterplanDescription: '240-unit lifestyle estate with parks, clubhouse, and commercial strip.',
  masterplanLegend: const ['Available', 'Reserved', 'Sold', 'Amenities', 'Roads', 'Parks'],
  constructionMilestones: const [
    ConstructionMilestone(phase: ConstructionPhase.planning, label: 'Planning', completionPercent: 100, date: 'Q3 2025', completed: true),
    ConstructionMilestone(phase: ConstructionPhase.foundation, label: 'Foundation', completionPercent: 100, date: 'Q4 2025', completed: true),
    ConstructionMilestone(phase: ConstructionPhase.structure, label: 'Structure', completionPercent: 85, date: 'Apr 2026', completed: false),
    ConstructionMilestone(phase: ConstructionPhase.roofing, label: 'Roofing', completionPercent: 40, date: 'May 2026', completed: false),
    ConstructionMilestone(phase: ConstructionPhase.finishing, label: 'Finishing', completionPercent: 10, date: 'Q3 2026', completed: false),
    ConstructionMilestone(phase: ConstructionPhase.inspection, label: 'Inspection', completionPercent: 0, date: 'Q4 2026', completed: false),
    ConstructionMilestone(phase: ConstructionPhase.completed, label: 'Completed', completionPercent: 0, date: 'Q1 2027', completed: false),
  ],
  completionPercent: 62,
  expectedCompletion: 'Q1 2027',
  downloads: const [
    MediaDownloadItem(title: 'Horizon Gardens Brochure', type: 'PDF', size: '4.2 MB', category: 'Brochure'),
    MediaDownloadItem(title: 'Estate Masterplan', type: 'PDF', size: '8.1 MB', category: 'Masterplan'),
    MediaDownloadItem(title: 'Investment Pack', type: 'PDF', size: '2.8 MB', category: 'Investment'),
    MediaDownloadItem(title: 'Price List — Phase 1', type: 'PDF', size: '1.1 MB', category: 'Pricing'),
  ],
  openHouses: const [
    VirtualOpenHouse(
      title: 'Horizon Gardens Virtual Open House',
      date: 'Sat, 18 Apr 2026 · 11:00 AM WAT',
      host: 'Tunde Bakare, Senior Property Advisor',
      registeredCount: 84,
      status: 'Registration open',
    ),
  ],
  timeline: const [
    MediaTimelineEvent(date: 'Dec 2025', title: 'Concept renders published', type: 'Render', description: 'Initial architectural visualization.'),
    MediaTimelineEvent(date: 'Jan 2026', title: 'Groundbreaking ceremony', type: 'Event', description: 'Official launch with drone coverage.'),
    MediaTimelineEvent(date: 'Mar 2026', title: 'Phase 1 marketing launch', type: 'Marketing', description: 'Full media kit and virtual tour live.'),
    MediaTimelineEvent(date: 'Apr 2026', title: 'Weekly construction drone update', type: 'Construction', description: 'Structure 85% complete.'),
  ],
  relatedSlugs: const ['h001', 'emerald-heights'],
);

final _horizonTerrace = MediaExperience(
  slug: 'h001',
  propertyName: 'Horizon Gardens 3BR Terrace',
  estateName: 'Horizon Gardens',
  mediaCount: 48,
  heroHeadline: '3BR Terrace — Virtual Showroom',
  featuredCards: _horizonGardens.featuredCards,
  galleryImages: _horizonGardens.galleryImages.take(4).toList(),
  virtualTourRooms: _horizonGardens.virtualTourRooms,
  droneChapters: _horizonGardens.droneChapters.take(2).toList(),
  videos: _horizonGardens.videos.take(2).toList(),
  floorPlans: _horizonGardens.floorPlans.take(1).toList(),
  masterplanDescription: 'Unit within Horizon Gardens Phase 1.',
  masterplanLegend: _horizonGardens.masterplanLegend,
  constructionMilestones: _horizonGardens.constructionMilestones,
  completionPercent: 62,
  expectedCompletion: 'Q1 2027',
  downloads: _horizonGardens.downloads.take(2).toList(),
  openHouses: _horizonGardens.openHouses,
  timeline: _horizonGardens.timeline.take(3).toList(),
  relatedSlugs: const ['horizon-gardens', 'emerald-heights'],
);

final _emeraldHeights = MediaExperience(
  slug: 'emerald-heights',
  propertyName: 'Emerald Heights Estate',
  estateName: 'Abuja',
  mediaCount: 86,
  heroHeadline: 'Emerald Heights — Construction Showcase',
  featuredCards: _horizonGardens.featuredCards,
  galleryImages: _horizonGardens.galleryImages,
  virtualTourRooms: _horizonGardens.virtualTourRooms.take(2).toList(),
  droneChapters: _horizonGardens.droneChapters,
  videos: _horizonGardens.videos,
  floorPlans: _horizonGardens.floorPlans,
  masterplanDescription: 'Premium Abuja development with smart city features.',
  masterplanLegend: _horizonGardens.masterplanLegend,
  constructionMilestones: _horizonGardens.constructionMilestones,
  completionPercent: 45,
  expectedCompletion: 'Q2 2027',
  downloads: _horizonGardens.downloads,
  openHouses: const [],
  timeline: _horizonGardens.timeline,
  relatedSlugs: const ['horizon-gardens'],
);
