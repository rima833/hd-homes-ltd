import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/estates/data/models/estate_detail_content.dart';

/// Public estates catalog. Only estates the admin has published.
final estateListingsProvider = Provider<List<EstateSummary>>((ref) {
  return ref.watch(estateListingsAsyncProvider).valueOrNull ?? const [];
});

/// Loading, error, and published estates for the public catalog.
final estateListingsAsyncProvider =
    Provider<AsyncValue<List<EstateSummary>>>((ref) {
  ref.watch(publishedEstatesRealtimeProvider);
  if (!ref.watch(supabaseConfiguredProvider)) {
    return const AsyncData([]);
  }
  return ref.watch(publishedEstatesCatalogProvider).when(
        data: (estates) => AsyncData(estates.map(_toEstateSummary).toList()),
        loading: () => const AsyncLoading(),
        error: AsyncError.new,
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
