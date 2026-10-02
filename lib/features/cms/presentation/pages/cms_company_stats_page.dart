import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/cms/presentation/widgets/cms_admin_widgets.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';

/// Admin → Website → Statistics: CRUD for company KPIs.
class CmsCompanyStatsPage extends ConsumerWidget {
  const CmsCompanyStatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(cmsCompanyStatsProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSectionHeader(
            title: 'Company statistics',
            subtitle:
                'Orbit + summary KPIs on Home, About, and Trust. Drag to reorder within placement.',
            action: FilledButton.icon(
              onPressed: () => _openEditor(context, ref, null),
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('Add statistic'),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: statsAsync.when(
              loading: () => const AdminLoadingView(),
              error: (err, _) => AdminErrorView(
                message: '$err',
                onRetry: () => ref.invalidate(cmsCompanyStatsProvider),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return AdminEmptyState(
                    title: 'No statistics yet',
                    message: 'Add your first company KPI for the public hub.',
                    icon: LucideIcons.barChart3,
                    action: FilledButton.icon(
                      onPressed: () => _openEditor(context, ref, null),
                      icon: const Icon(LucideIcons.plus, size: 16),
                      label: const Text('Add statistic'),
                    ),
                  );
                }
                return ReorderableListView.builder(
                  itemCount: items.length,
                  buildDefaultDragHandles: false,
                  onReorder: (oldIndex, newIndex) =>
                      _reorder(ref, items, oldIndex, newIndex),
                  itemBuilder: (context, i) {
                    final stat = items[i];
                    final active = stat.status == 'active';
                    return ReorderableDragStartListener(
                      key: ValueKey(stat.id),
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
                                radius: 22,
                                backgroundColor:
                                    AppColors.gold.withValues(alpha: 0.16),
                                backgroundImage:
                                    (stat.logoUrl?.trim().isNotEmpty ?? false)
                                        ? NetworkImage(stat.logoUrl!.trim())
                                        : null,
                                child: (stat.logoUrl?.trim().isEmpty ?? true)
                                    ? const Icon(
                                        LucideIcons.barChart3,
                                        color: AppColors.gold,
                                        size: 18,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${stat.value}${stat.suffix} · ${stat.label}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        _Chip(
                                          label: stat.isSummary
                                              ? 'Summary'
                                              : 'Orbit',
                                          color: AppColors.gold,
                                        ),
                                        _Chip(
                                          label: active ? 'Active' : 'Hidden',
                                          color: active
                                              ? AppColors.success
                                              : AppColors.slate500,
                                        ),
                                        if (stat.showOnHome)
                                          const _Chip(
                                            label: 'Home',
                                            color: AppColors.gold,
                                          ),
                                        if (stat.showOnAbout)
                                          const _Chip(
                                            label: 'About',
                                            color: AppColors.gold,
                                          ),
                                      ],
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
                                      .setCompanyStatVisibility(
                                        id: stat.id,
                                        status: v ? 'active' : 'draft',
                                      );
                                  _invalidate(ref);
                                },
                              ),
                              IconButton(
                                onPressed: () =>
                                    _openEditor(context, ref, stat),
                                icon: const Icon(LucideIcons.pencil, size: 18),
                              ),
                              IconButton(
                                onPressed: () async {
                                  await ref
                                      .read(cmsServiceProvider)
                                      .deleteCompanyStat(stat.id);
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
    ref.invalidate(cmsCompanyStatsProvider);
    ref.invalidate(publishedCompanyStatsHomeProvider);
    ref.invalidate(publishedCompanyStatsAboutProvider);
  }

  Future<void> _reorder(
    WidgetRef ref,
    List<CmsCompanyStat> items,
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
        await service.setCompanyStatSortOrder(reordered[i].id, nextOrder);
      }
    }
    _invalidate(ref);
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref,
    CmsCompanyStat? stat,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _StatEditDialog(stat: stat),
    );
    _invalidate(ref);
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StatEditDialog extends ConsumerStatefulWidget {
  const _StatEditDialog({this.stat});

  final CmsCompanyStat? stat;

  @override
  ConsumerState<_StatEditDialog> createState() => _StatEditDialogState();
}

class _StatEditDialogState extends ConsumerState<_StatEditDialog> {
  late TextEditingController _value;
  late TextEditingController _label;
  late TextEditingController _suffix;
  late TextEditingController _description;
  late TextEditingController _logoUrl;
  late TextEditingController _sortOrder;
  String _iconName = 'barChart';
  String _placement = 'orbit';
  bool _showOnHome = true;
  bool _showOnAbout = true;
  bool _published = true;
  bool _saving = false;
  bool _uploading = false;
  String? _error;

  static const _icons = <String>[
    'barChart',
    'home',
    'users',
    'calendar',
    'building',
    'trendingUp',
    'hardHat',
    'briefcase',
    'handshake',
    'award',
    'shield',
    'heart',
  ];

  @override
  void initState() {
    super.initState();
    final s = widget.stat;
    _value = TextEditingController(text: '${s?.value ?? 0}');
    _label = TextEditingController(text: s?.label ?? '');
    _suffix = TextEditingController(text: s?.suffix ?? '');
    _description = TextEditingController(text: s?.description ?? '');
    _logoUrl = TextEditingController(text: s?.logoUrl ?? '');
    _sortOrder = TextEditingController(text: '${s?.sortOrder ?? 0}');
    _iconName = s?.iconName ?? 'barChart';
    _placement = s?.placement ?? 'orbit';
    _showOnHome = s?.showOnHome ?? true;
    _showOnAbout = s?.showOnAbout ?? true;
    _published = (s?.status ?? 'active') == 'active';
  }

  @override
  void dispose() {
    _value.dispose();
    _label.dispose();
    _suffix.dispose();
    _description.dispose();
    _logoUrl.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  Future<void> _uploadLogo() async {
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        withData: true,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        throw StateError('Could not read image bytes.');
      }
      final name = file.name.toLowerCase();
      final contentType = name.endsWith('.png')
          ? 'image/png'
          : name.endsWith('.webp')
              ? 'image/webp'
              : 'image/jpeg';
      final url = await ref.read(cmsServiceProvider).uploadCompanyStatLogo(
            bytes: bytes,
            contentType: contentType,
          );
      if (!mounted) return;
      setState(() => _logoUrl.text = url);
    } catch (e) {
      if (mounted) setState(() => _error = userFacingError(e));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    if (_label.text.trim().isEmpty) {
      setState(() => _error = 'Label is required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(cmsServiceProvider).upsertCompanyStat(
            id: widget.stat?.id,
            value: int.tryParse(_value.text.trim()) ?? 0,
            label: _label.text.trim(),
            suffix: _suffix.text.trim(),
            description: _description.text.trim(),
            iconName: _iconName,
            logoUrl: _logoUrl.text.trim().isEmpty ? null : _logoUrl.text.trim(),
            placement: _placement,
            sortOrder: int.tryParse(_sortOrder.text.trim()) ?? 0,
            showOnHome: _showOnHome,
            showOnAbout: _showOnAbout,
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
                  widget.stat == null ? 'Add statistic' : 'Edit statistic',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _value,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Value'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _suffix,
                  decoration: const InputDecoration(
                    labelText: 'Suffix (e.g. +)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _label,
                  decoration: const InputDecoration(labelText: 'Label'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _description,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Description (summary cards)',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _placement,
                  decoration: const InputDecoration(labelText: 'Placement'),
                  items: const [
                    DropdownMenuItem(value: 'orbit', child: Text('Orbit ring')),
                    DropdownMenuItem(
                      value: 'summary',
                      child: Text('Bottom summary'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _placement = v);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue:
                      _icons.contains(_iconName) ? _iconName : 'barChart',
                  decoration: const InputDecoration(labelText: 'Icon'),
                  items: [
                    for (final icon in _icons)
                      DropdownMenuItem(value: icon, child: Text(icon)),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _iconName = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _logoUrl,
                  decoration: const InputDecoration(
                    labelText: 'Logo / image URL (optional)',
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _uploading ? null : _uploadLogo,
                  icon: _uploading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(LucideIcons.upload, size: 16),
                  label: Text(_uploading ? 'Uploading…' : 'Upload image'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _sortOrder,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Sort order'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show on Home'),
                  value: _showOnHome,
                  onChanged: (v) => setState(() => _showOnHome = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show on About'),
                  value: _showOnAbout,
                  onChanged: (v) => setState(() => _showOnAbout = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
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
                      onPressed:
                          _saving ? null : () => Navigator.of(context).pop(),
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
