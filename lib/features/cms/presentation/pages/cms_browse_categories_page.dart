import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/cms/presentation/widgets/cms_admin_widgets.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';

/// Admin → Website → Browse Categories
class CmsBrowseCategoriesPage extends ConsumerWidget {
  const CmsBrowseCategoriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(cmsBrowseCategoriesProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSectionHeader(
            title: 'Browse by category',
            subtitle:
                'Cards on Home and /properties. Listing counts update live from published inventory.',
            action: FilledButton.icon(
              onPressed: () => _openEditor(context, ref, null),
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('Add category'),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: async.when(
              loading: () => const AdminLoadingView(),
              error: (e, _) => AdminErrorView(
                message: '$e',
                onRetry: () => ref.invalidate(cmsBrowseCategoriesProvider),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return AdminEmptyState(
                    title: 'No categories yet',
                    message: 'Add Luxury, Family, Land, and other browse cards.',
                    icon: LucideIcons.layoutGrid,
                    action: FilledButton.icon(
                      onPressed: () => _openEditor(context, ref, null),
                      icon: const Icon(LucideIcons.plus, size: 16),
                      label: const Text('Add category'),
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
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            item.label,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                        ),
                                        if (item.isFeatured) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.gold
                                                  .withValues(alpha: 0.18),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: const Text(
                                              'Featured',
                                              style: TextStyle(
                                                color: AppColors.gold,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'key: ${item.filterKey} · icon: ${item.iconName}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: AppColors.slate500),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: (active
                                          ? AppColors.success
                                          : AppColors.slate500)
                                      .withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  active ? 'Published' : 'Draft',
                                  style: TextStyle(
                                    color: active
                                        ? AppColors.success
                                        : AppColors.slate500,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Edit',
                                onPressed: () =>
                                    _openEditor(context, ref, item),
                                icon: const Icon(LucideIcons.pencil, size: 16),
                              ),
                              IconButton(
                                tooltip: 'Delete',
                                onPressed: () => _delete(context, ref, item),
                                icon: const Icon(
                                  LucideIcons.trash2,
                                  size: 16,
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

  Future<void> _reorder(
    WidgetRef ref,
    List<CmsBrowseCategory> items,
    int oldIndex,
    int newIndex,
  ) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final next = [...items];
    final item = next.removeAt(oldIndex);
    next.insert(newIndex, item);
    final service = ref.read(cmsServiceProvider);
    for (var i = 0; i < next.length; i++) {
      await service.setBrowseCategorySortOrder(next[i].id, (i + 1) * 10);
    }
    ref.invalidate(cmsBrowseCategoriesProvider);
    ref.invalidate(publishedBrowseCategoriesProvider);
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    CmsBrowseCategory item,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete category?'),
        content: Text('Remove “${item.label}” from Browse by Category.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(cmsServiceProvider).deleteBrowseCategory(item.id);
    ref.invalidate(cmsBrowseCategoriesProvider);
    ref.invalidate(publishedBrowseCategoriesProvider);
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref,
    CmsBrowseCategory? item,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _BrowseCategoryEditor(item: item),
    );
    ref.invalidate(cmsBrowseCategoriesProvider);
    ref.invalidate(publishedBrowseCategoriesProvider);
  }
}

class _BrowseCategoryEditor extends ConsumerStatefulWidget {
  const _BrowseCategoryEditor({this.item});

  final CmsBrowseCategory? item;

  @override
  ConsumerState<_BrowseCategoryEditor> createState() =>
      _BrowseCategoryEditorState();
}

class _BrowseCategoryEditorState extends ConsumerState<_BrowseCategoryEditor> {
  late final TextEditingController _label;
  late final TextEditingController _key;
  late final TextEditingController _description;
  late final TextEditingController _icon;
  late final TextEditingController _image;
  late bool _featured;
  late bool _published;
  bool _saving = false;
  bool _uploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final i = widget.item;
    _label = TextEditingController(text: i?.label ?? '');
    _key = TextEditingController(text: i?.filterKey ?? '');
    _description = TextEditingController(text: i?.description ?? '');
    _icon = TextEditingController(text: i?.iconName ?? 'home');
    _image = TextEditingController(text: i?.imageUrl ?? '');
    _featured = i?.isFeatured ?? false;
    _published = (i?.status ?? 'active') == 'active';
  }

  @override
  void dispose() {
    _label.dispose();
    _key.dispose();
    _description.dispose();
    _icon.dispose();
    _image.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        withData: true,
      );
      final file = result?.files.single;
      final bytes = file?.bytes;
      if (bytes == null || bytes.isEmpty) {
        throw StateError('Could not read image bytes.');
      }
      final url = await ref.read(cmsServiceProvider).uploadBrowseCategoryImage(
            bytes: bytes,
            contentType: file?.extension == 'png' ? 'image/png' : 'image/jpeg',
          );
      _image.text = url;
    } catch (e) {
      setState(() => _error = userFacingError(e));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    final label = _label.text.trim();
    final key = _key.text.trim().toLowerCase().replaceAll(' ', '_');
    if (label.isEmpty || key.isEmpty) {
      setState(() => _error = 'Label and filter key are required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(cmsServiceProvider).upsertBrowseCategory(
            id: widget.item?.id,
            label: label,
            filterKey: key,
            description: _description.text.trim(),
            iconName: _icon.text.trim().isEmpty ? 'home' : _icon.text.trim(),
            imageUrl:
                _image.text.trim().isEmpty ? null : _image.text.trim(),
            isFeatured: _featured,
            sortOrder: widget.item?.sortOrder ?? 0,
            status: _published ? 'active' : 'draft',
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = userFacingError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item == null ? 'Add category' : 'Edit category'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _label,
                decoration: const InputDecoration(
                  labelText: 'Label',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _key,
                decoration: const InputDecoration(
                  labelText: 'Filter key (e.g. luxury, family, land)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _description,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _icon,
                decoration: const InputDecoration(
                  labelText: 'Icon name (crown, home, users, building…)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _image,
                decoration: const InputDecoration(
                  labelText: 'Image URL',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _uploading ? null : _pickImage,
                icon: _uploading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(LucideIcons.upload, size: 16),
                label: Text(_uploading ? 'Uploading…' : 'Upload image'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Featured card'),
                subtitle: const Text('Large left card in the mockup layout'),
                value: _featured,
                onChanged: (v) => setState(() => _featured = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Published'),
                value: _published,
                onChanged: (v) => setState(() => _published = v),
              ),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: AppColors.error)),
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
}
