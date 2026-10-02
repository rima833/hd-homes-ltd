import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/seo/seo_config.dart';
import 'package:hdhomesproject/core/website/seo/seo_resolver.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/cms/presentation/widgets/cms_admin_widgets.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

const _seoTypes = ['page', 'blog', 'landing_page', 'property', 'estate', 'service'];

/// Public routes whose document tags this desk can override.
const _publicPages = <({String path, String label})>[
  (path: RoutePaths.home, label: 'Home'),
  (path: RoutePaths.about, label: 'About'),
  (path: RoutePaths.properties, label: 'Properties'),
  (path: RoutePaths.estates, label: 'Estates'),
  (path: RoutePaths.construction, label: 'Construction'),
  (path: RoutePaths.services, label: 'Services'),
  (path: RoutePaths.blog, label: 'Blog'),
  (path: RoutePaths.gallery, label: 'Gallery'),
  (path: RoutePaths.contact, label: 'Contact'),
  (path: RoutePaths.bookInspection, label: 'Book inspection'),
  (path: RoutePaths.bookConsultation, label: 'Book consultation'),
  (path: RoutePaths.search, label: 'Search'),
  (path: RoutePaths.trust, label: 'Trust'),
  (path: RoutePaths.investment, label: 'Investment'),
  (path: RoutePaths.careers, label: 'Careers'),
];

String _typeLabel(String type) => switch (type) {
      'page' => 'Page',
      'blog' => 'Blog',
      'landing_page' => 'Landing page',
      'property' => 'Property',
      'estate' => 'Estate',
      'service' => 'Service',
      _ => type,
    };

Color _scoreColor(int score) {
  if (score >= 70) return AppColors.success;
  if (score >= 40) return AppColors.warning;
  return AppColors.error;
}

/// Admin → Website → SEO: manage meta title/description/canonical/OG image
/// per page or entity (`seo_metadata` table).
class CmsSeoPage extends ConsumerStatefulWidget {
  const CmsSeoPage({super.key});

  @override
  ConsumerState<CmsSeoPage> createState() => _CmsSeoPageState();
}

class _CmsSeoPageState extends ConsumerState<CmsSeoPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    ref.watch(cmsSeoRealtimeProvider);
    final seoAsync = ref.watch(cmsSeoProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSectionHeader(
            title: 'SEO settings',
            subtitle:
                'Titles and descriptions saved here replace the public page tags for that path.',
            action: FilledButton.icon(
              onPressed: () => _openEditor(context, null),
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('Add SEO entry'),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: seoAsync.when(
              skipLoadingOnReload: true,
              loading: () => const AdminLoadingView(),
              error: (err, _) => AdminErrorView(
                message: userFacingError(err, fallback: 'Unable to load SEO entries.'),
                onRetry: () => ref.invalidate(cmsSeoProvider),
              ),
              data: (all) {
                final records = all.where((r) => r.entityType != 'company').toList();
                if (records.isEmpty) {
                  return AdminEmptyState(
                    title: 'No SEO records yet',
                    message: 'Add a path, title, and description for a public page.',
                    icon: LucideIcons.globe,
                    action: FilledButton.icon(
                      onPressed: () => _openEditor(context, null),
                      icon: const Icon(LucideIcons.plus, size: 16),
                      label: const Text('Add SEO entry'),
                    ),
                  );
                }
                final scores = records.map((r) => r.contentAudit.score).toList();
                final avg = scores.reduce((a, b) => a + b) / scores.length;
                final withIssues = records.where((r) => r.contentAudit.issues.isNotEmpty).length;
                final q = _query.trim().toLowerCase();
                final visible = records.where((r) {
                  if (q.isEmpty) return true;
                  return '${r.entityType} ${r.path ?? ''} ${r.metaTitle ?? ''} ${r.metaDescription ?? ''}'
                      .toLowerCase()
                      .contains(q);
                }).toList();
                final covered = records.map((r) => r.path).whereType<String>().toSet();
                final missing = _publicPages.where((page) => !covered.contains(page.path)).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (seoAsync.isLoading)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: AdminKpi(
                            label: 'Tracked entries',
                            value: '${records.length}',
                            icon: LucideIcons.fileText,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AdminKpi(
                            label: 'Average score',
                            value: avg.round().toString(),
                            icon: LucideIcons.searchCheck,
                            accent: avg >= 70 ? AppColors.success : AppColors.warning,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AdminKpi(
                            label: 'Need attention',
                            value: '$withIssues',
                            icon: LucideIcons.alertCircle,
                            accent: withIssues == 0 ? AppColors.success : AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: 'Search path, title, or type',
                        prefixIcon: Icon(LucideIcons.search, size: 18),
                      ),
                      onChanged: (value) => setState(() => _query = value),
                    ),
                    if (missing.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Public pages still using built-in tags',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final page in missing)
                            ActionChip(
                              label: Text(page.label),
                              avatar: const Icon(LucideIcons.plus, size: 14),
                              onPressed: () => _openEditor(context, null, seedPath: page.path),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    Expanded(
                      child: visible.isEmpty
                          ? const Center(child: Text('No SEO entries match that search.'))
                          : ListView.separated(
                              itemCount: visible.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 10),
                              itemBuilder: (context, i) {
                                final record = visible[i];
                                final audit = record.contentAudit;
                                return AdminCard(
                                  onTap: () => _openEditor(context, record),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                AdminStatusPill(
                                                  label: _typeLabel(record.entityType),
                                                  color: AppColors.info,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    record.path ?? 'No path',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(color: AppColors.slate500),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              (record.metaTitle ?? '').trim().isEmpty
                                                  ? 'No meta title'
                                                  : record.metaTitle!.trim(),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium
                                                  ?.copyWith(fontWeight: FontWeight.w600),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              (record.metaDescription ?? '').trim().isEmpty
                                                  ? 'No meta description'
                                                  : record.metaDescription!.trim(),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(context).textTheme.bodySmall,
                                            ),
                                            if (audit.issues.isNotEmpty) ...[
                                              const SizedBox(height: 8),
                                              Text(
                                                audit.issues.take(2).join(' '),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(color: AppColors.warning),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        children: [
                                          Text(
                                            '${audit.score}',
                                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                  color: _scoreColor(audit.score),
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                          const Text('score', style: TextStyle(fontSize: 11)),
                                        ],
                                      ),
                                      IconButton(
                                        tooltip: 'Open public page',
                                        onPressed: record.path == null
                                            ? null
                                            : () => _openPublic(record.path!),
                                        icon: const Icon(LucideIcons.externalLink, size: 18),
                                      ),
                                      IconButton(
                                        tooltip: 'Edit',
                                        onPressed: () => _openEditor(context, record),
                                        icon: const Icon(LucideIcons.pencil, size: 18),
                                      ),
                                      IconButton(
                                        tooltip: 'Delete',
                                        onPressed: () => _confirmDelete(context, record),
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

  Future<void> _openPublic(String path) async {
    final uri = Uri.base.replace(path: path, query: '');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openEditor(
    BuildContext context,
    CmsSeoRecord? record, {
    String? seedPath,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _SeoEditDialog(record: record, seedPath: seedPath),
    );
  }

  Future<void> _confirmDelete(BuildContext context, CmsSeoRecord record) async {
    final label = record.path ?? record.metaTitle ?? 'this entry';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete SEO entry'),
        content: Text(
          'Remove SEO for $label? The public page falls back to its built-in tags.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(cmsServiceProvider).deleteSeo(record.id);
      ref.invalidate(cmsSeoProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userFacingError(e, fallback: 'Could not delete this SEO entry.')),
        ),
      );
    }
  }
}

class _SeoEditDialog extends ConsumerStatefulWidget {
  const _SeoEditDialog({this.record, this.seedPath});

  final CmsSeoRecord? record;
  final String? seedPath;

  @override
  ConsumerState<_SeoEditDialog> createState() => _SeoEditDialogState();
}

class _SeoEditDialogState extends ConsumerState<_SeoEditDialog> {
  late String _entityType;
  late TextEditingController _path;
  late TextEditingController _metaTitle;
  late TextEditingController _metaDescription;
  late TextEditingController _canonicalUrl;
  late TextEditingController _ogImageUrl;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final record = widget.record;
    final seeded = widget.seedPath == null
        ? null
        : SeoResolver.resolvePath(widget.seedPath!);
    final type = record?.entityType ?? 'page';
    _entityType = _seoTypes.contains(type) ? type : type;
    _path = TextEditingController(text: record?.path ?? widget.seedPath ?? '');
    _metaTitle = TextEditingController(text: record?.metaTitle ?? seeded?.title ?? '');
    _metaDescription = TextEditingController(
      text: record?.metaDescription ?? seeded?.description ?? '',
    );
    _canonicalUrl = TextEditingController(
      text: record?.canonicalUrl ??
          (widget.seedPath == null ? '' : SeoConfig.canonicalFor(widget.seedPath!)),
    );
    _ogImageUrl = TextEditingController(text: record?.ogImageUrl ?? seeded?.ogImageUrl ?? '');
  }

  void _applyBuiltIn() {
    final route = _path.text.trim().isEmpty ? '/' : _path.text.trim();
    final builtIn = SeoResolver.resolvePath(route.startsWith('/') ? route : '/$route');
    if (builtIn == null) {
      setState(() => _error = 'This path has no built-in tags.');
      return;
    }
    _metaTitle.text = builtIn.title;
    _metaDescription.text = builtIn.description;
    if (_canonicalUrl.text.trim().isEmpty) {
      _canonicalUrl.text = SeoConfig.canonicalFor(route.startsWith('/') ? route : '/$route');
    }
    setState(() => _error = null);
  }

  @override
  void dispose() {
    _path.dispose();
    _metaTitle.dispose();
    _metaDescription.dispose();
    _canonicalUrl.dispose();
    _ogImageUrl.dispose();
    super.dispose();
  }

  SeoContentAudit get _audit => SeoContentAudit.evaluate(
        path: _path.text,
        metaTitle: _metaTitle.text,
        metaDescription: _metaDescription.text,
        canonicalUrl: _canonicalUrl.text,
        ogImageUrl: _ogImageUrl.text,
      );

  Future<void> _save() async {
    var path = _path.text.trim();
    if (path.isNotEmpty && !path.startsWith('/')) path = '/$path';
    if (path.isEmpty || _metaTitle.text.trim().isEmpty) {
      setState(() => _error = 'Path and meta title are required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(cmsServiceProvider).upsertSeo(
            id: widget.record?.id,
            entityType: _entityType.trim().isEmpty ? 'page' : _entityType.trim(),
            entityId: widget.record?.entityId,
            path: path,
            metaTitle: _metaTitle.text.trim(),
            metaDescription: _metaDescription.text.trim().isEmpty
                ? null
                : _metaDescription.text.trim(),
            canonicalUrl:
                _canonicalUrl.text.trim().isEmpty ? null : _canonicalUrl.text.trim(),
            ogImageUrl: _ogImageUrl.text.trim().isEmpty ? null : _ogImageUrl.text.trim(),
          );
      ref.invalidate(cmsSeoProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = userFacingError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final audit = _audit;
    final types = {
      ..._seoTypes,
      if (!_seoTypes.contains(_entityType)) _entityType,
    }.toList();
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
                  widget.record == null ? 'Add SEO entry' : 'Edit SEO entry',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'Score ${audit.score}. These tags are what the public page uses for this path.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.slate500,
                      ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  // ignore: deprecated_member_use
                  value: _publicPages.any((page) => page.path == _path.text.trim())
                      ? _path.text.trim()
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Public page',
                    hintText: 'Choose a page, or type a path',
                  ),
                  items: [
                    for (final page in _publicPages)
                      DropdownMenuItem(
                        value: page.path,
                        child: Text('${page.label}  ${page.path}'),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    final builtIn = SeoResolver.resolvePath(value);
                    setState(() {
                      _path.text = value;
                      if (widget.record == null && builtIn != null) {
                        _metaTitle.text = builtIn.title;
                        _metaDescription.text = builtIn.description;
                        _canonicalUrl.text = SeoConfig.canonicalFor(value);
                      }
                    });
                  },
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _applyBuiltIn,
                    child: const Text('Use built-in title and description'),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        // ignore: deprecated_member_use
                        value: types.contains(_entityType) ? _entityType : types.first,
                        decoration: const InputDecoration(labelText: 'Type'),
                        items: [
                          for (final type in types)
                            DropdownMenuItem(value: type, child: Text(_typeLabel(type))),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _entityType = value);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _path,
                        decoration: const InputDecoration(
                          labelText: 'Path',
                          hintText: '/contact',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _metaTitle,
                  decoration: InputDecoration(
                    labelText: 'Meta title',
                    helperText: '${_metaTitle.text.trim().length} characters · aim for 30–60',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _metaDescription,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Meta description',
                    helperText:
                        '${_metaDescription.text.trim().length} characters · aim for 80–160',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _canonicalUrl,
                  decoration: const InputDecoration(
                    labelText: 'Canonical URL',
                    hintText: 'https://hdhomesltd.com/contact',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _ogImageUrl,
                  decoration: const InputDecoration(
                    labelText: 'Open Graph image URL',
                    hintText: 'https://…',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                if (audit.issues.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  for (final issue in audit.issues)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        issue,
                        style: const TextStyle(color: AppColors.warning, fontSize: 12),
                      ),
                    ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: AppColors.error)),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _saving ? null : () => Navigator.of(context).pop(),
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
