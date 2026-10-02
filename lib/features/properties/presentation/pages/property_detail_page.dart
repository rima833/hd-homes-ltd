import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/growth/analytics/journey_tracker.dart';
import 'package:hdhomesproject/core/website/seo/seo_binder.dart';
import 'package:hdhomesproject/core/website/seo/seo_config.dart';
import 'package:hdhomesproject/core/website/seo/seo_metadata.dart';
import 'package:hdhomesproject/core/website/seo/seo_resolver.dart';
import 'package:hdhomesproject/core/widgets/feedback/empty_state.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/properties/data/providers/property_detail_provider.dart';
import 'package:hdhomesproject/features/properties/presentation/sections/property_detail_body_sections.dart';
import 'package:hdhomesproject/features/properties/presentation/sections/property_detail_closing_sections.dart';
import 'package:hdhomesproject/features/properties/presentation/sections/property_detail_explore_sections.dart';
import 'package:hdhomesproject/features/properties/presentation/sections/property_detail_header.dart';
import 'package:hdhomesproject/features/properties/presentation/widgets/property_media_gallery.dart';

/// Premium digital property showroom — Volume 2 Part 5.
class PropertyDetailPage extends ConsumerStatefulWidget {
  const PropertyDetailPage({super.key, required this.propertyId});

  final String propertyId;

  @override
  ConsumerState<PropertyDetailPage> createState() => _PropertyDetailPageState();
}

class _PropertyDetailPageState extends ConsumerState<PropertyDetailPage> {
  String? _trackedViewId;

  @override
  Widget build(BuildContext context) {
    ref.watch(publishedPropertiesRealtimeProvider);
    final detail = ref.watch(propertyDetailProvider(widget.propertyId));
    final remote = ref.watch(publishedPropertyByIdProvider(widget.propertyId));

    if (detail != null && _trackedViewId != detail.listing.id) {
      _trackedViewId = detail.listing.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        trackGrowthPropertyView(ref, detail.listing.id);
      });
    }

    if (detail == null && remote.isLoading) {
      return const SizedBox(
        height: 320,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (detail == null) {
      return EmptyState(
        title: 'Property not found',
        message: 'This listing may have been removed or is no longer available.',
        icon: Icons.home_work_outlined,
        actionLabel: 'Browse properties',
        onAction: () => context.go(RoutePaths.properties),
      );
    }

    final seo = SeoMetadata.propertyDetail(
      detail.listing.title,
      detail.overview.summary,
    ).withCanonical(SeoConfig.canonicalFor('/properties/${detail.listing.id}'));

    return SeoBinder(
      metadata: seo,
      child: Column(
        children: [
          PropertyMediaGallery(media: detail.media, title: detail.listing.title),
          PropertyDetailHeader(detail: detail),
          PropertyDetailBodySections(detail: detail),
          PropertyDetailExploreSections(detail: detail),
          PropertyDetailClosingSections(detail: detail),
        ],
      ),
    );
  }
}
