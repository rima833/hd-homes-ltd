/// HD Homes media domain models — metadata lives in Supabase `public.media`.

enum MediaStorageProvider { supabase, cloudinary }

enum MediaEntityType {
  library('library'),
  property('property'),
  estate('estate'),
  development('development'),
  construction('construction'),
  blog('blog'),
  marketing('marketing'),
  team('team'),
  partner('partner'),
  hero('hero'),
  banner('banner'),
  testimonial('testimonial'),
  office('office'),
  investment('investment'),
  marketInsight('market_insight'),
  careers('careers'),
  digitalProfile('digital_profile'),
  user('user'),
  inspection('inspection'),
  crm('crm');

  const MediaEntityType(this.value);
  final String value;

  static MediaEntityType? fromValue(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    // Back-compat aliases
    if (raw == 'estate') return MediaEntityType.estate;
    for (final t in MediaEntityType.values) {
      if (t.value == raw) return t;
    }
    return null;
  }
}

enum MediaResourceType { image, video, raw }

MediaResourceType resourceTypeFromMime(String mime) {
  if (mime.startsWith('video/')) return MediaResourceType.video;
  if (mime.startsWith('image/')) return MediaResourceType.image;
  return MediaResourceType.raw;
}

String resourceTypeSlug(MediaResourceType type) => switch (type) {
      MediaResourceType.image => 'image',
      MediaResourceType.video => 'video',
      MediaResourceType.raw => 'raw',
    };

/// Upload request — UI/controllers pass this to [MediaService].
class UploadMediaRequest {
  const UploadMediaRequest({
    required this.bytes,
    required this.contentType,
    required this.originalFilename,
    this.entityType = MediaEntityType.library,
    this.entityId,
    this.folder,
    this.role = 'gallery',
    this.title,
    this.altText,
    this.caption,
    this.sortOrder = 0,
    this.isCover = false,
    this.isPublished = true,
    this.folderName,
    this.onProgress,
  });

  final List<int> bytes;
  final String contentType;
  final String originalFilename;
  final MediaEntityType entityType;
  final String? entityId;
  final String? folder;
  /// Subfolder role slug: gallery, featured, avatar, progress, etc.
  final String role;
  final String? title;
  final String? altText;
  final String? caption;
  final int sortOrder;
  final bool isCover;
  final bool isPublished;
  final String? folderName;
  final void Function(double progress)? onProgress;

  MediaResourceType get resourceType => resourceTypeFromMime(contentType);
}

/// Signed upload parameters returned by Edge Function `cloudinary-sign`.
class CloudinarySignResponse {
  const CloudinarySignResponse({
    required this.cloudName,
    required this.apiKey,
    required this.timestamp,
    required this.signature,
    required this.folder,
    required this.resourceType,
    this.publicId,
    this.eager,
  });

  factory CloudinarySignResponse.fromJson(Map<String, dynamic> json) =>
      CloudinarySignResponse(
        cloudName: json['cloud_name'] as String,
        apiKey: json['api_key'] as String,
        timestamp: json['timestamp'] as int,
        signature: json['signature'] as String,
        folder: json['folder'] as String,
        resourceType: json['resource_type'] as String? ?? 'image',
        publicId: json['public_id'] as String?,
        eager: json['eager'] as String?,
      );

  final String cloudName;
  final String apiKey;
  final int timestamp;
  final String signature;
  final String folder;
  final String resourceType;
  final String? publicId;
  final String? eager;
}

/// Canonical media asset row (Supabase `public.media`).
class MediaAsset {
  const MediaAsset({
    required this.id,
    this.title,
    this.fileUrl = '',
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
    this.duration,
    this.tags = const [],
    this.status = 'active',
    this.createdAt,
    this.entityType,
    this.entityId,
    this.storageProvider = MediaStorageProvider.supabase,
    this.cloudinaryPublicId,
    this.resourceType,
    this.originalFilename,
    this.folder,
    this.sortOrder = 0,
    this.isCover = false,
    this.isPublished = true,
    this.isActive = true,
    this.uploadedBy,
  });

  factory MediaAsset.fromJson(Map<String, dynamic> json) {
    final providerRaw = json['storage_provider'] as String? ?? 'supabase';
    return MediaAsset(
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
      duration: (json['duration'] as num?)?.toDouble(),
      tags: _stringList(json['tags']),
      status: json['status'] as String? ?? 'active',
      createdAt: _date(json['created_at']),
      entityType: MediaEntityType.fromValue(json['entity_type'] as String?),
      entityId: json['entity_id']?.toString(),
      storageProvider: providerRaw == 'cloudinary'
          ? MediaStorageProvider.cloudinary
          : MediaStorageProvider.supabase,
      cloudinaryPublicId: json['cloudinary_public_id'] as String?,
      resourceType: json['resource_type'] as String?,
      originalFilename: json['original_filename'] as String?,
      folder: json['folder'] as String?,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isCover: json['is_cover'] as bool? ?? false,
      isPublished: json['is_published'] as bool? ?? true,
      isActive: json['is_active'] as bool? ?? true,
      uploadedBy: json['uploaded_by']?.toString(),
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
  final double? duration;
  final List<String> tags;
  final String status;
  final DateTime? createdAt;
  final MediaEntityType? entityType;
  final String? entityId;
  final MediaStorageProvider storageProvider;
  final String? cloudinaryPublicId;
  final String? resourceType;
  final String? originalFilename;
  final String? folder;
  final int sortOrder;
  final bool isCover;
  final bool isPublished;
  final bool isActive;
  final String? uploadedBy;

  /// Primary delivery URL — Cloudinary secure_url preferred, legacy file_url fallback.
  String get deliveryUrl {
    final secure = secureUrl?.trim();
    if (secure != null && secure.isNotEmpty) return secure;
    return fileUrl;
  }

  bool get isImage =>
      fileType == 'image' ||
      resourceType == 'image' ||
      (mimeType?.startsWith('image/') ?? false);

  bool get isVideo =>
      fileType == 'video' ||
      resourceType == 'video' ||
      (mimeType?.startsWith('video/') ?? false);

  String get displayTitle =>
      title?.isNotEmpty == true ? title! : (originalFilename ?? 'Untitled asset');

  static List<String> _stringList(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => '$e').where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }

  static DateTime? _date(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse('$raw');
  }
}

/// Cloudinary upload API response (subset).
class CloudinaryUploadResult {
  const CloudinaryUploadResult({
    required this.publicId,
    required this.secureUrl,
    required this.resourceType,
    this.format,
    this.width,
    this.height,
    this.duration,
    this.bytes,
    this.thumbnailUrl,
  });

  factory CloudinaryUploadResult.fromJson(Map<String, dynamic> json) =>
      CloudinaryUploadResult(
        publicId: json['public_id'] as String,
        secureUrl: json['secure_url'] as String,
        resourceType: json['resource_type'] as String? ?? 'image',
        format: json['format'] as String?,
        width: (json['width'] as num?)?.toInt(),
        height: (json['height'] as num?)?.toInt(),
        duration: (json['duration'] as num?)?.toDouble(),
        bytes: (json['bytes'] as num?)?.toInt(),
        thumbnailUrl: json['thumbnail_url'] as String?,
      );

  final String publicId;
  final String secureUrl;
  final String resourceType;
  final String? format;
  final int? width;
  final int? height;
  final double? duration;
  final int? bytes;
  final String? thumbnailUrl;
}
