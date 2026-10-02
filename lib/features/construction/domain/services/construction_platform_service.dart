import 'dart:typed_data';

import 'package:hdhomesproject/core/media/media_models.dart';
import 'package:hdhomesproject/core/media/media_service.dart';
import 'package:hdhomesproject/features/construction/domain/entities/construction_platform_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads/writes unified construction progress from Supabase.
class ConstructionPlatformService {
  ConstructionPlatformService({SupabaseClient? client, MediaService? mediaService})
      : _client = client,
        _media = mediaService;

  final SupabaseClient? _client;
  final MediaService? _media;

  SupabaseClient get _c {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    return client;
  }

  /// Published public projects — prefers canonical `construction_projects`, falls back to website CMS.
  Future<List<ConstructionProjectPublic>> listPublicProjects() async {
    final merged = <String, ConstructionProjectPublic>{};

    try {
      final rows = await _c
          .from('construction_projects')
          .select('''
            *,
            project_milestones (id, name, status, progress_pct, due_date, completed_at),
            construction_progress_updates (
              id, project_id, title, short_description, description, progress_pct,
              update_date, status, visibility, is_published, published_at,
              construction_update_media (id, update_id, project_id, media_type, file_url, thumbnail_url, caption, display_order, media_id, media:media_id(secure_url, thumbnail_url))
            )
          ''')
          .eq('is_published_public', true)
          .order('updated_at', ascending: false)
          .limit(50);

      if (rows.isNotEmpty) {
        for (final p in _mapProjectRows(rows)) {
          if (p.slug.isNotEmpty) merged[p.slug] = p;
        }
      }
    } catch (_) {
      // Table/column may not exist yet — fall through to website CMS.
    }

    try {
      final website = await _c
          .from('website_construction_updates')
          .select()
          .eq('is_deleted', false)
          .eq('status', 'active')
          .order('sort_order')
          .limit(50);

      for (final e in website) {
        final project = ConstructionProjectPublic.fromWebsiteRow(
          Map<String, dynamic>.from(e),
        );
        if (project.slug.isNotEmpty && !merged.containsKey(project.slug)) {
          merged[project.slug] = project;
        }
      }
    } catch (_) {}

    if (merged.isEmpty) return [];

    final list = merged.values.toList()
      ..sort((a, b) {
        final ad = a.updatedAt ?? DateTime(1970);
        final bd = b.updatedAt ?? DateTime(1970);
        return bd.compareTo(ad);
      });
    return list;
  }

  Future<ConstructionProjectPublic?> getPublicProjectBySlug(String slug) async {
    try {
      final rows = await _c
          .from('construction_projects')
          .select('''
            *,
            project_milestones (id, name, status, progress_pct, due_date, completed_at),
            construction_progress_updates (
              id, project_id, title, short_description, description, progress_pct,
              update_date, status, visibility, is_published, published_at,
              construction_update_media (id, update_id, project_id, media_type, file_url, thumbnail_url, caption, display_order, media_id, media:media_id(secure_url, thumbnail_url))
            )
          ''')
          .eq('slug', slug)
          .eq('is_published_public', true)
          .limit(1);

      if (rows.isNotEmpty) {
        final mapped = _mapProjectRows(rows);
        return mapped.isEmpty ? null : mapped.first;
      }
    } catch (_) {}

    final website = await _c
        .from('website_construction_updates')
        .select()
        .eq('slug', slug)
        .eq('is_deleted', false)
        .eq('status', 'active')
        .maybeSingle();

    if (website == null) return null;
    return ConstructionProjectPublic.fromWebsiteRow(
      Map<String, dynamic>.from(website),
    );
  }

  List<ConstructionProjectPublic> _mapProjectRows(List<dynamic> rows) {
    return rows.map((row) {
      final map = Map<String, dynamic>.from(row as Map);
      final milestonesRaw = map['project_milestones'] as List? ?? [];
      final milestones = milestonesRaw
          .map((e) => ConstructionMilestonePublic.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList()
        ..sort((a, b) {
          final ad = a.dueDate ?? DateTime(2100);
          final bd = b.dueDate ?? DateTime(2100);
          return ad.compareTo(bd);
        });

      final updatesRaw = map['construction_progress_updates'] as List? ?? [];
      final updates = updatesRaw
          .map((e) => ConstructionProgressUpdate.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .where((u) => u.isPublished && u.visibility.contains('public'))
          .toList()
        ..sort((a, b) {
          final ad = a.publishedAt ?? a.updateDate ?? DateTime(1970);
          final bd = b.publishedAt ?? b.updateDate ?? DateTime(1970);
          return bd.compareTo(ad);
        });

      final gallery = <String>[];
      for (final u in updates) {
        for (final m in u.media) {
          if (m.deliveryUrl.trim().isNotEmpty && !gallery.contains(m.deliveryUrl)) {
            gallery.add(m.deliveryUrl);
          }
        }
      }

      final project = ConstructionProjectPublic.fromConstructionProjectRow(
        map,
        milestones: milestones,
        updates: updates,
      );
      if (gallery.isNotEmpty && project.galleryImageUrls.isEmpty) {
        return ConstructionProjectPublic(
          id: project.id,
          name: project.name,
          slug: project.slug,
          locationLabel: project.locationLabel,
          description: project.description,
          progressPct: project.progressPct,
          coverImageUrl: project.coverImageUrl,
          galleryImageUrls: gallery,
          expectedCompletionLabel: project.expectedCompletionLabel,
          statusUpdate: project.statusUpdate,
          scheduleStatus: project.scheduleStatus,
          isFeatured: project.isFeatured,
          milestones: project.milestones,
          latestUpdates: project.latestUpdates,
          updatedAt: project.updatedAt,
        );
      }
      return project;
    }).toList();
  }

  Future<List<ConstructionProgressUpdate>> listAllUpdates({
    String? projectId,
    bool publishedOnly = false,
    int limit = 60,
  }) async {
    final select = '''
          *,
          construction_projects (id, name, slug),
          construction_update_media (id, update_id, project_id, media_type, file_url, thumbnail_url, caption, display_order, media_id, media:media_id(secure_url, thumbnail_url))
        ''';
    var query = _c
        .from('construction_progress_updates')
        .select(select)
        .eq('is_deleted', false);
    if (projectId != null) {
      query = query.eq('project_id', projectId);
    }
    if (publishedOnly) {
      query = query.eq('is_published', true);
    }
    final rows =
        await query.order('published_at', ascending: false).limit(limit);
    return rows
        .map((e) => ConstructionProgressUpdate.fromJson(
              Map<String, dynamic>.from(e),
            ))
        .toList();
  }

  Future<List<ConstructionProgressUpdate>> listUpdatesForProject(
    String projectId, {
    bool publishedOnly = true,
  }) async {
    final select = '''
          *,
          construction_update_media (id, update_id, project_id, media_type, file_url, thumbnail_url, caption, display_order, media_id, media:media_id(secure_url, thumbnail_url))
        ''';
    final rows = publishedOnly
        ? await _c
            .from('construction_progress_updates')
            .select(select)
            .eq('project_id', projectId)
            .eq('is_deleted', false)
            .eq('is_published', true)
            .order('update_date', ascending: false)
            .limit(100)
        : await _c
            .from('construction_progress_updates')
            .select(select)
            .eq('project_id', projectId)
            .eq('is_deleted', false)
            .order('update_date', ascending: false)
            .limit(100);
    return rows
        .map((e) => ConstructionProgressUpdate.fromJson(
              Map<String, dynamic>.from(e),
            ))
        .toList();
  }

  Future<ConstructionProgressUpdate> createUpdate({
    required String projectId,
    required String title,
    String? shortDescription,
    String? description,
    double? progressPct,
    DateTime? updateDate,
    List<String> visibility = const ['public', 'clients', 'investors'],
    String? phaseId,
    String? milestoneId,
  }) async {
    final row = await _c
        .from('construction_progress_updates')
        .insert({
          'project_id': projectId,
          'title': title.trim(),
          'short_description': shortDescription,
          'description': description,
          'progress_pct': progressPct,
          'update_date': (updateDate ?? DateTime.now()).toIso8601String().split('T').first,
          'visibility': visibility,
          'phase_id': phaseId,
          'milestone_id': milestoneId,
          'status': 'draft',
        })
        .select()
        .single();
    return ConstructionProgressUpdate.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> publishUpdate(String updateId) async {
    await _c.rpc('construction_publish_update', params: {'p_update_id': updateId});
  }

  Future<String> uploadMedia({
    required List<int> bytes,
    required String contentType,
    required String projectId,
    required String updateId,
    String? caption,
    int displayOrder = 0,
    String? fileName,
    void Function(double progress)? onProgress,
  }) async {
    final isVideo = contentType.startsWith('video/');
    final mediaType = isVideo ? 'video' : 'image';
    final media = _media;
    String url;
    String? thumbnailUrl;
    String? mediaId;

    if (media == null || !media.isCloudinaryEnabled) {
      throw StateError(
        'Cloudinary media service is required for construction media uploads.',
      );
    }
    final asset = await media.upload(
      UploadMediaRequest(
        bytes: bytes,
        contentType: contentType,
        originalFilename: fileName ?? 'construction-$mediaType',
        entityType: MediaEntityType.construction,
        entityId: projectId,
        role: isVideo ? 'progress' : 'progress',
        sortOrder: displayOrder,
        onProgress: onProgress,
      ),
    );
    url = asset.deliveryUrl;
    thumbnailUrl = asset.thumbnailUrl;
    mediaId = asset.id;

    await _c.from('construction_update_media').insert({
      'update_id': updateId,
      'project_id': projectId,
      'media_type': mediaType,
      'file_url': url,
      if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
      if (mediaId != null) 'media_id': mediaId,
      'caption': caption,
      'display_order': displayOrder,
    });
    return url;
  }

  Future<void> setProjectPublished({
    required String projectId,
    required bool isPublishedPublic,
    String? coverImageUrl,
    bool? isFeatured,
    String? scheduleStatus,
  }) async {
    await _c.from('construction_projects').update({
      if (coverImageUrl != null) 'cover_image_url': coverImageUrl,
      'is_published_public': isPublishedPublic,
      if (isFeatured != null) 'is_featured': isFeatured,
      if (scheduleStatus != null) 'schedule_status': scheduleStatus,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', projectId);
  }

  /// Sync a CMS website card into the canonical platform (client/investor/public).
  Future<void> syncWebsiteCardToPlatform({
    required String projectName,
    required String slug,
    String statusUpdate = '',
    String expectedCompletion = '',
    double progressPct = 0,
    String? coverImageUrl,
    List<String> galleryImageUrls = const [],
    bool published = true,
  }) async {
    final normalizedSlug = slug.trim().toLowerCase();
    if (normalizedSlug.isEmpty) return;

    var projectRow = await _c
        .from('construction_projects')
        .select('id, project_code')
        .eq('slug', normalizedSlug)
        .maybeSingle();

    String projectId;
    if (projectRow == null) {
      final codeBase = normalizedSlug
          .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
          .toUpperCase();
      final projectCode = 'WEB-${codeBase.length > 24 ? codeBase.substring(0, 24) : codeBase}';
      final inserted = await _c
          .from('construction_projects')
          .insert({
            'project_code': projectCode,
            'name': projectName.trim(),
            'slug': normalizedSlug,
            'progress_pct': progressPct,
            'cover_image_url': coverImageUrl,
            'status': 'active',
            'is_published_public': published,
          })
          .select('id')
          .single();
      projectId = inserted['id'] as String;
    } else {
      projectId = projectRow['id'] as String;
      await _c.from('construction_projects').update({
        'name': projectName.trim(),
        'progress_pct': progressPct,
        if (coverImageUrl != null) 'cover_image_url': coverImageUrl,
        'is_published_public': published,
        'status': published ? 'active' : 'draft',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', projectId);
    }

    if (!published) return;

    final title = statusUpdate.trim().isEmpty
        ? '$projectName site progress'
        : statusUpdate.trim();
    final update = await createUpdate(
      projectId: projectId,
      title: title,
      shortDescription: expectedCompletion.trim().isEmpty
          ? null
          : 'Expected completion: ${expectedCompletion.trim()}',
      description: statusUpdate.trim().isEmpty ? null : statusUpdate.trim(),
      progressPct: progressPct,
      visibility: const ['public', 'clients', 'investors'],
    );

    final mediaUrls = <String>[
      if (coverImageUrl != null && coverImageUrl.trim().isNotEmpty)
        coverImageUrl.trim(),
      ...galleryImageUrls.where((u) => u.trim().isNotEmpty),
    ];
    var order = 0;
    for (final url in mediaUrls) {
      await _c.from('construction_update_media').insert({
        'update_id': update.id,
        'project_id': projectId,
        'media_type': 'image',
        'file_url': url,
        'display_order': order++,
      });
    }

    await publishUpdate(update.id);
    await setProjectPublished(
      projectId: projectId,
      isPublishedPublic: true,
      coverImageUrl: coverImageUrl,
    );
  }
}
