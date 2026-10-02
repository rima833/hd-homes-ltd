import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/cms/presentation/widgets/cms_admin_widgets.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';

/// Admin → Website → Partners: CRUD for partners & affiliations.
class CmsPartnersPage extends ConsumerWidget {
  const CmsPartnersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partnersAsync = ref.watch(cmsPartnersProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSectionHeader(
            title: 'Partners & affiliations',
            subtitle:
                'Logos and details shown on Home, About, and Trust. Drag to reorder.',
            action: FilledButton.icon(
              onPressed: () => _openEditor(context, ref, null),
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('Add partner'),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: partnersAsync.when(
              loading: () => const AdminLoadingView(),
              error: (err, _) => AdminErrorView(
                message: '$err',
                onRetry: () => ref.invalidate(cmsPartnersProvider),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return AdminEmptyState(
                    title: 'No partners yet',
                    message: 'Add your first institutional partner or affiliate.',
                    icon: LucideIcons.heartHandshake,
                    action: FilledButton.icon(
                      onPressed: () => _openEditor(context, ref, null),
                      icon: const Icon(LucideIcons.plus, size: 16),
                      label: const Text('Add partner'),
                    ),
                  );
                }
                return ReorderableListView.builder(
                  itemCount: items.length,
                  buildDefaultDragHandles: false,
                  proxyDecorator: (child, index, animation) {
                    return Material(
                      elevation: 6,
                      borderRadius: BorderRadius.circular(12),
                      child: child,
                    );
                  },
                  onReorder: (oldIndex, newIndex) =>
                      _reorder(ref, items, oldIndex, newIndex),
                  itemBuilder: (context, i) {
                    final partner = items[i];
                    final active = partner.status == 'active';
                    return ReorderableDragStartListener(
                      key: ValueKey(partner.id),
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
                              _LogoThumb(partner: partner),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      partner.name,
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
                                        partner.category,
                                        if (partner.tagline.trim().isNotEmpty)
                                          partner.tagline,
                                      ].join(' · '),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: AppColors.slate500),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        _Chip(
                                          label: active ? 'Active' : 'Inactive',
                                          color: active
                                              ? AppColors.success
                                              : AppColors.slate500,
                                        ),
                                        if (partner.showOnHome)
                                          const _Chip(
                                            label: 'Home',
                                            color: AppColors.gold,
                                          ),
                                        if (partner.showOnAbout)
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
                                      .setPartnerVisibility(
                                        id: partner.id,
                                        status: v ? 'active' : 'draft',
                                      );
                                  _invalidate(ref);
                                },
                              ),
                              IconButton(
                                onPressed: () =>
                                    _openEditor(context, ref, partner),
                                icon: const Icon(LucideIcons.pencil, size: 18),
                              ),
                              IconButton(
                                onPressed: () async {
                                  await ref
                                      .read(cmsServiceProvider)
                                      .deletePartner(partner.id);
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
    ref.invalidate(cmsPartnersProvider);
    ref.invalidate(publishedPartnersHomeProvider);
    ref.invalidate(publishedPartnersAboutProvider);
  }

  Future<void> _reorder(
    WidgetRef ref,
    List<CmsPartner> items,
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
        await service.setPartnerSortOrder(reordered[i].id, nextOrder);
      }
    }
    _invalidate(ref);
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref,
    CmsPartner? partner,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _PartnerEditDialog(partner: partner),
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

class _LogoThumb extends StatelessWidget {
  const _LogoThumb({required this.partner});

  final CmsPartner partner;

  @override
  Widget build(BuildContext context) {
    final url = partner.logoUrl?.trim();
    return CircleAvatar(
      radius: 22,
      backgroundColor: AppColors.gold.withValues(alpha: 0.16),
      backgroundImage: (url != null && url.isNotEmpty) ? NetworkImage(url) : null,
      child: (url == null || url.isEmpty)
          ? const Icon(LucideIcons.building2, color: AppColors.gold, size: 18)
          : null,
    );
  }
}

class _PartnerEditDialog extends ConsumerStatefulWidget {
  const _PartnerEditDialog({this.partner});

  final CmsPartner? partner;

  @override
  ConsumerState<_PartnerEditDialog> createState() => _PartnerEditDialogState();
}

class _PartnerEditDialogState extends ConsumerState<_PartnerEditDialog> {
  late TextEditingController _name;
  late TextEditingController _category;
  late TextEditingController _tagline;
  late TextEditingController _logoUrl;
  late TextEditingController _sortOrder;
  String _iconName = 'building';
  bool _showOnHome = true;
  bool _showOnAbout = true;
  bool _published = true;
  bool _saving = false;
  bool _uploading = false;
  String? _error;

  static const _icons = <String>[
    'building',
    'landmark',
    'hardHat',
    'shield',
    'badge',
    'compass',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.partner;
    _name = TextEditingController(text: p?.name ?? '');
    _category = TextEditingController(text: p?.category ?? '');
    _tagline = TextEditingController(text: p?.tagline ?? '');
    _logoUrl = TextEditingController(text: p?.logoUrl ?? '');
    _sortOrder = TextEditingController(text: '${p?.sortOrder ?? 0}');
    _iconName = p?.iconName ?? 'building';
    _showOnHome = p?.showOnHome ?? true;
    _showOnAbout = p?.showOnAbout ?? true;
    _published = (p?.status ?? 'active') == 'active';
  }

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _tagline.dispose();
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
      final url = await ref.read(cmsServiceProvider).uploadPartnerLogo(
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
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Name is required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(cmsServiceProvider).upsertPartner(
            id: widget.partner?.id,
            name: _name.text.trim(),
            category: _category.text.trim(),
            tagline: _tagline.text.trim(),
            logoUrl: _logoUrl.text.trim().isEmpty ? null : _logoUrl.text.trim(),
            iconName: _iconName,
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
                  widget.partner == null ? 'Add partner' : 'Edit partner',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _category,
                  decoration: const InputDecoration(
                    labelText: 'Category (e.g. Banking)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _tagline,
                  decoration: const InputDecoration(
                    labelText: 'Tagline (optional)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _logoUrl,
                  decoration: const InputDecoration(
                    labelText: 'Logo URL',
                    hintText: 'Upload or paste a public image URL',
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
                  label: Text(_uploading ? 'Uploading…' : 'Upload logo'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _sortOrder,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Sort order'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue:
                      _icons.contains(_iconName) ? _iconName : 'building',
                  decoration: const InputDecoration(
                    labelText: 'Fallback icon (when no logo)',
                  ),
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
