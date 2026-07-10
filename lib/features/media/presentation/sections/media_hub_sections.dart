import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/media/data/models/media_content.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Hub sections — featured experiences, press kit, analytics preview.
class MediaHubSections extends StatelessWidget {
  const MediaHubSections({
    super.key,
    required this.cms,
    this.experiencesKey,
    this.pressKitKey,
  });

  final MediaHubCms cms;
  final GlobalKey? experiencesKey;
  final GlobalKey? pressKitKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SectionWrapper(
          key: experiencesKey,
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'SHOWROOMS',
                title: 'Featured media experiences',
                subtitle: 'Explore estates and properties through immersive digital showrooms.',
              ),
              const SizedBox(height: AppSpacing.xl),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cross = context.isMobile ? 1 : 3;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cross,
                      mainAxisSpacing: AppSpacing.base,
                      crossAxisSpacing: AppSpacing.base,
                      childAspectRatio: context.isMobile ? 2.2 : 1.1,
                    ),
                    itemCount: cms.featuredExperiences.length,
                    itemBuilder: (_, i) {
                      final exp = cms.featuredExperiences[i];
                      return _ExperienceCard(
                        summary: exp,
                        onTap: () => context.go('${RoutePaths.gallery}/${exp.slug}'),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
        SectionWrapper(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'ANALYTICS',
                title: 'Smart media analytics preview',
                subtitle: 'Engagement insights that feed the Admin Analytics Dashboard.',
              ),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.base,
                runSpacing: AppSpacing.base,
                children: [
                  _AnalyticsChip(label: 'Top photo', value: cms.analytics.topPhoto),
                  _AnalyticsChip(label: 'Top video', value: cms.analytics.topVideo),
                  _AnalyticsChip(label: 'Avg view', value: cms.analytics.avgViewDuration),
                  _AnalyticsChip(label: 'Tour completion', value: cms.analytics.tourCompletionRate),
                  _AnalyticsChip(label: 'Downloads', value: '${cms.analytics.downloadCount}'),
                  _AnalyticsChip(label: 'Shares', value: '${cms.analytics.shareCount}'),
                ],
              ),
            ],
          ),
        ),
        SectionWrapper(
          key: pressKitKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AnimatedSectionTitle(
                overline: 'PRESS KIT',
                title: 'Press & brand kit',
                subtitle: 'Logos, guidelines, executive photos, and media contacts.',
              ),
              const SizedBox(height: AppSpacing.lg),
              if (context.isMobile) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Press resources', style: Theme.of(context).textTheme.titleSmall),
                    ...cms.pressKitItems.map((item) => ListTile(
                          dense: true,
                          leading: const Icon(LucideIcons.fileText, color: AppColors.gold, size: 18),
                          title: Text(item),
                        )),
                    const SizedBox(height: AppSpacing.lg),
                    Text('Brand assets', style: Theme.of(context).textTheme.titleSmall),
                    ...cms.brandAssets.map((item) => ListTile(
                          dense: true,
                          leading: const Icon(LucideIcons.palette, color: AppColors.gold, size: 18),
                          title: Text(item),
                        )),
                  ],
                ),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Press resources', style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: AppSpacing.sm),
                          ...cms.pressKitItems.map((item) => ListTile(
                                dense: true,
                                leading: const Icon(LucideIcons.fileText, color: AppColors.gold, size: 18),
                                title: Text(item),
                              )),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Brand assets', style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: AppSpacing.sm),
                          ...cms.brandAssets.map((item) => ListTile(
                                dense: true,
                                leading: const Icon(LucideIcons.palette, color: AppColors.gold, size: 18),
                                title: Text(item),
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        SectionWrapper(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Row(
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
                  label: 'Talk to Sales',
                  variant: ButtonVariant.secondary,
                  icon: LucideIcons.phone,
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

class _ExperienceCard extends StatefulWidget {
  const _ExperienceCard({required this.summary, required this.onTap});

  final MediaExperienceSummary summary;
  final VoidCallback onTap;

  @override
  State<_ExperienceCard> createState() => _ExperienceCardState();
}

class _ExperienceCardState extends State<_ExperienceCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.summary;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppDurations.fast,
        transform: Matrix4.translationValues(0, _hovered ? -4 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: AppRadius.cardBorder,
          boxShadow: _hovered ? AppShadows.lg : AppShadows.md,
        ),
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: AppRadius.cardBorder,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: AppRadius.cardBorder,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 100,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: AppRadius.cardBorder,
                      gradient: LinearGradient(
                        colors: [AppColors.charcoal, AppColors.gold.withValues(alpha: 0.15)],
                      ),
                    ),
                    child: Center(
                      child: Text(
                        s.thumbnailLabel,
                        style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.base),
                  Text(s.title, style: Theme.of(context).textTheme.titleMedium),
                  Text(s.estateName, style: Theme.of(context).textTheme.bodySmall),
                  const Spacer(),
                  Text('${s.mediaCount} media assets', style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: AppSpacing.sm),
                  const Text('Explore showroom →', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnalyticsChip extends StatelessWidget {
  const _AnalyticsChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: const Icon(LucideIcons.barChart2, size: 16, color: AppColors.gold),
      label: Text('$label: $value'),
    );
  }
}
