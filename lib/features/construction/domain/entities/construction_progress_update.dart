import 'package:hdhomesproject/features/construction/domain/entities/construction_update_media.dart';

class ConstructionProgressUpdate {
  const ConstructionProgressUpdate({
    required this.id,
    required this.projectId,
    required this.title,
    this.shortDescription,
    this.description,
    this.progressPct,
    this.updateDate,
    this.status = 'draft',
    this.visibility = const ['internal'],
    this.isPublished = false,
    this.publishedAt,
    this.media = const [],
    this.phaseId,
    this.milestoneId,
  });

  final String id;
  final String projectId;
  final String title;
  final String? shortDescription;
  final String? description;
  final double? progressPct;
  final DateTime? updateDate;
  final String status;
  final List<String> visibility;
  final bool isPublished;
  final DateTime? publishedAt;
  final List<ConstructionUpdateMedia> media;
  final String? phaseId;
  final String? milestoneId;

  factory ConstructionProgressUpdate.fromJson(Map<String, dynamic> json) {
    final vis = json['visibility'];
    final visibility = <String>[];
    if (vis is List) {
      for (final v in vis) {
        final s = '$v'.trim();
        if (s.isNotEmpty) visibility.add(s);
      }
    }
    final mediaRaw = json['construction_update_media'] as List? ?? [];
    return ConstructionProgressUpdate(
      id: json['id'] as String,
      projectId: json['project_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      shortDescription: json['short_description'] as String?,
      description: json['description'] as String?,
      progressPct: (json['progress_pct'] as num?)?.toDouble(),
      updateDate: DateTime.tryParse(json['update_date'] as String? ?? ''),
      status: json['status'] as String? ?? 'draft',
      visibility: visibility,
      isPublished: json['is_published'] as bool? ?? false,
      publishedAt: DateTime.tryParse(json['published_at'] as String? ?? ''),
      phaseId: json['phase_id'] as String?,
      milestoneId: json['milestone_id'] as String?,
      media: mediaRaw
          .map((e) => ConstructionUpdateMedia.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList(),
    );
  }
}
