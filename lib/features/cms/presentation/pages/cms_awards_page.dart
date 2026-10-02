import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/cms/presentation/widgets/cms_admin_widgets.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';

/// Admin → Website → Awards: CRUD for awards & certifications.
class CmsAwardsPage extends ConsumerWidget {
  const CmsAwardsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final awardsAsync = ref.watch(cmsAwardsProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSectionHeader(
            title: 'Awards & certifications',
            subtitle:
                'Recognition shown on Home, About, and Trust. Reorder with the arrows.',
            action: FilledButton.icon(
              onPressed: () => _openEditor(context, ref, null),
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('Add award'),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: awardsAsync.when(
              loading: () => const AdminLoadingView(),
              error: (err, _) => AdminErrorView(
                message: '$err',
                onRetry: () => ref.invalidate(cmsAwardsProvider),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return AdminEmptyState(
                    title: 'No awards yet',
                    message:
                        'Add your first award or certification for social proof.',
                    icon: LucideIcons.award,
                    action: FilledButton.icon(
                      onPressed: () => _openEditor(context, ref, null),
                      icon: const Icon(LucideIcons.plus, size: 16),
                      label: const Text('Add award'),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final award = items[i];
                    return AdminCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor:
                                AppColors.gold.withValues(alpha: 0.18),
                            child: Icon(
                              _iconFor(award.iconName),
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
                                  award.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${award.issuer} · ${award.year}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: AppColors.slate500),
                                ),
                                if (award.description.trim().isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    award.description,
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              Switch(
                                value: award.isFeatured,
                                activeTrackColor: AppColors.gold,
                                onChanged: (v) async {
                                  await ref
                                      .read(cmsServiceProvider)
                                      .setAwardFeatured(award.id, v);
                                  ref.invalidate(cmsAwardsProvider);
                                  ref.invalidate(publishedAwardsProvider);
                                },
                              ),
                              const Text(
                                'Featured',
                                style: TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                          IconButton(
                            tooltip: 'Move up',
                            onPressed: i == 0
                                ? null
                                : () => _swapOrder(
                                      ref,
                                      items,
                                      i,
                                      i - 1,
                                    ),
                            icon: const Icon(LucideIcons.arrowUp, size: 18),
                          ),
                          IconButton(
                            tooltip: 'Move down',
                            onPressed: i >= items.length - 1
                                ? null
                                : () => _swapOrder(
                                      ref,
                                      items,
                                      i,
                                      i + 1,
                                    ),
                            icon: const Icon(LucideIcons.arrowDown, size: 18),
                          ),
                          IconButton(
                            onPressed: () => _openEditor(context, ref, award),
                            icon: const Icon(LucideIcons.pencil, size: 18),
                          ),
                          IconButton(
                            onPressed: () async {
                              await ref
                                  .read(cmsServiceProvider)
                                  .deleteAward(award.id);
                              ref.invalidate(cmsAwardsProvider);
                              ref.invalidate(publishedAwardsProvider);
                            },
                            icon: const Icon(
                              LucideIcons.trash2,
                              size: 18,
                              color: AppColors.error,
                            ),
                          ),
                        ],
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

  Future<void> _swapOrder(
    WidgetRef ref,
    List<CmsAward> items,
    int a,
    int b,
  ) async {
    final first = items[a];
    final second = items[b];
    final service = ref.read(cmsServiceProvider);
    await service.setAwardSortOrder(first.id, second.sortOrder);
    await service.setAwardSortOrder(second.id, first.sortOrder);
    ref.invalidate(cmsAwardsProvider);
    ref.invalidate(publishedAwardsProvider);
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref,
    CmsAward? award,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _AwardEditDialog(award: award),
    );
    ref.invalidate(cmsAwardsProvider);
    ref.invalidate(publishedAwardsProvider);
  }
}

IconData _iconFor(String name) {
  switch (name.toLowerCase()) {
    case 'trophy':
      return LucideIcons.trophy;
    case 'star':
      return LucideIcons.star;
    case 'badge':
    case 'shield':
      return LucideIcons.shieldCheck;
    case 'medal':
      return LucideIcons.medal;
    default:
      return LucideIcons.award;
  }
}

class _AwardEditDialog extends ConsumerStatefulWidget {
  const _AwardEditDialog({this.award});

  final CmsAward? award;

  @override
  ConsumerState<_AwardEditDialog> createState() => _AwardEditDialogState();
}

class _AwardEditDialogState extends ConsumerState<_AwardEditDialog> {
  late TextEditingController _title;
  late TextEditingController _issuer;
  late TextEditingController _year;
  late TextEditingController _description;
  late TextEditingController _verificationUrl;
  late TextEditingController _sortOrder;
  String _iconName = 'award';
  bool _featured = false;
  bool _published = true;
  bool _saving = false;
  String? _error;

  static const _icons = <String>['award', 'trophy', 'star', 'medal', 'badge'];

  @override
  void initState() {
    super.initState();
    final a = widget.award;
    _title = TextEditingController(text: a?.title ?? '');
    _issuer = TextEditingController(text: a?.issuer ?? '');
    _year = TextEditingController(text: a?.year ?? '');
    _description = TextEditingController(text: a?.description ?? '');
    _verificationUrl = TextEditingController(text: a?.verificationUrl ?? '');
    _sortOrder = TextEditingController(text: '${a?.sortOrder ?? 0}');
    _iconName = a?.iconName ?? 'award';
    _featured = a?.isFeatured ?? false;
    _published = (a?.status ?? 'active') == 'active';
  }

  @override
  void dispose() {
    _title.dispose();
    _issuer.dispose();
    _year.dispose();
    _description.dispose();
    _verificationUrl.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Title is required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(cmsServiceProvider).upsertAward(
            id: widget.award?.id,
            title: _title.text.trim(),
            issuer: _issuer.text.trim(),
            year: _year.text.trim(),
            description: _description.text.trim(),
            verificationUrl: _verificationUrl.text.trim().isEmpty
                ? null
                : _verificationUrl.text.trim(),
            iconName: _iconName,
            sortOrder: int.tryParse(_sortOrder.text.trim()) ?? 0,
            isFeatured: _featured,
            status: _published ? 'active' : 'draft',
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = userFacingError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.dialogBorder),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.award == null ? 'Add award' : 'Edit award',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _issuer,
                  decoration: const InputDecoration(
                    labelText: 'Issuer / organization',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _year,
                  decoration: const InputDecoration(labelText: 'Year'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _description,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _verificationUrl,
                  decoration: const InputDecoration(
                    labelText: 'Verification URL (optional)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _sortOrder,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Sort order'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _icons.contains(_iconName) ? _iconName : 'award',
                  decoration: const InputDecoration(labelText: 'Icon'),
                  items: [
                    for (final icon in _icons)
                      DropdownMenuItem(value: icon, child: Text(icon)),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _iconName = v);
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Featured'),
                  value: _featured,
                  onChanged: (v) => setState(() => _featured = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Published'),
                  value: _published,
                  onChanged: (v) => setState(() => _published = v),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: AppColors.error)),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Text(_saving ? 'Saving…' : 'Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
