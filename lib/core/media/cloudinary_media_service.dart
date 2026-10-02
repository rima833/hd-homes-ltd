import 'dart:convert';

import 'package:hdhomesproject/core/media/media_delivery.dart';
import 'package:hdhomesproject/core/media/media_folders.dart';
import 'package:hdhomesproject/core/media/media_models.dart';
import 'package:hdhomesproject/core/media/media_service.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Cloudinary-backed [MediaService]. Metadata always written to Supabase `media`.
class CloudinaryMediaService implements MediaService {
  CloudinaryMediaService(this._client);

  final SupabaseClient _client;

  static const _maxImageBytes = 15 * 1024 * 1024; // 15 MB
  static const _maxVideoBytes = 120 * 1024 * 1024; // 120 MB

  @override
  bool get isCloudinaryEnabled => true;

  @override
  Future<MediaAsset> uploadImage(UploadMediaRequest request) async {
    if (!request.contentType.startsWith('image/')) {
      throw ArgumentError('uploadImage requires an image MIME type.');
    }
    return upload(request);
  }

  @override
  Future<MediaAsset> uploadVideo(UploadMediaRequest request) async {
    if (!request.contentType.startsWith('video/')) {
      throw ArgumentError('uploadVideo requires a video MIME type.');
    }
    return upload(request);
  }

  @override
  Future<MediaAsset> upload(UploadMediaRequest request) async {
    _validateRequest(request);
    final folder = _resolveFolder(request);
    final resourceType = resourceTypeSlug(request.resourceType);

    final sign = await _signUpload(
      folder: folder,
      resourceType: resourceType,
      entityType: request.entityType.value,
      entityId: request.entityId,
    );

    request.onProgress?.call(0.15);
    final uploaded = await _uploadToCloudinary(
      request: request,
      sign: sign,
      resourceType: resourceType,
      onProgress: request.onProgress,
    );
    request.onProgress?.call(0.85);

    final asset = await _insertMediaRow(
      request: request,
      uploaded: uploaded,
      folder: folder,
    );

    if (request.isCover &&
        request.entityId != null &&
        request.entityId!.isNotEmpty) {
      await setCover(
        entityType: request.entityType,
        entityId: request.entityId!,
        mediaId: asset.id,
      );
    }

    request.onProgress?.call(1.0);
    return asset;
  }

  @override
  Future<MediaAsset> replace({
    required String mediaId,
    required UploadMediaRequest request,
  }) async {
    final existing = await getMedia(mediaId);
    if (existing == null) {
      throw StateError('Media asset not found.');
    }

    final sign = await _signReplace(
      mediaId: mediaId,
      oldPublicId: existing.cloudinaryPublicId,
      folder: existing.folder ?? _resolveFolder(request),
      resourceType: resourceTypeSlug(request.resourceType),
    );

    _validateRequest(request);
    final uploaded = await _uploadToCloudinary(
      request: request,
      sign: sign,
      resourceType: resourceTypeSlug(request.resourceType),
      onProgress: request.onProgress,
    );

    final row = await _client
        .from('media')
        .update({
          'title': request.title ?? request.originalFilename,
          'file_url': uploaded.secureUrl,
          'secure_url': uploaded.secureUrl,
          'thumbnail_url': uploaded.thumbnailUrl ??
              MediaDelivery.thumbnail(uploaded.secureUrl),
          'cloudinary_public_id': uploaded.publicId,
          'cloudinary_asset_id': uploaded.publicId,
          'resource_type': uploaded.resourceType,
          'format': uploaded.format,
          'mime_type': request.contentType,
          'file_size': uploaded.bytes ?? request.bytes.length,
          'width': uploaded.width,
          'height': uploaded.height,
          'duration': uploaded.duration,
          'original_filename': request.originalFilename,
          'storage_provider': 'cloudinary',
          'file_type': request.resourceType == MediaResourceType.video
              ? 'video'
              : 'image',
          if (request.caption != null) 'caption': request.caption,
          if (request.altText != null) 'alt_text': request.altText,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', mediaId)
        .select()
        .single();

    return MediaAsset.fromJson(Map<String, dynamic>.from(row));
  }

  @override
  Future<MediaAsset> replaceMedia({
    required String mediaId,
    required UploadMediaRequest request,
  }) =>
      replace(mediaId: mediaId, request: request);

  @override
  Future<void> delete(String mediaId, {bool hardDeleteCloudinary = true}) async {
    final existing = await getMedia(mediaId);
    if (existing == null) return;

    await _client.from('media').update({
      'is_deleted': true,
      'is_active': false,
      'deleted_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', mediaId);

    if (hardDeleteCloudinary &&
        existing.storageProvider == MediaStorageProvider.cloudinary &&
        existing.cloudinaryPublicId != null &&
        existing.cloudinaryPublicId!.isNotEmpty) {
      await _client.functions.invoke(
        'cloudinary-delete',
        body: {
          'public_id': existing.cloudinaryPublicId,
          'resource_type': existing.resourceType ?? 'image',
        },
      );
    }
  }

  @override
  Future<void> deleteMedia(String mediaId, {bool hardDeleteCloudinary = true}) =>
      delete(mediaId, hardDeleteCloudinary: hardDeleteCloudinary);

  @override
  Future<MediaAsset?> getMedia(String mediaId) async {
    final row = await _client
        .from('media_library')
        .select()
        .eq('id', mediaId)
        .maybeSingle();
    if (row == null) return null;
    return MediaAsset.fromJson(Map<String, dynamic>.from(row));
  }

  @override
  Future<Map<String, dynamic>> getMediaMetadata(String mediaId) async {
    final asset = await getMedia(mediaId);
    if (asset == null) {
      throw StateError('Media asset not found.');
    }
    return {
      'id': asset.id,
      'title': asset.title,
      'secure_url': asset.secureUrl,
      'file_url': asset.fileUrl,
      'delivery_url': asset.deliveryUrl,
      'thumbnail_url': asset.thumbnailUrl,
      'cloudinary_public_id': asset.cloudinaryPublicId,
      'resource_type': asset.resourceType,
      'width': asset.width,
      'height': asset.height,
      'duration': asset.duration,
      'file_size': asset.fileSize,
      'folder': asset.folder,
      'entity_type': asset.entityType?.value,
      'entity_id': asset.entityId,
      'storage_provider': asset.storageProvider.name,
      'is_cover': asset.isCover,
      'is_published': asset.isPublished,
      'alt_text': asset.altText,
    };
  }

  @override
  Future<List<MediaAsset>> getMediaForEntity({
    required MediaEntityType entityType,
    required String entityId,
  }) async {
    final rows = await _client
        .from('media_library')
        .select()
        .eq('entity_type', entityType.value)
        .eq('entity_id', entityId)
        .order('sort_order', ascending: true);
    return rows
        .map((e) => MediaAsset.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<void> reorder({
    required MediaEntityType entityType,
    required String entityId,
    required List<String> orderedMediaIds,
  }) async {
    await _client.rpc('reorder_entity_media', params: {
      'p_entity_type': entityType.value,
      'p_entity_id': entityId,
      'p_ordered_ids': orderedMediaIds,
    });
  }

  @override
  Future<void> setCover({
    required MediaEntityType entityType,
    required String entityId,
    required String mediaId,
  }) async {
    await _client.rpc('set_entity_cover_media', params: {
      'p_entity_type': entityType.value,
      'p_entity_id': entityId,
      'p_media_id': mediaId,
    });

    // Sync property_images / estate_images when applicable
    if (entityType == MediaEntityType.property) {
      await _client
          .from('property_images')
          .update({'is_cover': false, 'updated_at': _nowIso()})
          .eq('property_id', entityId)
          .eq('is_deleted', false);
      await _client
          .from('property_images')
          .update({'is_cover': true, 'updated_at': _nowIso()})
          .eq('media_id', mediaId);
    } else if (entityType == MediaEntityType.estate) {
      await _client
          .from('estate_images')
          .update({'is_cover': false, 'updated_at': _nowIso()})
          .eq('estate_id', entityId)
          .eq('is_deleted', false);
      await _client
          .from('estate_images')
          .update({'is_cover': true, 'updated_at': _nowIso()})
          .eq('media_id', mediaId);
    }
  }

  @override
  String getUrl(
    MediaAsset asset, {
    int? width,
    int? height,
    bool thumbnail = false,
  }) =>
      MediaDelivery.resolve(
        secureUrl: asset.secureUrl,
        fileUrl: asset.fileUrl,
        width: width,
        height: height,
        thumbnail: thumbnail,
      );

  @override
  String getThumbnail(MediaAsset asset, {int size = 400}) =>
      MediaDelivery.thumbnail(asset.deliveryUrl, size: size);

  @override
  String generateOptimizedUrl(
    MediaAsset asset, {
    int? width,
    int? height,
  }) =>
      MediaDelivery.resolve(
        secureUrl: asset.secureUrl,
        fileUrl: asset.fileUrl,
        width: width,
        height: height,
      );

  @override
  String generateThumbnail(MediaAsset asset, {int size = 400}) =>
      getThumbnail(asset, size: size);

  @override
  String generateResponsiveUrl(MediaAsset asset, {required int width}) =>
      MediaDelivery.resolve(
        secureUrl: asset.secureUrl,
        fileUrl: asset.fileUrl,
        width: width,
      );

  @override
  String generateVideoThumbnail(MediaAsset asset, {int width = 640}) {
    final base = asset.thumbnailUrl?.trim();
    if (base != null && base.isNotEmpty) {
      return MediaDelivery.resolve(secureUrl: base, fileUrl: base, width: width);
    }
    return MediaDelivery.transform(
      asset.deliveryUrl,
      width: width,
      height: (width * 9 / 16).round(),
    );
  }

  @override
  String resolveFolder({
    required MediaEntityType entityType,
    String? entityId,
    MediaFolderRole role = MediaFolderRole.gallery,
  }) =>
      MediaFolders.resolve(
        entityType: entityType,
        entityId: entityId,
        role: role,
      );

  @override
  Future<String> uploadAndGetUrl(UploadMediaRequest request) async {
    final asset = await upload(request);
    return asset.deliveryUrl;
  }

  @override
  Future<MediaAsset> migrateFromUrl({
    required String sourceUrl,
    required MediaEntityType entityType,
    String? entityId,
    String? mediaId,
    String role = 'gallery',
    MediaResourceType resourceType = MediaResourceType.image,
  }) async {
    final folder = MediaFolders.resolve(
      entityType: entityType,
      entityId: entityId,
      role: MediaFolderRoleSlug.fromSlug(role),
    );
    final response = await _client.functions.invoke(
      'cloudinary-migrate',
      body: {
        'source_url': sourceUrl,
        'folder': folder,
        'resource_type': resourceTypeSlug(resourceType),
        if (mediaId != null) 'media_id': mediaId,
      },
    );
    if (response.status != 200) {
      throw StateError(
        'Media migration failed (${response.status}): ${response.data}',
      );
    }
    final data = response.data;
    if (data is! Map) {
      throw StateError('Invalid migration response.');
    }
    final map = Map<String, dynamic>.from(data);
    final existingId = mediaId ?? map['media_id']?.toString();
    if (existingId != null && existingId.isNotEmpty) {
      final asset = await getMedia(existingId);
      if (asset != null) return asset;
    }

    final userId = _client.auth.currentUser?.id;
    final secureUrl = map['secure_url']?.toString() ?? '';
    final row = await _client
        .from('media')
        .insert({
          'title': 'Migrated media',
          'file_url': secureUrl,
          'secure_url': secureUrl,
          'thumbnail_url': map['thumbnail_url'],
          'file_type':
              resourceType == MediaResourceType.video ? 'video' : 'image',
          'entity_type': entityType.value,
          'entity_id': entityId,
          'storage_provider': 'cloudinary',
          'cloudinary_public_id': map['cloudinary_public_id'],
          'cloudinary_asset_id': map['cloudinary_asset_id'],
          'resource_type':
              map['resource_type'] ?? resourceTypeSlug(resourceType),
          'format': map['format'],
          'width': map['width'],
          'height': map['height'],
          'duration': map['duration'],
          'file_size': map['file_size'],
          'folder': folder,
          'is_published': true,
          'is_active': true,
          'uploaded_by': userId,
          'owner_id': userId,
          'created_by': userId,
        })
        .select()
        .single();
    return MediaAsset.fromJson(Map<String, dynamic>.from(row));
  }

  @override
  Future<String> uploadPublicWebsiteMedia({
    required List<int> bytes,
    required String contentType,
    required String originalFilename,
    String folder = 'hdhomes/general/website/inbox',
  }) async {
    final request = UploadMediaRequest(
      bytes: bytes,
      contentType: contentType,
      originalFilename: originalFilename,
      entityType: MediaEntityType.marketing,
      folder: folder,
      role: 'website',
    );
    _validateRequest(request);
    if (!folder.startsWith('hdhomes/general/website/') &&
        !folder.startsWith('hdhomes/inspections/') &&
        !folder.startsWith('hdhomes/crm/')) {
      throw ArgumentError('Public upload folder is not allowed: $folder');
    }
    final resourceType = resourceTypeSlug(request.resourceType);
    final response = await _client.functions.invoke(
      'cloudinary-sign-public',
      body: {
        'folder': folder,
        'resource_type': resourceType,
      },
    );
    if (response.status != 200) {
      throw StateError(
        'Public Cloudinary sign failed (${response.status}): ${response.data}',
      );
    }
    final data = response.data;
    if (data is! Map) {
      throw StateError('Invalid public sign response.');
    }
    final sign = CloudinarySignResponse.fromJson(Map<String, dynamic>.from(data));
    final uploaded = await _uploadToCloudinary(
      request: request,
      sign: sign,
      resourceType: resourceType,
    );

    // Best-effort metadata row (staff/authenticated only under RLS).
    try {
      await _insertMediaRow(
        request: request,
        uploaded: uploaded,
        folder: folder,
      );
    } catch (_) {}

    return uploaded.secureUrl;
  }

  // ── internals ──────────────────────────────────────────────────────────

  void _validateRequest(UploadMediaRequest request) {
    if (request.bytes.isEmpty) {
      throw ArgumentError('File is empty.');
    }
    final max = request.resourceType == MediaResourceType.video
        ? _maxVideoBytes
        : _maxImageBytes;
    if (request.bytes.length > max) {
      throw ArgumentError(
        'File exceeds maximum size (${(max / (1024 * 1024)).round()} MB).',
      );
    }
    // Image/video only — PDFs and other docs stay on private Supabase Storage.
    if (!request.contentType.startsWith('image/') &&
        !request.contentType.startsWith('video/')) {
      throw ArgumentError(
        'Unsupported media type: ${request.contentType}. '
        'Only image/* and video/* are stored on Cloudinary.',
      );
    }
  }

  String _resolveFolder(UploadMediaRequest request) =>
      MediaFolders.resolveFromRequest(request);

  Future<CloudinarySignResponse> _signUpload({
    required String folder,
    required String resourceType,
    required String entityType,
    String? entityId,
  }) async {
    final response = await _client.functions.invoke(
      'cloudinary-sign',
      body: {
        'folder': folder,
        'resource_type': resourceType,
        'entity_type': entityType,
        if (entityId != null) 'entity_id': entityId,
      },
    );
    if (response.status != 200) {
      throw StateError(
        'Cloudinary sign failed (${response.status}): ${response.data}',
      );
    }
    final data = response.data;
    if (data is! Map) {
      throw StateError('Invalid sign response.');
    }
    return CloudinarySignResponse.fromJson(Map<String, dynamic>.from(data));
  }

  Future<CloudinarySignResponse> _signReplace({
    required String mediaId,
    required String? oldPublicId,
    required String folder,
    required String resourceType,
  }) async {
    final response = await _client.functions.invoke(
      'cloudinary-replace',
      body: {
        'media_id': mediaId,
        'old_public_id': oldPublicId,
        'folder': folder,
        'resource_type': resourceType,
      },
    );
    if (response.status != 200) {
      throw StateError(
        'Cloudinary replace sign failed (${response.status}): ${response.data}',
      );
    }
    final data = response.data;
    if (data is! Map) {
      throw StateError('Invalid replace sign response.');
    }
    return CloudinarySignResponse.fromJson(Map<String, dynamic>.from(data));
  }

  Future<CloudinaryUploadResult> _uploadToCloudinary({
    required UploadMediaRequest request,
    required CloudinarySignResponse sign,
    required String resourceType,
    void Function(double progress)? onProgress,
  }) async {
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/${sign.cloudName}/$resourceType/upload',
    );
    final multipart = http.MultipartRequest('POST', uri)
      ..fields['api_key'] = sign.apiKey
      ..fields['timestamp'] = '${sign.timestamp}'
      ..fields['signature'] = sign.signature
      ..fields['folder'] = sign.folder;
    if (sign.publicId != null) {
      multipart.fields['public_id'] = sign.publicId!;
    }
    if (sign.eager != null) {
      multipart.fields['eager'] = sign.eager!;
    }

    multipart.files.add(
      http.MultipartFile.fromBytes(
        'file',
        request.bytes,
        filename: request.originalFilename,
      ),
    );

    onProgress?.call(divProgress(0.2, 0.75, 0.5));
    final streamed = await multipart.send();
    onProgress?.call(divProgress(0.2, 0.75, 0.9));
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw StateError('Cloudinary upload failed (${streamed.statusCode}): $body');
    }

    final json = jsonDecode(body);
    if (json is! Map<String, dynamic>) {
      throw StateError('Invalid Cloudinary upload response.');
    }
    return CloudinaryUploadResult.fromJson(json);
  }

  double divProgress(double start, double end, double t) => start + (end - start) * t;

  Future<MediaAsset> _insertMediaRow({
    required UploadMediaRequest request,
    required CloudinaryUploadResult uploaded,
    required String folder,
  }) async {
    String? folderId;
    final folderName = request.folderName;
    if (folderName != null && folderName.trim().isNotEmpty) {
      folderId = await _ensureFolderId(folderName.trim());
    }

    final userId = _client.auth.currentUser?.id;
    final size = uploaded.bytes ?? request.bytes.length;
    if (uploaded.width != null && uploaded.height != null && size > 0) {
      final existing = await _client
          .from('media')
          .select()
          .eq('is_deleted', false)
          .eq('file_size', size)
          .eq('width', uploaded.width!)
          .eq('height', uploaded.height!)
          .limit(1)
          .maybeSingle();
      if (existing != null) {
        try {
          await _client.functions.invoke(
            'cloudinary-delete',
            body: {
              'public_id': uploaded.publicId,
              'resource_type': uploaded.resourceType,
            },
          );
        } catch (_) {}
        return MediaAsset.fromJson(Map<String, dynamic>.from(existing));
      }
    }
    final thumbnail = uploaded.thumbnailUrl ??
        (uploaded.resourceType == 'video'
            ? MediaDelivery.transform(uploaded.secureUrl, width: 640, height: 360)
            : MediaDelivery.thumbnail(uploaded.secureUrl));

    final row = await _client
        .from('media')
        .insert({
          'title': request.title ?? request.originalFilename,
          'file_url': uploaded.secureUrl,
          'secure_url': uploaded.secureUrl,
          'thumbnail_url': thumbnail,
          'file_type': request.resourceType == MediaResourceType.video
              ? 'video'
              : 'image',
          'mime_type': request.contentType,
          'file_size': uploaded.bytes ?? request.bytes.length,
          'alt_text': request.altText,
          if (request.caption != null) 'caption': request.caption,
          'folder_id': folderId,
          'width': uploaded.width,
          'height': uploaded.height,
          'duration': uploaded.duration,
          'entity_type': request.entityType.value,
          'entity_id': request.entityId,
          'storage_provider': 'cloudinary',
          'cloudinary_public_id': uploaded.publicId,
          'cloudinary_asset_id': uploaded.publicId,
          'resource_type': uploaded.resourceType,
          'format': uploaded.format,
          'original_filename': request.originalFilename,
          'folder': folder,
          'sort_order': request.sortOrder,
          'is_cover': request.isCover,
          'is_primary': request.isCover,
          'is_published': request.isPublished,
          'is_active': true,
          'uploaded_by': userId,
          'owner_id': userId,
          'created_by': userId,
          'updated_by': userId,
        })
        .select()
        .single();

    return MediaAsset.fromJson(Map<String, dynamic>.from(row));
  }

  Future<String?> _ensureFolderId(String folderName) async {
    final slug = folderName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    final existing = await _client
        .from('media_folders')
        .select('id')
        .eq('slug', slug)
        .maybeSingle();
    if (existing != null) return existing['id'] as String;
    final created = await _client
        .from('media_folders')
        .insert({'name': folderName, 'slug': slug})
        .select('id')
        .single();
    return created['id'] as String;
  }

  @override
  Future<void> updateMediaMetadata({
    required String mediaId,
    String? title,
    String? altText,
    String? caption,
    bool? isPublished,
    bool? isActive,
    int? sortOrder,
  }) async {
    final payload = <String, dynamic>{
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      if (title != null) 'title': title,
      if (altText != null) 'alt_text': altText,
      if (caption != null) 'caption': caption,
      if (isPublished != null) 'is_published': isPublished,
      if (isActive != null) 'is_active': isActive,
      if (sortOrder != null) 'sort_order': sortOrder,
    };
    if (payload.length <= 1) return;
    await _client.from('media').update(payload).eq('id', mediaId);
  }

  String _nowIso() => DateTime.now().toUtc().toIso8601String();
}
