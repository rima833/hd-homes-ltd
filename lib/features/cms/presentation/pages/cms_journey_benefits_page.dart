import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/about/presentation/widgets/about_icons.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/cms/presentation/widgets/cms_admin_widgets.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Admin → Website → Journey Benefits: CRUD for the feature strip cards.
class CmsJourneyBenefitsPage extends ConsumerWidget {
  const CmsJourneyBenefitsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(cmsJourneyBenefitsProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSectionHeader(
            title: 'Journey benefits',
            subtitle:
                'Four feature cards under Our client journey. Drag to reorder.',
            action: FilledButton.icon(
              onPressed: () => _openEditor(context, ref, null),
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('Add benefit'),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: async.when(
              loading: () => const AdminLoadingView(),
              error: (err, _) => AdminErrorView(
                message: '$err',
                onRetry: () => ref.invalidate(cmsJourneyBenefitsProvider),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return AdminEmptyState(
                    title: 'No benefits yet',
                    message: 'Add the first journey benefit card.',
                    icon: LucideIcons.sparkles,
                    action: FilledButton.icon(
                      onPressed: () => _openEditor(context, ref, null),
                      icon: const Icon(LucideIcons.plus, size: 16),
                      label: const Text('Add benefit'),
                    ),
                  );
                }
                return ReorderableListView.builder(
                  itemCount: items.length,
                  buildDefaultDragHandles: false,
                  onReorder: (o, n) => _reorder(ref, items, o, n),
                  itemBuilder: (context, i) {
                    final item = items[i];
                    final active = item.status == 'active';
                    return ReorderableDragStartListener(
                      key: ValueKey(item.id),
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
                              Icon(
                                AboutIcons.resolve(item.iconName),
                                color: AppColors.gold,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    Text(
                                      item.description,
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
                                      .setJourneyBenefitStatus(
                                        id: item.id,
                                        status: v ? 'active' : 'draft',
                                      );
                                  _invalidate(ref);
                                },
                              ),
                              IconButton(
                                onPressed: () =>
                                    _openEditor(context, ref, item),
                                icon: const Icon(LucideIcons.pencil, size: 18),
                              ),
                              IconButton(
                                onPressed: () async {
                                  await ref
                                      .read(cmsServiceProvider)
                                      .deleteJourneyBenefit(item.id);
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
    ref.invalidate(cmsJourneyBenefitsProvider);
    ref.invalidate(publishedJourneyBenefitsProvider);
  }

  Future<void> _reorder(
    WidgetRef ref,
    List<CmsJourneyBenefit> items,
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
        await service.setJourneyBenefitSortOrder(reordered[i].id, nextOrder);
      }
    }
    _invalidate(ref);
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref,
    CmsJourneyBenefit? item,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _BenefitEditDialog(item: item),
    );
    _invalidate(ref);
  }
}

class _BenefitEditDialog extends ConsumerStatefulWidget {
  const _BenefitEditDialog({this.item});

  final CmsJourneyBenefit? item;

  @override
  ConsumerState<_BenefitEditDialog> createState() => _BenefitEditDialogState();
}

class _BenefitEditDialogState extends ConsumerState<_BenefitEditDialog> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _icon;
  late bool _active;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final i = widget.item;
    _title = TextEditingController(text: i?.title ?? '');
    _description = TextEditingController(text: i?.description ?? '');
    _icon = TextEditingController(text: i?.iconName ?? 'shield');
    _active = (i?.status ?? 'active') == 'active';
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _icon.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item == null ? 'Add benefit' : 'Edit benefit'),
      content: SizedBox(
        width: 440,
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
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _icon,
              decoration: const InputDecoration(
                labelText: 'Icon name',
                hintText: 'shield, award, target, heart…',
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
      final existing = widget.item;
      await ref.read(cmsServiceProvider).upsertJourneyBenefit(
            id: existing?.id,
            title: title,
            description: _description.text.trim(),
            iconName: _icon.text.trim().isEmpty ? 'shield' : _icon.text.trim(),
            sortOrder: existing?.sortOrder ?? 999,
            status: _active ? 'active' : 'draft',
          );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
