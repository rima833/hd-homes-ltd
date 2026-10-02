import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/cms/domain/data/homepage_section_defaults.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/cms/presentation/widgets/cms_admin_widgets.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/features/home/data/providers/home_content_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Public homepage order, including blocks that render inside another band.
const _deskOrder = <String>[
  'homepage_hero',
  'homepage_search',
  'homepage_about',
  'homepage_why_choose',
  'homepage_executive_welcome',
  'homepage_featured_estates',
  'homepage_featured_properties',
  'homepage_testimonials',
  'homepage_partners',
  'homepage_trust',
  'homepage_awards',
  'homepage_content_hub',
  'homepage_blog',
  'homepage_faq',
  'homepage_cta',
  'homepage_stats',
  'homepage_closing',
];

/// Admin → Website → Homepage. Visibility and the copy edited here
/// publish on the public homepage. Other blocks open their own desks.
class CmsHomepagePage extends ConsumerStatefulWidget {
  const CmsHomepagePage({super.key});

  @override
  ConsumerState<CmsHomepagePage> createState() => _CmsHomepagePageState();
}

class _CmsHomepagePageState extends ConsumerState<CmsHomepagePage> {
  final Map<String, bool> _pendingVisible = {};

  @override
  Widget build(BuildContext context) {
    ref.watch(homepageContentRealtimeProvider);
    final sectionsAsync = ref.watch(cmsHomepageSectionsProvider);
    final counts = _LiveCounts(
      hero: ref.watch(publishedHomepageHeroProvider).valueOrNull?.headline ?? '',
      estates: _count(ref.watch(publishedFeaturedEstatesProvider)),
      properties: _count(ref.watch(publishedFeaturedPropertiesProvider)),
      testimonials: _count(ref.watch(publishedTestimonialsProvider)),
      partners: _count(ref.watch(publishedPartnersHomeProvider)),
      awards: _count(ref.watch(publishedAwardsProvider)),
      stats: _count(ref.watch(publishedCompanyStatsHomeProvider)),
      faqs: _count(ref.watch(publishedFaqsProvider)),
      posts: _count(ref.watch(publishedBlogsProvider)),
    );

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSectionHeader(
            title: 'Homepage',
            subtitle:
                'Show or hide each block on the public homepage. '
                'About, Why Choose, the leadership quote, and the closing call to action are edited here. '
                'Hero, listings, testimonials, partners, awards, stats, blog, and FAQ open their own desks.',
            action: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _openPublic,
                  icon: const Icon(LucideIcons.externalLink, size: 16),
                  label: const Text('View homepage'),
                ),
                OutlinedButton.icon(
                  onPressed: _syncSections,
                  icon: const Icon(LucideIcons.refreshCw, size: 16),
                  label: const Text('Add missing sections'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: sectionsAsync.when(
              skipLoadingOnReload: true,
              loading: () => const AdminLoadingView(),
              error: (err, _) => AdminErrorView(
                message: userFacingError(err, fallback: 'Unable to load homepage sections.'),
                onRetry: () => ref.invalidate(cmsHomepageSectionsProvider),
              ),
              data: (sections) {
                final byKey = {for (final section in sections) section.sectionKey: section};
                final live = [
                  for (final key in _deskOrder)
                    if (byKey[key] != null && kLiveHomepageSectionKeys.contains(key))
                      byKey[key]!,
                ];
                if (live.isEmpty) {
                  return AdminEmptyState(
                    title: 'No homepage sections yet',
                    message: 'Add the homepage blocks so you can show, hide, and edit them.',
                    icon: LucideIcons.layoutTemplate,
                    action: FilledButton.icon(
                      onPressed: _syncSections,
                      icon: const Icon(LucideIcons.sparkles, size: 16),
                      label: const Text('Add homepage sections'),
                    ),
                  );
                }
                final settled = [
                  for (final section in live)
                    if (_pendingVisible[section.id] == section.isVisible) section.id,
                ];
                if (settled.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    setState(() {
                      for (final id in settled) {
                        _pendingVisible.remove(id);
                      }
                    });
                  });
                }
                final visibleCount = live.where((section) {
                  return _pendingVisible[section.id] ?? section.isVisible;
                }).length;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (sectionsAsync.isLoading)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: AdminKpi(
                            label: 'On the homepage',
                            value: '$visibleCount',
                            icon: LucideIcons.eye,
                            accent: AppColors.success,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AdminKpi(
                            label: 'Hidden',
                            value: '${live.length - visibleCount}',
                            icon: LucideIcons.eyeOff,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AdminKpi(
                            label: 'Blocks',
                            value: '${live.length}',
                            icon: LucideIcons.layoutTemplate,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView(
                        children: [
                          for (var index = 0; index < live.length; index++) ...[
                            if (index == 0 ||
                                _groupFor(live[index].sectionKey) !=
                                    _groupFor(live[index - 1].sectionKey))
                              Padding(
                                padding: EdgeInsets.only(top: index == 0 ? 0 : 16, bottom: 8),
                                child: Text(
                                  _groupFor(live[index].sectionKey),
                                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                        color: AppColors.gold,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              )
                            else
                              const SizedBox(height: 10),
                            _SectionTile(
                              index: index + 1,
                              section: live[index],
                              shown: _pendingVisible[live[index].id] ?? live[index].isVisible,
                              preview: _preview(live[index], counts),
                              onToggleVisible: (visible) => _setVisible(live[index], visible),
                              onEdit: () => _openEditDialog(live[index]),
                              onOpen: () {
                                final path = _editorPath(live[index].sectionKey);
                                if (path != null) context.go(path);
                              },
                            ),
                          ],
                        ],
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

  int? _count<T>(AsyncValue<List<T>> async) => async.valueOrNull?.length;

  Future<void> _openPublic() async {
    await launchUrl(Uri.base.replace(path: '/', query: ''), mode: LaunchMode.externalApplication);
  }

  Future<void> _setVisible(CmsSectionRecord section, bool visible) async {
    setState(() => _pendingVisible[section.id] = visible);
    try {
      await ref.read(cmsServiceProvider).updateSectionVisibility(section.id, visible);
      ref.invalidate(cmsHomepageSectionsProvider);
      ref.invalidate(publishedHomepageSectionsProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() => _pendingVisible.remove(section.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingError(e, fallback: 'Could not update visibility.'))),
      );
    }
  }

  Future<void> _syncSections() async {
    try {
      await ref.read(cmsServiceProvider).ensureHomepageSections();
      ref.invalidate(cmsHomepageSectionsProvider);
      ref.invalidate(publishedHomepageSectionsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing homepage sections were added.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingError(e, fallback: 'Could not add homepage sections.'))),
      );
    }
  }

  Future<void> _openEditDialog(CmsSectionRecord section) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _SectionEditDialog(section: section),
    );
    ref.invalidate(cmsHomepageSectionsProvider);
    ref.invalidate(publishedHomepageSectionsProvider);
  }
}

class _LiveCounts {
  const _LiveCounts({
    required this.hero,
    required this.estates,
    required this.properties,
    required this.testimonials,
    required this.partners,
    required this.awards,
    required this.stats,
    required this.faqs,
    required this.posts,
  });

  final String hero;
  final int? estates;
  final int? properties;
  final int? testimonials;
  final int? partners;
  final int? awards;
  final int? stats;
  final int? faqs;
  final int? posts;
}

String _countLine(int? count, String singular, String plural) {
  if (count == null) return 'Loading published items…';
  if (count == 0) return 'Nothing published yet.';
  if (count == 1) return '1 $singular published.';
  return '$count $plural published.';
}

String _preview(CmsSectionRecord section, _LiveCounts counts) {
  String text(String key) => '${section.content[key] ?? ''}'.trim();
  final items = section.content['items'];
  final itemCount = items is List ? items.length : 0;

  return switch (section.sectionKey) {
    'homepage_hero' => counts.hero.trim().isEmpty
        ? 'No published hero headline yet.'
        : counts.hero.trim(),
    'homepage_search' => 'Property search on the homepage.',
    'homepage_about' => text('story').isNotEmpty
        ? text('story')
        : (text('title').isEmpty ? 'No about copy saved yet.' : text('title')),
    'homepage_why_choose' => itemCount == 0
        ? 'No reasons saved yet.'
        : '$itemCount reasons. ${items is List && items.isNotEmpty && items.first is Map ? '${items.first['title'] ?? ''}' : ''}'
            .trim(),
    'homepage_executive_welcome' => text('message').isEmpty
        ? 'No quote saved yet. The homepage hides the quote until you add one.'
        : '${text('name').isEmpty ? 'Quote' : text('name')}: ${text('message')}',
    'homepage_featured_estates' => _countLine(counts.estates, 'featured estate', 'featured estates'),
    'homepage_featured_properties' =>
      _countLine(counts.properties, 'featured property', 'featured properties'),
    'homepage_testimonials' => _countLine(counts.testimonials, 'testimonial', 'testimonials'),
    'homepage_partners' => _countLine(counts.partners, 'partner', 'partners'),
    'homepage_trust' => 'Trust center teaser.',
    'homepage_awards' => _countLine(counts.awards, 'award', 'awards'),
    'homepage_content_hub' => 'Blog posts and FAQs share this band.',
    'homepage_blog' => _countLine(counts.posts, 'published post', 'published posts'),
    'homepage_faq' => _countLine(counts.faqs, 'published question', 'published questions'),
    'homepage_cta' => text('headline').isEmpty ? 'No call to action saved yet.' : text('headline'),
    'homepage_stats' => _countLine(counts.stats, 'statistic', 'statistics'),
    'homepage_closing' => 'Bottom band. The call to action sits inside it when that block is visible.',
    _ => section.displayTitle,
  };
}

String? _editorPath(String key) => switch (key) {
      'homepage_hero' => RoutePaths.dashboardWebsiteHero,
      'homepage_featured_estates' => RoutePaths.dashboardEstates,
      'homepage_featured_properties' => RoutePaths.dashboardProperties,
      'homepage_testimonials' => RoutePaths.dashboardWebsiteTestimonials,
      'homepage_partners' => RoutePaths.dashboardWebsitePartners,
      'homepage_awards' => RoutePaths.dashboardWebsiteAwards,
      'homepage_stats' => RoutePaths.dashboardWebsiteStatistics,
      'homepage_blog' => RoutePaths.dashboardWebsiteBlog,
      'homepage_faq' => RoutePaths.dashboardWebsiteFaq,
      _ => null,
    };

String _fieldLabel(String key) => switch (key) {
      'title' => 'Title',
      'description' => 'Description',
      'label' => 'Label',
      'route' => 'Link',
      'roi' => 'Return',
      'fileType' => 'File type',
      'url' => 'Link',
      'timeAgo' => 'When',
      'summary' => 'Summary',
      _ => key,
    };

String _groupFor(String key) => switch (key) {
      'homepage_hero' || 'homepage_search' => 'Opening',
      'homepage_about' ||
      'homepage_why_choose' ||
      'homepage_executive_welcome' =>
        'Story',
      'homepage_featured_estates' || 'homepage_featured_properties' => 'Listings',
      'homepage_testimonials' ||
      'homepage_partners' ||
      'homepage_trust' ||
      'homepage_awards' =>
        'Proof',
      'homepage_content_hub' || 'homepage_blog' || 'homepage_faq' => 'Stories',
      _ => 'Close',
    };

String _blurb(String key) => switch (key) {
      'homepage_hero' => 'Opening screen. Headline, buttons, and background.',
      'homepage_search' => 'Search field under the hero.',
      'homepage_about' => 'Story, mission, and highlights.',
      'homepage_why_choose' => 'Three reasons on the experience band. The first three saved items are the ones that publish.',
      'homepage_executive_welcome' => 'Quote on the experience band.',
      'homepage_featured_estates' => 'Estates marked published and featured.',
      'homepage_featured_properties' => 'Properties marked published and featured.',
      'homepage_testimonials' => 'Published client quotes.',
      'homepage_partners' => 'Partners marked for the homepage.',
      'homepage_trust' => 'Short link into the trust center.',
      'homepage_awards' => 'Published awards.',
      'homepage_content_hub' => 'The band that holds blog posts and FAQs.',
      'homepage_blog' => 'Shows published posts inside the content band.',
      'homepage_faq' => 'Shows published questions inside the content band.',
      'homepage_cta' => 'Buttons at the bottom of the homepage.',
      'homepage_stats' => 'Company numbers just above the footer.',
      'homepage_closing' => 'Closes the page. Hide this to drop the bottom band.',
      _ => '',
    };

class _SectionTile extends StatelessWidget {
  const _SectionTile({
    required this.index,
    required this.section,
    required this.shown,
    required this.preview,
    required this.onToggleVisible,
    required this.onEdit,
    required this.onOpen,
  });

  final int index;
  final CmsSectionRecord section;
  final bool shown;
  final String preview;
  final ValueChanged<bool> onToggleVisible;
  final VoidCallback onEdit;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final kind = homepageEditorKind(section.sectionKey);
    final opensElsewhere = _editorPath(section.sectionKey) != null;
    final editsHere = kind == 'about' || kind == 'why' || kind == 'cta' || kind == 'executive';
    return AdminCard(
      onTap: opensElsewhere ? onOpen : (editsHere ? onEdit : null),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$index',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.slate500,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section.displayTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  _blurb(section.sectionKey),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.slate500,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              Switch(
                value: shown,
                activeTrackColor: AppColors.gold,
                onChanged: onToggleVisible,
              ),
              Text(
                shown ? 'Visible' : 'Hidden',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.slate500,
                    ),
              ),
            ],
          ),
          if (editsHere)
            IconButton(
              onPressed: onEdit,
              icon: const Icon(LucideIcons.pencil, size: 18),
              tooltip: 'Edit',
            )
          else if (opensElsewhere)
            IconButton(
              onPressed: onOpen,
              icon: const Icon(LucideIcons.externalLink, size: 18),
              tooltip: 'Open editor',
            ),
        ],
      ),
    );
  }
}

class _SectionEditDialog extends ConsumerStatefulWidget {
  const _SectionEditDialog({this.section});

  final CmsSectionRecord? section;

  @override
  ConsumerState<_SectionEditDialog> createState() => _SectionEditDialogState();
}

class _SectionEditDialogState extends ConsumerState<_SectionEditDialog> {
  late final TextEditingController _keyController;
  late final TextEditingController _titleController;
  late final TextEditingController _typeController;
  late final TextEditingController _contentController;

  // About / executive / CTA
  late final TextEditingController _f1;
  late final TextEditingController _f2;
  late final TextEditingController _f3;
  late final TextEditingController _f4;
  late final TextEditingController _f5;
  late final TextEditingController _f6;
  late final TextEditingController _f7;
  late final TextEditingController _f8;

  late List<Map<String, dynamic>> _items;
  late List<String> _values;
  late List<Map<String, dynamic>> _highlights;

  bool _saving = false;
  bool _uploadingVideo = false;
  String? _error;
  late final String _kind;

  @override
  void initState() {
    super.initState();
    final s = widget.section;
    _kind = s == null ? 'json' : homepageEditorKind(s.sectionKey);
    _keyController = TextEditingController(text: s?.sectionKey ?? '');
    _titleController = TextEditingController(text: s?.title ?? '');
    _typeController = TextEditingController(text: s?.sectionType ?? 'block');
    final content = Map<String, dynamic>.from(s?.content ?? {});
    _contentController = TextEditingController(
      text: const JsonEncoder.withIndent('  ').convert(content),
    );

    _f1 = TextEditingController();
    _f2 = TextEditingController();
    _f3 = TextEditingController();
    _f4 = TextEditingController();
    _f5 = TextEditingController();
    _f6 = TextEditingController();
    _f7 = TextEditingController();
    _f8 = TextEditingController();
    _items = [];
    _values = [];
    _highlights = [];

    if (_kind == 'about') {
      _f1.text = '${content['title'] ?? ''}';
      _f2.text = '${content['titleAccent'] ?? ''}';
      _f3.text = '${content['story'] ?? ''}';
      _f4.text = '${content['mission'] ?? ''}';
      _f5.text = '${content['vision'] ?? ''}';
      _f6.text = '${content['ctaLabel'] ?? ''}';
      _f7.text = '${content['ctaPath'] ?? ''}';
      _f8.text = '${content['backgroundImageUrl'] ?? ''}';
      _values = [
        for (final v in (content['values'] as List? ?? const [])) '$v',
      ];
      _highlights = [
        for (final h in (content['highlights'] as List? ?? const []))
          Map<String, dynamic>.from(h as Map),
      ];
    } else if (_kind == 'executive') {
      _f1.text = '${content['name'] ?? ''}';
      _f2.text = '${content['title'] ?? ''}';
      _f3.text = '${content['message'] ?? ''}';
      _f4.text =
          '${content['videoUrl'] ?? content['video_url'] ?? ''}';
    } else if (_kind == 'cta') {
      _f1.text = '${content['headline'] ?? content['title'] ?? ''}';
      _f2.text = '${content['subheadline'] ?? content['subtitle'] ?? ''}';
      _f3.text =
          '${content['cta_label'] ?? content['primary_label'] ?? content['primaryCtaLabel'] ?? ''}';
      _f4.text =
          '${content['cta_url'] ?? content['primary_path'] ?? content['primaryCtaPath'] ?? ''}';
      _f5.text =
          '${content['secondary_label'] ?? content['secondaryCtaLabel'] ?? ''}';
      _f6.text =
          '${content['secondary_path'] ?? content['secondaryCtaPath'] ?? ''}';
    } else if (const {
      'stats',
      'why',
      'lifestyle',
      'investments',
      'partners',
      'awards',
      'insights',
      'events',
      'downloads',
      'live',
    }.contains(_kind)) {
      _items = [
        for (final i in (content['items'] as List? ?? const []))
          Map<String, dynamic>.from(i as Map),
      ];
    }
  }

  @override
  void dispose() {
    _keyController.dispose();
    _titleController.dispose();
    _typeController.dispose();
    _contentController.dispose();
    _f1.dispose();
    _f2.dispose();
    _f3.dispose();
    _f4.dispose();
    _f5.dispose();
    _f6.dispose();
    _f7.dispose();
    _f8.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildContent() {
    switch (_kind) {
      case 'about':
        return {
          'title': _f1.text.trim(),
          'titleAccent': _f2.text.trim(),
          'story': _f3.text.trim(),
          'mission': _f4.text.trim(),
          'vision': _f5.text.trim(),
          'ctaLabel': _f6.text.trim(),
          'ctaPath': _f7.text.trim(),
          'backgroundImageUrl': _f8.text.trim().isEmpty ? null : _f8.text.trim(),
          'values': [for (final v in _values) if (v.trim().isNotEmpty) v.trim()],
          'highlights': _highlights,
        };
      case 'executive':
        return {
          'name': _f1.text.trim(),
          'title': _f2.text.trim(),
          'message': _f3.text.trim(),
          'videoUrl': _f4.text.trim().isEmpty ? null : _f4.text.trim(),
        };
      case 'cta':
        return {
          'headline': _f1.text.trim(),
          'subheadline': _f2.text.trim(),
          'cta_label': _f3.text.trim(),
          'cta_url': _f4.text.trim(),
          'secondary_label': _f5.text.trim(),
          'secondary_path': _f6.text.trim(),
        };
      case 'stats':
      case 'why':
      case 'lifestyle':
      case 'investments':
      case 'partners':
      case 'awards':
      case 'insights':
      case 'events':
      case 'downloads':
      case 'live':
        return {'items': _items};
      case 'managed_elsewhere':
      case 'hero_link':
      case 'visibility_only':
        return Map<String, dynamic>.from(widget.section?.content ?? {});
      default:
        final decoded = _contentController.text.trim().isEmpty
            ? <String, dynamic>{}
            : jsonDecode(_contentController.text);
        return decoded is Map<String, dynamic>
            ? decoded
            : Map<String, dynamic>.from(decoded as Map);
    }
  }

  Future<void> _uploadExecutiveVideo() async {
    setState(() {
      _uploadingVideo = true;
      _error = null;
    });
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.video,
        withData: true,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        throw StateError('Could not read video bytes. Try another file.');
      }
      final name = file.name.toLowerCase();
      final contentType = name.endsWith('.webm')
          ? 'video/webm'
          : name.endsWith('.mov')
              ? 'video/quicktime'
              : 'video/mp4';
      final url = await ref.read(cmsServiceProvider).uploadHeroMedia(
            bytes: bytes,
            contentType: contentType,
            pageKey: 'executive-welcome',
            kind: 'video',
          );
      if (!mounted) return;
      setState(() => _f4.text = url);
    } catch (e) {
      if (mounted) setState(() => _error = userFacingError(e));
    } finally {
      if (mounted) setState(() => _uploadingVideo = false);
    }
  }

  Future<void> _save() async {
    if (_kind == 'managed_elsewhere' ||
        _kind == 'hero_link' ||
        _kind == 'visibility_only') {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    Map<String, dynamic> content;
    try {
      content = _buildContent();
    } catch (_) {
      setState(() => _error = 'Content must be valid JSON.');
      return;
    }
    if (_keyController.text.trim().isEmpty) {
      setState(() => _error = 'Section key is required.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(cmsServiceProvider).upsertSection(
            id: widget.section?.id,
            sectionKey: _keyController.text.trim(),
            sectionType: _typeController.text.trim().isEmpty
                ? 'block'
                : _typeController.text.trim(),
            title: _titleController.text.trim(),
            content: content,
            sortOrder: widget.section?.sortOrder ?? 0,
            isVisible: widget.section?.isVisible ?? true,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = userFacingError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _managedPath() {
    final key = widget.section?.sectionKey ?? '';
    return switch (key) {
      'homepage_hero' => RoutePaths.dashboardWebsiteHero,
      'homepage_featured_estates' => RoutePaths.dashboardEstates,
      'homepage_featured_properties' => RoutePaths.dashboardProperties,
      'homepage_testimonials' => RoutePaths.dashboardWebsiteTestimonials,
      'homepage_partners' => RoutePaths.dashboardWebsitePartners,
      'homepage_stats' => RoutePaths.dashboardWebsiteStatistics,
      'homepage_awards' => RoutePaths.dashboardWebsiteAwards,
      'homepage_construction' => RoutePaths.dashboardWebsiteConstruction,
      'homepage_faq' => RoutePaths.dashboardWebsiteFaq,
      'homepage_blog' => RoutePaths.dashboardWebsiteBlog,
      _ => null,
    };
  }

  List<String> _itemFieldsForKind() {
    return switch (_kind) {
      'stats' => const ['value', 'label', 'suffix', 'caption', 'iconName'],
      'why' => const ['title', 'description'],
      'lifestyle' => const ['label', 'description', 'route'],
      'investments' => const [
          'title',
          'roi',
          'type',
          'duration',
          'risk',
          'growth',
          'route',
        ],
      'partners' => const ['name', 'category'],
      'awards' => const ['title', 'year', 'issuer'],
      'insights' => const ['title', 'trend', 'change', 'summary'],
      'events' => const ['title', 'date', 'location', 'type'],
      'downloads' => const ['title', 'fileType', 'url'],
      'live' => const ['message', 'timeAgo', 'type'],
      _ => const <String>[],
    };
  }

  @override
  Widget build(BuildContext context) {
    final isCreate = widget.section == null;
    final managedPath = _managedPath();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.dialogBorder),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isCreate ? 'Add homepage section' : 'Edit section',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isCreate || _kind == 'json') ...[
                        TextField(
                          controller: _keyController,
                          readOnly: !isCreate,
                          decoration: const InputDecoration(
                            labelText: 'Section key',
                            hintText: 'homepage_stats',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _typeController,
                          decoration:
                              const InputDecoration(labelText: 'Section type'),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: _titleController,
                        decoration: const InputDecoration(labelText: 'Title'),
                      ),
                      const SizedBox(height: 16),
                      if (_kind == 'hero_link' ||
                          _kind == 'managed_elsewhere' ||
                          _kind == 'visibility_only') ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.slate100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            widget.section?.content['note'] as String? ??
                                (_kind == 'visibility_only'
                                    ? 'Use the Visible switch on the Homepage list to show or hide this block on the public site.'
                                    : 'This block is managed in a dedicated Website tool. '
                                        'Use visibility and order here; edit content there.'),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        if (managedPath != null) ...[
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              context.go(managedPath);
                            },
                            icon: const Icon(LucideIcons.externalLink, size: 16),
                            label: const Text('Open dedicated editor'),
                          ),
                        ],
                      ] else if (_kind == 'about') ...[
                        _field(_f1, 'Title'),
                        _field(_f2, 'Title accent'),
                        _field(_f3, 'Story', lines: 3),
                        _field(_f4, 'Mission', lines: 2),
                        _field(_f5, 'Vision', lines: 2),
                        _field(_f6, 'CTA label'),
                        _field(_f7, 'CTA path'),
                        _field(_f8, 'Background image URL'),
                        const SizedBox(height: 8),
                        Text('Values',
                            style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 8),
                        for (var i = 0; i < _values.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    initialValue: _values[i],
                                    decoration: InputDecoration(
                                      labelText: 'Value ${i + 1}',
                                    ),
                                    onChanged: (v) => _values[i] = v,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      setState(() => _values.removeAt(i)),
                                  icon: const Icon(LucideIcons.trash2, size: 16),
                                ),
                              ],
                            ),
                          ),
                        TextButton.icon(
                          onPressed: () =>
                              setState(() => _values.add('New value')),
                          icon: const Icon(LucideIcons.plus, size: 16),
                          label: const Text('Add value'),
                        ),
                        const SizedBox(height: 12),
                        Text('Highlights',
                            style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 8),
                        for (var i = 0; i < _highlights.length; i++)
                          _HighlightEditor(
                            data: _highlights[i],
                            onChanged: (m) =>
                                setState(() => _highlights[i] = m),
                            onRemove: () =>
                                setState(() => _highlights.removeAt(i)),
                          ),
                        TextButton.icon(
                          onPressed: () => setState(
                            () => _highlights.add({
                              'title': 'New highlight',
                              'description': '',
                              'iconName': 'star',
                            }),
                          ),
                          icon: const Icon(LucideIcons.plus, size: 16),
                          label: const Text('Add highlight'),
                        ),
                      ] else if (_kind == 'executive') ...[
                        Text(
                          'This quote sits on the Why Choose band. '
                          'Save publishes it on the public homepage. '
                          'Hide the section to remove the quote.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondaryLight,
                              ),
                        ),
                        const SizedBox(height: 12),
                        _field(_f1, 'Name'),
                        _field(_f2, 'Title / role'),
                        _field(_f3, 'Message', lines: 4),
                        _field(_f4, 'Video URL'),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed:
                                  _uploadingVideo ? null : _uploadExecutiveVideo,
                              icon: _uploadingVideo
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(LucideIcons.upload, size: 16),
                              label: Text(
                                _f4.text.trim().isEmpty
                                    ? 'Upload video'
                                    : 'Replace video',
                              ),
                            ),
                            if (_f4.text.trim().isNotEmpty)
                              TextButton.icon(
                                onPressed: () => setState(() => _f4.clear()),
                                icon: const Icon(LucideIcons.trash2, size: 16),
                                label: const Text('Remove video'),
                              ),
                          ],
                        ),
                      ] else if (_kind == 'cta') ...[
                        _field(_f1, 'Headline'),
                        _field(_f2, 'Subheadline', lines: 2),
                        _field(_f3, 'Primary CTA label'),
                        _field(_f4, 'Primary CTA path'),
                        _field(_f5, 'Secondary CTA label'),
                        _field(_f6, 'Secondary CTA path'),
                      ] else if (_kind == 'stats') ...[
                        Text(
                          'Each card appears on the public homepage near the '
                          'footer. Use real numbers — they publish immediately '
                          'after save.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondaryLight,
                              ),
                        ),
                        const SizedBox(height: 12),
                        for (var i = 0; i < _items.length; i++)
                          _StatsItemEditor(
                            data: _items[i],
                            index: i,
                            onChanged: (m) => setState(() => _items[i] = m),
                            onRemove: () =>
                                setState(() => _items.removeAt(i)),
                          ),
                        TextButton.icon(
                          onPressed: () => setState(
                            () => _items.add(emptyHomepageItem('stats')),
                          ),
                          icon: const Icon(LucideIcons.plus, size: 16),
                          label: const Text('Add stat card'),
                        ),
                      ] else if (_itemFieldsForKind().isNotEmpty) ...[
                        if (_kind == 'why')
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              'The first three cards are the three cards on the homepage.',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.slate500,
                                  ),
                            ),
                          ),
                        for (var i = 0; i < _items.length; i++)
                          _ListItemEditor(
                            kind: _kind,
                            fields: _itemFieldsForKind(),
                            data: _items[i],
                            index: i,
                            onChanged: (m) => setState(() => _items[i] = m),
                            onRemove: () =>
                                setState(() => _items.removeAt(i)),
                          ),
                        if (_kind != 'why' || _items.length < 3)
                          TextButton.icon(
                            onPressed: () => setState(
                              () => _items.add(emptyHomepageItem(_kind)),
                            ),
                            icon: const Icon(LucideIcons.plus, size: 16),
                            label: Text(_kind == 'why' ? 'Add card' : 'Add item'),
                          ),
                      ] else ...[
                        TextField(
                          controller: _contentController,
                          minLines: 5,
                          maxLines: 12,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Content (JSON)',
                            alignLabelWithHint: true,
                          ),
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  if (_kind != 'managed_elsewhere' &&
                      _kind != 'hero_link' &&
                      _kind != 'visibility_only')
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save & publish'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    int lines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        minLines: lines,
        maxLines: lines,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

class _HighlightEditor extends StatelessWidget {
  const _HighlightEditor({
    required this.data,
    required this.onChanged,
    required this.onRemove,
  });

  final Map<String, dynamic> data;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Highlight',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(LucideIcons.trash2, size: 16),
                ),
              ],
            ),
            for (final key in const ['title', 'description', 'iconName'])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextFormField(
                  initialValue: '${data[key] ?? ''}',
                  decoration: InputDecoration(labelText: key),
                  maxLines: key == 'description' ? 2 : 1,
                  onChanged: (v) {
                    final next = Map<String, dynamic>.from(data);
                    next[key] = v;
                    onChanged(next);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatsItemEditor extends StatelessWidget {
  const _StatsItemEditor({
    required this.data,
    required this.index,
    required this.onChanged,
    required this.onRemove,
  });

  final Map<String, dynamic> data;
  final int index;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final VoidCallback onRemove;

  static const _iconOptions = <String>[
    'trophy',
    'building',
    'home',
    'users',
    'user',
    'crane',
    'star',
    'globe',
  ];

  void _set(String key, Object? value) {
    final next = Map<String, dynamic>.from(data);
    next[key] = value;
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final icon = '${data['iconName'] ?? 'star'}';
    final selectedIcon = _iconOptions.contains(icon) ? icon : 'star';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Stat card ${index + 1}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(LucideIcons.trash2, size: 16),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: '${data['value'] ?? ''}',
                    decoration: const InputDecoration(
                      labelText: 'Value (number)',
                      hintText: '12000',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final cleaned = v.replaceAll(',', '').trim();
                      _set(
                        'value',
                        int.tryParse(cleaned) ??
                            num.tryParse(cleaned) ??
                            cleaned,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 88,
                  child: TextFormField(
                    initialValue: '${data['suffix'] ?? ''}',
                    decoration: const InputDecoration(
                      labelText: 'Suffix',
                      hintText: '+ or %',
                    ),
                    onChanged: (v) => _set('suffix', v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: '${data['label'] ?? ''}',
              decoration: const InputDecoration(
                labelText: 'Label',
                hintText: 'Happy Clients',
              ),
              onChanged: (v) => _set('label', v),
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: '${data['caption'] ?? ''}',
              decoration: const InputDecoration(
                labelText: 'Caption',
                hintText: 'Across the country',
              ),
              onChanged: (v) => _set('caption', v),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: selectedIcon,
              decoration: const InputDecoration(labelText: 'Icon'),
              items: [
                for (final name in _iconOptions)
                  DropdownMenuItem(value: name, child: Text(name)),
              ],
              onChanged: (v) {
                if (v != null) _set('iconName', v);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ListItemEditor extends StatelessWidget {
  const _ListItemEditor({
    required this.kind,
    required this.fields,
    required this.data,
    required this.index,
    required this.onChanged,
    required this.onRemove,
  });

  final String kind;
  final List<String> fields;
  final Map<String, dynamic> data;
  final int index;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    kind == 'why' ? 'Card ${index + 1}' : 'Item ${index + 1}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(LucideIcons.trash2, size: 16),
                ),
              ],
            ),
            for (final key in fields)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextFormField(
                  initialValue: '${data[key] ?? ''}',
                  decoration: InputDecoration(labelText: _fieldLabel(key)),
                  maxLines: key == 'description' ||
                          key == 'summary' ||
                          key == 'update' ||
                          key == 'message'
                      ? 2
                      : 1,
                  onChanged: (v) {
                    final next = Map<String, dynamic>.from(data);
                    if (key == 'value') {
                      next[key] = int.tryParse(v) ?? num.tryParse(v) ?? v;
                    } else if (key == 'progress') {
                      next[key] = double.tryParse(v) ?? v;
                    } else {
                      next[key] = v;
                    }
                    onChanged(next);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
