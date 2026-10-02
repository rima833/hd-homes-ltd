import 'package:hdhomesproject/core/media/media_delivery.dart';

class ConstructionUpdateMedia {
  const ConstructionUpdateMedia({
    required this.id,
    required this.updateId,
    required this.projectId,
    required this.fileUrl,
    this.mediaType = 'image',
    this.thumbnailUrl,
    this.secureUrl,
    this.caption,
    this.displayOrder = 0,
  });

  final String id;
  final String updateId;
  final String projectId;
  final String fileUrl;
  final String mediaType;
  final String? thumbnailUrl;
  final String? secureUrl;
  final String? caption;
  final int displayOrder;

  factory ConstructionUpdateMedia.fromJson(Map<String, dynamic> json) {
    final media = json['media'];
    String? secure;
    if (media is Map) {
      secure = media['secure_url'] as String?;
    }
    return ConstructionUpdateMedia(
      id: json['id'] as String,
      updateId: json['update_id'] as String? ?? '',
      projectId: json['project_id'] as String? ?? '',
      fileUrl: json['file_url'] as String? ?? '',
      mediaType: json['media_type'] as String? ?? 'image',
      thumbnailUrl: json['thumbnail_url'] as String?,
      secureUrl: secure,
      caption: json['caption'] as String?,
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
    );
  }

  String get deliveryUrl {
    final resolved = MediaDelivery.resolve(
      secureUrl: secureUrl,
      fileUrl: fileUrl,
      thumbnail: mediaType != 'video',
    );
    return resolved.isEmpty ? fileUrl : resolved;
  }

  String? get deliveryThumbnail {
    final thumb = thumbnailUrl?.trim();
    if (thumb != null && thumb.isNotEmpty) return thumb;
    return deliveryUrl;
  }
}
