import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/website/components/breadcrumbs.dart';
import 'package:hdhomesproject/core/website/components/page_container.dart';
import 'package:hdhomesproject/core/website/seo/seo_binder.dart';
import 'package:hdhomesproject/core/website/seo/seo_config.dart';
import 'package:hdhomesproject/core/website/seo/seo_metadata.dart';
import 'package:hdhomesproject/core/website/seo/seo_resolver.dart';
import 'package:hdhomesproject/core/widgets/feedback/empty_state.dart';
import 'package:hdhomesproject/features/media/data/providers/media_cms_provider.dart';
import 'package:hdhomesproject/features/media/presentation/sections/media_experience_sections.dart';
import 'package:hdhomesproject/features/media/presentation/sections/media_hero_section.dart';

/// Immersive media experience detail — Volume 2 Part 13.
class MediaExperiencePage extends ConsumerStatefulWidget {
  const MediaExperiencePage({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<MediaExperiencePage> createState() => _MediaExperiencePageState();
}

class _MediaExperiencePageState extends ConsumerState<MediaExperiencePage> {
  final _tourKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final experience = ref.watch(mediaExperienceProvider(widget.slug));

    if (experience == null) {
      return EmptyState(
        title: 'Media experience not found',
        message: 'This showroom may have been unpublished or moved.',
        icon: Icons.perm_media_outlined,
        actionLabel: 'Browse Media Center',
        onAction: () => context.go(RoutePaths.gallery),
      );
    }

    final seo = SeoMetadata.mediaExperience(
      experience.propertyName,
      '${experience.mediaCount} media assets — 360° tours, drone footage, floor plans, and construction progress.',
    ).withCanonical(SeoConfig.canonicalFor('${RoutePaths.gallery}/${experience.slug}'));

    return SeoBinder(
      metadata: seo,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: MediaHeroSection(
              headline: experience.heroHeadline,
              subheadline: 'Immersive digital showroom for ${experience.estateName}',
              propertyName: experience.propertyName,
              estateName: experience.estateName,
              mediaCount: experience.mediaCount,
              onWatchVideo: () {},
              onVirtualTour: () {
                final target = _tourKey.currentContext;
                if (target != null) {
                  Scrollable.ensureVisible(target, duration: const Duration(milliseconds: 500));
                }
              },
            ),
          ),
          SliverToBoxAdapter(
            child: PageContainer(
              child: WebsiteBreadcrumbs(
                items: [
                  const BreadcrumbItem(label: 'Home', path: RoutePaths.home),
                  const BreadcrumbItem(label: 'Media Center', path: RoutePaths.gallery),
                  BreadcrumbItem(label: experience.propertyName),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: MediaExperienceSections(
              experience: experience,
              tourKey: _tourKey,
            ),
          ),
          SliverToBoxAdapter(child: MediaClosingSections(experience: experience)),
        ],
      ),
    );
  }
}
