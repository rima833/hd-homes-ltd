import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/media/widgets/delivery_image.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/construction/domain/entities/construction_platform_models.dart';
import 'package:hdhomesproject/features/construction/presentation/widgets/construction_milestone_timeline.dart';
import 'package:hdhomesproject/features/construction/presentation/widgets/construction_progress_bar.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

class ConstructionProjectCard extends StatefulWidget {
  const ConstructionProjectCard({
    super.key,
    required this.project,
    required this.onView,
  });

  final ConstructionProjectPublic project;
  final VoidCallback onView;

  @override
  State<ConstructionProjectCard> createState() =>
      _ConstructionProjectCardState();
}

class _ConstructionProjectCardState extends State<ConstructionProjectCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final project = widget.project;
    final mobile = context.isMobile;
    final cover = project.coverImageUrl?.trim();
    final thumbs = project.allImageUrls;
    final milestones = _milestones(project);
    final updates = project.latestUpdates.take(4).toList();
    final updatedLabel = _relativeUpdated(project.updatedAt);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        transform: Matrix4.identity()..translate(0.0, _hovered ? -3.0 : 0.0),
        decoration: BoxDecoration(
          color: const Color(0xFF151821),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.white.withValues(alpha: _hovered ? 0.14 : 0.08),
          ),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.1),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: EdgeInsets.all(mobile ? AppSpacing.base : AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (mobile)
                _buildMobileLayout(
                  project,
                  cover,
                  thumbs,
                  milestones,
                  updates,
                  updatedLabel,
                )
              else
                _buildDesktopLayout(
                  project,
                  cover,
                  thumbs,
                  milestones,
                  updates,
                  updatedLabel,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(
    ConstructionProjectPublic project,
    String? cover,
    List<String> thumbs,
    List<ConstructionMilestonePublic> milestones,
    List<ConstructionProgressUpdate> updates,
    String updatedLabel,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 280,
              child: _MediaColumn(
                cover: cover,
                thumbs: thumbs,
                scheduleStatus: project.scheduleStatus,
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _ProjectHeader(project: project)),
                      _LiveUpdatedBadge(label: updatedLabel),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ConstructionProgressBar(percent: project.progressPct),
                  const SizedBox(height: AppSpacing.lg),
                  ConstructionMilestoneTimeline(
                    milestones: milestones,
                    activeIndex: project.activeMilestoneIndex,
                    projectProgressPct: project.progressPct,
                  ),
                ],
              ),
            ),
          ],
        ),
        if (updates.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _LatestUpdatesRow(
            updates: updates,
            onViewAll: widget.onView,
          ),
        ] else ...[
          const SizedBox(height: AppSpacing.base),
          Align(
            alignment: Alignment.centerRight,
            child: _ViewAllButton(onPressed: widget.onView),
          ),
        ],
      ],
    );
  }

  Widget _buildMobileLayout(
    ConstructionProjectPublic project,
    String? cover,
    List<String> thumbs,
    List<ConstructionMilestonePublic> milestones,
    List<ConstructionProgressUpdate> updates,
    String updatedLabel,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _ProjectHeader(project: project)),
            _LiveUpdatedBadge(label: updatedLabel, compact: true),
          ],
        ),
        const SizedBox(height: AppSpacing.base),
        _MediaColumn(
          cover: cover,
          thumbs: thumbs,
          scheduleStatus: project.scheduleStatus,
        ),
        const SizedBox(height: AppSpacing.lg),
        ConstructionProgressBar(percent: project.progressPct),
        const SizedBox(height: AppSpacing.lg),
        ConstructionMilestoneTimeline(
          milestones: milestones,
          activeIndex: project.activeMilestoneIndex,
          projectProgressPct: project.progressPct,
          compact: true,
        ),
        if (updates.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _LatestUpdatesRow(
            updates: updates,
            onViewAll: widget.onView,
          ),
        ] else ...[
          const SizedBox(height: AppSpacing.base),
          Align(
            alignment: Alignment.centerRight,
            child: _ViewAllButton(onPressed: widget.onView),
          ),
        ],
      ],
    );
  }

  List<ConstructionMilestonePublic> _milestones(
    ConstructionProjectPublic project,
  ) {
    if (project.milestones.isNotEmpty) return project.milestones;
    return project.phaseLabels
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
  }

  String _relativeUpdated(DateTime? at) {
    if (at == null) return 'Recently';
    final local = at.toLocal();
    final now = DateTime.now();
    final sameDay = local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    if (sameDay) return 'Today, ${DateFormat.jm().format(local)}';
    final yesterday = now.subtract(const Duration(days: 1));
    final wasYesterday = local.year == yesterday.year &&
        local.month == yesterday.month &&
        local.day == yesterday.day;
    if (wasYesterday) return 'Yesterday, ${DateFormat.jm().format(local)}';
    final diff = now.difference(local);
    if (diff.inHours < 48) return '${diff.inHours} hours ago';
    return DateFormat.yMMMd().format(local);
  }
}

class _MediaColumn extends StatelessWidget {
  const _MediaColumn({
    required this.cover,
    required this.thumbs,
    required this.scheduleStatus,
  });

  final String? cover;
  final List<String> thumbs;
  final ConstructionScheduleStatus scheduleStatus;

  @override
  Widget build(BuildContext context) {
    final badgeBg = switch (scheduleStatus) {
      ConstructionScheduleStatus.ahead => AppColors.gold,
      ConstructionScheduleStatus.atRisk => AppColors.warning,
      ConstructionScheduleStatus.delayed => AppColors.error,
      _ => const Color(0xFF22C55E),
    };
    final badgeFg = switch (scheduleStatus) {
      ConstructionScheduleStatus.ahead => const Color(0xFF121212),
      _ => Colors.white,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: cover != null && cover!.isNotEmpty
                    ? MediaDeliveryImage(
                        url: cover!,
                        fit: BoxFit.cover,
                        placeholder: _imagePlaceholder(),
                        errorWidget: _imagePlaceholder(),
                      )
                    : _imagePlaceholder(),
              ),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  scheduleStatus.label,
                  style: TextStyle(
                    color: badgeFg,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (thumbs.length > 1) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: thumbs.length > 5 ? 5 : thumbs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                if (i == 4 && thumbs.length > 5) {
                  return _ThumbTile(
                    label: '+${thumbs.length - 4}',
                    isMore: true,
                  );
                }
                return _ThumbTile(url: thumbs[i]);
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _imagePlaceholder() {
    return ColoredBox(
      color: AppColors.charcoal.withValues(alpha: 0.45),
      child: const Center(
        child: Icon(LucideIcons.hardHat, color: AppColors.gold, size: 32),
      ),
    );
  }
}

class _ThumbTile extends StatelessWidget {
  const _ThumbTile({this.url, this.label, this.isMore = false});

  final String? url;
  final String? label;
  final bool isMore;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 72,
        height: 56,
        child: isMore
            ? ColoredBox(
                color: const Color(0xFF1A1F28),
                child: Center(
                  child: Text(
                    label ?? '',
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )
            : MediaDeliveryImage(
                url: url!,
                fit: BoxFit.cover,
                placeholder: ColoredBox(
                  color: AppColors.charcoal.withValues(alpha: 0.4),
                ),
                errorWidget: ColoredBox(
                  color: AppColors.charcoal.withValues(alpha: 0.4),
                ),
              ),
      ),
    );
  }
}

class _ProjectHeader extends StatelessWidget {
  const _ProjectHeader({required this.project});

  final ConstructionProjectPublic project;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                project.name,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.white,
                ),
              ),
            ),
            if (project.isFeatured)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(LucideIcons.star, color: AppColors.gold, size: 18),
              ),
          ],
        ),
        if (project.locationLabel != null &&
            project.locationLabel!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(LucideIcons.mapPin, size: 14, color: AppColors.gold),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  project.locationLabel!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondaryDark,
                      ),
                ),
              ),
            ],
          ),
        ],
        if (project.description != null &&
            project.description!.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            project.description!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondaryDark,
                  height: 1.45,
                ),
          ),
        ],
        if (project.statusUpdate != null &&
            project.statusUpdate!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            project.statusUpdate!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
        if (project.expectedCompletionLabel != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Icon(
                LucideIcons.calendar,
                size: 14,
                color: AppColors.textSecondaryDark,
              ),
              const SizedBox(width: 6),
              Text.rich(
                TextSpan(
                  text: 'Expected completion: ',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondaryDark,
                      ),
                  children: [
                    TextSpan(
                      text: project.expectedCompletionLabel,
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _LiveUpdatedBadge extends StatelessWidget {
  const _LiveUpdatedBadge({required this.label, this.compact = false});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'LAST UPDATED',
          style: TextStyle(
            color: AppColors.textSecondaryDark,
            fontSize: compact ? 9 : 10,
            letterSpacing: 1,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: AppColors.white,
            fontSize: compact ? 11 : 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _LatestUpdatesRow extends StatelessWidget {
  const _LatestUpdatesRow({
    required this.updates,
    required this.onViewAll,
  });

  final List<ConstructionProgressUpdate> updates;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LATEST UPDATES',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondaryDark,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: updates.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              if (i == updates.length) {
                return _ViewAllButton(onPressed: onViewAll, vertical: true);
              }
              return _UpdateMiniCard(update: updates[i]);
            },
          ),
        ),
      ],
    );
  }
}

class _UpdateMiniCard extends StatelessWidget {
  const _UpdateMiniCard({required this.update});

  final ConstructionProgressUpdate update;

  @override
  Widget build(BuildContext context) {
    final thumb = update.media.isNotEmpty
        ? update.media.first.deliveryUrl
        : null;
    final pct = update.progressPct;
    final when = update.publishedAt ?? update.updateDate;

    return Container(
      width: 200,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F28),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x18FFFFFF)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 52,
              height: 52,
              child: thumb != null
                  ? MediaDeliveryImage(
                      url: thumb,
                      fit: BoxFit.cover,
                      placeholder: _miniPlaceholder(),
                      errorWidget: _miniPlaceholder(),
                    )
                  : _miniPlaceholder(),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  update.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (pct != null) '${pct.round()}% complete',
                    if (when != null)
                      DateFormat.MMMd().format(when.toLocal()),
                  ].join(' · '),
                  style: const TextStyle(
                    color: Color(0xFF8B929E),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniPlaceholder() {
    return ColoredBox(
      color: AppColors.charcoal.withValues(alpha: 0.4),
      child: const Icon(LucideIcons.image, size: 16, color: AppColors.gold),
    );
  }
}

class _ViewAllButton extends StatelessWidget {
  const _ViewAllButton({required this.onPressed, this.vertical = false});

  final VoidCallback onPressed;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    if (vertical) {
      return InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 140,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.arrowRight, color: AppColors.gold, size: 18),
              SizedBox(height: 6),
              Text(
                'View All Updates',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(LucideIcons.arrowRight, size: 16),
      label: const Text('View All Updates'),
      style: TextButton.styleFrom(foregroundColor: AppColors.gold),
    );
  }
}

String constructionProjectDetailPath(ConstructionProjectPublic project) =>
    project.detailPath.isNotEmpty
        ? project.detailPath
        : RoutePaths.constructionProgress(project.slug);
