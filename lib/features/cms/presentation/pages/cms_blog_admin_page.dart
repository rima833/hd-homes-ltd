import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/media/widgets/media_upload_panel.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

String? blogPublishValidationError({
  required String title,
  required String slug,
  required String? coverImageUrl,
  required bool publish,
}) {
  if (title.trim().isEmpty || slug.trim().isEmpty) {
    return 'Title and slug are required.';
  }
  if (publish && (coverImageUrl == null || coverImageUrl.trim().isEmpty)) {
    return 'Add a cover image before publishing.';
  }
  return null;
}

/// Admin → Website → Blog: posts, topics, and authors.
class CmsBlogAdminPage extends ConsumerStatefulWidget {
  const CmsBlogAdminPage({super.key});

  @override
  ConsumerState<CmsBlogAdminPage> createState() => _CmsBlogAdminPageState();
}

class _CmsBlogAdminPageState extends ConsumerState<CmsBlogAdminPage> {
  int _section = 0;
  _PostFilter _filter = _PostFilter.all;
  String _query = '';

  void _bump() => bumpBlogCmsTickFromWidget(ref);

  @override
  Widget build(BuildContext context) {
    ref.watch(blogCmsRealtimeProvider);
    final realtime = ref.watch(blogCmsRealtimeStateProvider);
    final posts = ref.watch(cmsBlogsProvider);
    final categories = ref.watch(cmsBlogCategoriesProvider);
    final authors = ref.watch(cmsBlogAuthorsProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(realtime: realtime),
          const SizedBox(height: 14),
          _SectionSwitch(
            section: _section,
            onChanged: (value) => setState(() {
              _section = value;
              _query = '';
            }),
          ),
          const SizedBox(height: 12),
          _SearchField(
            key: ValueKey(_section),
            hint: switch (_section) {
              1 => 'Search topics',
              2 => 'Search authors',
              _ => 'Search posts',
            },
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: switch (_section) {
              1 => _CategoriesPane(
                categories: categories,
                posts: posts.valueOrNull ?? const [],
                query: _query,
                onChanged: _bump,
              ),
              2 => _AuthorsPane(
                authors: authors,
                posts: posts.valueOrNull ?? const [],
                query: _query,
                onChanged: _bump,
              ),
              _ => _PostsPane(
                posts: posts,
                categories: categories.valueOrNull ?? const [],
                authors: authors.valueOrNull ?? const [],
                filter: _filter,
                query: _query,
                onFilter: (value) => setState(() => _filter = value),
                onChanged: _bump,
              ),
            },
          ),
        ],
      ),
    );
  }
}

enum _PostFilter { all, published, drafts, featured }

class _Header extends StatelessWidget {
  const _Header({required this.realtime});

  final BlogCmsRealtimeState realtime;

  @override
  Widget build(BuildContext context) {
    final note = switch (realtime) {
      BlogCmsRealtimeState.live => 'Your latest articles are here.',
      BlogCmsRealtimeState.connecting => "We're gathering the latest articles.",
      BlogCmsRealtimeState.error || BlogCmsRealtimeState.offline =>
        "We'll refresh these articles when the connection is back.",
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF141820),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Blog',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Write, publish, feature, and remove the articles, topics, and authors on /blog.',
                    style: TextStyle(color: Color(0xFF9AA1AB), height: 1.35),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                note,
                textAlign: TextAlign.end,
                style: const TextStyle(
                  color: Color(0xFF9AA1AB),
                  fontSize: 12,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionSwitch extends StatelessWidget {
  const _SectionSwitch({required this.section, required this.onChanged});

  final int section;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in [
          (0, 'Posts', LucideIcons.newspaper),
          (1, 'Topics', LucideIcons.layoutGrid),
          (2, 'Authors', LucideIcons.userCircle),
        ])
          _ChipButton(
            label: item.$2,
            icon: item.$3,
            selected: section == item.$1,
            onTap: () => onChanged(item.$1),
          ),
      ],
    );
  }
}

class _ChipButton extends StatelessWidget {
  const _ChipButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.gold : const Color(0xFFC8CDD4);
    return Material(
      color: selected ? AppColors.gold.withValues(alpha: 0.16) : const Color(0xFF141820),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? AppColors.gold.withValues(alpha: 0.7)
                  : const Color(0x18FFFFFF),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({super.key, required this.hint, required this.onChanged});

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white),
      decoration: _fieldDecoration(hint).copyWith(
        prefixIcon: const Icon(LucideIcons.search, size: 16, color: Color(0xFF9AA1AB)),
      ),
    );
  }
}

class _PostsPane extends ConsumerWidget {
  const _PostsPane({
    required this.posts,
    required this.categories,
    required this.authors,
    required this.filter,
    required this.query,
    required this.onFilter,
    required this.onChanged,
  });

  final AsyncValue<List<CmsBlogPost>> posts;
  final List<CmsBlogCategory> categories;
  final List<CmsBlogAuthor> authors;
  final _PostFilter filter;
  final String query;
  final ValueChanged<_PostFilter> onFilter;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return posts.when(
      loading: () => const _Loading(),
      error: (error, _) => _ErrorPane(
        message: userFacingError(error, fallback: 'Unable to load posts.'),
        onRetry: onChanged,
      ),
      data: (items) {
        final published = items.where((post) => post.isPublished).length;
        final filtered = items.where((post) {
          final matchesFilter = switch (filter) {
            _PostFilter.published => post.isPublished,
            _PostFilter.drafts => !post.isPublished,
            _PostFilter.featured => post.featured,
            _PostFilter.all => true,
          };
          if (!matchesFilter) return false;
          final needle = query.trim().toLowerCase();
          if (needle.isEmpty) return true;
          return post.title.toLowerCase().contains(needle) ||
              post.slug.toLowerCase().contains(needle);
        }).toList();
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _Stat(label: 'Published', value: '$published / ${items.length}'),
                      _Stat(
                        label: 'Featured',
                        value: '${items.where((post) => post.featured).length}',
                      ),
                      for (final item in const [
                        (_PostFilter.all, 'All'),
                        (_PostFilter.published, 'Published'),
                        (_PostFilter.drafts, 'Drafts'),
                        (_PostFilter.featured, 'Featured'),
                      ])
                        _ChipButton(
                          label: item.$2,
                          icon: LucideIcons.filter,
                          selected: filter == item.$1,
                          onTap: () => onFilter(item.$1),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => _openPost(context, ref, null),
                  icon: const Icon(LucideIcons.plus, size: 16),
                  label: const Text('New post'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filtered.isEmpty
                  ? _EmptyPane(
                      title: items.isEmpty ? 'No posts yet' : 'No posts match',
                      message: items.isEmpty
                          ? 'Create a post, add a cover, then publish it to /blog.'
                          : 'Try another search or filter.',
                      action: items.isEmpty
                          ? FilledButton.icon(
                              onPressed: () => _openPost(context, ref, null),
                              icon: const Icon(LucideIcons.plus, size: 16),
                              label: const Text('New post'),
                            )
                          : null,
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final post = filtered[index];
                        return _PostCard(
                          post: post,
                          categoryName: _categoryName(post),
                          onEdit: () => _openPost(context, ref, post),
                          onPublish: () {
                            final missingCover =
                                post.coverImageUrl == null ||
                                post.coverImageUrl!.trim().isEmpty;
                            if (!post.isPublished && missingCover) {
                              _toast(
                                context,
                                'Add a cover image before publishing.',
                              );
                              return;
                            }
                            _run(
                              context,
                              () => ref
                                  .read(cmsServiceProvider)
                                  .setBlogPublished(post.id, !post.isPublished),
                            );
                          },
                          onFeature: () => _run(
                            context,
                            () => ref
                                .read(cmsServiceProvider)
                                .setBlogFeatured(post.id, !post.featured),
                          ),
                          onDelete: () => _deletePost(context, ref, post),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  String _categoryName(CmsBlogPost post) {
    for (final category in categories) {
      if (category.id == post.categoryId) return category.name;
    }
    return 'Uncategorized';
  }

  Future<void> _openPost(
    BuildContext context,
    WidgetRef ref,
    CmsBlogPost? post,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _BlogEditDialog(
        post: post,
        categories: categories,
        authors: authors,
      ),
    );
    onChanged();
  }

  Future<void> _deletePost(
    BuildContext context,
    WidgetRef ref,
    CmsBlogPost post,
  ) async {
    final ok = await _confirm(
      context,
      title: 'Delete post?',
      message: '“${post.title}” will leave /blog. This can be recreated, not restored.',
      confirmLabel: 'Delete post',
    );
    if (!ok || !context.mounted) return;
    await _run(context, () => ref.read(cmsServiceProvider).deleteBlog(post.id));
  }

  Future<void> _run(BuildContext context, Future<void> Function() action) async {
    try {
      await action();
      onChanged();
    } catch (error) {
      if (!context.mounted) return;
      _toast(context, userFacingError(error, fallback: 'Unable to update the post.'));
    }
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.categoryName,
    required this.onEdit,
    required this.onPublish,
    required this.onFeature,
    required this.onDelete,
  });

  final CmsBlogPost post;
  final String categoryName;
  final VoidCallback onEdit;
  final VoidCallback onPublish;
  final VoidCallback onFeature;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final hasCover = post.coverImageUrl != null && post.coverImageUrl!.isNotEmpty;
    return _Panel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: hasCover
                ? MediaDeliveryImage(
                    url: post.coverImageUrl!,
                    width: 92,
                    height: 72,
                    fit: BoxFit.cover,
                    errorWidget: _thumb(),
                  )
                : _thumb(),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$categoryName · /blog/${post.slug}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF9AA1AB), fontSize: 12),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _StatusPill(
                      label: post.isPublished ? 'Published' : 'Draft',
                      color: post.isPublished
                          ? const Color(0xFF86EFAC)
                          : const Color(0xFFF5E6B8),
                    ),
                    if (post.featured)
                      const _StatusPill(label: 'Featured', color: AppColors.gold),
                    if (!hasCover)
                      const _StatusPill(label: 'No cover', color: Color(0xFFFCA5A5)),
                    Text(
                      post.publishedAt != null
                          ? DateFormat.yMMMd().format(post.publishedAt!.toLocal())
                          : 'Not published',
                      style: const TextStyle(color: Color(0xFF6E7682), fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    _ActionButton(label: 'Edit', icon: LucideIcons.pencil, onTap: onEdit),
                    _ActionButton(
                      label: post.isPublished ? 'Unpublish' : 'Publish',
                      icon: post.isPublished ? LucideIcons.eyeOff : LucideIcons.badgeCheck,
                      onTap: onPublish,
                    ),
                    _ActionButton(
                      label: post.featured ? 'Unfeature' : 'Feature',
                      icon: LucideIcons.star,
                      onTap: onFeature,
                    ),
                    _ActionButton(
                      label: 'Delete',
                      icon: LucideIcons.trash2,
                      onTap: onDelete,
                      danger: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumb() => Container(
    width: 92,
    height: 72,
    color: const Color(0xFF0E1016),
    child: const Icon(LucideIcons.newspaper, color: Color(0xFF9AA1AB)),
  );
}

class _CategoriesPane extends ConsumerWidget {
  const _CategoriesPane({
    required this.categories,
    required this.posts,
    required this.query,
    required this.onChanged,
  });

  final AsyncValue<List<CmsBlogCategory>> categories;
  final List<CmsBlogPost> posts;
  final String query;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return categories.when(
      loading: () => const _Loading(),
      error: (error, _) => _ErrorPane(
        message: userFacingError(error, fallback: 'Unable to load topics.'),
        onRetry: onChanged,
      ),
      data: (items) {
        final needle = query.trim().toLowerCase();
        final filtered = items.where((category) {
          if (needle.isEmpty) return true;
          return category.name.toLowerCase().contains(needle) ||
              category.slug.toLowerCase().contains(needle);
        }).toList();
        return Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => _open(context, ref, null),
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('New topic'),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filtered.isEmpty
                  ? _EmptyPane(
                      title: items.isEmpty ? 'No topics yet' : 'No topics match',
                      message: 'Topics filter the public blog.',
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final category = filtered[index];
                        final used = posts
                            .where((post) => post.categoryId == category.id)
                            .length;
                        return _Panel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      category.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  _StatusPill(
                                    label: category.isPublished ? 'Published' : 'Hidden',
                                    color: category.isPublished
                                        ? const Color(0xFF86EFAC)
                                        : const Color(0xFFF5E6B8),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${category.slug} · $used ${used == 1 ? 'post' : 'posts'}',
                                style: const TextStyle(
                                  color: Color(0xFF9AA1AB),
                                  fontSize: 12,
                                ),
                              ),
                              Wrap(
                                spacing: 4,
                                children: [
                                  _ActionButton(
                                    label: category.isPublished ? 'Hide' : 'Show',
                                    icon: LucideIcons.eye,
                                    onTap: () => _run(
                                      context,
                                      () => ref
                                          .read(cmsServiceProvider)
                                          .setBlogCategoryStatus(
                                            category.id,
                                            category.isPublished
                                                ? 'draft'
                                                : 'active',
                                          ),
                                    ),
                                  ),
                                  _ActionButton(
                                    label: 'Edit',
                                    icon: LucideIcons.pencil,
                                    onTap: () => _open(context, ref, category),
                                  ),
                                  _ActionButton(
                                    label: 'Delete',
                                    icon: LucideIcons.trash2,
                                    danger: true,
                                    onTap: () =>
                                        _delete(context, ref, category, used),
                                  ),
                                ],
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
    );
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    CmsBlogCategory? category,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _CategoryDialog(category: category),
    );
    onChanged();
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    CmsBlogCategory category,
    int used,
  ) async {
    final ok = await _confirm(
      context,
      title: 'Delete topic?',
      message: used == 0
          ? '“${category.name}” will be removed from the blog filters.'
          : '“${category.name}” is on $used ${used == 1 ? 'post' : 'posts'}. Those posts become uncategorized.',
      confirmLabel: 'Delete topic',
    );
    if (!ok || !context.mounted) return;
    await _run(
      context,
      () => ref.read(cmsServiceProvider).deleteBlogCategory(category.id),
    );
  }

  Future<void> _run(BuildContext context, Future<void> Function() action) async {
    try {
      await action();
      onChanged();
    } catch (error) {
      if (!context.mounted) return;
      _toast(context, userFacingError(error, fallback: 'Unable to update the topic.'));
    }
  }
}

class _AuthorsPane extends ConsumerWidget {
  const _AuthorsPane({
    required this.authors,
    required this.posts,
    required this.query,
    required this.onChanged,
  });

  final AsyncValue<List<CmsBlogAuthor>> authors;
  final List<CmsBlogPost> posts;
  final String query;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return authors.when(
      loading: () => const _Loading(),
      error: (error, _) => _ErrorPane(
        message: userFacingError(error, fallback: 'Unable to load authors.'),
        onRetry: onChanged,
      ),
      data: (items) {
        final needle = query.trim().toLowerCase();
        final filtered = items.where((author) {
          if (needle.isEmpty) return true;
          return author.displayName.toLowerCase().contains(needle) ||
              author.slug.toLowerCase().contains(needle);
        }).toList();
        return Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => _open(context, null),
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('New author'),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filtered.isEmpty
                  ? _EmptyPane(
                      title: items.isEmpty ? 'No authors yet' : 'No authors match',
                      message: 'Authors appear on published articles.',
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final author = filtered[index];
                        final used = posts
                            .where((post) => post.blogAuthorId == author.id)
                            .length;
                        return _Panel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: const Color(0xFF0E1016),
                                backgroundImage:
                                    author.avatarUrl != null &&
                                        author.avatarUrl!.isNotEmpty
                                    ? NetworkImage(author.avatarUrl!)
                                    : null,
                                child:
                                    author.avatarUrl == null ||
                                        author.avatarUrl!.isEmpty
                                    ? const Icon(
                                        LucideIcons.userCircle,
                                        color: AppColors.gold,
                                        size: 16,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      author.displayName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      '$used ${used == 1 ? 'post' : 'posts'}',
                                      style: const TextStyle(
                                        color: Color(0xFF9AA1AB),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _StatusPill(
                                label: author.isActive ? 'Active' : 'Hidden',
                                color: author.isActive
                                    ? const Color(0xFF86EFAC)
                                    : const Color(0xFFF5E6B8),
                              ),
                              const SizedBox(width: 8),
                              _ActionButton(
                                label: 'Edit',
                                icon: LucideIcons.pencil,
                                onTap: () => _open(context, author),
                              ),
                              _ActionButton(
                                label: 'Delete',
                                icon: LucideIcons.trash2,
                                danger: true,
                                onTap: () => _delete(context, ref, author, used),
                              ),
                                ],
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
    );
  }

  Future<void> _open(BuildContext context, CmsBlogAuthor? author) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _AuthorDialog(author: author),
    );
    onChanged();
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    CmsBlogAuthor author,
    int used,
  ) async {
    final ok = await _confirm(
      context,
      title: 'Delete author?',
      message: used == 0
          ? '“${author.displayName}” will be removed.'
          : '“${author.displayName}” is on $used ${used == 1 ? 'post' : 'posts'}. Those posts keep their text and lose this byline.',
      confirmLabel: 'Delete author',
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(cmsServiceProvider).deleteBlogAuthor(author.id);
      onChanged();
    } catch (error) {
      if (!context.mounted) return;
      _toast(context, userFacingError(error, fallback: 'Unable to delete the author.'));
    }
  }
}

class _CategoryDialog extends ConsumerStatefulWidget {
  const _CategoryDialog({this.category});

  final CmsBlogCategory? category;

  @override
  ConsumerState<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends ConsumerState<_CategoryDialog> {
  late final TextEditingController _name;
  late final TextEditingController _slug;
  bool _slugTouched = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.category?.name ?? '');
    _slug = TextEditingController(text: widget.category?.slug ?? '');
    _slugTouched = widget.category != null;
  }

  @override
  void dispose() {
    _name.dispose();
    _slug.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _slug.text.trim().isEmpty) {
      setState(() => _error = 'Name and slug are required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(cmsServiceProvider).upsertBlogCategory(
        id: widget.category?.id,
        name: _name.text.trim(),
        slug: _slug.text.trim(),
        status: widget.category?.status ?? 'active',
      );
      bumpBlogCmsTickFromWidget(ref);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      setState(() => _error = userFacingError(error, fallback: 'Unable to save the topic.'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _EditorFrame(
      title: widget.category == null ? 'New topic' : 'Edit topic',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            style: const TextStyle(color: Colors.white),
            decoration: _fieldDecoration('Name'),
            onChanged: (value) {
              if (!_slugTouched) _slug.text = _slugify(value);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _slug,
            style: const TextStyle(color: Colors.white),
            decoration: _fieldDecoration('Slug'),
            onChanged: (_) => _slugTouched = true,
          ),
          if (_error != null) _ErrorLine(_error!),
          const SizedBox(height: 18),
          _EditorActions(
            saving: _saving,
            onCancel: () => Navigator.pop(context),
            primaryLabel: 'Save topic',
            onPrimary: _save,
          ),
        ],
      ),
    );
  }
}

class _AuthorDialog extends ConsumerStatefulWidget {
  const _AuthorDialog({this.author});

  final CmsBlogAuthor? author;

  @override
  ConsumerState<_AuthorDialog> createState() => _AuthorDialogState();
}

class _AuthorDialogState extends ConsumerState<_AuthorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _slug;
  late final TextEditingController _bio;
  late final TextEditingController _avatar;
  bool _slugTouched = false;
  bool _active = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final author = widget.author;
    _name = TextEditingController(text: author?.displayName ?? '');
    _slug = TextEditingController(text: author?.slug ?? '');
    _bio = TextEditingController(text: author?.bio ?? '');
    _avatar = TextEditingController(text: author?.avatarUrl ?? '');
    _active = author?.isActive ?? true;
    _slugTouched = author != null;
  }

  @override
  void dispose() {
    _name.dispose();
    _slug.dispose();
    _bio.dispose();
    _avatar.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _slug.text.trim().isEmpty) {
      setState(() => _error = 'Name and slug are required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final avatar = _avatar.text.trim();
      final bio = _bio.text.trim();
      await ref.read(cmsServiceProvider).upsertBlogAuthor(
        id: widget.author?.id,
        displayName: _name.text.trim(),
        slug: _slug.text.trim(),
        bio: bio.isEmpty ? null : bio,
        avatarUrl: avatar.isEmpty ? null : avatar,
        isActive: _active,
      );
      bumpBlogCmsTickFromWidget(ref);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      setState(() => _error = userFacingError(error, fallback: 'Unable to save the author.'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _EditorFrame(
      title: widget.author == null ? 'New author' : 'Edit author',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            style: const TextStyle(color: Colors.white),
            decoration: _fieldDecoration('Display name'),
            onChanged: (value) {
              if (!_slugTouched) _slug.text = _slugify(value);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _slug,
            style: const TextStyle(color: Colors.white),
            decoration: _fieldDecoration('Slug'),
            onChanged: (_) => _slugTouched = true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bio,
            minLines: 2,
            maxLines: 4,
            style: const TextStyle(color: Colors.white),
            decoration: _fieldDecoration('Bio'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _avatar,
            style: const TextStyle(color: Colors.white),
            decoration: _fieldDecoration('Avatar URL'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _active,
            activeTrackColor: AppColors.gold,
            title: const Text('Active', style: TextStyle(color: Colors.white)),
            subtitle: const Text(
              'Hidden authors stay off new posts.',
              style: TextStyle(color: Color(0xFF9AA1AB)),
            ),
            onChanged: (value) => setState(() => _active = value),
          ),
          if (_error != null) _ErrorLine(_error!),
          const SizedBox(height: 8),
          _EditorActions(
            saving: _saving,
            onCancel: () => Navigator.pop(context),
            primaryLabel: 'Save author',
            onPrimary: _save,
          ),
        ],
      ),
    );
  }
}

class _BlogEditDialog extends ConsumerStatefulWidget {
  const _BlogEditDialog({
    this.post,
    required this.categories,
    required this.authors,
  });

  final CmsBlogPost? post;
  final List<CmsBlogCategory> categories;
  final List<CmsBlogAuthor> authors;

  @override
  ConsumerState<_BlogEditDialog> createState() => _BlogEditDialogState();
}

class _BlogEditDialogState extends ConsumerState<_BlogEditDialog> {
  late final TextEditingController _title;
  late final TextEditingController _slug;
  late final TextEditingController _excerpt;
  late final TextEditingController _body;
  late final TextEditingController _coverUrl;
  String? _coverImageUrl;
  String? _categoryId;
  String? _authorId;
  bool _featured = false;
  bool _slugTouched = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final post = widget.post;
    _title = TextEditingController(text: post?.title ?? '');
    _slug = TextEditingController(text: post?.slug ?? '');
    _excerpt = TextEditingController(text: post?.excerpt ?? '');
    _body = TextEditingController(text: post?.body ?? '');
    _coverImageUrl = post?.coverImageUrl;
    _coverUrl = TextEditingController(text: post?.coverImageUrl ?? '');
    _categoryId = post?.categoryId;
    _authorId = post?.blogAuthorId ??
        widget.authors.where((author) => author.isActive).firstOrNull?.id;
    _featured = post?.featured ?? false;
    _slugTouched = post != null && post.slug.isNotEmpty;
  }

  @override
  void dispose() {
    _title.dispose();
    _slug.dispose();
    _excerpt.dispose();
    _body.dispose();
    _coverUrl.dispose();
    super.dispose();
  }

  Future<void> _uploadCover(
    List<int> bytes,
    String contentType,
    String fileName,
    void Function(double progress) onProgress,
  ) async {
    setState(() => _error = null);
    final url = await ref.read(cmsServiceProvider).uploadBlogCover(
      bytes: bytes,
      contentType: contentType,
      blogId: widget.post?.id,
      onProgress: onProgress,
    );
    if (!mounted) return;
    setState(() => _coverImageUrl = url);
    _coverUrl.text = url;
  }

  Future<void> _save({required bool publish}) async {
    final fromField = _coverUrl.text.trim();
    final cover = fromField.isNotEmpty ? fromField : (_coverImageUrl ?? '').trim();
    final error = blogPublishValidationError(
      title: _title.text,
      slug: _slug.text,
      coverImageUrl: cover,
      publish: publish,
    );
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _coverImageUrl = cover.isEmpty ? null : cover;
    });
    try {
      final excerpt = _excerpt.text.trim();
      await ref.read(cmsServiceProvider).upsertBlog(
        id: widget.post?.id,
        title: _title.text.trim(),
        slug: _slug.text.trim(),
        excerpt: excerpt.isEmpty ? null : excerpt,
        coverImageUrl: _coverImageUrl,
        body: _body.text.trim(),
        categoryId: _categoryId,
        blogAuthorId: _authorId,
        isPublished: publish,
        featured: _featured,
        publishedAt: publish && widget.post?.isPublished == true
            ? widget.post?.publishedAt
            : null,
      );
      bumpBlogCmsTickFromWidget(ref);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      setState(() => _error = userFacingError(error, fallback: 'Unable to save the post.'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authors = widget.authors.where((author) {
      return author.isActive || author.id == _authorId;
    }).toList();
    return _EditorFrame(
      title: widget.post == null ? 'New post' : 'Edit post',
      wide: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _title,
            style: const TextStyle(color: Colors.white),
            decoration: _fieldDecoration('Title'),
            onChanged: (value) {
              if (!_slugTouched) _slug.text = _slugify(value);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _slug,
            style: const TextStyle(color: Colors.white),
            decoration: _fieldDecoration('Slug', prefix: '/blog/'),
            onChanged: (_) => _slugTouched = true,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: _categoryId,
            dropdownColor: const Color(0xFF141820),
            style: const TextStyle(color: Colors.white),
            decoration: _fieldDecoration('Topic'),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('Uncategorized')),
              ...widget.categories.map(
                (category) => DropdownMenuItem<String?>(
                  value: category.id,
                  child: Text(category.name),
                ),
              ),
            ],
            onChanged: (value) => setState(() => _categoryId = value),
          ),
          if (authors.isNotEmpty) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _authorId,
              dropdownColor: const Color(0xFF141820),
              style: const TextStyle(color: Colors.white),
              decoration: _fieldDecoration('Author'),
              items: [
                for (final author in authors)
                  DropdownMenuItem<String?>(
                    value: author.id,
                    child: Text(author.displayName),
                  ),
              ],
              onChanged: (value) => setState(() => _authorId = value),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _excerpt,
            minLines: 2,
            maxLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: _fieldDecoration('Excerpt'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _body,
            minLines: 8,
            maxLines: 14,
            style: const TextStyle(color: Colors.white),
            decoration: _fieldDecoration(
              'Body',
              hint: 'Plain text or markdown headings (## Heading)',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _coverUrl,
            style: const TextStyle(color: Colors.white),
            decoration: _fieldDecoration(
              'Cover image URL',
              hint: 'Required before a post can go live',
            ),
            onChanged: (value) => setState(
              () => _coverImageUrl = value.trim().isEmpty ? null : value.trim(),
            ),
          ),
          if (_coverImageUrl != null && _coverImageUrl!.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: MediaDeliveryImage(
                url: _coverImageUrl!,
                height: 160,
                fit: BoxFit.cover,
              ),
            ),
          ],
          const SizedBox(height: 12),
          MediaUploadPanel(
            label: 'Upload cover image',
            hint: 'JPEG, PNG, WebP · uploads via Cloudinary',
            allowVideo: false,
            onUpload: _uploadCover,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _featured,
            activeTrackColor: AppColors.gold,
            title: const Text('Featured', style: TextStyle(color: Colors.white)),
            subtitle: const Text(
              'Featured posts are highlighted on the blog.',
              style: TextStyle(color: Color(0xFF9AA1AB)),
            ),
            onChanged: (value) => setState(() => _featured = value),
          ),
          if (_error != null) _ErrorLine(_error!),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              OutlinedButton(
                onPressed: _saving ? null : () => _save(publish: false),
                child: Text(_saving ? 'Saving…' : 'Save draft'),
              ),
              FilledButton(
                onPressed: _saving ? null : () => _save(publish: true),
                child: Text(
                  widget.post?.isPublished == true ? 'Update live post' : 'Publish',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditorFrame extends StatelessWidget {
  const _EditorFrame({
    required this.title,
    required this.child,
    this.wide = false,
  });

  final String title;
  final Widget child;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF12141A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppColors.gold.withValues(alpha: 0.28)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: wide ? 760 : 460, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EditorActions extends StatelessWidget {
  const _EditorActions({
    required this.saving,
    required this.onCancel,
    required this.primaryLabel,
    required this.onPrimary,
  });

  final bool saving;
  final VoidCallback onCancel;
  final String primaryLabel;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(onPressed: saving ? null : onCancel, child: const Text('Cancel')),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: saving ? null : onPrimary,
          child: Text(saving ? 'Saving…' : primaryLabel),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF141820),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x18FFFFFF)),
      ),
      child: Padding(padding: const EdgeInsets.all(14), child: child),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF141820),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.28)),
      ),
      child: Text(
        '$value $label',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFFCA5A5) : const Color(0xFFF5E6B8);
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14, color: color),
      label: Text(label, style: TextStyle(color: color, fontSize: 12)),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator(color: AppColors.gold));
  }
}

class _EmptyPane extends StatelessWidget {
  const _EmptyPane({required this.title, required this.message, this.action});

  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _Panel(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.newspaper, color: AppColors.gold, size: 28),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF9AA1AB)),
              ),
              if (action != null) ...[const SizedBox(height: 14), action!],
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorPane extends StatelessWidget {
  const _ErrorPane({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _Panel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, style: const TextStyle(color: Color(0xFFFCA5A5))),
            const SizedBox(height: 10),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

class _ErrorLine extends StatelessWidget {
  const _ErrorLine(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(message, style: const TextStyle(color: Color(0xFFFCA5A5))),
    );
  }
}

InputDecoration _fieldDecoration(String label, {String? hint, String? prefix}) {
  const border = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
    borderSide: BorderSide(color: Color(0x18FFFFFF)),
  );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixText: prefix,
    filled: true,
    fillColor: const Color(0xFF0E1016),
    labelStyle: const TextStyle(color: Color(0xFF9AA1AB)),
    hintStyle: const TextStyle(color: Color(0xFF6E7682)),
    prefixStyle: const TextStyle(color: Color(0xFF9AA1AB)),
    border: border,
    enabledBorder: border,
    focusedBorder: OutlineInputBorder(
      borderRadius: const BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: AppColors.gold.withValues(alpha: 0.8)),
    ),
  );
}

String _slugify(String value) {
  final lower = value.trim().toLowerCase();
  final replaced = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  return replaced.replaceAll(RegExp(r'^-+|-+$'), '');
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: const Color(0xFF12141A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppColors.gold.withValues(alpha: 0.28)),
      ),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      content: Text(message, style: const TextStyle(color: Color(0xFFC8CDD4))),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7F1D1D)),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result == true;
}

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
