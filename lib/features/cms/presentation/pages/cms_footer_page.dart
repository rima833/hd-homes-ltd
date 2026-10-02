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

/// Admin → Website → Footer: columns shown on every public page.
class CmsFooterPage extends ConsumerWidget {
  const CmsFooterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final footerAsync = ref.watch(cmsFooterSectionsProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSectionHeader(
            title: 'Footer',
            subtitle:
                'These columns replace the public footer links. Changes appear on every public page immediately.',
            action: FilledButton.icon(
              onPressed: () => _openEditor(context, ref, null),
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('Add column'),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: footerAsync.when(
              loading: () => const AdminLoadingView(),
              error: (err, _) => AdminErrorView(
                message: userFacingError(err),
                onRetry: () => ref.invalidate(cmsFooterSectionsProvider),
              ),
              data: (columns) {
                if (columns.isEmpty) {
                  return AdminEmptyState(
                    title: 'No footer columns yet',
                    message:
                        'Add a column such as Explore with About, Properties, and Contact.',
                    icon: LucideIcons.panelTop,
                    action: FilledButton.icon(
                      onPressed: () => _openEditor(context, ref, null),
                      icon: const Icon(LucideIcons.plus, size: 16),
                      label: const Text('Add column'),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: columns.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final column = columns[i];
                    final items = cmsLinksFromContent(column.content);
                    return AdminCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            LucideIcons.layoutTemplate,
                            size: 20,
                            color: AppColors.gold,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  column.displayTitle,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    for (final item in items)
                                      AdminStatusPill(
                                        label: item.label,
                                        color: AppColors.slate500,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Edit column',
                            onPressed: () => _openEditor(context, ref, column),
                            icon: const Icon(LucideIcons.pencil, size: 18),
                          ),
                          IconButton(
                            tooltip: 'Delete column',
                            onPressed: () =>
                                _deleteColumn(context, ref, column),
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
    CmsSectionRecord? column,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _FooterEditDialog(column: column),
    );
    ref.invalidate(cmsFooterSectionsProvider);
    ref.invalidate(publishedFooterSectionsProvider);
  }

  Future<void> _deleteColumn(
    BuildContext context,
    WidgetRef ref,
    CmsSectionRecord column,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete footer column?'),
        content: Text('Remove ${column.displayTitle} from the public footer.'),
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
    await ref.read(cmsServiceProvider).deleteSection(column.id);
    ref.invalidate(cmsFooterSectionsProvider);
    ref.invalidate(publishedFooterSectionsProvider);
  }
}

class _FooterEditDialog extends ConsumerStatefulWidget {
  const _FooterEditDialog({this.column});

  final CmsSectionRecord? column;

  @override
  ConsumerState<_FooterEditDialog> createState() => _FooterEditDialogState();
}

class _FooterEditDialogState extends ConsumerState<_FooterEditDialog> {
  late TextEditingController _title;
  final _linksKey = GlobalKey<CmsLinkListEditorState>();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.column?.title ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  String _sectionKey(String title) {
    final existing = widget.column?.sectionKey.trim() ?? '';
    if (existing.isNotEmpty) return existing;
    final slug = title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    if (slug.isNotEmpty) return 'footer_$slug';
    return 'footer_${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Give the column a name.');
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
          .upsertFooterSection(
            id: widget.column?.id,
            sectionKey: _sectionKey(title),
            title: title,
            content: {'items': items},
            sortOrder: widget.column?.sortOrder ?? 0,
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
      for (final link in cmsLinksFromContent(
        widget.column?.content ?? const {},
      ))
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
                  widget.column == null
                      ? 'Add footer column'
                      : 'Edit footer column',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _title,
                  decoration: const InputDecoration(
                    labelText: 'Column name',
                    hintText: 'Explore',
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
