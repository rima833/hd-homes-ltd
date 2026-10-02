import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/media/widgets/delivery_image.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/offline_updates_note.dart';
import 'package:hdhomesproject/features/investor/domain/entities/investor_models.dart';
import 'package:hdhomesproject/features/investor/presentation/providers/investor_portal_realtime_provider.dart';
import 'package:hdhomesproject/features/investor/presentation/providers/investor_providers.dart';
import 'package:hdhomesproject/features/investor/presentation/widgets/investor_gantt_chart.dart';
import 'package:hdhomesproject/features/investor/presentation/widgets/investor_portal_widgets.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

class InvestorConstructionPage extends ConsumerStatefulWidget {
  const InvestorConstructionPage({super.key});

  @override
  ConsumerState<InvestorConstructionPage> createState() =>
      _InvestorConstructionPageState();
}

class _InvestorConstructionPageState
    extends ConsumerState<InvestorConstructionPage> {
  String? _selectedProjectId;

  EdgeInsets _padding(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return EdgeInsets.all(w >= AppBreakpoints.tablet ? 24 : 16);
  }

  Future<void> _openMedia(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _previewPhoto(BuildContext context, String url) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: MediaDeliveryImage(
                  url: url,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton.filled(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(LucideIcons.x),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.charcoal.withValues(alpha: 0.85),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final updatesAsync = ref.watch(investorConstructionProvider);
    final connection = ref.watch(investorRealtimeConnectionProvider);
    final live = connection == InvestorRealtimeConnection.live;
    final pad = _padding(context);
    final isWide = MediaQuery.sizeOf(context).width >= AppBreakpoints.tablet;

    return updatesAsync.when(
      loading: () => const InvestorDashboardSkeleton(),
      error: (e, _) => InvestorErrorView(
        message: e,
        onRetry: () => ref.invalidate(investorConstructionProvider),
      ),
      data: (bundle) {
        if (bundle.isEmpty) {
          return InvestorEmptyState(
            title: 'No construction updates yet',
            message:
                'Progress stages, photos, drone videos, and milestones for your holdings stream here when Construction publishes them.',
            icon: LucideIcons.hardHat,
            action: FilledButton.icon(
              onPressed: () => ref.invalidate(investorConstructionProvider),
              icon: const Icon(LucideIcons.rotateCcw, size: 16),
              label: const Text('Refresh'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.charcoal,
              ),
            ),
          );
        }

        final selectedId = _selectedProjectId ?? bundle.primaryProject?.id;
        InvestorConstructionProject? selected;
        if (selectedId != null) {
          for (final p in bundle.projects) {
            if (p.id == selectedId) {
              selected = p;
              break;
            }
          }
          selected ??= bundle.primaryProject;
        }
        final view = selected == null
            ? bundle
            : InvestorConstructionBundle(
                projects: [selected],
                updates: selected.updates,
                milestones: selected.milestones,
                phases: selected.phases,
                overallPercent: selected.progressPct,
              );

        final videos = view.allVideos;
        final photos = view.allPhotos;
        final milestonesDone = view.milestones
            .where(
              (m) =>
                  m.status == 'completed' ||
                  m.status == 'done' ||
                  m.completedAt != null,
            )
            .length;
        final heroImage = selected?.coverImageUrl ??
            (photos.isNotEmpty
                ? photos.first
                : (videos.isNotEmpty ? videos.first.thumbnailUrl : null));
        final currentPhase = selected?.currentPhase;

        return RefreshIndicator(
          color: AppColors.gold,
          onRefresh: () async {
            ref.invalidate(investorConstructionProvider);
            await ref.read(investorConstructionProvider.future);
          },
          child: ListView(
            padding: pad,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Construction Progress',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: AppColors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Stages, milestones, and photos from the construction desk.',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.slate400,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _LiveChip(live: live, connection: connection),
                ],
              ),
              if (bundle.projects.length > 1) ...[
                const SizedBox(height: 20),
                SizedBox(
                  height: 108,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: bundle.projects.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, i) {
                      final p = bundle.projects[i];
                      final active = p.id == selectedId;
                      return _ProjectChip(
                        project: p,
                        selected: active,
                        onTap: () => setState(() => _selectedProjectId = p.id),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 20),
              _ConstructionHero(
                percent: view.overallPercent,
                milestonesDone: milestonesDone,
                milestonesTotal: view.milestones.length,
                updatesCount: view.updates.length,
                imageUrl: heroImage,
                isWide: isWide,
                projectName: selected?.name,
                scheduleStatus: selected?.scheduleStatus,
                expectedCompletion: selected?.targetEndDate,
                currentPhaseName: currentPhase?.name,
              ),
              if (view.phases.isNotEmpty) ...[
                const SizedBox(height: 24),
                InvestorSectionHeader(
                  title: 'Construction stages',
                  subtitle: currentPhase != null
                      ? 'Current: ${currentPhase.name}'
                      : '${view.phases.length} stages on programme',
                ),
                InvestorPortalCard(
                  child: _StagePipeline(phases: view.phases),
                ),
              ],
              if (view.milestones.isNotEmpty) ...[
                const SizedBox(height: 24),
                InvestorSectionHeader(
                  title: 'Milestone timeline',
                  subtitle:
                      '$milestonesDone of ${view.milestones.length} complete',
                ),
                InvestorPortalCard(
                  child: InvestorGanttChart(milestones: view.milestones),
                ),
                const SizedBox(height: 12),
                ...view.milestones.map(
                  (m) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _MilestoneTile(milestone: m),
                  ),
                ),
              ],
              if (videos.isNotEmpty) ...[
                const SizedBox(height: 24),
                const InvestorSectionHeader(
                  title: 'Drone & site videos',
                  subtitle: 'Tap to open in your browser',
                ),
                SizedBox(
                  height: 148,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: videos.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, i) {
                      final v = videos[i];
                      return InkWell(
                        onTap: () => _openMedia(context, v.url),
                        borderRadius: BorderRadius.circular(14),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: SizedBox(
                            width: 230,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (v.thumbnailUrl != null &&
                                    v.thumbnailUrl!.isNotEmpty)
                                  MediaDeliveryImage(
                                    url: v.thumbnailUrl!,
                                    fit: BoxFit.cover,
                                  )
                                else
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          AppColors.gold
                                              .withValues(alpha: 0.12),
                                          AppColors.darkSurface,
                                        ],
                                      ),
                                    ),
                                  ),
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        AppColors.deepBlack
                                            .withValues(alpha: 0.85),
                                      ],
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: AppColors.gold
                                              .withValues(alpha: 0.18),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: const Icon(
                                          LucideIcons.play,
                                          color: AppColors.gold,
                                          size: 20,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        v.title ?? 'Drone video',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              color: AppColors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Tap to play',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: AppColors.slate400,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              if (view.updates.isNotEmpty) ...[
                const SizedBox(height: 24),
                InvestorSectionHeader(
                  title: 'Progress updates',
                  subtitle:
                      '${view.updates.length} published update${view.updates.length == 1 ? '' : 's'}',
                ),
                ...view.updates.map(
                  (u) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _UpdateCard(
                      update: u,
                      onOpenMedia: (url) => _openMedia(context, url),
                      onPreviewPhoto: (url) => _previewPhoto(context, url),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

class _LiveChip extends StatelessWidget {
  const _LiveChip({required this.live, required this.connection});

  final bool live;
  final InvestorRealtimeConnection connection;

  @override
  Widget build(BuildContext context) {
    if (live || connection == InvestorRealtimeConnection.connecting) {
      return const SizedBox.shrink();
    }
    return const OfflineUpdatesNote();
  }
}

class _ProjectChip extends StatelessWidget {
  const _ProjectChip({
    required this.project,
    required this.selected,
    required this.onTap,
  });

  final InvestorConstructionProject project;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.gold.withValues(alpha: 0.12)
              : AppColors.darkSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? AppColors.gold.withValues(alpha: 0.55)
                : AppColors.slate700.withValues(alpha: 0.6),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              project.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const Spacer(),
            Text(
              '${project.progressPct.round()}% · ${project.scheduleStatus.replaceAll('_', ' ')}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.slate400,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StagePipeline extends StatelessWidget {
  const _StagePipeline({required this.phases});

  final List<InvestorConstructionPhase> phases;

  @override
  Widget build(BuildContext context) {
    final sorted = [...phases]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < sorted.length; i++) ...[
            if (i > 0)
              Container(
                width: 28,
                height: 2,
                margin: const EdgeInsets.only(bottom: 28),
                color: sorted[i - 1].isComplete
                    ? AppColors.success.withValues(alpha: 0.7)
                    : AppColors.slate700,
              ),
            _StageNode(phase: sorted[i]),
          ],
        ],
      ),
    );
  }
}

class _StageNode extends StatelessWidget {
  const _StageNode({required this.phase});

  final InvestorConstructionPhase phase;

  Color get _accent {
    if (phase.isComplete) return AppColors.success;
    if (phase.isActive) return AppColors.gold;
    return AppColors.slate500;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _accent.withValues(alpha: 0.15),
              border: Border.all(color: _accent, width: 2),
            ),
            child: Icon(
              phase.isComplete
                  ? LucideIcons.check
                  : phase.isActive
                      ? LucideIcons.hammer
                      : LucideIcons.circle,
              size: 16,
              color: _accent,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            phase.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            '${phase.progressPct.round()}%',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.slate400,
                ),
          ),
        ],
      ),
    );
  }
}

class _ConstructionHero extends StatelessWidget {
  const _ConstructionHero({
    required this.percent,
    required this.milestonesDone,
    required this.milestonesTotal,
    required this.updatesCount,
    required this.isWide,
    this.imageUrl,
    this.projectName,
    this.scheduleStatus,
    this.expectedCompletion,
    this.currentPhaseName,
  });

  final double percent;
  final int milestonesDone;
  final int milestonesTotal;
  final int updatesCount;
  final bool isWide;
  final String? imageUrl;
  final String? projectName;
  final String? scheduleStatus;
  final DateTime? expectedCompletion;
  final String? currentPhaseName;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.cardBorder,
      child: SizedBox(
        height: isWide ? 220 : 240,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl != null)
              MediaDeliveryImage(
                url: imageUrl!,
                fit: BoxFit.cover,
                errorWidget: const _HeroFallback(),
              )
            else
              const _HeroFallback(),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.deepBlack.withValues(alpha: 0.35),
                    AppColors.deepBlack.withValues(alpha: 0.92),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: isWide
                  ? Row(
                      children: [
                        InvestorCircularGauge(
                          percent: percent,
                          size: 96,
                          strokeWidth: 8,
                        ),
                        const SizedBox(width: 24),
                        Expanded(child: _heroCopy(context)),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            InvestorCircularGauge(
                              percent: percent,
                              size: 72,
                              strokeWidth: 6,
                            ),
                            const SizedBox(width: 16),
                            Expanded(child: _heroCopy(context)),
                          ],
                        ),
                        const Spacer(),
                        InvestorProgressBar(
                          label: 'Overall completion',
                          percent: percent,
                          color: AppColors.gold,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroCopy(BuildContext context) {
    final meta = <String>[
      if (currentPhaseName != null) currentPhaseName!,
      if (scheduleStatus != null)
        scheduleStatus!.replaceAll('_', ' '),
      if (expectedCompletion != null)
        'ETA ${DateFormat.yMMM().format(expectedCompletion!)}',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          projectName ?? 'Overall site progress',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          milestonesTotal > 0
              ? '$milestonesDone of $milestonesTotal milestones complete · $updatesCount update${updatesCount == 1 ? '' : 's'}'
              : '$updatesCount live update${updatesCount == 1 ? '' : 's'} from your projects',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.slate400,
              ),
        ),
        if (meta.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            meta.join(' · '),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
        if (isWide) ...[
          const SizedBox(height: 14),
          InvestorProgressBar(
            label: 'Overall completion',
            percent: percent,
            color: AppColors.gold,
          ),
        ],
      ],
    );
  }
}

class _HeroFallback extends StatelessWidget {
  const _HeroFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A1510),
            Color(0xFF0F1115),
            Color(0xFF152018),
          ],
        ),
      ),
    );
  }
}

class _MilestoneTile extends StatelessWidget {
  const _MilestoneTile({required this.milestone});

  final InvestorMilestone milestone;

  Color get _accent {
    switch (milestone.status) {
      case 'completed':
      case 'done':
        return AppColors.success;
      case 'in_progress':
      case 'active':
        return AppColors.gold;
      default:
        return AppColors.slate400;
    }
  }

  IconData get _icon {
    switch (milestone.status) {
      case 'completed':
      case 'done':
        return LucideIcons.checkCircle2;
      case 'in_progress':
      case 'active':
        return LucideIcons.loader;
      default:
        return LucideIcons.circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InvestorPortalCard(
      child: Row(
        children: [
          Icon(_icon, color: _accent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  milestone.name,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    milestone.status.replaceAll('_', ' '),
                    if (milestone.projectName != null) milestone.projectName!,
                    if (milestone.targetDate != null)
                      'Target ${DateFormat.yMMMd().format(milestone.targetDate!)}',
                    if (milestone.completedAt != null)
                      'Done ${DateFormat.yMMMd().format(milestone.completedAt!)}',
                  ].join(' · '),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.slate400,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UpdateCard extends StatelessWidget {
  const _UpdateCard({
    required this.update,
    required this.onOpenMedia,
    required this.onPreviewPhoto,
  });

  final InvestorConstructionUpdate update;
  final Future<void> Function(String url) onOpenMedia;
  final Future<void> Function(String url) onPreviewPhoto;

  @override
  Widget build(BuildContext context) {
    final tags = <String>[
      if (update.phaseName != null) update.phaseName!,
      if (update.milestoneName != null) update.milestoneName!,
    ];
    return InvestorPortalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (update.projectName != null)
            Text(
              update.projectName!,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          if (update.projectName != null) const SizedBox(height: 6),
          Text(
            update.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (update.updateDate != null) ...[
            const SizedBox(height: 4),
            Text(
              DateFormat.yMMMd().format(update.updateDate!),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.slate400,
                  ),
            ),
          ],
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: tags
                  .map(
                    (t) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        t,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.gold,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (update.completionPercent != null) ...[
            const SizedBox(height: 12),
            InvestorProgressBar(
              label: 'Completion at update',
              percent: update.completionPercent!,
              color: AppColors.info,
            ),
          ],
          if (update.description != null) ...[
            const SizedBox(height: 12),
            Text(
              update.description!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.slate400,
                    height: 1.4,
                  ),
            ),
          ],
          if (update.photos.isNotEmpty) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: update.photos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => onPreviewPhoto(update.photos[i]),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: MediaDeliveryImage(
                      url: update.photos[i],
                      width: 150,
                      height: 110,
                      fit: BoxFit.cover,
                      thumbnail: true,
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (update.videos.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: update.videos
                  .map(
                    (v) => ActionChip(
                      avatar: const Icon(LucideIcons.video, size: 16),
                      label: Text(v.title ?? 'Video'),
                      onPressed: () => onOpenMedia(v.url),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}
