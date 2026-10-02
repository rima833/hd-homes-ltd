import 'package:hdhomesproject/core/media/media_folders.dart';
import 'package:hdhomesproject/core/media/media_models.dart';

/// Central media abstraction — UI must never call Cloudinary directly.
abstract class MediaService {
  bool get isCloudinaryEnabled;

  Future<MediaAsset> upload(UploadMediaRequest request);

  Future<MediaAsset> uploadImage(UploadMediaRequest request);

  Future<MediaAsset> uploadVideo(UploadMediaRequest request);

  Future<MediaAsset> replace({
    required String mediaId,
    required UploadMediaRequest request,
  });

  Future<MediaAsset> replaceMedia({
    required String mediaId,
    required UploadMediaRequest request,
  });

  Future<void> delete(String mediaId, {bool hardDeleteCloudinary = true});

  Future<void> deleteMedia(String mediaId, {bool hardDeleteCloudinary = true});

  Future<MediaAsset?> getMedia(String mediaId);

  Future<Map<String, dynamic>> getMediaMetadata(String mediaId);

  Future<List<MediaAsset>> getMediaForEntity({
    required MediaEntityType entityType,
    required String entityId,
  });

  Future<void> reorder({
    required MediaEntityType entityType,
    required String entityId,
    required List<String> orderedMediaIds,
  });

  Future<void> setCover({
    required MediaEntityType entityType,
    required String entityId,
    required String mediaId,
  });

  Future<void> updateMediaMetadata({
    required String mediaId,
    String? title,
    String? altText,
    String? caption,
    bool? isPublished,
    bool? isActive,
    int? sortOrder,
  });

  String getUrl(
    MediaAsset asset, {
    int? width,
    int? height,
    bool thumbnail = false,
  });

  String getThumbnail(MediaAsset asset, {int size = 400});

  String generateOptimizedUrl(
    MediaAsset asset, {
    int? width,
    int? height,
  });

  String generateThumbnail(MediaAsset asset, {int size = 400});

  String generateResponsiveUrl(MediaAsset asset, {required int width});

  String generateVideoThumbnail(MediaAsset asset, {int width = 640});

  String resolveFolder({
    required MediaEntityType entityType,
    String? entityId,
    MediaFolderRole role = MediaFolderRole.gallery,
  });

  Future<String> uploadAndGetUrl(UploadMediaRequest request);

  /// Import a remote image/video URL into Cloudinary (staff-only Edge Function).
  /// Does not delete the source. Optionally updates an existing media row.
  Future<MediaAsset> migrateFromUrl({
    required String sourceUrl,
    required MediaEntityType entityType,
    String? entityId,
    String? mediaId,
    String role = 'gallery',
    MediaResourceType resourceType = MediaResourceType.image,
  });

  /// Public website image/video upload (anon-safe Edge Function).
  /// Restricted to `hdhomes/general/website|inspections|crm` folders.
  /// Returns the Cloudinary secure URL (may not create a media row for anon).
  Future<String> uploadPublicWebsiteMedia({
    required List<int> bytes,
    required String contentType,
    required String originalFilename,
    String folder = 'hdhomes/general/website/inbox',
  });
}
