import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/growth/seo/seo_engine.dart';
import 'package:hdhomesproject/core/website/seo/seo_binder.dart';
import 'package:hdhomesproject/core/website/seo/seo_config.dart';
import 'package:hdhomesproject/core/website/seo/seo_metadata.dart';
import 'package:hdhomesproject/core/website/components/breadcrumbs.dart';
import 'package:hdhomesproject/core/website/components/page_container.dart';
import 'package:hdhomesproject/core/widgets/feedback/empty_state.dart';
import 'package:hdhomesproject/features/estates/data/providers/estate_detail_provider.dart';
import 'package:hdhomesproject/features/estates/presentation/sections/estate_closing_sections.dart';
import 'package:hdhomesproject/features/estates/presentation/sections/estate_explore_sections.dart';
import 'package:hdhomesproject/features/estates/presentation/sections/estate_overview_sections.dart';
import 'package:hdhomesproject/features/estates/presentation/sections/estate_properties_sections.dart';
import 'package:hdhomesproject/features/estates/presentation/widgets/estate_detail_hero.dart';

/// Premium estate showcase — Volume 2 Part 6.
class EstateDetailPage extends ConsumerStatefulWidget {
  const EstateDetailPage({super.key, required this.estateSlug});

  final String estateSlug;

  @override
  ConsumerState<EstateDetailPage> createState() => _EstateDetailPageState();
}

class _EstateDetailPageState extends ConsumerState<EstateDetailPage> {
  final _propertiesKey = GlobalKey();

  void _scrollToProperties() {
    final target = _propertiesKey.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(estateDetailProvider(widget.estateSlug));

    if (detail == null) {
      return SeoBinder(
        metadata: const SeoMetadata(
          title: 'Estate not found | HD Homes',
          description: 'This development is not available.',
          robots: 'noindex, nofollow',
        ),
        child: EmptyState(
          title: 'Estate not found',
          message: 'This development may have been removed or is not yet published.',
          icon: Icons.location_city_outlined,
          actionLabel: 'Browse estates',
          onAction: () => context.go(RoutePaths.estates),
        ),
      );
    }

    final heroImage = detail.summary.heroImageUrl?.trim();
    final seo = SeoMetadata.estateDetail(
      detail.summary.name,
      detail.overview.description,
    )
        .copyWithOgImage(
          heroImage != null && heroImage.isNotEmpty ? heroImage : null,
        );
    final withCanonical = SeoMetadata(
      title: seo.title,
      description: seo.description,
      canonicalUrl: SeoConfig.canonicalFor('/estates/${detail.summary.slug}'),
      ogImageUrl: seo.ogImageUrl,
      keywords: seo.keywords,
      robots: seo.robots,
      structuredData: seo.structuredData,
    );

    return SeoBinder(
      metadata: withCanonical,
      child: Column(
        children: [
          EstateDetailHero(
            detail: detail,
            onExploreProperties: _scrollToProperties,
          ),
          PageContainer(
            child: WebsiteBreadcrumbs(
              items: [
                const BreadcrumbItem(label: 'Home', path: RoutePaths.home),
                const BreadcrumbItem(label: 'Estates', path: RoutePaths.estates),
                BreadcrumbItem(label: detail.summary.name),
              ],
            ),
          ),
          EstateOverviewSections(detail: detail),
          KeyedSubtree(
            key: _propertiesKey,
            child: EstatePropertiesSections(detail: detail),
          ),
          EstateExploreSections(detail: detail),
          EstateClosingSections(detail: detail),
        ],
      ),
    );
  }
}
