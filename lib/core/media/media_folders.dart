import 'package:hdhomesproject/core/config/cloudinary_config.dart';
import 'package:hdhomesproject/core/media/media_models.dart';

/// Gallery subfolder roles under `hdhomes/{domain}/{id}/{role}/`.
enum MediaFolderRole {
  gallery,
  floorplans,
  documentsPreview,
  marketing,
  progress,
  milestones,
  site,
  featured,
  content,
  avatar,
  property,
  evidence,
  campaigns,
  banners,
  social,
  website,
  branding,
}

extension MediaFolderRoleSlug on MediaFolderRole {
  String get slug => switch (this) {
        MediaFolderRole.documentsPreview => 'documents-preview',
        _ => name,
      };

  static MediaFolderRole fromSlug(String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    if (v.isEmpty || v == 'gallery') return MediaFolderRole.gallery;
    if (v == 'documents-preview' || v == 'documents_preview') {
      return MediaFolderRole.documentsPreview;
    }
    for (final role in MediaFolderRole.values) {
      if (role.name == v || role.slug == v) return role;
    }
    return MediaFolderRole.gallery;
  }
}

/// Canonical Cloudinary folder paths for HD Homes.
abstract final class MediaFolders {
  static String get root => CloudinaryConfig.uploadFolderRoot;

  static String resolve({
    required MediaEntityType entityType,
    String? entityId,
    MediaFolderRole role = MediaFolderRole.gallery,
  }) {
    final id = (entityId ?? '').trim();
    final domain = _domain(entityType);
    final roleSlug = role.slug;
    if (id.isEmpty) return '$root/$domain/$roleSlug';
    return '$root/$domain/$id/$roleSlug';
  }

  static String resolveFromRequest(UploadMediaRequest request) {
    final explicit = request.folder?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    return resolve(
      entityType: request.entityType,
      entityId: request.entityId,
      role: MediaFolderRoleSlug.fromSlug(request.role),
    );
  }

  static String forEntity({
    required MediaEntityType entityType,
    String? entityId,
    String? role,
  }) =>
      resolve(
        entityType: entityType,
        entityId: entityId,
        role: MediaFolderRoleSlug.fromSlug(role),
      );

  static String _domain(MediaEntityType type) => switch (type) {
        MediaEntityType.property => 'properties',
        MediaEntityType.estate || MediaEntityType.development => 'developments',
        MediaEntityType.construction => 'construction',
        MediaEntityType.blog => 'blog',
        MediaEntityType.user || MediaEntityType.team => 'users',
        MediaEntityType.inspection => 'inspections',
        MediaEntityType.crm => 'crm',
        MediaEntityType.hero ||
        MediaEntityType.banner ||
        MediaEntityType.marketing ||
        MediaEntityType.partner ||
        MediaEntityType.testimonial ||
        MediaEntityType.marketInsight =>
          'marketing',
        MediaEntityType.library ||
        MediaEntityType.office ||
        MediaEntityType.careers ||
        MediaEntityType.digitalProfile =>
          'general',
        MediaEntityType.investment => 'developments',
      };
}
