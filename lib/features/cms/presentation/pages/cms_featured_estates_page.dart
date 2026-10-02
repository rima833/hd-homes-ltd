import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/media/widgets/estate_gallery_manager.dart';
import 'package:hdhomesproject/core/media/widgets/media_upload_panel.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/cms/presentation/widgets/cms_admin_widgets.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';

/// Admin → Properties → Estates
///
/// Create estates, upload covers, then Feature + Publish for homepage & /estates.
class CmsFeaturedEstatesPage extends ConsumerWidget {
  const CmsFeaturedEstatesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(publishedEstatesRealtimeProvider);
    final estatesAsync = ref.watch(cmsEstatesProvider);
    final liveAsync = ref.watch(publishedFeaturedEstatesProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSectionHeader(
            title: 'Estates',
            subtitle:
                'One place for estates on the public site.\n'
                'Flow: 1) New estate  →  2) Upload cover  →  3) Turn on Featured + Published  →  live on homepage & /estates.',
            action: FilledButton.icon(
              onPressed: () => _openEditor(context, ref, null),
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('New estate'),
            ),
          ),
          const SizedBox(height: 8),
          liveAsync.when(
            skipLoadingOnReload: true,
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (live) => _LiveOnHomepageStrip(
              label: 'On the public homepage',
              emptyMessage: 'Nothing featured yet — publish an estate below.',
              children: live
                  .map(
                    (e) => _LiveChip(
                      title: e.name,
                      subtitle: e.location.isEmpty ? e.displayStatus : e.location,
                      imageUrl: e.coverImageUrl,
                      icon: LucideIcons.building2,
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: estatesAsync.when(
              skipLoadingOnReload: true,
              loading: () => const AdminLoadingView(),
              error: (err, _) => AdminErrorView(
                message: '$err',
                onRetry: () => ref.invalidate(cmsEstatesProvider),
              ),
              data: (estates) {
                if (estates.isEmpty) {
                  return AdminEmptyState(
                    title: 'No estates yet',
                    message:
                        'Create an estate here, upload a cover, then publish it to the homepage.',
                    icon: LucideIcons.building2,
                    action: FilledButton.icon(
                      onPressed: () => _openEditor(context, ref, null),
                      icon: const Icon(LucideIcons.plus, size: 16),
                      label: const Text('New estate'),
                    ),
                  );
                }
                final featuredCount =
                    estates.where((e) => e.isFeatured && e.isPublished).length;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AdminKpi(
                      label: 'On the homepage',
                      value: '$featuredCount / ${estates.length}',
                      icon: LucideIcons.star,
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        itemCount: estates.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final estate = estates[i];
                          return AdminCard(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _CoverThumb(
                                  url: estate.coverImageUrl,
                                  fallbackIcon: LucideIcons.building2,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        estate.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      if (estate.location.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          estate.location,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: AppColors.slate500,
                                              ),
                                        ),
                                      ],
                                      if (estate.priceFromLabel != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          'From ${estate.priceFromLabel}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                                color: AppColors.gold,
                                              ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Column(
                                  children: [
                                    Text('Published',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall),
                                    Switch(
                                      value: estate.isPublished,
                                      activeTrackColor: AppColors.success,
                                      onChanged: (v) => _setPublished(
                                        context,
                                        ref,
                                        estate,
                                        v,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  children: [
                                    Text('Featured',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall),
                                    Switch(
                                      value: estate.isFeatured,
                                      activeTrackColor: AppColors.gold,
                                      onChanged: (v) => _setFeatured(
                                        context,
                                        ref,
                                        estate,
                                        v,
                                      ),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  tooltip: 'Edit estate',
                                  onPressed: () =>
                                      _openEditor(context, ref, estate),
                                  icon: const Icon(LucideIcons.pencil, size: 18),
                                ),
                                IconButton(
                                  tooltip: 'Delete estate',
                                  onPressed: () =>
                                      _confirmDelete(context, ref, estate),
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
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _invalidate(WidgetRef ref) {
    ref.invalidate(cmsEstatesProvider);
    ref.invalidate(publishedFeaturedEstatesProvider);
  }

  Future<void> _setPublished(
    BuildContext context,
    WidgetRef ref,
    CmsEstateSummary estate,
    bool published,
  ) async {
    try {
      await ref.read(cmsServiceProvider).setEstatePublished(estate.id, published);
      _invalidate(ref);
    } catch (e) {
      if (!context.mounted) return;
      _showError(context, e, 'Could not update publish status.');
    }
  }

  Future<void> _setFeatured(
    BuildContext context,
    WidgetRef ref,
    CmsEstateSummary estate,
    bool featured,
  ) async {
    try {
      await ref.read(cmsServiceProvider).setEstateFeatured(estate.id, featured);
      _invalidate(ref);
    } catch (e) {
      if (!context.mounted) return;
      _showError(context, e, 'Could not update featured status.');
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    CmsEstateSummary estate,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete estate'),
        content: Text(
          'Remove “${estate.name}” from the catalog? It leaves the public site. Properties linked to it stay.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(cmsServiceProvider).deleteEstate(estate.id);
      _invalidate(ref);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted ${estate.name}.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      _showError(context, e, 'Could not delete this estate.');
    }
  }

  void _showError(BuildContext context, Object error, String fallback) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(userFacingError(error, fallback: fallback))),
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref,
    CmsEstateSummary? estate,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _EstateFeaturedEditor(estate: estate),
    );
    _invalidate(ref);
  }
}

class _LiveOnHomepageStrip extends StatelessWidget {
  const _LiveOnHomepageStrip({
    required this.label,
    required this.emptyMessage,
    required this.children,
  });

  final String label;
  final String emptyMessage;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.globe, size: 16, color: AppColors.success),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (children.isEmpty)
            Text(
              emptyMessage,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.slate500),
            )
          else
            Wrap(spacing: 10, runSpacing: 10, children: children),
        ],
      ),
    );
  }
}

class _LiveChip extends StatelessWidget {
  const _LiveChip({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String? imageUrl;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.slate400.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 44,
              height: 44,
              child: imageUrl != null && imageUrl!.isNotEmpty
                  ? MediaDeliveryImage(
                      url: imageUrl!,
                      fit: BoxFit.cover,
                      errorWidget: _ph(),
                    )
                  : _ph(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: AppColors.slate500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ph() => Container(
        color: AppColors.slate400.withValues(alpha: 0.2),
        child: Icon(icon, size: 18, color: AppColors.slate500),
      );
}

class _CoverThumb extends StatelessWidget {
  const _CoverThumb({required this.url, required this.fallbackIcon});

  final String? url;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 72,
        height: 72,
        child: url != null && url!.isNotEmpty
            ? MediaDeliveryImage(
                url: url!,
                fit: BoxFit.cover,
                errorWidget: _placeholder(),
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: AppColors.slate400.withValues(alpha: 0.2),
        child: Icon(fallbackIcon, size: 22, color: AppColors.slate500),
      );
}

class _EstateFeaturedEditor extends ConsumerStatefulWidget {
  const _EstateFeaturedEditor({required this.estate});

  final CmsEstateSummary? estate;

  @override
  ConsumerState<_EstateFeaturedEditor> createState() =>
      _EstateFeaturedEditorState();
}

class _EstateFeaturedEditorState extends ConsumerState<_EstateFeaturedEditor> {
  late TextEditingController _name;
  late TextEditingController _slug;
  late TextEditingController _description;
  late TextEditingController _tagline;
  late TextEditingController _city;
  late TextEditingController _state;
  late TextEditingController _priceFrom;
  late TextEditingController _status;
  String? _coverUrl;
  String? _estateId;
  bool _saving = false;
  String? _error;
  String? _success;

  bool get _isNew => widget.estate == null;

  @override
  void initState() {
    super.initState();
    final e = widget.estate;
    _estateId = e?.id;
    _name = TextEditingController(text: e?.name ?? '');
    _slug = TextEditingController(text: e?.slug ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _tagline = TextEditingController(text: e?.tagline ?? '');
    _city = TextEditingController(text: e?.city ?? '');
    _state = TextEditingController(text: e?.state ?? '');
    _priceFrom = TextEditingController(text: e?.priceFromLabel ?? '');
    _status = TextEditingController(text: e?.marketingStatus ?? '');
    _coverUrl = e?.coverImageUrl;
  }

  @override
  void dispose() {
    _name.dispose();
    _slug.dispose();
    _description.dispose();
    _tagline.dispose();
    _city.dispose();
    _state.dispose();
    _priceFrom.dispose();
    _status.dispose();
    super.dispose();
  }

  String _slugify(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');

  Future<void> _uploadCover(
    List<int> bytes,
    String contentType,
    String fileName,
    void Function(double progress) onProgress,
  ) async {
    if (_estateId == null) {
      setState(() => _error = 'Save the estate once before uploading a cover.');
      return;
    }
    setState(() {
      _error = null;
      _success = null;
    });
    final url = await ref.read(cmsServiceProvider).uploadEstateCover(
          estateId: _estateId!,
          bytes: bytes,
          contentType: contentType,
          fileName: fileName,
          onProgress: onProgress,
        );
    if (!mounted) return;
    setState(() {
      _coverUrl = url;
      _success = 'Cover uploaded — preview below. Publish to go live.';
    });
  }

  Future<void> _save({required bool publishAndFeature}) async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Name is required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _success = null;
    });
    try {
      final service = ref.read(cmsServiceProvider);
      final slug = _slug.text.trim().isEmpty
          ? _slugify(_name.text)
          : _slug.text.trim();
      if (_isNew || _estateId == null) {
        final created = await service.createEstate(
          name: _name.text.trim(),
          slug: slug,
          description: _description.text.trim(),
          tagline: _tagline.text.trim(),
          city: _city.text.trim(),
          state: _state.text.trim(),
          priceFromLabel: _priceFrom.text.trim(),
          marketingStatus: _status.text.trim(),
          featureAndPublish: publishAndFeature,
        );
        _estateId = created.id;
      } else {
        await service.upsertEstateBasic(
          id: _estateId!,
          name: _name.text.trim(),
          slug: slug,
          description: _description.text.trim(),
          tagline: _tagline.text.trim(),
          city: _city.text.trim(),
          state: _state.text.trim(),
          priceFromLabel: _priceFrom.text.trim(),
          marketingStatus: _status.text.trim(),
        );
        if (publishAndFeature) {
          await service.setEstatePublished(_estateId!, true);
          await service.setEstateFeatured(_estateId!, true);
        }
      }
      if (!mounted) return;
      setState(() {
        _success = publishAndFeature
            ? 'Published to the public homepage.'
            : 'Saved. Toggle Featured + Published on the list, or publish now.';
      });
      if (publishAndFeature) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) setState(() => _error = userFacingError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isNew ? 'New estate' : 'Edit estate',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _coverUrl != null && _coverUrl!.isNotEmpty
                              ? SizedBox.expand(
                                  child: MediaDeliveryImage(
                                    url: _coverUrl!,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : _previewPlaceholder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_estateId != null)
                        MediaUploadPanel(
                          label: 'Upload cover image',
                          hint: 'JPEG, PNG, WebP · uploads via Cloudinary',
                          allowVideo: false,
                          onUpload: _uploadCover,
                        )
                      else
                        OutlinedButton.icon(
                          onPressed: null,
                          icon: const Icon(LucideIcons.upload, size: 16),
                          label: const Text('Save once, then upload cover'),
                        ),
                      if (_estateId != null) ...[
                        const SizedBox(height: 20),
                        Text(
                          'Estate gallery',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 8),
                        EstateGalleryManager(estateId: _estateId!),
                      ],
                      const SizedBox(height: 16),
                      TextField(
                        controller: _name,
                        decoration: const InputDecoration(labelText: 'Name'),
                        onChanged: (v) {
                          if (_isNew && _slug.text.isEmpty) {
                            _slug.text = _slugify(v);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _slug,
                        decoration: const InputDecoration(labelText: 'Slug'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _tagline,
                        decoration: const InputDecoration(labelText: 'Tagline'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _description,
                        maxLines: 3,
                        decoration:
                            const InputDecoration(labelText: 'Description'),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _city,
                              decoration:
                                  const InputDecoration(labelText: 'City'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _state,
                              decoration:
                                  const InputDecoration(labelText: 'State'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _priceFrom,
                              decoration: const InputDecoration(
                                labelText: 'Price from (e.g. ₦45M)',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _status,
                              decoration: const InputDecoration(
                                labelText: 'Badge (e.g. Selling Fast)',
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!,
                            style: const TextStyle(color: AppColors.error)),
                      ],
                      if (_success != null) ...[
                        const SizedBox(height: 12),
                        Text(_success!,
                            style: const TextStyle(color: AppColors.success)),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  if (!_isNew && _estateId != null)
                    TextButton.icon(
                      onPressed: _saving
                          ? null
                          : () async {
                              final id = _estateId!;
                              final name = _name.text.trim().isEmpty
                                  ? 'this estate'
                                  : _name.text.trim();
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (dialogContext) => AlertDialog(
                                  title: const Text('Delete estate'),
                                  content: Text(
                                    'Remove “$name” from the catalog? It leaves the public site. Properties linked to it stay.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(dialogContext).pop(false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.of(dialogContext).pop(true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed != true || !context.mounted) return;
                              setState(() => _saving = true);
                              try {
                                await ref.read(cmsServiceProvider).deleteEstate(id);
                                if (context.mounted) Navigator.of(context).pop();
                              } catch (e) {
                                if (mounted) {
                                  setState(() => _error = userFacingError(e));
                                }
                              } finally {
                                if (mounted) setState(() => _saving = false);
                              }
                            },
                      icon: const Icon(LucideIcons.trash2, size: 16),
                      label: const Text('Delete'),
                      style: TextButton.styleFrom(foregroundColor: AppColors.error),
                    ),
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  OutlinedButton.icon(
                    onPressed:
                        _saving ? null : () => _save(publishAndFeature: false),
                    icon: const Icon(LucideIcons.save, size: 16),
                    label: const Text('Save'),
                  ),
                  FilledButton.icon(
                    onPressed:
                        _saving ? null : () => _save(publishAndFeature: true),
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(LucideIcons.globe, size: 16),
                    label: const Text('Publish to homepage'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _previewPlaceholder() => Container(
        color: AppColors.charcoal,
        alignment: Alignment.center,
        child:
            const Icon(LucideIcons.building2, size: 40, color: AppColors.gold),
      );
}
