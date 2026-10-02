import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/media/widgets/delivery_image.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/cms/presentation/widgets/cms_admin_widgets.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';

/// Admin → Banners: promo/carousel banners CRUD (`banners` table).
class CmsBannersPage extends ConsumerWidget {
  const CmsBannersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bannersAsync = ref.watch(cmsBannersProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSectionHeader(
            title: 'Banners',
            subtitle:
                'The first active banner is the gold bar on every public page. Explore appears only when a link is set.',
            action: FilledButton.icon(
              onPressed: () => _openEditor(context, ref, null),
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('Add banner'),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: bannersAsync.when(
              loading: () => const AdminLoadingView(),
              error: (err, _) => AdminErrorView(
                message: '$err',
                onRetry: () => ref.invalidate(cmsBannersProvider),
              ),
              data: (banners) {
                if (banners.isEmpty) {
                  return AdminEmptyState(
                    title: 'No banners yet',
                    message:
                        'Add a promotional banner to run on the public site.',
                    icon: LucideIcons.megaphone,
                    action: FilledButton.icon(
                      onPressed: () => _openEditor(context, ref, null),
                      icon: const Icon(LucideIcons.plus, size: 16),
                      label: const Text('Add banner'),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: banners.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final banner = banners[i];
                    return AdminCard(
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: banner.imageUrl != null
                                ? MediaDeliveryImage(
                                    url: banner.imageUrl!,
                                    width: 64,
                                    height: 48,
                                    fit: BoxFit.cover,
                                    errorWidget: _thumb(),
                                  )
                                : _thumb(),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  banner.title,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                if (banner.subtitle != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    banner.subtitle!,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: AppColors.slate500),
                                  ),
                                ],
                                if (banner.startsAt != null ||
                                    banner.endsAt != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    '${banner.startsAt != null ? DateFormat.yMMMd().format(banner.startsAt!) : 'Any time'} '
                                    '→ ${banner.endsAt != null ? DateFormat.yMMMd().format(banner.endsAt!) : 'no end'}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(color: AppColors.slate500),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          AdminStatusPill(
                            label: banner.isActive ? 'Active' : 'Inactive',
                            color: banner.isActive
                                ? AppColors.success
                                : AppColors.slate500,
                          ),
                          IconButton(
                            tooltip: banner.isActive
                                ? 'Hide from public site'
                                : 'Show on public site',
                            onPressed: () async {
                              await ref
                                  .read(cmsServiceProvider)
                                  .setBannerActive(banner.id, !banner.isActive);
                              ref.invalidate(cmsBannersProvider);
                              ref.invalidate(publishedActiveBannersProvider);
                            },
                            icon: Icon(
                              banner.isActive
                                  ? LucideIcons.eyeOff
                                  : LucideIcons.eye,
                              size: 18,
                            ),
                          ),
                          IconButton(
                            onPressed: () => _openEditor(context, ref, banner),
                            icon: const Icon(LucideIcons.pencil, size: 18),
                          ),
                          IconButton(
                            onPressed: () async {
                              await ref
                                  .read(cmsServiceProvider)
                                  .deleteBanner(banner.id);
                              ref.invalidate(cmsBannersProvider);
                              ref.invalidate(publishedActiveBannersProvider);
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

  Widget _thumb() => Container(
    width: 64,
    height: 48,
    color: AppColors.slate400.withValues(alpha: 0.2),
    child: const Icon(LucideIcons.image, size: 18, color: AppColors.slate500),
  );

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref,
    CmsBanner? banner,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _BannerEditDialog(banner: banner),
    );
    ref.invalidate(cmsBannersProvider);
  }
}

class _BannerEditDialog extends ConsumerStatefulWidget {
  const _BannerEditDialog({this.banner});

  final CmsBanner? banner;

  @override
  ConsumerState<_BannerEditDialog> createState() => _BannerEditDialogState();
}

class _BannerEditDialogState extends ConsumerState<_BannerEditDialog> {
  late TextEditingController _title;
  late TextEditingController _subtitle;
  late TextEditingController _imageUrl;
  late TextEditingController _linkUrl;
  late bool _active;
  bool _saving = false;
  bool _uploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final b = widget.banner;
    _title = TextEditingController(text: b?.title ?? '');
    _subtitle = TextEditingController(text: b?.subtitle ?? '');
    _imageUrl = TextEditingController(text: b?.imageUrl ?? '');
    _linkUrl = TextEditingController(text: b?.linkUrl ?? '');
    _active = b?.isActive ?? true;
  }

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    _imageUrl.dispose();
    _linkUrl.dispose();
    super.dispose();
  }

  Future<void> _uploadImage() async {
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
      final url = await ref
          .read(cmsServiceProvider)
          .uploadBannerImage(bytes: bytes, contentType: contentType);
      if (!mounted) return;
      setState(() => _imageUrl.text = url);
    } catch (e) {
      if (mounted) setState(() => _error = userFacingError(e));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
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
      await ref
          .read(cmsServiceProvider)
          .upsertBanner(
            id: widget.banner?.id,
            title: _title.text.trim(),
            subtitle: _subtitle.text.trim().isEmpty
                ? null
                : _subtitle.text.trim(),
            imageUrl: _imageUrl.text.trim().isEmpty
                ? null
                : _imageUrl.text.trim(),
            linkUrl: _linkUrl.text.trim().isEmpty ? null : _linkUrl.text.trim(),
            sortOrder: widget.banner?.sortOrder ?? 0,
            status: _active ? 'active' : 'inactive',
          );
      ref.invalidate(publishedActiveBannersProvider);
      ref.invalidate(cmsBannersProvider);
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
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.banner == null ? 'Add banner' : 'Edit banner',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _subtitle,
                  decoration: const InputDecoration(labelText: 'Subtitle'),
                ),
                const SizedBox(height: 12),
                if (_imageUrl.text.trim().isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: MediaDeliveryImage(
                      url: _imageUrl.text.trim(),
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorWidget: const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                OutlinedButton.icon(
                  onPressed: _uploading ? null : _uploadImage,
                  icon: _uploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(LucideIcons.upload, size: 16),
                  label: Text(_uploading ? 'Uploading…' : 'Upload image'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _imageUrl,
                  decoration: const InputDecoration(
                    labelText: 'Image URL (or upload above)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _linkUrl,
                  decoration: const InputDecoration(
                    labelText: 'Explore link',
                    hintText: '/properties or https://…',
                    helperText:
                        'Leave blank to show the message with no button.',
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show on public site'),
                  subtitle: const Text(
                    'Active banners appear in the gold top announcement bar.',
                  ),
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
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
