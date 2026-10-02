import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/cms/presentation/widgets/cms_admin_widgets.dart';
import 'package:hdhomesproject/features/services/data/providers/services_cms_admin_provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

class CmsServicesPage extends ConsumerStatefulWidget {
  const CmsServicesPage({super.key});

  @override
  ConsumerState<CmsServicesPage> createState() => _CmsServicesPageState();
}

class _CmsServicesPageState extends ConsumerState<CmsServicesPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _invalidate() {
    bumpServicesCmsTickFromWidget(ref);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(servicesCmsRealtimeProvider);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminSectionHeader(
            title: 'Website Services CMS',
            subtitle:
                'Manage service categories, catalog entries, and case studies shown on /services.',
          ),
          const SizedBox(height: 8),
          TabBar(
            controller: _tabs,
            isScrollable: true,
            labelColor: AppColors.gold,
            unselectedLabelColor: AppColors.slate500,
            indicatorColor: AppColors.gold,
            tabs: const [
              Tab(text: 'Categories'),
              Tab(text: 'Catalog'),
              Tab(text: 'Case Studies'),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _CategoriesTab(onChanged: _invalidate),
                _CatalogTab(onChanged: _invalidate),
                _CaseStudiesTab(onChanged: _invalidate),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.published});

  final bool published;

  @override
  Widget build(BuildContext context) {
    final color = published ? AppColors.success : AppColors.slate500;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        published ? 'Published' : 'Draft',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CategoriesTab extends ConsumerWidget {
  const _CategoriesTab({required this.onChanged});

  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(cmsWebsiteServiceCategoriesProvider);
    return _AdminList<CmsWebsiteServiceCategory>(
      async: async,
      addLabel: 'Add category',
      emptyTitle: 'No service categories',
      emptyMessage: 'Add categories used to group the public service catalog.',
      emptyIcon: LucideIcons.layoutGrid,
      onAdd: () => _openCategory(context, ref, null),
      itemBuilder: (category) => _ServiceRow(
        title: category.name,
        subtitle: category.slug,
        published: category.status == 'active',
        onPublishedChanged: (value) async {
          await ref
              .read(cmsServiceProvider)
              .setWebsiteServiceCategoryStatus(
                category.id,
                value ? 'active' : 'draft',
              );
          onChanged();
        },
        onEdit: () => _openCategory(context, ref, category),
        onDelete: () async {
          await ref
              .read(cmsServiceProvider)
              .deleteWebsiteServiceCategory(category.id);
          onChanged();
        },
      ),
      onRetry: () => ref.invalidate(cmsWebsiteServiceCategoriesProvider),
    );
  }

  Future<void> _openCategory(
    BuildContext context,
    WidgetRef ref,
    CmsWebsiteServiceCategory? category,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _CategoryDialog(category: category),
    );
    onChanged();
  }
}

class _CatalogTab extends ConsumerWidget {
  const _CatalogTab({required this.onChanged});

  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(cmsWebsiteServiceItemsProvider);
    final categories =
        ref.watch(cmsWebsiteServiceCategoriesProvider).valueOrNull ?? const [];
    return _AdminList<CmsWebsiteServiceItem>(
      async: async,
      addLabel: 'Add service',
      emptyTitle: 'No catalog services',
      emptyMessage: 'Add services to replace the built-in public catalog.',
      emptyIcon: LucideIcons.briefcase,
      onAdd: () => _openItem(context, null, categories),
      itemBuilder: (item) => _ServiceRow(
        title: item.name,
        subtitle: '${item.categorySlug} · ${item.slug}',
        published: item.status == 'active',
        featured: item.isFeatured,
        onPublishedChanged: (value) async {
          await ref
              .read(cmsServiceProvider)
              .setWebsiteServiceItemStatus(item.id, value ? 'active' : 'draft');
          onChanged();
        },
        onFeaturedChanged: (value) async {
          await ref
              .read(cmsServiceProvider)
              .setWebsiteServiceItemFeatured(item.id, value);
          onChanged();
        },
        onEdit: () => _openItem(context, item, categories),
        onDelete: () async {
          await ref.read(cmsServiceProvider).deleteWebsiteServiceItem(item.id);
          onChanged();
        },
      ),
      onRetry: () => ref.invalidate(cmsWebsiteServiceItemsProvider),
    );
  }

  Future<void> _openItem(
    BuildContext context,
    CmsWebsiteServiceItem? item,
    List<CmsWebsiteServiceCategory> categories,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _ItemDialog(item: item, categories: categories),
    );
    onChanged();
  }
}

class _CaseStudiesTab extends ConsumerWidget {
  const _CaseStudiesTab({required this.onChanged});

  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(cmsWebsiteServiceCaseStudiesProvider);
    return _AdminList<CmsWebsiteServiceCaseStudy>(
      async: async,
      addLabel: 'Add case study',
      emptyTitle: 'No case studies',
      emptyMessage: 'Add outcomes and client stories for the services page.',
      emptyIcon: LucideIcons.fileCheck,
      onAdd: () => _open(context, null),
      itemBuilder: (study) => _ServiceRow(
        title: study.client,
        subtitle: '${study.serviceLabel} · ${study.serviceSlug}',
        published: study.status == 'active',
        onPublishedChanged: (value) async {
          await ref
              .read(cmsServiceProvider)
              .setWebsiteServiceCaseStudyStatus(
                study.id,
                value ? 'active' : 'draft',
              );
          onChanged();
        },
        onEdit: () => _open(context, study),
        onDelete: () async {
          await ref
              .read(cmsServiceProvider)
              .deleteWebsiteServiceCaseStudy(study.id);
          onChanged();
        },
      ),
      onRetry: () => ref.invalidate(cmsWebsiteServiceCaseStudiesProvider),
    );
  }

  Future<void> _open(
    BuildContext context,
    CmsWebsiteServiceCaseStudy? study,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _CaseStudyDialog(study: study),
    );
    onChanged();
  }
}

class _AdminList<T> extends StatelessWidget {
  const _AdminList({
    required this.async,
    required this.addLabel,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.emptyIcon,
    required this.onAdd,
    required this.itemBuilder,
    required this.onRetry,
  });

  final AsyncValue<List<T>> async;
  final String addLabel;
  final String emptyTitle;
  final String emptyMessage;
  final IconData emptyIcon;
  final VoidCallback onAdd;
  final Widget Function(T item) itemBuilder;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(LucideIcons.plus, size: 16),
            label: Text(addLabel),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: async.when(
            loading: () => const AdminLoadingView(),
            error: (error, _) =>
                AdminErrorView(message: '$error', onRetry: onRetry),
            data: (items) {
              if (items.isEmpty) {
                return AdminEmptyState(
                  title: emptyTitle,
                  message: emptyMessage,
                  icon: emptyIcon,
                  action: FilledButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(LucideIcons.plus, size: 16),
                    label: Text(addLabel),
                  ),
                );
              }
              return ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, index) => itemBuilder(items[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    required this.title,
    required this.subtitle,
    required this.published,
    required this.onPublishedChanged,
    required this.onEdit,
    required this.onDelete,
    this.featured,
    this.onFeaturedChanged,
  });

  final String title;
  final String subtitle;
  final bool published;
  final bool? featured;
  final ValueChanged<bool> onPublishedChanged;
  final ValueChanged<bool>? onFeaturedChanged;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.slate500),
                ),
                const SizedBox(height: 6),
                _StatusChip(published: published),
              ],
            ),
          ),
          if (featured != null)
            Tooltip(
              message: 'Featured',
              child: Switch(
                value: featured!,
                activeTrackColor: AppColors.gold,
                onChanged: onFeaturedChanged,
              ),
            ),
          Tooltip(
            message: published ? 'Published' : 'Draft',
            child: Switch(
              value: published,
              activeTrackColor: AppColors.gold,
              onChanged: onPublishedChanged,
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(LucideIcons.pencil, size: 18),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(
              LucideIcons.trash2,
              size: 18,
              color: AppColors.error,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryDialog extends ConsumerStatefulWidget {
  const _CategoryDialog({this.category});

  final CmsWebsiteServiceCategory? category;

  @override
  ConsumerState<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends ConsumerState<_CategoryDialog> {
  late final TextEditingController _name;
  late final TextEditingController _slug;
  late final TextEditingController _description;
  late final TextEditingController _icon;
  late final TextEditingController _sort;
  late bool _published;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final item = widget.category;
    _name = TextEditingController(text: item?.name ?? '');
    _slug = TextEditingController(text: item?.slug ?? '');
    _description = TextEditingController(text: item?.description ?? '');
    _icon = TextEditingController(text: item?.iconName ?? 'briefcase');
    _sort = TextEditingController(text: '${item?.sortOrder ?? 0}');
    _published = (item?.status ?? 'active') == 'active';
  }

  @override
  void dispose() {
    for (final controller in [_name, _slug, _description, _icon, _sort]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _slug.text.trim().isEmpty) {
      setState(() => _error = 'Name and slug are required');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(cmsServiceProvider)
          .upsertWebsiteServiceCategory(
            id: widget.category?.id,
            name: _name.text.trim(),
            slug: _slug.text.trim(),
            description: _description.text.trim(),
            iconName: _icon.text.trim(),
            sortOrder: int.tryParse(_sort.text.trim()) ?? 0,
            status: _published ? 'active' : 'draft',
          );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => _EditDialog(
    title: widget.category == null ? 'Add category' : 'Edit category',
    saving: _saving,
    error: _error,
    onSave: _save,
    fields: [
      _field(_name, 'Name'),
      _field(_slug, 'Slug'),
      _field(_description, 'Description', maxLines: 3),
      _field(_icon, 'Icon name'),
      _field(_sort, 'Sort order', number: true),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Published'),
        value: _published,
        onChanged: (value) => setState(() => _published = value),
      ),
    ],
  );
}

class _ItemDialog extends ConsumerStatefulWidget {
  const _ItemDialog({this.item, required this.categories});

  final CmsWebsiteServiceItem? item;
  final List<CmsWebsiteServiceCategory> categories;

  @override
  ConsumerState<_ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends ConsumerState<_ItemDialog> {
  late final TextEditingController _name;
  late final TextEditingController _slug;
  late final TextEditingController _description;
  late final TextEditingController _icon;
  late final TextEditingController _benefits;
  late final TextEditingController _badges;
  late final TextEditingController _sort;
  late final TextEditingController _ctaLabel;
  late final TextEditingController _ctaHref;
  late String _categorySlug;
  late bool _featured;
  late bool _published;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _name = TextEditingController(text: item?.name ?? '');
    _slug = TextEditingController(text: item?.slug ?? '');
    _description = TextEditingController(text: item?.shortDescription ?? '');
    _icon = TextEditingController(text: item?.iconName ?? 'briefcase');
    _benefits = TextEditingController(text: item?.keyBenefits.join(', ') ?? '');
    _badges = TextEditingController(text: item?.badges.join(', ') ?? '');
    _sort = TextEditingController(text: '${item?.sortOrder ?? 0}');
    _ctaLabel = TextEditingController(text: item?.ctaLabel ?? 'Learn More');
    _ctaHref = TextEditingController(text: item?.ctaHref ?? '');
    _categorySlug =
        item?.categorySlug ??
        (widget.categories.isEmpty ? '' : widget.categories.first.slug);
    _featured = item?.isFeatured ?? false;
    _published = (item?.status ?? 'active') == 'active';
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _slug,
      _description,
      _icon,
      _benefits,
      _badges,
      _sort,
      _ctaLabel,
      _ctaHref,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  List<String> _csv(String value) => value
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();

  Future<void> _save() async {
    if (_name.text.trim().isEmpty ||
        _slug.text.trim().isEmpty ||
        _categorySlug.isEmpty) {
      setState(() => _error = 'Name, slug, and category are required');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(cmsServiceProvider)
          .upsertWebsiteServiceItem(
            id: widget.item?.id,
            name: _name.text.trim(),
            slug: _slug.text.trim(),
            categorySlug: _categorySlug,
            shortDescription: _description.text.trim(),
            iconName: _icon.text.trim(),
            keyBenefits: _csv(_benefits.text),
            badges: _csv(_badges.text),
            isFeatured: _featured,
            sortOrder: int.tryParse(_sort.text.trim()) ?? 0,
            status: _published ? 'active' : 'draft',
            ctaLabel: _ctaLabel.text.trim().isEmpty
                ? 'Learn More'
                : _ctaLabel.text.trim(),
            ctaHref: _ctaHref.text.trim().isEmpty
                ? null
                : _ctaHref.text.trim(),
          );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final slugs = {
      ...widget.categories.map((category) => category.slug),
      if (_categorySlug.isNotEmpty) _categorySlug,
    }.toList();
    return _EditDialog(
      title: widget.item == null ? 'Add service' : 'Edit service',
      saving: _saving,
      error: _error,
      onSave: _save,
      fields: [
        _field(_name, 'Name'),
        _field(_slug, 'Slug'),
        DropdownButtonFormField<String>(
          initialValue: _categorySlug.isEmpty ? null : _categorySlug,
          decoration: const InputDecoration(
            labelText: 'Category',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final slug in slugs)
              DropdownMenuItem(value: slug, child: Text(slug)),
          ],
          onChanged: (value) => setState(() => _categorySlug = value ?? ''),
        ),
        const SizedBox(height: 10),
        _field(_description, 'Short description', maxLines: 3),
        _field(_icon, 'Icon name'),
        _field(_benefits, 'Key benefits (comma-separated)', maxLines: 2),
        _field(_badges, 'Badges (featured, popular, new)'),
        _field(_ctaLabel, 'Learn More button label'),
        _field(
          _ctaHref,
          'Learn More link (optional)',
          maxLines: 1,
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            'Leave link empty to open /services/{slug}. '
            'Or set an internal path (/contact, /book-consultation) '
            'or full URL (https://…).',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.slate500,
                ),
          ),
        ),
        _field(_sort, 'Sort order', number: true),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Featured'),
          value: _featured,
          onChanged: (value) => setState(() => _featured = value),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Published'),
          value: _published,
          onChanged: (value) => setState(() => _published = value),
        ),
      ],
    );
  }
}

class _CaseStudyDialog extends ConsumerStatefulWidget {
  const _CaseStudyDialog({this.study});

  final CmsWebsiteServiceCaseStudy? study;

  @override
  ConsumerState<_CaseStudyDialog> createState() => _CaseStudyDialogState();
}

class _CaseStudyDialogState extends ConsumerState<_CaseStudyDialog> {
  late final TextEditingController _client;
  late final TextEditingController _label;
  late final TextEditingController _challenge;
  late final TextEditingController _solution;
  late final TextEditingController _results;
  late final TextEditingController _slug;
  late final TextEditingController _sort;
  late bool _featured;
  late bool _published;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final study = widget.study;
    _client = TextEditingController(text: study?.client ?? '');
    _label = TextEditingController(text: study?.serviceLabel ?? '');
    _challenge = TextEditingController(text: study?.challenge ?? '');
    _solution = TextEditingController(text: study?.solution ?? '');
    _results = TextEditingController(text: study?.results ?? '');
    _slug = TextEditingController(text: study?.serviceSlug ?? '');
    _sort = TextEditingController(text: '${study?.sortOrder ?? 0}');
    _featured = study?.isFeatured ?? false;
    _published = (study?.status ?? 'active') == 'active';
  }

  @override
  void dispose() {
    for (final controller in [
      _client,
      _label,
      _challenge,
      _solution,
      _results,
      _slug,
      _sort,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_client.text.trim().isEmpty) {
      setState(() => _error = 'Client is required');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(cmsServiceProvider)
          .upsertWebsiteServiceCaseStudy(
            id: widget.study?.id,
            client: _client.text.trim(),
            serviceLabel: _label.text.trim(),
            challenge: _challenge.text.trim(),
            solution: _solution.text.trim(),
            results: _results.text.trim(),
            serviceSlug: _slug.text.trim(),
            isFeatured: _featured,
            sortOrder: int.tryParse(_sort.text.trim()) ?? 0,
            status: _published ? 'active' : 'draft',
          );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => _EditDialog(
    title: widget.study == null ? 'Add case study' : 'Edit case study',
    saving: _saving,
    error: _error,
    onSave: _save,
    fields: [
      _field(_client, 'Client'),
      _field(_label, 'Service label'),
      _field(_challenge, 'Challenge', maxLines: 3),
      _field(_solution, 'Solution', maxLines: 3),
      _field(_results, 'Results', maxLines: 3),
      _field(_slug, 'Service slug'),
      _field(_sort, 'Sort order', number: true),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Featured'),
        value: _featured,
        onChanged: (value) => setState(() => _featured = value),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Published'),
        value: _published,
        onChanged: (value) => setState(() => _published = value),
      ),
    ],
  );
}

class _EditDialog extends StatelessWidget {
  const _EditDialog({
    required this.title,
    required this.fields,
    required this.saving,
    required this.onSave,
    this.error,
  });

  final String title;
  final List<Widget> fields;
  final bool saving;
  final VoidCallback onSave;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...fields,
              if (error != null)
                Text(error!, style: const TextStyle(color: AppColors.error)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: saving ? null : onSave,
          child: Text(saving ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }
}

Widget _field(
  TextEditingController controller,
  String label, {
  int maxLines = 1,
  bool number = false,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: number ? TextInputType.number : null,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    ),
  );
}
