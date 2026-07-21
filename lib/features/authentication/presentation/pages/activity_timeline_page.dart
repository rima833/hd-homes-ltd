import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/observability_models.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/audit_controller.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Personal activity timeline — searchable user history.
class ActivityTimelinePage extends HookConsumerWidget {
  const ActivityTimelinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapAsync = ref.watch(activityTimelineProvider);
    final filter = ref.watch(observabilityFilterProvider);
    final filterCtrl = ref.read(observabilityFilterProvider.notifier);
    final queryCtrl = useTextEditingController(text: filter.query ?? '');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Timeline'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: () => ref.invalidate(activityTimelineProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              0,
            ),
            child: TextField(
              controller: queryCtrl,
              decoration: InputDecoration(
                hintText: 'Search actions, modules, correlation ID…',
                prefixIcon: const Icon(LucideIcons.search),
                suffixIcon: IconButton(
                  icon: const Icon(LucideIcons.x),
                  onPressed: () {
                    queryCtrl.clear();
                    filterCtrl.setQuery(null);
                  },
                ),
              ),
              onSubmitted: filterCtrl.setQuery,
              onChanged: (v) {
                if (v.trim().isEmpty) filterCtrl.setQuery(null);
              },
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                for (final preset in ActivityDatePreset.values)
                  if (preset != ActivityDatePreset.custom)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: FilterChip(
                        label: Text(preset.label),
                        selected: filter.preset == preset,
                        onSelected: (_) => filterCtrl.setPreset(preset),
                      ),
                    ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All categories'),
                  selected: filter.category == null,
                  onSelected: (_) => filterCtrl.setCategory(null),
                ),
                const SizedBox(width: AppSpacing.sm),
                for (final cat in const [
                  AuditEventCategory.authentication,
                  AuditEventCategory.security,
                  AuditEventCategory.profile,
                  AuditEventCategory.kyc,
                  AuditEventCategory.property,
                  AuditEventCategory.payment,
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: FilterChip(
                      label: Text(cat.label),
                      selected: filter.category == cat,
                      onSelected: (sel) =>
                          filterCtrl.setCategory(sel ? cat : null),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: snapAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Unable to load activity: $e')),
              data: (snap) {
                if (snap == null) {
                  return const Center(child: Text('Sign in to view your activity.'));
                }
                if (snap.items.isEmpty) {
                  return const Center(
                    child: Text('No activity in this range yet.'),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: snap.items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final item = snap.items[index];
                    final isLast = index == snap.items.length - 1;
                    return _TimelineTile(record: item, isLast: isLast);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({required this.record, required this.isLast});

  final AuditRecord record;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm').format(record.createdAt.toLocal());
    final date = DateFormat('MMM d').format(record.createdAt.toLocal());
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 56,
            child: Column(
              children: [
                Text(time, style: Theme.of(context).textTheme.labelMedium),
                Text(date, style: Theme.of(context).textTheme.labelSmall),
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: isLast
                        ? Colors.transparent
                        : record.severity.color.withValues(alpha: 0.35),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: record.severity.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              record.severity.icon,
              size: 18,
              color: record.severity.color,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.timelineTitle,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${record.category.label} · ${record.module}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (record.reason != null) ...[
                      const SizedBox(height: 4),
                      Text(record.reason!),
                    ],
                    if (record.oldValues != null || record.newValues != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Change recorded',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.gold,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
