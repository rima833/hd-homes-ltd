import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/cms/presentation/widgets/cms_admin_widgets.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';

/// Admin → Estates: full estates admin surface — publish, feature and
/// edit basic identity (name/slug/description) for every estate.
class CmsEstatesAdminPage extends ConsumerWidget {
  const CmsEstatesAdminPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estatesAsync = ref.watch(cmsEstatesProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSectionHeader(
            title: 'Estates',
            subtitle: 'Manage every estate that can appear on the public website.',
            action: FilledButton.icon(
              onPressed: () => _openEditor(context, ref, null),
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('New estate'),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: estatesAsync.when(
              loading: () => const AdminLoadingView(),
              error: (err, _) => AdminErrorView(
                message: '$err',
                onRetry: () => ref.invalidate(cmsEstatesProvider),
              ),
              data: (estates) {
                if (estates.isEmpty) {
                  return AdminEmptyState(
                    title: 'No estates yet',
                    message: 'Create your first estate to start building the public catalog.',
                    icon: LucideIcons.building2,
                    action: FilledButton.icon(
                      onPressed: () => _openEditor(context, ref, null),
                      icon: const Icon(LucideIcons.plus, size: 16),
                      label: const Text('New estate'),
                    ),
                  );
                }
                final published = estates.where((e) => e.isPublished).length;
                final featured = estates.where((e) => e.isFeatured).length;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: AdminKpi(
                            label: 'Total estates',
                            value: '${estates.length}',
                            icon: LucideIcons.building2,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AdminKpi(
                            label: 'Published',
                            value: '$published',
                            icon: LucideIcons.globe,
                            accent: AppColors.success,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AdminKpi(
                            label: 'Featured on homepage',
                            value: '$featured',
                            icon: LucideIcons.star,
                          ),
                        ),
                      ],
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
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        estate.name,
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '/${estate.slug}',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: AppColors.slate500,
                                            ),
                                      ),
                                      if (estate.location.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          estate.location,
                                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                color: AppColors.slate500,
                                              ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                AdminStatusPill(
                                  label: estate.isPublished ? 'Published' : 'Draft',
                                  color: estate.isPublished ? AppColors.success : AppColors.slate500,
                                ),
                                const SizedBox(width: 8),
                                if (estate.isFeatured)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 4),
                                    child: Icon(LucideIcons.star, size: 16, color: AppColors.gold),
                                  ),
                                Switch(
                                  value: estate.isFeatured,
                                  activeTrackColor: AppColors.gold,
                                  onChanged: (v) async {
                                    await ref.read(cmsServiceProvider).setEstateFeatured(estate.id, v);
                                    ref.invalidate(cmsEstatesProvider);
                                  },
                                ),
                                Switch(
                                  value: estate.isPublished,
                                  activeTrackColor: AppColors.success,
                                  onChanged: (v) async {
                                    await ref.read(cmsServiceProvider).setEstatePublished(estate.id, v);
                                    ref.invalidate(cmsEstatesProvider);
                                  },
                                ),
                                IconButton(
                                  onPressed: () => _openEditor(context, ref, estate),
                                  icon: const Icon(LucideIcons.pencil, size: 18),
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

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref,
    CmsEstateSummary? estate,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _EstateEditDialog(estate: estate),
    );
    ref.invalidate(cmsEstatesProvider);
  }
}

class _EstateEditDialog extends ConsumerStatefulWidget {
  const _EstateEditDialog({this.estate});

  final CmsEstateSummary? estate;

  @override
  ConsumerState<_EstateEditDialog> createState() => _EstateEditDialogState();
}

class _EstateEditDialogState extends ConsumerState<_EstateEditDialog> {
  late TextEditingController _name;
  late TextEditingController _slug;
  late TextEditingController _description;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.estate;
    _name = TextEditingController(text: e?.name ?? '');
    _slug = TextEditingController(text: e?.slug ?? '');
    _description = TextEditingController(text: e?.description ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _slug.dispose();
    _description.dispose();
    super.dispose();
  }

  String _slugify(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
      .replaceAll(RegExp(r'\s+'), '-');

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Name is required.');
      return;
    }
    final slug = _slug.text.trim().isEmpty ? _slugify(_name.text) : _slug.text.trim();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final service = ref.read(cmsServiceProvider);
      if (widget.estate == null) {
        await service.createEstate(
          name: _name.text.trim(),
          slug: slug,
          description: _description.text.trim().isEmpty ? null : _description.text.trim(),
        );
      } else {
        await service.upsertEstateBasic(
          id: widget.estate!.id,
          name: _name.text.trim(),
          slug: slug,
          description: _description.text.trim().isEmpty ? null : _description.text.trim(),
        );
      }
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
                  widget.estate == null ? 'New estate' : 'Edit estate',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Estate name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _slug,
                  decoration: const InputDecoration(
                    labelText: 'Slug',
                    helperText: 'Leave blank to auto-generate from the name.',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _description,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description'),
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
