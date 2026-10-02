import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/layout/public/published_chrome.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/cms/presentation/widgets/cms_admin_widgets.dart';
import 'package:hdhomesproject/features/cms/presentation/widgets/cms_link_list_editor.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Admin → Website → Menus: navigation menus editor.
///
/// There is no dedicated public "menus" table with a rich editor UX, so
/// menus are stored as `cms_sections` rows with `section_type = 'menu'` —
/// each row is one named menu (e.g. `header`) and its `content.items`
/// array holds the nav links (`{label, url}`).
class CmsMenusPage extends ConsumerWidget {
  const CmsMenusPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menusAsync = ref.watch(cmsMenuSectionsProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSectionHeader(
            title: 'Navigation menus',
            subtitle:
                'The Primary menu is the public header, in this order. Changes appear on the site immediately.',
            action: FilledButton.icon(
              onPressed: () => _openEditor(context, ref, null),
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('Add menu'),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: menusAsync.when(
              loading: () => const AdminLoadingView(),
              error: (err, _) => AdminErrorView(
                message: '$err',
                onRetry: () => ref.invalidate(cmsMenuSectionsProvider),
              ),
              data: (menus) {
                if (menus.isEmpty) {
                  return AdminEmptyState(
                    title: 'No navigation menus yet',
                    message:
                        'Create your first menu — e.g. "header" with Home, Properties, Contact.',
                    icon: LucideIcons.menu,
                    action: FilledButton.icon(
                      onPressed: () => _openEditor(context, ref, null),
                      icon: const Icon(LucideIcons.plus, size: 16),
                      label: const Text('Add menu'),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: menus.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final menu = menus[i];
                    final items = (menu.content['items'] as List?) ?? const [];
                    return AdminCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            LucideIcons.menu,
                            size: 20,
                            color: AppColors.gold,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  menu.displayTitle,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: items.map((item) {
                                    final map = Map<String, dynamic>.from(
                                      item as Map,
                                    );
                                    return AdminStatusPill(
                                      label: map['label']?.toString() ?? '—',
                                      color: AppColors.slate500,
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Edit menu',
                            onPressed: () => _openEditor(context, ref, menu),
                            icon: const Icon(LucideIcons.pencil, size: 18),
                          ),
                          IconButton(
                            tooltip: 'Delete menu',
                            onPressed: () => _deleteMenu(context, ref, menu),
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

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref,
    CmsSectionRecord? menu,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _MenuEditDialog(menu: menu),
    );
    ref.invalidate(cmsMenuSectionsProvider);
    ref.invalidate(publishedMenuSectionsProvider);
  }

  Future<void> _deleteMenu(
    BuildContext context,
    WidgetRef ref,
    CmsSectionRecord menu,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete menu?'),
        content: Text('Remove ${menu.displayTitle} from the public header.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(cmsServiceProvider).deleteSection(menu.id);
    ref.invalidate(cmsMenuSectionsProvider);
    ref.invalidate(publishedMenuSectionsProvider);
  }
}

class _MenuEditDialog extends ConsumerStatefulWidget {
  const _MenuEditDialog({this.menu});

  final CmsSectionRecord? menu;

  @override
  ConsumerState<_MenuEditDialog> createState() => _MenuEditDialogState();
}

class _MenuEditDialogState extends ConsumerState<_MenuEditDialog> {
  late TextEditingController _title;
  final _linksKey = GlobalKey<CmsLinkListEditorState>();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.menu?.title ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  String _sectionKey(String title) {
    final existing = widget.menu?.sectionKey.trim() ?? '';
    if (existing.isNotEmpty) return existing;
    final slug = title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    if (slug.isNotEmpty) return slug;
    return 'menu_${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Give the menu a name.');
      return;
    }
    List<Map<String, String>> items;
    try {
      items = _linksKey.currentState!.validatedLinks();
    } on StateError catch (error) {
      setState(() => _error = error.message);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(cmsServiceProvider)
          .upsertMenuSection(
            id: widget.menu?.id,
            sectionKey: _sectionKey(title),
            title: title,
            content: {'items': items},
            sortOrder: widget.menu?.sortOrder ?? 0,
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
    final initial = [
      for (final link in cmsLinksFromContent(widget.menu?.content ?? const {}))
        CmsEditableLink(label: link.label, url: link.url),
    ];
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.dialogBorder),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.menu == null ? 'Add menu' : 'Edit menu',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _title,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'Primary',
                  ),
                ),
                const SizedBox(height: 16),
                CmsLinkListEditor(key: _linksKey, initial: initial),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: AppColors.error)),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save'),
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
