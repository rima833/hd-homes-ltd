import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/media/widgets/media_upload_panel.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';

/// Admin estate gallery — Cloudinary upload, reorder, cover, alt text, delete.
class EstateGalleryManager extends ConsumerStatefulWidget {
  const EstateGalleryManager({
    super.key,
    required this.estateId,
    this.compact = false,
  });

  final String estateId;
  final bool compact;

  @override
  ConsumerState<EstateGalleryManager> createState() =>
      _EstateGalleryManagerState();
}

class _EstateGalleryManagerState extends ConsumerState<EstateGalleryManager> {
  bool _busy = false;
  String? _error;

  Future<void> _refresh() async {
    ref.invalidate(estateImagesProvider(widget.estateId));
  }

  Future<void> _upload(
    List<int> bytes,
    String contentType,
    String fileName,
    void Function(double progress) onProgress,
  ) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final cms = ref.read(cmsServiceProvider);
      final existing = await cms.listEstateImages(widget.estateId);
      await cms.uploadEstateGalleryImage(
        estateId: widget.estateId,
        bytes: bytes,
        contentType: contentType,
        asCover: existing.isEmpty,
        sortOrder: existing.length,
        fileName: fileName,
        onProgress: onProgress,
      );
      await _refresh();
    } catch (e) {
      setState(() => _error = userFacingError(e));
      rethrow;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _uploadMultiple() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        withData: true,
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty) return;

      final cms = ref.read(cmsServiceProvider);
      var sortOrder = (await cms.listEstateImages(widget.estateId)).length;
      for (final file in result.files) {
        final bytes = file.bytes;
        if (bytes == null || bytes.isEmpty) continue;
        final name = file.name.toLowerCase();
        final contentType = name.endsWith('.png')
            ? 'image/png'
            : name.endsWith('.webp')
                ? 'image/webp'
                : name.endsWith('.gif')
                    ? 'image/gif'
                    : 'image/jpeg';
        await cms.uploadEstateGalleryImage(
          estateId: widget.estateId,
          bytes: bytes,
          contentType: contentType,
          asCover: sortOrder == 0,
          sortOrder: sortOrder,
          fileName: file.name,
        );
        sortOrder++;
      }
      await _refresh();
    } catch (e) {
      setState(() => _error = userFacingError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(EstateGalleryImage image) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove image?'),
        content: const Text('This removes the image from the estate gallery.'),
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

    setState(() => _busy = true);
    try {
      await ref.read(cmsServiceProvider).deleteEstateImage(image.id);
      await _refresh();
    } catch (e) {
      setState(() => _error = userFacingError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setCover(EstateGalleryImage image) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(cmsServiceProvider)
          .setEstateCoverImage(widget.estateId, image.id);
      await _refresh();
    } catch (e) {
      setState(() => _error = userFacingError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _replace(EstateGalleryImage image) async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) return;

    final name = file.name.toLowerCase();
    final contentType = name.endsWith('.png')
        ? 'image/png'
        : name.endsWith('.webp')
            ? 'image/webp'
            : name.endsWith('.gif')
                ? 'image/gif'
                : 'image/jpeg';

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(cmsServiceProvider).replaceEstateImage(
            imageId: image.id,
            bytes: bytes,
            contentType: contentType,
            fileName: file.name,
          );
      await _refresh();
    } catch (e) {
      setState(() => _error = userFacingError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editAlt(EstateGalleryImage image) async {
    final controller = TextEditingController(text: image.altText ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Alt text'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Describe this image for accessibility and SEO',
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (saved != true) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(cmsServiceProvider)
          .updateEstateImageAlt(image.id, controller.text.trim());
      await _refresh();
    } catch (e) {
      setState(() => _error = userFacingError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    final imagesAsync = ref.read(estateImagesProvider(widget.estateId));
    final images = imagesAsync.valueOrNull;
    if (images == null || images.length < 2) return;

    if (newIndex > oldIndex) newIndex -= 1;
    final next = [...images];
    final item = next.removeAt(oldIndex);
    next.insert(newIndex, item);

    setState(() => _busy = true);
    try {
      await ref.read(cmsServiceProvider).reorderEstateImages(
            widget.estateId,
            next.map((e) => e.id).toList(),
          );
      await _refresh();
    } catch (e) {
      setState(() => _error = userFacingError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(estateImagesRealtimeProvider(widget.estateId));
    final imagesAsync = ref.watch(estateImagesProvider(widget.estateId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.compact) ...[
          MediaUploadPanel(
            label: 'Upload estate image',
            hint: 'JPEG, PNG, WebP · max 15 MB · uploads via Cloudinary',
            allowVideo: false,
            onUpload: _upload,
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _busy ? null : _uploadMultiple,
            icon: Icon(LucideIcons.imagePlus, size: 16),
            label: const Text('Upload multiple images'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.gold,
              side: const BorderSide(color: AppColors.gold),
            ),
          ),
        ],
        if (_busy)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(color: AppColors.gold),
          ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: AppColors.error)),
        ],
        const SizedBox(height: 12),
        imagesAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: AppColors.gold),
            ),
          ),
          error: (e, _) => _EstateEmptyState(
            icon: LucideIcons.alertCircle,
            title: 'Could not load gallery',
            subtitle: '$e',
            action: TextButton(onPressed: _refresh, child: const Text('Retry')),
          ),
          data: (images) {
            if (images.isEmpty) {
              return const _EstateEmptyState(
                icon: LucideIcons.image,
                title: 'No gallery images yet',
                subtitle: 'Upload photos to showcase this estate on the website.',
              );
            }
            return ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorder: _reorder,
              itemCount: images.length,
              itemBuilder: (context, index) {
                final image = images[index];
                return _EstateGalleryTile(
                  key: ValueKey(image.id),
                  image: image,
                  index: index,
                  onSetCover: () => _setCover(image),
                  onDelete: () => _delete(image),
                  onEditAlt: () => _editAlt(image),
                  onReplace: () => _replace(image),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _EstateGalleryTile extends StatelessWidget {
  const _EstateGalleryTile({
    super.key,
    required this.image,
    required this.index,
    required this.onSetCover,
    required this.onDelete,
    required this.onEditAlt,
    required this.onReplace,
  });

  final EstateGalleryImage image;
  final int index;
  final VoidCallback onSetCover;
  final VoidCallback onDelete;
  final VoidCallback onEditAlt;
  final VoidCallback onReplace;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: AppColors.darkSurface.withValues(alpha: 0.6),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.only(right: 8, top: 28),
                child: Icon(LucideIcons.gripVertical, color: AppColors.slate500, size: 18),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: MediaDeliveryImage(
                url: image.url,
                secureUrl: image.secureUrl,
                width: 96,
                height: 72,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (image.isCover)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Cover',
                            style: TextStyle(
                              color: AppColors.gold,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (!image.isPublished)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Text(
                            'Draft',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: AppColors.slate500,
                                ),
                          ),
                        ),
                    ],
                  ),
                  if (image.altText?.isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Text(
                      image.altText!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    children: [
                      if (!image.isCover)
                        TextButton.icon(
                          onPressed: onSetCover,
                          icon: const Icon(LucideIcons.star, size: 14),
                          label: const Text('Set cover'),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            foregroundColor: AppColors.gold,
                          ),
                        ),
                      TextButton.icon(
                        onPressed: onEditAlt,
                        icon: const Icon(LucideIcons.type, size: 14),
                        label: const Text('Alt text'),
                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      ),
                      TextButton.icon(
                        onPressed: onReplace,
                        icon: const Icon(LucideIcons.refreshCw, size: 14),
                        label: const Text('Replace'),
                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      ),
                      TextButton.icon(
                        onPressed: onDelete,
                        icon: const Icon(LucideIcons.trash2, size: 14, color: AppColors.error),
                        label: const Text('Delete'),
                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EstateEmptyState extends StatelessWidget {
  const _EstateEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.slate700),
        color: AppColors.darkSurface.withValues(alpha: 0.35),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: AppColors.slate500),
          const SizedBox(height: 10),
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.slate500),
          ),
          if (action != null) ...[const SizedBox(height: 8), action!],
        ],
      ),
    );
  }
}
