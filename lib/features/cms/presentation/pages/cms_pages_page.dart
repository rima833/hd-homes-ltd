import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/cms/domain/data/hub_page_cms.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/cms/presentation/widgets/cms_admin_widgets.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';

/// Admin → Website → Pages: CRUD list of CMS pages (`pages` table).
/// Hub slugs (properties, estates, services, …) drive public hero copy.
class CmsPagesPage extends ConsumerStatefulWidget {
  const CmsPagesPage({super.key});

  @override
  ConsumerState<CmsPagesPage> createState() => _CmsPagesPageState();
}

enum _PageScope { all, hubs, legal, drafts }

class _CmsPagesPageState extends ConsumerState<CmsPagesPage> {
  bool _seeding = false;
  final _search = TextEditingController();
  String _query = '';
  _PageScope _scope = _PageScope.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _seedHubs() async {
    setState(() => _seeding = true);
    try {
      final created =
          await ref.read(cmsServiceProvider).ensurePublicHubPages();
      ref.invalidate(cmsPagesProvider);
      ref.invalidate(publishedPageBySlugProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            created > 0
                ? 'Seeded $created hub page(s). Edit heroes below and keep Published on.'
                : 'Hub pages are ready. Edit hero fields and publish to update the public site.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Seed failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(publishedPagesRealtimeProvider);
    final live = ref.watch(publishedPagesRealtimeStatusProvider);
    final pagesAsync = ref.watch(cmsPagesProvider);
    final synced = live || pagesAsync.hasValue;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminSectionHeader(
            title: 'Website pages',
            subtitle: 'Hub heroes and legal pages. Publish updates the public site.',
            action: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LivePill(live: synced),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _seeding ? null : _seedHubs,
                  icon: _seeding
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(LucideIcons.sparkles, size: 16),
                  label: const Text('Seed hubs'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => _openEditor(context, ref, null),
                  icon: const Icon(LucideIcons.plus, size: 16),
                  label: const Text('New page'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: pagesAsync.when(
              loading: () => const AdminLoadingView(),
              error: (err, _) => AdminErrorView(
                message: '$err',
                onRetry: () => ref.invalidate(cmsPagesProvider),
              ),
              data: (pages) {
                if (pages.isEmpty) {
                  return AdminEmptyState(
                    title: 'No pages yet',
                    message:
                        'Seed the public hubs or create a page such as Privacy or Terms.',
                    icon: LucideIcons.fileText,
                    action: FilledButton.icon(
                      onPressed: _seeding ? null : _seedHubs,
                      icon: const Icon(LucideIcons.sparkles, size: 16),
                      label: const Text('Seed hubs'),
                    ),
                  );
                }

                final visible = _visiblePages(pages);
                final hubs = pages
                    .where((p) => kPublicHubSlugs.contains(p.slug))
                    .length;
                final published = pages.where((p) => p.isPublished).length;
                final drafts = pages.length - published;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _CountChip(
                          'Pages',
                          '${pages.length}',
                          selected: _scope == _PageScope.all && _query.isEmpty,
                          onTap: () => setState(() {
                            _scope = _PageScope.all;
                            _query = '';
                            _search.clear();
                          }),
                        ),
                        _CountChip('Published', '$published'),
                        _CountChip(
                          'Hubs',
                          '$hubs',
                          selected: _scope == _PageScope.hubs,
                          onTap: () => setState(() => _scope = _PageScope.hubs),
                        ),
                        _CountChip(
                          'Legal',
                          '${pages.length - hubs}',
                          selected: _scope == _PageScope.legal,
                          onTap: () => setState(() => _scope = _PageScope.legal),
                        ),
                        _CountChip(
                          'Drafts',
                          '$drafts',
                          selected: _scope == _PageScope.drafts,
                          onTap: () =>
                              setState(() => _scope = _PageScope.drafts),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _search,
                            onChanged: (v) => setState(() => _query = v),
                            decoration: const InputDecoration(
                              isDense: true,
                              prefixIcon: Icon(LucideIcons.search, size: 16),
                              hintText: 'Search title, slug, or headline',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final scope in _PageScope.values)
                          ChoiceChip(
                            label: Text(_scopeLabel(scope)),
                            selected: _scope == scope,
                            selectedColor: AppColors.gold.withValues(alpha: 0.2),
                            onSelected: (_) => setState(() => _scope = scope),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: visible.isEmpty
                          ? const Center(
                              child: Text(
                                'No pages match this filter.',
                                style: TextStyle(color: AppColors.slate500),
                              ),
                            )
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                final cols = constraints.maxWidth >= 980 ? 2 : 1;
                                return GridView.builder(
                                  itemCount: visible.length,
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: cols,
                                    mainAxisExtent: 168,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                  ),
                                  itemBuilder: (context, i) =>
                                      _pageCard(context, visible[i]),
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

  List<CmsPageRecord> _visiblePages(List<CmsPageRecord> pages) {
    final q = _query.trim().toLowerCase();
    final list = pages.where((page) {
      final hub = kPublicHubSlugs.contains(page.slug);
      final matchesScope = switch (_scope) {
        _PageScope.all => true,
        _PageScope.hubs => hub,
        _PageScope.legal => !hub,
        _PageScope.drafts => !page.isPublished,
      };
      if (!matchesScope) return false;
      if (q.isEmpty) return true;
      final hero = _heroLine(page).toLowerCase();
      return page.title.toLowerCase().contains(q) ||
          page.slug.toLowerCase().contains(q) ||
          hero.contains(q);
    }).toList();
    list.sort((a, b) {
      final hubA = kPublicHubSlugs.contains(a.slug);
      final hubB = kPublicHubSlugs.contains(b.slug);
      if (hubA != hubB) return hubA ? -1 : 1;
      return a.title.compareTo(b.title);
    });
    return list;
  }

  String _scopeLabel(_PageScope scope) => switch (scope) {
        _PageScope.all => 'All',
        _PageScope.hubs => 'Hubs',
        _PageScope.legal => 'Legal',
        _PageScope.drafts => 'Drafts',
      };

  String _heroLine(CmsPageRecord page) {
    final headline = '${page.content['heroHeadline'] ?? page.content['headline'] ?? ''}'
        .trim();
    if (headline.isNotEmpty) return headline;
    final meta = page.metaDescription?.trim() ?? '';
    return meta;
  }

  String _publicPath(CmsPageRecord page) {
    if (kPublicHubSlugs.contains(page.slug)) return '/${page.slug}';
    return RoutePaths.cmsPagePath(page.slug);
  }

  Widget _pageCard(BuildContext context, CmsPageRecord page) {
    final hub = kPublicHubSlugs.contains(page.slug);
    final hero = _heroLine(page);
    final path = _publicPath(page);
    return AdminCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  page.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              AdminStatusPill(
                label: hub ? 'Hub' : 'Page',
                color: hub ? AppColors.info : AppColors.slate500,
              ),
              const SizedBox(width: 6),
              AdminStatusPill(
                label: page.isPublished ? 'Published' : 'Draft',
                color: page.isPublished ? AppColors.success : AppColors.warning,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            path,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            hero.isEmpty ? 'No hero headline yet' : hero,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.slate400,
                ),
          ),
          const Spacer(),
          Row(
            children: [
              if (page.updatedAt != null)
                Expanded(
                  child: Text(
                    DateFormat.yMMMd().format(page.updatedAt!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.slate500,
                        ),
                  ),
                )
              else
                const Spacer(),
              Switch(
                value: page.isPublished,
                activeTrackColor: AppColors.gold,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (v) => _setPublished(page, v),
              ),
              IconButton(
                tooltip: 'Edit',
                visualDensity: VisualDensity.compact,
                onPressed: () => _openEditor(context, ref, page),
                icon: const Icon(LucideIcons.pencil, size: 16),
              ),
              IconButton(
                tooltip: 'Open public page',
                visualDensity: VisualDensity.compact,
                onPressed: page.isPublished ? () => context.go(path) : null,
                icon: const Icon(LucideIcons.externalLink, size: 16),
              ),
              IconButton(
                tooltip: 'Delete',
                visualDensity: VisualDensity.compact,
                onPressed: () => _confirmDelete(page),
                icon: const Icon(
                  LucideIcons.trash2,
                  size: 16,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _setPublished(CmsPageRecord page, bool published) async {
    try {
      await ref
          .read(cmsServiceProvider)
          .setPageStatus(page.id, isPublished: published);
      ref.invalidate(cmsPagesProvider);
      ref.invalidate(publishedPageBySlugProvider);
      ref.read(publishedPagesTickProvider.notifier).state++;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update publish state: $e')),
      );
    }
  }

  Future<void> _confirmDelete(CmsPageRecord page) async {
    final hub = kPublicHubSlugs.contains(page.slug);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(hub ? 'Delete hub page?' : 'Delete page?'),
        content: Text(
          hub
              ? '“${page.title}” is a public hub. Deleting it removes the hero on /${page.slug}.'
              : 'Remove “${page.title}” from the website?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(cmsServiceProvider).deletePage(page.id);
      ref.invalidate(cmsPagesProvider);
      ref.invalidate(publishedPageBySlugProvider);
      ref.read(publishedPagesTickProvider.notifier).state++;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref,
    CmsPageRecord? page,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _PageEditDialog(page: page),
    );
    ref.invalidate(cmsPagesProvider);
    ref.invalidate(publishedPageBySlugProvider);
  }
}

class _LivePill extends StatelessWidget {
  const _LivePill({required this.live});

  final bool live;

  @override
  Widget build(BuildContext context) {
    return Text(
      live
          ? 'Your latest pages are here.'
          : "We're gathering the latest pages.",
      style: const TextStyle(
        color: AppColors.slate400,
        fontSize: 12,
        height: 1.35,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip(
    this.label,
    this.value, {
    this.selected = false,
    this.onTap,
  });

  final String label;
  final String value;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final border = selected ? AppColors.gold : AppColors.slate400;
    return Material(
      color: selected
          ? AppColors.gold.withValues(alpha: 0.14)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border.withValues(alpha: selected ? 0.7 : 0.25)),
          ),
          child: Text(
            '$label  $value',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _PageEditDialog extends ConsumerStatefulWidget {
  const _PageEditDialog({this.page});

  final CmsPageRecord? page;

  @override
  ConsumerState<_PageEditDialog> createState() => _PageEditDialogState();
}

class _PageEditDialogState extends ConsumerState<_PageEditDialog> {
  late TextEditingController _title;
  late TextEditingController _slug;
  late TextEditingController _heroHeadline;
  late TextEditingController _heroSubheadline;
  late TextEditingController _primaryCta;
  late TextEditingController _mission;
  late TextEditingController _vision;
  late TextEditingController _body;
  late TextEditingController _metaTitle;
  late TextEditingController _metaDescription;
  late TextEditingController _yearsOperating;
  late TextEditingController _philosophy;
  late TextEditingController _introImageUrl;
  late TextEditingController _geographicPresence;
  late TextEditingController _execName;
  late TextEditingController _execTitle;
  late TextEditingController _execMessage;
  late TextEditingController _execVideoUrl;
  late TextEditingController _heroBgImageUrl;
  late TextEditingController _heroBgVideoUrl;
  late List<_IntroTagDraft> _specializations;
  late List<_IntroStatDraft> _achievements;
  late List<_StoryDraftItem> _storyItems;
  late bool _publish;
  bool _saving = false;
  bool _uploadingVideo = false;
  bool _uploadingHeroImage = false;
  bool _uploadingHeroVideo = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.page;
    final c = p?.content ?? const {};
    final intro = c['intro'] is Map
        ? Map<String, dynamic>.from(c['intro'] as Map)
        : const <String, dynamic>{};
    _publish = p?.isPublished ?? true;
    _title = TextEditingController(text: p?.title ?? '');
    _slug = TextEditingController(text: p?.slug ?? '');
    _heroHeadline = TextEditingController(
      text: '${c['heroHeadline'] ?? c['headline'] ?? ''}',
    );
    _heroSubheadline = TextEditingController(
      text: '${c['heroSubheadline'] ?? c['subheadline'] ?? ''}',
    );
    _primaryCta = TextEditingController(
      text: '${c['primaryCtaLabel'] ?? c['ctaLabel'] ?? ''}',
    );
    _mission = TextEditingController(text: '${c['mission'] ?? ''}');
    _vision = TextEditingController(text: '${c['vision'] ?? ''}');
    _body = TextEditingController(
      text: '${intro['description'] ?? c['body'] ?? c['html'] ?? ''}',
    );
    _metaTitle = TextEditingController(text: p?.metaTitle ?? '');
    _metaDescription = TextEditingController(text: p?.metaDescription ?? '');
    _yearsOperating = TextEditingController(
      text: '${intro['yearsOperating'] ?? c['yearsOperating'] ?? '15'}',
    );
    _philosophy = TextEditingController(
      text: '${intro['philosophy'] ?? c['philosophy'] ?? ''}',
    );
    _introImageUrl = TextEditingController(
      text: '${intro['imageUrl'] ?? c['introImageUrl'] ?? ''}',
    );
    final geo = intro['geographicPresence'] ?? c['geographicPresence'];
    _geographicPresence = TextEditingController(
      text: geo is List ? geo.map((e) => '$e').join(', ') : '',
    );
    final executive = c['executiveVideo'] is Map
        ? Map<String, dynamic>.from(c['executiveVideo'] as Map)
        : (c['executive_video'] is Map
            ? Map<String, dynamic>.from(c['executive_video'] as Map)
            : Map<String, dynamic>.from(kDefaultAboutExecutiveVideo));
    _execName = TextEditingController(
      text:
          '${executive['speakerName'] ?? executive['name'] ?? kDefaultAboutExecutiveVideo['speakerName']}',
    );
    _execTitle = TextEditingController(
      text:
          '${executive['speakerTitle'] ?? executive['title'] ?? kDefaultAboutExecutiveVideo['speakerTitle']}',
    );
    _execMessage = TextEditingController(
      text:
          '${executive['message'] ?? kDefaultAboutExecutiveVideo['message']}',
    );
    _execVideoUrl = TextEditingController(
      text: '${executive['videoUrl'] ?? executive['video_url'] ?? ''}',
    );
    final heroNested = c['hero'] is Map
        ? Map<String, dynamic>.from(c['hero'] as Map)
        : const <String, dynamic>{};
    _heroBgImageUrl = TextEditingController(
      text:
          '${c['backgroundImageUrl'] ?? c['background_image_url'] ?? heroNested['backgroundImageUrl'] ?? ''}',
    );
    _heroBgVideoUrl = TextEditingController(
      text:
          '${c['backgroundVideoUrl'] ?? c['background_video_url'] ?? heroNested['backgroundVideoUrl'] ?? ''}',
    );
    final specs = intro['specializations'] ?? c['specializations'];
    _specializations = specs is List
        ? specs
            .map((e) => e is Map
                ? _IntroTagDraft.fromMap(Map<String, dynamic>.from(e))
                : _IntroTagDraft.fromLabel('$e'))
            .toList()
        : <_IntroTagDraft>[];
    final achievements = intro['achievements'] ?? c['achievements'];
    _achievements = achievements is List
        ? achievements
            .map((e) => e is Map
                ? _IntroStatDraft.fromMap(Map<String, dynamic>.from(e))
                : _IntroStatDraft.fromLabel('$e'))
            .toList()
        : <_IntroStatDraft>[];
    final rawStory = c['story'];
    _storyItems = rawStory is List
        ? rawStory
            .whereType<Map>()
            .map((e) => _StoryDraftItem.fromMap(Map<String, dynamic>.from(e)))
            .toList()
        : <_StoryDraftItem>[];
    _slug.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _slug.dispose();
    _heroHeadline.dispose();
    _heroSubheadline.dispose();
    _primaryCta.dispose();
    _mission.dispose();
    _vision.dispose();
    _body.dispose();
    _metaTitle.dispose();
    _metaDescription.dispose();
    _yearsOperating.dispose();
    _philosophy.dispose();
    _introImageUrl.dispose();
    _geographicPresence.dispose();
    _execName.dispose();
    _execTitle.dispose();
    _execMessage.dispose();
    _execVideoUrl.dispose();
    _heroBgImageUrl.dispose();
    _heroBgVideoUrl.dispose();
    for (final item in _specializations) {
      item.dispose();
    }
    for (final item in _achievements) {
      item.dispose();
    }
    for (final item in _storyItems) {
      item.dispose();
    }
    super.dispose();
  }

  String? _uploadSuccess;

  bool get _supportsHeroMedia {
    // Any Website → Pages entry can set a landing hero image/video.
    return _slug.text.trim().isNotEmpty;
  }

  Future<void> _uploadHeroBackground({required bool video}) async {
    setState(() {
      if (video) {
        _uploadingHeroVideo = true;
      } else {
        _uploadingHeroImage = true;
      }
      _error = null;
      _uploadSuccess = null;
    });
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: video
            ? const ['mp4', 'webm']
            : const ['jpg', 'jpeg', 'png', 'webp', 'gif'],
        withData: true,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final name = file.name.toLowerCase();
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        throw StateError('Could not read file bytes. Try another file.');
      }
      final contentType = video
          ? (name.endsWith('.webm') ? 'video/webm' : 'video/mp4')
          : (name.endsWith('.png')
              ? 'image/png'
              : name.endsWith('.webp')
                  ? 'image/webp'
                  : name.endsWith('.gif')
                      ? 'image/gif'
                      : 'image/jpeg');
      final url = await ref.read(cmsServiceProvider).uploadHeroMedia(
            bytes: bytes,
            contentType: contentType,
            pageKey: _slug.text.trim().isEmpty ? 'page' : _slug.text.trim(),
            kind: video ? 'video' : 'image',
          );
      if (!mounted) return;
      setState(() {
        if (video) {
          _heroBgVideoUrl.text = url;
          _uploadSuccess =
              'Hero video uploaded. Click Save to show it on the public site.';
        } else {
          _heroBgImageUrl.text = url;
          _uploadSuccess =
              'Hero image uploaded. Click Save to show it on the public site.';
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = userFacingError(e));
    } finally {
      if (mounted) {
        setState(() {
          _uploadingHeroImage = false;
          _uploadingHeroVideo = false;
        });
      }
    }
  }

  Future<void> _uploadExecutiveVideo() async {
    setState(() {
      _uploadingVideo = true;
      _error = null;
      _uploadSuccess = null;
    });
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['mp4', 'webm'],
        withData: true,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final name = file.name.toLowerCase();
      if (!(name.endsWith('.mp4') || name.endsWith('.webm'))) {
        throw StateError(
          'Please upload an MP4 or WebM file. MOV/QuickTime will not play in browsers.',
        );
      }
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        throw StateError('Could not read video bytes. Try another file.');
      }
      final contentType =
          name.endsWith('.webm') ? 'video/webm' : 'video/mp4';
      final url = await ref.read(cmsServiceProvider).uploadHeroMedia(
            bytes: bytes,
            contentType: contentType,
            pageKey: 'about-executive',
            kind: 'video',
          );
      if (!mounted) return;
      setState(() {
        _execVideoUrl.text = url;
        _uploadSuccess =
            'MP4 uploaded. Click Save, then play it on /about.';
      });
    } catch (e) {
      if (mounted) setState(() => _error = userFacingError(e));
    } finally {
      if (mounted) setState(() => _uploadingVideo = false);
    }
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _slug.text.trim().isEmpty) {
      setState(() => _error = 'Title and slug are required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _uploadSuccess = null;
    });
    try {
      final content =
          Map<String, dynamic>.from(widget.page?.content ?? const {});
      content['heroHeadline'] = _heroHeadline.text.trim();
      content['heroSubheadline'] = _heroSubheadline.text.trim();
      content['primaryCtaLabel'] = _primaryCta.text.trim();
      content['backgroundImageUrl'] = _heroBgImageUrl.text.trim().isEmpty
          ? null
          : _heroBgImageUrl.text.trim();
      content['backgroundVideoUrl'] = _heroBgVideoUrl.text.trim().isEmpty
          ? null
          : _heroBgVideoUrl.text.trim();
      content['mission'] = _mission.text.trim();
      content['vision'] = _vision.text.trim();
      content['body'] = _body.text.trim();
      content['philosophy'] = _philosophy.text.trim();
      content['yearsOperating'] =
          int.tryParse(_yearsOperating.text.trim()) ?? 15;
      content['introImageUrl'] = _introImageUrl.text.trim();
      content['intro'] = {
        'description': _body.text.trim(),
        'yearsOperating': int.tryParse(_yearsOperating.text.trim()) ?? 15,
        'philosophy': _philosophy.text.trim(),
        'imageUrl': _introImageUrl.text.trim(),
        'specializations': [
          for (final item in _specializations)
            if (item.label.text.trim().isNotEmpty) item.toMap(),
        ],
        'geographicPresence': _geographicPresence.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        'achievements': [
          for (final item in _achievements)
            if (item.value.text.trim().isNotEmpty ||
                item.label.text.trim().isNotEmpty)
              item.toMap(),
        ],
      };
      content['story'] = [
        for (final item in _storyItems)
          if (item.year.text.trim().isNotEmpty &&
              item.title.text.trim().isNotEmpty &&
              item.body.text.trim().isNotEmpty)
            item.toMap(),
      ];
      if (_slug.text.trim().toLowerCase() == 'about') {
        final defaults = kDefaultAboutExecutiveVideo;
        content['executiveVideo'] = {
          'speakerName': _execName.text.trim().isEmpty
              ? defaults['speakerName']
              : _execName.text.trim(),
          'speakerTitle': _execTitle.text.trim().isEmpty
              ? defaults['speakerTitle']
              : _execTitle.text.trim(),
          'message': _execMessage.text.trim().isEmpty
              ? defaults['message']
              : _execMessage.text.trim(),
          'videoUrl': _execVideoUrl.text.trim().isEmpty
              ? null
              : _execVideoUrl.text.trim(),
        };
      }
      final saved = await ref.read(cmsServiceProvider).upsertPage(
            id: widget.page?.id,
            title: _title.text.trim(),
            slug: _slug.text.trim(),
            content: content,
            metaTitle:
                _metaTitle.text.trim().isEmpty ? null : _metaTitle.text.trim(),
            metaDescription: _metaDescription.text.trim().isEmpty
                ? null
                : _metaDescription.text.trim(),
          );
      // Honor the Published switch so drafts stay off the public site.
      await ref
          .read(cmsServiceProvider)
          .setPageStatus(saved.id, isPublished: _publish);
      ref.invalidate(cmsPagesProvider);
      ref.invalidate(publishedPageBySlugProvider);
      ref.read(publishedPagesTickProvider.notifier).state++;
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
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 820),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                Text(
                  widget.page == null ? 'New page' : 'Edit page',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'For hubs, use slug properties / estates / services / contact / '
                  'gallery / trust / investment / careers / search / about.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.slate500,
                      ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _slug,
                  decoration: const InputDecoration(
                    labelText: 'Slug',
                    prefixText: '/',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _heroHeadline,
                  decoration: const InputDecoration(
                    labelText: 'Hero headline',
                    hintText: 'Shown on the matching public hub',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _heroSubheadline,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Hero subheadline',
                  ),
                ),
                if (_supportsHeroMedia) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Hero background media',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Optional image or looping muted video behind the hero '
                    '(same pattern as Homepage Hero Manager). Video wins when both are set.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.slate500,
                        ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _heroBgImageUrl,
                    decoration: const InputDecoration(
                      labelText: 'Background image URL',
                      hintText: 'Upload or paste a public image URL',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _uploadingHeroImage
                          ? null
                          : () => _uploadHeroBackground(video: false),
                      icon: _uploadingHeroImage
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.image_outlined, size: 18),
                      label: Text(
                        _uploadingHeroImage
                            ? 'Uploading…'
                            : 'Upload hero image',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _heroBgVideoUrl,
                    decoration: const InputDecoration(
                      labelText: 'Background video URL',
                      hintText: 'MP4 / WebM preferred for browsers',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _uploadingHeroVideo
                          ? null
                          : () => _uploadHeroBackground(video: true),
                      icon: _uploadingHeroVideo
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.videocam_outlined, size: 18),
                      label: Text(
                        _uploadingHeroVideo
                            ? 'Uploading…'
                            : 'Upload hero video',
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _primaryCta,
                  decoration: const InputDecoration(
                    labelText: 'Primary CTA label',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _mission,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Mission',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _vision,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Vision',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _body,
                  minLines: 5,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    labelText: 'Company overview description',
                    alignLabelWithHint: true,
                    hintText: 'Shown under Company overview on the Home page',
                  ),
                ),
                if (_slug.text.trim().toLowerCase() == 'about') ...[
                  const SizedBox(height: 16),
                  Text(
                    'Executive video message',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Shown above About HD Homes on /about. Upload an MP4 or WebM '
                    '(MOV files will not play in Chrome). Then click Save.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.slate500,
                        ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _execName,
                    decoration: const InputDecoration(
                      labelText: 'Speaker name',
                      hintText: 'Managing Director',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _execTitle,
                    decoration: const InputDecoration(
                      labelText: 'Speaker title',
                      hintText: 'Chief Executive Officer',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _execMessage,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Message',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _execVideoUrl,
                    decoration: const InputDecoration(
                      labelText: 'Video URL',
                      hintText: 'Upload below or paste a public video URL',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed:
                            _uploadingVideo ? null : _uploadExecutiveVideo,
                        icon: _uploadingVideo
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(LucideIcons.upload, size: 16),
                        label: Text(
                          _execVideoUrl.text.trim().isEmpty
                              ? 'Upload video'
                              : 'Replace video',
                        ),
                      ),
                      if (_execVideoUrl.text.trim().isNotEmpty)
                        TextButton.icon(
                          onPressed: () => setState(() {
                            _execVideoUrl.clear();
                            _uploadSuccess = null;
                          }),
                          icon: const Icon(LucideIcons.trash2, size: 16),
                          label: const Text('Remove video'),
                        ),
                    ],
                  ),
                  if (_uploadSuccess != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _uploadSuccess!,
                      style: const TextStyle(color: AppColors.success),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    'Company overview details',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _yearsOperating,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Years of operation',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _philosophy,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Philosophy quote',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _introImageUrl,
                    decoration: const InputDecoration(
                      labelText: 'Overview image URL',
                      hintText: 'https://…',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _geographicPresence,
                    decoration: const InputDecoration(
                      labelText: 'Geographic presence',
                      hintText: 'Lagos, Abuja, Port Harcourt, Enugu',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Specializations',
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _specializations.add(_IntroTagDraft.empty());
                          });
                        },
                        icon: const Icon(LucideIcons.plus, size: 14),
                        label: const Text('Add'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            for (final item in _specializations) {
                              item.dispose();
                            }
                            final defaults =
                                kDefaultAboutIntro['specializations'] as List;
                            _specializations = [
                              for (final raw in defaults)
                                if (raw is Map)
                                  _IntroTagDraft.fromMap(
                                    Map<String, dynamic>.from(raw),
                                  ),
                            ];
                          });
                        },
                        child: const Text('Load defaults'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (var i = 0; i < _specializations.length; i++) ...[
                    _IntroTagCard(
                      item: _specializations[i],
                      onRemove: () {
                        setState(() {
                          final removed = _specializations.removeAt(i);
                          removed.dispose();
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Achievement stats',
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _achievements.add(_IntroStatDraft.empty());
                          });
                        },
                        icon: const Icon(LucideIcons.plus, size: 14),
                        label: const Text('Add'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            for (final item in _achievements) {
                              item.dispose();
                            }
                            final defaults =
                                kDefaultAboutIntro['achievements'] as List;
                            _achievements = [
                              for (final raw in defaults)
                                if (raw is Map)
                                  _IntroStatDraft.fromMap(
                                    Map<String, dynamic>.from(raw),
                                  ),
                            ];
                          });
                        },
                        child: const Text('Load defaults'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (var i = 0; i < _achievements.length; i++) ...[
                    _IntroStatCard(
                      item: _achievements[i],
                      onRemove: () {
                        setState(() {
                          final removed = _achievements.removeAt(i);
                          removed.dispose();
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Our story timeline (2011 → 2026)',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _storyItems.add(_StoryDraftItem.empty());
                          });
                        },
                        icon: const Icon(LucideIcons.plus, size: 14),
                        label: const Text('Add year'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            for (final item in _storyItems) {
                              item.dispose();
                            }
                            _storyItems = [
                              for (final chapter in kDefaultAboutStoryChapters)
                                _StoryDraftItem.fromMap(chapter),
                            ];
                          });
                        },
                        child: const Text('Load 2011→2026'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_storyItems.isEmpty)
                    Text(
                      'No story years yet. Add a year or load the 2011→2026 defaults.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.slate500,
                          ),
                    )
                  else
                    ...[
                      for (var i = 0; i < _storyItems.length; i++) ...[
                        _StoryItemCard(
                          item: _storyItems[i],
                          index: i,
                          canMoveUp: i > 0,
                          canMoveDown: i < _storyItems.length - 1,
                          onMoveUp: () {
                            if (i == 0) return;
                            setState(() {
                              final item = _storyItems.removeAt(i);
                              _storyItems.insert(i - 1, item);
                            });
                          },
                          onMoveDown: () {
                            if (i >= _storyItems.length - 1) return;
                            setState(() {
                              final item = _storyItems.removeAt(i);
                              _storyItems.insert(i + 1, item);
                            });
                          },
                          onRemove: () {
                            setState(() {
                              final removed = _storyItems.removeAt(i);
                              removed.dispose();
                            });
                          },
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _metaTitle,
                  decoration: const InputDecoration(labelText: 'Meta title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _metaDescription,
                  minLines: 2,
                  maxLines: 3,
                  decoration:
                      const InputDecoration(labelText: 'Meta description'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: AppColors.error)),
                ],
                const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Published'),
                  Switch(
                    value: _publish,
                    activeTrackColor: AppColors.gold,
                    onChanged: _saving
                        ? null
                        : (v) => setState(() => _publish = v),
                  ),
                  const Spacer(),
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
    );
  }
}

class _IntroTagDraft {
  _IntroTagDraft({
    required this.label,
    required this.iconName,
  });

  factory _IntroTagDraft.fromMap(Map<String, dynamic> map) => _IntroTagDraft(
        label: TextEditingController(text: '${map['label'] ?? map['title'] ?? ''}'),
        iconName: TextEditingController(
          text: '${map['iconName'] ?? map['icon'] ?? 'home'}',
        ),
      );

  factory _IntroTagDraft.fromLabel(String label) => _IntroTagDraft(
        label: TextEditingController(text: label),
        iconName: TextEditingController(text: 'home'),
      );

  factory _IntroTagDraft.empty() => _IntroTagDraft(
        label: TextEditingController(),
        iconName: TextEditingController(text: 'home'),
      );

  final TextEditingController label;
  final TextEditingController iconName;

  Map<String, dynamic> toMap() => {
        'label': label.text.trim(),
        'iconName':
            iconName.text.trim().isEmpty ? 'home' : iconName.text.trim(),
      };

  void dispose() {
    label.dispose();
    iconName.dispose();
  }
}

class _IntroStatDraft {
  _IntroStatDraft({
    required this.value,
    required this.label,
    required this.iconName,
  });

  factory _IntroStatDraft.fromMap(Map<String, dynamic> map) => _IntroStatDraft(
        value: TextEditingController(text: '${map['value'] ?? ''}'),
        label: TextEditingController(text: '${map['label'] ?? map['title'] ?? ''}'),
        iconName: TextEditingController(
          text: '${map['iconName'] ?? map['icon'] ?? 'building'}',
        ),
      );

  factory _IntroStatDraft.fromLabel(String text) {
    final parts = text.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && RegExp(r'[\d+]').hasMatch(parts.first)) {
      return _IntroStatDraft(
        value: TextEditingController(text: parts.first),
        label: TextEditingController(text: parts.skip(1).join(' ')),
        iconName: TextEditingController(text: 'building'),
      );
    }
    return _IntroStatDraft(
      value: TextEditingController(text: text),
      label: TextEditingController(),
      iconName: TextEditingController(text: 'building'),
    );
  }

  factory _IntroStatDraft.empty() => _IntroStatDraft(
        value: TextEditingController(),
        label: TextEditingController(),
        iconName: TextEditingController(text: 'building'),
      );

  final TextEditingController value;
  final TextEditingController label;
  final TextEditingController iconName;

  Map<String, dynamic> toMap() => {
        'value': value.text.trim(),
        'label': label.text.trim(),
        'iconName':
            iconName.text.trim().isEmpty ? 'building' : iconName.text.trim(),
      };

  void dispose() {
    value.dispose();
    label.dispose();
    iconName.dispose();
  }
}

class _IntroTagCard extends StatelessWidget {
  const _IntroTagCard({
    required this.item,
    required this.onRemove,
  });

  final _IntroTagDraft item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: item.label,
              decoration: const InputDecoration(labelText: 'Specialization'),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 140,
            child: TextField(
              controller: item.iconName,
              decoration: const InputDecoration(labelText: 'Icon'),
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(LucideIcons.trash2, size: 16, color: AppColors.error),
          ),
        ],
      ),
    );
  }
}

class _IntroStatCard extends StatelessWidget {
  const _IntroStatCard({
    required this.item,
    required this.onRemove,
  });

  final _IntroStatDraft item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: item.value,
                  decoration: const InputDecoration(labelText: 'Value (e.g. 48+)'),
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(
                  LucideIcons.trash2,
                  size: 16,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: item.label,
            decoration: const InputDecoration(labelText: 'Label'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: item.iconName,
            decoration: const InputDecoration(
              labelText: 'Icon name',
              hintText: 'building / award / users / badge',
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryDraftItem {
  _StoryDraftItem({
    required this.year,
    required this.title,
    required this.summary,
    required this.body,
    required this.imageUrl,
    required this.feature1Title,
    required this.feature1Desc,
    required this.feature1Icon,
    required this.feature2Title,
    required this.feature2Desc,
    required this.feature2Icon,
    required this.feature3Title,
    required this.feature3Desc,
    required this.feature3Icon,
  });

  factory _StoryDraftItem.fromMap(Map<String, dynamic> map) {
    final features = map['features'] is List
        ? (map['features'] as List).whereType<Map>().toList()
        : const <Map>[];
    Map featureAt(int i) =>
        i < features.length ? Map<String, dynamic>.from(features[i]) : const {};
    final f1 = featureAt(0);
    final f2 = featureAt(1);
    final f3 = featureAt(2);
    final legacyHighlights = map['highlights'] is List
        ? (map['highlights'] as List).map((e) => '$e').toList()
        : const <String>[];

    String highlight(int i) =>
        i < legacyHighlights.length ? legacyHighlights[i] : '';

    return _StoryDraftItem(
      year: TextEditingController(text: '${map['year'] ?? ''}'),
      title: TextEditingController(text: '${map['title'] ?? ''}'),
      summary: TextEditingController(text: '${map['summary'] ?? ''}'),
      body: TextEditingController(
        text: '${map['body'] ?? map['description'] ?? ''}',
      ),
      imageUrl: TextEditingController(
        text: '${map['imageUrl'] ?? map['image_url'] ?? ''}',
      ),
      feature1Title: TextEditingController(
        text: '${f1['title'] ?? highlight(0)}',
      ),
      feature1Desc: TextEditingController(
        text: '${f1['description'] ?? f1['body'] ?? ''}',
      ),
      feature1Icon: TextEditingController(
        text: '${f1['iconName'] ?? f1['icon'] ?? 'building'}',
      ),
      feature2Title: TextEditingController(
        text: '${f2['title'] ?? highlight(1)}',
      ),
      feature2Desc: TextEditingController(
        text: '${f2['description'] ?? f2['body'] ?? ''}',
      ),
      feature2Icon: TextEditingController(
        text: '${f2['iconName'] ?? f2['icon'] ?? 'leaf'}',
      ),
      feature3Title: TextEditingController(
        text: '${f3['title'] ?? highlight(2)}',
      ),
      feature3Desc: TextEditingController(
        text: '${f3['description'] ?? f3['body'] ?? ''}',
      ),
      feature3Icon: TextEditingController(
        text: '${f3['iconName'] ?? f3['icon'] ?? 'cpu'}',
      ),
    );
  }

  factory _StoryDraftItem.empty() => _StoryDraftItem(
        year: TextEditingController(),
        title: TextEditingController(),
        summary: TextEditingController(),
        body: TextEditingController(),
        imageUrl: TextEditingController(),
        feature1Title: TextEditingController(),
        feature1Desc: TextEditingController(),
        feature1Icon: TextEditingController(text: 'building'),
        feature2Title: TextEditingController(),
        feature2Desc: TextEditingController(),
        feature2Icon: TextEditingController(text: 'leaf'),
        feature3Title: TextEditingController(),
        feature3Desc: TextEditingController(),
        feature3Icon: TextEditingController(text: 'cpu'),
      );

  final TextEditingController year;
  final TextEditingController title;
  final TextEditingController summary;
  final TextEditingController body;
  final TextEditingController imageUrl;
  final TextEditingController feature1Title;
  final TextEditingController feature1Desc;
  final TextEditingController feature1Icon;
  final TextEditingController feature2Title;
  final TextEditingController feature2Desc;
  final TextEditingController feature2Icon;
  final TextEditingController feature3Title;
  final TextEditingController feature3Desc;
  final TextEditingController feature3Icon;

  Map<String, dynamic> toMap() {
    final features = <Map<String, String>>[];
    void addFeature(
      TextEditingController titleCtrl,
      TextEditingController descCtrl,
      TextEditingController iconCtrl,
    ) {
      final t = titleCtrl.text.trim();
      if (t.isEmpty) return;
      features.add({
        'title': t,
        'description': descCtrl.text.trim(),
        'iconName': iconCtrl.text.trim().isEmpty ? 'star' : iconCtrl.text.trim(),
      });
    }

    addFeature(feature1Title, feature1Desc, feature1Icon);
    addFeature(feature2Title, feature2Desc, feature2Icon);
    addFeature(feature3Title, feature3Desc, feature3Icon);

    return {
      'year': year.text.trim(),
      'title': title.text.trim(),
      'summary': summary.text.trim(),
      'body': body.text.trim(),
      'imageUrl': imageUrl.text.trim(),
      'features': features,
      'highlights': [for (final f in features) f['title']],
    };
  }

  void dispose() {
    year.dispose();
    title.dispose();
    summary.dispose();
    body.dispose();
    imageUrl.dispose();
    feature1Title.dispose();
    feature1Desc.dispose();
    feature1Icon.dispose();
    feature2Title.dispose();
    feature2Desc.dispose();
    feature2Icon.dispose();
    feature3Title.dispose();
    feature3Desc.dispose();
    feature3Icon.dispose();
  }
}

class _StoryItemCard extends StatelessWidget {
  const _StoryItemCard({
    required this.item,
    required this.index,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
  });

  final _StoryDraftItem item;
  final int index;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Year ${index + 1}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              IconButton(
                onPressed: canMoveUp ? onMoveUp : null,
                icon: const Icon(LucideIcons.arrowUp, size: 16),
              ),
              IconButton(
                onPressed: canMoveDown ? onMoveDown : null,
                icon: const Icon(LucideIcons.arrowDown, size: 16),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(
                  LucideIcons.trash2,
                  size: 16,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: item.year,
            decoration: const InputDecoration(labelText: 'Year (e.g. 2011)'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: item.title,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: item.summary,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Left timeline summary',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: item.body,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Main story description',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: item.imageUrl,
            decoration: const InputDecoration(
              labelText: 'Detail image URL',
              hintText: 'https://…',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Feature chips (up to 3)',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          _FeatureDraftFields(
            index: 1,
            title: item.feature1Title,
            description: item.feature1Desc,
            iconName: item.feature1Icon,
          ),
          const SizedBox(height: 8),
          _FeatureDraftFields(
            index: 2,
            title: item.feature2Title,
            description: item.feature2Desc,
            iconName: item.feature2Icon,
          ),
          const SizedBox(height: 8),
          _FeatureDraftFields(
            index: 3,
            title: item.feature3Title,
            description: item.feature3Desc,
            iconName: item.feature3Icon,
          ),
        ],
      ),
    );
  }
}

class _FeatureDraftFields extends StatelessWidget {
  const _FeatureDraftFields({
    required this.index,
    required this.title,
    required this.description,
    required this.iconName,
  });

  final int index;
  final TextEditingController title;
  final TextEditingController description;
  final TextEditingController iconName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.slate100),
      ),
      child: Column(
        children: [
          TextField(
            controller: title,
            decoration: InputDecoration(labelText: 'Feature $index title'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: description,
            minLines: 1,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Feature $index description',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: iconName,
            decoration: const InputDecoration(
              labelText: 'Icon name',
              hintText: 'building / leaf / cpu / home / users',
            ),
          ),
        ],
      ),
    );
  }
}
