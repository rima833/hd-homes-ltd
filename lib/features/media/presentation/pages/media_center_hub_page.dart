import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/media/data/providers/media_cms_provider.dart';
import 'package:hdhomesproject/features/media/presentation/sections/media_hero_section.dart';
import 'package:hdhomesproject/features/media/presentation/sections/media_hub_sections.dart';

/// Media Center hub — Volume 2 Part 13.
class MediaCenterHubPage extends ConsumerWidget {
  const MediaCenterHubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cms = ref.watch(mediaHubCmsProvider);
    final loading = ref.watch(publishedEstatesCatalogProvider).isLoading ||
        ref.watch(publishedPropertiesCatalogProvider).isLoading;

    return Column(
      children: [
        MediaHubHeroSection(
          headline: cms.heroHeadline,
          subheadline: cms.heroSubheadline,
          imageUrl: cms.backgroundImageUrl,
          videoUrl: cms.backgroundVideoUrl,
        ),
        MediaHubSections(cms: cms, isLoading: loading),
      ],
    );
  }
}
