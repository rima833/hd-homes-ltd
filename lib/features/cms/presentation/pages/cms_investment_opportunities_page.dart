import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/media/widgets/delivery_image.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/cms/presentation/widgets/cms_admin_widgets.dart';
import 'package:hdhomesproject/features/cms/presentation/pages/cms_market_insights_page.dart';
import 'package:lucide_icons/lucide_icons.dart';

const _kStatuses = <String, String>{
  'open': 'Open',
  'limited': 'Limited',
  'coming_soon': 'Coming Soon',
  'closing_soon': 'Closing Soon',
  'closed': 'Closed',
  'sold_out': 'Sold Out',
};

/// Admin → Website → Investments: marketing investment opportunities CMS.
class CmsInvestmentOpportunitiesPage extends ConsumerWidget {
  const CmsInvestmentOpportunitiesPage({super.key, this.initialTab = 0});

  final int initialTab;

  static void _invalidate(WidgetRef ref) {
    ref.invalidate(cmsWebsiteInvestmentOpportunitiesProvider);
    ref.invalidate(publishedWebsiteInvestmentOpportunitiesProvider);
    ref.invalidate(publishedWebsiteInvestmentBySlugProvider);
    ref.invalidate(cmsWebsiteInvestmentCategoriesProvider);
    ref.invalidate(publishedWebsiteInvestmentCategoriesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab.clamp(0, 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: const TabBar(
              tabs: [
                Tab(text: 'Opportunities'),
                Tab(text: 'Market Insights'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                const _InvestmentOpportunitiesPanel(),
                const CmsMarketInsightsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InvestmentOpportunitiesPanel extends ConsumerWidget {
  const _InvestmentOpportunitiesPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(websiteInvestmentOpportunitiesRealtimeProvider);
    ref.watch(websiteInvestmentCategoriesRealtimeProvider);
    final async = ref.watch(cmsWebsiteInvestmentOpportunitiesProvider);
    final categories =
        ref.watch(cmsWebsiteInvestmentCategoriesProvider).valueOrNull ??
            const <CmsWebsiteInvestmentCategory>[];

    ref.listen(cmsWebsiteInvestmentOpportunitiesProvider, (prev, next) {
      if (prev is AsyncData && next is AsyncData && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Investment opportunity updated'),
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
            title: 'Investment opportunities',
            subtitle:
                'Public hub cards update in real time. Create, feature, publish, reorder, or archive.',
            action: Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _openCategories(context, ref),
                  icon: const Icon(LucideIcons.tags, size: 16),
                  label: const Text('Categories'),
                ),
                FilledButton.icon(
                  onPressed: () => _openEditor(context, ref, null, categories),
                  icon: const Icon(LucideIcons.plus, size: 16),
                  label: const Text('Add Investment'),
                ),
              ],
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
              data: (items) => _OpportunitiesWorkspace(
                items: items,
                categories: categories,
                onAdd: () => _openEditor(context, ref, null, categories),
                onEdit: (item) =>
                    _openEditor(context, ref, item, categories),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void _invalidate(WidgetRef ref) {
    ref.invalidate(cmsWebsiteInvestmentOpportunitiesProvider);
    ref.invalidate(publishedWebsiteInvestmentOpportunitiesProvider);
    ref.invalidate(publishedWebsiteInvestmentBySlugProvider);
    ref.invalidate(cmsWebsiteInvestmentCategoriesProvider);
    ref.invalidate(publishedWebsiteInvestmentCategoriesProvider);
  }

  Future<void> _openCategories(BuildContext context, WidgetRef ref) async {
    await showDialog<void>(
      context: context,
      builder: (_) => const _CategoryManagerDialog(),
    );
    _invalidate(ref);
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref,
    CmsWebsiteInvestmentOpportunity? item,
    List<CmsWebsiteInvestmentCategory> categories,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _OpportunityEditDialog(
        item: item,
        categories: categories,
      ),
    );
    _invalidate(ref);
  }
}

class _OpportunitiesWorkspace extends ConsumerStatefulWidget {
  const _OpportunitiesWorkspace({
    required this.items,
    required this.categories,
    required this.onAdd,
    required this.onEdit,
  });

  final List<CmsWebsiteInvestmentOpportunity> items;
  final List<CmsWebsiteInvestmentCategory> categories;
  final VoidCallback onAdd;
  final ValueChanged<CmsWebsiteInvestmentOpportunity> onEdit;

  @override
  ConsumerState<_OpportunitiesWorkspace> createState() =>
      _OpportunitiesWorkspaceState();
}

class _OpportunitiesWorkspaceState
    extends ConsumerState<_OpportunitiesWorkspace> {
  String _query = '';
  String _statusFilter = 'all';
  final _selected = <String>{};

  List<CmsWebsiteInvestmentOpportunity> get _filtered {
    final q = _query.trim().toLowerCase();
    return widget.items.where((item) {
      switch (_statusFilter) {
        case 'published':
          if (!item.isPublished) return false;
        case 'draft':
          if (item.isPublished) return false;
        case 'featured':
          if (!item.isFeatured) return false;
        case 'open':
        case 'limited':
        case 'closed':
          if (item.opportunityStatus != _statusFilter) return false;
      }
      if (q.isEmpty) return true;
      final hay = [
        item.projectName,
        item.locationDisplay,
        item.categoryLabel,
        item.opportunityStatus,
        item.slug,
      ].join(' ').toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  String _categoryName(CmsWebsiteInvestmentOpportunity item) {
    for (final c in widget.categories) {
      if (c.id == item.categoryId) return c.name;
    }
    return item.categoryLabel;
  }

  Future<void> _confirmDelete(CmsWebsiteInvestmentOpportunity item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete opportunity?'),
        content: Text(
          'Archive “${item.projectName}” from the public website? This can be undone only from the database.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref
        .read(cmsServiceProvider)
        .deleteWebsiteInvestmentOpportunity(item.id);
    CmsInvestmentOpportunitiesPage._invalidate(ref);
  }

  Future<void> _bulk(String action) async {
    if (_selected.isEmpty) return;
    if (action == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete selected?'),
          content: Text('Archive ${_selected.length} opportunities?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    final service = ref.read(cmsServiceProvider);
    for (final id in _selected) {
      switch (action) {
        case 'publish':
          await service.setWebsiteInvestmentStatus(id: id, status: 'active');
        case 'unpublish':
          await service.setWebsiteInvestmentStatus(id: id, status: 'draft');
        case 'feature':
          await service.setWebsiteInvestmentFeatured(id: id, isFeatured: true);
        case 'unfeature':
          await service.setWebsiteInvestmentFeatured(id: id, isFeatured: false);
        case 'delete':
          await service.deleteWebsiteInvestmentOpportunity(id);
      }
    }
    setState(() => _selected.clear());
    CmsInvestmentOpportunitiesPage._invalidate(ref);
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    if (oldIndex == newIndex) return;
    final reordered = [...widget.items];
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    final service = ref.read(cmsServiceProvider);
    for (var i = 0; i < reordered.length; i++) {
      final nextOrder = (i + 1) * 10;
      if (reordered[i].sortOrder != nextOrder) {
        await service.setWebsiteInvestmentSortOrder(reordered[i].id, nextOrder);
      }
    }
    CmsInvestmentOpportunitiesPage._invalidate(ref);
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final filtered = _filtered;
    final published = items.where((e) => e.isPublished).length;
    final drafts = items.length - published;
    final open = items.where((e) => e.opportunityStatus == 'open').length;
    final limited = items.where((e) => e.opportunityStatus == 'limited').length;
    final closed = items.where((e) => e.opportunityStatus == 'closed').length;
    final featured = items.where((e) => e.isFeatured).length;

    if (items.isEmpty) {
      return AdminEmptyState(
        title: 'No investment opportunities found.',
        message: 'Add your first opportunity to publish it on the public website.',
        icon: LucideIcons.trendingUp,
        action: FilledButton.icon(
          onPressed: widget.onAdd,
          icon: const Icon(LucideIcons.plus, size: 16),
          label: const Text('Add Investment'),
        ),
      );
    }

    return Column(
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: 160,
              child: AdminKpi(
                label: 'Total',
                value: '${items.length}',
                icon: LucideIcons.layers,
              ),
            ),
            SizedBox(
              width: 160,
              child: AdminKpi(
                label: 'Published',
                value: '$published',
                icon: LucideIcons.globe,
              ),
            ),
            SizedBox(
              width: 160,
              child: AdminKpi(
                label: 'Drafts',
                value: '$drafts',
                icon: LucideIcons.fileEdit,
              ),
            ),
            SizedBox(
              width: 160,
              child: AdminKpi(
                label: 'Open',
                value: '$open',
                icon: LucideIcons.circle,
              ),
            ),
            SizedBox(
              width: 160,
              child: AdminKpi(
                label: 'Limited',
                value: '$limited',
                icon: LucideIcons.alertTriangle,
              ),
            ),
            SizedBox(
              width: 160,
              child: AdminKpi(
                label: 'Closed',
                value: '$closed',
                icon: LucideIcons.lock,
              ),
            ),
            SizedBox(
              width: 160,
              child: AdminKpi(
                label: 'Featured',
                value: '$featured',
                icon: LucideIcons.crown,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  hintText: 'Search title, location, category…',
                  prefixIcon: Icon(LucideIcons.search, size: 16),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 10),
            DropdownButton<String>(
              value: _statusFilter,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All')),
                DropdownMenuItem(value: 'published', child: Text('Published')),
                DropdownMenuItem(value: 'draft', child: Text('Draft')),
                DropdownMenuItem(value: 'featured', child: Text('Featured')),
                DropdownMenuItem(value: 'open', child: Text('Open')),
                DropdownMenuItem(value: 'limited', child: Text('Limited')),
                DropdownMenuItem(value: 'closed', child: Text('Closed')),
              ],
              onChanged: (v) => setState(() => _statusFilter = v ?? 'all'),
            ),
            if (_selected.isNotEmpty) ...[
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                onSelected: _bulk,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'publish', child: Text('Publish')),
                  PopupMenuItem(value: 'unpublish', child: Text('Unpublish')),
                  PopupMenuItem(value: 'feature', child: Text('Feature')),
                  PopupMenuItem(value: 'unfeature', child: Text('Unfeature')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
                child: Chip(label: Text('${_selected.length} selected')),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: filtered.isEmpty
              ? const AdminEmptyState(
                  title: 'No matching opportunities',
                  message: 'Try another search or filter.',
                )
              : ReorderableListView.builder(
                  itemCount: filtered.length,
                  buildDefaultDragHandles: false,
                  onReorder: (o, n) {
                    // Reorder against the full published list, not the filtered view.
                    final from = widget.items
                        .indexWhere((e) => e.id == filtered[o].id);
                    var to = n >= filtered.length
                        ? widget.items
                            .indexWhere((e) => e.id == filtered.last.id)
                        : widget.items
                            .indexWhere((e) => e.id == filtered[n].id);
                    if (from < 0 || to < 0) return;
                    _reorder(from, to);
                  },
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
                              const SizedBox(width: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: 56,
                                  height: 40,
                                  child: item.coverImageUrl == null ||
                                          item.coverImageUrl!.isEmpty
                                      ? ColoredBox(
                                          color: AppColors.slate100,
                                          child: Icon(
                                            LucideIcons.image,
                                            size: 18,
                                            color: AppColors.slate500,
                                          ),
                                        )
                                      : MediaDeliveryImage(
                                          url: item.coverImageUrl!,
                                          fit: BoxFit.cover,
                                          errorWidget: const ColoredBox(
                                            color: AppColors.slate100,
                                            child: Icon(
                                              LucideIcons.image,
                                              size: 18,
                                              color: AppColors.slate500,
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            item.projectName,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                        ),
                                        if (item.isFeatured) ...[
                                          const SizedBox(width: 8),
                                          const Icon(
                                            LucideIcons.crown,
                                            size: 14,
                                            color: AppColors.gold,
                                          ),
                                        ],
                                      ],
                                    ),
                                    Text(
                                      [
                                        _categoryName(item),
                                        if (item.locationDisplay.isNotEmpty)
                                          item.locationDisplay,
                                        item.roiDisplay,
                                        item.statusLabel,
                                        '/investment/${item.slug}',
                                      ].join(' · '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: AppColors.slate500),
                                    ),
                                  ],
                                ),
                              ),
                              AdminStatusPill(
                                label: published ? 'Published' : 'Draft',
                                color: published
                                    ? AppColors.success
                                    : AppColors.slate500,
                              ),
                              const SizedBox(width: 8),
                              Switch(
                                value: published,
                                activeTrackColor: AppColors.gold,
                                onChanged: (v) async {
                                  await ref
                                      .read(cmsServiceProvider)
                                      .setWebsiteInvestmentStatus(
                                        id: item.id,
                                        status: v ? 'active' : 'draft',
                                      );
                                  CmsInvestmentOpportunitiesPage._invalidate(
                                    ref,
                                  );
                                },
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) async {
                                  final service = ref.read(cmsServiceProvider);
                                  switch (value) {
                                    case 'edit':
                                      widget.onEdit(item);
                                    case 'duplicate':
                                      await service
                                          .duplicateWebsiteInvestmentOpportunity(
                                        item,
                                      );
                                      CmsInvestmentOpportunitiesPage
                                          ._invalidate(ref);
                                    case 'feature':
                                      await service.setWebsiteInvestmentFeatured(
                                        id: item.id,
                                        isFeatured: !item.isFeatured,
                                      );
                                      CmsInvestmentOpportunitiesPage
                                          ._invalidate(ref);
                                    case 'delete':
                                      await _confirmDelete(item);
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'duplicate',
                                    child: Text('Duplicate'),
                                  ),
                                  PopupMenuItem(
                                    value: 'feature',
                                    child: Text(
                                      item.isFeatured ? 'Unfeature' : 'Feature',
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete'),
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
}

class _CategoryManagerDialog extends ConsumerStatefulWidget {
  const _CategoryManagerDialog();

  @override
  ConsumerState<_CategoryManagerDialog> createState() =>
      _CategoryManagerDialogState();
}

class _CategoryManagerDialogState
    extends ConsumerState<_CategoryManagerDialog> {
  final _name = TextEditingController();
  final _slug = TextEditingController();
  String _icon = 'building2';
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _slug.dispose();
    super.dispose();
  }

  String _slugify(String input) => input
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(cmsWebsiteInvestmentCategoriesProvider);
    return AlertDialog(
      title: const Text('Investment categories'),
      content: SizedBox(
        width: 520,
        child: async.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text(userFacingError(e)),
          data: (cats) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...cats.map(
                (c) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(c.name),
                  subtitle: Text(c.slug),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: c.isActive,
                        onChanged: (v) async {
                          await ref
                              .read(cmsServiceProvider)
                              .setWebsiteInvestmentCategoryActive(
                                id: c.id,
                                isActive: v,
                              );
                          ref.invalidate(cmsWebsiteInvestmentCategoriesProvider);
                          ref.invalidate(
                            publishedWebsiteInvestmentCategoriesProvider,
                          );
                        },
                      ),
                      IconButton(
                        onPressed: () async {
                          await ref
                              .read(cmsServiceProvider)
                              .deleteWebsiteInvestmentCategory(c.id);
                          ref.invalidate(cmsWebsiteInvestmentCategoriesProvider);
                          ref.invalidate(
                            publishedWebsiteInvestmentCategoriesProvider,
                          );
                        },
                        icon: const Icon(LucideIcons.trash2, size: 16),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(),
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'New category'),
                onChanged: (v) {
                  if (_slug.text.isEmpty) _slug.text = _slugify(v);
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _slug,
                decoration: const InputDecoration(labelText: 'Slug'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _icon,
                decoration: const InputDecoration(labelText: 'Icon'),
                items: const [
                  DropdownMenuItem(value: 'building2', child: Text('Building')),
                  DropdownMenuItem(value: 'lineChart', child: Text('Chart')),
                  DropdownMenuItem(value: 'package', child: Text('Growth')),
                  DropdownMenuItem(value: 'building', child: Text('Commercial')),
                  DropdownMenuItem(value: 'map', child: Text('Map')),
                  DropdownMenuItem(
                    value: 'splitSquareVertical',
                    child: Text('Fractional'),
                  ),
                ],
                onChanged: (v) => setState(() => _icon = v ?? 'building2'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: _saving
              ? null
              : () async {
                  final name = _name.text.trim();
                  if (name.isEmpty) return;
                  setState(() => _saving = true);
                  try {
                    final existing = ref
                            .read(cmsWebsiteInvestmentCategoriesProvider)
                            .valueOrNull
                            ?.length ??
                        0;
                    await ref
                        .read(cmsServiceProvider)
                        .upsertWebsiteInvestmentCategory(
                          name: name,
                          slug: _slug.text.trim().isEmpty
                              ? _slugify(name)
                              : _slug.text.trim(),
                          icon: _icon,
                          displayOrder: (existing + 1) * 10,
                        );
                    _name.clear();
                    _slug.clear();
                    ref.invalidate(cmsWebsiteInvestmentCategoriesProvider);
                    ref.invalidate(
                      publishedWebsiteInvestmentCategoriesProvider,
                    );
                  } finally {
                    if (mounted) setState(() => _saving = false);
                  }
                },
          child: Text(_saving ? 'Saving…' : 'Add category'),
        ),
      ],
    );
  }
}

class _OpportunityEditDialog extends ConsumerStatefulWidget {
  const _OpportunityEditDialog({this.item, required this.categories});

  final CmsWebsiteInvestmentOpportunity? item;
  final List<CmsWebsiteInvestmentCategory> categories;

  @override
  ConsumerState<_OpportunityEditDialog> createState() =>
      _OpportunityEditDialogState();
}

class _OpportunityEditDialogState
    extends ConsumerState<_OpportunityEditDialog> {
  late final TextEditingController _name;
  late final TextEditingController _slug;
  late final TextEditingController _cover;
  late final TextEditingController _gallery;
  late final TextEditingController _short;
  late final TextEditingController _full;
  late final TextEditingController _investmentType;
  late final TextEditingController _typeLabel;
  late final TextEditingController _location;
  late final TextEditingController _city;
  late final TextEditingController _roiMin;
  late final TextEditingController _roiMax;
  late final TextEditingController _roiLabel;
  late final TextEditingController _duration;
  late final TextEditingController _risk;
  late final TextEditingController _growth;
  late final TextEditingController _minInvest;
  late final TextEditingController _target;
  late final TextEditingController _raised;
  late final TextEditingController _progress;
  late final TextEditingController _featuredBadge;
  late final TextEditingController _demandBadge;
  late final TextEditingController _ctaLabel;
  late final TextEditingController _ctaLink;
  late final TextEditingController _secondaryCta;
  late final TextEditingController _metaTitle;
  late final TextEditingController _metaDescription;

  late String _opportunityStatus;
  late String? _categoryId;
  late bool _featured;
  late bool _published;
  late bool _showProgress;
  bool _saving = false;
  bool _uploading = false;
  String? _error;

  bool get _isNewPlaceholder =>
      widget.item != null && widget.item!.id.isEmpty;

  @override
  void initState() {
    super.initState();
    final i = _isNewPlaceholder ? null : widget.item;
    _name = TextEditingController(text: i?.projectName ?? '');
    _slug = TextEditingController(text: i?.slug ?? '');
    _cover = TextEditingController(text: i?.coverImageUrl ?? '');
    _gallery = TextEditingController(text: (i?.galleryImages ?? []).join('\n'));
    _short = TextEditingController(text: i?.shortDescription ?? '');
    _full = TextEditingController(text: i?.fullDescription ?? '');
    _investmentType =
        TextEditingController(text: i?.investmentType ?? 'Off-Plan');
    _typeLabel = TextEditingController(text: i?.typeLabel ?? 'Off-Plan');
    _location = TextEditingController(text: i?.location ?? '');
    _city = TextEditingController(text: i?.city ?? '');
    _roiMin = TextEditingController(text: '${i?.roiMin ?? 18}');
    _roiMax = TextEditingController(text: '${i?.roiMax ?? 22}');
    _roiLabel = TextEditingController(text: i?.roiLabel ?? '');
    _duration = TextEditingController(text: i?.duration ?? '24 months');
    _risk = TextEditingController(text: i?.riskLevel ?? 'Moderate');
    _growth = TextEditingController(text: i?.growthPotential ?? 'High');
    _minInvest = TextEditingController(text: i?.minimumInvestment ?? '');
    _target = TextEditingController(text: i?.targetAmount ?? '');
    _raised = TextEditingController(text: i?.amountRaised ?? '');
    _progress = TextEditingController(text: '${i?.progressPct ?? 0}');
    _featuredBadge = TextEditingController(text: i?.featuredBadge ?? 'Featured');
    _demandBadge = TextEditingController(text: i?.demandBadge ?? '');
    _ctaLabel = TextEditingController(text: i?.ctaLabel ?? 'View Opportunity');
    _ctaLink = TextEditingController(text: i?.ctaLink ?? '');
    _secondaryCta =
        TextEditingController(text: i?.secondaryCtaLabel ?? 'Request Information');
    _metaTitle = TextEditingController(text: i?.metaTitle ?? '');
    _metaDescription = TextEditingController(text: i?.metaDescription ?? '');
    _opportunityStatus = i?.opportunityStatus ?? 'open';
    _categoryId = i?.categoryId;
    _featured = i?.isFeatured ?? false;
    _published = (i?.status ?? 'active') == 'active';
    _showProgress = i?.showProgress ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _slug.dispose();
    _cover.dispose();
    _gallery.dispose();
    _short.dispose();
    _full.dispose();
    _investmentType.dispose();
    _typeLabel.dispose();
    _location.dispose();
    _city.dispose();
    _roiMin.dispose();
    _roiMax.dispose();
    _roiLabel.dispose();
    _duration.dispose();
    _risk.dispose();
    _growth.dispose();
    _minInvest.dispose();
    _target.dispose();
    _raised.dispose();
    _progress.dispose();
    _featuredBadge.dispose();
    _demandBadge.dispose();
    _ctaLabel.dispose();
    _ctaLink.dispose();
    _secondaryCta.dispose();
    _metaTitle.dispose();
    _metaDescription.dispose();
    super.dispose();
  }

  String _slugify(String input) => input
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  List<String> _galleryList() => _gallery.text
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
          await ref.read(cmsServiceProvider).uploadWebsiteInvestmentCover(
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

  Future<void> _uploadGallery() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
      allowMultiple: true,
    );
    final files = result?.files ?? const [];
    if (files.isEmpty) return;
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final urls = [..._galleryList()];
      for (final file in files) {
        final bytes = file.bytes;
        if (bytes == null || bytes.isEmpty) continue;
        final url = await ref
            .read(cmsServiceProvider)
            .uploadWebsiteInvestmentGalleryImage(
              bytes: bytes,
              contentType: file.extension == 'png' ? 'image/png' : 'image/jpeg',
            );
        urls.add(url);
      }
      _gallery.text = urls.join('\n');
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
      setState(() => _error = 'Title is required');
      return;
    }
    if (_categoryId == null || _categoryId!.isEmpty) {
      setState(() => _error = 'Category is required');
      return;
    }
    final roiMin = double.tryParse(_roiMin.text.trim()) ?? 0;
    final roiMax = double.tryParse(_roiMax.text.trim()) ?? 0;
    if (roiMin < 0 || roiMax < 0) {
      setState(() => _error = 'ROI cannot be negative');
      return;
    }
    if (slug.isEmpty) slug = _slugify(name);
    final selected = widget.categories.where((c) => c.id == _categoryId);
    final cat = selected.isEmpty ? null : selected.first;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final existing = ref
              .read(cmsWebsiteInvestmentOpportunitiesProvider)
              .valueOrNull
              ?.length ??
          0;
      await ref.read(cmsServiceProvider).upsertWebsiteInvestmentOpportunity(
            id: (_isNewPlaceholder || widget.item == null)
                ? null
                : widget.item!.id,
            projectName: name,
            slug: slug,
            coverImageUrl:
                _cover.text.trim().isEmpty ? null : _cover.text.trim(),
            galleryImages: _galleryList(),
            shortDescription: _short.text.trim(),
            fullDescription: _full.text.trim(),
            investmentType: cat?.name ?? _investmentType.text.trim(),
            typeLabel: cat?.name ?? _typeLabel.text.trim(),
            categoryId: _categoryId,
            location: _location.text.trim(),
            city: _city.text.trim(),
            roiMin: roiMin,
            roiMax: roiMax,
            roiLabel: _roiLabel.text.trim(),
            duration: _duration.text.trim(),
            riskLevel: _risk.text.trim(),
            growthPotential: _growth.text.trim(),
            minimumInvestment: _minInvest.text.trim(),
            targetAmount: _target.text.trim(),
            amountRaised: _raised.text.trim(),
            progressPct: (double.tryParse(_progress.text.trim()) ?? 0)
                .clamp(0, 100)
                .toDouble(),
            opportunityStatus: _opportunityStatus,
            isFeatured: _featured,
            featuredBadge: _featuredBadge.text.trim(),
            demandBadge: _demandBadge.text.trim().isEmpty
                ? null
                : _demandBadge.text.trim(),
            ctaLabel: _ctaLabel.text.trim().isEmpty
                ? 'View Opportunity'
                : _ctaLabel.text.trim(),
            ctaLink: _ctaLink.text.trim().isEmpty ? null : _ctaLink.text.trim(),
            secondaryCtaLabel: _secondaryCta.text.trim(),
            showProgress: _showProgress,
            metaTitle: _metaTitle.text.trim(),
            metaDescription: _metaDescription.text.trim(),
            sortOrder: widget.item?.sortOrder ?? (existing + 1) * 10,
            status: _published ? 'active' : 'draft',
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = userFacingError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.item == null || _isNewPlaceholder
            ? 'Add opportunity'
            : 'Edit opportunity',
      ),
      content: SizedBox(
        width: 680,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(_name, 'Title', onChanged: (v) {
                if ((widget.item == null || _isNewPlaceholder) &&
                    _slug.text.isEmpty) {
                  _slug.text = _slugify(v);
                }
              }),
              _field(_slug, 'Slug'),
              DropdownButtonFormField<String>(
                initialValue: widget.categories.any((c) => c.id == _categoryId)
                    ? _categoryId
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final c in widget.categories)
                    DropdownMenuItem(value: c.id, child: Text(c.name)),
                ],
                onChanged: (v) => setState(() => _categoryId = v),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _field(_location, 'Location')),
                  const SizedBox(width: 8),
                  Expanded(child: _field(_city, 'City')),
                ],
              ),
              Row(
                children: [
                  Expanded(child: _field(_cover, 'Cover image URL')),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _uploading ? null : _uploadCover,
                    icon: const Icon(LucideIcons.upload, size: 16),
                    label: const Text('Upload'),
                  ),
                ],
              ),
              _field(_gallery, 'Gallery image URLs (one per line)', maxLines: 3),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _uploading ? null : _uploadGallery,
                  icon: const Icon(LucideIcons.image, size: 16),
                  label: Text(_uploading ? 'Uploading…' : 'Upload gallery'),
                ),
              ),
              const SizedBox(height: 8),
              _field(_short, 'Short description', maxLines: 2),
              _field(_full, 'Full description', maxLines: 5),
              Row(
                children: [
                  Expanded(child: _field(_roiMin, 'ROI min %')),
                  const SizedBox(width: 8),
                  Expanded(child: _field(_roiMax, 'ROI max %')),
                  const SizedBox(width: 8),
                  Expanded(child: _field(_roiLabel, 'ROI label (e.g. yield)')),
                ],
              ),
              Row(
                children: [
                  Expanded(child: _field(_duration, 'Duration')),
                  const SizedBox(width: 8),
                  Expanded(child: _field(_risk, 'Risk level')),
                  const SizedBox(width: 8),
                  Expanded(child: _field(_growth, 'Growth potential')),
                ],
              ),
              Row(
                children: [
                  Expanded(child: _field(_minInvest, 'Minimum investment')),
                  const SizedBox(width: 8),
                  Expanded(child: _field(_target, 'Target amount')),
                ],
              ),
              Row(
                children: [
                  Expanded(child: _field(_raised, 'Amount raised')),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _field(
                      _progress,
                      'Progress %',
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                    ),
                  ),
                ],
              ),
              DropdownButtonFormField<String>(
                initialValue: _opportunityStatus,
                decoration: const InputDecoration(
                  labelText: 'Availability status',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final e in _kStatuses.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _opportunityStatus = v);
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _field(_featuredBadge, 'Featured badge')),
                  const SizedBox(width: 8),
                  Expanded(child: _field(_demandBadge, 'Demand badge')),
                ],
              ),
              Row(
                children: [
                  Expanded(child: _field(_ctaLabel, 'Primary CTA')),
                  const SizedBox(width: 8),
                  Expanded(child: _field(_ctaLink, 'CTA link (optional)')),
                ],
              ),
              _field(_secondaryCta, 'Secondary CTA (Request Information)'),
              _field(_metaTitle, 'SEO title'),
              _field(_metaDescription, 'SEO description', maxLines: 2),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show progress'),
                value: _showProgress,
                activeTrackColor: AppColors.gold,
                onChanged: (v) => setState(() => _showProgress = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Featured'),
                value: _featured,
                activeTrackColor: AppColors.gold,
                onChanged: (v) => setState(() => _featured = v),
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
