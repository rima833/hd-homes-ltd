import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';

/// Structured weekly hours for one office (0 = Monday … 6 = Sunday).
class OfficeHourEntry {
  const OfficeHourEntry({
    required this.id,
    required this.officeId,
    required this.dayOfWeek,
    required this.isOpen,
    required this.openTime,
    required this.closeTime,
  });

  factory OfficeHourEntry.fromJson(Map<String, dynamic> json) => OfficeHourEntry(
        id: '${json['id']}',
        officeId: '${json['office_id']}',
        dayOfWeek: (json['day_of_week'] as num?)?.toInt() ?? 0,
        isOpen: json['is_open'] as bool? ?? true,
        openTime: _parseTime(json['open_time']),
        closeTime: _parseTime(json['close_time']),
      );

  static String _parseTime(dynamic raw) {
    if (raw == null) return '08:00';
    final s = '$raw';
    if (s.length >= 5) return s.substring(0, 5);
    return s;
  }

  final String id;
  final String officeId;
  final int dayOfWeek;
  final bool isOpen;
  final String openTime;
  final String closeTime;
}

class OfficeMediaEntry {
  const OfficeMediaEntry({
    required this.id,
    required this.officeId,
    required this.mediaType,
    required this.storagePath,
    this.sortOrder = 0,
    this.isCover = false,
  });

  factory OfficeMediaEntry.fromJson(Map<String, dynamic> json) => OfficeMediaEntry(
        id: '${json['id']}',
        officeId: '${json['office_id']}',
        mediaType: json['media_type'] as String? ?? 'image',
        storagePath: json['storage_path'] as String? ?? '',
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
        isCover: json['is_cover'] as bool? ?? false,
      );

  final String id;
  final String officeId;
  final String mediaType;
  final String storagePath;
  final int sortOrder;
  final bool isCover;
}

/// Public office directory record with hours + media.
class OfficeDirectoryEntry {
  const OfficeDirectoryEntry({
    required this.location,
    this.hours = const [],
    this.media = const [],
  });

  final CmsOfficeLocation location;
  final List<OfficeHourEntry> hours;
  final List<OfficeMediaEntry> media;

  List<String> get galleryUrls {
    final urls = <String>[];
    if (location.coverImage != null && location.coverImage!.trim().isNotEmpty) {
      urls.add(location.coverImage!.trim());
    }
    for (final m in media) {
      if (m.mediaType == 'image' && m.storagePath.trim().isNotEmpty) {
        if (!urls.contains(m.storagePath)) urls.add(m.storagePath);
      }
    }
    return urls;
  }

  List<String> get landmarks {
    return location.nearbyLandmarks;
  }

  String get displayCity {
    if (location.city.trim().isNotEmpty) return location.city.trim();
    final parts = location.address.split(',');
    return parts.length > 1 ? parts.last.trim() : location.address;
  }

  String get typeLabel => location.officeType;

  bool get hasCoordinates =>
      location.latitude != null && location.longitude != null;
}

/// Computed open/closed status (Africa/Lagos).
enum OfficeLiveStatus { open, closingSoon, closed, opensLater }

class OfficeStatusSnapshot {
  const OfficeStatusSnapshot({
    required this.status,
    required this.label,
    required this.detail,
  });

  final OfficeLiveStatus status;
  final String label;
  final String detail;
}
