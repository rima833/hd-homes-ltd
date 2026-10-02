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

    return platformAsync.when(
      loading: () => cmsAsync.when(
        loading: () => const Scaffold(
          backgroundColor: AppColors.deepBlack,
          body: Center(child: CircularProgressIndicator(color: AppColors.gold)),
        ),
        error: (e, _) => _errorScaffold(context, e),
        data: (cms) => _buildBody(context, _fromCms(cms)),
      ),
      error: (e, _) => _errorScaffold(context, e),
      data: (platform) {
        if (platform != null) {
          return _buildBody(context, platform);
        }
        return cmsAsync.when(
          loading: () => const Scaffold(
            backgroundColor: AppColors.deepBlack,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.gold),
            ),
          ),
          error: (e, _) => _errorScaffold(context, e),
          data: (cms) => _buildBody(context, _fromCms(cms)),
        );
      },
    );
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

  Widget _errorScaffold(BuildContext context, Object err) {
    return Scaffold(
      backgroundColor: AppColors.deepBlack,
      body: Center(
        child: Text(
          userFacingError(err, fallback: 'Unable to load progress.'),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ConstructionProjectPublic? project) {
    if (project == null) {
      return Scaffold(
        backgroundColor: AppColors.deepBlack,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Construction update not found',
                style: TextStyle(color: AppColors.white),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go(RoutePaths.construction),
                child: const Text('Back to Construction Updates'),
              ),
            ],
          ),
        ),
      );
    }

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
                status: e.key < project.activeMilestoneIndex
                    ? 'completed'
                    : (e.key == project.activeMilestoneIndex
                        ? 'in_progress'
                        : 'planned'),
              ),
            )
            .toList();
    final latest = project.latestUpdates.isNotEmpty
        ? project.latestUpdates.first
        : null;

    return SeoBinder(
      metadata: SeoMetadata.constructionDetail(
        project.name,
        project.statusUpdate ??
            'Live construction progress for ${project.name} from HD Homes.',
      ).withCanonical(
        SeoConfig.canonicalFor(RoutePaths.constructionProgress(project.slug)),
      ),
      child: Scaffold(
      backgroundColor: AppColors.deepBlack,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: AppColors.deepBlack,
            foregroundColor: AppColors.white,
            pinned: true,
            title: Text(project.name),
            leading: IconButton(
              icon: const Icon(LucideIcons.arrowLeft),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(RoutePaths.construction);
                }
              },
            ),
          ),
          SliverToBoxAdapter(
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
                  const SizedBox(height: AppSpacing.lg),
                  if (images.isNotEmpty)
                    ConstructionGallery(imageUrls: images)
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
                            if (project.locationLabel != null) ...[
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
                  const SizedBox(height: AppSpacing.sm),
                  if (project.statusUpdate != null)
                    Text(
                      project.statusUpdate!,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.textSecondaryDark,
                            height: 1.45,
                          ),
                    ),
                  const SizedBox(height: AppSpacing.lg),
                  if (project.expectedCompletionLabel != null)
                    Text(
                      'Expected completion: ${project.expectedCompletionLabel}',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.gold,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
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
                  ),
                  if (latest != null) ...[
                    const SizedBox(height: AppSpacing.xxl),
                    Text(
                      'LATEST UPDATE',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.gold,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (latest.updateDate != null)
                      Text(
                        DateFormat.yMMMMd().format(latest.updateDate!),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.textSecondaryDark),
                      ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      latest.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    if (latest.description != null &&
                        latest.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        latest.description!,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                              color: AppColors.textSecondaryDark,
                              height: 1.5,
                            ),
                      ),
                    ],
                  ],
                  const SizedBox(height: AppSpacing.xxl),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      PrimaryButton(
                        label: 'Book Inspection',
                        onPressed: () =>
                            context.go(RoutePaths.bookInspection),
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
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }
}
