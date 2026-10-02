import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/cms/presentation/widgets/cms_admin_widgets.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/audit_controller.dart';
import 'package:hdhomesproject/features/cms/presentation/utils/market_insights_audit.dart';
import 'package:hdhomesproject/features/investment/presentation/widgets/investment_market_insight_ui.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';

const _visualTypes = <String, String>{
  'line_chart': 'Line chart',
  'bar_chart': 'Bar chart',
  'gauge': 'Gauge / donut',
  'image': 'Cover image',
};

const _trendDirections = <String, String>{
  'up': 'Up',
  'down': 'Down',
  'neutral': 'Neutral',
};

const _iconOptions = <String, String>{
  'trendingUp': 'Trending up',
  'lineChart': 'Line chart',
  'barChart': 'Bar chart',
  'building2': 'Building',
  'percent': 'Percent',
  'map': 'Location',
  'pieChart': 'Pie chart',
};

/// Admin → Website → Investments → Market Insights tab.
class CmsMarketInsightsTab extends ConsumerWidget {
  const CmsMarketInsightsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(websiteMarketInsightsRealtimeProvider);
    final async = ref.watch(cmsWebsiteMarketInsightsProvider);

    ref.listen(cmsWebsiteMarketInsightsProvider, (prev, next) {
      if (prev is AsyncData && next is AsyncData && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Market insights synced'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    });

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSectionHeader(
            title: 'Market insights',
            subtitle:
                'Manage market intelligence on the public Investment Hub. Changes sync in real time.',
            action: FilledButton.icon(
              onPressed: () => _openEditor(context, ref, null),
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('Add Market Insight'),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: async.when(
              loading: () => const AdminLoadingView(),
              error: (err, _) => AdminErrorView(
                message: '$err',
                onRetry: () => _invalidate(ref),
              ),
              data: (items) => _InsightsWorkspace(
                items: items,
                onAdd: () => _openEditor(context, ref, null),
                onEdit: (item) => _openEditor(context, ref, item),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void _invalidate(WidgetRef ref) {
    ref.invalidate(cmsWebsiteMarketInsightsProvider);
    ref.invalidate(publishedWebsiteMarketInsightsProvider);
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref,
    CmsWebsiteMarketInsight? item,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _InsightEditDialog(item: item),
    );
    _invalidate(ref);
  }
}

/// Standalone route wrapper (deep-link to Market Insights tab).
class CmsMarketInsightsPage extends StatelessWidget {
  const CmsMarketInsightsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const CmsMarketInsightsTab();
  }
}

class _InsightsWorkspace extends ConsumerStatefulWidget {
  const _InsightsWorkspace({
    required this.items,
    required this.onAdd,
    required this.onEdit,
  });

  final List<CmsWebsiteMarketInsight> items;
  final VoidCallback onAdd;
  final ValueChanged<CmsWebsiteMarketInsight> onEdit;

  @override
  ConsumerState<_InsightsWorkspace> createState() =>
      _InsightsWorkspaceState();
}

class _InsightsWorkspaceState extends ConsumerState<_InsightsWorkspace> {
  String _query = '';
  String _filter = 'all';
  String _sort = 'sort_order';
  final _selected = <String>{};

  List<CmsWebsiteMarketInsight> get _filtered {
    final q = _query.trim().toLowerCase();
    final list = widget.items.where((item) {
      if (_filter == 'published' && !item.isPublished) return false;
      if (_filter == 'draft' && !item.isDraft) return false;
      if (_filter == 'archived' && !item.isArchived) return false;
      if (_filter == 'featured' && !item.isFeatured) return false;
      if (q.isEmpty) return true;
      return item.title.toLowerCase().contains(q) ||
          item.location.toLowerCase().contains(q) ||
          item.category.toLowerCase().contains(q) ||
          item.trend.toLowerCase().contains(q);
    }).toList();

    list.sort((a, b) {
      switch (_sort) {
        case 'newest':
          return (b.createdAt ?? DateTime(0))
              .compareTo(a.createdAt ?? DateTime(0));
        case 'oldest':
          return (a.createdAt ?? DateTime(0))
              .compareTo(b.createdAt ?? DateTime(0));
        case 'title':
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case 'updated':
          return (b.updatedAt ?? DateTime(0))
              .compareTo(a.updatedAt ?? DateTime(0));
        default:
          return a.sortOrder.compareTo(b.sortOrder);
      }
    });
    return list;
  }

  int get _published => widget.items.where((i) => i.isPublished).length;
  int get _drafts => widget.items.where((i) => i.isDraft).length;
  int get _archived => widget.items.where((i) => i.isArchived).length;
  int get _featured => widget.items.where((i) => i.isFeatured).length;

  DateTime? get _lastUpdated {
    DateTime? latest;
    for (final item in widget.items) {
      final u = item.updatedAt;
      if (u != null && (latest == null || u.isAfter(latest))) latest = u;
    }
    return latest;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            AdminKpi(label: 'Total', value: '${widget.items.length}'),
            AdminKpi(label: 'Published', value: '$_published'),
            AdminKpi(label: 'Drafts', value: '$_drafts'),
            AdminKpi(label: 'Archived', value: '$_archived'),
            AdminKpi(label: 'Featured', value: '$_featured'),
            if (_lastUpdated != null)
              AdminKpi(
                label: 'Last updated',
                value: _formatDate(_lastUpdated!),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(LucideIcons.search, size: 18),
                  hintText: 'Search insights…',
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(width: 10),
            DropdownButton<String>(
              value: _filter,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All')),
                DropdownMenuItem(value: 'published', child: Text('Published')),
                DropdownMenuItem(value: 'draft', child: Text('Drafts')),
                DropdownMenuItem(value: 'archived', child: Text('Archived')),
                DropdownMenuItem(value: 'featured', child: Text('Featured')),
              ],
              onChanged: (v) => setState(() => _filter = v ?? 'all'),
            ),
            const SizedBox(width: 10),
            DropdownButton<String>(
              value: _sort,
              items: const [
                DropdownMenuItem(value: 'sort_order', child: Text('Sort order')),
                DropdownMenuItem(value: 'updated', child: Text('Recently updated')),
                DropdownMenuItem(value: 'newest', child: Text('Newest')),
                DropdownMenuItem(value: 'oldest', child: Text('Oldest')),
                DropdownMenuItem(value: 'title', child: Text('Title')),
              ],
              onChanged: (v) => setState(() => _sort = v ?? 'sort_order'),
            ),
            if (_selected.isNotEmpty) ...[
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: const Icon(LucideIcons.moreHorizontal),
                onSelected: (action) => _bulk(action),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'publish', child: Text('Publish')),
                  PopupMenuItem(value: 'unpublish', child: Text('Unpublish')),
                  PopupMenuItem(value: 'archive', child: Text('Archive')),
                  PopupMenuItem(value: 'feature', child: Text('Feature')),
                  PopupMenuItem(
                    value: 'unfeature',
                    child: Text('Remove feature'),
                  ),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: filtered.isEmpty
              ? AdminEmptyState(
                  title: 'No market insights',
                  message: 'Add your first intelligence card for /investment.',
                  icon: LucideIcons.lineChart,
                  action: FilledButton.icon(
                    onPressed: widget.onAdd,
                    icon: const Icon(LucideIcons.plus, size: 16),
                    label: const Text('Add insight'),
                  ),
                )
              : ReorderableListView.builder(
                  itemCount: filtered.length,
                  buildDefaultDragHandles: false,
                  onReorder: _reorder,
                  itemBuilder: (context, i) {
                    final item = filtered[i];
                    final published = item.isPublished;
                    return ReorderableDragStartListener(
                      key: ValueKey(item.id),
                      index: i,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AdminCard(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Checkbox(
                                value: _selected.contains(item.id),
                                onChanged: (v) => setState(() {
                                  if (v == true) {
                                    _selected.add(item.id);
                                  } else {
                                    _selected.remove(item.id);
                                  }
                                }),
                              ),
                              const Icon(
                                LucideIcons.gripVertical,
                                size: 18,
                                color: AppColors.slate500,
                              ),
                              const SizedBox(width: 10),
                              if (MediaQuery.sizeOf(context).width >= 1100) ...[
                                SizedBox(
                                  width: 220,
                                  child: MarketInsightCard(
                                    insight: item,
                                    compact: true,
                                  ),
                                ),
                                const SizedBox(width: 14),
                              ],
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      [
                                        if (item.location.isNotEmpty)
                                          item.location,
                                        if (item.category.isNotEmpty)
                                          item.category,
                                        if (item.source.isNotEmpty)
                                          item.source,
                                      ].join(' · '),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        Chip(
                                          label: Text(
                                            item.statusLabel,
                                            style: const TextStyle(fontSize: 11),
                                          ),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        if (item.isFeatured)
                                          const Chip(
                                            label: Text(
                                              'Featured',
                                              style: TextStyle(fontSize: 11),
                                            ),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                        Chip(
                                          label: Text(
                                            item.value,
                                            style: const TextStyle(fontSize: 11),
                                          ),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                children: [
                                  IconButton(
                                    tooltip: published ? 'Unpublish' : 'Publish',
                                    onPressed: () => _togglePublish(item),
                                    icon: Icon(
                                      published
                                          ? LucideIcons.eyeOff
                                          : LucideIcons.eye,
                                      size: 18,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: item.isFeatured
                                        ? 'Unfeature'
                                        : 'Feature',
                                    onPressed: () => _toggleFeatured(item),
                                    icon: Icon(
                                      item.isFeatured
                                          ? LucideIcons.starOff
                                          : LucideIcons.star,
                                      size: 18,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Archive',
                                    onPressed: item.isArchived ? null : () => _archive(item),
                                    icon: const Icon(LucideIcons.archive, size: 18),
                                  ),
                                  IconButton(
                                    tooltip: 'Edit',
                                    onPressed: () => widget.onEdit(item),
                                    icon: const Icon(LucideIcons.pencil, size: 18),
                                  ),
                                  IconButton(
                                    tooltip: 'Delete',
                                    onPressed: () => _delete(item),
                                    icon: const Icon(
                                      LucideIcons.trash2,
                                      size: 18,
                                      color: AppColors.error,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    final d = dt.toLocal();
    return '${d.day.toString().padLeft(2, '0')} '
        '${_months[d.month - 1]} ${d.year}, '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  Future<void> _reorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final items = [..._filtered];
    final moved = items.removeAt(oldIndex);
    items.insert(newIndex, moved);
    final service = ref.read(cmsServiceProvider);
    for (var i = 0; i < items.length; i++) {
      await service.setWebsiteMarketInsightSortOrder(
        id: items[i].id,
        sortOrder: (i + 1) * 10,
      );
    }
    ref.invalidate(cmsWebsiteMarketInsightsProvider);
    ref.invalidate(publishedWebsiteMarketInsightsProvider);
    await logMarketInsightAudit(
      ref.read(auditServiceProvider),
      action: 'market_insight.reorder',
      insightId: moved.id,
      title: moved.title,
    );
  }

  Future<void> _togglePublish(CmsWebsiteMarketInsight item) async {
    final service = ref.read(cmsServiceProvider);
    final audit = ref.read(auditServiceProvider);
    if (item.isPublished) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Unpublish insight?'),
          content: Text('"${item.title}" will be hidden from /investment.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Unpublish'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      await service.unpublishWebsiteMarketInsight(item.id);
      await logMarketInsightAudit(
        audit,
        action: 'market_insight.unpublish',
        insightId: item.id,
        title: item.title,
      );
    } else {
      await service.publishWebsiteMarketInsight(item.id);
      await logMarketInsightAudit(
        audit,
        action: 'market_insight.publish',
        insightId: item.id,
        title: item.title,
      );
    }
    ref.invalidate(cmsWebsiteMarketInsightsProvider);
    ref.invalidate(publishedWebsiteMarketInsightsProvider);
  }

  Future<void> _archive(CmsWebsiteMarketInsight item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Archive insight?'),
        content: Text('"${item.title}" will be hidden publicly but kept in CMS.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(cmsServiceProvider).archiveWebsiteMarketInsight(item.id);
    await logMarketInsightAudit(
      ref.read(auditServiceProvider),
      action: 'market_insight.archive',
      insightId: item.id,
      title: item.title,
    );
    ref.invalidate(cmsWebsiteMarketInsightsProvider);
    ref.invalidate(publishedWebsiteMarketInsightsProvider);
  }

  Future<void> _toggleFeatured(CmsWebsiteMarketInsight item) async {
    final service = ref.read(cmsServiceProvider);
    await service.setWebsiteMarketInsightFeatured(
      id: item.id,
      isFeatured: !item.isFeatured,
    );
    ref.invalidate(cmsWebsiteMarketInsightsProvider);
    ref.invalidate(publishedWebsiteMarketInsightsProvider);
  }

  Future<void> _delete(CmsWebsiteMarketInsight item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete insight?'),
        content: Text('Remove "${item.title}" from the investment hub?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(cmsServiceProvider).deleteWebsiteMarketInsight(item.id);
    await logMarketInsightAudit(
      ref.read(auditServiceProvider),
      action: 'market_insight.delete',
      insightId: item.id,
      title: item.title,
    );
    ref.invalidate(cmsWebsiteMarketInsightsProvider);
    ref.invalidate(publishedWebsiteMarketInsightsProvider);
  }

  Future<void> _bulk(String action) async {
    final service = ref.read(cmsServiceProvider);
    final audit = ref.read(auditServiceProvider);
    for (final id in _selected) {
      CmsWebsiteMarketInsight? match;
      for (final i in widget.items) {
        if (i.id == id) {
          match = i;
          break;
        }
      }
      switch (action) {
        case 'publish':
          await service.publishWebsiteMarketInsight(id);
          await logMarketInsightAudit(
            audit,
            action: 'market_insight.publish',
            insightId: id,
            title: match?.title,
          );
        case 'unpublish':
          await service.unpublishWebsiteMarketInsight(id);
          await logMarketInsightAudit(
            audit,
            action: 'market_insight.unpublish',
            insightId: id,
            title: match?.title,
          );
        case 'archive':
          await service.archiveWebsiteMarketInsight(id);
          await logMarketInsightAudit(
            audit,
            action: 'market_insight.archive',
            insightId: id,
            title: match?.title,
          );
        case 'feature':
          await service.setWebsiteMarketInsightFeatured(
            id: id,
            isFeatured: true,
          );
        case 'unfeature':
          await service.setWebsiteMarketInsightFeatured(
            id: id,
            isFeatured: false,
          );
        case 'delete':
          await service.deleteWebsiteMarketInsight(id);
      }
    }
    setState(_selected.clear);
    ref.invalidate(cmsWebsiteMarketInsightsProvider);
    ref.invalidate(publishedWebsiteMarketInsightsProvider);
  }
}

class _InsightEditDialog extends ConsumerStatefulWidget {
  const _InsightEditDialog({this.item});

  final CmsWebsiteMarketInsight? item;

  @override
  ConsumerState<_InsightEditDialog> createState() =>
      _InsightEditDialogState();
}

class _InsightEditDialogState extends ConsumerState<_InsightEditDialog> {
  late final TextEditingController _title;
  late final TextEditingController _value;
  late final TextEditingController _trend;
  late final TextEditingController _summary;
  late final TextEditingController _location;
  late final TextEditingController _category;
  late final TextEditingController _source;
  late final TextEditingController _sourceUrl;
  late final TextEditingController _coverUrl;
  late String _icon;
  late String _visualType;
  late String _trendDirection;
  late bool _featured;
  late bool _published;
  bool _saving = false;
  bool _uploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _title = TextEditingController(text: item?.title ?? '');
    _value = TextEditingController(text: item?.value ?? '');
    _trend = TextEditingController(text: item?.trend ?? '');
    _summary = TextEditingController(text: item?.summary ?? '');
    _location = TextEditingController(text: item?.location ?? '');
    _category = TextEditingController(text: item?.category ?? '');
    _source = TextEditingController(text: item?.source ?? '');
    _sourceUrl = TextEditingController(text: item?.sourceUrl ?? '');
    _coverUrl = TextEditingController(text: item?.coverImageUrl ?? '');
    _icon = item?.icon ?? 'trendingUp';
    _visualType = item?.visualType ?? 'line_chart';
    _trendDirection = item?.trendDirection ?? 'up';
    _featured = item?.isFeatured ?? false;
    _published = item?.isPublished ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    _value.dispose();
    _trend.dispose();
    _summary.dispose();
    _location.dispose();
    _category.dispose();
    _source.dispose();
    _sourceUrl.dispose();
    _coverUrl.dispose();
    super.dispose();
  }

  CmsWebsiteMarketInsight get _preview => CmsWebsiteMarketInsight(
        id: widget.item?.id ?? 'preview',
        title: _title.text.trim().isEmpty ? 'Preview title' : _title.text.trim(),
        value: _value.text.trim(),
        trend: _trend.text.trim(),
        summary: _summary.text.trim(),
        location: _location.text.trim(),
        category: _category.text.trim(),
        icon: _icon,
        source: _source.text.trim(),
        sourceUrl: _sourceUrl.text.trim().isEmpty ? null : _sourceUrl.text.trim(),
        coverImageUrl:
            _coverUrl.text.trim().isEmpty ? null : _coverUrl.text.trim(),
        visualType: _visualType,
        trendDirection: _trendDirection,
        isFeatured: _featured,
        sortOrder: widget.item?.sortOrder ?? 0,
        status: _published ? 'published' : 'draft',
        isPublishedFlag: _published,
      );

  Future<void> _uploadCover() async {
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
      final id = widget.item?.id ?? 'new-${DateTime.now().millisecondsSinceEpoch}';
      final url = await ref.read(cmsServiceProvider).uploadWebsiteMarketInsightCover(
            bytes: bytes,
            contentType: contentType,
            insightId: id,
          );
      if (!mounted) return;
      setState(() => _coverUrl.text = url);
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
    if (_value.text.trim().isEmpty) {
      setState(() => _error = 'Value is required.');
      return;
    }
    if (_summary.text.trim().isEmpty) {
      setState(() => _error = 'Summary is required.');
      return;
    }
    final sourceUrl = _sourceUrl.text.trim();
    if (sourceUrl.isNotEmpty) {
      final uri = Uri.tryParse(sourceUrl);
      if (uri == null || !uri.hasScheme) {
        setState(() => _error = 'Source URL must be a valid http(s) link.');
        return;
      }
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final existing =
          ref.read(cmsWebsiteMarketInsightsProvider).valueOrNull ?? [];
      final published = _published;
      final saved = await ref.read(cmsServiceProvider).upsertWebsiteMarketInsight(
            id: widget.item?.id,
            title: _title.text.trim(),
            value: _value.text.trim(),
            trend: _trend.text.trim(),
            summary: _summary.text.trim(),
            location: _location.text.trim(),
            category: _category.text.trim(),
            icon: _icon,
            source: _source.text.trim(),
            sourceUrl: sourceUrl.isEmpty ? null : sourceUrl,
            coverImageUrl:
                _coverUrl.text.trim().isEmpty ? null : _coverUrl.text.trim(),
            visualType: _visualType,
            trendDirection: _trendDirection,
            isFeatured: _featured,
            sortOrder: widget.item?.sortOrder ?? (existing.length + 1) * 10,
            status: published ? 'published' : 'draft',
            isPublished: published,
            publishedAt: published ? DateTime.now().toUtc() : null,
          );
      await logMarketInsightAudit(
        ref.read(auditServiceProvider),
        action: widget.item == null
            ? 'market_insight.create'
            : published
                ? 'market_insight.publish'
                : 'market_insight.update',
        insightId: saved.id,
        title: saved.title,
        metadata: {'value': saved.value},
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = userFacingError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item == null ? 'Add market insight' : 'Edit insight'),
      content: SizedBox(
        width: 760,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: AppColors.error)),
                const SizedBox(height: 8),
              ],
              const Text(
                'Preview',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              MarketInsightCard(insight: _preview, compact: true),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _title,
                      decoration: const InputDecoration(labelText: 'Title *'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _value,
                      decoration: const InputDecoration(labelText: 'Value *'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _trend,
                      decoration: const InputDecoration(labelText: 'Trend label'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _trendDirection,
                      decoration: const InputDecoration(labelText: 'Direction'),
                      items: [
                        for (final e in _trendDirections.entries)
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                      ],
                      onChanged: (v) => setState(
                        () => _trendDirection = v ?? 'up',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _summary,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Summary *'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _location,
                      decoration: const InputDecoration(labelText: 'Location'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _category,
                      decoration: const InputDecoration(labelText: 'Category'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _icon,
                      decoration: const InputDecoration(labelText: 'Icon'),
                      items: [
                        for (final e in _iconOptions.entries)
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                      ],
                      onChanged: (v) => setState(() => _icon = v ?? 'trendingUp'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _visualType,
                      decoration: const InputDecoration(labelText: 'Visual'),
                      items: [
                        for (final e in _visualTypes.entries)
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                      ],
                      onChanged: (v) =>
                          setState(() => _visualType = v ?? 'line_chart'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _source,
                      decoration: const InputDecoration(labelText: 'Source'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _sourceUrl,
                      decoration: const InputDecoration(labelText: 'Source URL'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _coverUrl,
                      decoration: const InputDecoration(
                        labelText: 'Cover image URL',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _uploading ? null : _uploadCover,
                    icon: _uploading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(LucideIcons.upload, size: 16),
                    label: const Text('Upload'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Featured'),
                value: _featured,
                onChanged: (v) => setState(() => _featured = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Published'),
                subtitle: const Text('Visible on /investment when published'),
                value: _published,
                onChanged: (v) => setState(() => _published = v),
              ),
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
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
