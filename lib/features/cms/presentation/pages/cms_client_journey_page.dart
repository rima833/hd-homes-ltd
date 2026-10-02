import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/about/presentation/widgets/about_icons.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/cms/presentation/widgets/cms_admin_widgets.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Admin → Website → Client Journey: CRUD for serpentine journey steps.
class CmsClientJourneyPage extends ConsumerWidget {
  const CmsClientJourneyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(cmsClientJourneyStepsProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSectionHeader(
            title: 'Client journey',
            subtitle:
                'Steps shown on About → Our client journey. Drag to reorder.',
            action: FilledButton.icon(
              onPressed: () => _openEditor(context, ref, null),
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('Add step'),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: async.when(
              loading: () => const AdminLoadingView(),
              error: (err, _) => AdminErrorView(
                message: '$err',
                onRetry: () => ref.invalidate(cmsClientJourneyStepsProvider),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return AdminEmptyState(
                    title: 'No journey steps yet',
                    message: 'Add the first step in the client journey.',
                    icon: LucideIcons.gitBranch,
                    action: FilledButton.icon(
                      onPressed: () => _openEditor(context, ref, null),
                      icon: const Icon(LucideIcons.plus, size: 16),
                      label: const Text('Add step'),
                    ),
                  );
                }
                return ReorderableListView.builder(
                  itemCount: items.length,
                  buildDefaultDragHandles: false,
                  onReorder: (o, n) => _reorder(ref, items, o, n),
                  itemBuilder: (context, i) {
                    final step = items[i];
                    final active = step.status == 'active';
                    return ReorderableDragStartListener(
                      key: ValueKey(step.id),
                      index: i,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AdminCard(
                          child: Row(
                            children: [
                              const Icon(
                                LucideIcons.gripVertical,
                                size: 18,
                                color: AppColors.slate500,
                              ),
                              const SizedBox(width: 10),
                              CircleAvatar(
                                backgroundColor:
                                    AppColors.gold.withValues(alpha: 0.16),
                                child: Icon(
                                  AboutIcons.resolve(step.iconName),
                                  color: AppColors.gold,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${(i + 1).toString().padLeft(2, '0')}  ${step.title}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      [
                                        step.timeline,
                                        step.description,
                                      ].where((s) => s.trim().isNotEmpty).join(
                                            ' · ',
                                          ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: AppColors.slate500),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: active,
                                activeTrackColor: AppColors.gold,
                                onChanged: (v) async {
                                  await ref
                                      .read(cmsServiceProvider)
                                      .setClientJourneyStepStatus(
                                        id: step.id,
                                        status: v ? 'active' : 'draft',
                                      );
                                  _invalidate(ref);
                                },
                              ),
                              IconButton(
                                onPressed: () =>
                                    _openEditor(context, ref, step),
                                icon: const Icon(LucideIcons.pencil, size: 18),
                              ),
                              IconButton(
                                onPressed: () async {
                                  await ref
                                      .read(cmsServiceProvider)
                                      .deleteClientJourneyStep(step.id);
                                  _invalidate(ref);
                                },
                                icon: const Icon(
                                  LucideIcons.trash2,
                                  size: 18,
                                  color: AppColors.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _invalidate(WidgetRef ref) {
    ref.invalidate(cmsClientJourneyStepsProvider);
    ref.invalidate(publishedClientJourneyStepsProvider);
  }

  Future<void> _reorder(
    WidgetRef ref,
    List<CmsClientJourneyStep> items,
    int oldIndex,
    int newIndex,
  ) async {
    if (newIndex > oldIndex) newIndex -= 1;
    if (oldIndex == newIndex) return;
    final reordered = [...items];
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    final service = ref.read(cmsServiceProvider);
    for (var i = 0; i < reordered.length; i++) {
      final nextOrder = (i + 1) * 10;
      if (reordered[i].sortOrder != nextOrder) {
        await service.setClientJourneyStepSortOrder(
          reordered[i].id,
          nextOrder,
        );
      }
    }
    _invalidate(ref);
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref,
    CmsClientJourneyStep? step,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _StepEditDialog(step: step),
    );
    _invalidate(ref);
  }
}

class _StepEditDialog extends ConsumerStatefulWidget {
  const _StepEditDialog({this.step});

  final CmsClientJourneyStep? step;

  @override
  ConsumerState<_StepEditDialog> createState() => _StepEditDialogState();
}

class _StepEditDialogState extends ConsumerState<_StepEditDialog> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _timeline;
  late final TextEditingController _icon;
  late bool _active;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.step;
    _title = TextEditingController(text: s?.title ?? '');
    _description = TextEditingController(text: s?.description ?? '');
    _timeline = TextEditingController(text: s?.timeline ?? '');
    _icon = TextEditingController(text: s?.iconName ?? 'message');
    _active = (s?.status ?? 'active') == 'active';
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _timeline.dispose();
    _icon.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.step == null ? 'Add journey step' : 'Edit journey step'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _description,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _timeline,
                decoration: const InputDecoration(
                  labelText: 'Status / time label',
                  hintText: 'e.g. Day 1, Ongoing',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _icon,
                decoration: const InputDecoration(
                  labelText: 'Icon name',
                  hintText: 'message, users, search, map_pin…',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enabled (active)'),
                value: _active,
                activeTrackColor: AppColors.gold,
                onChanged: (v) => setState(() => _active = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    setState(() => _saving = true);
    try {
      final existing = widget.step;
      await ref.read(cmsServiceProvider).upsertClientJourneyStep(
            id: existing?.id,
            title: title,
            description: _description.text.trim(),
            timeline: _timeline.text.trim(),
            iconName: _icon.text.trim().isEmpty ? 'circle' : _icon.text.trim(),
            sortOrder: existing?.sortOrder ?? 999,
            status: _active ? 'active' : 'draft',
          );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
