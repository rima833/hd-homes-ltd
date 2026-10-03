import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/breadcrumbs.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/core/website/seo/seo_binder.dart';
import 'package:hdhomesproject/core/website/seo/seo_config.dart';
import 'package:hdhomesproject/core/website/seo/seo_metadata.dart';
import 'package:hdhomesproject/core/website/seo/seo_resolver.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/core/widgets/feedback/loading_skeleton.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/construction/domain/entities/construction_platform_models.dart';
import 'package:hdhomesproject/features/construction/presentation/providers/construction_platform_providers.dart';
import 'package:hdhomesproject/features/construction/presentation/widgets/construction_gallery.dart';
import 'package:hdhomesproject/features/construction/presentation/widgets/construction_milestone_timeline.dart';
import 'package:hdhomesproject/features/construction/presentation/widgets/construction_progress_bar.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Public construction progress detail (`/construction/:slug`).
class ConstructionProgressDetailPage extends ConsumerWidget {
  const ConstructionProgressDetailPage({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(constructionPlatformRealtimeProvider);
    ref.watch(websiteConstructionUpdatesRealtimeProvider);

    final platformAsync =
        ref.watch(publicConstructionProjectBySlugProvider(slug));
    final cmsAsync = ref.watch(publishedWebsiteConstructionBySlugProvider(slug));

    final project =
        platformAsync.asData?.value ?? _fromCms(cmsAsync.asData?.value);
    final waiting = project == null &&
        (platformAsync.isLoading || cmsAsync.isLoading);
    if (waiting) {
      return const _StatusPanel(
        child: CircularProgressIndicator(color: AppColors.gold),
      );
    }
    if (project == null) {
      if (platformAsync.hasError && cmsAsync.hasError) {
        return _StatusPanel(
          message: userFacingError(
            platformAsync.error!,
            fallback: 'Unable to load progress.',
          ),
        );
      }
      return _StatusPanel(
        message: 'Construction update not found',
        action: TextButton(
          onPressed: () => context.go(RoutePaths.construction),
          child: const Text('Back to Construction Updates'),
        ),
      );
    }
    return _buildBody(context, project);
  }

  ConstructionProjectPublic? _fromCms(CmsWebsiteConstructionUpdate? cms) {
    if (cms == null) return null;
    return ConstructionProjectPublic.fromWebsiteRow({
      'id': cms.id,
      'project_name': cms.projectName,
      'slug': cms.slug,
      'status_update': cms.statusUpdate,
      'expected_completion': cms.expectedCompletion,
      'progress_pct': cms.progressPct,
      'current_phase_index': cms.safePhaseIndex,
      'phases': cms.phases,
      'cover_image_url': cms.coverImageUrl,
      'gallery_image_urls': cms.galleryImageUrls,
      'updated_at': null,
    });
  }

  Widget _buildBody(BuildContext context, ConstructionProjectPublic project) {
    final mobile = context.isMobile;
    final images = project.allImageUrls;
    final milestones = project.milestones.isNotEmpty
        ? project.milestones
        : project.phaseLabels
            .asMap()
            .entries
            .map(
              (e) => ConstructionMilestonePublic(
                id: 'phase-${e.key}',
                name: e.value,
                progressPct: e.key < project.activeMilestoneIndex
                    ? 100
                    : (e.key == project.activeMilestoneIndex
                        ? project.progressPct
                        : 0),
                status: e.key < project.activeMilestoneIndex
                    ? 'completed'
                    : (e.key == project.activeMilestoneIndex
                        ? 'in_progress'
                        : 'planned'),
              ),
            )
            .toList();

    return SeoBinder(
      metadata: SeoMetadata.constructionDetail(
        project.name,
        project.statusUpdate ??
            'Live construction progress for ${project.name} from HD Homes.',
      ).withCanonical(
        SeoConfig.canonicalFor(RoutePaths.constructionProgress(project.slug)),
      ),
      child: ColoredBox(
        color: AppColors.deepBlack,
        child: SectionWrapper(
          backgroundColor: AppColors.deepBlack,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WebsiteBreadcrumbs(
                items: [
                  const BreadcrumbItem(
                    label: 'Home',
                    path: RoutePaths.home,
                  ),
                  const BreadcrumbItem(
                    label: 'Properties',
                    path: RoutePaths.properties,
                  ),
                  const BreadcrumbItem(
                    label: 'Construction Updates',
                    path: RoutePaths.construction,
                  ),
                  BreadcrumbItem(label: project.name),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton.icon(
                onPressed: () => context.go(RoutePaths.construction),
                icon: const Icon(LucideIcons.arrowLeft, size: 16),
                label: const Text('All construction updates'),
                style: TextButton.styleFrom(foregroundColor: AppColors.gold),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (images.isNotEmpty)
                ConstructionGallery(imageUrls: images, showAll: true)
              else
                const LoadingSkeleton(height: 220),
              const SizedBox(height: AppSpacing.xl),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.name,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: mobile ? 30 : 42,
                            fontWeight: FontWeight.w700,
                            color: AppColors.white,
                          ),
                        ),
                        if (project.locationLabel != null &&
                            project.locationLabel!.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            project.locationLabel!,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: AppColors.textSecondaryDark,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Text(
                    '${project.progressPct.round()}%',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: mobile ? 36 : 48,
                      fontWeight: FontWeight.w700,
                      color: AppColors.gold,
                    ),
                  ),
                ],
              ),
              if (project.statusUpdate != null &&
                  project.statusUpdate!.trim().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  project.statusUpdate!,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textSecondaryDark,
                        height: 1.45,
                      ),
                ),
              ],
              if (project.description != null &&
                  project.description!.trim().isNotEmpty &&
                  project.description!.trim() !=
                      project.statusUpdate?.trim()) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  project.description!,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.white,
                        height: 1.55,
                      ),
                ),
              ],
              if (project.expectedCompletionLabel != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Expected completion: ${project.expectedCompletionLabel}',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              ConstructionProgressBar(percent: project.progressPct),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Construction timeline',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: AppSpacing.md),
              ConstructionMilestoneTimeline(
                milestones: milestones,
                activeIndex: project.activeMilestoneIndex,
                projectProgressPct: project.progressPct,
              ),
              if (project.latestUpdates.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xxl),
                Text(
                  'ALL UPDATES',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.gold,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppSpacing.md),
                for (final update in project.latestUpdates) ...[
                  _ConstructionUpdateDetail(update: update),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ],
              const SizedBox(height: AppSpacing.xl),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  PrimaryButton(
                    label: 'Book Inspection',
                    onPressed: () => context.go(RoutePaths.bookInspection),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.go(RoutePaths.contact),
                    icon: const Icon(LucideIcons.phone),
                    label: const Text('Contact HD Homes'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.gold,
                      side: const BorderSide(color: AppColors.gold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({this.message, this.child, this.action});

  final String? message;
  final Widget? child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.deepBlack,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 96, horizontal: 24),
        child: Column(
          children: [
            if (child != null) child!,
            if (message != null)
              Text(
                message!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.white,
                    ),
              ),
            if (action != null) ...[
              const SizedBox(height: 12),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class _ConstructionUpdateDetail extends StatelessWidget {
  const _ConstructionUpdateDetail({required this.update});

  final ConstructionProgressUpdate update;

  @override
  Widget build(BuildContext context) {
    final when = update.publishedAt ?? update.updateDate;
    final photos = [
      for (final media in update.media)
        if (media.deliveryUrl.trim().isNotEmpty) media.deliveryUrl.trim(),
    ];
    final body = (update.description?.trim().isNotEmpty == true)
        ? update.description!.trim()
        : update.shortDescription?.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151821),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (when != null)
            Text(
              DateFormat.yMMMMd().format(when.toLocal()),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
            ),
          const SizedBox(height: 6),
          Text(
            update.title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (update.progressPct != null) ...[
            const SizedBox(height: 6),
            Text(
              '${update.progressPct!.round()}% complete',
              style: const TextStyle(
                color: AppColors.gold,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (body != null && body.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              body,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondaryDark,
                    height: 1.5,
                  ),
            ),
          ],
          if (photos.isNotEmpty) ...[
            const SizedBox(height: 14),
            ConstructionGallery(imageUrls: photos, showAll: true),
          ],
        ],
      ),
    );
  }
}
