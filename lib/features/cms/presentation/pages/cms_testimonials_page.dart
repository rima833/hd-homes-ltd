import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/cms/presentation/widgets/cms_admin_widgets.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';

/// Admin → Website → Testimonials: CRUD for client testimonials.
class CmsTestimonialsPage extends ConsumerWidget {
  const CmsTestimonialsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final testimonialsAsync = ref.watch(cmsTestimonialsProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSectionHeader(
            title: 'Testimonials',
            subtitle:
                'Quotes on Home, Opportunities, About & trust pages. Portal submissions arrive as Pending — publish to go live.',
            action: FilledButton.icon(
              onPressed: () => _openEditor(context, ref, null),
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('Add testimonial'),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: testimonialsAsync.when(
              loading: () => const AdminLoadingView(),
              error: (err, _) => AdminErrorView(
                message: '$err',
                onRetry: () => ref.invalidate(cmsTestimonialsProvider),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return AdminEmptyState(
                    title: 'No testimonials yet',
                    message: 'Add your first client quote to build social proof.',
                    icon: LucideIcons.messageSquare,
                    action: FilledButton.icon(
                      onPressed: () => _openEditor(context, ref, null),
                      icon: const Icon(LucideIcons.plus, size: 16),
                      label: const Text('Add testimonial'),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final t = items[i];
                    return AdminCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: AppColors.slate400.withValues(alpha: 0.2),
                            backgroundImage:
                                t.avatarUrl != null ? NetworkImage(t.avatarUrl!) : null,
                            child: t.avatarUrl == null
                                ? Text(t.clientName.isNotEmpty ? t.clientName[0] : '?')
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      t.clientName,
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    if (t.rating != null) ...[
                                      const SizedBox(width: 8),
                                      ...List.generate(
                                        t.rating!.clamp(0, 5),
                                        (_) => const Icon(LucideIcons.star, size: 14, color: AppColors.gold),
                                      ),
                                    ],
                                  ],
                                ),
                                if (t.clientTitle != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    t.clientTitle!,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: AppColors.slate500,
                                        ),
                                  ),
                                ],
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    Chip(
                                      label: Text(
                                        t.status == 'pending'
                                            ? 'Pending review'
                                            : t.status,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                      backgroundColor: t.status == 'pending'
                                          ? AppColors.gold.withValues(alpha: 0.18)
                                          : t.status == 'active'
                                              ? AppColors.success.withValues(alpha: 0.15)
                                              : AppColors.slate400.withValues(alpha: 0.15),
                                    ),
                                    if (t.status == 'pending')
                                      TextButton(
                                        onPressed: () async {
                                          await ref
                                              .read(cmsServiceProvider)
                                              .setTestimonialStatus(t.id, 'active');
                                          ref.invalidate(cmsTestimonialsProvider);
                                          ref.invalidate(publishedTestimonialsProvider);
                                        },
                                        child: const Text('Publish'),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(t.content, style: Theme.of(context).textTheme.bodyMedium),
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              Switch(
                                value: t.isFeatured,
                                activeTrackColor: AppColors.gold,
                                onChanged: (v) async {
                                  await ref
                                      .read(cmsServiceProvider)
                                      .setTestimonialFeatured(t.id, v);
                                  ref.invalidate(cmsTestimonialsProvider);
                                },
                              ),
                              const Text('Featured', style: TextStyle(fontSize: 11)),
                            ],
                          ),
                          IconButton(
                            onPressed: () => _openEditor(context, ref, t),
                            icon: const Icon(LucideIcons.pencil, size: 18),
                          ),
                          IconButton(
                            onPressed: () async {
                              await ref.read(cmsServiceProvider).deleteTestimonial(t.id);
                              ref.invalidate(cmsTestimonialsProvider);
                            },
                            icon: const Icon(LucideIcons.trash2, size: 18, color: AppColors.error),
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
    CmsTestimonial? testimonial,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _TestimonialEditDialog(testimonial: testimonial),
    );
    ref.invalidate(cmsTestimonialsProvider);
    ref.invalidate(publishedTestimonialsProvider);
  }
}

class _TestimonialEditDialog extends ConsumerStatefulWidget {
  const _TestimonialEditDialog({this.testimonial});

  final CmsTestimonial? testimonial;

  @override
  ConsumerState<_TestimonialEditDialog> createState() => _TestimonialEditDialogState();
}

class _TestimonialEditDialogState extends ConsumerState<_TestimonialEditDialog> {
  late TextEditingController _name;
  late TextEditingController _title;
  late TextEditingController _content;
  late TextEditingController _avatarUrl;
  int _rating = 5;
  bool _featured = false;
  String _status = 'active';
  bool _saving = false;
  bool _uploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final t = widget.testimonial;
    _name = TextEditingController(text: t?.clientName ?? '');
    _title = TextEditingController(text: t?.clientTitle ?? '');
    _content = TextEditingController(text: t?.content ?? '');
    _avatarUrl = TextEditingController(text: t?.avatarUrl ?? '');
    _rating = t?.rating ?? 5;
    _featured = t?.isFeatured ?? false;
    _status = t?.status ?? 'active';
  }

  @override
  void dispose() {
    _name.dispose();
    _title.dispose();
    _content.dispose();
    _avatarUrl.dispose();
    super.dispose();
  }

  Future<void> _uploadAvatar() async {
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
      final url = await ref.read(cmsServiceProvider).uploadTestimonialAvatar(
            bytes: bytes,
            contentType: contentType,
          );
      if (!mounted) return;
      setState(() => _avatarUrl.text = url);
    } catch (e) {
      if (mounted) setState(() => _error = userFacingError(e));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _content.text.trim().isEmpty) {
      setState(() => _error = 'Client name and quote are required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(cmsServiceProvider).upsertTestimonial(
            id: widget.testimonial?.id,
            clientName: _name.text.trim(),
            clientTitle: _title.text.trim().isEmpty ? null : _title.text.trim(),
            content: _content.text.trim(),
            rating: _rating,
            avatarUrl: _avatarUrl.text.trim().isEmpty ? null : _avatarUrl.text.trim(),
            isFeatured: _featured,
            status: _status,
          );
      ref.invalidate(publishedTestimonialsProvider);
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
                  widget.testimonial == null ? 'Add testimonial' : 'Edit testimonial',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Client name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Client title / company'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _content,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'Testimonial'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _uploading ? null : _uploadAvatar,
                  icon: _uploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(LucideIcons.upload, size: 16),
                  label: Text(_uploading ? 'Uploading…' : 'Upload avatar'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _avatarUrl,
                  decoration: const InputDecoration(labelText: 'Avatar URL (or upload)'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('Rating', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(width: 12),
                    ...List.generate(5, (i) {
                      final value = i + 1;
                      return IconButton(
                        onPressed: () => setState(() => _rating = value),
                        icon: Icon(
                          value <= _rating ? LucideIcons.star : LucideIcons.starOff,
                          size: 18,
                          color: AppColors.gold,
                        ),
                      );
                    }),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Featured on homepage'),
                  value: _featured,
                  activeTrackColor: AppColors.gold,
                  onChanged: (v) => setState(() => _featured = v),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Publish status'),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Active (live)')),
                    DropdownMenuItem(value: 'pending', child: Text('Pending review')),
                    DropdownMenuItem(value: 'draft', child: Text('Draft')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _status = v);
                  },
                ),
                const SizedBox(height: 8),                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: AppColors.error)),
                ],
                const SizedBox(height: 12),
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
