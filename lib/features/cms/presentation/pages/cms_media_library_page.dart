import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/media/media_providers.dart';
import 'package:hdhomesproject/core/media/widgets/media_upload_panel.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/cms/presentation/widgets/cms_admin_widgets.dart';
import 'package:lucide_icons/lucide_icons.dart';

enum _MediaFilter { all, images, videos }

/// Admin → Website → Media Library — Cloudinary-backed with Supabase metadata.
class CmsMediaLibraryPage extends ConsumerStatefulWidget {
  const CmsMediaLibraryPage({super.key});

  @override
  ConsumerState<CmsMediaLibraryPage> createState() =>
      _CmsMediaLibraryPageState();
}

class _CmsMediaLibraryPageState extends ConsumerState<CmsMediaLibraryPage> {
  String? _folder;
  _MediaFilter _filter = _MediaFilter.all;
  String _query = '';
  String _sort = 'newest';
  String? _entityFilter;

  @override
  Widget build(BuildContext context) {
    ref.watch(cmsMediaRealtimeProvider);
    final live = ref.watch(cmsMediaRealtimeStatusProvider);
    final mediaAsync = ref.watch(cmsMediaProvider(_folder));
    final foldersAsync = ref.watch(cmsMediaFoldersProvider);
    final cloudinaryOn = ref.watch(cloudinaryEnabledProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSectionHeader(
            title: 'Media library',
            subtitle: cloudinaryOn
                ? '${mediaAsync.valueOrNull?.length ?? '—'} unique assets · optimized Cloudinary thumbnails'
                : 'Connect Supabase to enable Cloudinary uploads.',
            action: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  live || mediaAsync.hasValue
                      ? 'Your latest files are here.'
                      : "We're gathering the latest files.",
                  style: const TextStyle(
                    color: AppColors.slate400,
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _runLegacyMigration(context),
                  icon: const Icon(LucideIcons.refreshCcw, size: 16),
                  label: const Text('Migrate'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => _openUploadSheet(context),
                  icon: const Icon(LucideIcons.upload, size: 16),
                  label: const Text('Upload'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(LucideIcons.search, size: 18),
                    hintText: 'Search title, folder, entity…',
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _sort,
                items: const [
                  DropdownMenuItem(value: 'newest', child: Text('Newest')),
                  DropdownMenuItem(value: 'oldest', child: Text('Oldest')),
                  DropdownMenuItem(value: 'name', child: Text('Name')),
                ],
                onChanged: (v) => setState(() => _sort = v ?? 'newest'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              _FilterChip(
                label: 'All',
                selected: _filter == _MediaFilter.all,
                onTap: () => setState(() => _filter = _MediaFilter.all),
              ),
              _FilterChip(
                label: 'Images',
                selected: _filter == _MediaFilter.images,
                onTap: () => setState(() => _filter = _MediaFilter.images),
              ),
              _FilterChip(
                label: 'Videos',
                selected: _filter == _MediaFilter.videos,
                onTap: () => setState(() => _filter = _MediaFilter.videos),
              ),
              DropdownButton<String?>(
                value: _entityFilter,
                hint: const Text('Module'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('All modules')),
                  DropdownMenuItem(value: 'property', child: Text('Property')),
                  DropdownMenuItem(
                    value: 'development',
                    child: Text('Development'),
                  ),
                  DropdownMenuItem(value: 'estate', child: Text('Estate')),
                  DropdownMenuItem(
                    value: 'construction',
                    child: Text('Construction'),
                  ),
                  DropdownMenuItem(value: 'blog', child: Text('Blog')),
                  DropdownMenuItem(value: 'user', child: Text('User')),
                  DropdownMenuItem(value: 'library', child: Text('Library')),
                  DropdownMenuItem(
                    value: 'marketing',
                    child: Text('Marketing'),
                  ),
                ],
                onChanged: (v) => setState(() => _entityFilter = v),
              ),
            ],
          ),
          foldersAsync.when(
            data: (folders) => folders.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _FolderChip(
                            label: 'All folders',
                            selected: _folder == null,
                            onTap: () => setState(() => _folder = null),
                          ),
                          ...folders.map(
                            (f) => _FolderChip(
                              label: f,
                              selected: _folder == f,
                              onTap: () => setState(() => _folder = f),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: mediaAsync.when(
              loading: () => const AdminLoadingView(),
              error: (err, _) => AdminErrorView(
                message: '$err',
                onRetry: () => ref.invalidate(cmsMediaProvider(_folder)),
              ),
              data: (assets) {
                final filtered = _applyFilters(assets);
                if (filtered.isEmpty) {
                  return AdminEmptyState(
                    title: 'No media assets yet',
                    message: 'Upload images or videos to the HD Homes media library.',
                    icon: LucideIcons.image,
                    action: FilledButton.icon(
                      onPressed: () => _openUploadSheet(context),
                      icon: const Icon(LucideIcons.upload, size: 16),
                      label: const Text('Upload'),
                    ),
                  );
                }
                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) => _MediaCard(
                    asset: filtered[i],
                    onDelete: () => _confirmDelete(context, filtered[i]),
                    onTogglePublish: () => _togglePublish(filtered[i]),
                    onPreview: () => _preview(context, filtered[i]),
                    onEditAlt: () => _editAlt(filtered[i]),
                    onReplace: () => _replace(filtered[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<CmsMediaAsset> _applyFilters(List<CmsMediaAsset> assets) {
    final q = _query.trim().toLowerCase();
    var list = assets.where((a) {
      if (_filter == _MediaFilter.images && !a.isImage) return false;
      if (_filter == _MediaFilter.videos && !a.isVideo) return false;
      if (_entityFilter != null &&
          (a.entityType?.toLowerCase() != _entityFilter)) {
        return false;
      }
      if (q.isEmpty) return true;
      return a.displayTitle.toLowerCase().contains(q) ||
          (a.folderName?.toLowerCase().contains(q) ?? false) ||
          (a.entityType?.toLowerCase().contains(q) ?? false) ||
          (a.cloudinaryPublicId?.toLowerCase().contains(q) ?? false);
    }).toList();

    list = switch (_sort) {
      'oldest' => list..sort((a, b) => (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0))),
      'name' => list..sort((a, b) => a.displayTitle.compareTo(b.displayTitle)),
      _ => list..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0))),
    };
    return list;
  }

  Future<void> _runLegacyMigration(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Migrate legacy media?'),
        content: const Text(
          'Imports property galleries, estate images, and blog covers into '
          'Cloudinary. Source Storage/Unsplash files are not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Migrate'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final cms = ref.read(cmsServiceProvider);
      // Prefer server-side batch (service role + Cloudinary).
      try {
        final batch = await cms.migrateLegacyMediaBatch();
        ref.invalidate(cmsMediaProvider(_folder));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Migrated ${batch['migrated'] ?? 0} · '
              'failed ${batch['failed'] ?? 0} · '
              'scanned ${batch['scanned'] ?? 0}',
            ),
          ),
        );
        return;
      } catch (_) {
        // Fall back to client-side loops if batch function unavailable.
      }
      final props = await cms.migrateLegacyPropertyImages();
      final blogs = await cms.migrateLegacyBlogCovers();
      ref.invalidate(cmsMediaProvider(_folder));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Properties ${props['migrated']}/${props['failed']} failed · '
            'Blogs ${blogs['migrated']}/${blogs['failed']} failed',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Migration failed: $e')),
      );
    }
  }

  Future<void> _openUploadSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: _UploadSheet(
          onDone: () {
            ref.invalidate(cmsMediaProvider(_folder));
            ref.invalidate(cmsMediaFoldersProvider);
          },
        ),
      ),
    );
    ref.invalidate(cmsMediaProvider(_folder));
  }

  Future<void> _confirmDelete(BuildContext context, CmsMediaAsset asset) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete media?'),
        content: Text('Remove "${asset.displayTitle}" from the library?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(cmsServiceProvider).deleteMediaAsset(asset.id);
    ref.invalidate(cmsMediaProvider(_folder));
  }

  Future<void> _togglePublish(CmsMediaAsset asset) async {
    await ref
        .read(cmsServiceProvider)
        .setMediaPublished(asset.id, !asset.isPublished);
    ref.invalidate(cmsMediaProvider(_folder));
  }

  Future<void> _editAlt(CmsMediaAsset asset) async {
    final controller = TextEditingController(text: asset.altText ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Alt text'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Accessibility / SEO description'),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (saved != true) return;
    await ref.read(cmsServiceProvider).updateMediaAltText(asset.id, controller.text.trim());
    ref.invalidate(cmsMediaProvider(_folder));
  }

  Future<void> _replace(CmsMediaAsset asset) async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;
    final name = file.name.toLowerCase();
    final contentType = name.endsWith('.png')
        ? 'image/png'
        : name.endsWith('.webp')
            ? 'image/webp'
            : 'image/jpeg';
    try {
      await ref.read(cmsServiceProvider).replaceMediaAsset(
            id: asset.id,
            bytes: bytes,
            contentType: contentType,
            fileName: file.name,
          );
      ref.invalidate(cmsMediaProvider(_folder));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Media replaced')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Replace failed: $e')),
      );
    }
  }

  void _preview(BuildContext context, CmsMediaAsset asset) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 560),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(asset.displayTitle, style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 8),
                Expanded(
                  child: asset.isVideo
                      ? Center(child: Text('Video: ${asset.deliveryUrl}'))
                      : MediaDeliveryImage(
                          url: asset.fileUrl,
                          secureUrl: asset.secureUrl,
                          fit: BoxFit.contain,
                        ),
                ),
                const SizedBox(height: 8),
                Text('Provider: ${asset.storageProvider}'),
                if (asset.cloudinaryPublicId != null)
                  SelectableText('Public ID: ${asset.cloudinaryPublicId}'),
                if (asset.entityType != null)
                  Text('Entity: ${asset.entityType} · ${asset.entityId ?? '—'}'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: asset.deliveryUrl),
                        );
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('URL copied')),
                          );
                        }
                      },
                      icon: const Icon(LucideIcons.copy, size: 14),
                      label: const Text('Copy URL'),
                    ),
                    if (asset.cloudinaryPublicId != null)
                      OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: asset.cloudinaryPublicId!),
                          );
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Public ID copied')),
                            );
                          }
                        },
                        icon: const Icon(LucideIcons.fingerprint, size: 14),
                        label: const Text('Copy public ID'),
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

class _MediaCard extends StatelessWidget {
  const _MediaCard({
    required this.asset,
    required this.onDelete,
    required this.onTogglePublish,
    required this.onPreview,
    required this.onEditAlt,
    required this.onReplace,
  });

  final CmsMediaAsset asset;
  final VoidCallback onDelete;
  final VoidCallback onTogglePublish;
  final VoidCallback onPreview;
  final VoidCallback onEditAlt;
  final VoidCallback onReplace;

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (asset.entityType != null) asset.entityType!,
      if (asset.folderName != null && asset.folderName!.isNotEmpty)
        asset.folderName!,
      if (asset.isPublished) 'Published' else 'Draft',
    ].join(' · ');

    return AdminCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onPreview,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    child: asset.isImage
                        ? MediaDeliveryImage(
                            url: asset.thumbnailUrl ?? asset.fileUrl,
                            secureUrl: asset.secureUrl,
                            fit: BoxFit.cover,
                            thumbnail: true,
                            cacheWidth: 480,
                            errorWidget: _fallback(),
                          )
                        : _fallback(video: true),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Material(
                      color: const Color(0xCC0B0E14),
                      shape: const CircleBorder(),
                      child: PopupMenuButton<String>(
                        tooltip: 'Actions',
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          LucideIcons.moreHorizontal,
                          size: 16,
                          color: Colors.white,
                        ),
                        onSelected: (value) {
                          switch (value) {
                            case 'alt':
                              onEditAlt();
                            case 'replace':
                              onReplace();
                            case 'publish':
                              onTogglePublish();
                            case 'delete':
                              onDelete();
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'alt',
                            child: Text('Alt text'),
                          ),
                          const PopupMenuItem(
                            value: 'replace',
                            child: Text('Replace'),
                          ),
                          PopupMenuItem(
                            value: 'publish',
                            child: Text(
                              asset.isPublished ? 'Unpublish' : 'Publish',
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    asset.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.slate500,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallback({bool video = false}) => Container(
        width: double.infinity,
        color: AppColors.slate700.withValues(alpha: 0.3),
        child: Icon(
          video ? LucideIcons.video : LucideIcons.fileText,
          size: 28,
          color: AppColors.slate500,
        ),
      );
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: AppColors.gold.withValues(alpha: 0.2),
        onSelected: (_) => onTap(),
      );
}

class _FolderChip extends StatelessWidget {
  const _FolderChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          selectedColor: AppColors.gold.withValues(alpha: 0.2),
          onSelected: (_) => onTap(),
        ),
      );
}

class _UploadSheet extends ConsumerStatefulWidget {
  const _UploadSheet({required this.onDone});
  final VoidCallback onDone;

  @override
  ConsumerState<_UploadSheet> createState() => _UploadSheetState();
}

class _UploadSheetState extends ConsumerState<_UploadSheet> {
  final _title = TextEditingController();
  final _folder = TextEditingController();
  bool _done = false;

  @override
  void dispose() {
    _title.dispose();
    _folder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Upload media', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        TextField(
          controller: _title,
          decoration: const InputDecoration(labelText: 'Title (optional)'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _folder,
          decoration: const InputDecoration(
            labelText: 'Folder (optional)',
            hintText: 'Campaign Assets',
          ),
        ),
        const SizedBox(height: 16),
        MediaUploadPanel(
          allowVideo: true,
          label: 'Choose image or video',
          hint: 'Max 15 MB images · 120 MB videos',
          onUpload: (bytes, contentType, fileName, onProgress) async {
            final cms = ref.read(cmsServiceProvider);
            final url = await cms.uploadMediaFile(
              bytes: bytes,
              contentType: contentType,
              folder: _folder.text.trim().isEmpty ? 'library' : _folder.text.trim(),
              fileName: fileName,
              onProgress: onProgress,
            );
            if (_title.text.trim().isEmpty) {
              _title.text = fileName;
            }
            // uploadMediaFile already inserts media row when Cloudinary enabled
            if (!ref.read(cloudinaryEnabledProvider)) {
              await cms.createMediaAsset(
                title: _title.text.trim().isEmpty ? fileName : _title.text.trim(),
                fileUrl: url,
                fileType: contentType.startsWith('video/') ? 'video' : 'image',
                folderName: _folder.text.trim().isEmpty ? null : _folder.text.trim(),
              );
            }
            setState(() => _done = true);
            widget.onDone();
          },
        ),
        if (_done) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ),
        ],
      ],
    );
  }
}
