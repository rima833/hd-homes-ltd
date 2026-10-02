import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/estates/data/models/estate_detail_content.dart';

/// Public estates catalog — backed by published CMS estates when Supabase
/// is configured, falling back to the curated sample list otherwise (or
/// while the CMS has no published estates yet).
final estateListingsProvider = Provider<List<EstateSummary>>((ref) {
  ref.watch(publishedEstatesRealtimeProvider);
  final configured = ref.watch(supabaseConfiguredProvider);
  if (!configured) return _sampleEstates;

  final publishedAsync = ref.watch(publishedEstatesCatalogProvider);
  return publishedAsync.when(
    data: (estates) {
      if (estates.isEmpty) return _sampleEstates;
      return estates.map(_toEstateSummary).toList();
    },
    loading: () => _sampleEstates,
    error: (_, _) => _sampleEstates,
  );
});

EstateSummary _toEstateSummary(CmsEstateSummary e) => EstateSummary(
      id: e.id,
      slug: e.slug,
      name: e.name,
      location: e.location,
      city: e.city ?? '',
      state: e.state ?? '',
      status: _toEstateStatus(e.displayStatus),
      startingPrice: e.priceFromLabel?.trim().isNotEmpty == true
          ? e.priceFromLabel!.trim()
          : 'Price on request',
      startingPriceValue: 0,
      propertyTypes: const [],
      estateSize: '—',
      completionStatus: e.displayStatus,
      phaseCount: 1,
      propertyCount: e.propertyCount,
      heroImageUrl: e.coverImageUrl,
      heroVideoUrl: null,
      galleryUrls: e.galleryUrls,
      tagline: e.tagline?.trim().isNotEmpty == true
          ? e.tagline!.trim()
          : (e.description ?? ''),
    );

EstateStatus _toEstateStatus(String displayStatus) {
  final s = displayStatus.toLowerCase();
  if (s.contains('sold out')) return EstateStatus.soldOut;
  if (s.contains('complet')) return EstateStatus.completed;
  if (s.contains('construction')) return EstateStatus.underConstruction;
  if (s.contains('pre-launch') || s.contains('pre launch')) {
    return EstateStatus.preLaunch;
  }
  if (s.contains('coming soon')) return EstateStatus.comingSoon;
  if (s.contains('phase 2')) return EstateStatus.phase2Open;
  if (s.contains('phase 1')) return EstateStatus.phase1Open;
  if (s.contains('selling')) return EstateStatus.sellingFast;
  return EstateStatus.sellingFast;
}

const _sampleEstates = [
  EstateSummary(
    id: 'e001',
    slug: 'horizon-gardens',
    name: 'Horizon Gardens',
    location: 'Lekki, Lagos',
    city: 'Lagos',
    state: 'Lagos',
    status: EstateStatus.sellingFast,
    startingPrice: '₦45M',
    startingPriceValue: 45000000,
    propertyTypes: ['Villas', 'Duplexes', 'Terraces', 'Apartments'],
    estateSize: '42 hectares',
    completionStatus: 'Phase 1 — 78% complete',
    phaseCount: 3,
    propertyCount: 240,
    heroImageUrl: null,
    heroVideoUrl: null,
    tagline: 'Lekki\'s premier lifestyle estate with smart infrastructure and green living.',
  ),
  EstateSummary(
    id: 'e002',
    slug: 'emerald-heights',
    name: 'Emerald Heights',
    location: 'Central Business District, Abuja',
    city: 'Abuja',
    state: 'FCT',
    status: EstateStatus.phase1Open,
    startingPrice: '₦38M',
    startingPriceValue: 38000000,
    propertyTypes: ['Duplexes', 'Terraces', 'Apartments'],
    estateSize: '28 hectares',
    completionStatus: 'Phase 1 — Selling',
    phaseCount: 2,
    propertyCount: 180,
    heroImageUrl: null,
    heroVideoUrl: null,
    tagline: 'Elevated Abuja living with panoramic views and executive amenities.',
  ),
  EstateSummary(
    id: 'e003',
    slug: 'palm-grove-estate',
    name: 'Palm Grove Estate',
    location: 'Port Harcourt',
    city: 'Port Harcourt',
    state: 'Rivers',
    status: EstateStatus.completed,
    startingPrice: '₦28M',
    startingPriceValue: 28000000,
    propertyTypes: ['Terraces', 'Bungalows', 'Land Plots'],
    estateSize: '18 hectares',
    completionStatus: 'Completed — Ready to move',
    phaseCount: 2,
    propertyCount: 96,
    heroImageUrl: null,
    heroVideoUrl: null,
    tagline: 'Tranquil riverside community designed for families and professionals.',
  ),
  EstateSummary(
    id: 'e004',
    slug: 'green-valley',
    name: 'Green Valley',
    location: 'Ajah, Lagos',
    city: 'Lagos',
    state: 'Lagos',
    status: EstateStatus.underConstruction,
    startingPrice: '₦32M',
    startingPriceValue: 32000000,
    propertyTypes: ['Villas', 'Duplexes', 'Land Plots'],
    estateSize: '35 hectares',
    completionStatus: 'Phase 1 — Under construction',
    phaseCount: 3,
    propertyCount: 150,
    heroImageUrl: null,
    heroVideoUrl: null,
    tagline: 'Sustainable eco-estate with solar-ready homes and expansive green belts.',
  ),
];
