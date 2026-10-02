/// Website CMS domain models — Admin "Website" control center.
///
/// These map onto existing Supabase tables (see `supabase/migrations/`):
/// `cms_sections`, `hero_sections`, `pages`, `banners`, `seo_metadata`,
/// `media` / `media_library` (view), `blogs`, `estates`, `properties`,
/// `testimonials`, `faqs`, `employees` (used for the public "Team" display).
library;

import 'package:hdhomesproject/core/media/media_delivery.dart';
import 'package:hdhomesproject/features/properties/data/models/property_detail_extras.dart';

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

List<String> _asStringList(dynamic value) {
  if (value is List) {
    return value.map((e) => e.toString()).toList();
  }
  return const [];
}

DateTime? _asDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

/// Resolves Cloudinary `secure_url` over legacy entity `url` for gallery rows.
String? _galleryDeliveryUrl(Map<String, dynamic> row) {
  final media = _asMap(row['media']);
  final secure = media['secure_url'] as String?;
  final file = row['url'] as String? ?? '';
  final resolved = MediaDelivery.resolve(secureUrl: secure, fileUrl: file);
  return resolved.isEmpty ? null : resolved;
}

/// A single content block on a CMS-managed page (homepage, landing page…).
class CmsSectionRecord {
  const CmsSectionRecord({
    required this.id,
    this.pageId,
    this.landingPageId,
    required this.sectionKey,
    this.sectionType = 'block',
    this.title,
    this.content = const {},
    this.sortOrder = 0,
    this.isVisible = true,
    this.metadata = const {},
    this.updatedAt,
  });

  factory CmsSectionRecord.fromJson(Map<String, dynamic> json) =>
      CmsSectionRecord(
        id: json['id'] as String,
        pageId: json['page_id'] as String?,
        landingPageId: json['landing_page_id'] as String?,
        sectionKey: json['section_key'] as String? ?? '',
        sectionType: json['section_type'] as String? ?? 'block',
        title: json['title'] as String?,
        content: _asMap(json['content']),
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
        isVisible: json['is_visible'] as bool? ?? true,
        metadata: _asMap(json['metadata']),
        updatedAt: _asDate(json['updated_at']),
      );

  final String id;
  final String? pageId;
  final String? landingPageId;
  final String sectionKey;
  final String sectionType;
  final String? title;
  final Map<String, dynamic> content;
  final int sortOrder;
  final bool isVisible;
  final Map<String, dynamic> metadata;
  final DateTime? updatedAt;

  String get displayTitle => title?.isNotEmpty == true
      ? title!
      : sectionKey.replaceAll('_', ' ').replaceAll('-', ' ');

  CmsSectionRecord copyWith({
    String? title,
    Map<String, dynamic>? content,
    int? sortOrder,
    bool? isVisible,
  }) => CmsSectionRecord(
    id: id,
    pageId: pageId,
    landingPageId: landingPageId,
    sectionKey: sectionKey,
    sectionType: sectionType,
    title: title ?? this.title,
    content: content ?? this.content,
    sortOrder: sortOrder ?? this.sortOrder,
    isVisible: isVisible ?? this.isVisible,
    metadata: metadata,
    updatedAt: updatedAt,
  );
}

/// Focused hero/banner editor row — backed by `hero_sections`.
class CmsHeroSection {
  const CmsHeroSection({
    this.id,
    required this.pageKey,
    this.headline = '',
    this.subheadline,
    this.ctaLabel,
    this.ctaUrl,
    this.backgroundUrl,
    this.content = const {},
    this.status = 'active',
  });

  factory CmsHeroSection.fromJson(Map<String, dynamic> json) => CmsHeroSection(
    id: json['id'] as String?,
    pageKey: json['page_key'] as String? ?? 'homepage',
    headline: json['headline'] as String? ?? '',
    subheadline: json['subheadline'] as String?,
    ctaLabel: json['cta_label'] as String?,
    ctaUrl: json['cta_url'] as String?,
    backgroundUrl: json['background_url'] as String?,
    content: _asMap(json['content']),
    status: json['status'] as String? ?? 'active',
  );

  final String? id;
  final String pageKey;
  final String headline;
  final String? subheadline;
  final String? ctaLabel;
  final String? ctaUrl;
  final String? backgroundUrl;
  final Map<String, dynamic> content;
  final String status;

  String? get secondaryCtaLabel => content['secondary_cta_label'] as String?;
  String? get secondaryCtaUrl => content['secondary_cta_url'] as String?;
  String? get videoUrl => content['video_url'] as String?;
  double get overlayOpacity =>
      (content['overlay_opacity'] as num?)?.toDouble() ?? 0.4;
  bool get isPublished => status == 'active';

  Map<String, dynamic> toUpsertJson() => {
    if (id != null) 'id': id,
    'page_key': pageKey,
    'headline': headline,
    'subheadline': subheadline,
    'cta_label': ctaLabel,
    'cta_url': ctaUrl,
    'background_url': backgroundUrl,
    'content': content,
    'status': status,
  };

  CmsHeroSection copyWith({
    String? headline,
    String? subheadline,
    String? ctaLabel,
    String? ctaUrl,
    String? backgroundUrl,
    Map<String, dynamic>? content,
    String? status,
  }) => CmsHeroSection(
    id: id,
    pageKey: pageKey,
    headline: headline ?? this.headline,
    subheadline: subheadline ?? this.subheadline,
    ctaLabel: ctaLabel ?? this.ctaLabel,
    ctaUrl: ctaUrl ?? this.ctaUrl,
    backgroundUrl: backgroundUrl ?? this.backgroundUrl,
    content: content ?? this.content,
    status: status ?? this.status,
  );
}

/// A CMS-managed static page (`pages` table).
class CmsPageRecord {
  const CmsPageRecord({
    required this.id,
    required this.title,
    required this.slug,
    this.content = const {},
    this.metaTitle,
    this.metaDescription,
    this.isPublished = false,
    this.publishedAt,
    this.status = 'active',
    this.updatedAt,
  });

  factory CmsPageRecord.fromJson(Map<String, dynamic> json) => CmsPageRecord(
    id: json['id'] as String,
    title: json['title'] as String? ?? 'Untitled page',
    slug: json['slug'] as String? ?? '',
    content: _asMap(json['content']),
    metaTitle: json['meta_title'] as String?,
    metaDescription: json['meta_description'] as String?,
    isPublished: json['is_published'] as bool? ?? false,
    publishedAt: _asDate(json['published_at']),
    status: json['status'] as String? ?? 'active',
    updatedAt: _asDate(json['updated_at']),
  );

  final String id;
  final String title;
  final String slug;
  final Map<String, dynamic> content;
  final String? metaTitle;
  final String? metaDescription;
  final bool isPublished;
  final DateTime? publishedAt;
  final String status;
  final DateTime? updatedAt;
}

/// Homepage / promo carousel entry (`banners` table).
class CmsBanner {
  const CmsBanner({
    required this.id,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.linkUrl,
    this.sortOrder = 0,
    this.startsAt,
    this.endsAt,
    this.status = 'active',
  });

  factory CmsBanner.fromJson(Map<String, dynamic> json) => CmsBanner(
    id: json['id'] as String,
    title: json['title'] as String? ?? 'Untitled banner',
    subtitle: json['subtitle'] as String?,
    imageUrl: json['image_url'] as String?,
    linkUrl: json['link_url'] as String?,
    sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    startsAt: _asDate(json['starts_at']),
    endsAt: _asDate(json['ends_at']),
    status: json['status'] as String? ?? 'active',
  );

  final String id;
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final String? linkUrl;
  final int sortOrder;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String status;

  bool get isActive => status == 'active';
}

/// SEO metadata for any page / entity (`seo_metadata` table).
class CmsSeoRecord {
  const CmsSeoRecord({
    required this.id,
    required this.entityType,
    this.entityId,
    this.path,
    this.metaTitle,
    this.metaDescription,
    this.canonicalUrl,
    this.ogImageUrl,
    this.healthScore = 0,
    this.issueCount = 0,
    this.issues = const [],
    this.lastAuditAt,
    this.metadata = const {},
  });

  factory CmsSeoRecord.fromJson(Map<String, dynamic> json) => CmsSeoRecord(
    id: json['id'] as String,
    entityType: json['entity_type'] as String? ?? 'page',
    entityId: json['entity_id'] as String?,
    path: json['path'] as String?,
    metaTitle: json['meta_title'] as String?,
    metaDescription: json['meta_description'] as String?,
    canonicalUrl: json['canonical_url'] as String?,
    ogImageUrl: json['og_image_url'] as String?,
    healthScore: (json['health_score'] as num?)?.toDouble() ?? 0,
    issueCount: (json['issue_count'] as num?)?.toInt() ?? 0,
    issues:
        (json['issues'] as List?)
            ?.map((e) => _asMap(e))
            .toList(growable: false) ??
        const [],
    lastAuditAt: _asDate(json['last_audit_at']),
    metadata: _asMap(json['metadata']),
  );

  final String id;
  final String entityType;
  final String? entityId;
  final String? path;
  final String? metaTitle;
  final String? metaDescription;
  final String? canonicalUrl;
  final String? ogImageUrl;
  final double healthScore;
  final int issueCount;
  final List<Map<String, dynamic>> issues;
  final DateTime? lastAuditAt;
  final Map<String, dynamic> metadata;

  /// Score from the fields that are actually saved, not the stored default of 0.
  SeoContentAudit get contentAudit => SeoContentAudit.evaluate(
        path: path,
        metaTitle: metaTitle,
        metaDescription: metaDescription,
        canonicalUrl: canonicalUrl,
        ogImageUrl: ogImageUrl,
      );
}

/// Checks the SEO fields a public page actually uses.
class SeoContentAudit {
  const SeoContentAudit({required this.score, required this.issues});

  final int score;
  final List<String> issues;

  static SeoContentAudit evaluate({
    String? path,
    String? metaTitle,
    String? metaDescription,
    String? canonicalUrl,
    String? ogImageUrl,
  }) {
    final issues = <String>[];
    var score = 0;

    final route = path?.trim() ?? '';
    if (route.isEmpty) {
      issues.add('Add a path such as /contact.');
    } else if (!route.startsWith('/')) {
      issues.add('Path should start with /.');
      score += 8;
    } else {
      score += 15;
    }

    final title = metaTitle?.trim() ?? '';
    if (title.isEmpty) {
      issues.add('Add a meta title.');
    } else if (title.length < 30) {
      issues.add('Meta title is short (${title.length} characters). Aim for 30–60.');
      score += 18;
    } else if (title.length > 60) {
      issues.add('Meta title is long (${title.length} characters). Aim for 30–60.');
      score += 18;
    } else {
      score += 30;
    }

    final description = metaDescription?.trim() ?? '';
    if (description.isEmpty) {
      issues.add('Add a meta description.');
    } else if (description.length < 80) {
      issues.add(
        'Meta description is short (${description.length} characters). Aim for 80–160.',
      );
      score += 16;
    } else if (description.length > 160) {
      issues.add(
        'Meta description is long (${description.length} characters). Aim for 80–160.',
      );
      score += 18;
    } else {
      score += 30;
    }

    final canonical = canonicalUrl?.trim() ?? '';
    if (canonical.isEmpty) {
      issues.add('Add a canonical URL.');
    } else if (!canonical.startsWith('http://') && !canonical.startsWith('https://')) {
      issues.add('Canonical URL should start with https://.');
      score += 4;
    } else {
      score += 10;
    }

    final image = ogImageUrl?.trim() ?? '';
    if (image.isEmpty) {
      issues.add('Add an Open Graph image URL.');
    } else if (!image.startsWith('http://') && !image.startsWith('https://')) {
      issues.add('Open Graph image should be a full https URL.');
      score += 6;
    } else {
      score += 15;
    }

    return SeoContentAudit(score: score.clamp(0, 100), issues: issues);
  }

  List<Map<String, dynamic>> get issueMaps => [
        for (final issue in issues) {'message': issue},
      ];
}

/// Media library asset — reads from the `media_library` view.
class CmsMediaAsset {
  const CmsMediaAsset({
    required this.id,
    this.title,
    required this.fileUrl,
    this.secureUrl,
    this.thumbnailUrl,
    this.fileType = 'image',
    this.mimeType,
    this.fileSize,
    this.altText,
    this.folderId,
    this.folderName,
    this.width,
    this.height,
    this.tags = const [],
    this.status = 'active',
    this.createdAt,
    this.entityType,
    this.entityId,
    this.storageProvider = 'supabase',
    this.cloudinaryPublicId,
    this.resourceType,
    this.originalFilename,
    this.sortOrder = 0,
    this.isCover = false,
    this.isPublished = true,
    this.isActive = true,
    this.uploadedBy,
    this.deliveryUrlFromView,
  });

  factory CmsMediaAsset.fromJson(Map<String, dynamic> json) {
    final deliveryFromView = json['delivery_url'] as String?;
    return CmsMediaAsset(
      id: json['id'] as String,
      title: json['title'] as String?,
      fileUrl: json['file_url'] as String? ?? '',
      secureUrl: json['secure_url'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      fileType: json['file_type'] as String? ?? 'image',
      mimeType: json['mime_type'] as String?,
      fileSize: (json['file_size'] as num?)?.toInt(),
      altText: json['alt_text'] as String?,
      folderId: json['folder_id'] as String?,
      folderName: json['folder_name'] as String?,
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      tags: _asStringList(json['tags']),
      status: json['status'] as String? ?? 'active',
      createdAt: _asDate(json['created_at']),
      entityType: json['entity_type'] as String?,
      entityId: json['entity_id']?.toString(),
      storageProvider: json['storage_provider'] as String? ?? 'supabase',
      cloudinaryPublicId: json['cloudinary_public_id'] as String?,
      resourceType: json['resource_type'] as String?,
      originalFilename: json['original_filename'] as String?,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isCover: json['is_cover'] as bool? ?? false,
      isPublished: json['is_published'] as bool? ?? true,
      isActive: json['is_active'] as bool? ?? true,
      uploadedBy: json['uploaded_by']?.toString(),
      deliveryUrlFromView: deliveryFromView,
    );
  }

  final String id;
  final String? title;
  final String fileUrl;
  final String? secureUrl;
  final String? thumbnailUrl;
  final String fileType;
  final String? mimeType;
  final int? fileSize;
  final String? altText;
  final String? folderId;
  final String? folderName;
  final int? width;
  final int? height;
  final List<String> tags;
  final String status;
  final DateTime? createdAt;
  final String? entityType;
  final String? entityId;
  final String storageProvider;
  final String? cloudinaryPublicId;
  final String? resourceType;
  final String? originalFilename;
  final int sortOrder;
  final bool isCover;
  final bool isPublished;
  final bool isActive;
  final String? uploadedBy;
  final String? deliveryUrlFromView;

  /// Cloudinary secure_url preferred; legacy Supabase file_url fallback.
  String get deliveryUrl {
    final secure = secureUrl?.trim();
    if (secure != null && secure.isNotEmpty) return secure;
    final fromView = deliveryUrlFromView?.trim();
    if (fromView != null && fromView.isNotEmpty) return fromView;
    return fileUrl;
  }

  bool get isImage =>
      fileType == 'image' || (mimeType?.startsWith('image/') ?? false);

  bool get isVideo =>
      fileType == 'video' || (mimeType?.startsWith('video/') ?? false);

  String get displayTitle => title?.isNotEmpty == true
      ? title!
      : (originalFilename ?? 'Untitled asset');
}

/// Property gallery row — `property_images` joined with optional `media` metadata.
class PropertyGalleryImage {
  const PropertyGalleryImage({
    required this.id,
    required this.propertyId,
    required this.url,
    this.mediaId,
    this.isCover = false,
    this.sortOrder = 0,
    this.altText,
    this.secureUrl,
    this.isPublished = true,
  });

  factory PropertyGalleryImage.fromJson(Map<String, dynamic> json) {
    final media = _asMap(json['media']);
    final secure = media['secure_url'] as String?;
    return PropertyGalleryImage(
      id: json['id'] as String,
      propertyId: json['property_id'] as String,
      url: json['url'] as String? ?? '',
      mediaId: json['media_id']?.toString(),
      isCover: json['is_cover'] as bool? ?? false,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      altText: (json['alt_text'] as String?) ?? (media['alt_text'] as String?),
      secureUrl: secure,
      isPublished: media['is_published'] as bool? ?? true,
    );
  }

  final String id;
  final String propertyId;
  final String url;
  final String? mediaId;
  final bool isCover;
  final int sortOrder;
  final String? altText;
  final String? secureUrl;
  final bool isPublished;

  String get deliveryUrl {
    final secure = secureUrl?.trim();
    if (secure != null && secure.isNotEmpty) return secure;
    return url;
  }
}

/// Estate gallery row — `estate_images` joined with optional `media` metadata.
class EstateGalleryImage {
  const EstateGalleryImage({
    required this.id,
    required this.estateId,
    required this.url,
    this.mediaId,
    this.isCover = false,
    this.sortOrder = 0,
    this.altText,
    this.secureUrl,
    this.isPublished = true,
  });

  factory EstateGalleryImage.fromJson(Map<String, dynamic> json) {
    final media = _asMap(json['media']);
    final secure = media['secure_url'] as String?;
    return EstateGalleryImage(
      id: json['id'] as String,
      estateId: json['estate_id'] as String,
      url: json['url'] as String? ?? '',
      mediaId: json['media_id']?.toString(),
      isCover: json['is_cover'] as bool? ?? false,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      altText: (json['alt_text'] as String?) ?? (media['alt_text'] as String?),
      secureUrl: secure,
      isPublished: media['is_published'] as bool? ?? true,
    );
  }

  final String id;
  final String estateId;
  final String url;
  final String? mediaId;
  final bool isCover;
  final int sortOrder;
  final String? altText;
  final String? secureUrl;
  final bool isPublished;

  String get deliveryUrl {
    final secure = secureUrl?.trim();
    if (secure != null && secure.isNotEmpty) return secure;
    return url;
  }
}

/// Blog post summary (`blogs` table).
class CmsBlogPost {
  const CmsBlogPost({
    required this.id,
    required this.title,
    required this.slug,
    this.excerpt,
    this.coverImageUrl,
    this.body,
    this.categoryId,
    this.blogAuthorId,
    this.isPublished = false,
    this.featured = false,
    this.publishedAt,
    this.readingTimeMinutes,
    this.seoScore,
    this.status = 'draft',
  });

  factory CmsBlogPost.fromJson(Map<String, dynamic> json) {
    final content = _asMap(json['content']);
    return CmsBlogPost(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Untitled post',
      slug: json['slug'] as String? ?? '',
      excerpt: json['excerpt'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      body: _blogBodyFromContent(content, json),
      categoryId: json['category_id'] as String?,
      blogAuthorId:
          json['blog_author_id'] as String? ?? json['author_id'] as String?,
      isPublished: json['is_published'] as bool? ?? false,
      featured: json['featured'] as bool? ?? false,
      publishedAt: _asDate(json['published_at']),
      readingTimeMinutes: (json['reading_time_minutes'] as num?)?.toInt(),
      seoScore: (json['seo_score'] as num?)?.toDouble(),
      status: json['status'] as String? ?? 'draft',
    );
  }

  final String id;
  final String title;
  final String slug;
  final String? excerpt;
  final String? coverImageUrl;
  final String? body;
  final String? categoryId;
  final String? blogAuthorId;
  final bool isPublished;
  final bool featured;
  final DateTime? publishedAt;
  final int? readingTimeMinutes;
  final double? seoScore;
  final String status;
}

String? _blogBodyFromContent(
  Map<String, dynamic> content,
  Map<String, dynamic> json,
) {
  final direct = content['body'] ?? json['body'];
  if (direct is String && direct.trim().isNotEmpty) return direct;
  final blocks = content['blocks'];
  if (blocks is List) {
    final parts = <String>[];
    for (final raw in blocks) {
      if (raw is! Map) continue;
      final block = Map<String, dynamic>.from(raw);
      final text = (block['text'] ?? block['content'] ?? '').toString().trim();
      if (text.isEmpty) continue;
      final type = (block['type'] ?? 'paragraph').toString().toLowerCase();
      if (type == 'heading' || type == 'h2' || type == 'h3') {
        parts.add('## $text');
      } else if (type == 'quote') {
        parts.add('> $text');
      } else {
        parts.add(text);
      }
    }
    if (parts.isNotEmpty) return parts.join('\n\n');
  }
  return direct is String ? direct : null;
}

class CmsBlogCategory {
  const CmsBlogCategory({
    required this.id,
    required this.name,
    required this.slug,
    this.status = 'active',
  });

  factory CmsBlogCategory.fromJson(Map<String, dynamic> json) =>
      CmsBlogCategory(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Untitled',
        slug: json['slug'] as String? ?? '',
        status: json['status'] as String? ?? 'active',
      );

  final String id;
  final String name;
  final String slug;
  final String status;

  bool get isPublished => status == 'active';
}

class CmsBlogAuthor {
  const CmsBlogAuthor({
    required this.id,
    required this.displayName,
    required this.slug,
    this.bio,
    this.avatarUrl,
    this.isActive = true,
  });

  factory CmsBlogAuthor.fromJson(Map<String, dynamic> json) => CmsBlogAuthor(
    id: json['id'] as String,
    displayName: json['display_name'] as String? ?? 'HD Homes Editorial',
    slug: json['slug'] as String? ?? '',
    bio: json['bio'] as String?,
    avatarUrl: json['avatar_url'] as String?,
    isActive: json['is_active'] as bool? ?? true,
  );

  final String id;
  final String displayName;
  final String slug;
  final String? bio;
  final String? avatarUrl;
  final bool isActive;
}

/// Estate summary for the "Featured Estates" / estates admin surfaces.
class CmsEstateSummary {
  const CmsEstateSummary({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.tagline,
    this.city,
    this.state,
    this.country = 'Nigeria',
    this.priceFromLabel,
    this.marketingStatus,
    this.coverImageUrl,
    this.galleryUrls = const [],
    this.propertyCount = 0,
    this.isFeatured = false,
    this.isPublished = false,
    this.publishedAt,
    this.status = 'active',
  });

  factory CmsEstateSummary.fromJson(Map<String, dynamic> json) {
    final images = json['estate_images'] as List? ?? const [];
    final gallery = <String>[];
    String? cover;
    final sortedImages = [...images]
      ..sort((a, b) {
        final am = _asMap(a);
        final bm = _asMap(b);
        final ao = (am['sort_order'] as num?)?.toInt() ?? 0;
        final bo = (bm['sort_order'] as num?)?.toInt() ?? 0;
        return ao.compareTo(bo);
      });
    for (final img in sortedImages) {
      final m = _asMap(img);
      if (m['is_deleted'] == true || m['is_deleted'] == 'true') continue;
      final url = _galleryDeliveryUrl(m);
      if (url == null) continue;
      gallery.add(url);
      if (cover == null && (m['is_cover'] == true || m['is_cover'] == 'true')) {
        cover = url;
      }
    }
    cover ??= gallery.isNotEmpty ? gallery.first : null;

    var propertyCount = 0;
    final props = json['properties'];
    if (props is List) {
      if (props.isNotEmpty &&
          props.first is Map &&
          _asMap(props.first).containsKey('count')) {
        propertyCount =
            (_asMap(props.first)['count'] as num?)?.toInt() ?? props.length;
      } else {
        propertyCount = props.length;
      }
    }

    return CmsEstateSummary(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Untitled estate',
      slug: json['slug'] as String? ?? '',
      description: json['description'] as String?,
      tagline: json['tagline'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      country: json['country'] as String? ?? 'Nigeria',
      priceFromLabel: json['price_from_label'] as String?,
      marketingStatus: json['marketing_status'] as String?,
      coverImageUrl: cover,
      galleryUrls: gallery,
      propertyCount: propertyCount,
      isFeatured: json['is_featured'] as bool? ?? false,
      isPublished: json['is_published'] as bool? ?? false,
      publishedAt: _asDate(json['published_at']),
      status: json['status'] as String? ?? 'active',
    );
  }

  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? tagline;
  final String? city;
  final String? state;
  final String country;
  final String? priceFromLabel;
  final String? marketingStatus;
  final String? coverImageUrl;
  final List<String> galleryUrls;
  final int propertyCount;
  final bool isFeatured;
  final bool isPublished;
  final DateTime? publishedAt;
  final String status;

  String get location =>
      [city, state].whereType<String>().where((s) => s.isNotEmpty).join(', ');

  String get displayStatus {
    final m = marketingStatus?.trim();
    if (m != null && m.isNotEmpty) return m;
    return isPublished ? 'Available' : 'Draft';
  }
}

/// Property row used by the "Featured Properties" admin surface.
class CmsPropertyFeatured {
  const CmsPropertyFeatured({
    required this.id,
    required this.title,
    required this.slug,
    this.description,
    this.summary,
    this.isFeatured = false,
    this.isPublished = false,
    this.coverImageUrl,
    this.galleryUrls = const [],
    this.city,
    this.state,
    this.addressLine,
    this.estateName,
    this.propertyCode,
    this.bedrooms,
    this.bathrooms,
    this.toilets,
    this.kitchens,
    this.parkingSpaces,
    this.floors,
    this.landSizeSqm,
    this.buildingSizeSqm,
    this.yearBuilt,
    this.powerSupply,
    this.waterSupply,
    this.internetConnectivity,
    this.architecturalConcept,
    this.investmentPotential,
    this.amenities = const [],
    this.listingPrice,
    this.promoPrice,
    this.currency = 'NGN',
    this.priceLabel,
    this.propertyType,
    this.marketingStatus,
    this.homepageBadge,
    this.status = 'draft',
    this.detailExtras,
    this.createdAt,
    this.updatedAt,
  });

  factory CmsPropertyFeatured.fromJson(Map<String, dynamic> json) {
    final locations = json['property_locations'];
    Map<String, dynamic>? loc;
    if (locations is List && locations.isNotEmpty) {
      loc = _asMap(locations.first);
    } else if (locations is Map) {
      loc = _asMap(locations);
    }

    final images = json['property_images'] as List? ?? const [];
    final gallery = <String>[];
    String? cover;
    final sortedImages = [...images]
      ..sort((a, b) {
        final am = _asMap(a);
        final bm = _asMap(b);
        final ao = (am['sort_order'] as num?)?.toInt() ?? 0;
        final bo = (bm['sort_order'] as num?)?.toInt() ?? 0;
        return ao.compareTo(bo);
      });
    for (final img in sortedImages) {
      final m = _asMap(img);
      if (m['is_deleted'] == true || m['is_deleted'] == 'true') continue;
      final url = _galleryDeliveryUrl(m);
      if (url == null) continue;
      gallery.add(url);
      if (cover == null && (m['is_cover'] == true || m['is_cover'] == 'true')) {
        cover = url;
      }
    }
    cover ??= gallery.isNotEmpty ? gallery.first : null;

    final pricingRaw = json['property_pricing'];
    Map<String, dynamic>? pricing;
    if (pricingRaw is List && pricingRaw.isNotEmpty) {
      pricing = _asMap(pricingRaw.first);
    } else if (pricingRaw is Map) {
      pricing = _asMap(pricingRaw);
    }

    final typeRaw = json['property_types'];
    String? typeName;
    if (typeRaw is List && typeRaw.isNotEmpty) {
      typeName = _asMap(typeRaw.first)['name'] as String?;
    } else if (typeRaw is Map) {
      typeName = _asMap(typeRaw)['name'] as String?;
    }

    final amenitiesRaw = json['property_amenities'] as List? ?? const [];
    final amenities = <String>[];
    for (final row in amenitiesRaw) {
      final m = _asMap(row);
      if (m['is_deleted'] == true || m['is_deleted'] == 'true') continue;
      final amenity = m['amenity'] as String?;
      if (amenity != null && amenity.trim().isNotEmpty) {
        amenities.add(amenity.trim());
      }
    }

    final listingPrice =
        (json['listing_price'] as num?)?.toDouble() ??
        (pricing?['price'] as num?)?.toDouble();

    return CmsPropertyFeatured(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Untitled property',
      slug: json['slug'] as String? ?? '',
      description: json['description'] as String?,
      summary: json['summary'] as String?,
      isFeatured: json['is_featured'] as bool? ?? false,
      isPublished: json['is_published'] as bool? ?? false,
      coverImageUrl: cover,
      galleryUrls: gallery,
      city: (loc?['city'] as String?) ?? json['city'] as String?,
      state: (loc?['state'] as String?) ?? json['state'] as String?,
      addressLine:
          (loc?['address'] as String?) ?? json['address_line'] as String?,
      estateName: json['estate_name'] as String?,
      propertyCode: json['property_code'] as String?,
      bedrooms: (json['bedrooms'] as num?)?.toDouble(),
      bathrooms: (json['bathrooms'] as num?)?.toDouble(),
      toilets: (json['toilets'] as num?)?.toDouble(),
      kitchens: (json['kitchens'] as num?)?.toDouble(),
      parkingSpaces: (json['parking_spaces'] as num?)?.toInt(),
      floors: (json['floors'] as num?)?.toInt(),
      landSizeSqm: (json['land_size_sqm'] as num?)?.toDouble(),
      buildingSizeSqm: (json['building_size_sqm'] as num?)?.toDouble(),
      yearBuilt: json['year_built'] as String?,
      powerSupply: json['power_supply'] as String?,
      waterSupply: json['water_supply'] as String?,
      internetConnectivity: json['internet_connectivity'] as String?,
      architecturalConcept: json['architectural_concept'] as String?,
      investmentPotential: json['investment_potential'] as String?,
      amenities: amenities,
      listingPrice: listingPrice,
      promoPrice: (json['promo_price'] as num?)?.toDouble(),
      currency:
          json['currency'] as String? ??
          pricing?['currency'] as String? ??
          'NGN',
      priceLabel: pricing?['price_label'] as String?,
      propertyType: typeName ?? json['category_slug'] as String?,
      marketingStatus: json['marketing_status'] as String?,
      homepageBadge: json['homepage_badge'] as String?,
      status: json['status'] as String? ?? 'draft',
      createdAt: _asDate(json['created_at']),
      updatedAt: _asDate(json['updated_at']),
      detailExtras: PropertyDetailExtras.fromJson(
        json['detail_extras'] is Map
            ? Map<String, dynamic>.from(json['detail_extras'] as Map)
            : null,
      ),
    );
  }

  final String id;
  final String title;
  final String slug;
  final String? description;
  final String? summary;
  final bool isFeatured;
  final bool isPublished;
  final String? coverImageUrl;
  final List<String> galleryUrls;
  final String? city;
  final String? state;
  final String? addressLine;
  final String? estateName;
  final String? propertyCode;
  final double? bedrooms;
  final double? bathrooms;
  final double? toilets;
  final double? kitchens;
  final int? parkingSpaces;
  final int? floors;
  final double? landSizeSqm;
  final double? buildingSizeSqm;
  final String? yearBuilt;
  final String? powerSupply;
  final String? waterSupply;
  final String? internetConnectivity;
  final String? architecturalConcept;
  final String? investmentPotential;
  final List<String> amenities;
  final double? listingPrice;
  final double? promoPrice;
  final String currency;
  final String? priceLabel;
  final String? propertyType;
  final String? marketingStatus;
  final String? homepageBadge;
  final String status;
  final PropertyDetailExtras? detailExtras;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get location =>
      [city, state].whereType<String>().where((s) => s.isNotEmpty).join(', ');

  String get overviewText {
    final d = description?.trim();
    if (d != null && d.isNotEmpty) return d;
    final s = summary?.trim();
    if (s != null && s.isNotEmpty) return s;
    return '';
  }

  String get displayPrice {
    if (priceLabel != null && priceLabel!.trim().isNotEmpty) {
      return priceLabel!.trim();
    }
    final price = listingPrice;
    if (price == null) return 'Price on request';
    final n = price >= 1000000
        ? '₦${(price / 1000000).toStringAsFixed(price % 1000000 == 0 ? 0 : 1)}M'
        : '₦${price.toStringAsFixed(0)}';
    return n;
  }

  String get displayStatus {
    final badge = homepageBadge?.trim();
    if (badge != null && badge.isNotEmpty) return badge;
    final m = marketingStatus?.trim();
    if (m != null && m.isNotEmpty) {
      return m.replaceAll('_', ' ');
    }
    return isPublished ? 'Available' : 'Draft';
  }

  String get landSizeLabel {
    final size = landSizeSqm;
    if (size == null) return '—';
    return '${size.toStringAsFixed(size.truncateToDouble() == size ? 0 : 0)} sqm';
  }

  String get buildingSizeLabel {
    final size = buildingSizeSqm;
    if (size == null) return '—';
    return '${size.toStringAsFixed(size.truncateToDouble() == size ? 0 : 0)} sqm';
  }
}

/// Client testimonial (`testimonials` table).
class CmsTestimonial {
  const CmsTestimonial({
    required this.id,
    required this.clientName,
    this.clientTitle,
    required this.content,
    this.rating,
    this.avatarUrl,
    this.isFeatured = false,
    this.status = 'active',
  });

  factory CmsTestimonial.fromJson(Map<String, dynamic> json) => CmsTestimonial(
    id: json['id'] as String,
    clientName: json['client_name'] as String? ?? 'Anonymous',
    clientTitle: json['client_title'] as String?,
    content: json['content'] as String? ?? '',
    rating: (json['rating'] as num?)?.toInt(),
    avatarUrl: json['avatar_url'] as String?,
    isFeatured: json['is_featured'] as bool? ?? false,
    status: json['status'] as String? ?? 'active',
  );

  final String id;
  final String clientName;
  final String? clientTitle;
  final String content;
  final int? rating;
  final String? avatarUrl;
  final bool isFeatured;
  final String status;
}

/// Award / certification (`awards` table) — homepage + about.
class CmsAward {
  const CmsAward({
    required this.id,
    required this.title,
    required this.issuer,
    required this.year,
    required this.description,
    this.verificationUrl,
    this.iconName = 'award',
    this.sortOrder = 0,
    this.isFeatured = false,
    this.status = 'active',
  });

  factory CmsAward.fromJson(Map<String, dynamic> json) => CmsAward(
    id: json['id'] as String,
    title: json['title'] as String? ?? 'Award',
    issuer: json['issuer'] as String? ?? '',
    year: '${json['year'] ?? ''}',
    description: json['description'] as String? ?? '',
    verificationUrl: json['verification_url'] as String?,
    iconName: json['icon_name'] as String? ?? 'award',
    sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    isFeatured: json['is_featured'] as bool? ?? false,
    status: json['status'] as String? ?? 'active',
  );

  final String id;
  final String title;
  final String issuer;
  final String year;
  final String description;
  final String? verificationUrl;
  final String iconName;
  final int sortOrder;
  final bool isFeatured;
  final String status;
}

/// Partner / affiliation shown on Home and About.
class CmsPartner {
  const CmsPartner({
    required this.id,
    required this.name,
    required this.category,
    this.tagline = '',
    this.logoUrl,
    this.iconName = 'building',
    this.sortOrder = 0,
    this.showOnHome = true,
    this.showOnAbout = true,
    this.status = 'active',
  });

  factory CmsPartner.fromJson(Map<String, dynamic> json) => CmsPartner(
    id: json['id'] as String,
    name: json['name'] as String? ?? 'Partner',
    category: json['category'] as String? ?? '',
    tagline: json['tagline'] as String? ?? '',
    logoUrl: json['logo_url'] as String?,
    iconName: json['icon_name'] as String? ?? 'building',
    sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    showOnHome: json['show_on_home'] as bool? ?? true,
    showOnAbout: json['show_on_about'] as bool? ?? true,
    status: json['status'] as String? ?? 'active',
  );

  final String id;
  final String name;
  final String category;
  final String tagline;
  final String? logoUrl;
  final String iconName;
  final int sortOrder;
  final bool showOnHome;
  final bool showOnAbout;
  final String status;
}

/// Company statistic KPI for Home / About circular hub.
class CmsCompanyStat {
  const CmsCompanyStat({
    required this.id,
    required this.value,
    required this.label,
    this.suffix = '',
    this.description = '',
    this.iconName = 'barChart',
    this.logoUrl,
    this.placement = 'orbit',
    this.sortOrder = 0,
    this.showOnHome = true,
    this.showOnAbout = true,
    this.status = 'active',
  });

  factory CmsCompanyStat.fromJson(Map<String, dynamic> json) => CmsCompanyStat(
    id: json['id'] as String,
    value: (json['value'] as num?)?.toInt() ?? 0,
    label: json['label'] as String? ?? 'Statistic',
    suffix: json['suffix'] as String? ?? '',
    description: json['description'] as String? ?? '',
    iconName: json['icon_name'] as String? ?? 'barChart',
    logoUrl: json['logo_url'] as String?,
    placement: json['placement'] as String? ?? 'orbit',
    sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    showOnHome: json['show_on_home'] as bool? ?? true,
    showOnAbout: json['show_on_about'] as bool? ?? true,
    status: json['status'] as String? ?? 'active',
  );

  final String id;
  final int value;
  final String label;
  final String suffix;
  final String description;
  final String iconName;
  final String? logoUrl;
  final String placement;
  final int sortOrder;
  final bool showOnHome;
  final bool showOnAbout;
  final String status;

  bool get isSummary => placement == 'summary';
}

/// About "Digital company profile" singleton (`digital_company_profile`).
class CmsDigitalCompanyProfile {
  const CmsDigitalCompanyProfile({
    required this.id,
    this.overline = 'COMPANY PROFILE',
    this.title = 'Digital company profile',
    this.subtitle =
        'Interactive overview of our history, projects, leadership, and investment opportunities.',
    this.cardTitle = 'Interactive Company Profile',
    this.cardDescription =
        'Explore HD Homes through an interactive digital experience — from our founding story to current projects and investment opportunities.',
    this.features = const [
      'Company History',
      'Investment Portfolio',
      'Completed Projects',
      'Certifications',
      'Executive Leadership',
      'Core Values',
    ],
    this.ctaLabel = 'View Digital Profile',
    this.viewUrl = '#',
    this.mockupImageUrl,
    this.pdfLabel = 'Download PDF',
    this.pdfUrl = '#',
    this.pdfMeta = '18 MB | Updated May 20, 2025',
    this.brochureLabel = 'Download Brochure',
    this.brochureUrl = '#',
    this.brochureMeta = '12 MB | Updated May 20, 2025',
    this.trustMessage =
        'Trusted by thousands of clients and investors across Nigeria and beyond.',
    this.yearsValue = 15,
    this.yearsSuffix = '+',
    this.yearsLabel = 'Years Experience',
    this.homesValue = 3200,
    this.homesSuffix = '+',
    this.homesLabel = 'Homes Delivered',
    this.clientsValue = 12000,
    this.clientsSuffix = '+',
    this.clientsLabel = 'Happy Clients',
    this.projectsValue = 48,
    this.projectsSuffix = '',
    this.projectsLabel = 'Projects Completed',
    this.status = 'active',
  });

  factory CmsDigitalCompanyProfile.fromJson(Map<String, dynamic> json) {
    final rawFeatures = json['features'];
    final features = <String>[];
    if (rawFeatures is List) {
      for (final item in rawFeatures) {
        final text = '$item'.trim();
        if (text.isNotEmpty) features.add(text);
      }
    }
    return CmsDigitalCompanyProfile(
      id: json['id'] as String,
      overline: json['overline'] as String? ?? 'COMPANY PROFILE',
      title: json['title'] as String? ?? 'Digital company profile',
      subtitle:
          json['subtitle'] as String? ??
          'Interactive overview of our history, projects, leadership, and investment opportunities.',
      cardTitle: json['card_title'] as String? ?? 'Interactive Company Profile',
      cardDescription:
          json['card_description'] as String? ??
          'Explore HD Homes through an interactive digital experience — from our founding story to current projects and investment opportunities.',
      features: features.isNotEmpty
          ? features
          : const [
              'Company History',
              'Investment Portfolio',
              'Completed Projects',
              'Certifications',
              'Executive Leadership',
              'Core Values',
            ],
      ctaLabel: json['cta_label'] as String? ?? 'View Digital Profile',
      viewUrl: json['view_url'] as String? ?? '#',
      mockupImageUrl: json['mockup_image_url'] as String?,
      pdfLabel: json['pdf_label'] as String? ?? 'Download PDF',
      pdfUrl: json['pdf_url'] as String? ?? '#',
      pdfMeta: json['pdf_meta'] as String? ?? '18 MB | Updated May 20, 2025',
      brochureLabel: json['brochure_label'] as String? ?? 'Download Brochure',
      brochureUrl: json['brochure_url'] as String? ?? '#',
      brochureMeta:
          json['brochure_meta'] as String? ?? '12 MB | Updated May 20, 2025',
      trustMessage:
          json['trust_message'] as String? ??
          'Trusted by thousands of clients and investors across Nigeria and beyond.',
      yearsValue: (json['years_value'] as num?)?.toInt() ?? 15,
      yearsSuffix: json['years_suffix'] as String? ?? '+',
      yearsLabel: json['years_label'] as String? ?? 'Years Experience',
      homesValue: (json['homes_value'] as num?)?.toInt() ?? 3200,
      homesSuffix: json['homes_suffix'] as String? ?? '+',
      homesLabel: json['homes_label'] as String? ?? 'Homes Delivered',
      clientsValue: (json['clients_value'] as num?)?.toInt() ?? 12000,
      clientsSuffix: json['clients_suffix'] as String? ?? '+',
      clientsLabel: json['clients_label'] as String? ?? 'Happy Clients',
      projectsValue: (json['projects_value'] as num?)?.toInt() ?? 48,
      projectsSuffix: json['projects_suffix'] as String? ?? '',
      projectsLabel: json['projects_label'] as String? ?? 'Projects Completed',
      status: json['status'] as String? ?? 'active',
    );
  }

  final String id;
  final String overline;
  final String title;
  final String subtitle;
  final String cardTitle;
  final String cardDescription;
  final List<String> features;
  final String ctaLabel;
  final String viewUrl;
  final String? mockupImageUrl;
  final String pdfLabel;
  final String pdfUrl;
  final String pdfMeta;
  final String brochureLabel;
  final String brochureUrl;
  final String brochureMeta;
  final String trustMessage;
  final int yearsValue;
  final String yearsSuffix;
  final String yearsLabel;
  final int homesValue;
  final String homesSuffix;
  final String homesLabel;
  final int clientsValue;
  final String clientsSuffix;
  final String clientsLabel;
  final int projectsValue;
  final String projectsSuffix;
  final String projectsLabel;
  final String status;
}

/// Careers page settings (singleton row).
class CmsCareersSettings {
  const CmsCareersSettings({
    required this.id,
    this.heroOverline = 'CAREERS',
    this.heroTitleLine1 = 'Build the Future',
    this.heroTitleLine2 = 'With Us',
    this.heroBody = '',
    this.heroImageUrl,
    this.cultureSummary = '',
    this.aboutSubtitle = 'Build your career while building communities.',
    this.ctaPrimaryLabel = 'View All Careers',
    this.ctaSecondaryLabel = 'Submit Your CV',
    this.cvBannerText =
        "Don't see the right role? Send us your CV and we'll keep you in mind for future opportunities.",
    this.cvBannerCtaLabel = 'Send Your CV',
    this.cvEmail = 'careers@hdhomes.ng',
    this.seoTitle,
    this.seoDescription,
    this.openPositionsOverride,
  });

  factory CmsCareersSettings.fromJson(
    Map<String, dynamic> json,
  ) => CmsCareersSettings(
    id: json['id'] as String,
    heroOverline: json['hero_overline'] as String? ?? 'CAREERS',
    heroTitleLine1: json['hero_title_line1'] as String? ?? 'Build the Future',
    heroTitleLine2: json['hero_title_line2'] as String? ?? 'With Us',
    heroBody: json['hero_body'] as String? ?? '',
    heroImageUrl: json['hero_image_url'] as String?,
    cultureSummary: json['culture_summary'] as String? ?? '',
    aboutSubtitle:
        json['about_subtitle'] as String? ??
        'Build your career while building communities.',
    ctaPrimaryLabel: json['cta_primary_label'] as String? ?? 'View All Careers',
    ctaSecondaryLabel:
        json['cta_secondary_label'] as String? ?? 'Submit Your CV',
    cvBannerText:
        json['cv_banner_text'] as String? ??
        "Don't see the right role? Send us your CV and we'll keep you in mind for future opportunities.",
    cvBannerCtaLabel: json['cv_banner_cta_label'] as String? ?? 'Send Your CV',
    cvEmail: json['cv_email'] as String? ?? 'careers@hdhomes.ng',
    seoTitle: json['seo_title'] as String?,
    seoDescription: json['seo_description'] as String?,
    openPositionsOverride: (json['open_positions_override'] as num?)?.toInt(),
  );

  final String id;
  final String heroOverline;
  final String heroTitleLine1;
  final String heroTitleLine2;
  final String heroBody;
  final String? heroImageUrl;
  final String cultureSummary;
  final String aboutSubtitle;
  final String ctaPrimaryLabel;
  final String ctaSecondaryLabel;
  final String cvBannerText;
  final String cvBannerCtaLabel;
  final String cvEmail;
  final String? seoTitle;
  final String? seoDescription;
  final int? openPositionsOverride;
}

class CmsCareerJob {
  const CmsCareerJob({
    required this.id,
    required this.title,
    this.department = '',
    this.location = '',
    this.employmentType = 'Full Time',
    this.summary = '',
    this.description = '',
    this.iconName = 'briefcase',
    this.applyUrl,
    this.sortOrder = 0,
    this.isFeatured = false,
    this.status = 'active',
    this.requirements = '',
    this.applicationDeadline,
  });

  factory CmsCareerJob.fromJson(Map<String, dynamic> json) => CmsCareerJob(
    id: json['id'] as String,
    title: json['title'] as String? ?? 'Role',
    department: json['department'] as String? ?? '',
    location: json['location'] as String? ?? '',
    employmentType: json['employment_type'] as String? ?? 'Full Time',
    summary: json['summary'] as String? ?? '',
    description: json['description'] as String? ?? '',
    iconName: json['icon_name'] as String? ?? 'briefcase',
    applyUrl: json['apply_url'] as String?,
    sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    isFeatured: json['is_featured'] as bool? ?? false,
    status: json['status'] as String? ?? 'active',
    requirements: json['requirements'] as String? ?? '',
    applicationDeadline: DateTime.tryParse(
      '${json['application_deadline'] ?? ''}',
    ),
  );

  final String id;
  final String title;
  final String department;
  final String location;
  final String employmentType;
  final String summary;
  final String description;
  final String iconName;
  final String? applyUrl;
  final int sortOrder;
  final bool isFeatured;
  final String status;
  final String requirements;
  final DateTime? applicationDeadline;
}

class CmsCareerBenefit {
  const CmsCareerBenefit({
    required this.id,
    required this.title,
    this.description = '',
    this.iconName = 'sparkles',
    this.sortOrder = 0,
    this.status = 'active',
  });

  factory CmsCareerBenefit.fromJson(Map<String, dynamic> json) =>
      CmsCareerBenefit(
        id: json['id'] as String,
        title: json['title'] as String? ?? 'Benefit',
        description: json['description'] as String? ?? '',
        iconName: json['icon_name'] as String? ?? 'sparkles',
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
        status: json['status'] as String? ?? 'active',
      );

  final String id;
  final String title;
  final String description;
  final String iconName;
  final int sortOrder;
  final String status;
}

class CmsCareerStat {
  const CmsCareerStat({
    required this.id,
    required this.value,
    required this.label,
    this.iconName = 'briefcase',
    this.sortOrder = 0,
    this.status = 'active',
  });

  factory CmsCareerStat.fromJson(Map<String, dynamic> json) => CmsCareerStat(
    id: json['id'] as String,
    value: '${json['value'] ?? ''}',
    label: json['label'] as String? ?? '',
    iconName: json['icon_name'] as String? ?? 'briefcase',
    sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    status: json['status'] as String? ?? 'active',
  );

  final String id;
  final String value;
  final String label;
  final String iconName;
  final int sortOrder;
  final String status;
}

class CmsCareerTag {
  const CmsCareerTag({
    required this.id,
    required this.label,
    this.kind = 'benefit_pill',
    this.sortOrder = 0,
    this.status = 'active',
  });

  factory CmsCareerTag.fromJson(Map<String, dynamic> json) => CmsCareerTag(
    id: json['id'] as String,
    label: json['label'] as String? ?? '',
    kind: json['kind'] as String? ?? 'benefit_pill',
    sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    status: json['status'] as String? ?? 'active',
  );

  final String id;
  final String label;
  final String kind;
  final int sortOrder;
  final String status;
}

class CmsCalculatorTrustItem {
  const CmsCalculatorTrustItem({required this.label, this.iconName = 'shield'});

  factory CmsCalculatorTrustItem.fromJson(Map<String, dynamic> json) =>
      CmsCalculatorTrustItem(
        label: json['label'] as String? ?? '',
        iconName: json['icon'] as String? ?? 'shield',
      );

  final String label;
  final String iconName;

  Map<String, dynamic> toJson() => {'label': label, 'icon': iconName};
}

class CmsCalculatorSettings {
  const CmsCalculatorSettings({
    required this.id,
    this.overline = 'PAYMENT PLANS',
    this.title = 'Payment plan calculator',
    this.subtitle = 'Estimate monthly installments for your dream home.',
    this.infoText =
        'Adjust the values to see how your monthly installment changes in real time.',
    this.applyCtaLabel = 'Apply for Plan',
    this.priceMin = 10000000,
    this.priceMax = 200000000,
    this.priceDefault = 50000000,
    this.trustItems = const [
      CmsCalculatorTrustItem(label: 'Secure Transactions', iconName: 'shield'),
      CmsCalculatorTrustItem(label: 'Flexible Payment', iconName: 'percent'),
      CmsCalculatorTrustItem(label: 'Quick Approval', iconName: 'clock'),
      CmsCalculatorTrustItem(label: 'Dedicated Support', iconName: 'headset'),
    ],
  });

  factory CmsCalculatorSettings.fromJson(Map<String, dynamic> json) {
    final raw = json['trust_items'];
    final items = <CmsCalculatorTrustItem>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) {
          items.add(
            CmsCalculatorTrustItem.fromJson(Map<String, dynamic>.from(e)),
          );
        }
      }
    }
    return CmsCalculatorSettings(
      id: json['id'] as String,
      overline: json['overline'] as String? ?? 'PAYMENT PLANS',
      title: json['title'] as String? ?? 'Payment plan calculator',
      subtitle:
          json['subtitle'] as String? ??
          'Estimate monthly installments for your dream home.',
      infoText:
          json['info_text'] as String? ??
          'Adjust the values to see how your monthly installment changes in real time.',
      applyCtaLabel: json['apply_cta_label'] as String? ?? 'Apply for Plan',
      priceMin: (json['price_min'] as num?)?.toDouble() ?? 10000000,
      priceMax: (json['price_max'] as num?)?.toDouble() ?? 200000000,
      priceDefault: (json['price_default'] as num?)?.toDouble() ?? 50000000,
      trustItems: items.isEmpty
          ? const [
              CmsCalculatorTrustItem(
                label: 'Secure Transactions',
                iconName: 'shield',
              ),
              CmsCalculatorTrustItem(
                label: 'Flexible Payment',
                iconName: 'percent',
              ),
              CmsCalculatorTrustItem(
                label: 'Quick Approval',
                iconName: 'clock',
              ),
              CmsCalculatorTrustItem(
                label: 'Dedicated Support',
                iconName: 'headset',
              ),
            ]
          : items,
    );
  }

  final String id;
  final String overline;
  final String title;
  final String subtitle;
  final String infoText;
  final String applyCtaLabel;
  final double priceMin;
  final double priceMax;
  final double priceDefault;
  final List<CmsCalculatorTrustItem> trustItems;
}

class CmsCalculatorPaymentPlan {
  const CmsCalculatorPaymentPlan({
    required this.id,
    required this.name,
    this.description = '',
    this.isGlobal = true,
    this.interestRateDefault = 12,
    this.interestRateMin = 0,
    this.interestRateMax = 30,
    this.durationMonthsDefault = 24,
    this.durationMonthsMin = 6,
    this.durationMonthsMax = 120,
    this.depositPercentMin = 10,
    this.depositPercentDefault = 20,
    this.minDepositAmount = 1000000,
    this.maxDepositAmount,
    this.calculationMethod = 'reducing_balance',
    this.sortOrder = 0,
    this.status = 'active',
    this.propertyIds = const [],
  });

  factory CmsCalculatorPaymentPlan.fromJson(Map<String, dynamic> json) {
    final links = json['calculator_plan_properties'];
    final propertyIds = <String>[];
    if (links is List) {
      for (final row in links) {
        final map = _asMap(row);
        final id = map['property_id'] as String?;
        if (id != null && id.isNotEmpty) propertyIds.add(id);
      }
    }
    return CmsCalculatorPaymentPlan(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Plan',
      description: json['description'] as String? ?? '',
      isGlobal: json['is_global'] as bool? ?? true,
      interestRateDefault:
          (json['interest_rate_default'] as num?)?.toDouble() ?? 12,
      interestRateMin: (json['interest_rate_min'] as num?)?.toDouble() ?? 0,
      interestRateMax: (json['interest_rate_max'] as num?)?.toDouble() ?? 30,
      durationMonthsDefault:
          (json['duration_months_default'] as num?)?.toInt() ?? 24,
      durationMonthsMin: (json['duration_months_min'] as num?)?.toInt() ?? 6,
      durationMonthsMax: (json['duration_months_max'] as num?)?.toInt() ?? 120,
      depositPercentMin:
          (json['deposit_percent_min'] as num?)?.toDouble() ?? 10,
      depositPercentDefault:
          (json['deposit_percent_default'] as num?)?.toDouble() ?? 20,
      minDepositAmount:
          (json['min_deposit_amount'] as num?)?.toDouble() ?? 1000000,
      maxDepositAmount: (json['max_deposit_amount'] as num?)?.toDouble(),
      calculationMethod:
          json['calculation_method'] as String? ?? 'reducing_balance',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'active',
      propertyIds: propertyIds,
    );
  }

  final String id;
  final String name;
  final String description;
  final bool isGlobal;
  final double interestRateDefault;
  final double interestRateMin;
  final double interestRateMax;
  final int durationMonthsDefault;
  final int durationMonthsMin;
  final int durationMonthsMax;
  final double depositPercentMin;
  final double depositPercentDefault;
  final double minDepositAmount;
  final double? maxDepositAmount;
  final String calculationMethod;
  final int sortOrder;
  final String status;
  final List<String> propertyIds;

  bool get isActive => status == 'active';
}

class CmsCalculatorApplication {
  const CmsCalculatorApplication({
    required this.id,
    required this.fullName,
    required this.email,
    required this.propertyPrice,
    required this.depositAmount,
    required this.durationMonths,
    required this.interestRate,
    required this.loanAmount,
    required this.monthlyPayment,
    required this.totalRepayment,
    required this.totalInterest,
    this.phone = '',
    this.city = '',
    this.preferredContact = 'phone',
    this.occupation = '',
    this.applicantMessage = '',
    this.adminReply = '',
    this.planId,
    this.planName = '',
    this.propertyId,
    this.userId,
    this.status = 'new',
    this.notes = '',
    this.createdAt,
    this.repliedAt,
  });

  factory CmsCalculatorApplication.fromJson(Map<String, dynamic> json) {
    final plan = json['calculator_payment_plans'];
    return CmsCalculatorApplication(
      id: json['id'] as String,
      planId: json['plan_id'] as String?,
      planName: plan is Map ? plan['name'] as String? ?? '' : '',
      propertyId: json['property_id'] as String?,
      userId: json['user_id'] as String?,
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      city: json['city'] as String? ?? '',
      preferredContact: json['preferred_contact'] as String? ?? 'phone',
      occupation: json['occupation'] as String? ?? '',
      applicantMessage: json['applicant_message'] as String? ?? '',
      adminReply: json['admin_reply'] as String? ?? '',
      propertyPrice: (json['property_price'] as num?)?.toDouble() ?? 0,
      depositAmount: (json['deposit_amount'] as num?)?.toDouble() ?? 0,
      durationMonths: (json['duration_months'] as num?)?.toInt() ?? 0,
      interestRate: (json['interest_rate'] as num?)?.toDouble() ?? 0,
      loanAmount: (json['loan_amount'] as num?)?.toDouble() ?? 0,
      monthlyPayment: (json['monthly_payment'] as num?)?.toDouble() ?? 0,
      totalRepayment: (json['total_repayment'] as num?)?.toDouble() ?? 0,
      totalInterest: (json['total_interest'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'new',
      notes: json['notes'] as String? ?? '',
      createdAt: _asDate(json['created_at']),
      repliedAt: _asDate(json['replied_at']),
    );
  }

  final String id;
  final String? planId;
  final String planName;
  final String? propertyId;
  final String? userId;
  final String fullName;
  final String email;
  final String phone;
  final String city;
  final String preferredContact;
  final String occupation;
  final String applicantMessage;
  final String adminReply;
  final double propertyPrice;
  final double depositAmount;
  final int durationMonths;
  final double interestRate;
  final double loanAmount;
  final double monthlyPayment;
  final double totalRepayment;
  final double totalInterest;
  final String status;
  final String notes;
  final DateTime? createdAt;
  final DateTime? repliedAt;

  bool get hasReply => adminReply.trim().isNotEmpty;

  String get statusLabel => switch (status) {
    'reviewed' => 'Reviewed',
    'contacted' => 'Contacted',
    'qualified' => 'Qualified',
    'converted' => 'Converted',
    'closed' => 'Closed',
    'spam' => 'Spam',
    _ => 'New',
  };

  String get preferredContactLabel => switch (preferredContact) {
    'email' => 'Email',
    'whatsapp' => 'WhatsApp',
    _ => 'Phone',
  };
}

/// Staff member shown on the public "About / Team" page.
///
/// Backed by `employees`; the website-facing attributes (bio, job title,
/// visibility, sort order) live in `employees.metadata` since there is no
/// dedicated public team table — see [CmsService] for details.
class CmsTeamMember {
  const CmsTeamMember({
    required this.id,
    required this.fullName,
    this.email,
    this.phone,
    this.avatarUrl,
    this.jobTitle,
    this.bio,
    this.showOnWebsite = false,
    this.sortOrder = 0,
    this.status = 'active',
  });

  factory CmsTeamMember.fromJson(Map<String, dynamic> json) {
    final metadata = _asMap(json['metadata']);
    final first = json['first_name'] as String? ?? '';
    final last = json['last_name'] as String? ?? '';
    final preferred = json['preferred_name'] as String?;
    final name = (preferred?.isNotEmpty ?? false)
        ? preferred!
        : [first, last].where((s) => s.isNotEmpty).join(' ');
    return CmsTeamMember(
      id: json['id'] as String,
      fullName: name.isNotEmpty ? name : 'Team member',
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      jobTitle:
          metadata['job_title'] as String? ?? json['role_slug'] as String?,
      bio: metadata['bio'] as String?,
      showOnWebsite: metadata['show_on_website'] as bool? ?? false,
      sortOrder: (metadata['sort_order'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'active',
    );
  }

  final String id;
  final String fullName;
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final String? jobTitle;
  final String? bio;
  final bool showOnWebsite;
  final int sortOrder;
  final String status;
}

/// Frequently asked question (`faqs` table).
class CmsFaq {
  const CmsFaq({
    required this.id,
    required this.question,
    required this.answer,
    this.category,
    this.sortOrder = 0,
    this.status = 'active',
  });

  factory CmsFaq.fromJson(Map<String, dynamic> json) => CmsFaq(
    id: json['id'] as String,
    question: json['question'] as String? ?? '',
    answer: json['answer'] as String? ?? '',
    category: json['category'] as String?,
    sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    status: json['status'] as String? ?? 'active',
  );

  final String id;
  final String question;
  final String answer;
  final String? category;
  final int sortOrder;
  final String status;
}

/// About "Our client journey" step (`client_journey_steps` table).
class CmsClientJourneyStep {
  const CmsClientJourneyStep({
    required this.id,
    required this.title,
    this.description = '',
    this.timeline = '',
    this.iconName = 'circle',
    this.sortOrder = 0,
    this.status = 'active',
  });

  factory CmsClientJourneyStep.fromJson(Map<String, dynamic> json) =>
      CmsClientJourneyStep(
        id: json['id'] as String,
        title: json['title'] as String? ?? 'Step',
        description: json['description'] as String? ?? '',
        timeline: json['timeline'] as String? ?? '',
        iconName: json['icon_name'] as String? ?? 'circle',
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
        status: json['status'] as String? ?? 'active',
      );

  final String id;
  final String title;
  final String description;
  final String timeline;
  final String iconName;
  final int sortOrder;
  final String status;
}

/// Benefit card under the client journey (`journey_benefits` table).
class CmsJourneyBenefit {
  const CmsJourneyBenefit({
    required this.id,
    required this.title,
    this.description = '',
    this.iconName = 'shield',
    this.sortOrder = 0,
    this.status = 'active',
  });

  factory CmsJourneyBenefit.fromJson(Map<String, dynamic> json) =>
      CmsJourneyBenefit(
        id: json['id'] as String,
        title: json['title'] as String? ?? 'Benefit',
        description: json['description'] as String? ?? '',
        iconName: json['icon_name'] as String? ?? 'shield',
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
        status: json['status'] as String? ?? 'active',
      );

  final String id;
  final String title;
  final String description;
  final String iconName;
  final int sortOrder;
  final String status;
}

/// Public office / sales location (`office_locations` table).
class CmsOfficeLocation {
  const CmsOfficeLocation({
    required this.id,
    required this.name,
    this.slug,
    this.officeType = 'Office',
    this.shortDescription = '',
    this.description = '',
    this.address = '',
    this.city = '',
    this.state = '',
    this.country = 'Nigeria',
    this.latitude,
    this.longitude,
    this.phone = '',
    this.whatsapp = '',
    this.email = '',
    this.hours = '',
    this.mapUrl = 'https://maps.google.com',
    this.appointmentPath = '/book-inspection',
    this.mapLabel = 'View Map',
    this.appointmentLabel = 'Book Appointment',
    this.coverImage,
    this.parkingInfo = '',
    this.nearbyLandmarks = const [],
    this.isFeatured = false,
    this.showOnMap = true,
    this.allowAppointments = true,
    this.facilities = const {},
    this.sortOrder = 0,
    this.status = 'active',
  });

  factory CmsOfficeLocation.fromJson(Map<String, dynamic> json) {
    final landmarksRaw = json['nearby_landmarks'];
    final landmarks = <String>[];
    if (landmarksRaw is List) {
      for (final e in landmarksRaw) {
        final s = '$e'.trim();
        if (s.isNotEmpty) landmarks.add(s);
      }
    }
    final facilitiesRaw = json['facilities'];
    final facilities = <String, bool>{};
    if (facilitiesRaw is Map) {
      facilitiesRaw.forEach((k, v) {
        facilities['$k'] = v == true;
      });
    }
    return CmsOfficeLocation(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Office',
      slug: json['slug'] as String?,
      officeType: json['office_type'] as String? ?? 'Office',
      shortDescription: json['short_description'] as String? ?? '',
      description: json['description'] as String? ?? '',
      address: json['address'] as String? ?? '',
      city: json['city'] as String? ?? '',
      state: json['state'] as String? ?? '',
      country: json['country'] as String? ?? 'Nigeria',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      phone: json['phone'] as String? ?? '',
      whatsapp: json['whatsapp'] as String? ?? '',
      email: json['email'] as String? ?? '',
      hours: json['hours'] as String? ?? '',
      mapUrl: json['map_url'] as String? ?? 'https://maps.google.com',
      appointmentPath:
          json['appointment_path'] as String? ?? '/book-inspection',
      mapLabel: json['map_label'] as String? ?? 'View Map',
      appointmentLabel:
          json['appointment_label'] as String? ?? 'Book Appointment',
      coverImage: json['cover_image'] as String?,
      parkingInfo: json['parking_info'] as String? ?? '',
      nearbyLandmarks: landmarks,
      isFeatured: json['is_featured'] as bool? ?? false,
      showOnMap: json['show_on_map'] as bool? ?? true,
      allowAppointments: json['allow_appointments'] as bool? ?? true,
      facilities: facilities,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'active',
    );
  }

  final String id;
  final String name;
  final String? slug;
  final String officeType;
  final String shortDescription;
  final String description;
  final String address;
  final String city;
  final String state;
  final String country;
  final double? latitude;
  final double? longitude;
  final String phone;
  final String whatsapp;
  final String email;
  final String hours;
  final String mapUrl;
  final String appointmentPath;
  final String mapLabel;
  final String appointmentLabel;
  final String? coverImage;
  final String parkingInfo;
  final List<String> nearbyLandmarks;
  final bool isFeatured;
  final bool showOnMap;
  final bool allowAppointments;
  final Map<String, bool> facilities;
  final int sortOrder;
  final String status;
}

/// Marketing investment opportunity (`website_investment_opportunities`).
class CmsWebsiteInvestmentCategory {
  const CmsWebsiteInvestmentCategory({
    required this.id,
    required this.name,
    required this.slug,
    this.description = '',
    this.icon = 'building2',
    this.displayOrder = 0,
    this.isActive = true,
  });

  factory CmsWebsiteInvestmentCategory.fromJson(Map<String, dynamic> json) {
    return CmsWebsiteInvestmentCategory(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Category',
      slug: json['slug'] as String? ?? '',
      description: json['description'] as String? ?? '',
      icon: json['icon'] as String? ?? 'building2',
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  final String id;
  final String name;
  final String slug;
  final String description;
  final String icon;
  final int displayOrder;
  final bool isActive;
}

class CmsWebsiteInvestmentOpportunity {
  const CmsWebsiteInvestmentOpportunity({
    required this.id,
    required this.projectName,
    required this.slug,
    this.coverImageUrl,
    this.galleryImages = const [],
    this.shortDescription = '',
    this.fullDescription = '',
    this.investmentType = 'Real Estate Fund',
    this.typeLabel = 'Estate Development',
    this.categoryId,
    this.location = '',
    this.city = '',
    this.roiMin = 0,
    this.roiMax = 0,
    this.roiLabel = '',
    this.duration = '',
    this.riskLevel = 'Moderate',
    this.growthPotential = 'High',
    this.minimumInvestment = '',
    this.targetAmount = '',
    this.amountRaised = '',
    this.progressPct = 0,
    this.opportunityStatus = 'open',
    this.isFeatured = false,
    this.featuredBadge = 'Featured',
    this.demandBadge,
    this.ctaLabel = 'View Opportunity',
    this.ctaLink,
    this.secondaryCtaLabel = '',
    this.secondaryCtaLink,
    this.showProgress = true,
    this.metaTitle = '',
    this.metaDescription = '',
    this.openingDate,
    this.closingDate,
    this.sortOrder = 0,
    this.status = 'active',
  });

  factory CmsWebsiteInvestmentOpportunity.fromJson(Map<String, dynamic> json) {
    final galleryRaw = json['gallery_images'];
    final gallery = <String>[];
    if (galleryRaw is List) {
      for (final e in galleryRaw) {
        final s = '$e'.trim();
        if (s.isNotEmpty) gallery.add(s);
      }
    }
    return CmsWebsiteInvestmentOpportunity(
      id: json['id'] as String,
      projectName: json['project_name'] as String? ?? 'Opportunity',
      slug: json['slug'] as String? ?? '',
      coverImageUrl: json['cover_image_url'] as String?,
      galleryImages: gallery,
      shortDescription: json['short_description'] as String? ?? '',
      fullDescription: json['full_description'] as String? ?? '',
      investmentType: json['investment_type'] as String? ?? 'Real Estate Fund',
      typeLabel: json['type_label'] as String? ?? 'Estate Development',
      categoryId: json['category_id'] as String?,
      location: json['location'] as String? ?? '',
      city: json['city'] as String? ?? '',
      roiMin: (json['roi_min'] as num?)?.toDouble() ?? 0,
      roiMax: (json['roi_max'] as num?)?.toDouble() ?? 0,
      roiLabel: json['roi_label'] as String? ?? '',
      duration: json['duration'] as String? ?? '',
      riskLevel: json['risk_level'] as String? ?? 'Moderate',
      growthPotential: json['growth_potential'] as String? ?? 'High',
      minimumInvestment: json['minimum_investment'] as String? ?? '',
      targetAmount: json['target_amount'] as String? ?? '',
      amountRaised: json['amount_raised'] as String? ?? '',
      progressPct: (json['progress_pct'] as num?)?.toDouble() ?? 0,
      opportunityStatus: json['opportunity_status'] as String? ?? 'open',
      isFeatured: json['is_featured'] as bool? ?? false,
      featuredBadge: json['featured_badge'] as String? ?? 'Featured',
      demandBadge: json['demand_badge'] as String?,
      ctaLabel: json['cta_label'] as String? ?? 'View Opportunity',
      ctaLink: json['cta_link'] as String?,
      secondaryCtaLabel: json['secondary_cta_label'] as String? ?? '',
      secondaryCtaLink: json['secondary_cta_link'] as String?,
      showProgress: json['show_progress'] as bool? ?? true,
      metaTitle: json['meta_title'] as String? ?? '',
      metaDescription: json['meta_description'] as String? ?? '',
      openingDate: json['opening_date'] as String?,
      closingDate: json['closing_date'] as String?,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'active',
    );
  }

  final String id;
  final String projectName;
  final String slug;
  final String? coverImageUrl;
  final List<String> galleryImages;
  final String shortDescription;
  final String fullDescription;
  final String investmentType;
  final String typeLabel;
  final String? categoryId;
  final String location;
  final String city;
  final double roiMin;
  final double roiMax;
  final String roiLabel;
  final String duration;
  final String riskLevel;
  final String growthPotential;
  final String minimumInvestment;
  final String targetAmount;
  final String amountRaised;
  final double progressPct;
  final String opportunityStatus;
  final bool isFeatured;
  final String featuredBadge;
  final String? demandBadge;
  final String ctaLabel;
  final String? ctaLink;
  final String secondaryCtaLabel;
  final String? secondaryCtaLink;
  final bool showProgress;
  final String metaTitle;
  final String metaDescription;
  final String? openingDate;
  final String? closingDate;
  final int sortOrder;
  final String status;

  String get categoryLabel =>
      typeLabel.trim().isNotEmpty ? typeLabel.trim() : investmentType;

  String get categorySlug {
    final raw = categoryLabel.toLowerCase().trim();
    return raw
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  String get locationDisplay {
    if (location.trim().isNotEmpty) return location.trim();
    return city.trim();
  }

  String get roiDisplay {
    final a = _trimNum(roiMin);
    final b = _trimNum(roiMax);
    final range = a == b ? '$a%' : '$a–$b%';
    if (roiLabel.trim().isEmpty) return range;
    return '$range ${roiLabel.trim()}';
  }

  String get statusLabel {
    switch (opportunityStatus) {
      case 'limited':
        return 'Limited';
      case 'closing_soon':
        return 'Closing Soon';
      case 'coming_soon':
        return 'Coming Soon';
      case 'closed':
        return 'Closed';
      case 'sold_out':
        return 'Sold Out';
      default:
        return 'Open';
    }
  }

  bool get isOpenForEnquiry =>
      opportunityStatus == 'open' ||
      opportunityStatus == 'limited' ||
      opportunityStatus == 'closing_soon';

  bool get isPublished => status == 'active';

  double get progressFraction => (progressPct / 100).clamp(0.0, 1.0);

  static String _trimNum(double v) {
    if (v == v.roundToDouble()) return '${v.toInt()}';
    return v.toStringAsFixed(1);
  }

  String get detailPath => '/investment/$slug';

  String get seoTitle => metaTitle.trim().isNotEmpty
      ? metaTitle.trim()
      : '$projectName | HD Homes';

  String get seoDescription {
    if (metaDescription.trim().isNotEmpty) return metaDescription.trim();
    if (shortDescription.trim().isNotEmpty) return shortDescription.trim();
    return 'Explore $projectName — a structured HD Homes investment opportunity.';
  }
}

/// Homepage construction progress card (`website_construction_updates`).
class CmsWebsiteConstructionUpdate {
  const CmsWebsiteConstructionUpdate({
    required this.id,
    required this.projectName,
    required this.slug,
    this.statusUpdate = '',
    this.expectedCompletion = '',
    this.progressPct = 0,
    this.currentPhaseIndex = 0,
    this.phases = const [
      'Planning',
      'Foundation',
      'Structure',
      'Roofing',
      'Finishing',
      'Completed',
    ],
    this.coverImageUrl,
    this.galleryImageUrls = const [],
    this.ctaLabel = 'View Progress',
    this.ctaLink,
    this.sortOrder = 0,
    this.status = 'active',
  });

  factory CmsWebsiteConstructionUpdate.fromJson(Map<String, dynamic> json) {
    final phasesRaw = json['phases'];
    final phases = <String>[];
    if (phasesRaw is List) {
      for (final e in phasesRaw) {
        final s = '$e'.trim();
        if (s.isNotEmpty) phases.add(s);
      }
    }
    return CmsWebsiteConstructionUpdate(
      id: json['id'] as String,
      projectName: json['project_name'] as String? ?? 'Project',
      slug: json['slug'] as String? ?? '',
      statusUpdate: json['status_update'] as String? ?? '',
      expectedCompletion: json['expected_completion'] as String? ?? '',
      progressPct: (json['progress_pct'] as num?)?.toDouble() ?? 0,
      currentPhaseIndex: (json['current_phase_index'] as num?)?.toInt() ?? 0,
      phases: phases.isEmpty
          ? const [
              'Planning',
              'Foundation',
              'Structure',
              'Roofing',
              'Finishing',
              'Completed',
            ]
          : phases,
      coverImageUrl: json['cover_image_url'] as String?,
      galleryImageUrls: _parseGalleryUrls(json['gallery_image_urls']),
      ctaLabel: json['cta_label'] as String? ?? 'View Progress',
      ctaLink: json['cta_link'] as String?,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'active',
    );
  }

  final String id;
  final String projectName;
  final String slug;
  final String statusUpdate;
  final String expectedCompletion;
  final double progressPct;
  final int currentPhaseIndex;
  final List<String> phases;
  final String? coverImageUrl;
  final List<String> galleryImageUrls;
  final String ctaLabel;
  final String? ctaLink;
  final int sortOrder;
  final String status;

  double get progressFraction => (progressPct / 100).clamp(0.0, 1.0);

  int get safePhaseIndex {
    if (phases.isEmpty) return 0;
    return currentPhaseIndex.clamp(0, phases.length - 1);
  }

  String get detailPath => '/construction/$slug';

  List<String> get allImageUrls {
    final urls = <String>[];
    final cover = coverImageUrl?.trim();
    if (cover != null && cover.isNotEmpty) urls.add(cover);
    for (final url in galleryImageUrls) {
      final trimmed = url.trim();
      if (trimmed.isNotEmpty && !urls.contains(trimmed)) {
        urls.add(trimmed);
      }
    }
    return urls;
  }
}

List<String> _parseGalleryUrls(dynamic raw) {
  if (raw is! List) return const [];
  return [
    for (final e in raw)
      if ('$e'.trim().isNotEmpty) '$e'.trim(),
  ];
}

class CmsRoiCalculatorSettings {
  const CmsRoiCalculatorSettings({
    required this.id,
    this.isEnabled = true,
    this.overline = 'INVESTOR TOOLS',
    this.title = 'ROI calculator',
    this.subtitle = 'Project returns on your HD Homes investment.',
    this.inputsTitle = 'Investment inputs',
    this.inputsSubtitle = 'Adjust the values to see your projected returns.',
    this.resultsTitle = 'Projected returns',
    this.infoText =
        'Adjust the inputs to see your projected returns in real time.',
    this.disclaimerText =
        'Estimated values based on current investment assumptions. Returns are projections and not guaranteed.',
    this.ctaLabel = 'Explore Investments',
    this.ctaPath = '/investment',
    this.currencySymbol = '₦',
    this.currencyCode = 'NGN',
    this.compoundingMethod = 'compound',
    this.amountMin = 1000000,
    this.amountMax = 100000000,
    this.amountDefault = 5000000,
    this.growthMin = 1,
    this.growthMax = 30,
    this.growthDefault = 15,
    this.yearsMin = 1,
    this.yearsMax = 10,
    this.yearsDefault = 3,
    this.showChart = true,
  });

  factory CmsRoiCalculatorSettings.fromJson(Map<String, dynamic> json) {
    return CmsRoiCalculatorSettings(
      id: json['id'] as String,
      isEnabled: json['is_enabled'] as bool? ?? true,
      overline: json['overline'] as String? ?? 'INVESTOR TOOLS',
      title: json['title'] as String? ?? 'ROI calculator',
      subtitle:
          json['subtitle'] as String? ??
          'Project returns on your HD Homes investment.',
      inputsTitle: json['inputs_title'] as String? ?? 'Investment inputs',
      inputsSubtitle:
          json['inputs_subtitle'] as String? ??
          'Adjust the values to see your projected returns.',
      resultsTitle: json['results_title'] as String? ?? 'Projected returns',
      infoText:
          json['info_text'] as String? ??
          'Adjust the inputs to see your projected returns in real time.',
      disclaimerText:
          json['disclaimer_text'] as String? ??
          'Estimated values based on current investment assumptions. Returns are projections and not guaranteed.',
      ctaLabel: json['cta_label'] as String? ?? 'Explore Investments',
      ctaPath: json['cta_path'] as String? ?? '/investment',
      currencySymbol: json['currency_symbol'] as String? ?? '₦',
      currencyCode: json['currency_code'] as String? ?? 'NGN',
      compoundingMethod: json['compounding_method'] as String? ?? 'compound',
      amountMin: (json['amount_min'] as num?)?.toDouble() ?? 1000000,
      amountMax: (json['amount_max'] as num?)?.toDouble() ?? 100000000,
      amountDefault: (json['amount_default'] as num?)?.toDouble() ?? 5000000,
      growthMin: (json['growth_min'] as num?)?.toDouble() ?? 1,
      growthMax: (json['growth_max'] as num?)?.toDouble() ?? 30,
      growthDefault: (json['growth_default'] as num?)?.toDouble() ?? 15,
      yearsMin: (json['years_min'] as num?)?.toDouble() ?? 1,
      yearsMax: (json['years_max'] as num?)?.toDouble() ?? 10,
      yearsDefault: (json['years_default'] as num?)?.toDouble() ?? 3,
      showChart: json['show_chart'] as bool? ?? true,
    );
  }

  final String id;
  final bool isEnabled;
  final String overline;
  final String title;
  final String subtitle;
  final String inputsTitle;
  final String inputsSubtitle;
  final String resultsTitle;
  final String infoText;
  final String disclaimerText;
  final String ctaLabel;
  final String ctaPath;
  final String currencySymbol;
  final String currencyCode;
  final String compoundingMethod;
  final double amountMin;
  final double amountMax;
  final double amountDefault;
  final double growthMin;
  final double growthMax;
  final double growthDefault;
  final double yearsMin;
  final double yearsMax;
  final double yearsDefault;
  final bool showChart;
}

/// Browse-by-category marketing cards (Home + Properties).
class CmsBrowseCategory {
  const CmsBrowseCategory({
    required this.id,
    required this.label,
    required this.filterKey,
    this.description = '',
    this.iconName = 'home',
    this.imageUrl,
    this.isFeatured = false,
    this.sortOrder = 0,
    this.status = 'active',
  });

  factory CmsBrowseCategory.fromJson(Map<String, dynamic> json) =>
      CmsBrowseCategory(
        id: json['id'] as String,
        label: json['label'] as String? ?? '',
        filterKey: json['filter_key'] as String? ?? '',
        description: json['description'] as String? ?? '',
        iconName: json['icon_name'] as String? ?? 'home',
        imageUrl: json['image_url'] as String?,
        isFeatured: json['is_featured'] as bool? ?? false,
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
        status: json['status'] as String? ?? 'active',
      );

  final String id;
  final String label;
  final String filterKey;
  final String description;
  final String iconName;
  final String? imageUrl;
  final bool isFeatured;
  final int sortOrder;
  final String status;
}

/// Marketing market insight card (`website_market_insights`).
class CmsWebsiteMarketInsight {
  const CmsWebsiteMarketInsight({
    required this.id,
    required this.title,
    this.value = '',
    this.trend = '',
    this.summary = '',
    this.location = '',
    this.category = '',
    this.icon = 'trendingUp',
    this.source = '',
    this.sourceUrl,
    this.coverImageUrl,
    this.visualType = 'line_chart',
    this.trendDirection = 'up',
    this.isFeatured = false,
    this.sortOrder = 0,
    this.status = 'draft',
    this.isPublishedFlag = false,
    this.publishedAt,
    this.updatedAt,
    this.createdAt,
  });

  factory CmsWebsiteMarketInsight.fromJson(Map<String, dynamic> json) {
    return CmsWebsiteMarketInsight(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Insight',
      value: json['value'] as String? ?? '',
      trend: json['trend'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      location: json['location'] as String? ?? '',
      category: json['category'] as String? ?? '',
      icon: json['icon'] as String? ?? 'trendingUp',
      source: json['source'] as String? ?? '',
      sourceUrl: json['source_url'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      visualType: json['visual_type'] as String? ?? 'line_chart',
      trendDirection: json['trend_direction'] as String? ?? 'up',
      isFeatured: json['is_featured'] as bool? ?? false,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'draft',
      isPublishedFlag:
          json['is_published'] as bool? ??
          (json['status'] == 'active' || json['status'] == 'published'),
      publishedAt: json['published_at'] != null
          ? DateTime.tryParse('${json['published_at']}')
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse('${json['updated_at']}')
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse('${json['created_at']}')
          : null,
    );
  }

  final String id;
  final String title;
  final String value;
  final String trend;
  final String summary;
  final String location;
  final String category;
  final String icon;
  final String source;
  final String? sourceUrl;
  final String? coverImageUrl;
  final String visualType;
  final String trendDirection;
  final bool isFeatured;
  final int sortOrder;
  final String status;
  final bool isPublishedFlag;
  final DateTime? publishedAt;
  final DateTime? updatedAt;
  final DateTime? createdAt;

  bool get isPublished =>
      isPublishedFlag && (status == 'published' || status == 'active');

  bool get isArchived => status == 'archived';

  bool get isDraft => !isPublished && !isArchived;

  bool get hasDetailLink => sourceUrl != null && sourceUrl!.trim().isNotEmpty;

  String get statusLabel => isPublished
      ? 'Published'
      : isArchived
      ? 'Archived'
      : 'Draft';
}

class CmsWebsiteServiceCategory {
  const CmsWebsiteServiceCategory({
    required this.id,
    required this.name,
    required this.slug,
    this.description = '',
    this.iconName = 'briefcase',
    this.sortOrder = 0,
    this.status = 'active',
    this.isDeleted = false,
  });

  factory CmsWebsiteServiceCategory.fromJson(Map<String, dynamic> json) =>
      CmsWebsiteServiceCategory(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Category',
        slug: json['slug'] as String? ?? '',
        description: json['description'] as String? ?? '',
        iconName: json['icon_name'] as String? ?? 'briefcase',
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
        status: json['status'] as String? ?? 'active',
        isDeleted: json['is_deleted'] as bool? ?? false,
      );

  final String id;
  final String name;
  final String slug;
  final String description;
  final String iconName;
  final int sortOrder;
  final String status;
  final bool isDeleted;
}

class CmsWebsiteServiceItem {
  const CmsWebsiteServiceItem({
    required this.id,
    required this.slug,
    required this.name,
    this.shortDescription = '',
    this.categorySlug = '',
    this.iconName = 'briefcase',
    this.keyBenefits = const [],
    this.badges = const [],
    this.isFeatured = false,
    this.sortOrder = 0,
    this.status = 'active',
    this.isDeleted = false,
    this.ctaLabel = 'Learn More',
    this.ctaHref,
  });

  factory CmsWebsiteServiceItem.fromJson(Map<String, dynamic> json) =>
      CmsWebsiteServiceItem(
        id: json['id'] as String,
        slug: json['slug'] as String? ?? '',
        name: json['name'] as String? ?? 'Service',
        shortDescription: json['short_description'] as String? ?? '',
        categorySlug: json['category_slug'] as String? ?? '',
        iconName: json['icon_name'] as String? ?? 'briefcase',
        keyBenefits: _asStringList(json['key_benefits']),
        badges: _asStringList(json['badges']),
        isFeatured: json['is_featured'] as bool? ?? false,
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
        status: json['status'] as String? ?? 'active',
        isDeleted: json['is_deleted'] as bool? ?? false,
        ctaLabel: (json['cta_label'] as String?)?.trim().isNotEmpty == true
            ? (json['cta_label'] as String).trim()
            : 'Learn More',
        ctaHref: (json['cta_href'] as String?)?.trim().isNotEmpty == true
            ? (json['cta_href'] as String).trim()
            : null,
      );

  final String id;
  final String slug;
  final String name;
  final String shortDescription;
  final String categorySlug;
  final String iconName;
  final List<String> keyBenefits;
  final List<String> badges;
  final bool isFeatured;
  final int sortOrder;
  final String status;
  final bool isDeleted;
  final String ctaLabel;
  final String? ctaHref;
}

class CmsWebsiteServiceCaseStudy {
  const CmsWebsiteServiceCaseStudy({
    required this.id,
    required this.client,
    this.serviceLabel = '',
    this.challenge = '',
    this.solution = '',
    this.results = '',
    this.serviceSlug = '',
    this.isFeatured = false,
    this.sortOrder = 0,
    this.status = 'active',
    this.isDeleted = false,
  });

  factory CmsWebsiteServiceCaseStudy.fromJson(Map<String, dynamic> json) =>
      CmsWebsiteServiceCaseStudy(
        id: json['id'] as String,
        client: json['client'] as String? ?? 'Client',
        serviceLabel: json['service_label'] as String? ?? '',
        challenge: json['challenge'] as String? ?? '',
        solution: json['solution'] as String? ?? '',
        results: json['results'] as String? ?? '',
        serviceSlug: json['service_slug'] as String? ?? '',
        isFeatured: json['is_featured'] as bool? ?? false,
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
        status: json['status'] as String? ?? 'active',
        isDeleted: json['is_deleted'] as bool? ?? false,
      );

  final String id;
  final String client;
  final String serviceLabel;
  final String challenge;
  final String solution;
  final String results;
  final String serviceSlug;
  final bool isFeatured;
  final int sortOrder;
  final String status;
  final bool isDeleted;
}
