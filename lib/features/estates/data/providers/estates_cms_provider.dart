import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/cms/domain/data/hub_page_cms.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';

class EstatesHubCms {
  const EstatesHubCms({
    required this.heroHeadline,
    required this.heroSubheadline,
    this.overline = 'ESTATES',
    this.backgroundImageUrl,
    this.backgroundVideoUrl,
  });

  final String heroHeadline;
  final String heroSubheadline;
  final String overline;
  final String? backgroundImageUrl;
  final String? backgroundVideoUrl;
}

const _estatesHubFallback = EstatesHubCms(
  heroHeadline: 'Flagship developments',
  heroSubheadline:
      'Explore entire communities — master plans, amenities, inventory, and investment potential.',
);

final estatesHubCmsProvider = Provider<EstatesHubCms>((ref) {
  final base = _estatesHubFallback;
  if (!ref.watch(supabaseConfiguredProvider)) return base;
  final overlay =
      hubHeroFromPage(ref.watch(publishedPageBySlugProvider('estates')).valueOrNull);
  if (overlay.isEmpty) return base;
  return EstatesHubCms(
    heroHeadline: overlay.headline ?? base.heroHeadline,
    heroSubheadline: overlay.subheadline ?? base.heroSubheadline,
    backgroundImageUrl:
        overlay.backgroundImageUrl ?? base.backgroundImageUrl,
    backgroundVideoUrl:
        overlay.backgroundVideoUrl ?? base.backgroundVideoUrl,
  );
});
