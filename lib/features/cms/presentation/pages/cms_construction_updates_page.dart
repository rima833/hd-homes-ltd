import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/media/widgets/delivery_image.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/construction/presentation/providers/construction_platform_providers.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/cms/presentation/widgets/cms_admin_widgets.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';

/// Admin → Website → Construction: public Properties → Construction Updates CMS.
class CmsConstructionUpdatesPage extends ConsumerWidget {
  const CmsConstructionUpdatesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(cmsWebsiteConstructionUpdatesProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSectionHeader(
            title: 'Construction updates',
            subtitle:
                'Public progress cards for Properties → Construction Updates (/construction). '
                'Published cards sync across portals in realtime.',
            action: FilledButton.icon(
              onPressed: () => _openEditor(context, ref, null),
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('Add project'),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: async.when(
              loading: () => const AdminLoadingView(),
              error: (err, _) => AdminErrorView(
                message: '$err',
                onRetry: () =>
                    ref.invalidate(cmsWebsiteConstructionUpdatesProvider),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return AdminEmptyState(
                    title: 'No construction updates yet',
                    message: 'Add your first on-site progress card.',
                    icon: LucideIcons.hardHat,
                    action: FilledButton.icon(
                      onPressed: () => _openEditor(context, ref, null),
                      icon: const Icon(LucideIcons.plus, size: 16),
                      label: const Text('Add project'),
                    ),
                  );
                }
                return ReorderableListView.builder(
                  itemCount: items.length,
                  buildDefaultDragHandles: false,
                  onReorder: (o, n) => _reorder(ref, items, o, n),
                  itemBuilder: (context, i) {
                    final item = items[i];
                    final published = item.status == 'active';
                    final phase = item.phases.isEmpty
                        ? '—'
                        : item.phases[item.safePhaseIndex];
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
                              _ConstructionAdminThumb(
                                coverUrl: item.coverImageUrl,
                                galleryCount: item.galleryImageUrls.length,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.projectName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    Text(
                                      [
                                        '${item.progressPct.toStringAsFixed(0)}%',
                                        phase,
                                        item.expectedCompletion,
                                        item.statusUpdate,
                                      ]
                                          .where((s) => s.trim().isNotEmpty)
                                          .join(' · '),
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
                                value: published,
                                activeTrackColor: AppColors.gold,
                                onChanged: (v) async {
                                  await ref
                                      .read(cmsServiceProvider)
                                      .setWebsiteConstructionStatus(
                                        id: item.id,
                                        status: v ? 'active' : 'draft',
                                      );
                                  if (ref.read(supabaseConfiguredProvider)) {
                                    await ref
                                        .read(constructionPlatformServiceProvider)
                                        .syncWebsiteCardToPlatform(
                                          projectName: item.projectName,
                                          slug: item.slug,
                                          statusUpdate: item.statusUpdate,
                                          expectedCompletion:
                                              item.expectedCompletion,
                                          progressPct: item.progressPct,
                                          coverImageUrl: item.coverImageUrl,
                                          galleryImageUrls:
                                              item.galleryImageUrls,
                                          published: v,
                                        );
                                  }
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
                                      .deleteWebsiteConstructionUpdate(
                                        item.id,
                                      );
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
    ref.invalidate(cmsWebsiteConstructionUpdatesProvider);
    ref.invalidate(publishedWebsiteConstructionUpdatesProvider);
    ref.invalidate(publicConstructionProjectsProvider);
    ref.invalidate(publicConstructionProjectBySlugProvider);
  }

  Future<void> _reorder(
    WidgetRef ref,
    List<CmsWebsiteConstructionUpdate> items,
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
        await service.setWebsiteConstructionSortOrder(
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
    CmsWebsiteConstructionUpdate? item,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _ConstructionEditDialog(item: item),
    );
    _invalidate(ref);
  }
}

class _ConstructionEditDialog extends ConsumerStatefulWidget {
  const _ConstructionEditDialog({this.item});

  final CmsWebsiteConstructionUpdate? item;

  @override
  ConsumerState<_ConstructionEditDialog> createState() =>
      _ConstructionEditDialogState();
}

class _ConstructionEditDialogState
    extends ConsumerState<_ConstructionEditDialog> {
  late final TextEditingController _name;
  late final TextEditingController _slug;
  late final TextEditingController _update;
  late final TextEditingController _completion;
  late final TextEditingController _progress;
  late final TextEditingController _phases;
  late final TextEditingController _cover;
  late final TextEditingController _ctaLabel;
  late final TextEditingController _ctaLink;
  final List<String> _galleryUrls = [];

  late int _phaseIndex;
  late bool _published;
  bool _saving = false;
  bool _uploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final i = widget.item;
    _name = TextEditingController(text: i?.projectName ?? '');
    _slug = TextEditingController(text: i?.slug ?? '');
    _update = TextEditingController(text: i?.statusUpdate ?? '');
    _completion = TextEditingController(text: i?.expectedCompletion ?? '');
    _progress = TextEditingController(
      text: '${i?.progressPct ?? 0}',
    );
    _phases = TextEditingController(
      text: (i?.phases ??
              const [
                'Planning',
                'Foundation',
                'Structure',
                'Roofing',
                'Finishing',
                'Completed',
              ])
          .join('\n'),
    );
    _cover = TextEditingController(text: i?.coverImageUrl ?? '');
    if (i != null && i.galleryImageUrls.isNotEmpty) {
      _galleryUrls.addAll(i.galleryImageUrls);
    }
    _ctaLabel = TextEditingController(text: i?.ctaLabel ?? 'View Progress');
    _ctaLink = TextEditingController(text: i?.ctaLink ?? '');
    _phaseIndex = i?.currentPhaseIndex ?? 0;
    _published = (i?.status ?? 'active') == 'active';
  }

  @override
  void dispose() {
    _name.dispose();
    _slug.dispose();
    _update.dispose();
    _completion.dispose();
    _progress.dispose();
    _phases.dispose();
    _cover.dispose();
    _ctaLabel.dispose();
    _ctaLink.dispose();
    super.dispose();
  }

  String _slugify(String input) => input
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  List<String> _phaseList() => _phases.text
      .split(RegExp(r'[\n,]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  Future<void> _uploadCover() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (bytes == null || bytes.isEmpty) return;
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final url =
          await ref.read(cmsServiceProvider).uploadWebsiteConstructionCover(
                bytes: bytes,
                contentType:
                    file?.extension == 'png' ? 'image/png' : 'image/jpeg',
              );
      _cover.text = url;
    } catch (e) {
      _error = userFacingError(e);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _uploadGalleryPhoto() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (bytes == null || bytes.isEmpty) return;
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final url =
          await ref.read(cmsServiceProvider).uploadWebsiteConstructionCover(
                bytes: bytes,
                contentType:
                    file?.extension == 'png' ? 'image/png' : 'image/jpeg',
              );
      _galleryUrls.add(url);
    } catch (e) {
      _error = userFacingError(e);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    var slug = _slug.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Project name is required');
      return;
    }
    if (slug.isEmpty) slug = _slugify(name);
    final phases = _phaseList();
    if (phases.isEmpty) {
      setState(() => _error = 'Add at least one milestone phase');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final existing = ref
              .read(cmsWebsiteConstructionUpdatesProvider)
              .valueOrNull
              ?.length ??
          0;
      await ref.read(cmsServiceProvider).upsertWebsiteConstructionUpdate(
            id: widget.item?.id,
            projectName: name,
            slug: slug,
            statusUpdate: _update.text.trim(),
            expectedCompletion: _completion.text.trim(),
            progressPct: double.tryParse(_progress.text.trim()) ?? 0,
            currentPhaseIndex: _phaseIndex.clamp(0, phases.length - 1),
            phases: phases,
            coverImageUrl:
                _cover.text.trim().isEmpty ? null : _cover.text.trim(),
            galleryImageUrls: List<String>.from(_galleryUrls),
            ctaLabel: _ctaLabel.text.trim().isEmpty
                ? 'View Progress'
                : _ctaLabel.text.trim(),
            ctaLink:
                _ctaLink.text.trim().isEmpty ? null : _ctaLink.text.trim(),
            sortOrder: widget.item?.sortOrder ?? (existing + 1) * 10,
            status: _published ? 'active' : 'draft',
          );
      if (ref.read(supabaseConfiguredProvider)) {
        await ref.read(constructionPlatformServiceProvider).syncWebsiteCardToPlatform(
              projectName: name,
              slug: slug,
              statusUpdate: _update.text.trim(),
              expectedCompletion: _completion.text.trim(),
              progressPct: double.tryParse(_progress.text.trim()) ?? 0,
              coverImageUrl:
                  _cover.text.trim().isEmpty ? null : _cover.text.trim(),
              galleryImageUrls: List<String>.from(_galleryUrls),
              published: _published,
            );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = userFacingError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final phases = _phaseList();
    final phaseItems = [
      for (var i = 0; i < phases.length; i++)
        DropdownMenuItem(value: i, child: Text('${i + 1}. ${phases[i]}')),
    ];

    return AlertDialog(
      title: Text(widget.item == null ? 'Add project' : 'Edit project'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(_name, 'Project name', onChanged: (v) {
                if (widget.item == null && _slug.text.isEmpty) {
                  _slug.text = _slugify(v);
                }
              }),
              _field(_slug, 'Slug'),
              _field(_update, 'Status update', maxLines: 2),
              _field(_completion, 'Expected completion (e.g. Q4 2026)'),
              _field(
                _progress,
                'Overall progress %',
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
              ),
              _field(
                _phases,
                'Milestone phases (one per line)',
                maxLines: 6,
                onChanged: (_) => setState(() {}),
              ),
              if (phaseItems.isNotEmpty)
                DropdownButtonFormField<int>(
                  initialValue: _phaseIndex.clamp(0, phases.length - 1),
                  decoration: const InputDecoration(
                    labelText: 'Current phase',
                    border: OutlineInputBorder(),
                  ),
                  items: phaseItems,
                  onChanged: (v) {
                    if (v != null) setState(() => _phaseIndex = v);
                  },
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _field(_cover, 'Cover image URL')),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _uploading ? null : _uploadCover,
                    icon: const Icon(LucideIcons.upload, size: 16),
                    label: Text(_uploading ? '…' : 'Upload'),
                  ),
                ],
              ),
              if (_cover.text.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: MediaDeliveryImage(
                    url: _cover.text.trim(),
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorWidget: const SizedBox.shrink(),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Site gallery photos'),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: _uploading ? null : _uploadGalleryPhoto,
                    icon: const Icon(LucideIcons.plus, size: 16),
                    label: const Text('Add photo'),
                  ),
                ],
              ),
              if (_galleryUrls.isNotEmpty)
                SizedBox(
                  height: 72,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _galleryUrls.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: MediaDeliveryImage(
                            url: _galleryUrls[i],
                            width: 96,
                            height: 72,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: InkWell(
                            onTap: () => setState(() => _galleryUrls.removeAt(i)),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(2),
                              child: const Icon(Icons.close, size: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Row(
                children: [
                  Expanded(child: _field(_ctaLabel, 'CTA label')),
                  const SizedBox(width: 8),
                  Expanded(child: _field(_ctaLink, 'CTA link (optional)')),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Published'),
                value: _published,
                activeTrackColor: AppColors.gold,
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

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    ValueChanged<String>? onChanged,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        onChanged: onChanged,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

class _ConstructionAdminThumb extends StatelessWidget {
  const _ConstructionAdminThumb({
    required this.coverUrl,
    required this.galleryCount,
  });

  final String? coverUrl;
  final int galleryCount;

  @override
  Widget build(BuildContext context) {
    final url = coverUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: MediaDeliveryImage(
              url: url,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              errorWidget: _fallback(),
            ),
          ),
          if (galleryCount > 0)
            Positioned(
              right: -4,
              bottom: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '+$galleryCount',
                  style: const TextStyle(
                    color: AppColors.deepBlack,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      );
    }
    return _fallback();
  }

  Widget _fallback() => Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.gold.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(LucideIcons.hardHat, color: AppColors.gold, size: 22),
      );
}
