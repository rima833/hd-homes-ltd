import 'dart:typed_data';

import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/media/media_delivery.dart';
import 'package:hdhomesproject/core/media/media_models.dart';
import 'package:hdhomesproject/core/media/media_service.dart';
import 'package:hdhomesproject/features/contact/domain/entities/office_directory_models.dart';
import 'package:hdhomesproject/features/cms/domain/entities/property_listings_insights.dart';
import 'package:hdhomesproject/features/cms/domain/data/homepage_section_defaults.dart';
import 'package:hdhomesproject/features/cms/domain/data/hub_page_cms.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/properties/data/models/property_detail_extras.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Website CMS service — all Supabase reads/writes for the Admin "Website"
/// control center (homepage sections, hero, pages, banners, SEO, media,
/// blog, estates, featured properties, testimonials, team, FAQs).
///
/// Mirrors the shape of `InvestorService`: the [SupabaseClient] is optional
/// so widgets can render an empty/"not configured" state instead of
/// crashing when Supabase hasn't been initialized.
class CmsService {
  CmsService({SupabaseClient? client, MediaService? mediaService})
    : _client = client,
      _media = mediaService;

  final SupabaseClient? _client;
  final MediaService? _media;

  SupabaseClient get _c {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase is not configured');
    }
    return client;
  }

  String _nowIso() => DateTime.now().toIso8601String();

  // ───────────────────────────────────────────────────────────────────────
  // Homepage sections (cms_sections)
  // ───────────────────────────────────────────────────────────────────────

  Future<List<CmsSectionRecord>> listHomepageSections() async {
    final rows = await _c
        .from('cms_sections')
        .select()
        .like('section_key', 'homepage_%')
        .order('sort_order');
    return rows
        .map((e) => CmsSectionRecord.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Inserts any missing homepage sections, fills empty `content`, and
  /// syncs `sort_order` to the canonical public layout.
  Future<List<CmsSectionRecord>> ensureHomepageSections({
    bool fillEmptyContent = true,
    bool syncSortOrder = true,
  }) async {
    final existing = await listHomepageSections();
    final seeds = buildDefaultHomepageSectionSeeds();
    final byKey = {for (final s in existing) s.sectionKey: s};

    final toInsert = <Map<String, dynamic>>[];
    for (final seed in seeds) {
      final key = seed['section_key'] as String;
      final current = byKey[key];
      final seedContent = Map<String, dynamic>.from(seed['content'] as Map);
      final seedOrder = seed['sort_order'] as int;
      if (current == null) {
        toInsert.add(seed);
        continue;
      }
      if (syncSortOrder && current.sortOrder != seedOrder) {
        await updateSectionOrder(current.id, seedOrder);
      }
      if (!fillEmptyContent) continue;
      if (!_homepageContentNeedsSeed(key, current.content)) continue;
      await updateSectionContent(
        current.id,
        title: seed['title'] as String?,
        content: seedContent,
      );
    }

    if (toInsert.isNotEmpty) {
      await _c.from('cms_sections').insert(toInsert);
    }
    return listHomepageSections();
  }

  /// True when section content is empty / placeholder and should be seeded.
  bool _homepageContentNeedsSeed(String key, Map<String, dynamic> content) {
    final kind = homepageEditorKind(key);
    if (kind == 'managed_elsewhere' ||
        kind == 'hero_link' ||
        kind == 'visibility_only') {
      return false;
    }
    if (content.isEmpty) return true;

    switch (kind) {
      case 'about':
        return !_hasNonEmptyString(content, 'title') &&
            !_hasNonEmptyString(content, 'story');
      case 'executive':
        // A blank quote is a real saved state. Fill only a row that was never edited.
        return !content.containsKey('message') && !content.containsKey('name');
      case 'cta':
        return !_hasNonEmptyString(content, 'headline') &&
            !_hasNonEmptyString(content, 'title');
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
        final items = content['items'];
        return items is! List || items.isEmpty;
      default:
        // Ignore note/limit/key-only placeholders.
        final useful = content.keys
            .where((k) => k != 'note' && k != 'limit' && k != 'key')
            .toList();
        return useful.isEmpty;
    }
  }

  bool _hasNonEmptyString(Map<String, dynamic> map, String key) {
    final v = map[key];
    return v is String && v.trim().isNotEmpty;
  }

  Future<void> updateSectionVisibility(String id, bool isVisible) async {
    await _c
        .from('cms_sections')
        .update({'is_visible': isVisible, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  Future<void> updateSectionOrder(String id, int sortOrder) async {
    await _c
        .from('cms_sections')
        .update({'sort_order': sortOrder, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  /// Persists a full reordered list — writes `sort_order` sequentially.
  Future<void> reorderSections(List<CmsSectionRecord> ordered) async {
    for (var i = 0; i < ordered.length; i++) {
      await updateSectionOrder(ordered[i].id, i);
    }
  }

  Future<void> updateSectionContent(
    String id, {
    String? title,
    Map<String, dynamic>? content,
  }) async {
    await _c
        .from('cms_sections')
        .update({
          if (title != null) 'title': title,
          if (content != null) 'content': content,
          'updated_at': _nowIso(),
        })
        .eq('id', id);
  }

  Future<CmsSectionRecord> upsertSection({
    String? id,
    required String sectionKey,
    String sectionType = 'block',
    String? title,
    Map<String, dynamic> content = const {},
    int sortOrder = 0,
    bool isVisible = true,
    String? pageId,
  }) async {
    final payload = {
      if (id != null) 'id': id,
      'section_key': sectionKey,
      'section_type': sectionType,
      'title': title,
      'content': content,
      'sort_order': sortOrder,
      'is_visible': isVisible,
      'page_id': pageId,
      'updated_at': _nowIso(),
    };
    final row = await _c.from('cms_sections').upsert(payload).select().single();
    return CmsSectionRecord.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> deleteSection(String id) async {
    await _c.from('cms_sections').delete().eq('id', id);
  }

  // ───────────────────────────────────────────────────────────────────────
  // Hero manager (hero_sections)
  // ───────────────────────────────────────────────────────────────────────

  Future<CmsHeroSection> getHero({String pageKey = 'homepage'}) async {
    final row = await _c
        .from('hero_sections')
        .select()
        .eq('page_key', pageKey)
        .maybeSingle();
    if (row == null) return CmsHeroSection(pageKey: pageKey);
    return CmsHeroSection.fromJson(Map<String, dynamic>.from(row));
  }

  /// Public homepage — published hero only (`status = active`).
  Future<CmsHeroSection?> getPublishedHero({
    String pageKey = 'homepage',
  }) async {
    final row = await _c
        .from('hero_sections')
        .select()
        .eq('page_key', pageKey)
        .eq('status', 'active')
        .eq('is_deleted', false)
        .maybeSingle();
    if (row == null) return null;
    return CmsHeroSection.fromJson(Map<String, dynamic>.from(row));
  }

  Future<CmsHeroSection> upsertHero(CmsHeroSection hero) async {
    final prepared = await _ensureHeroCloudinaryUrls(hero);
    final row = await _c
        .from('hero_sections')
        .upsert(prepared.toUpsertJson(), onConflict: 'page_key')
        .select()
        .single();
    return CmsHeroSection.fromJson(Map<String, dynamic>.from(row));
  }

  /// Uploads hero image or video via Cloudinary only.
  /// Returns the delivery URL.
  Future<String> uploadHeroMedia({
    required List<int> bytes,
    required String contentType,
    String pageKey = 'homepage',
    required String kind, // 'image' | 'video'
    void Function(double progress)? onProgress,
  }) async {
    return _uploadPublicBytes(
      bucket: 'marketing',
      bytes: bytes,
      contentType: contentType,
      folder: 'hero/$pageKey',
      fileNameHint: '$kind-${DateTime.now().millisecondsSinceEpoch}',
      entityType: MediaEntityType.marketing,
      onProgress: onProgress,
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // Pages (pages)
  // ───────────────────────────────────────────────────────────────────────

  Future<List<CmsPageRecord>> listPages() async {
    final rows = await _c
        .from('pages')
        .select()
        .eq('is_deleted', false)
        .order('updated_at', ascending: false);
    return rows
        .map((e) => CmsPageRecord.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<CmsPageRecord> upsertPage({
    String? id,
    required String title,
    required String slug,
    Map<String, dynamic> content = const {},
    String? metaTitle,
    String? metaDescription,
  }) async {
    final payload = {
      if (id != null) 'id': id,
      'title': title,
      'slug': slug,
      'content': content,
      'meta_title': metaTitle,
      'meta_description': metaDescription,
      'updated_at': _nowIso(),
    };
    final row = await _c
        .from('pages')
        .upsert(payload, onConflict: 'slug')
        .select()
        .single();
    return CmsPageRecord.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> setPageStatus(String id, {required bool isPublished}) async {
    await _c
        .from('pages')
        .update({
          'is_published': isPublished,
          'published_at': isPublished ? _nowIso() : null,
          'updated_at': _nowIso(),
        })
        .eq('id', id);
  }

  Future<void> deletePage(String id) async {
    await _c
        .from('pages')
        .update({'is_deleted': true, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  /// Public page by slug (published only).
  Future<CmsPageRecord?> getPublishedPageBySlug(String slug) async {
    final row = await _c
        .from('pages')
        .select()
        .eq('slug', slug)
        .eq('is_deleted', false)
        .eq('is_published', true)
        .maybeSingle();
    if (row == null) return null;
    return CmsPageRecord.fromJson(Map<String, dynamic>.from(row));
  }

  /// Published CMS pages for public surfaces (legal docs, hubs, static pages).
  Future<List<CmsPageRecord>> listPublishedPages() async {
    final rows = await _c
        .from('pages')
        .select()
        .eq('is_deleted', false)
        .eq('is_published', true)
        .order('title');
    return rows
        .map((e) => CmsPageRecord.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Ensures published hub pages exist so Admin → Website → Pages can edit
  /// public hero copy for marketplace, estates, services, etc.
  Future<int> ensurePublicHubPages({bool fillEmptyHero = true}) async {
    final existing = await listPages();
    final bySlug = {for (final p in existing) p.slug: p};
    var created = 0;

    for (final seed in [...kPublicHubPageSeeds, ...kLegalPageSeeds]) {
      final slug = seed['slug'] as String;
      final title = seed['title'] as String;
      final content = Map<String, dynamic>.from(seed['content'] as Map);
      final metaTitle = seed['meta_title'] as String?;
      final metaDescription = seed['meta_description'] as String?;
      final current = bySlug[slug];

      if (current == null) {
        await _c.from('pages').insert({
          'title': title,
          'slug': slug,
          'content': content,
          'meta_title': metaTitle,
          'meta_description': metaDescription,
          'is_published': true,
          'published_at': _nowIso(),
          'status': 'active',
          'updated_at': _nowIso(),
        });
        created++;
        continue;
      }

      if (!fillEmptyHero) continue;
      final merged = Map<String, dynamic>.from(current.content);
      var changed = false;
      for (final entry in content.entries) {
        final existingVal = merged[entry.key];
        final empty =
            existingVal == null ||
            (existingVal is String && existingVal.trim().isEmpty);
        if (empty) {
          merged[entry.key] = entry.value;
          changed = true;
        }
      }
      if (changed) {
        await upsertPage(
          id: current.id,
          title: current.title,
          slug: current.slug,
          content: merged,
          metaTitle: current.metaTitle ?? metaTitle,
          metaDescription: current.metaDescription ?? metaDescription,
        );
      }
      if (!current.isPublished) {
        await setPageStatus(current.id, isPublished: true);
      }
    }
    return created;
  }

  // ───────────────────────────────────────────────────────────────────────
  // Banners (banners)
  // ───────────────────────────────────────────────────────────────────────

  Future<List<CmsBanner>> listBanners() async {
    final rows = await _c
        .from('banners')
        .select()
        .eq('is_deleted', false)
        .order('sort_order');
    return rows
        .map((e) => CmsBanner.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<CmsBanner> upsertBanner({
    String? id,
    required String title,
    String? subtitle,
    String? imageUrl,
    String? linkUrl,
    int sortOrder = 0,
    DateTime? startsAt,
    DateTime? endsAt,
    String status = 'active',
  }) async {
    MediaDelivery.assertCloudinaryMediaUrl(imageUrl, field: 'Banner image');
    final payload = {
      if (id != null) 'id': id,
      'title': title,
      'subtitle': subtitle,
      'image_url': imageUrl,
      'link_url': linkUrl,
      'sort_order': sortOrder,
      'starts_at': startsAt?.toIso8601String(),
      'ends_at': endsAt?.toIso8601String(),
      'status': status == 'active' ? 'active' : 'inactive',
      'updated_at': _nowIso(),
    };
    final row = await _c.from('banners').upsert(payload).select().single();
    return CmsBanner.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> deleteBanner(String id) async {
    await _c
        .from('banners')
        .update({'is_deleted': true, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  Future<void> setBannerActive(String id, bool active) async {
    await _c
        .from('banners')
        .update({
          'status': active ? 'active' : 'inactive',
          'updated_at': _nowIso(),
        })
        .eq('id', id);
  }

  Future<String> uploadBannerImage({
    required List<int> bytes,
    required String contentType,
  }) => _uploadPublicImage(
    bucket: 'marketing',
    bytes: bytes,
    contentType: contentType,
    folder: 'banners',
  );

  Future<String> uploadMarketingAsset({
    required List<int> bytes,
    required String contentType,
    required String folder,
  }) => _uploadPublicImage(
    bucket: 'marketing',
    bytes: bytes,
    contentType: contentType,
    folder: folder,
  );

  Future<String> uploadTestimonialAvatar({
    required List<int> bytes,
    required String contentType,
  }) => _uploadPublicImage(
    bucket: 'avatars',
    bytes: bytes,
    contentType: contentType,
    folder: 'testimonials',
  );

  Future<String> uploadTeamPhoto({
    required String employeeId,
    required List<int> bytes,
    required String contentType,
  }) async {
    final url = await _uploadPublicImage(
      bucket: 'team',
      bytes: bytes,
      contentType: contentType,
      folder: employeeId,
    );
    await _c
        .from('employees')
        .update({'avatar_url': url, 'updated_at': _nowIso()})
        .eq('id', employeeId);
    return url;
  }

  // ───────────────────────────────────────────────────────────────────────
  // SEO (seo_metadata)
  // ───────────────────────────────────────────────────────────────────────

  Future<List<CmsSeoRecord>> listSeo({String? entityType}) async {
    var query = _c.from('seo_metadata').select();
    if (entityType != null) {
      query = query.eq('entity_type', entityType);
    }
    final rows = await query.order('updated_at', ascending: false);
    return rows
        .map((e) => CmsSeoRecord.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<CmsSeoRecord> upsertSeo({
    String? id,
    required String entityType,
    String? entityId,
    String? path,
    String? metaTitle,
    String? metaDescription,
    String? canonicalUrl,
    String? ogImageUrl,
  }) async {
    final audit = SeoContentAudit.evaluate(
      path: path,
      metaTitle: metaTitle,
      metaDescription: metaDescription,
      canonicalUrl: canonicalUrl,
      ogImageUrl: ogImageUrl,
    );
    var resolvedId = id;
    final route = path?.trim() ?? '';
    if (resolvedId == null && route.isNotEmpty) {
      final existing = await _c
          .from('seo_metadata')
          .select('id')
          .eq('path', route)
          .order('updated_at', ascending: false)
          .limit(1);
      if (existing.isNotEmpty) {
        resolvedId = existing.first['id'] as String?;
      }
    }
    final payload = {
      'id': ?resolvedId,
      'entity_type': entityType,
      'entity_id': entityId,
      'path': path,
      'meta_title': metaTitle,
      'meta_description': metaDescription,
      'canonical_url': canonicalUrl,
      'og_image_url': ogImageUrl,
      'health_score': audit.score,
      'issue_count': audit.issues.length,
      'issues': audit.issueMaps,
      'last_audit_at': _nowIso(),
      'updated_at': _nowIso(),
    };
    final row = await _c.from('seo_metadata').upsert(payload).select().single();
    return CmsSeoRecord.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> deleteSeo(String id) async {
    await _c.from('seo_metadata').delete().eq('id', id);
  }

  // ───────────────────────────────────────────────────────────────────────
  // Media library (media / media_library view / media_folders)
  // ───────────────────────────────────────────────────────────────────────

  Future<List<CmsMediaAsset>> listMedia({String? folder}) async {
    var query = _c.from('media_library').select();
    if (folder != null && folder.isNotEmpty) {
      query = query.eq('folder_name', folder);
    }
    try {
      final rows = await query.order('created_at', ascending: false);
      return _uniqueMedia(
        rows
            .map((e) => CmsMediaAsset.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
    } catch (_) {
      // Fallback: view may not exist on older schemas — read base table.
      final rows = await _c
          .from('media')
          .select()
          .eq('is_deleted', false)
          .order('created_at', ascending: false);
      return _uniqueMedia(
        rows
            .map((e) => CmsMediaAsset.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
    }
  }

  /// Same bytes and pixel size are one asset. Keeps the first row (newest).
  List<CmsMediaAsset> _uniqueMedia(List<CmsMediaAsset> assets) {
    final seen = <String>{};
    final unique = <CmsMediaAsset>[];
    for (final asset in assets) {
      final key = asset.fileSize != null &&
              asset.width != null &&
              asset.height != null
          ? '${asset.fileSize}|${asset.width}|${asset.height}|${asset.fileType}'
          : (asset.cloudinaryPublicId ?? asset.deliveryUrl);
      if (key.isEmpty || !seen.add(key)) {
        if (key.isEmpty) unique.add(asset);
        continue;
      }
      unique.add(asset);
    }
    return unique;
  }

  Future<List<String>> listMediaFolders() async {
    try {
      final rows = await _c.from('media_folders').select('name').order('name');
      return rows
          .map((e) => Map<String, dynamic>.from(e)['name'] as String)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<String> uploadMediaFile({
    required List<int> bytes,
    required String contentType,
    String folder = 'library',
    String? fileName,
    void Function(double progress)? onProgress,
  }) async {
    final media = _media;
    if (media == null || !media.isCloudinaryEnabled) {
      throw StateError('Cloudinary is required for media library uploads.');
    }
    final asset = await media.upload(
      UploadMediaRequest(
        bytes: bytes,
        contentType: contentType,
        originalFilename: fileName ?? 'upload',
        entityType: MediaEntityType.library,
        folderName: folder,
        role: 'website',
        onProgress: onProgress,
      ),
    );
    return asset.deliveryUrl;
  }

  Future<CmsMediaAsset> createMediaAsset({
    required String title,
    required String fileUrl,
    String fileType = 'image',
    String? altText,
    String? folderName,
    String? secureUrl,
    String? cloudinaryPublicId,
    String storageProvider = 'supabase',
  }) async {
    String? folderId;
    if (folderName != null && folderName.isNotEmpty) {
      final slug = folderName.toLowerCase().trim().replaceAll(
        RegExp(r'[^a-z0-9]+'),
        '-',
      );
      final existing = await _c
          .from('media_folders')
          .select('id')
          .eq('slug', slug)
          .maybeSingle();
      if (existing != null) {
        folderId = existing['id'] as String;
      } else {
        final created = await _c
            .from('media_folders')
            .insert({'name': folderName, 'slug': slug})
            .select('id')
            .single();
        folderId = created['id'] as String;
      }
    }

    final row = await _c
        .from('media')
        .insert({
          'title': title,
          'file_url': fileUrl,
          if (secureUrl != null) 'secure_url': secureUrl,
          if (cloudinaryPublicId != null)
            'cloudinary_public_id': cloudinaryPublicId,
          'storage_provider': storageProvider,
          'file_type': fileType,
          'alt_text': altText,
          'folder_id': folderId,
          'entity_type': MediaEntityType.library.value,
        })
        .select()
        .single();
    return CmsMediaAsset.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> deleteMediaAsset(String id) async {
    final media = _media;
    if (media != null && media.isCloudinaryEnabled) {
      await media.delete(id);
      return;
    }
    await _c
        .from('media')
        .update({'is_deleted': true, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  Future<void> setMediaPublished(String id, bool published) async {
    await _c
        .from('media')
        .update({'is_published': published, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  Future<void> updateMediaAltText(String id, String altText) async {
    final media = _media;
    if (media != null) {
      await media.updateMediaMetadata(mediaId: id, altText: altText);
      return;
    }
    await _c
        .from('media')
        .update({'alt_text': altText, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  Future<void> replaceMediaAsset({
    required String id,
    required List<int> bytes,
    required String contentType,
    required String fileName,
  }) async {
    final media = _media;
    if (media == null || !media.isCloudinaryEnabled) {
      throw StateError('Cloudinary media service is not configured.');
    }
    await media.replace(
      mediaId: id,
      request: UploadMediaRequest(
        bytes: bytes,
        contentType: contentType,
        originalFilename: fileName,
        entityType: MediaEntityType.library,
      ),
    );
  }

  /// Staff one-shot: server-side batch migrate property/blog/estate legacy URLs.
  Future<Map<String, dynamic>> migrateLegacyMediaBatch({int limit = 40}) async {
    final media = _media;
    if (media == null || !media.isCloudinaryEnabled) {
      throw StateError('Cloudinary media service is required for migration.');
    }
    final response = await _c.functions.invoke(
      'cloudinary-migrate-batch',
      body: {'limit': limit},
    );
    if (response.status != 200) {
      throw StateError(
        'Batch migration failed (${response.status}): ${response.data}',
      );
    }
    final data = response.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {'ok': true, 'raw': data};
  }

  /// Migrate legacy property_images Storage/Unsplash URLs into Cloudinary.
  /// Does not delete source files. Returns counts: migrated / skipped / failed.
  Future<Map<String, int>> migrateLegacyPropertyImages({int limit = 50}) async {
    final media = _media;
    if (media == null || !media.isCloudinaryEnabled) {
      throw StateError('Cloudinary media service is required for migration.');
    }
    final rows = await _c
        .from('property_images')
        .select('id, property_id, url, media_id, is_cover, sort_order')
        .eq('is_deleted', false)
        .limit(limit);
    var migrated = 0;
    var skipped = 0;
    var failed = 0;
    for (final raw in rows as List) {
      final row = Map<String, dynamic>.from(raw as Map);
      final url = (row['url'] as String?)?.trim() ?? '';
      final propertyId = row['property_id']?.toString() ?? '';
      final imageId = row['id']?.toString() ?? '';
      if (url.isEmpty || propertyId.isEmpty || imageId.isEmpty) {
        skipped++;
        continue;
      }
      if (url.contains('res.cloudinary.com') && row['media_id'] != null) {
        skipped++;
        continue;
      }
      try {
        final asset = await media.migrateFromUrl(
          sourceUrl: url,
          entityType: MediaEntityType.property,
          entityId: propertyId,
          mediaId: row['media_id']?.toString(),
          role: 'gallery',
        );
        await _c
            .from('property_images')
            .update({
              'url': asset.deliveryUrl,
              'media_id': asset.id,
              'updated_at': _nowIso(),
            })
            .eq('id', imageId);
        if (row['is_cover'] == true) {
          await media.setCover(
            entityType: MediaEntityType.property,
            entityId: propertyId,
            mediaId: asset.id,
          );
        }
        migrated++;
      } catch (_) {
        failed++;
      }
    }
    return {'migrated': migrated, 'skipped': skipped, 'failed': failed};
  }

  /// Migrate blog cover_image_url values that are not yet on Cloudinary.
  Future<Map<String, int>> migrateLegacyBlogCovers({int limit = 50}) async {
    final media = _media;
    if (media == null || !media.isCloudinaryEnabled) {
      throw StateError('Cloudinary media service is required for migration.');
    }
    final rows = await _c
        .from('blogs')
        .select('id, cover_image_url, media_id')
        .eq('is_deleted', false)
        .not('cover_image_url', 'is', null)
        .limit(limit);
    var migrated = 0;
    var skipped = 0;
    var failed = 0;
    for (final raw in rows as List) {
      final row = Map<String, dynamic>.from(raw as Map);
      final url = (row['cover_image_url'] as String?)?.trim() ?? '';
      final blogId = row['id']?.toString() ?? '';
      if (url.isEmpty || blogId.isEmpty) {
        skipped++;
        continue;
      }
      if (url.contains('res.cloudinary.com') && row['media_id'] != null) {
        skipped++;
        continue;
      }
      try {
        final asset = await media.migrateFromUrl(
          sourceUrl: url,
          entityType: MediaEntityType.blog,
          entityId: blogId,
          mediaId: row['media_id']?.toString(),
          role: 'featured',
        );
        await _c
            .from('blogs')
            .update({
              'cover_image_url': asset.deliveryUrl,
              'media_id': asset.id,
              'updated_at': _nowIso(),
            })
            .eq('id', blogId);
        migrated++;
      } catch (_) {
        failed++;
      }
    }
    return {'migrated': migrated, 'skipped': skipped, 'failed': failed};
  }

  /// Migrate homepage/hub hero image + video off Supabase Storage / Unsplash.
  Future<Map<String, int>> migrateLegacyWebsiteHeroMedia({
    int limit = 40,
  }) async {
    final media = _media;
    if (media == null || !media.isCloudinaryEnabled) {
      throw StateError('Cloudinary media service is required for migration.');
    }
    final rows = await _c
        .from('hero_sections')
        .select('id, page_key, background_url, content')
        .eq('is_deleted', false)
        .limit(limit);
    var migrated = 0;
    var skipped = 0;
    var failed = 0;
    for (final raw in rows as List) {
      final row = Map<String, dynamic>.from(raw as Map);
      final id = row['id']?.toString() ?? '';
      if (id.isEmpty) {
        skipped++;
        continue;
      }
      try {
        final content = Map<String, dynamic>.from(
          (row['content'] as Map?) ?? const {},
        );
        var changed = false;
        var background = (row['background_url'] as String?)?.trim() ?? '';
        if (background.isNotEmpty &&
            !MediaDelivery.isCloudinaryUrl(background)) {
          final asset = await media.migrateFromUrl(
            sourceUrl: background,
            entityType: MediaEntityType.marketing,
            role: 'marketing',
            resourceType: MediaResourceType.image,
          );
          background = asset.deliveryUrl;
          changed = true;
        }
        final videoKey = content.containsKey('video_url')
            ? 'video_url'
            : (content.containsKey('videoUrl') ? 'videoUrl' : 'video_url');
        final video = '${content[videoKey] ?? ''}'.trim();
        if (video.isNotEmpty && !MediaDelivery.isCloudinaryUrl(video)) {
          final asset = await media.migrateFromUrl(
            sourceUrl: video,
            entityType: MediaEntityType.marketing,
            role: 'marketing',
            resourceType: MediaResourceType.video,
          );
          content['video_url'] = asset.deliveryUrl;
          content.remove('videoUrl');
          changed = true;
        }
        if (!changed) {
          skipped++;
          continue;
        }
        await _c
            .from('hero_sections')
            .update({
              'background_url': background.isEmpty ? null : background,
              'content': content,
              'updated_at': _nowIso(),
            })
            .eq('id', id);
        migrated++;
      } catch (_) {
        failed++;
      }
    }
    return {'migrated': migrated, 'skipped': skipped, 'failed': failed};
  }

  /// Migrate banner image_url values that are not yet on Cloudinary.
  Future<Map<String, int>> migrateLegacyBannerImages({int limit = 50}) async {
    final media = _media;
    if (media == null || !media.isCloudinaryEnabled) {
      throw StateError('Cloudinary media service is required for migration.');
    }
    final rows = await _c
        .from('banners')
        .select('id, image_url')
        .eq('is_deleted', false)
        .not('image_url', 'is', null)
        .limit(limit);
    var migrated = 0;
    var skipped = 0;
    var failed = 0;
    for (final raw in rows as List) {
      final row = Map<String, dynamic>.from(raw as Map);
      final id = row['id']?.toString() ?? '';
      final url = (row['image_url'] as String?)?.trim() ?? '';
      if (id.isEmpty || url.isEmpty) {
        skipped++;
        continue;
      }
      if (MediaDelivery.isCloudinaryUrl(url)) {
        skipped++;
        continue;
      }
      try {
        final asset = await media.migrateFromUrl(
          sourceUrl: url,
          entityType: MediaEntityType.marketing,
          role: 'banners',
        );
        await _c
            .from('banners')
            .update({'image_url': asset.deliveryUrl, 'updated_at': _nowIso()})
            .eq('id', id);
        migrated++;
      } catch (_) {
        failed++;
      }
    }
    return {'migrated': migrated, 'skipped': skipped, 'failed': failed};
  }

  /// Migrate partner logo_url values that are not yet on Cloudinary.
  Future<Map<String, int>> migrateLegacyPartnerLogos({int limit = 50}) async {
    final media = _media;
    if (media == null || !media.isCloudinaryEnabled) {
      throw StateError('Cloudinary media service is required for migration.');
    }
    final rows = await _c
        .from('partners')
        .select('id, logo_url')
        .eq('is_deleted', false)
        .not('logo_url', 'is', null)
        .limit(limit);
    var migrated = 0;
    var skipped = 0;
    var failed = 0;
    for (final raw in rows as List) {
      final row = Map<String, dynamic>.from(raw as Map);
      final id = row['id']?.toString() ?? '';
      final url = (row['logo_url'] as String?)?.trim() ?? '';
      if (id.isEmpty || url.isEmpty) {
        skipped++;
        continue;
      }
      if (MediaDelivery.isCloudinaryUrl(url)) {
        skipped++;
        continue;
      }
      try {
        final asset = await media.migrateFromUrl(
          sourceUrl: url,
          entityType: MediaEntityType.marketing,
          entityId: id,
          role: 'branding',
        );
        await _c
            .from('partners')
            .update({
              'logo_url': asset.deliveryUrl,
              'media_id': asset.id,
              'updated_at': _nowIso(),
            })
            .eq('id', id);
        migrated++;
      } catch (_) {
        failed++;
      }
    }
    return {'migrated': migrated, 'skipped': skipped, 'failed': failed};
  }

  /// Migrate testimonial avatar_url values that are not yet on Cloudinary.
  Future<Map<String, int>> migrateLegacyTestimonialAvatars({
    int limit = 50,
  }) async {
    final media = _media;
    if (media == null || !media.isCloudinaryEnabled) {
      throw StateError('Cloudinary media service is required for migration.');
    }
    final rows = await _c
        .from('testimonials')
        .select('id, avatar_url')
        .eq('is_deleted', false)
        .not('avatar_url', 'is', null)
        .limit(limit);
    var migrated = 0;
    var skipped = 0;
    var failed = 0;
    for (final raw in rows as List) {
      final row = Map<String, dynamic>.from(raw as Map);
      final id = row['id']?.toString() ?? '';
      final url = (row['avatar_url'] as String?)?.trim() ?? '';
      if (id.isEmpty || url.isEmpty) {
        skipped++;
        continue;
      }
      if (MediaDelivery.isCloudinaryUrl(url)) {
        skipped++;
        continue;
      }
      try {
        final asset = await media.migrateFromUrl(
          sourceUrl: url,
          entityType: MediaEntityType.marketing,
          entityId: id,
          role: 'avatar',
        );
        await _c
            .from('testimonials')
            .update({'avatar_url': asset.deliveryUrl, 'updated_at': _nowIso()})
            .eq('id', id);
        migrated++;
      } catch (_) {
        failed++;
      }
    }
    return {'migrated': migrated, 'skipped': skipped, 'failed': failed};
  }

  /// Migrate landing page hero images that are not yet on Cloudinary.
  Future<Map<String, int>> migrateLegacyLandingHeroes({int limit = 50}) async {
    final media = _media;
    if (media == null || !media.isCloudinaryEnabled) {
      throw StateError('Cloudinary media service is required for migration.');
    }
    final rows = await _c
        .from('landing_pages')
        .select('id, hero_image_url')
        .not('hero_image_url', 'is', null)
        .limit(limit);
    var migrated = 0;
    var skipped = 0;
    var failed = 0;
    for (final raw in rows as List) {
      final row = Map<String, dynamic>.from(raw as Map);
      final id = row['id']?.toString() ?? '';
      final url = (row['hero_image_url'] as String?)?.trim() ?? '';
      if (id.isEmpty || url.isEmpty) {
        skipped++;
        continue;
      }
      if (MediaDelivery.isCloudinaryUrl(url)) {
        skipped++;
        continue;
      }
      try {
        final asset = await media.migrateFromUrl(
          sourceUrl: url,
          entityType: MediaEntityType.marketing,
          entityId: id,
          role: 'hero',
        );
        await _c
            .from('landing_pages')
            .update({
              'hero_image_url': asset.deliveryUrl,
              'updated_at': _nowIso(),
            })
            .eq('id', id);
        migrated++;
      } catch (_) {
        failed++;
      }
    }
    return {'migrated': migrated, 'skipped': skipped, 'failed': failed};
  }

  /// Run all website-facing legacy URL migrations (images + videos).
  Future<Map<String, Object?>> migrateAllWebsiteMediaToCloudinary({
    int limit = 50,
  }) async {
    final heroes = await migrateLegacyWebsiteHeroMedia(limit: limit);
    final banners = await migrateLegacyBannerImages(limit: limit);
    final partners = await migrateLegacyPartnerLogos(limit: limit);
    final testimonials = await migrateLegacyTestimonialAvatars(limit: limit);
    final landings = await migrateLegacyLandingHeroes(limit: limit);
    final blogs = await migrateLegacyBlogCovers(limit: limit);
    final properties = await migrateLegacyPropertyImages(limit: limit);
    Map<String, dynamic> batch = const {};
    try {
      batch = await migrateLegacyMediaBatch(limit: limit);
    } catch (e) {
      batch = {'error': '$e'};
    }
    return {
      'heroes': heroes,
      'banners': banners,
      'partners': partners,
      'testimonials': testimonials,
      'landings': landings,
      'blogs': blogs,
      'properties': properties,
      'edge_batch': batch,
    };
  }

  Future<CmsHeroSection> _ensureHeroCloudinaryUrls(CmsHeroSection hero) async {
    final media = _media;
    if (media == null || !media.isCloudinaryEnabled) {
      MediaDelivery.assertCloudinaryMediaUrl(
        hero.backgroundUrl,
        field: 'Hero background',
      );
      final video =
          '${hero.content['video_url'] ?? hero.content['videoUrl'] ?? ''}';
      MediaDelivery.assertCloudinaryMediaUrl(video, field: 'Hero video');
      return hero;
    }

    var background = hero.backgroundUrl?.trim();
    final content = Map<String, dynamic>.from(hero.content);
    final videoKey = content.containsKey('video_url')
        ? 'video_url'
        : (content.containsKey('videoUrl') ? 'videoUrl' : 'video_url');
    var video = '${content[videoKey] ?? ''}'.trim();

    if (background != null &&
        background.isNotEmpty &&
        !MediaDelivery.isCloudinaryUrl(background)) {
      final asset = await media.migrateFromUrl(
        sourceUrl: background,
        entityType: MediaEntityType.marketing,
        role: 'marketing',
      );
      background = asset.deliveryUrl;
    }
    if (video.isNotEmpty && !MediaDelivery.isCloudinaryUrl(video)) {
      final asset = await media.migrateFromUrl(
        sourceUrl: video,
        entityType: MediaEntityType.marketing,
        role: 'marketing',
        resourceType: MediaResourceType.video,
      );
      video = asset.deliveryUrl;
      content['video_url'] = video;
      content.remove('videoUrl');
    }

    return hero.copyWith(backgroundUrl: background, content: content);
  }

  // ───────────────────────────────────────────────────────────────────────
  // Blog (blogs)
  // ───────────────────────────────────────────────────────────────────────

  Future<List<CmsBlogPost>> listBlogs() async {
    final rows = await _c
        .from('blogs')
        .select()
        .eq('is_deleted', false)
        .order('created_at', ascending: false);
    return rows
        .map((e) => CmsBlogPost.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> setBlogPublished(String id, bool isPublished) async {
    await _c
        .from('blogs')
        .update({
          'is_published': isPublished,
          'status': isPublished ? 'published' : 'draft',
          'published_at': isPublished ? _nowIso() : null,
          'updated_at': _nowIso(),
        })
        .eq('id', id);
  }

  Future<void> setBlogFeatured(String id, bool featured) async {
    await _c
        .from('blogs')
        .update({'featured': featured, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  Future<void> deleteBlog(String id) async {
    await _c
        .from('blogs')
        .update({'is_deleted': true, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  Future<List<CmsBlogCategory>> listBlogCategories() async {
    final rows = await _c
        .from('blog_categories')
        .select()
        .eq('is_deleted', false)
        .order('name');
    return rows
        .map((e) => CmsBlogCategory.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<CmsBlogCategory>> listPublishedBlogCategories() async {
    final rows = await _c
        .from('blog_categories')
        .select()
        .eq('is_deleted', false)
        .eq('status', 'active')
        .order('name');
    return rows
        .map((e) => CmsBlogCategory.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<CmsBlogCategory> upsertBlogCategory({
    String? id,
    required String name,
    required String slug,
    String status = 'active',
  }) async {
    final row = await _c
        .from('blog_categories')
        .upsert({
          if (id != null) 'id': id,
          'name': name,
          'slug': slug,
          'status': status,
          'is_deleted': false,
          'updated_at': _nowIso(),
        })
        .select()
        .single();
    return CmsBlogCategory.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> setBlogCategoryStatus(String id, String status) async {
    await _c
        .from('blog_categories')
        .update({'status': status, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  Future<void> deleteBlogCategory(String id) async {
    await _c
        .from('blogs')
        .update({'category_id': null, 'updated_at': _nowIso()})
        .eq('category_id', id);
    await _c
        .from('blog_categories')
        .update({'is_deleted': true, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  Future<List<CmsBlogAuthor>> listBlogAuthors() async {
    final rows = await _c.from('blog_authors').select().order('display_name');
    return rows
        .map((e) => CmsBlogAuthor.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<CmsBlogAuthor> upsertBlogAuthor({
    String? id,
    required String displayName,
    required String slug,
    String? bio,
    String? avatarUrl,
    bool isActive = true,
  }) async {
    final row = await _c
        .from('blog_authors')
        .upsert({
          if (id != null) 'id': id,
          'display_name': displayName,
          'slug': slug,
          'bio': bio,
          'avatar_url': avatarUrl,
          'is_active': isActive,
          'updated_at': _nowIso(),
        })
        .select()
        .single();
    return CmsBlogAuthor.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> deleteBlogAuthor(String id) async {
    await _c.from('blog_authors').delete().eq('id', id);
  }

  // ───────────────────────────────────────────────────────────────────────
  // Estates (estates)
  // ───────────────────────────────────────────────────────────────────────

  static const _estateImagesJoin =
      'estate_images (url, is_cover, sort_order, is_deleted, media_id, media:media_id(secure_url, thumbnail_url, is_published))';

  static const _estateSelect =
      '''
    id, name, slug, description, tagline, city, state, country,
    price_from_label, marketing_status, is_featured, is_published,
    published_at, status, updated_at,
    $_estateImagesJoin,
    properties (count)
  ''';

  static const _estateSelectLite =
      '''
    id, name, slug, description, tagline, city, state, country,
    price_from_label, marketing_status, is_featured, is_published,
    published_at, status, updated_at,
    $_estateImagesJoin
  ''';

  Future<List<CmsEstateSummary>> listEstates() async {
    final rows = await _selectEstates(
      featuredOnly: false,
      publishedOnly: false,
    );
    return rows
        .map((e) => CmsEstateSummary.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Public homepage — published + featured estates only.
  Future<List<CmsEstateSummary>> listPublishedFeaturedEstates({
    int limit = 6,
  }) async {
    final rows = await _selectEstates(
      featuredOnly: true,
      publishedOnly: true,
      limit: limit,
    );
    return rows
        .map((e) => CmsEstateSummary.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<Map<String, dynamic>>> _selectEstates({
    required bool featuredOnly,
    required bool publishedOnly,
    int? limit,
  }) async {
    Future<List<Map<String, dynamic>>> run(String select) async {
      var query = _c.from('estates').select(select).eq('is_deleted', false);
      if (publishedOnly) query = query.eq('is_published', true);
      if (featuredOnly) query = query.eq('is_featured', true);
      final ordered = query
          .order('is_featured', ascending: false)
          .order('updated_at', ascending: false)
          .order('name');
      final rows = limit == null ? await ordered : await ordered.limit(limit);
      return rows.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }

    try {
      return await run(_estateSelect);
    } catch (_) {
      try {
        return await run(_estateSelectLite);
      } catch (_) {
        return await run(
          'id, name, slug, description, tagline, city, state, country, '
          'price_from_label, marketing_status, is_featured, is_published, '
          'published_at, status, updated_at',
        );
      }
    }
  }

  /// Public estates catalog — all published (non-deleted) estates, featured
  /// first, for the public "Estates" listing page.
  Future<List<CmsEstateSummary>> listPublishedEstates({int limit = 50}) async {
    final rows = await _selectEstates(
      featuredOnly: false,
      publishedOnly: true,
      limit: limit,
    );
    return rows
        .map((e) => CmsEstateSummary.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> setEstateFeatured(String id, bool featured) async {
    await _c
        .from('estates')
        .update({'is_featured': featured, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  Future<void> setEstatePublished(String id, bool published) async {
    await _c
        .from('estates')
        .update({
          'is_published': published,
          'published_at': published ? _nowIso() : null,
          'updated_at': _nowIso(),
        })
        .eq('id', id);
  }

  /// Removes an estate from the catalog. Linked properties stay; the estate
  /// and its gallery leave the public site.
  Future<void> deleteEstate(String id) async {
    await _c
        .from('estates')
        .update({
          'is_deleted': true,
          'is_published': false,
          'is_featured': false,
          'updated_at': _nowIso(),
        })
        .eq('id', id);
    try {
      await _c
          .from('estate_images')
          .update({'is_deleted': true, 'updated_at': _nowIso()})
          .eq('estate_id', id)
          .eq('is_deleted', false);
    } catch (_) {}
  }

  Future<void> upsertEstateBasic({
    required String id,
    required String name,
    required String slug,
    String? description,
    String? tagline,
    String? city,
    String? state,
    String? priceFromLabel,
    String? marketingStatus,
  }) async {
    await _c
        .from('estates')
        .update({
          'name': name,
          'slug': slug,
          'description': description,
          'tagline': tagline,
          'city': city,
          'state': state,
          'price_from_label': priceFromLabel,
          'marketing_status': marketingStatus,
          'updated_at': _nowIso(),
        })
        .eq('id', id);
  }

  Future<CmsEstateSummary> createEstate({
    required String name,
    required String slug,
    String? description,
    String? tagline,
    String? city,
    String? state,
    String? priceFromLabel,
    String? marketingStatus,
    bool featureAndPublish = false,
  }) async {
    final row = await _c
        .from('estates')
        .insert({
          'name': name,
          'slug': slug,
          'description': description,
          'tagline': tagline,
          'city': city,
          'state': state,
          'price_from_label': priceFromLabel,
          'marketing_status': marketingStatus,
          'is_featured': featureAndPublish,
          'is_published': featureAndPublish,
          'published_at': featureAndPublish ? _nowIso() : null,
          'status': 'active',
        })
        .select()
        .single();
    return CmsEstateSummary.fromJson(Map<String, dynamic>.from(row));
  }

  Future<String> uploadEstateCover({
    required String estateId,
    required List<int> bytes,
    required String contentType,
    String? fileName,
    void Function(double progress)? onProgress,
  }) async {
    final media = _media;
    String url;
    String? mediaId;

    if (media != null && media.isCloudinaryEnabled) {
      final asset = await media.upload(
        UploadMediaRequest(
          bytes: bytes,
          contentType: contentType,
          originalFilename: fileName ?? 'estate-cover',
          entityType: MediaEntityType.estate,
          entityId: estateId,
          role: 'gallery',
          isCover: true,
          onProgress: onProgress,
        ),
      );
      url = asset.deliveryUrl;
      mediaId = asset.id;
    } else {
      throw StateError('Cloudinary is required for this image/video upload.');
    }

    await _c
        .from('estate_images')
        .update({'is_cover': false, 'updated_at': _nowIso()})
        .eq('estate_id', estateId)
        .eq('is_deleted', false);
    await _c.from('estate_images').insert({
      'estate_id': estateId,
      'url': url,
      if (mediaId != null) 'media_id': mediaId,
      'is_cover': true,
      'sort_order': 0,
    });
    return url;
  }

  /// Upload a gallery image (optionally as cover). Returns public URL.
  Future<String> uploadEstateGalleryImage({
    required String estateId,
    required List<int> bytes,
    required String contentType,
    bool asCover = false,
    int sortOrder = 0,
    String? fileName,
    void Function(double progress)? onProgress,
  }) async {
    final media = _media;
    String url;
    String? mediaId;

    if (media != null && media.isCloudinaryEnabled) {
      final asset = await media.upload(
        UploadMediaRequest(
          bytes: bytes,
          contentType: contentType,
          originalFilename: fileName ?? 'estate-image',
          entityType: MediaEntityType.estate,
          entityId: estateId,
          role: 'gallery',
          isCover: asCover,
          sortOrder: sortOrder,
          onProgress: onProgress,
        ),
      );
      url = asset.deliveryUrl;
      mediaId = asset.id;
    } else {
      throw StateError('Cloudinary is required for this image/video upload.');
    }

    if (asCover) {
      await _c
          .from('estate_images')
          .update({'is_cover': false, 'updated_at': _nowIso()})
          .eq('estate_id', estateId)
          .eq('is_deleted', false);
    }
    await _c.from('estate_images').insert({
      'estate_id': estateId,
      'url': url,
      if (mediaId != null) 'media_id': mediaId,
      'is_cover': asCover,
      'sort_order': sortOrder,
    });
    return url;
  }

  Future<List<EstateGalleryImage>> listEstateImages(String estateId) async {
    final rows = await _c
        .from('estate_images')
        .select(
          'id, estate_id, url, media_id, is_cover, sort_order, alt_text, media:media_id(secure_url, alt_text, is_published)',
        )
        .eq('estate_id', estateId)
        .eq('is_deleted', false)
        .order('sort_order', ascending: true);
    return (rows as List)
        .map((e) => EstateGalleryImage.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> deleteEstateImage(String imageId) async {
    final row = await _c
        .from('estate_images')
        .select('media_id')
        .eq('id', imageId)
        .maybeSingle();
    await _c
        .from('estate_images')
        .update({'is_deleted': true, 'updated_at': _nowIso()})
        .eq('id', imageId);
    final mediaId = row?['media_id']?.toString();
    if (mediaId != null && _media != null) {
      try {
        await _media!.delete(mediaId);
      } catch (_) {}
    }
  }

  Future<void> setEstateCoverImage(String estateId, String imageId) async {
    await _c
        .from('estate_images')
        .update({'is_cover': false, 'updated_at': _nowIso()})
        .eq('estate_id', estateId)
        .eq('is_deleted', false);
    await _c
        .from('estate_images')
        .update({'is_cover': true, 'updated_at': _nowIso()})
        .eq('id', imageId);
    final row = await _c
        .from('estate_images')
        .select('media_id')
        .eq('id', imageId)
        .maybeSingle();
    final mediaId = row?['media_id']?.toString();
    if (mediaId != null && _media != null) {
      await _media!.setCover(
        entityType: MediaEntityType.estate,
        entityId: estateId,
        mediaId: mediaId,
      );
    }
  }

  Future<void> reorderEstateImages(
    String estateId,
    List<String> orderedImageIds,
  ) async {
    for (var i = 0; i < orderedImageIds.length; i++) {
      await _c
          .from('estate_images')
          .update({'sort_order': i, 'updated_at': _nowIso()})
          .eq('id', orderedImageIds[i])
          .eq('estate_id', estateId);
    }
    final mediaIds = <String>[];
    for (final id in orderedImageIds) {
      final row = await _c
          .from('estate_images')
          .select('media_id')
          .eq('id', id)
          .maybeSingle();
      final mid = row?['media_id']?.toString();
      if (mid != null) mediaIds.add(mid);
    }
    if (mediaIds.isNotEmpty && _media != null) {
      await _media!.reorder(
        entityType: MediaEntityType.estate,
        entityId: estateId,
        orderedMediaIds: mediaIds,
      );
    }
  }

  Future<void> updateEstateImageAlt(String imageId, String altText) async {
    await _c
        .from('estate_images')
        .update({'alt_text': altText, 'updated_at': _nowIso()})
        .eq('id', imageId);
    final row = await _c
        .from('estate_images')
        .select('media_id')
        .eq('id', imageId)
        .maybeSingle();
    final mediaId = row?['media_id']?.toString();
    if (mediaId != null && _media != null) {
      await _media!.updateMediaMetadata(mediaId: mediaId, altText: altText);
    }
  }

  Future<String> replaceEstateImage({
    required String imageId,
    required List<int> bytes,
    required String contentType,
    required String fileName,
    void Function(double progress)? onProgress,
  }) async {
    final row = await _c
        .from('estate_images')
        .select('estate_id, media_id, is_cover, sort_order')
        .eq('id', imageId)
        .maybeSingle();
    if (row == null) throw StateError('Estate image not found.');

    final estateId = row['estate_id'] as String;
    final mediaId = row['media_id']?.toString();
    final media = _media;

    if (mediaId != null && media != null && media.isCloudinaryEnabled) {
      final asset = await media.replace(
        mediaId: mediaId,
        request: UploadMediaRequest(
          bytes: bytes,
          contentType: contentType,
          originalFilename: fileName,
          entityType: MediaEntityType.estate,
          entityId: estateId,
          role: 'gallery',
          onProgress: onProgress,
        ),
      );
      final url = asset.deliveryUrl;
      await _c
          .from('estate_images')
          .update({'url': url, 'updated_at': _nowIso()})
          .eq('id', imageId);
      return url;
    }

    final url = await uploadEstateGalleryImage(
      estateId: estateId,
      bytes: bytes,
      contentType: contentType,
      asCover: row['is_cover'] as bool? ?? false,
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
      fileName: fileName,
      onProgress: onProgress,
    );
    await deleteEstateImage(imageId);
    return url;
  }

  // ───────────────────────────────────────────────────────────────────────
  // Featured properties (properties)
  // ───────────────────────────────────────────────────────────────────────

  static const _propertyImagesJoin =
      'property_images (url, is_cover, sort_order, is_deleted, media_id, media:media_id(secure_url, thumbnail_url, is_published))';

  static const _propertySelect =
      '''
    id, title, slug, description, summary, is_featured, is_published, status,
    property_code, estate_name, address_line,
    bedrooms, bathrooms, toilets, kitchens, parking_spaces, floors,
    land_size_sqm, building_size_sqm, year_built,
    power_supply, water_supply, internet_connectivity,
    architectural_concept, investment_potential, detail_extras,
    listing_price, promo_price, currency,
    marketing_status, homepage_badge, category_slug, city, state, updated_at, created_at,
    property_locations (city, state, address),
    $_propertyImagesJoin,
    property_pricing (price, currency, price_label),
    property_types (name),
    property_amenities (amenity, is_deleted)
  ''';

  static const _propertySelectLite =
      '''
    id, title, slug, description, summary, is_featured, is_published, status,
    property_code, estate_name, address_line,
    bedrooms, bathrooms, toilets, kitchens, parking_spaces, floors,
    land_size_sqm, building_size_sqm, year_built,
    power_supply, water_supply, internet_connectivity,
    architectural_concept, investment_potential, detail_extras,
    listing_price, promo_price, currency,
    marketing_status, homepage_badge, category_slug, city, state, updated_at, created_at,
    property_locations (city, state, address),
    $_propertyImagesJoin,
    property_pricing (price, currency, price_label),
    property_amenities (amenity, is_deleted)
  ''';

  Future<List<CmsPropertyFeatured>> listFeaturedProperties({
    String? search,
  }) async {
    final rows = await _selectProperties(
      search: search,
      featuredOnly: false,
      publishedOnly: false,
    );
    return rows.map((e) => CmsPropertyFeatured.fromJson(e)).toList();
  }

  /// Public homepage — published + featured properties only.
  Future<List<CmsPropertyFeatured>> listPublishedFeaturedProperties({
    int limit = 6,
  }) async {
    final rows = await _selectProperties(
      featuredOnly: true,
      publishedOnly: true,
      limit: limit,
    );
    return rows.map((e) => CmsPropertyFeatured.fromJson(e)).toList();
  }

  Future<List<Map<String, dynamic>>> _selectProperties({
    String? search,
    required bool featuredOnly,
    required bool publishedOnly,
    int? limit,
  }) async {
    Future<List<Map<String, dynamic>>> run(String select) async {
      var query = _c.from('properties').select(select).eq('is_deleted', false);
      if (publishedOnly) query = query.eq('is_published', true);
      if (featuredOnly) query = query.eq('is_featured', true);
      if (search != null && search.isNotEmpty) {
        query = query.ilike('title', '%$search%');
      }
      final ordered = query
          .order('is_featured', ascending: false)
          .order('updated_at', ascending: false)
          .order('title');
      final rows = limit == null ? await ordered : await ordered.limit(limit);
      return rows.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }

    try {
      return await run(_propertySelect);
    } catch (_) {
      try {
        return await run(_propertySelectLite);
      } catch (_) {
        return await run(
          'id, title, slug, description, summary, is_featured, is_published, '
          'status, property_code, estate_name, address_line, '
          'bedrooms, bathrooms, toilets, kitchens, parking_spaces, floors, '
          'land_size_sqm, building_size_sqm, year_built, '
          'power_supply, water_supply, internet_connectivity, '
          'architectural_concept, investment_potential, '
          'listing_price, promo_price, currency, '
          'marketing_status, homepage_badge, category_slug, city, state, updated_at, '
          '$_propertyImagesJoin',
        );
      }
    }
  }

  /// Public properties catalog — all published (non-deleted) properties,
  /// featured first, for the public "Properties" marketplace.
  Future<List<CmsPropertyFeatured>> listPublishedProperties({
    int limit = 100,
  }) async {
    final rows = await _selectProperties(
      featuredOnly: false,
      publishedOnly: true,
      limit: limit,
    );
    return rows.map((e) => CmsPropertyFeatured.fromJson(e)).toList();
  }

  /// Single published property for public detail / Quick View.
  /// Accepts either a UUID [id] or a public [slug].
  Future<CmsPropertyFeatured?> getPublishedPropertyById(String idOrSlug) async {
    return _getPropertyByKey(idOrSlug, publishedOnly: true);
  }

  /// Admin fetch by UUID (published or draft).
  Future<CmsPropertyFeatured?> getPropertyById(String id) async {
    return _getPropertyByKey(id, publishedOnly: false, preferId: true);
  }

  Future<CmsPropertyFeatured?> _getPropertyByKey(
    String idOrSlug, {
    required bool publishedOnly,
    bool preferId = false,
  }) async {
    final key = idOrSlug.trim();
    if (key.isEmpty) return null;

    Future<Map<String, dynamic>?> run(
      String select, {
      required bool byId,
    }) async {
      var query = _c.from('properties').select(select).eq('is_deleted', false);
      if (publishedOnly) query = query.eq('is_published', true);
      query = byId ? query.eq('id', key) : query.eq('slug', key);
      final row = await query.maybeSingle();
      if (row == null) return null;
      return Map<String, dynamic>.from(row);
    }

    Future<CmsPropertyFeatured?> load({required bool byId}) async {
      try {
        final row = await run(_propertySelect, byId: byId);
        if (row == null) return null;
        return CmsPropertyFeatured.fromJson(row);
      } catch (_) {
        try {
          final row = await run(_propertySelectLite, byId: byId);
          if (row == null) return null;
          return CmsPropertyFeatured.fromJson(row);
        } catch (_) {
          final row = await run(
            'id, title, slug, description, summary, is_featured, is_published, '
            'status, property_code, estate_name, address_line, '
            'bedrooms, bathrooms, toilets, kitchens, parking_spaces, floors, '
            'land_size_sqm, building_size_sqm, year_built, '
            'power_supply, water_supply, internet_connectivity, '
            'architectural_concept, investment_potential, '
            'listing_price, promo_price, currency, '
            'marketing_status, homepage_badge, category_slug, city, state, updated_at, '
            '$_propertyImagesJoin, '
            'property_amenities (amenity, is_deleted)',
            byId: byId,
          );
          if (row == null) return null;
          return CmsPropertyFeatured.fromJson(row);
        }
      }
    }

    final looksLikeUuid = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(key);

    if (preferId || looksLikeUuid) {
      final byId = await load(byId: true);
      if (byId != null) return byId;
      if (preferId) return null;
    }
    return load(byId: false);
  }

  Future<void> setPropertyFeatured(String id, bool featured) async {
    await _c
        .from('properties')
        .update({'is_featured': featured, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  Future<void> deleteProperty(String id) async {
    await _c
        .from('properties')
        .update({
          'is_deleted': true,
          'is_published': false,
          'is_featured': false,
          'updated_at': _nowIso(),
        })
        .eq('id', id);
  }

  Future<void> setPropertyPublished(String id, bool published) async {
    await _c
        .from('properties')
        .update({
          'is_published': published,
          'published_at': published ? _nowIso() : null,
          'publish_workflow_status': published ? 'published' : 'draft',
          'updated_at': _nowIso(),
        })
        .eq('id', id);
  }

  Future<void> archiveProperty(String id) async {
    await _c
        .from('properties')
        .update({
          'is_published': false,
          'is_featured': false,
          'publish_workflow_status': 'archived',
          'updated_at': _nowIso(),
        })
        .eq('id', id);
  }

  Future<CmsPropertyFeatured> createProperty({
    required String title,
    required String slug,
    String? description,
    String? summary,
    String? city,
    String? state,
    String? addressLine,
    String? estateName,
    String? propertyCode,
    String? categorySlug,
    double? bedrooms,
    double? bathrooms,
    double? toilets,
    double? kitchens,
    int? parkingSpaces,
    int? floors,
    double? landSizeSqm,
    double? buildingSizeSqm,
    String? yearBuilt,
    String? powerSupply,
    String? waterSupply,
    String? internetConnectivity,
    String? architecturalConcept,
    String? investmentPotential,
    double? listingPrice,
    double? promoPrice,
    double? investorPrice,
    double? rentalPrice,
    String? currency,
    String? homepageBadge,
    String? priceLabel,
    String? marketingStatus,
    String? inventoryStatus,
    String? publishWorkflowStatus,
    List<String> amenities = const [],
    PropertyDetailExtras? detailExtras,
    bool featureAndPublish = false,
  }) async {
    final published = featureAndPublish || publishWorkflowStatus == 'published';
    final featured = featureAndPublish || marketingStatus == 'featured';
    final year = yearBuilt?.trim() ?? '';
    final power = powerSupply?.trim() ?? '';
    final water = waterSupply?.trim() ?? '';
    final internet = internetConnectivity?.trim() ?? '';

    final row = await _c
        .from('properties')
        .insert({
          'title': title,
          'slug': slug,
          if (description != null) 'description': description,
          if (summary != null) 'summary': summary,
          if (city != null) 'city': city,
          if (state != null) 'state': state,
          if (addressLine != null) 'address_line': addressLine,
          if (estateName != null) 'estate_name': estateName,
          if (propertyCode != null) 'property_code': propertyCode,
          if (categorySlug != null) 'category_slug': categorySlug,
          if (bedrooms != null) 'bedrooms': bedrooms,
          if (bathrooms != null) 'bathrooms': bathrooms,
          if (toilets != null) 'toilets': toilets,
          if (kitchens != null) 'kitchens': kitchens,
          if (parkingSpaces != null) 'parking_spaces': parkingSpaces,
          if (floors != null) 'floors': floors,
          if (landSizeSqm != null) 'land_size_sqm': landSizeSqm,
          if (buildingSizeSqm != null) 'building_size_sqm': buildingSizeSqm,
          if (year.isNotEmpty) 'year_built': year,
          if (power.isNotEmpty) 'power_supply': power,
          if (water.isNotEmpty) 'water_supply': water,
          if (internet.isNotEmpty) 'internet_connectivity': internet,
          if (architecturalConcept != null)
            'architectural_concept': architecturalConcept,
          if (investmentPotential != null)
            'investment_potential': investmentPotential,
          if (detailExtras != null) 'detail_extras': detailExtras.toJson(),
          if (listingPrice != null) 'listing_price': listingPrice,
          if (promoPrice != null) 'promo_price': promoPrice,
          if (investorPrice != null) 'investor_price': investorPrice,
          if (rentalPrice != null) 'rental_price': rentalPrice,
          'currency': currency ?? 'NGN',
          if (homepageBadge != null) 'homepage_badge': homepageBadge,
          if (marketingStatus != null) 'marketing_status': marketingStatus,
          if (inventoryStatus != null) 'inventory_status': inventoryStatus,
          'is_featured': featured,
          'is_published': published,
          'published_at': published ? _nowIso() : null,
          'publish_workflow_status':
              publishWorkflowStatus ?? (published ? 'published' : 'draft'),
          'status': 'active',
        })
        .select()
        .single();
    final created = CmsPropertyFeatured.fromJson(
      Map<String, dynamic>.from(row),
    );
    await upsertPropertyBasic(
      id: created.id,
      title: title,
      slug: slug,
      description: description,
      summary: summary,
      city: city,
      state: state,
      addressLine: addressLine,
      estateName: estateName,
      propertyCode: propertyCode,
      categorySlug: categorySlug,
      bedrooms: bedrooms,
      bathrooms: bathrooms,
      toilets: toilets,
      kitchens: kitchens,
      parkingSpaces: parkingSpaces,
      floors: floors,
      landSizeSqm: landSizeSqm,
      buildingSizeSqm: buildingSizeSqm,
      yearBuilt: year.isEmpty ? null : year,
      powerSupply: power.isEmpty ? null : power,
      waterSupply: water.isEmpty ? null : water,
      internetConnectivity: internet.isEmpty ? null : internet,
      architecturalConcept: architecturalConcept,
      investmentPotential: investmentPotential,
      listingPrice: listingPrice,
      promoPrice: promoPrice,
      investorPrice: investorPrice,
      rentalPrice: rentalPrice,
      currency: currency ?? 'NGN',
      homepageBadge: homepageBadge,
      priceLabel: priceLabel,
      marketingStatus: marketingStatus,
      inventoryStatus: inventoryStatus,
      amenities: amenities,
      detailExtras: detailExtras,
    );
    return created;
  }

  Future<void> upsertPropertyBasic({
    required String id,
    required String title,
    required String slug,
    String? description,
    String? summary,
    String? city,
    String? state,
    String? addressLine,
    String? estateName,
    String? propertyCode,
    String? categorySlug,
    double? bedrooms,
    double? bathrooms,
    double? toilets,
    double? kitchens,
    int? parkingSpaces,
    int? floors,
    double? landSizeSqm,
    double? buildingSizeSqm,
    String? yearBuilt,
    String? powerSupply,
    String? waterSupply,
    String? internetConnectivity,
    String? architecturalConcept,
    String? investmentPotential,
    double? listingPrice,
    double? promoPrice,
    double? investorPrice,
    double? rentalPrice,
    String? currency,
    String? homepageBadge,
    String? priceLabel,
    String? marketingStatus,
    String? inventoryStatus,
    List<String>? amenities,
    PropertyDetailExtras? detailExtras,
  }) async {
    await _c
        .from('properties')
        .update({
          'title': title,
          'slug': slug,
          if (description != null) 'description': description,
          if (summary != null) 'summary': summary,
          if (city != null) 'city': city,
          if (state != null) 'state': state,
          if (addressLine != null) 'address_line': addressLine,
          if (estateName != null) 'estate_name': estateName,
          if (propertyCode != null) 'property_code': propertyCode,
          if (categorySlug != null) 'category_slug': categorySlug,
          if (bedrooms != null) 'bedrooms': bedrooms,
          if (bathrooms != null) 'bathrooms': bathrooms,
          if (toilets != null) 'toilets': toilets,
          if (kitchens != null) 'kitchens': kitchens,
          if (parkingSpaces != null) 'parking_spaces': parkingSpaces,
          if (floors != null) 'floors': floors,
          if (landSizeSqm != null) 'land_size_sqm': landSizeSqm,
          if (buildingSizeSqm != null) 'building_size_sqm': buildingSizeSqm,
          if (yearBuilt != null) 'year_built': yearBuilt,
          if (powerSupply != null) 'power_supply': powerSupply,
          if (waterSupply != null) 'water_supply': waterSupply,
          if (internetConnectivity != null)
            'internet_connectivity': internetConnectivity,
          if (architecturalConcept != null)
            'architectural_concept': architecturalConcept,
          if (investmentPotential != null)
            'investment_potential': investmentPotential,
          if (detailExtras != null) 'detail_extras': detailExtras.toJson(),
          if (listingPrice != null) 'listing_price': listingPrice,
          if (promoPrice != null) 'promo_price': promoPrice,
          if (investorPrice != null) 'investor_price': investorPrice,
          if (rentalPrice != null) 'rental_price': rentalPrice,
          if (currency != null) 'currency': currency,
          if (homepageBadge != null) 'homepage_badge': homepageBadge,
          if (marketingStatus != null) 'marketing_status': marketingStatus,
          if (inventoryStatus != null) 'inventory_status': inventoryStatus,
          'updated_at': _nowIso(),
        })
        .eq('id', id);

    // Keep location / pricing in sync when present.
    if ((city != null && city.trim().isNotEmpty) ||
        (state != null && state.trim().isNotEmpty) ||
        (addressLine != null && addressLine.trim().isNotEmpty)) {
      await _c.from('property_locations').upsert({
        'property_id': id,
        'city': city,
        'state': state,
        'address': addressLine,
        'updated_at': _nowIso(),
      }, onConflict: 'property_id');
    }

    final hasPrice = listingPrice != null;
    final hasLabel = priceLabel != null && priceLabel.trim().isNotEmpty;
    if (hasPrice || hasLabel) {
      final existing = await _c
          .from('property_pricing')
          .select('price, currency')
          .eq('property_id', id)
          .eq('is_deleted', false)
          .maybeSingle();
      final price =
          listingPrice ?? (existing?['price'] as num?)?.toDouble() ?? 0;
      await _c.from('property_pricing').upsert({
        'property_id': id,
        'price': price,
        'currency': currency ?? existing?['currency'] as String? ?? 'NGN',
        'price_label': hasLabel ? priceLabel.trim() : null,
        'updated_at': _nowIso(),
      }, onConflict: 'property_id');
    }

    if (amenities != null) {
      await _replaceAmenities(id, amenities);
    }
  }

  Future<void> _replaceAmenities(
    String propertyId,
    List<String> amenities,
  ) async {
    await _c
        .from('property_amenities')
        .update({'is_deleted': true, 'updated_at': _nowIso()})
        .eq('property_id', propertyId)
        .eq('is_deleted', false);
    for (final amenity in amenities) {
      final trimmed = amenity.trim();
      if (trimmed.isEmpty) continue;
      await _c.from('property_amenities').insert({
        'property_id': propertyId,
        'amenity': trimmed,
      });
    }
  }

  /// Upload a public property asset (PDF → downloads, video → property-videos,
  /// image → estate-masterplans). Returns a cache-busted public URL.
  Future<String> uploadPropertyPublicAsset({
    required String propertyId,
    required List<int> bytes,
    required String contentType,
    String? fileName,
  }) async {
    final lowerName = (fileName ?? '').toLowerCase();
    final isPdf =
        contentType == 'application/pdf' || lowerName.endsWith('.pdf');
    final isVideo =
        contentType.startsWith('video/') ||
        lowerName.endsWith('.mp4') ||
        lowerName.endsWith('.webm') ||
        lowerName.endsWith('.mov');
    final bucket = isVideo
        ? 'property-videos'
        : isPdf
        ? 'downloads'
        : 'estate-masterplans';
    final resolvedType = isPdf
        ? 'application/pdf'
        : isVideo
        ? (contentType.startsWith('video/') ? contentType : 'video/mp4')
        : (contentType.startsWith('image/') ? contentType : 'image/jpeg');
    return _uploadPublicBytes(
      bucket: bucket,
      bytes: bytes,
      contentType: resolvedType,
      folder: 'properties/$propertyId',
      fileNameHint: fileName,
    );
  }

  Future<String> _uploadPublicBytes({
    required String bucket,
    required List<int> bytes,
    required String contentType,
    required String folder,
    String? fileNameHint,
    MediaEntityType entityType = MediaEntityType.marketing,
    String? entityId,
    String? role,
    void Function(double progress)? onProgress,
  }) async {
    final isBinaryMedia =
        contentType.startsWith('image/') || contentType.startsWith('video/');
    final media = _media;
    if (media != null && media.isCloudinaryEnabled && isBinaryMedia) {
      return media.uploadAndGetUrl(
        UploadMediaRequest(
          bytes: bytes,
          contentType: contentType,
          originalFilename: fileNameHint ?? 'asset',
          entityType: entityType,
          entityId: entityId,
          role: role ?? 'gallery',
          onProgress: onProgress,
        ),
      );
    }
    if (isBinaryMedia) {
      throw StateError(
        'Cloudinary is required for image/video uploads. '
        'Supabase Storage is not used for media binaries.',
      );
    }

    // Non-media documents (e.g. PDF) may still use Storage when configured.
    final ext = switch (contentType) {
      'application/pdf' => 'pdf',
      _ => 'bin',
    };
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final safeHint = (fileNameHint ?? 'asset')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final base = safeHint.isEmpty ? 'asset' : safeHint;
    final path = '$folder/$base-$stamp.$ext';
    final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    await _c.storage
        .from(bucket)
        .uploadBinary(
          path,
          data,
          fileOptions: FileOptions(upsert: true, contentType: contentType),
        );
    final publicUrl = _c.storage.from(bucket).getPublicUrl(path);
    return '$publicUrl?v=$stamp';
  }

  /// Upload a gallery image (optionally as cover). Returns public URL.
  Future<String> uploadPropertyGalleryImage({
    required String propertyId,
    required List<int> bytes,
    required String contentType,
    bool asCover = false,
    int sortOrder = 0,
    String? fileName,
    void Function(double progress)? onProgress,
  }) async {
    final media = _media;
    String url;
    String? mediaId;

    if (media == null || !media.isCloudinaryEnabled) {
      throw StateError('Cloudinary is required for property gallery uploads.');
    }
    final asset = await media.upload(
      UploadMediaRequest(
        bytes: bytes,
        contentType: contentType,
        originalFilename: fileName ?? 'property-image',
        entityType: MediaEntityType.property,
        entityId: propertyId,
        role: 'gallery',
        isCover: asCover,
        sortOrder: sortOrder,
        onProgress: onProgress,
      ),
    );
    url = asset.deliveryUrl;
    mediaId = asset.id;

    if (asCover) {
      await _c
          .from('property_images')
          .update({'is_cover': false, 'updated_at': _nowIso()})
          .eq('property_id', propertyId)
          .eq('is_deleted', false);
    }
    await _c.from('property_images').insert({
      'property_id': propertyId,
      'url': url,
      if (mediaId != null) 'media_id': mediaId,
      'is_cover': asCover,
      'sort_order': sortOrder,
    });
    return url;
  }

  /// Live property gallery rows for admin management.
  Future<List<PropertyGalleryImage>> listPropertyImages(
    String propertyId,
  ) async {
    final rows = await _c
        .from('property_images')
        .select(
          'id, property_id, url, media_id, is_cover, sort_order, alt_text, media:media_id(secure_url, alt_text, is_published)',
        )
        .eq('property_id', propertyId)
        .eq('is_deleted', false)
        .order('sort_order', ascending: true);
    return (rows as List)
        .map((e) => PropertyGalleryImage.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> deletePropertyImage(String imageId) async {
    final row = await _c
        .from('property_images')
        .select('media_id')
        .eq('id', imageId)
        .maybeSingle();
    await _c
        .from('property_images')
        .update({'is_deleted': true, 'updated_at': _nowIso()})
        .eq('id', imageId);
    final mediaId = row?['media_id']?.toString();
    if (mediaId != null && _media != null) {
      try {
        await _media!.delete(mediaId);
      } catch (_) {}
    }
  }

  Future<void> setPropertyCoverImage(String propertyId, String imageId) async {
    await _c
        .from('property_images')
        .update({'is_cover': false, 'updated_at': _nowIso()})
        .eq('property_id', propertyId)
        .eq('is_deleted', false);
    await _c
        .from('property_images')
        .update({'is_cover': true, 'updated_at': _nowIso()})
        .eq('id', imageId);
    final row = await _c
        .from('property_images')
        .select('media_id')
        .eq('id', imageId)
        .maybeSingle();
    final mediaId = row?['media_id']?.toString();
    if (mediaId != null && _media != null) {
      await _media!.setCover(
        entityType: MediaEntityType.property,
        entityId: propertyId,
        mediaId: mediaId,
      );
    }
  }

  Future<void> reorderPropertyImages(
    String propertyId,
    List<String> orderedImageIds,
  ) async {
    for (var i = 0; i < orderedImageIds.length; i++) {
      await _c
          .from('property_images')
          .update({'sort_order': i, 'updated_at': _nowIso()})
          .eq('id', orderedImageIds[i])
          .eq('property_id', propertyId);
    }
    final mediaIds = <String>[];
    for (final id in orderedImageIds) {
      final row = await _c
          .from('property_images')
          .select('media_id')
          .eq('id', id)
          .maybeSingle();
      final mid = row?['media_id']?.toString();
      if (mid != null) mediaIds.add(mid);
    }
    if (mediaIds.isNotEmpty && _media != null) {
      await _media!.reorder(
        entityType: MediaEntityType.property,
        entityId: propertyId,
        orderedMediaIds: mediaIds,
      );
    }
  }

  Future<void> updatePropertyImageAlt(String imageId, String altText) async {
    await _c
        .from('property_images')
        .update({'alt_text': altText, 'updated_at': _nowIso()})
        .eq('id', imageId);
    final row = await _c
        .from('property_images')
        .select('media_id')
        .eq('id', imageId)
        .maybeSingle();
    final mediaId = row?['media_id']?.toString();
    if (mediaId != null && _media != null) {
      await _media!.updateMediaMetadata(mediaId: mediaId, altText: altText);
    }
  }

  Future<String> replacePropertyImage({
    required String imageId,
    required List<int> bytes,
    required String contentType,
    required String fileName,
    void Function(double progress)? onProgress,
  }) async {
    final row = await _c
        .from('property_images')
        .select('property_id, media_id, is_cover, sort_order')
        .eq('id', imageId)
        .maybeSingle();
    if (row == null) throw StateError('Property image not found.');

    final propertyId = row['property_id'] as String;
    final mediaId = row['media_id']?.toString();
    final media = _media;

    if (mediaId != null && media != null && media.isCloudinaryEnabled) {
      final asset = await media.replace(
        mediaId: mediaId,
        request: UploadMediaRequest(
          bytes: bytes,
          contentType: contentType,
          originalFilename: fileName,
          entityType: MediaEntityType.property,
          entityId: propertyId,
          role: 'gallery',
          onProgress: onProgress,
        ),
      );
      final url = asset.deliveryUrl;
      await _c
          .from('property_images')
          .update({'url': url, 'updated_at': _nowIso()})
          .eq('id', imageId);
      return url;
    }

    final url = await uploadPropertyGalleryImage(
      propertyId: propertyId,
      bytes: bytes,
      contentType: contentType,
      asCover: row['is_cover'] as bool? ?? false,
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
      fileName: fileName,
      onProgress: onProgress,
    );
    await deletePropertyImage(imageId);
    return url;
  }

  Future<String> uploadPropertyCover({
    required String propertyId,
    required List<int> bytes,
    required String contentType,
    String? fileName,
    void Function(double progress)? onProgress,
  }) async {
    return uploadPropertyGalleryImage(
      propertyId: propertyId,
      bytes: bytes,
      contentType: contentType,
      asCover: true,
      sortOrder: 0,
      fileName: fileName,
      onProgress: onProgress,
    );
  }

  Future<String> _uploadPublicImage({
    required String bucket,
    required List<int> bytes,
    required String contentType,
    required String folder,
    String? fileNameHint,
    MediaEntityType entityType = MediaEntityType.marketing,
    String? entityId,
    void Function(double progress)? onProgress,
  }) async {
    // Images/videos always go through Cloudinary via the central media service.
    return _uploadPublicBytes(
      bucket: bucket,
      bytes: bytes,
      contentType: contentType,
      folder: folder,
      fileNameHint: fileNameHint,
      entityType: entityType,
      entityId: entityId,
      role: 'gallery',
      onProgress: onProgress,
    );
  }

  Future<String> _uploadMarketingBytes({
    required List<int> bytes,
    required String contentType,
    required String folder,
  }) async {
    return _uploadPublicBytes(
      bucket: 'marketing',
      bytes: bytes,
      contentType: contentType,
      folder: folder,
      fileNameHint: 'cover',
      entityType: MediaEntityType.marketing,
      role: 'website',
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // Testimonials (testimonials)
  // ───────────────────────────────────────────────────────────────────────

  Future<List<CmsTestimonial>> listTestimonials() async {
    final rows = await _c
        .from('testimonials')
        .select()
        .eq('is_deleted', false)
        .order('is_featured', ascending: false)
        .order('created_at', ascending: false);
    return rows
        .map((e) => CmsTestimonial.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<CmsTestimonial> upsertTestimonial({
    String? id,
    required String clientName,
    String? clientTitle,
    required String content,
    int? rating,
    String? avatarUrl,
    bool isFeatured = false,
    String status = 'active',
  }) async {
    MediaDelivery.assertCloudinaryMediaUrl(
      avatarUrl,
      field: 'Testimonial avatar',
    );
    final payload = {
      if (id != null) 'id': id,
      'client_name': clientName,
      'client_title': clientTitle,
      'content': content,
      'rating': rating,
      'avatar_url': avatarUrl,
      'is_featured': isFeatured,
      'status': status,
      'updated_at': _nowIso(),
    };
    final row = await _c.from('testimonials').upsert(payload).select().single();
    return CmsTestimonial.fromJson(Map<String, dynamic>.from(row));
  }

  /// Client/investor portal — quote waits for admin publish (status=pending).
  Future<CmsTestimonial> submitPortalTestimonial({
    required String clientName,
    String? clientTitle,
    required String content,
    int rating = 5,
  }) async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) {
      throw const AuthenticationException('Sign in to share your experience.');
    }
    final quote = content.trim();
    final name = clientName.trim();
    if (name.isEmpty || quote.length < 20) {
      throw const ValidationException(
        'Please add your name and a short experience (at least 20 characters).',
      );
    }
    final row = await _c
        .from('testimonials')
        .insert({
          'client_name': name,
          'client_title': clientTitle?.trim().isEmpty == true
              ? null
              : clientTitle?.trim(),
          'content': quote,
          'rating': rating.clamp(1, 5),
          'is_featured': false,
          'status': 'pending',
          'is_deleted': false,
          'created_by': uid,
          'updated_at': _nowIso(),
        })
        .select()
        .single();
    return CmsTestimonial.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> setTestimonialStatus(String id, String status) async {
    await _c
        .from('testimonials')
        .update({'status': status, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  Future<void> setTestimonialFeatured(String id, bool featured) async {
    await _c
        .from('testimonials')
        .update({'is_featured': featured, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  Future<void> deleteTestimonial(String id) async {
    await _c
        .from('testimonials')
        .update({'is_deleted': true, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  // ───────────────────────────────────────────────────────────────────────
  // Awards (awards)
  // ───────────────────────────────────────────────────────────────────────

  Future<List<CmsAward>> listAwards() async {
    final rows = await _c
        .from('awards')
        .select()
        .eq('is_deleted', false)
        .order('sort_order')
        .order('created_at', ascending: false);
    return rows
        .map((e) => CmsAward.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<CmsAward> upsertAward({
    String? id,
    required String title,
    required String issuer,
    required String year,
    required String description,
    String? verificationUrl,
    String iconName = 'award',
    int sortOrder = 0,
    bool isFeatured = false,
    String status = 'active',
  }) async {
    final payload = {
      if (id != null) 'id': id,
      'title': title,
      'issuer': issuer,
      'year': year,
      'description': description,
      'verification_url': verificationUrl,
      'icon_name': iconName,
      'sort_order': sortOrder,
      'is_featured': isFeatured,
      'status': status,
      'updated_at': _nowIso(),
    };
    final row = await _c.from('awards').upsert(payload).select().single();
    return CmsAward.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> setAwardFeatured(String id, bool featured) async {
    await _c
        .from('awards')
        .update({'is_featured': featured, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  Future<void> setAwardSortOrder(String id, int sortOrder) async {
    await _c
        .from('awards')
        .update({'sort_order': sortOrder, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  Future<void> deleteAward(String id) async {
    await _c
        .from('awards')
        .update({'is_deleted': true, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  Future<List<CmsAward>> listPublishedAwards({int limit = 12}) async {
    try {
      final rows = await _c
          .from('awards')
          .select()
          .eq('is_deleted', false)
          .eq('status', 'active')
          .order('sort_order')
          .order('is_featured', ascending: false)
          .limit(limit);
      return rows
          .map((e) => CmsAward.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      final rows = await _c
          .from('awards')
          .select()
          .eq('is_deleted', false)
          .order('sort_order')
          .limit(limit);
      return rows
          .map((e) => CmsAward.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
  }

  // ───────────────────────────────────────────────────────────────────────
  // Partners (partners)
  // ───────────────────────────────────────────────────────────────────────

  Future<List<CmsPartner>> listPartners() async {
    final rows = await _c
        .from('partners')
        .select()
        .eq('is_deleted', false)
        .order('sort_order')
        .order('created_at', ascending: false);
    return rows
        .map((e) => CmsPartner.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<CmsPartner> upsertPartner({
    String? id,
    required String name,
    required String category,
    String tagline = '',
    String? logoUrl,
    String iconName = 'building',
    int sortOrder = 0,
    bool showOnHome = true,
    bool showOnAbout = true,
    String status = 'active',
  }) async {
    MediaDelivery.assertCloudinaryMediaUrl(logoUrl, field: 'Partner logo');
    final payload = {
      if (id != null) 'id': id,
      'name': name,
      'category': category,
      'tagline': tagline,
      'logo_url': logoUrl,
      'icon_name': iconName,
      'sort_order': sortOrder,
      'show_on_home': showOnHome,
      'show_on_about': showOnAbout,
      'status': status,
      'updated_at': _nowIso(),
    };
    final row = await _c.from('partners').upsert(payload).select().single();
    return CmsPartner.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> setPartnerSortOrder(String id, int sortOrder) async {
    await _c
        .from('partners')
        .update({'sort_order': sortOrder, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  Future<void> setPartnerVisibility({
    required String id,
    bool? showOnHome,
    bool? showOnAbout,
    String? status,
  }) async {
    await _c
        .from('partners')
        .update({
          if (showOnHome != null) 'show_on_home': showOnHome,
          if (showOnAbout != null) 'show_on_about': showOnAbout,
          if (status != null) 'status': status,
          'updated_at': _nowIso(),
        })
        .eq('id', id);
  }

  Future<void> deletePartner(String id) async {
    await _c
        .from('partners')
        .update({'is_deleted': true, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  Future<String> uploadPartnerLogo({
    required List<int> bytes,
    required String contentType,
  }) => _uploadPublicImage(
    bucket: 'marketing',
    bytes: bytes,
    contentType: contentType,
    folder: 'partners',
  );

  Future<String> uploadBrowseCategoryImage({
    required List<int> bytes,
    required String contentType,
  }) => _uploadPublicImage(
    bucket: 'marketing',
    bytes: bytes,
    contentType: contentType,
    folder: 'browse-categories',
  );

  Future<List<CmsPartner>> listPublishedPartners({
    bool? forHome,
    bool? forAbout,
    int limit = 24,
  }) async {
    try {
      var query = _c
          .from('partners')
          .select()
          .eq('is_deleted', false)
          .eq('status', 'active');
      if (forHome == true) query = query.eq('show_on_home', true);
      if (forAbout == true) query = query.eq('show_on_about', true);
      final rows = await query.order('sort_order').limit(limit);
      return rows
          .map((e) => CmsPartner.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      final rows = await _c
          .from('partners')
          .select()
          .eq('is_deleted', false)
          .order('sort_order')
          .limit(limit);
      return rows
          .map((e) => CmsPartner.fromJson(Map<String, dynamic>.from(e)))
          .where((p) {
            if (forHome == true && !p.showOnHome) return false;
            if (forAbout == true && !p.showOnAbout) return false;
            return true;
          })
          .toList();
    }
  }

  // ───────────────────────────────────────────────────────────────────────
  // Company statistics (company_statistics)
  // ───────────────────────────────────────────────────────────────────────

  Future<List<CmsCompanyStat>> listCompanyStats() async {
    final rows = await _c
        .from('company_statistics')
        .select()
        .eq('is_deleted', false)
        .order('placement')
        .order('sort_order')
        .order('created_at', ascending: false);
    return rows
        .map((e) => CmsCompanyStat.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<CmsCompanyStat> upsertCompanyStat({
    String? id,
    required int value,
    required String label,
    String suffix = '',
    String description = '',
    String iconName = 'barChart',
    String? logoUrl,
    String placement = 'orbit',
    int sortOrder = 0,
    bool showOnHome = true,
    bool showOnAbout = true,
    String status = 'active',
  }) async {
    final payload = {
      if (id != null) 'id': id,
      'value': value,
      'label': label,
      'suffix': suffix,
      'description': description,
      'icon_name': iconName,
      'logo_url': logoUrl,
      'placement': placement,
      'sort_order': sortOrder,
      'show_on_home': showOnHome,
      'show_on_about': showOnAbout,
      'status': status,
      'updated_at': _nowIso(),
    };
    final row = await _c
        .from('company_statistics')
        .upsert(payload)
        .select()
        .single();
    return CmsCompanyStat.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> setCompanyStatSortOrder(String id, int sortOrder) async {
    await _c
        .from('company_statistics')
        .update({'sort_order': sortOrder, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  Future<void> setCompanyStatVisibility({
    required String id,
    bool? showOnHome,
    bool? showOnAbout,
    String? status,
  }) async {
    await _c
        .from('company_statistics')
        .update({
          if (showOnHome != null) 'show_on_home': showOnHome,
          if (showOnAbout != null) 'show_on_about': showOnAbout,
          if (status != null) 'status': status,
          'updated_at': _nowIso(),
        })
        .eq('id', id);
  }

  Future<void> deleteCompanyStat(String id) async {
    await _c
        .from('company_statistics')
        .update({'is_deleted': true, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  Future<String> uploadCompanyStatLogo({
    required List<int> bytes,
    required String contentType,
  }) => _uploadPublicImage(
    bucket: 'marketing',
    bytes: bytes,
    contentType: contentType,
    folder: 'company-stats',
  );

  Future<List<CmsCompanyStat>> listPublishedCompanyStats({
    bool? forHome,
    bool? forAbout,
    int limit = 48,
  }) async {
    try {
      var query = _c
          .from('company_statistics')
          .select()
          .eq('is_deleted', false)
          .eq('status', 'active');
      if (forHome == true) query = query.eq('show_on_home', true);
      if (forAbout == true) query = query.eq('show_on_about', true);
      final rows = await query
          .order('placement')
          .order('sort_order')
          .limit(limit);
      return rows
          .map((e) => CmsCompanyStat.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      final rows = await _c
          .from('company_statistics')
          .select()
          .eq('is_deleted', false)
          .order('sort_order')
          .limit(limit);
      return rows
          .map((e) => CmsCompanyStat.fromJson(Map<String, dynamic>.from(e)))
          .where((s) {
            if (forHome == true && !s.showOnHome) return false;
            if (forAbout == true && !s.showOnAbout) return false;
            return true;
          })
          .toList();
    }
  }

  // ───────────────────────────────────────────────────────────────────────
  // Careers CMS (careers_settings / career_jobs / benefits / stats / tags)
  // ───────────────────────────────────────────────────────────────────────

  Future<CmsCareersSettings> getCareersSettings() async {
    final rows = await _c.from('careers_settings').select().limit(1);
    if (rows.isEmpty) {
      final created = await _c
          .from('careers_settings')
          .insert({'updated_at': _nowIso()})
          .select()
          .single();
      return CmsCareersSettings.fromJson(Map<String, dynamic>.from(created));
    }
    return CmsCareersSettings.fromJson(Map<String, dynamic>.from(rows.first));
  }

  Future<CmsCareersSettings> upsertCareersSettings({
    required String id,
    required String heroOverline,
    required String heroTitleLine1,
    required String heroTitleLine2,
    required String heroBody,
    String? heroImageUrl,
    required String cultureSummary,
    required String aboutSubtitle,
    required String ctaPrimaryLabel,
    required String ctaSecondaryLabel,
    required String cvBannerText,
    required String cvBannerCtaLabel,
    required String cvEmail,
    String? seoTitle,
    String? seoDescription,
    int? openPositionsOverride,
  }) async {
    final row = await _c
        .from('careers_settings')
        .upsert({
          'id': id,
          'hero_overline': heroOverline,
          'hero_title_line1': heroTitleLine1,
          'hero_title_line2': heroTitleLine2,
          'hero_body': heroBody,
          'hero_image_url': heroImageUrl,
          'culture_summary': cultureSummary,
          'about_subtitle': aboutSubtitle,
          'cta_primary_label': ctaPrimaryLabel,
          'cta_secondary_label': ctaSecondaryLabel,
          'cv_banner_text': cvBannerText,
          'cv_banner_cta_label': cvBannerCtaLabel,
          'cv_email': cvEmail,
          'seo_title': seoTitle,
          'seo_description': seoDescription,
          'open_positions_override': openPositionsOverride,
          'updated_at': _nowIso(),
        })
        .select()
        .single();
    return CmsCareersSettings.fromJson(Map<String, dynamic>.from(row));
  }

  Future<String> uploadCareersHeroImage({
    required List<int> bytes,
    required String contentType,
  }) => _uploadPublicImage(
    bucket: 'marketing',
    bytes: bytes,
    contentType: contentType,
    folder: 'careers',
  );

  Future<List<CmsCareerJob>> listCareerJobs() async {
    final rows = await _c
        .from('career_jobs')
        .select()
        .eq('is_deleted', false)
        .order('sort_order');
    return rows
        .map((e) => CmsCareerJob.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<CmsCareerJob> upsertCareerJob({
    String? id,
    required String title,
    String department = '',
    String location = '',
    String employmentType = 'Full Time',
    String summary = '',
    String description = '',
    String iconName = 'briefcase',
    String? applyUrl,
    int sortOrder = 0,
    bool isFeatured = false,
    String status = 'active',
    String requirements = '',
    DateTime? applicationDeadline,
  }) async {
    final row = await _c
        .from('career_jobs')
        .upsert({
          if (id != null) 'id': id,
          'title': title,
          'department': department,
          'location': location,
          'employment_type': employmentType,
          'summary': summary,
          'description': description,
          'requirements': requirements,
          'application_deadline': applicationDeadline
              ?.toUtc()
              .toIso8601String(),
          'icon_name': iconName,
          'apply_url': applyUrl,
          'sort_order': sortOrder,
          'is_featured': isFeatured,
          'status': status,
          'updated_at': _nowIso(),
        })
        .select()
        .single();
    return CmsCareerJob.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> setCareerJobSortOrder(String id, int sortOrder) async {
    await _c
        .from('career_jobs')
        .update({'sort_order': sortOrder, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  Future<void> deleteCareerJob(String id) async {
    await _c
        .from('career_jobs')
        .update({'is_deleted': true, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  Future<List<CmsCareerJob>> listPublishedCareerJobs({int limit = 40}) async {
    final rows = await _c
        .from('career_jobs')
        .select()
        .eq('is_deleted', false)
        .eq('status', 'active')
        .order('sort_order')
        .limit(limit);
    return rows
        .map((e) => CmsCareerJob.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<CmsCareerBenefit>> listCareerBenefits() async {
    final rows = await _c
        .from('career_benefits')
        .select()
        .eq('is_deleted', false)
        .order('sort_order');
    return rows
        .map((e) => CmsCareerBenefit.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<CmsCareerBenefit> upsertCareerBenefit({
    String? id,
    required String title,
    String description = '',
    String iconName = 'sparkles',
    int sortOrder = 0,
    String status = 'active',
  }) async {
    final row = await _c
        .from('career_benefits')
        .upsert({
          if (id != null) 'id': id,
          'title': title,
          'description': description,
          'icon_name': iconName,
          'sort_order': sortOrder,
          'status': status,
          'updated_at': _nowIso(),
        })
        .select()
        .single();
    return CmsCareerBenefit.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> setCareerBenefitSortOrder(String id, int sortOrder) async {
    await _c
        .from('career_benefits')
        .update({'sort_order': sortOrder, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  Future<void> deleteCareerBenefit(String id) async {
    await _c
        .from('career_benefits')
        .update({'is_deleted': true, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  Future<List<CmsCareerBenefit>> listPublishedCareerBenefits() async {
    final rows = await _c
        .from('career_benefits')
        .select()
        .eq('is_deleted', false)
        .eq('status', 'active')
        .order('sort_order');
    return rows
        .map((e) => CmsCareerBenefit.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<CmsCareerStat>> listCareerStats() async {
    final rows = await _c
        .from('career_stats')
        .select()
        .eq('is_deleted', false)
        .order('sort_order');
    return rows
        .map((e) => CmsCareerStat.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<CmsCareerStat> upsertCareerStat({
    String? id,
    required String value,
    required String label,
    String iconName = 'briefcase',
    int sortOrder = 0,
    String status = 'active',
  }) async {
    final row = await _c
        .from('career_stats')
        .upsert({
          if (id != null) 'id': id,
          'value': value,
          'label': label,
          'icon_name': iconName,
          'sort_order': sortOrder,
          'status': status,
          'updated_at': _nowIso(),
        })
        .select()
        .single();
    return CmsCareerStat.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> setCareerStatSortOrder(String id, int sortOrder) async {
    await _c
        .from('career_stats')
        .update({'sort_order': sortOrder, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  Future<void> deleteCareerStat(String id) async {
    await _c
        .from('career_stats')
        .update({'is_deleted': true, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  Future<List<CmsCareerStat>> listPublishedCareerStats() async {
    final rows = await _c
        .from('career_stats')
        .select()
        .eq('is_deleted', false)
        .eq('status', 'active')
        .order('sort_order');
    return rows
        .map((e) => CmsCareerStat.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<CmsCareerTag>> listCareerTags() async {
    final rows = await _c
        .from('career_tags')
        .select()
        .eq('is_deleted', false)
        .order('kind')
        .order('sort_order');
    return rows
        .map((e) => CmsCareerTag.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<CmsCareerTag> upsertCareerTag({
    String? id,
    required String label,
    String kind = 'benefit_pill',
    int sortOrder = 0,
    String status = 'active',
  }) async {
    final row = await _c
        .from('career_tags')
        .upsert({
          if (id != null) 'id': id,
          'label': label,
          'kind': kind,
          'sort_order': sortOrder,
          'status': status,
          'updated_at': _nowIso(),
        })
        .select()
        .single();
    return CmsCareerTag.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> setCareerTagSortOrder(String id, int sortOrder) async {
    await _c
        .from('career_tags')
        .update({'sort_order': sortOrder, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  Future<void> deleteCareerTag(String id) async {
    await _c
        .from('career_tags')
        .update({'is_deleted': true, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  Future<List<CmsCareerTag>> listPublishedCareerTags() async {
    final rows = await _c
        .from('career_tags')
        .select()
        .eq('is_deleted', false)
        .eq('status', 'active')
        .order('kind')
        .order('sort_order');
    return rows
        .map((e) => CmsCareerTag.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  // ───────────────────────────────────────────────────────────────────────
  // Client journey steps
  // ───────────────────────────────────────────────────────────────────────

  Future<List<CmsClientJourneyStep>> listClientJourneySteps() async {
    final rows = await _c
        .from('client_journey_steps')
        .select()
        .eq('is_deleted', false)
        .order('sort_order')
        .order('created_at', ascending: false);
    return rows
        .map((e) => CmsClientJourneyStep.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<CmsClientJourneyStep> upsertClientJourneyStep({
    String? id,
    required String title,
    String description = '',
    String timeline = '',
    String iconName = 'circle',
    int sortOrder = 0,
    String status = 'active',
  }) async {
    final payload = {
      if (id != null) 'id': id,
      'title': title,
      'description': description,
      'timeline': timeline,
      'icon_name': iconName,
      'sort_order': sortOrder,
      'status': status,
      'updated_at': _nowIso(),
    };
    final row = await _c
        .from('client_journey_steps')
        .upsert(payload)
        .select()
        .single();
    return CmsClientJourneyStep.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> setClientJourneyStepSortOrder(String id, int sortOrder) async {
    await _c
        .from('client_journey_steps')
        .update({'sort_order': sortOrder, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  Future<void> setClientJourneyStepStatus({
    required String id,
    required String status,
  }) async {
    await _c
        .from('client_journey_steps')
        .update({'status': status, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  Future<void> deleteClientJourneyStep(String id) async {
    await _c
        .from('client_journey_steps')
        .update({'is_deleted': true, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  Future<List<CmsClientJourneyStep>> listPublishedClientJourneySteps({
    int limit = 24,
  }) async {
    final rows = await _c
        .from('client_journey_steps')
        .select()
        .eq('is_deleted', false)
        .eq('status', 'active')
        .order('sort_order', ascending: true)
        .limit(limit);
    return rows
        .map((e) => CmsClientJourneyStep.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  // ───────────────────────────────────────────────────────────────────────
  // Journey benefits
  // ───────────────────────────────────────────────────────────────────────

  Future<List<CmsJourneyBenefit>> listJourneyBenefits() async {
    final rows = await _c
        .from('journey_benefits')
        .select()
        .eq('is_deleted', false)
        .order('sort_order')
        .order('created_at', ascending: false);
    return rows
        .map((e) => CmsJourneyBenefit.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<CmsJourneyBenefit> upsertJourneyBenefit({
    String? id,
    required String title,
    String description = '',
    String iconName = 'shield',
    int sortOrder = 0,
    String status = 'active',
  }) async {
    final payload = {
      if (id != null) 'id': id,
      'title': title,
      'description': description,
      'icon_name': iconName,
      'sort_order': sortOrder,
      'status': status,
      'updated_at': _nowIso(),
    };
    final row = await _c
        .from('journey_benefits')
        .upsert(payload)
        .select()
        .single();
    return CmsJourneyBenefit.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> setJourneyBenefitSortOrder(String id, int sortOrder) async {
    await _c
        .from('journey_benefits')
        .update({'sort_order': sortOrder, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  Future<void> setJourneyBenefitStatus({
    required String id,
    required String status,
  }) async {
    await _c
        .from('journey_benefits')
        .update({'status': status, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  Future<void> deleteJourneyBenefit(String id) async {
    await _c
        .from('journey_benefits')
        .update({'is_deleted': true, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  Future<List<CmsJourneyBenefit>> listPublishedJourneyBenefits({
    int limit = 12,
  }) async {
    final rows = await _c
        .from('journey_benefits')
        .select()
        .eq('is_deleted', false)
        .eq('status', 'active')
        .order('sort_order')
        .limit(limit);
    return rows
        .map((e) => CmsJourneyBenefit.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  // ───────────────────────────────────────────────────────────────────────
  // Office locations
  // ───────────────────────────────────────────────────────────────────────

  Future<List<CmsOfficeLocation>> listOfficeLocations() async {
    final rows = await _c
        .from('office_locations')
        .select()
        .eq('is_deleted', false)
        .order('sort_order')
        .order('created_at', ascending: false);
    return rows
        .map((e) => CmsOfficeLocation.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<CmsOfficeLocation> upsertOfficeLocation({
    String? id,
    required String name,
    String? slug,
    String officeType = 'Office',
    String shortDescription = '',
    String description = '',
    String address = '',
    String city = '',
    String state = '',
    String country = 'Nigeria',
    double? latitude,
    double? longitude,
    String phone = '',
    String whatsapp = '',
    String email = '',
    String hours = '',
    String mapUrl = 'https://maps.google.com',
    String appointmentPath = '/book-inspection',
    String mapLabel = 'View Map',
    String appointmentLabel = 'Book Appointment',
    String? coverImage,
    String parkingInfo = '',
    List<String> nearbyLandmarks = const [],
    bool isFeatured = false,
    bool showOnMap = true,
    bool allowAppointments = true,
    Map<String, bool> facilities = const {},
    int sortOrder = 0,
    String status = 'active',
  }) async {
    final payload = {
      if (id != null) 'id': id,
      'name': name,
      if (slug != null && slug.trim().isNotEmpty) 'slug': slug.trim(),
      'office_type': officeType,
      'short_description': shortDescription,
      'description': description,
      'address': address,
      'city': city,
      'state': state,
      'country': country,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'phone': phone,
      'whatsapp': whatsapp,
      'email': email,
      'hours': hours,
      'map_url': mapUrl,
      'appointment_path': appointmentPath,
      'map_label': mapLabel,
      'appointment_label': appointmentLabel,
      if (coverImage != null) 'cover_image': coverImage,
      'parking_info': parkingInfo,
      'nearby_landmarks': nearbyLandmarks,
      'is_featured': isFeatured,
      'show_on_map': showOnMap,
      'allow_appointments': allowAppointments,
      'facilities': facilities,
      'sort_order': sortOrder,
      'status': status,
      'updated_at': _nowIso(),
    };
    final row = await _c
        .from('office_locations')
        .upsert(payload)
        .select()
        .single();
    return CmsOfficeLocation.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> setOfficeLocationSortOrder(String id, int sortOrder) async {
    await _c
        .from('office_locations')
        .update({'sort_order': sortOrder, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  Future<void> setOfficeLocationStatus({
    required String id,
    required String status,
  }) async {
    await _c
        .from('office_locations')
        .update({'status': status, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  Future<void> deleteOfficeLocation(String id) async {
    await _c
        .from('office_locations')
        .update({'is_deleted': true, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  Future<List<CmsOfficeLocation>> listPublishedOfficeLocations({
    int limit = 24,
  }) async {
    final rows = await _c
        .from('office_locations')
        .select()
        .eq('is_deleted', false)
        .eq('status', 'active')
        .order('sort_order')
        .limit(limit);
    return rows
        .map((e) => CmsOfficeLocation.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<OfficeHourEntry>> listOfficeHours(String officeId) async {
    final rows = await _c
        .from('office_hours')
        .select()
        .eq('office_id', officeId)
        .order('day_of_week');
    return rows
        .map((e) => OfficeHourEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<OfficeHourEntry>> listPublishedOfficeHours() async {
    final rows = await _c.from('office_hours').select().order('day_of_week');
    return rows
        .map((e) => OfficeHourEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> upsertOfficeHours({
    required String officeId,
    required List<OfficeHourEntry> hours,
  }) async {
    for (final h in hours) {
      await _c.from('office_hours').upsert({
        if (h.id.isNotEmpty) 'id': h.id,
        'office_id': officeId,
        'day_of_week': h.dayOfWeek,
        'is_open': h.isOpen,
        'open_time': h.openTime,
        'close_time': h.closeTime,
        'updated_at': _nowIso(),
      });
    }
  }

  Future<List<OfficeMediaEntry>> listOfficeMedia(String officeId) async {
    final rows = await _c
        .from('office_media')
        .select()
        .eq('office_id', officeId)
        .order('sort_order');
    return rows
        .map((e) => OfficeMediaEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<OfficeMediaEntry>> listPublishedOfficeMedia() async {
    final rows = await _c.from('office_media').select().order('sort_order');
    return rows
        .map((e) => OfficeMediaEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<OfficeMediaEntry> addOfficeMedia({
    required String officeId,
    required String storagePath,
    String mediaType = 'image',
    int sortOrder = 0,
    bool isCover = false,
  }) async {
    if (isCover) {
      await _c
          .from('office_media')
          .update({'is_cover': false})
          .eq('office_id', officeId);
      await _c
          .from('office_locations')
          .update({'cover_image': storagePath, 'updated_at': _nowIso()})
          .eq('id', officeId);
    }
    final row = await _c
        .from('office_media')
        .insert({
          'office_id': officeId,
          'media_type': mediaType,
          'storage_path': storagePath,
          'sort_order': sortOrder,
          'is_cover': isCover,
        })
        .select()
        .single();
    return OfficeMediaEntry.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> deleteOfficeMedia(String id) async {
    await _c.from('office_media').delete().eq('id', id);
  }

  Future<String> uploadOfficeImage({
    required String officeId,
    required List<int> bytes,
    required String filename,
    String contentType = 'image/jpeg',
  }) async {
    return _uploadPublicImage(
      bucket: 'marketing',
      bytes: bytes,
      contentType: contentType,
      folder: 'offices/$officeId',
    );
  }

  Future<CmsOfficeLocation?> duplicateOfficeLocation(String id) async {
    final offices = await listOfficeLocations();
    CmsOfficeLocation? source;
    for (final o in offices) {
      if (o.id == id) {
        source = o;
        break;
      }
    }
    if (source == null) return null;
    return upsertOfficeLocation(
      name: '${source.name} (Copy)',
      slug: source.slug != null ? '${source.slug}-copy' : null,
      officeType: source.officeType,
      shortDescription: source.shortDescription,
      description: source.description,
      address: source.address,
      city: source.city,
      state: source.state,
      country: source.country,
      latitude: source.latitude,
      longitude: source.longitude,
      phone: source.phone,
      whatsapp: source.whatsapp,
      email: source.email,
      hours: source.hours,
      mapUrl: source.mapUrl,
      appointmentPath: source.appointmentPath,
      mapLabel: source.mapLabel,
      appointmentLabel: source.appointmentLabel,
      coverImage: source.coverImage,
      parkingInfo: source.parkingInfo,
      nearbyLandmarks: source.nearbyLandmarks,
      isFeatured: false,
      showOnMap: source.showOnMap,
      allowAppointments: source.allowAppointments,
      facilities: source.facilities,
      sortOrder: source.sortOrder + 1,
      status: 'draft',
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // Website browse categories (marketing CMS)
  // ───────────────────────────────────────────────────────────────────────

  Future<List<CmsBrowseCategory>> listBrowseCategories() async {
    final rows = await _c
        .from('website_browse_categories')
        .select()
        .eq('is_deleted', false)
        .order('sort_order');
    return rows
        .map((e) => CmsBrowseCategory.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<CmsBrowseCategory>> listPublishedBrowseCategories({
    int limit = 24,
  }) async {
    final rows = await _c
        .from('website_browse_categories')
        .select()
        .eq('is_deleted', false)
        .eq('status', 'active')
        .order('sort_order')
        .limit(limit);
    return rows
        .map((e) => CmsBrowseCategory.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<CmsBrowseCategory> upsertBrowseCategory({
    String? id,
    required String label,
    required String filterKey,
    String description = '',
    String iconName = 'home',
    String? imageUrl,
    bool isFeatured = false,
    int sortOrder = 0,
    String status = 'active',
  }) async {
    final row = await _c
        .from('website_browse_categories')
        .upsert({
          if (id != null) 'id': id,
          'label': label,
          'filter_key': filterKey,
          'description': description,
          'icon_name': iconName,
          'image_url': imageUrl,
          'is_featured': isFeatured,
          'sort_order': sortOrder,
          'status': status,
          'updated_at': _nowIso(),
        })
        .select()
        .single();
    return CmsBrowseCategory.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> setBrowseCategorySortOrder(String id, int sortOrder) async {
    await _c
        .from('website_browse_categories')
        .update({'sort_order': sortOrder, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  Future<void> deleteBrowseCategory(String id) async {
    await _c
        .from('website_browse_categories')
        .update({'is_deleted': true, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  // ───────────────────────────────────────────────────────────────────────
  // Website investment opportunities (marketing CMS)
  // ───────────────────────────────────────────────────────────────────────

  Future<List<CmsWebsiteInvestmentOpportunity>>
  listWebsiteInvestmentOpportunities() async {
    final rows = await _c
        .from('website_investment_opportunities')
        .select()
        .eq('is_deleted', false)
        .order('is_featured', ascending: false)
        .order('sort_order')
        .order('created_at', ascending: false);
    return rows
        .map(
          (e) => CmsWebsiteInvestmentOpportunity.fromJson(
            Map<String, dynamic>.from(e),
          ),
        )
        .toList();
  }

  Future<List<CmsWebsiteInvestmentOpportunity>>
  listPublishedWebsiteInvestmentOpportunities({int limit = 48}) async {
    final rows = await _c
        .from('website_investment_opportunities')
        .select()
        .eq('is_deleted', false)
        .eq('status', 'active')
        .order('is_featured', ascending: false)
        .order('sort_order')
        .limit(limit);
    return rows
        .map(
          (e) => CmsWebsiteInvestmentOpportunity.fromJson(
            Map<String, dynamic>.from(e),
          ),
        )
        .toList();
  }

  Future<CmsWebsiteInvestmentOpportunity?> getPublishedWebsiteInvestmentBySlug(
    String slug,
  ) async {
    final rows = await _c
        .from('website_investment_opportunities')
        .select()
        .eq('is_deleted', false)
        .eq('status', 'active')
        .eq('slug', slug)
        .limit(1);
    if (rows.isEmpty) return null;
    return CmsWebsiteInvestmentOpportunity.fromJson(
      Map<String, dynamic>.from(rows.first),
    );
  }

  Future<CmsWebsiteInvestmentOpportunity> upsertWebsiteInvestmentOpportunity({
    String? id,
    required String projectName,
    required String slug,
    String? coverImageUrl,
    List<String> galleryImages = const [],
    String shortDescription = '',
    String fullDescription = '',
    String investmentType = 'Real Estate Fund',
    String typeLabel = 'Estate Development',
    String? categoryId,
    String location = '',
    String city = '',
    double roiMin = 0,
    double roiMax = 0,
    String roiLabel = '',
    String duration = '',
    String riskLevel = 'Moderate',
    String growthPotential = 'High',
    String minimumInvestment = '',
    String targetAmount = '',
    String amountRaised = '',
    double progressPct = 0,
    String opportunityStatus = 'open',
    bool isFeatured = false,
    String featuredBadge = 'Featured',
    String? demandBadge,
    String ctaLabel = 'View Opportunity',
    String? ctaLink,
    String secondaryCtaLabel = '',
    String? secondaryCtaLink,
    bool showProgress = true,
    String metaTitle = '',
    String metaDescription = '',
    String? openingDate,
    String? closingDate,
    int sortOrder = 0,
    String status = 'active',
  }) async {
    final clampedProgress = progressPct.clamp(0, 100);
    final payload = {
      if (id != null) 'id': id,
      'project_name': projectName,
      'slug': slug,
      'cover_image_url': coverImageUrl,
      'gallery_images': galleryImages,
      'short_description': shortDescription,
      'full_description': fullDescription,
      'investment_type': investmentType,
      'type_label': typeLabel,
      'category_id': categoryId,
      'location': location,
      'city': city,
      'roi_min': roiMin < 0 ? 0 : roiMin,
      'roi_max': roiMax < 0 ? 0 : roiMax,
      'roi_label': roiLabel,
      'duration': duration,
      'risk_level': riskLevel,
      'growth_potential': growthPotential,
      'minimum_investment': minimumInvestment,
      'target_amount': targetAmount,
      'amount_raised': amountRaised,
      'progress_pct': clampedProgress,
      'opportunity_status': opportunityStatus,
      'is_featured': isFeatured,
      'featured_badge': featuredBadge,
      'demand_badge': demandBadge,
      'cta_label': ctaLabel,
      'cta_link': ctaLink,
      'secondary_cta_label': secondaryCtaLabel,
      'secondary_cta_link': secondaryCtaLink,
      'show_progress': showProgress,
      'meta_title': metaTitle,
      'meta_description': metaDescription,
      'opening_date': openingDate,
      'closing_date': closingDate,
      'sort_order': sortOrder,
      'status': status,
      'updated_at': _nowIso(),
    };
    final row = await _c
        .from('website_investment_opportunities')
        .upsert(payload)
        .select()
        .single();
    return CmsWebsiteInvestmentOpportunity.fromJson(
      Map<String, dynamic>.from(row),
    );
  }

  Future<void> setWebsiteInvestmentSortOrder(String id, int sortOrder) async {
    await _c
        .from('website_investment_opportunities')
        .update({'sort_order': sortOrder, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  Future<void> setWebsiteInvestmentStatus({
    required String id,
    required String status,
  }) async {
    await _c
        .from('website_investment_opportunities')
        .update({'status': status, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  Future<void> setWebsiteInvestmentFeatured({
    required String id,
    required bool isFeatured,
  }) async {
    await _c
        .from('website_investment_opportunities')
        .update({'is_featured': isFeatured, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  Future<void> deleteWebsiteInvestmentOpportunity(String id) async {
    await _c
        .from('website_investment_opportunities')
        .update({'is_deleted': true, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  Future<void> setWebsiteInvestmentOpportunityStatus({
    required String id,
    required String opportunityStatus,
  }) async {
    await _c
        .from('website_investment_opportunities')
        .update({
          'opportunity_status': opportunityStatus,
          'updated_at': _nowIso(),
        })
        .eq('id', id);
  }

  Future<void> setWebsiteInvestmentCategoryId({
    required String id,
    required String? categoryId,
  }) async {
    await _c
        .from('website_investment_opportunities')
        .update({'category_id': categoryId, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  Future<CmsWebsiteInvestmentOpportunity> duplicateWebsiteInvestmentOpportunity(
    CmsWebsiteInvestmentOpportunity source,
  ) async {
    return upsertWebsiteInvestmentOpportunity(
      projectName: '${source.projectName} (Copy)',
      slug: '${source.slug}-copy-${DateTime.now().millisecondsSinceEpoch}',
      coverImageUrl: source.coverImageUrl,
      galleryImages: source.galleryImages,
      shortDescription: source.shortDescription,
      fullDescription: source.fullDescription,
      investmentType: source.investmentType,
      typeLabel: source.typeLabel,
      categoryId: source.categoryId,
      location: source.location,
      city: source.city,
      roiMin: source.roiMin,
      roiMax: source.roiMax,
      roiLabel: source.roiLabel,
      duration: source.duration,
      riskLevel: source.riskLevel,
      growthPotential: source.growthPotential,
      minimumInvestment: source.minimumInvestment,
      targetAmount: source.targetAmount,
      amountRaised: source.amountRaised,
      progressPct: source.progressPct,
      opportunityStatus: source.opportunityStatus,
      isFeatured: false,
      featuredBadge: source.featuredBadge,
      demandBadge: source.demandBadge,
      ctaLabel: source.ctaLabel,
      ctaLink: source.ctaLink,
      secondaryCtaLabel: source.secondaryCtaLabel,
      secondaryCtaLink: source.secondaryCtaLink,
      showProgress: source.showProgress,
      metaTitle: source.metaTitle,
      metaDescription: source.metaDescription,
      openingDate: source.openingDate,
      closingDate: source.closingDate,
      sortOrder: source.sortOrder + 5,
      status: 'draft',
    );
  }

  Future<List<CmsWebsiteInvestmentCategory>> listWebsiteInvestmentCategories({
    bool includeInactive = true,
  }) async {
    var query = _c
        .from('website_investment_categories')
        .select()
        .eq('is_deleted', false);
    if (!includeInactive) {
      query = query.eq('is_active', true);
    }
    final rows = await query.order('display_order');
    return rows
        .map(
          (e) => CmsWebsiteInvestmentCategory.fromJson(
            Map<String, dynamic>.from(e),
          ),
        )
        .toList();
  }

  Future<List<CmsWebsiteInvestmentCategory>>
  listPublishedWebsiteInvestmentCategories() {
    return listWebsiteInvestmentCategories(includeInactive: false);
  }

  Future<CmsWebsiteInvestmentCategory> upsertWebsiteInvestmentCategory({
    String? id,
    required String name,
    required String slug,
    String description = '',
    String icon = 'building2',
    int displayOrder = 0,
    bool isActive = true,
  }) async {
    final payload = {
      if (id != null) 'id': id,
      'name': name,
      'slug': slug,
      'description': description,
      'icon': icon,
      'display_order': displayOrder,
      'is_active': isActive,
      'updated_at': _nowIso(),
    };
    final row = await _c
        .from('website_investment_categories')
        .upsert(payload)
        .select()
        .single();
    return CmsWebsiteInvestmentCategory.fromJson(
      Map<String, dynamic>.from(row),
    );
  }

  Future<void> setWebsiteInvestmentCategoryOrder(String id, int order) async {
    await _c
        .from('website_investment_categories')
        .update({'display_order': order, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  Future<void> setWebsiteInvestmentCategoryActive({
    required String id,
    required bool isActive,
  }) async {
    await _c
        .from('website_investment_categories')
        .update({'is_active': isActive, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  Future<void> deleteWebsiteInvestmentCategory(String id) async {
    await _c
        .from('website_investment_categories')
        .update({
          'is_deleted': true,
          'is_active': false,
          'updated_at': _nowIso(),
        })
        .eq('id', id);
  }

  Future<String> uploadWebsiteInvestmentCover({
    required List<int> bytes,
    required String contentType,
  }) => _uploadPublicImage(
    bucket: 'marketing',
    bytes: bytes,
    contentType: contentType,
    folder: 'investment-opportunities',
  );

  Future<String> uploadWebsiteInvestmentGalleryImage({
    required List<int> bytes,
    required String contentType,
  }) => _uploadPublicImage(
    bucket: 'marketing',
    bytes: bytes,
    contentType: contentType,
    folder: 'investment-opportunities/gallery',
  );

  // ───────────────────────────────────────────────────────────────────────
  // Website construction updates (marketing CMS)
  // ───────────────────────────────────────────────────────────────────────

  Future<List<CmsWebsiteConstructionUpdate>>
  listWebsiteConstructionUpdates() async {
    final rows = await _c
        .from('website_construction_updates')
        .select()
        .eq('is_deleted', false)
        .order('sort_order')
        .order('created_at', ascending: false);
    return rows
        .map(
          (e) => CmsWebsiteConstructionUpdate.fromJson(
            Map<String, dynamic>.from(e),
          ),
        )
        .toList();
  }

  Future<List<CmsWebsiteConstructionUpdate>>
  listPublishedWebsiteConstructionUpdates({int limit = 48}) async {
    final rows = await _c
        .from('website_construction_updates')
        .select()
        .eq('is_deleted', false)
        .eq('status', 'active')
        .order('sort_order')
        .limit(limit);
    return rows
        .map(
          (e) => CmsWebsiteConstructionUpdate.fromJson(
            Map<String, dynamic>.from(e),
          ),
        )
        .toList();
  }

  Future<CmsWebsiteConstructionUpdate?> getPublishedWebsiteConstructionBySlug(
    String slug,
  ) async {
    final rows = await _c
        .from('website_construction_updates')
        .select()
        .eq('is_deleted', false)
        .eq('status', 'active')
        .eq('slug', slug)
        .limit(1);
    if (rows.isEmpty) return null;
    return CmsWebsiteConstructionUpdate.fromJson(
      Map<String, dynamic>.from(rows.first),
    );
  }

  Future<CmsWebsiteConstructionUpdate> upsertWebsiteConstructionUpdate({
    String? id,
    required String projectName,
    required String slug,
    String statusUpdate = '',
    String expectedCompletion = '',
    double progressPct = 0,
    int currentPhaseIndex = 0,
    List<String> phases = const [
      'Planning',
      'Foundation',
      'Structure',
      'Roofing',
      'Finishing',
      'Completed',
    ],
    String? coverImageUrl,
    List<String> galleryImageUrls = const [],
    String ctaLabel = 'View Progress',
    String? ctaLink,
    int sortOrder = 0,
    String status = 'active',
  }) async {
    final payload = {
      if (id != null) 'id': id,
      'project_name': projectName,
      'slug': slug,
      'status_update': statusUpdate,
      'expected_completion': expectedCompletion,
      'progress_pct': progressPct,
      'current_phase_index': currentPhaseIndex,
      'phases': phases,
      'cover_image_url': coverImageUrl,
      'gallery_image_urls': galleryImageUrls,
      'cta_label': ctaLabel,
      'cta_link': ctaLink,
      'sort_order': sortOrder,
      'status': status,
      'updated_at': _nowIso(),
    };
    final row = await _c
        .from('website_construction_updates')
        .upsert(payload)
        .select()
        .single();
    return CmsWebsiteConstructionUpdate.fromJson(
      Map<String, dynamic>.from(row),
    );
  }

  Future<void> setWebsiteConstructionSortOrder(String id, int sortOrder) async {
    await _c
        .from('website_construction_updates')
        .update({'sort_order': sortOrder, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  Future<void> setWebsiteConstructionStatus({
    required String id,
    required String status,
  }) async {
    await _c
        .from('website_construction_updates')
        .update({'status': status, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  Future<void> deleteWebsiteConstructionUpdate(String id) async {
    await _c
        .from('website_construction_updates')
        .update({'is_deleted': true, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  Future<String> uploadWebsiteConstructionCover({
    required List<int> bytes,
    required String contentType,
    String? updateId,
  }) => _uploadPublicImage(
    bucket: 'marketing',
    bytes: bytes,
    contentType: contentType,
    folder: 'construction-updates',
    entityType: MediaEntityType.construction,
    entityId: updateId,
  );

  // ───────────────────────────────────────────────────────────────────────
  // Digital company profile (singleton)
  // ───────────────────────────────────────────────────────────────────────

  Future<CmsDigitalCompanyProfile> getDigitalCompanyProfile() async {
    final rows = await _c.from('digital_company_profile').select().limit(1);
    if (rows.isEmpty) {
      final created = await _c
          .from('digital_company_profile')
          .insert({'updated_at': _nowIso()})
          .select()
          .single();
      return CmsDigitalCompanyProfile.fromJson(
        Map<String, dynamic>.from(created),
      );
    }
    return CmsDigitalCompanyProfile.fromJson(
      Map<String, dynamic>.from(rows.first),
    );
  }

  Future<CmsDigitalCompanyProfile?> getPublishedDigitalCompanyProfile() async {
    final rows = await _c
        .from('digital_company_profile')
        .select()
        .eq('status', 'active')
        .limit(1);
    if (rows.isEmpty) return null;
    return CmsDigitalCompanyProfile.fromJson(
      Map<String, dynamic>.from(rows.first),
    );
  }

  Future<CmsDigitalCompanyProfile> upsertDigitalCompanyProfile({
    required String id,
    required String overline,
    required String title,
    required String subtitle,
    required String cardTitle,
    required String cardDescription,
    required List<String> features,
    required String ctaLabel,
    required String viewUrl,
    String? mockupImageUrl,
    required String pdfLabel,
    required String pdfUrl,
    required String pdfMeta,
    required String brochureLabel,
    required String brochureUrl,
    required String brochureMeta,
    required String trustMessage,
    required int yearsValue,
    required String yearsSuffix,
    required String yearsLabel,
    required int homesValue,
    required String homesSuffix,
    required String homesLabel,
    required int clientsValue,
    required String clientsSuffix,
    required String clientsLabel,
    required int projectsValue,
    required String projectsSuffix,
    required String projectsLabel,
    String status = 'active',
  }) async {
    final row = await _c
        .from('digital_company_profile')
        .upsert({
          'id': id,
          'overline': overline,
          'title': title,
          'subtitle': subtitle,
          'card_title': cardTitle,
          'card_description': cardDescription,
          'features': features,
          'cta_label': ctaLabel,
          'view_url': viewUrl,
          'mockup_image_url': mockupImageUrl,
          'pdf_label': pdfLabel,
          'pdf_url': pdfUrl,
          'pdf_meta': pdfMeta,
          'brochure_label': brochureLabel,
          'brochure_url': brochureUrl,
          'brochure_meta': brochureMeta,
          'trust_message': trustMessage,
          'years_value': yearsValue,
          'years_suffix': yearsSuffix,
          'years_label': yearsLabel,
          'homes_value': homesValue,
          'homes_suffix': homesSuffix,
          'homes_label': homesLabel,
          'clients_value': clientsValue,
          'clients_suffix': clientsSuffix,
          'clients_label': clientsLabel,
          'projects_value': projectsValue,
          'projects_suffix': projectsSuffix,
          'projects_label': projectsLabel,
          'status': status,
          'updated_at': _nowIso(),
        })
        .select()
        .single();
    return CmsDigitalCompanyProfile.fromJson(Map<String, dynamic>.from(row));
  }

  Future<String> uploadDigitalProfileAsset({
    required List<int> bytes,
    required String contentType,
    String folder = 'digital-profile',
    void Function(double progress)? onProgress,
  }) async {
    return _uploadPublicBytes(
      bucket: 'marketing',
      bytes: bytes,
      contentType: contentType,
      folder: folder,
      fileNameHint: 'asset',
      entityType: MediaEntityType.marketing,
      onProgress: onProgress,
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // Team (employees — website-facing attributes live in metadata jsonb)
  // ───────────────────────────────────────────────────────────────────────

  Future<List<CmsTeamMember>> listTeam() async {
    final rows = await _c
        .from('employees')
        .select()
        .eq('is_deleted', false)
        .order('first_name');
    return rows
        .map((e) => CmsTeamMember.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> updateTeamDisplay(
    String id, {
    String? jobTitle,
    String? bio,
    bool? showOnWebsite,
    int? sortOrder,
  }) async {
    final row = await _c
        .from('employees')
        .select('metadata')
        .eq('id', id)
        .maybeSingle();
    final metadata = row != null && row['metadata'] is Map
        ? Map<String, dynamic>.from(row['metadata'] as Map)
        : <String, dynamic>{};
    if (jobTitle != null) metadata['job_title'] = jobTitle;
    if (bio != null) metadata['bio'] = bio;
    if (showOnWebsite != null) metadata['show_on_website'] = showOnWebsite;
    if (sortOrder != null) metadata['sort_order'] = sortOrder;

    await _c
        .from('employees')
        .update({'metadata': metadata, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  // ───────────────────────────────────────────────────────────────────────
  // FAQs (faqs)
  // ───────────────────────────────────────────────────────────────────────

  Future<List<CmsFaq>> listFaqs() async {
    final rows = await _c
        .from('faqs')
        .select()
        .eq('is_deleted', false)
        .order('sort_order');
    return rows
        .map((e) => CmsFaq.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<CmsFaq> upsertFaq({
    String? id,
    required String question,
    required String answer,
    String? category,
    int sortOrder = 0,
    String status = 'active',
  }) async {
    final payload = {
      if (id != null) 'id': id,
      'question': question,
      'answer': answer,
      'category': category,
      'sort_order': sortOrder,
      'status': status,
      'updated_at': _nowIso(),
    };
    final row = await _c.from('faqs').upsert(payload).select().single();
    return CmsFaq.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> reorderFaqs(List<CmsFaq> ordered) async {
    for (var i = 0; i < ordered.length; i++) {
      await _c
          .from('faqs')
          .update({'sort_order': i, 'updated_at': _nowIso()})
          .eq('id', ordered[i].id);
    }
  }

  Future<void> setFaqStatus(String id, String status) async {
    await _c
        .from('faqs')
        .update({'status': status, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  Future<void> setFaqPublished(String id, bool published) async {
    await _c
        .from('faqs')
        .update({
          'status': published ? 'active' : 'draft',
          'updated_at': _nowIso(),
        })
        .eq('id', id);
  }

  Future<void> deleteFaq(String id) async {
    await _c
        .from('faqs')
        .update({'is_deleted': true, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  // ───────────────────────────────────────────────────────────────────────
  // Menus / Footer (cms_sections with section_type = 'menu' | 'footer')
  // ───────────────────────────────────────────────────────────────────────

  Future<List<CmsSectionRecord>> listMenuSections() async {
    final rows = await _c
        .from('cms_sections')
        .select()
        .inFilter('section_type', ['menu', 'navigation'])
        .order('sort_order');
    return rows
        .map((e) => CmsSectionRecord.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<CmsSectionRecord>> listFooterSections() async {
    final rows = await _c
        .from('cms_sections')
        .select()
        .eq('section_type', 'footer')
        .order('sort_order');
    return rows
        .map((e) => CmsSectionRecord.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<CmsSectionRecord> upsertMenuSection({
    String? id,
    required String sectionKey,
    String? title,
    required Map<String, dynamic> content,
    int sortOrder = 0,
  }) => upsertSection(
    id: id,
    sectionKey: sectionKey,
    sectionType: 'menu',
    title: title,
    content: content,
    sortOrder: sortOrder,
  );

  Future<CmsSectionRecord> upsertFooterSection({
    String? id,
    required String sectionKey,
    String? title,
    required Map<String, dynamic> content,
    int sortOrder = 0,
  }) => upsertSection(
    id: id,
    sectionKey: sectionKey,
    sectionType: 'footer',
    title: title,
    content: content,
    sortOrder: sortOrder,
  );

  // ───────────────────────────────────────────────────────────────────────
  // Company profile (temporary store: seo_metadata entity_type='company')
  // ───────────────────────────────────────────────────────────────────────

  static const String companySettingsPath = '/admin/company';

  /// Reads the company profile stashed in `seo_metadata.metadata` where
  /// `entity_type = 'company'` and `path = '/admin/company'`.
  ///
  /// This is a pragmatic temporary store — see [CmsService] docs. A
  /// dedicated `company_settings` table is preferred long-term; if one is
  /// added, only this method (and [saveCompanySettings]) need updating.
  /// Prefer [PlatformSettingsService] / Settings Control Center.
  ///
  /// Kept as a read-compat shim for legacy tooling. Writes here omit several
  /// live contact fields and must not be used for production saves.
  @Deprecated('Use PlatformSettingsService.loadBundle / saveBundle instead')
  Future<Map<String, dynamic>> getCompanySettings() async {
    try {
      final rows = await _c
          .from('app_settings')
          .select('key, value')
          .eq('is_deleted', false)
          .inFilter('key', const [
            'company',
            'contact',
            'theme',
            'social',
            'seo',
          ]);
      final byKey = <String, Map<String, dynamic>>{};
      for (final row in rows as List) {
        final map = Map<String, dynamic>.from(row as Map);
        final key = '${map['key'] ?? ''}';
        final value = map['value'];
        if (key.isEmpty) continue;
        byKey[key] = value is Map
            ? Map<String, dynamic>.from(value)
            : <String, dynamic>{};
      }
      if (byKey.isNotEmpty) {
        final company = byKey['company'] ?? const <String, dynamic>{};
        final contact = byKey['contact'] ?? const <String, dynamic>{};
        final theme = byKey['theme'] ?? const <String, dynamic>{};
        final social = byKey['social'] ?? const <String, dynamic>{};
        final seo = byKey['seo'] ?? const <String, dynamic>{};
        return {
          'company_name': '${company['name'] ?? ''}'.trim(),
          'tagline': '${company['tagline'] ?? ''}'.trim(),
          'support_email': '${contact['email'] ?? ''}'.trim(),
          'support_phone': '${contact['phone'] ?? ''}'.trim(),
          'support_whatsapp': '${contact['whatsapp'] ?? ''}'.trim(),
          'address': '${contact['address'] ?? ''}'.trim(),
          'support_hours': '${contact['support_hours'] ?? ''}'.trim(),
          'brand_primary_color': '${theme['primary'] ?? ''}'.trim(),
          'brand_accent_color': '${theme['accent'] ?? theme['secondary'] ?? ''}'
              .trim(),
          'facebook_url': '${social['facebook_url'] ?? ''}'.trim(),
          'instagram_url': '${social['instagram_url'] ?? ''}'.trim(),
          'twitter_url': '${social['twitter_url'] ?? ''}'.trim(),
          'linkedin_url': '${social['linkedin_url'] ?? ''}'.trim(),
          'youtube_url': '${social['youtube_url'] ?? ''}'.trim(),
          'seo_title': '${seo['default_title'] ?? ''}'.trim(),
          'seo_description': '${seo['default_description'] ?? ''}'.trim(),
          'site_url': '${seo['site_url'] ?? ''}'.trim(),
          'og_image_url': '${seo['og_image_url'] ?? ''}'.trim(),
        };
      }
    } catch (_) {
      // Fall through to legacy seo_metadata blob.
    }

    final row = await _c
        .from('seo_metadata')
        .select('metadata')
        .eq('entity_type', 'company')
        .eq('path', companySettingsPath)
        .maybeSingle();
    if (row == null) return {};
    final metadata = row['metadata'];
    if (metadata is Map) return Map<String, dynamic>.from(metadata);
    return {};
  }

  @Deprecated('Use PlatformSettingsService.saveBundle instead')
  Future<void> saveCompanySettings(Map<String, dynamic> data) async {
    // Prefer the live app_settings store. Keep seo_metadata as a mirror for
    // older tooling until the Company Profile alias is fully retired.
    Future<void> upsertSetting(
      String key,
      Map<String, dynamic> value, {
      required String category,
      required String description,
    }) async {
      await _c.rpc(
        'upsert_app_setting',
        params: {
          'p_key': key,
          'p_value': value,
          'p_category': category,
          'p_is_public': true,
          'p_description': description,
        },
      );
    }

    await upsertSetting(
      'company',
      {
        'name': data['company_name'],
        'tagline': data['tagline'],
        'legal_name': data['company_name'],
      },
      category: 'general',
      description: 'Company business profile',
    );
    await upsertSetting(
      'contact',
      {
        'email': data['support_email'],
        'phone': data['support_phone'],
        'whatsapp': data['support_whatsapp'],
        'address': data['address'],
      },
      category: 'general',
      description: 'Public contact channels',
    );
    await upsertSetting(
      'theme',
      {
        'primary': data['brand_primary_color'],
        'accent': data['brand_accent_color'],
      },
      category: 'branding',
      description: 'Brand color references',
    );
    await upsertSetting(
      'social',
      {
        'facebook_url': data['facebook_url'],
        'instagram_url': data['instagram_url'],
        'twitter_url': data['twitter_url'],
        'linkedin_url': data['linkedin_url'],
        'youtube_url': data['youtube_url'],
      },
      category: 'branding',
      description: 'Public social profile links',
    );

    final existing = await _c
        .from('seo_metadata')
        .select('id')
        .eq('entity_type', 'company')
        .eq('path', companySettingsPath)
        .maybeSingle();

    await _c.from('seo_metadata').upsert({
      if (existing != null) 'id': existing['id'],
      'entity_type': 'company',
      'path': companySettingsPath,
      'meta_title': data['company_name'] as String?,
      'metadata': data,
      'updated_at': _nowIso(),
    });
  }

  // ───────────────────────────────────────────────────────────────────────
  // Public website published reads (admin CMS → public site)
  // ───────────────────────────────────────────────────────────────────────

  Future<List<CmsSectionRecord>> listPublishedHomepageSections() async {
    // Include hidden homepage sections so the public site can honor visibility
    // toggles (RLS allows homepage_% reads even when is_visible = false).
    final rows = await _c
        .from('cms_sections')
        .select()
        .like('section_key', 'homepage_%')
        .order('sort_order');
    return rows
        .map((e) => CmsSectionRecord.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<CmsTestimonial>> listPublishedTestimonials({
    int limit = 8,
  }) async {
    try {
      final rows = await _c
          .from('testimonials')
          .select()
          .eq('is_deleted', false)
          .eq('status', 'active')
          .order('is_featured', ascending: false)
          .order('created_at', ascending: false)
          .limit(limit);
      return rows
          .map((e) => CmsTestimonial.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      final rows = await _c
          .from('testimonials')
          .select()
          .eq('is_deleted', false)
          .order('is_featured', ascending: false)
          .limit(limit);
      return rows
          .map((e) => CmsTestimonial.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
  }

  Future<List<CmsFaq>> listPublishedFaqs({int limit = 12}) async {
    try {
      final rows = await _c
          .from('faqs')
          .select()
          .eq('is_deleted', false)
          .eq('status', 'active')
          .order('sort_order')
          .limit(limit);
      return rows
          .map((e) => CmsFaq.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      final rows = await _c
          .from('faqs')
          .select()
          .eq('is_deleted', false)
          .order('sort_order')
          .limit(limit);
      return rows
          .map((e) => CmsFaq.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
  }

  Future<List<CmsTeamMember>> listPublishedTeam({int limit = 12}) async {
    final all = await listTeam();
    final visible = all.where((m) => m.showOnWebsite).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return visible.take(limit).toList();
  }

  Future<List<CmsBanner>> listActiveBanners({int limit = 6}) async {
    final now = DateTime.now().toUtc();
    try {
      final rows = await _c
          .from('banners')
          .select()
          .eq('is_deleted', false)
          .eq('status', 'active')
          .order('sort_order')
          .limit(limit * 2);
      return rows
          .map((e) => CmsBanner.fromJson(Map<String, dynamic>.from(e)))
          .where((b) {
            if (b.startsAt != null && b.startsAt!.isAfter(now)) return false;
            if (b.endsAt != null && b.endsAt!.isBefore(now)) return false;
            return true;
          })
          .take(limit)
          .toList();
    } catch (_) {
      final rows = await listBanners();
      return rows
          .where((b) {
            if (!b.isActive) return false;
            if (b.startsAt != null && b.startsAt!.isAfter(now)) return false;
            if (b.endsAt != null && b.endsAt!.isBefore(now)) return false;
            return true;
          })
          .take(limit)
          .toList();
    }
  }

  Future<List<CmsBlogPost>> listPublishedBlogs({
    int limit = 100,
    bool featuredOnly = false,
  }) async {
    var query = _c
        .from('blogs')
        .select()
        .eq('is_deleted', false)
        .eq('is_published', true);
    if (featuredOnly) {
      query = query.eq('featured', true);
    }
    try {
      final rows = await query
          .order('published_at', ascending: false)
          .limit(limit);
      return rows
          .map((e) => CmsBlogPost.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      final rows = await _c
          .from('blogs')
          .select()
          .eq('is_deleted', false)
          .eq('is_published', true)
          .order('created_at', ascending: false)
          .limit(limit);
      return rows
          .map((e) => CmsBlogPost.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
  }

  Future<CmsBlogPost> upsertBlog({
    String? id,
    required String title,
    required String slug,
    String? excerpt,
    String? coverImageUrl,
    String? body,
    String? categoryId,
    String? blogAuthorId,
    bool isPublished = false,
    bool featured = false,
    DateTime? publishedAt,
  }) async {
    final words = (body ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;
    final readingMinutes = words == 0 ? 3 : (words / 200).ceil().clamp(1, 60);
    final payload = {
      if (id != null) 'id': id,
      'title': title,
      'slug': slug,
      'excerpt': excerpt,
      'cover_image_url': coverImageUrl,
      'content': {'body': body ?? ''},
      'category_id': categoryId,
      'blog_author_id': blogAuthorId,
      'is_published': isPublished,
      'featured': featured,
      'reading_time_minutes': readingMinutes,
      'status': isPublished ? 'published' : 'draft',
      'published_at': isPublished
          ? (publishedAt?.toUtc().toIso8601String() ?? _nowIso())
          : null,
      'is_deleted': false,
      'updated_at': _nowIso(),
    };
    final row = await _c.from('blogs').upsert(payload).select().single();
    return CmsBlogPost.fromJson(Map<String, dynamic>.from(row));
  }

  Future<String> uploadBlogCover({
    required List<int> bytes,
    required String contentType,
    String? blogId,
    void Function(double progress)? onProgress,
  }) => _uploadPublicImage(
    bucket: 'blog-images',
    bytes: bytes,
    contentType: contentType,
    folder: 'covers',
    entityType: MediaEntityType.blog,
    entityId: blogId,
    onProgress: onProgress,
  );

  Future<CmsSeoRecord?> getSeoByPath(String path) async {
    final normalized = path.isEmpty ? '/' : path;
    final rows = await _c
        .from('seo_metadata')
        .select()
        .eq('path', normalized)
        .order('updated_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return CmsSeoRecord.fromJson(Map<String, dynamic>.from(rows.first));
  }

  Future<List<CmsSectionRecord>> listPublishedMenuSections() async {
    final rows = await listMenuSections();
    return rows.where((s) => s.isVisible).toList();
  }

  Future<List<CmsSectionRecord>> listPublishedFooterSections() async {
    final rows = await listFooterSections();
    return rows.where((s) => s.isVisible).toList();
  }

  // ───────────────────────────────────────────────────────────────────────
  // Property listings engagement (views / inquiries / inspections / scores)
  // ───────────────────────────────────────────────────────────────────────

  Future<PropertyListingsInsights> loadPropertyListingsInsights() async {
    if (_client == null) return const PropertyListingsInsights();

    final byId = <String, PropertyEngagementStats>{};
    void addStats(String? id, {int views = 0, int inquiries = 0}) {
      if (id == null || id.isEmpty) return;
      final prev = byId[id] ?? const PropertyEngagementStats();
      byId[id] = PropertyEngagementStats(
        views: prev.views + views,
        inquiries: prev.inquiries + inquiries,
      );
    }

    try {
      final analytics = await _c
          .from('property_analytics_daily')
          .select('property_id, views, leads');
      for (final row in analytics) {
        final m = Map<String, dynamic>.from(row as Map);
        addStats(
          m['property_id']?.toString(),
          views: (m['views'] as num?)?.toInt() ?? 0,
          inquiries: (m['leads'] as num?)?.toInt() ?? 0,
        );
      }
    } catch (_) {}

    try {
      final viewRows = await _c.from('property_views').select('property_id');
      final counts = <String, int>{};
      for (final row in viewRows) {
        final id = (row as Map)['property_id']?.toString();
        if (id == null || id.isEmpty) continue;
        counts[id] = (counts[id] ?? 0) + 1;
      }
      for (final e in counts.entries) {
        final prev = byId[e.key];
        // Prefer analytics totals when present; otherwise use raw view events.
        if (prev == null || prev.views == 0) {
          addStats(e.key, views: e.value);
        }
      }
    } catch (_) {}

    try {
      final leadRows = await _c
          .from('leads')
          .select('property_id')
          .not('property_id', 'is', null);
      final counts = <String, int>{};
      for (final row in leadRows) {
        final id = (row as Map)['property_id']?.toString();
        if (id == null || id.isEmpty) continue;
        counts[id] = (counts[id] ?? 0) + 1;
      }
      for (final e in counts.entries) {
        final prev = byId[e.key];
        if (prev == null || prev.inquiries == 0) {
          addStats(e.key, inquiries: e.value);
        }
      }
    } catch (_) {}

    final inspections = <ListingsInspectionItem>[];
    try {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day).toUtc();
      final end = start.add(const Duration(days: 14));
      final inspRows = await _c
          .from('property_inspections')
          .select(
            'id, property_id, scheduled_at, visitor_name, status, '
            'properties(title, city, state)',
          )
          .gte('scheduled_at', start.toIso8601String())
          .lt('scheduled_at', end.toIso8601String())
          .order('scheduled_at', ascending: true)
          .limit(12);
      for (final row in inspRows) {
        final m = Map<String, dynamic>.from(row as Map);
        final prop = m['properties'];
        String title = 'Property';
        String location = '';
        if (prop is Map) {
          title = (prop['title'] as String?)?.trim().isNotEmpty == true
              ? prop['title'] as String
              : title;
          location = [prop['city'], prop['state']]
              .whereType<String>()
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .join(', ');
        }
        final when = DateTime.tryParse(
          m['scheduled_at'] as String? ?? '',
        )?.toLocal();
        if (when == null) continue;
        inspections.add(
          ListingsInspectionItem(
            id: m['id']?.toString() ?? '',
            propertyId: m['property_id']?.toString() ?? '',
            title: title,
            location: location,
            scheduledAt: when,
            visitorName: m['visitor_name'] as String?,
            status: m['status'] as String? ?? 'scheduled',
          ),
        );
      }
    } catch (_) {}

    var performance = const PropertyPerformanceBreakdown();
    try {
      final scoreMap = <String, double>{};
      try {
        final scoreRows = await _c
            .from('property_scores')
            .select('property_id, performance_score');
        for (final row in scoreRows) {
          final m = Map<String, dynamic>.from(row as Map);
          final id = m['property_id']?.toString();
          final score = (m['performance_score'] as num?)?.toDouble();
          if (id != null && score != null) scoreMap[id] = score;
        }
      } catch (_) {}

      final propRows = await _c
          .from('properties')
          .select('id, performance_score')
          .limit(200);
      for (final row in propRows) {
        final m = Map<String, dynamic>.from(row as Map);
        final id = m['id']?.toString();
        final score = (m['performance_score'] as num?)?.toDouble();
        // Column default is 0. Only a recorded score above 0 counts here.
        // Rows already loaded from property_scores are left as stored.
        if (id == null || score == null || score <= 0) continue;
        scoreMap.putIfAbsent(id, () => score);
      }

      var high = 0, avg = 0, low = 0;
      var sum = 0.0;
      for (final score in scoreMap.values) {
        sum += score;
        if (score >= 70) {
          high++;
        } else if (score >= 40) {
          avg++;
        } else {
          low++;
        }
      }
      final n = scoreMap.length;
      performance = PropertyPerformanceBreakdown(
        averageScore: n == 0 ? 0 : sum / n,
        highCount: high,
        averageCount: avg,
        lowCount: low,
      );
    } catch (_) {}

    return PropertyListingsInsights(
      byPropertyId: byId,
      inspections: inspections,
      performance: performance,
    );
  }

  /// Persist a public property view for realtime admin metrics.
  Future<void> recordPropertyView(String propertyId) async {
    if (_client == null || propertyId.trim().isEmpty) return;
    final id = propertyId.trim();
    try {
      await _c.from('property_views').insert({'property_id': id});
    } catch (_) {}

    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final existing = await _c
          .from('property_analytics_daily')
          .select('id, views')
          .eq('property_id', id)
          .eq('metric_date', today)
          .maybeSingle();
      if (existing != null) {
        final current = (existing['views'] as num?)?.toInt() ?? 0;
        await _c
            .from('property_analytics_daily')
            .update({'views': current + 1})
            .eq('id', existing['id']);
      } else {
        await _c.from('property_analytics_daily').insert({
          'property_id': id,
          'metric_date': today,
          'views': 1,
          'leads': 0,
          'favorites': 0,
          'bookings': 0,
          'inspections': 0,
        });
      }
    } catch (_) {}
  }

  // ───────────────────────────────────────────────────────────────────────
  // Payment plan calculator CMS
  // ───────────────────────────────────────────────────────────────────────

  Future<CmsCalculatorSettings> getCalculatorSettings() async {
    final rows = await _c.from('calculator_settings').select().limit(1);
    if (rows.isEmpty) {
      final created = await _c
          .from('calculator_settings')
          .insert({'updated_at': _nowIso()})
          .select()
          .single();
      return CmsCalculatorSettings.fromJson(Map<String, dynamic>.from(created));
    }
    return CmsCalculatorSettings.fromJson(
      Map<String, dynamic>.from(rows.first),
    );
  }

  Future<CmsCalculatorSettings> upsertCalculatorSettings({
    required String id,
    required String overline,
    required String title,
    required String subtitle,
    required String infoText,
    required String applyCtaLabel,
    required double priceMin,
    required double priceMax,
    required double priceDefault,
    required List<CmsCalculatorTrustItem> trustItems,
  }) async {
    final row = await _c
        .from('calculator_settings')
        .upsert({
          'id': id,
          'overline': overline,
          'title': title,
          'subtitle': subtitle,
          'info_text': infoText,
          'apply_cta_label': applyCtaLabel,
          'price_min': priceMin,
          'price_max': priceMax,
          'price_default': priceDefault,
          'trust_items': trustItems.map((e) => e.toJson()).toList(),
          'updated_at': _nowIso(),
        })
        .select()
        .single();
    return CmsCalculatorSettings.fromJson(Map<String, dynamic>.from(row));
  }

  Future<List<CmsCalculatorPaymentPlan>> listCalculatorPaymentPlans() async {
    final rows = await _c
        .from('calculator_payment_plans')
        .select('*, calculator_plan_properties(property_id)')
        .eq('is_deleted', false)
        .order('sort_order');
    return rows
        .map(
          (e) =>
              CmsCalculatorPaymentPlan.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList();
  }

  Future<List<CmsCalculatorPaymentPlan>>
  listPublishedCalculatorPaymentPlans() async {
    final rows = await _c
        .from('calculator_payment_plans')
        .select('*, calculator_plan_properties(property_id)')
        .eq('is_deleted', false)
        .eq('status', 'active')
        .order('sort_order');
    return rows
        .map(
          (e) =>
              CmsCalculatorPaymentPlan.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList();
  }

  Future<CmsCalculatorPaymentPlan> upsertCalculatorPaymentPlan({
    String? id,
    required String name,
    String description = '',
    bool isGlobal = true,
    double interestRateDefault = 12,
    double interestRateMin = 0,
    double interestRateMax = 30,
    int durationMonthsDefault = 24,
    int durationMonthsMin = 6,
    int durationMonthsMax = 120,
    double depositPercentMin = 10,
    double depositPercentDefault = 20,
    double minDepositAmount = 1000000,
    double? maxDepositAmount,
    String calculationMethod = 'reducing_balance',
    int sortOrder = 0,
    String status = 'active',
    List<String> propertyIds = const [],
  }) async {
    final row = await _c
        .from('calculator_payment_plans')
        .upsert({
          if (id != null) 'id': id,
          'name': name,
          'description': description,
          'is_global': isGlobal,
          'interest_rate_default': interestRateDefault,
          'interest_rate_min': interestRateMin,
          'interest_rate_max': interestRateMax,
          'duration_months_default': durationMonthsDefault,
          'duration_months_min': durationMonthsMin,
          'duration_months_max': durationMonthsMax,
          'deposit_percent_min': depositPercentMin,
          'deposit_percent_default': depositPercentDefault,
          'min_deposit_amount': minDepositAmount,
          'max_deposit_amount': maxDepositAmount,
          'calculation_method': calculationMethod,
          'sort_order': sortOrder,
          'status': status,
          'updated_at': _nowIso(),
        })
        .select()
        .single();

    final plan = CmsCalculatorPaymentPlan.fromJson(
      Map<String, dynamic>.from(row),
    );

    await _c.from('calculator_plan_properties').delete().eq('plan_id', plan.id);

    if (!isGlobal && propertyIds.isNotEmpty) {
      await _c.from('calculator_plan_properties').insert([
        for (final propertyId in propertyIds.toSet())
          {'plan_id': plan.id, 'property_id': propertyId},
      ]);
    }

    final refreshed = await _c
        .from('calculator_payment_plans')
        .select('*, calculator_plan_properties(property_id)')
        .eq('id', plan.id)
        .single();
    return CmsCalculatorPaymentPlan.fromJson(
      Map<String, dynamic>.from(refreshed),
    );
  }

  Future<void> setCalculatorPaymentPlanSortOrder(
    String id,
    int sortOrder,
  ) async {
    await _c
        .from('calculator_payment_plans')
        .update({'sort_order': sortOrder, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  Future<void> deleteCalculatorPaymentPlan(String id) async {
    await _c
        .from('calculator_payment_plans')
        .update({'is_deleted': true, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  static const _calculatorApplicationSelect =
      '*, calculator_payment_plans(name)';

  Future<List<CmsCalculatorApplication>> listCalculatorApplications({
    int limit = 100,
  }) async {
    final rows = await _c
        .from('calculator_applications')
        .select(_calculatorApplicationSelect)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows
        .map(
          (e) =>
              CmsCalculatorApplication.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList();
  }

  Future<List<CmsCalculatorApplication>> listMyCalculatorApplications({
    int limit = 20,
  }) async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) return const [];
    try {
      await _c.rpc('claim_my_calculator_applications');
    } catch (_) {
      // Listing still works for applications already tied to this account.
    }
    final rows = await _c
        .from('calculator_applications')
        .select(_calculatorApplicationSelect)
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows
        .map(
          (e) =>
              CmsCalculatorApplication.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList();
  }

  Future<CmsCalculatorApplication> submitCalculatorApplication({
    String? planId,
    String? propertyId,
    required String fullName,
    required String email,
    String phone = '',
    String city = '',
    String preferredContact = 'phone',
    String occupation = '',
    String message = '',
    required double propertyPrice,
    required double depositAmount,
    required int durationMonths,
    required double interestRate,
    required double loanAmount,
    required double monthlyPayment,
    required double totalRepayment,
    required double totalInterest,
  }) async {
    try {
      final raw = await _c.rpc(
        'submit_calculator_application',
        params: {
          'p_plan_id': planId,
          'p_property_id': propertyId,
          'p_full_name': fullName.trim(),
          'p_email': email.trim(),
          'p_phone': phone.trim(),
          'p_city': city.trim(),
          'p_preferred_contact': preferredContact,
          'p_occupation': occupation.trim(),
          'p_message': message.trim(),
          'p_property_price': propertyPrice,
          'p_deposit_amount': depositAmount,
          'p_duration_months': durationMonths,
          'p_interest_rate': interestRate,
          'p_loan_amount': loanAmount,
          'p_monthly_payment': monthlyPayment,
          'p_total_repayment': totalRepayment,
          'p_total_interest': totalInterest,
        },
      );
      if (raw is! Map) {
        throw StateError(
          'We could not submit your application. Please try again.',
        );
      }
      return CmsCalculatorApplication.fromJson(Map<String, dynamic>.from(raw));
    } on PostgrestException catch (e) {
      throw StateError(_calculatorApplyError(e));
    }
  }

  String _calculatorApplyError(PostgrestException error) {
    final msg = error.message.toLowerCase();
    if (msg.contains('invalid_name')) return 'Enter your full name.';
    if (msg.contains('invalid_email')) return 'Enter a valid email address.';
    if (msg.contains('invalid_phone')) return 'That phone number is too long.';
    if (msg.contains('invalid_city')) return 'That city name is too long.';
    if (msg.contains('invalid_occupation')) {
      return 'That occupation is too long.';
    }
    if (msg.contains('invalid_message')) {
      return 'Keep your message under 2,000 characters.';
    }
    if (msg.contains('invalid_figures')) {
      return 'Check the calculator figures and try again.';
    }
    return 'We could not submit your application. Please try again.';
  }

  Future<void> updateCalculatorApplicationStatus({
    required String id,
    required String status,
    String? notes,
    String? adminReply,
  }) async {
    try {
      await _c.rpc(
        'reply_calculator_application',
        params: {
          'p_application_id': id,
          'p_status': status,
          if (notes != null) 'p_notes': notes.trim(),
          if (adminReply != null) 'p_reply': adminReply.trim(),
        },
      );
    } on PostgrestException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('forbidden')) {
        throw StateError(
          'You do not have permission to reply to this application.',
        );
      }
      if (msg.contains('invalid_reply')) {
        throw StateError('That reply is too long.');
      }
      throw StateError('The reply could not be saved. Please try again.');
    }
  }

  // ---------------------------------------------------------------------------
  // ROI calculator CMS
  // ---------------------------------------------------------------------------

  Future<CmsRoiCalculatorSettings> getRoiCalculatorSettings() async {
    final rows = await _c.from('roi_calculator_settings').select().limit(1);
    if (rows.isEmpty) {
      final created = await _c
          .from('roi_calculator_settings')
          .insert({'updated_at': _nowIso()})
          .select()
          .single();
      return CmsRoiCalculatorSettings.fromJson(
        Map<String, dynamic>.from(created),
      );
    }
    return CmsRoiCalculatorSettings.fromJson(
      Map<String, dynamic>.from(rows.first),
    );
  }

  Future<CmsRoiCalculatorSettings> upsertRoiCalculatorSettings({
    required String id,
    required bool isEnabled,
    required String overline,
    required String title,
    required String subtitle,
    required String inputsTitle,
    required String inputsSubtitle,
    required String resultsTitle,
    required String infoText,
    required String disclaimerText,
    required String ctaLabel,
    required String ctaPath,
    required String currencySymbol,
    required String currencyCode,
    required String compoundingMethod,
    required double amountMin,
    required double amountMax,
    required double amountDefault,
    required double growthMin,
    required double growthMax,
    required double growthDefault,
    required double yearsMin,
    required double yearsMax,
    required double yearsDefault,
    required bool showChart,
  }) async {
    final row = await _c
        .from('roi_calculator_settings')
        .upsert({
          'id': id,
          'is_enabled': isEnabled,
          'overline': overline,
          'title': title,
          'subtitle': subtitle,
          'inputs_title': inputsTitle,
          'inputs_subtitle': inputsSubtitle,
          'results_title': resultsTitle,
          'info_text': infoText,
          'disclaimer_text': disclaimerText,
          'cta_label': ctaLabel,
          'cta_path': ctaPath,
          'currency_symbol': currencySymbol,
          'currency_code': currencyCode,
          'compounding_method': compoundingMethod,
          'amount_min': amountMin,
          'amount_max': amountMax,
          'amount_default': amountDefault,
          'growth_min': growthMin,
          'growth_max': growthMax,
          'growth_default': growthDefault,
          'years_min': yearsMin,
          'years_max': yearsMax,
          'years_default': yearsDefault,
          'show_chart': showChart,
          'updated_at': _nowIso(),
        })
        .select()
        .single();
    return CmsRoiCalculatorSettings.fromJson(Map<String, dynamic>.from(row));
  }

  // ───────────────────────────────────────────────────────────────────────
  // Website market insights (marketing CMS)
  // ───────────────────────────────────────────────────────────────────────

  Future<List<CmsWebsiteMarketInsight>> listWebsiteMarketInsights() async {
    final rows = await _c
        .from('website_market_insights')
        .select()
        .eq('is_deleted', false)
        .order('is_featured', ascending: false)
        .order('sort_order')
        .order('created_at', ascending: false);
    return rows
        .map(
          (e) => CmsWebsiteMarketInsight.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList();
  }

  Future<List<CmsWebsiteMarketInsight>> listPublishedWebsiteMarketInsights({
    int limit = 24,
  }) async {
    final rows = await _c
        .from('website_market_insights')
        .select()
        .eq('is_deleted', false)
        .eq('is_published', true)
        .eq('status', 'published')
        .order('sort_order')
        .limit(limit);
    return rows
        .map(
          (e) => CmsWebsiteMarketInsight.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList();
  }

  Future<CmsWebsiteMarketInsight> upsertWebsiteMarketInsight({
    String? id,
    required String title,
    required String value,
    required String summary,
    String trend = '',
    String location = '',
    String category = '',
    String icon = 'trendingUp',
    String source = '',
    String? sourceUrl,
    String? coverImageUrl,
    String visualType = 'line_chart',
    String trendDirection = 'up',
    bool isFeatured = false,
    int sortOrder = 0,
    String status = 'draft',
    bool isPublished = false,
    DateTime? publishedAt,
  }) async {
    final payload = {
      if (id != null) 'id': id,
      'title': title,
      'value': value,
      'trend': trend,
      'summary': summary,
      'location': location,
      'category': category,
      'icon': icon,
      'source': source,
      'source_url': sourceUrl,
      'cover_image_url': coverImageUrl,
      'visual_type': visualType,
      'trend_direction': trendDirection,
      'is_featured': isFeatured,
      'sort_order': sortOrder,
      'status': status,
      'is_published': isPublished,
      if (publishedAt != null)
        'published_at': publishedAt.toUtc().toIso8601String(),
      'updated_at': _nowIso(),
    };
    final row = await _c
        .from('website_market_insights')
        .upsert(payload)
        .select()
        .single();
    return CmsWebsiteMarketInsight.fromJson(Map<String, dynamic>.from(row));
  }

  Future<CmsWebsiteMarketInsight> publishWebsiteMarketInsight(String id) async {
    final row = await _c
        .from('website_market_insights')
        .update({
          'status': 'published',
          'is_published': true,
          'published_at': _nowIso(),
          'updated_at': _nowIso(),
        })
        .eq('id', id)
        .select()
        .single();
    return CmsWebsiteMarketInsight.fromJson(Map<String, dynamic>.from(row));
  }

  Future<CmsWebsiteMarketInsight> unpublishWebsiteMarketInsight(
    String id,
  ) async {
    final row = await _c
        .from('website_market_insights')
        .update({
          'status': 'draft',
          'is_published': false,
          'updated_at': _nowIso(),
        })
        .eq('id', id)
        .select()
        .single();
    return CmsWebsiteMarketInsight.fromJson(Map<String, dynamic>.from(row));
  }

  Future<CmsWebsiteMarketInsight> archiveWebsiteMarketInsight(String id) async {
    final row = await _c
        .from('website_market_insights')
        .update({
          'status': 'archived',
          'is_published': false,
          'updated_at': _nowIso(),
        })
        .eq('id', id)
        .select()
        .single();
    return CmsWebsiteMarketInsight.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> setWebsiteMarketInsightSortOrder({
    required String id,
    required int sortOrder,
  }) async {
    await _c
        .from('website_market_insights')
        .update({'sort_order': sortOrder, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  Future<void> setWebsiteMarketInsightStatus({
    required String id,
    required String status,
    bool? isPublished,
  }) async {
    final payload = <String, dynamic>{
      'status': status,
      'updated_at': _nowIso(),
    };
    if (isPublished != null) payload['is_published'] = isPublished;
    if (status == 'published' && isPublished == true) {
      payload['published_at'] = _nowIso();
    }
    await _c.from('website_market_insights').update(payload).eq('id', id);
  }

  Future<void> setWebsiteMarketInsightFeatured({
    required String id,
    required bool isFeatured,
  }) async {
    await _c
        .from('website_market_insights')
        .update({'is_featured': isFeatured, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  Future<void> deleteWebsiteMarketInsight(String id) async {
    await _c
        .from('website_market_insights')
        .update({'is_deleted': true, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  Future<String> uploadWebsiteMarketInsightCover({
    required List<int> bytes,
    required String contentType,
    required String insightId,
  }) async {
    return uploadMarketingAsset(
      bytes: bytes,
      contentType: contentType,
      folder: 'market-insights/$insightId',
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // Website services CMS
  // ───────────────────────────────────────────────────────────────────────

  Future<List<CmsWebsiteServiceCategory>> listWebsiteServiceCategories() async {
    final rows = await _c
        .from('website_service_categories')
        .select()
        .eq('is_deleted', false)
        .order('sort_order');
    return rows
        .map(
          (e) =>
              CmsWebsiteServiceCategory.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList();
  }

  Future<List<CmsWebsiteServiceCategory>>
  listPublishedWebsiteServiceCategories() async {
    final rows = await _c
        .from('website_service_categories')
        .select()
        .eq('is_deleted', false)
        .eq('status', 'active')
        .order('sort_order');
    return rows
        .map(
          (e) =>
              CmsWebsiteServiceCategory.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList();
  }

  Future<CmsWebsiteServiceCategory> upsertWebsiteServiceCategory({
    String? id,
    required String name,
    required String slug,
    String description = '',
    String iconName = 'briefcase',
    int sortOrder = 0,
    String status = 'active',
  }) async {
    final row = await _c
        .from('website_service_categories')
        .upsert({
          if (id != null) 'id': id,
          'name': name,
          'slug': slug,
          'description': description,
          'icon_name': iconName,
          'sort_order': sortOrder,
          'status': status,
          'is_deleted': false,
          'updated_at': _nowIso(),
        })
        .select()
        .single();
    return CmsWebsiteServiceCategory.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> deleteWebsiteServiceCategory(String id) async {
    await _c
        .from('website_service_categories')
        .update({'is_deleted': true, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  Future<void> setWebsiteServiceCategoryStatus(String id, String status) async {
    await _c
        .from('website_service_categories')
        .update({'status': status, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  Future<List<CmsWebsiteServiceItem>> listWebsiteServiceItems() async {
    final rows = await _c
        .from('website_service_items')
        .select()
        .eq('is_deleted', false)
        .order('sort_order');
    return rows
        .map(
          (e) => CmsWebsiteServiceItem.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList();
  }

  Future<List<CmsWebsiteServiceItem>> listPublishedWebsiteServiceItems() async {
    final rows = await _c
        .from('website_service_items')
        .select()
        .eq('is_deleted', false)
        .eq('status', 'active')
        .order('sort_order');
    return rows
        .map(
          (e) => CmsWebsiteServiceItem.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList();
  }

  Future<CmsWebsiteServiceItem> upsertWebsiteServiceItem({
    String? id,
    required String slug,
    required String name,
    String shortDescription = '',
    required String categorySlug,
    String iconName = 'briefcase',
    List<String> keyBenefits = const [],
    List<String> badges = const [],
    bool isFeatured = false,
    int sortOrder = 0,
    String status = 'active',
    String ctaLabel = 'Learn More',
    String? ctaHref,
  }) async {
    final cleanedHref = ctaHref?.trim();
    final row = await _c
        .from('website_service_items')
        .upsert({
          if (id != null) 'id': id,
          'slug': slug,
          'name': name,
          'short_description': shortDescription,
          'category_slug': categorySlug,
          'icon_name': iconName,
          'key_benefits': keyBenefits,
          'badges': badges,
          'is_featured': isFeatured,
          'sort_order': sortOrder,
          'status': status,
          'cta_label': ctaLabel.trim().isEmpty ? 'Learn More' : ctaLabel.trim(),
          'cta_href': (cleanedHref == null || cleanedHref.isEmpty)
              ? null
              : cleanedHref,
          'is_deleted': false,
          'updated_at': _nowIso(),
        })
        .select()
        .single();
    return CmsWebsiteServiceItem.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> deleteWebsiteServiceItem(String id) async {
    await _c
        .from('website_service_items')
        .update({'is_deleted': true, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  Future<void> setWebsiteServiceItemStatus(String id, String status) async {
    await _c
        .from('website_service_items')
        .update({'status': status, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  Future<void> setWebsiteServiceItemFeatured(String id, bool isFeatured) async {
    await _c
        .from('website_service_items')
        .update({'is_featured': isFeatured, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  Future<List<CmsWebsiteServiceCaseStudy>>
  listWebsiteServiceCaseStudies() async {
    final rows = await _c
        .from('website_service_case_studies')
        .select()
        .eq('is_deleted', false)
        .order('sort_order');
    return rows
        .map(
          (e) =>
              CmsWebsiteServiceCaseStudy.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList();
  }

  Future<List<CmsWebsiteServiceCaseStudy>>
  listPublishedWebsiteServiceCaseStudies() async {
    final rows = await _c
        .from('website_service_case_studies')
        .select()
        .eq('is_deleted', false)
        .eq('status', 'active')
        .order('sort_order');
    return rows
        .map(
          (e) =>
              CmsWebsiteServiceCaseStudy.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList();
  }

  Future<CmsWebsiteServiceCaseStudy> upsertWebsiteServiceCaseStudy({
    String? id,
    required String client,
    String serviceLabel = '',
    String challenge = '',
    String solution = '',
    String results = '',
    String serviceSlug = '',
    bool isFeatured = false,
    int sortOrder = 0,
    String status = 'active',
  }) async {
    final row = await _c
        .from('website_service_case_studies')
        .upsert({
          if (id != null) 'id': id,
          'client': client,
          'service_label': serviceLabel,
          'challenge': challenge,
          'solution': solution,
          'results': results,
          'service_slug': serviceSlug,
          'is_featured': isFeatured,
          'sort_order': sortOrder,
          'status': status,
          'is_deleted': false,
          'updated_at': _nowIso(),
        })
        .select()
        .single();
    return CmsWebsiteServiceCaseStudy.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> deleteWebsiteServiceCaseStudy(String id) async {
    await _c
        .from('website_service_case_studies')
        .update({'is_deleted': true, 'updated_at': _nowIso()})
        .eq('id', id);
  }

  Future<void> setWebsiteServiceCaseStudyStatus(
    String id,
    String status,
  ) async {
    await _c
        .from('website_service_case_studies')
        .update({'status': status, 'updated_at': _nowIso()})
        .eq('id', id);
  }
}
