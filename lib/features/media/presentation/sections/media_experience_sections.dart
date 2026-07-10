import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/media/data/models/media_content.dart';
import 'package:hdhomesproject/features/media/presentation/widgets/media_card.dart';
import 'package:hdhomesproject/features/media/presentation/widgets/media_gallery_grid.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

/// Experience sections 2–11 — featured media through virtual open house.
class MediaExperienceSections extends HookWidget {
  const MediaExperienceSections({
    super.key,
    required this.experience,
    this.featuredKey,
    this.galleryKey,
    this.tourKey,
  });

  final MediaExperience experience;
  final GlobalKey? featuredKey;
  final GlobalKey? galleryKey;
  final GlobalKey? tourKey;

  @override
  Widget build(BuildContext context) {
    final tourRoom = useState(0);
    final comparePosition = useState(0.5);

    return Column(
      children: [
        SectionWrapper(
          key: featuredKey,
          child: Column(
            children: [
              const AnimatedSectionTitle(overline: 'FEATURED', title: 'Featured media'),
              const SizedBox(height: AppSpacing.xl),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cross = context.isMobile ? 2 : 4;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cross,
                      mainAxisSpacing: AppSpacing.base,
                      crossAxisSpacing: AppSpacing.base,
                      childAspectRatio: 1.1,
                    ),
                    itemCount: experience.featuredCards.length,
                    itemBuilder: (_, i) => MediaFeaturedCardWidget(card: experience.featuredCards[i]),
                  );
                },
              ),
            ],
          ),
        ),
        SectionWrapper(
          key: galleryKey,
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AnimatedSectionTitle(overline: 'GALLERY', title: 'HD image gallery'),
              const SizedBox(height: AppSpacing.xl),
              MediaGalleryGrid(images: experience.galleryImages),
            ],
          ),
        ),
        SectionWrapper(
          key: tourKey,
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: '360° TOUR',
                title: 'Virtual property tour',
                subtitle: 'Room navigation, hotspots, guided and free exploration modes.',
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                height: context.isMobile ? 280 : 360,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: AppRadius.cardBorder,
                  color: AppColors.charcoal,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(LucideIcons.rotate3d, size: 56, color: AppColors.gold),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      experience.virtualTourRooms[tourRoom.value].name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(experience.virtualTourRooms[tourRoom.value].description),
                    const SizedBox(height: AppSpacing.base),
                    Wrap(
                      spacing: AppSpacing.xs,
                      children: experience.virtualTourRooms[tourRoom.value].hotspots
                          .map((h) => Chip(label: Text(h)))
                          .toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.base),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () {
                      if (tourRoom.value > 0) tourRoom.value--;
                    },
                  ),
                  Text('Room ${tourRoom.value + 1} / ${experience.virtualTourRooms.length}'),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () {
                      if (tourRoom.value < experience.virtualTourRooms.length - 1) tourRoom.value++;
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        SectionWrapper(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              const AnimatedSectionTitle(overline: 'DRONE', title: 'Drone experience'),
              const SizedBox(height: AppSpacing.lg),
              Container(
                height: 240,
                decoration: BoxDecoration(
                  borderRadius: AppRadius.cardBorder,
                  gradient: LinearGradient(colors: [AppColors.charcoal, AppColors.gold.withValues(alpha: 0.1)]),
                ),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.plane, size: 48, color: AppColors.gold),
                      SizedBox(height: AppSpacing.sm),
                      Text('4K drone streaming · Fullscreen · Chapters · Subtitles'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.base),
              ...experience.droneChapters.map(
                (c) => ListTile(
                  leading: const Icon(LucideIcons.play, color: AppColors.gold),
                  title: Text(c.title),
                  trailing: Text(c.duration),
                ),
              ),
            ],
          ),
        ),
        SectionWrapper(
          child: Column(
            children: [
              const AnimatedSectionTitle(overline: 'VIDEOS', title: 'Property video center'),
              const SizedBox(height: AppSpacing.lg),
              ...experience.videos.map(
                (v) => Card(
                  child: ListTile(
                    leading: const Icon(LucideIcons.video, color: AppColors.gold),
                    title: Text(v.title),
                    subtitle: Text('${v.category} · ${v.quality}'),
                    trailing: Text(v.duration),
                  ),
                ),
              ),
            ],
          ),
        ),
        SectionWrapper(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AnimatedSectionTitle(overline: 'FLOOR PLANS', title: 'Interactive floor plan viewer'),
              const SizedBox(height: AppSpacing.lg),
              ...experience.floorPlans.map(
                (fp) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(fp.label, style: Theme.of(context).textTheme.titleMedium),
                        Text('${fp.floor} · ${fp.dimensions}'),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.xs,
                          children: fp.rooms.map((r) => Chip(label: Text(r))).toList(),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            TextButton.icon(onPressed: () {}, icon: const Icon(Icons.zoom_in), label: const Text('Zoom')),
                            TextButton.icon(onPressed: () {}, icon: const Icon(Icons.print), label: const Text('Print')),
                            TextButton.icon(onPressed: () {}, icon: const Icon(Icons.download), label: const Text('PDF')),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SectionWrapper(
          child: Column(
            children: [
              const AnimatedSectionTitle(overline: 'MASTERPLAN', title: 'Estate masterplan'),
              const SizedBox(height: AppSpacing.lg),
              Text(experience.masterplanDescription),
              const SizedBox(height: AppSpacing.base),
              Wrap(
                spacing: AppSpacing.sm,
                children: experience.masterplanLegend.map((l) => Chip(label: Text(l))).toList(),
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                height: 280,
                decoration: BoxDecoration(
                  borderRadius: AppRadius.cardBorder,
                  color: AppColors.charcoal,
                ),
                child: const Center(
                  child: Text('Interactive plot selection — roads, amenities, available/reserved/sold units'),
                ),
              ),
            ],
          ),
        ),
        SectionWrapper(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              AnimatedSectionTitle(
                overline: 'CONSTRUCTION',
                title: 'Construction progress',
                subtitle: '${experience.completionPercent}% complete · Expected ${experience.expectedCompletion}',
              ),
              const SizedBox(height: AppSpacing.lg),
              LinearProgressIndicator(value: experience.completionPercent / 100, color: AppColors.gold),
              const SizedBox(height: AppSpacing.xl),
              ...experience.constructionMilestones.map(
                (m) => ListTile(
                  leading: Icon(
                    m.completed ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: m.completed ? AppColors.success : AppColors.gold,
                  ),
                  title: Text(m.label),
                  subtitle: Text('${m.date} · ${m.completionPercent}%'),
                ),
              ),
            ],
          ),
        ),
        SectionWrapper(
          child: Column(
            children: [
              const AnimatedSectionTitle(overline: 'VIRTUAL OPEN HOUSE', title: 'Live virtual events'),
              const SizedBox(height: AppSpacing.lg),
              if (experience.openHouses.isEmpty)
                const Text('No upcoming virtual events — check back soon.')
              else
                ...experience.openHouses.map(
                  (e) => Card(
                    child: ListTile(
                      title: Text(e.title),
                      subtitle: Text('${e.date}\nHost: ${e.host} · ${e.registeredCount} registered'),
                      isThreeLine: true,
                      trailing: PrimaryButton(label: 'Register', onPressed: () => context.go(RoutePaths.contact)),
                    ),
                  ),
                ),
            ],
          ),
        ),
        SectionWrapper(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AnimatedSectionTitle(overline: 'BEFORE & AFTER', title: 'Interactive before & after viewer'),
              const SizedBox(height: AppSpacing.lg),
              Slider(
                value: comparePosition.value,
                onChanged: (v) => comparePosition.value = v,
              ),
              Container(
                height: 200,
                decoration: BoxDecoration(borderRadius: AppRadius.cardBorder, color: AppColors.charcoal),
                child: Center(
                  child: Text(
                    'Drag slider: ${(comparePosition.value * 100).round()}% construction complete',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Closing sections — downloads, press kit, share, AI guide, analytics, related, CTA.
class MediaClosingSections extends ConsumerWidget {
  const MediaClosingSections({super.key, required this.experience});

  final MediaExperience experience;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        SectionWrapper(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AnimatedSectionTitle(overline: 'DOWNLOADS', title: 'Media download center'),
              const SizedBox(height: AppSpacing.lg),
              ...experience.downloads.map(
                (d) => ListTile(
                  leading: const Icon(LucideIcons.download, color: AppColors.gold),
                  title: Text(d.title),
                  subtitle: Text('${d.category} · ${d.type} · ${d.size}'),
                  trailing: IconButton(icon: const Icon(Icons.file_download_outlined), onPressed: () {}),
                ),
              ),
            ],
          ),
        ),
        SectionWrapper(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              const AnimatedSectionTitle(overline: 'TIMELINE', title: 'Smart media timeline'),
              const SizedBox(height: AppSpacing.lg),
              ...experience.timeline.map(
                (t) => ListTile(
                  leading: const Icon(LucideIcons.clock, color: AppColors.gold),
                  title: Text('${t.date} — ${t.title}'),
                  subtitle: Text('${t.type}: ${t.description}'),
                ),
              ),
            ],
          ),
        ),
        SectionWrapper(
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'INVESTOR PREVIEW',
                title: 'Construction dashboard preview',
                subtitle: 'Public metrics with deeper detail for authenticated investors.',
              ),
              const SizedBox(height: AppSpacing.lg),
              LinearProgressIndicator(value: experience.completionPercent / 100, color: AppColors.gold),
              const SizedBox(height: AppSpacing.sm),
              Text('${experience.completionPercent}% complete · Expected ${experience.expectedCompletion}'),
              const SizedBox(height: AppSpacing.base),
              const Text(
                'Completion milestones, latest drone updates, upcoming activities, and progress gallery '
                'integrate with the future Investor Portal.',
              ),
            ],
          ),
        ),
        SectionWrapper(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              const AnimatedSectionTitle(overline: 'AI GUIDE', title: 'AI virtual property guide'),
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  borderRadius: AppRadius.cardBorder,
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
                ),
                child: const Text(
                  'AI assistant explains room features, highlights premium finishes, compares layouts, '
                  'answers questions, recommends similar properties, and schedules inspections from the tour.',
                ),
              ),
            ],
          ),
        ),
        SectionWrapper(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              const AnimatedSectionTitle(overline: 'SHARE', title: 'Share this experience'),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(LucideIcons.share2),
                    label: const Text('Share gallery'),
                    onPressed: () => Share.share('Explore ${experience.propertyName} on HD Homes'),
                  ),
                  OutlinedButton.icon(icon: const Icon(LucideIcons.link), label: const Text('Copy link'), onPressed: () {}),
                  OutlinedButton.icon(icon: const Icon(LucideIcons.qrCode), label: const Text('QR code'), onPressed: () {}),
                  OutlinedButton.icon(icon: const Icon(LucideIcons.mail), label: const Text('Email'), onPressed: () {}),
                ],
              ),
            ],
          ),
        ),
        SectionWrapper(
          child: Column(
            children: [
              const AnimatedSectionTitle(overline: 'VR & AR', title: 'VR & AR experiences (future-ready)'),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                'Architecture prepared for VR walkthroughs, AR furniture placement, room measurements, '
                'material selection, and mixed reality visualization.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        SectionWrapper(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              const AnimatedSectionTitle(overline: 'RELATED', title: 'Related media'),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                children: experience.relatedSlugs
                    .map((s) => ActionChip(
                          label: Text(s),
                          onPressed: () => context.go('${RoutePaths.gallery}/$s'),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
        SectionWrapper(
          child: context.isMobile
              ? Column(
                  children: [
                    PrimaryButton(
                      label: 'Book Physical Visit',
                      icon: LucideIcons.calendarCheck,
                      onPressed: () => context.go(RoutePaths.bookInspection),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    PrimaryButton(
                      label: 'Book Virtual Tour',
                      variant: ButtonVariant.secondary,
                      icon: LucideIcons.video,
                      onPressed: () => context.go(RoutePaths.contact),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: PrimaryButton(
                        label: 'Book Physical Visit',
                        icon: LucideIcons.calendarCheck,
                        onPressed: () => context.go(RoutePaths.bookInspection),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.base),
                    Expanded(
                      child: PrimaryButton(
                        label: 'Book Virtual Tour',
                        variant: ButtonVariant.secondary,
                        icon: LucideIcons.video,
                        onPressed: () => context.go(RoutePaths.contact),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}
