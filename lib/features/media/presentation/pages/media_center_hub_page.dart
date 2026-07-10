import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/features/media/data/providers/media_cms_provider.dart';
import 'package:hdhomesproject/features/media/presentation/sections/media_hero_section.dart';
import 'package:hdhomesproject/features/media/presentation/sections/media_hub_sections.dart';

/// Media Center hub — Volume 2 Part 13.
class MediaCenterHubPage extends ConsumerWidget {
  const MediaCenterHubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cms = ref.watch(mediaHubCmsProvider);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: MediaHubHeroSection(
            headline: cms.heroHeadline,
            subheadline: cms.heroSubheadline,
          ),
        ),
        SliverToBoxAdapter(child: MediaHubSections(cms: cms)),
      ],
    );
  }
}
