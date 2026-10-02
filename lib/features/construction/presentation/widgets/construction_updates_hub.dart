import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/core/widgets/feedback/loading_skeleton.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/construction/domain/entities/construction_platform_models.dart';
import 'package:hdhomesproject/features/construction/presentation/providers/construction_platform_providers.dart';
import 'package:hdhomesproject/features/construction/presentation/widgets/construction_project_card.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

enum _SortMode { latest, progress, name }

/// Full public construction hub — matches the premium dark mockup.
class ConstructionUpdatesHub extends HookConsumerWidget {
  const ConstructionUpdatesHub({
    super.key,
    this.showViewAllCta = false,
    this.maxProjects,
  });

  final bool showViewAllCta;
  final int? maxProjects;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(constructionPlatformRealtimeProvider);
    ref.watch(websiteConstructionUpdatesRealtimeProvider);

    final configured = ref.watch(supabaseConfiguredProvider);
    final async = ref.watch(publicConstructionProjectsProvider);
    final scheduleFilter = useState<ConstructionScheduleStatus?>(null);
    final sortMode = useState(_SortMode.latest);
    final gridView = useState(false);

    return SectionWrapper(
      backgroundColor: AppColors.deepBlack,
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 780;
              final title = const AnimatedSectionTitle(
                overline: 'ON-SITE PROGRESS',
                title: 'Construction Updates',
                subtitle:
                    'Follow HD Homes developments from foundation to completion — live site photos, milestones, and progress.',
                alignment: TextAlign.left,
              );
              final controls = _HubControls(
                scheduleFilter: scheduleFilter.value,
                sortMode: sortMode.value,
                gridView: gridView.value,
                onSchedule: (v) => scheduleFilter.value = v,
                onSort: (v) => sortMode.value = v,
                onGrid: (v) => gridView.value = v,
              );
              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    title,
                    const SizedBox(height: AppSpacing.lg),
                    controls,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: title),
                  const SizedBox(width: AppSpacing.lg),
                  controls,
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.xxl),
          async.when(
            loading: () => const LoadingSkeleton(height: 320),
            error: (_, __) => _EmptyState(configured: configured),
            data: (projects) {
              if (projects.isEmpty) {
                return _EmptyState(configured: configured);
              }

              var filtered = [...projects];
              if (scheduleFilter.value != null) {
                filtered = filtered
                    .where((p) => p.scheduleStatus == scheduleFilter.value)
                    .toList();
              }
              switch (sortMode.value) {
                case _SortMode.latest:
                  filtered.sort((a, b) {
                    final ad = a.updatedAt ?? DateTime(1970);
                    final bd = b.updatedAt ?? DateTime(1970);
                    return bd.compareTo(ad);
                  });
                case _SortMode.progress:
                  filtered.sort(
                    (a, b) => b.progressPct.compareTo(a.progressPct),
                  );
                case _SortMode.name:
                  filtered.sort((a, b) => a.name.compareTo(b.name));
              }

              final visible = maxProjects == null
                  ? filtered
                  : filtered.take(maxProjects!).toList();

              if (visible.isEmpty) {
                return Column(
                  children: [
                    _EmptyState(
                      configured: configured,
                      filtered: scheduleFilter.value != null,
                      onClearFilter: () => scheduleFilter.value = null,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _StatsFooter(projects: projects),
                  ],
                );
              }

              return Column(
                children: [
                  if (gridView.value)
                    _GridList(projects: visible)
                  else
                    _StackList(projects: visible),
                  const SizedBox(height: AppSpacing.xl),
                  _StatsFooter(projects: projects),
                  if (showViewAllCta) ...[
                    const SizedBox(height: AppSpacing.xl),
                    TextButton.icon(
                      onPressed: () => context.go(RoutePaths.construction),
                      icon: const Icon(LucideIcons.arrowRight, size: 16),
                      label: const Text('View all construction updates'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.gold,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HubControls extends StatelessWidget {
  const _HubControls({
    required this.scheduleFilter,
    required this.sortMode,
    required this.gridView,
    required this.onSchedule,
    required this.onSort,
    required this.onGrid,
  });

  final ConstructionScheduleStatus? scheduleFilter;
  final _SortMode sortMode;
  final bool gridView;
  final ValueChanged<ConstructionScheduleStatus?> onSchedule;
  final ValueChanged<_SortMode> onSort;
  final ValueChanged<bool> onGrid;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _DeskDropdown<ConstructionScheduleStatus?>(
          value: scheduleFilter,
          hint: 'All Projects',
          items: [
            const DropdownMenuItem(value: null, child: Text('All Projects')),
            for (final s in ConstructionScheduleStatus.values)
              DropdownMenuItem(value: s, child: Text(s.label)),
          ],
          onChanged: onSchedule,
        ),
        _DeskDropdown<_SortMode>(
          value: sortMode,
          hint: 'Sort',
          items: const [
            DropdownMenuItem(
              value: _SortMode.latest,
              child: Text('Sort: Latest Update'),
            ),
            DropdownMenuItem(
              value: _SortMode.progress,
              child: Text('Sort: Progress'),
            ),
            DropdownMenuItem(
              value: _SortMode.name,
              child: Text('Sort: Name'),
            ),
          ],
          onChanged: (v) {
            if (v != null) onSort(v);
          },
        ),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF151821),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0x18FFFFFF)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ViewToggle(
                icon: LucideIcons.layoutList,
                selected: !gridView,
                onTap: () => onGrid(false),
              ),
              _ViewToggle(
                icon: LucideIcons.layoutGrid,
                selected: gridView,
                onTap: () => onGrid(true),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DeskDropdown<T> extends StatelessWidget {
  const _DeskDropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final String hint;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF151821),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x18FFFFFF)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(hint, style: const TextStyle(color: Color(0xFF8B929E))),
          dropdownColor: const Color(0xFF1A1F28),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          icon: const Icon(LucideIcons.chevronDown,
              size: 16, color: Color(0xFF8B929E)),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.gold.withValues(alpha: 0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 16,
          color: selected ? AppColors.gold : const Color(0xFF8B929E),
        ),
      ),
    );
  }
}

class _StackList extends StatelessWidget {
  const _StackList({required this.projects});

  final List<ConstructionProjectPublic> projects;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < projects.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.base),
          ConstructionProjectCard(
            project: projects[i],
            onView: () =>
                context.go(constructionProjectDetailPath(projects[i])),
          ),
        ],
      ],
    );
  }
}

class _GridList extends StatelessWidget {
  const _GridList({required this.projects});

  final List<ConstructionProjectPublic> projects;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 1100
            ? 2
            : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: projects.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: AppSpacing.base,
            crossAxisSpacing: AppSpacing.base,
            childAspectRatio: cols == 1 ? 0.92 : 1.15,
          ),
          itemBuilder: (context, i) => ConstructionProjectCard(
            project: projects[i],
            onView: () =>
                context.go(constructionProjectDetailPath(projects[i])),
          ),
        );
      },
    );
  }
}

class _StatsFooter extends StatelessWidget {
  const _StatsFooter({required this.projects});

  final List<ConstructionProjectPublic> projects;

  @override
  Widget build(BuildContext context) {
    final active = projects.where((p) => p.progressPct < 100).length;
    final onSchedule = projects
        .where((p) => p.scheduleStatus == ConstructionScheduleStatus.onTrack)
        .length;
    final ahead = projects
        .where((p) => p.scheduleStatus == ConstructionScheduleStatus.ahead)
        .length;
    final atRisk = projects
        .where((p) =>
            p.scheduleStatus == ConstructionScheduleStatus.atRisk ||
            p.scheduleStatus == ConstructionScheduleStatus.delayed)
        .length;
    final completed = projects.where((p) => p.progressPct >= 100).length;

    final items = [
      (LucideIcons.hardHat, 'Active Projects', '$active', AppColors.gold),
      (LucideIcons.checkCircle, 'On Schedule', '$onSchedule', AppColors.success),
      (LucideIcons.trendingUp, 'Ahead of Schedule', '$ahead', AppColors.success),
      (LucideIcons.alertTriangle, 'At Risk', '$atRisk', AppColors.warning),
      (LucideIcons.badgeCheck, 'Completed', '$completed', AppColors.info),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFF151821),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x18FFFFFF)),
      ),
      child: Wrap(
        spacing: 28,
        runSpacing: 16,
        alignment: WrapAlignment.spaceEvenly,
        children: [
          for (final item in items)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item.$1, size: 18, color: item.$4),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.$3,
                      style: TextStyle(
                        color: item.$4,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      item.$2,
                      style: const TextStyle(
                        color: Color(0xFF8B929E),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.configured,
    this.filtered = false,
    this.onClearFilter,
  });

  final bool configured;
  final bool filtered;
  final VoidCallback? onClearFilter;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Column(
        children: [
          Icon(
            configured
                ? (filtered ? LucideIcons.filterX : LucideIcons.hardHat)
                : LucideIcons.hardHat,
            color: AppColors.gold,
            size: 36,
          ),
          const SizedBox(height: 14),
          Text(
            !configured
                ? "Can't load updates right now"
                : filtered
                    ? 'No projects match this filter'
                    : 'No published construction updates yet',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            !configured
                ? "Updates will refresh when you're back online."
                : filtered
                    ? 'Try another schedule status or clear the filter to see all projects.'
                    : 'Publish a site progress update from CPMS or Website CMS to populate this feed.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF8B929E)),
          ),
          if (filtered && onClearFilter != null) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: onClearFilter,
              child: const Text('Clear filter'),
            ),
          ],
        ],
      ),
    );
  }
}
