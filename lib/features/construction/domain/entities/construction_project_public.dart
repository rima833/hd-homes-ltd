import 'package:hdhomesproject/features/construction/domain/entities/construction_progress_update.dart';

enum ConstructionScheduleStatus {
  onTrack,
  ahead,
  atRisk,
  delayed;

  static ConstructionScheduleStatus fromSlug(String? raw) => switch (raw) {
        'ahead' => ConstructionScheduleStatus.ahead,
        'at_risk' => ConstructionScheduleStatus.atRisk,
        'delayed' => ConstructionScheduleStatus.delayed,
        _ => ConstructionScheduleStatus.onTrack,
      };

  String get slug => switch (this) {
        ConstructionScheduleStatus.onTrack => 'on_track',
        ConstructionScheduleStatus.ahead => 'ahead',
        ConstructionScheduleStatus.atRisk => 'at_risk',
        ConstructionScheduleStatus.delayed => 'delayed',
      };

  String get label => switch (this) {
        ConstructionScheduleStatus.onTrack => 'ON SCHEDULE',
        ConstructionScheduleStatus.ahead => 'AHEAD OF SCHEDULE',
        ConstructionScheduleStatus.atRisk => 'AT RISK',
        ConstructionScheduleStatus.delayed => 'DELAYED',
      };
}

class ConstructionMilestonePublic {
  const ConstructionMilestonePublic({
    required this.id,
    required this.name,
    this.status = 'planned',
    this.progressPct = 0,
    this.dueDate,
    this.completedAt,
  });

  final String id;
  final String name;
  final String status;
  final double progressPct;
  final DateTime? dueDate;
  final DateTime? completedAt;

  bool get isCompleted => status == 'completed' || progressPct >= 100;
  bool get isActive => status == 'in_progress' && !isCompleted;

  factory ConstructionMilestonePublic.fromJson(Map<String, dynamic> json) {
    return ConstructionMilestonePublic(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      status: json['status'] as String? ?? 'planned',
      progressPct: (json['progress_pct'] as num?)?.toDouble() ?? 0,
      dueDate: DateTime.tryParse(json['due_date'] as String? ?? ''),
      completedAt: DateTime.tryParse(json['completed_at'] as String? ?? ''),
    );
  }
}

class ConstructionProjectPublic {
  const ConstructionProjectPublic({
    required this.id,
    required this.name,
    required this.slug,
    this.locationLabel,
    this.description,
    this.progressPct = 0,
    this.coverImageUrl,
    this.galleryImageUrls = const [],
    this.expectedCompletionLabel,
    this.statusUpdate,
    this.scheduleStatus = ConstructionScheduleStatus.onTrack,
    this.isFeatured = false,
    this.milestones = const [],
    this.latestUpdates = const [],
    this.updatedAt,
  });

  final String id;
  final String name;
  final String slug;
  final String? locationLabel;
  final String? description;
  final double progressPct;
  final String? coverImageUrl;
  final List<String> galleryImageUrls;
  final String? expectedCompletionLabel;
  final String? statusUpdate;
  final ConstructionScheduleStatus scheduleStatus;
  final bool isFeatured;
  final List<ConstructionMilestonePublic> milestones;
  final List<ConstructionProgressUpdate> latestUpdates;
  final DateTime? updatedAt;

  String get detailPath => '/construction/$slug';

  double get progressFraction => (progressPct / 100).clamp(0.0, 1.0);

  List<String> get allImageUrls {
    final urls = <String>[];
    final cover = coverImageUrl?.trim();
    if (cover != null && cover.isNotEmpty) urls.add(cover);
    for (final url in galleryImageUrls) {
      final t = url.trim();
      if (t.isNotEmpty && !urls.contains(t)) urls.add(t);
    }
    for (final u in latestUpdates) {
      for (final m in u.media) {
        if (m.deliveryUrl.trim().isNotEmpty && !urls.contains(m.deliveryUrl)) {
          urls.add(m.deliveryUrl);
        }
      }
    }
    return urls;
  }

  int get activeMilestoneIndex {
    if (milestones.isEmpty) {
      return (progressPct / (100 / 6)).floor().clamp(0, 5);
    }
    for (var i = milestones.length - 1; i >= 0; i--) {
      if (milestones[i].isCompleted) return i.clamp(0, milestones.length - 1);
      if (milestones[i].isActive) return i;
    }
    return 0;
  }

  List<String> get phaseLabels =>
      milestones.isEmpty
          ? const [
              'Planning',
              'Foundation',
              'Structure',
              'Roofing',
              'Finishing',
              'Completed',
            ]
          : milestones.map((m) => m.name).toList();

  factory ConstructionProjectPublic.fromConstructionProjectRow(
    Map<String, dynamic> json, {
    List<ConstructionMilestonePublic> milestones = const [],
    List<ConstructionProgressUpdate> updates = const [],
  }) {
    final slug = json['slug'] as String? ??
        (json['project_code'] as String? ?? json['name'] as String? ?? '')
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return ConstructionProjectPublic(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Project',
      slug: slug,
      locationLabel: json['location_label'] as String?,
      description: json['description'] as String?,
      progressPct: (json['progress_pct'] as num?)?.toDouble() ?? 0,
      coverImageUrl: json['cover_image_url'] as String?,
      expectedCompletionLabel: json['target_end_date'] != null
          ? _formatQuarter(DateTime.tryParse(json['target_end_date'] as String))
          : null,
      statusUpdate: updates.isNotEmpty
          ? (updates.first.shortDescription?.trim().isNotEmpty == true
              ? updates.first.shortDescription
              : updates.first.title)
          : null,
      scheduleStatus:
          ConstructionScheduleStatus.fromSlug(json['schedule_status'] as String?),
      isFeatured: json['is_featured'] as bool? ?? false,
      milestones: milestones,
      latestUpdates: updates,
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
    );
  }

  factory ConstructionProjectPublic.fromWebsiteRow(Map<String, dynamic> json) {
    final phasesRaw = json['phases'];
    final milestones = <ConstructionMilestonePublic>[];
    if (phasesRaw is List) {
      final current = (json['current_phase_index'] as num? ?? 0).toInt();
      final overall = (json['progress_pct'] as num?)?.toDouble() ?? 0;
      for (var i = 0; i < phasesRaw.length; i++) {
        milestones.add(
          ConstructionMilestonePublic(
            id: 'phase-$i',
            name: '${phasesRaw[i]}',
            progressPct: i < current
                ? 100
                : (i == current ? overall : 0),
            status: i < current
                ? 'completed'
                : (i == current ? 'in_progress' : 'planned'),
          ),
        );
      }
    }
    final galleryRaw = json['gallery_image_urls'];
    final gallery = <String>[];
    if (galleryRaw is List) {
      for (final e in galleryRaw) {
        final s = '$e'.trim();
        if (s.isNotEmpty) gallery.add(s);
      }
    }
    return ConstructionProjectPublic(
      id: json['id'] as String,
      name: json['project_name'] as String? ?? 'Project',
      slug: json['slug'] as String? ?? '',
      progressPct: (json['progress_pct'] as num?)?.toDouble() ?? 0,
      coverImageUrl: json['cover_image_url'] as String?,
      galleryImageUrls: gallery,
      expectedCompletionLabel: json['expected_completion'] as String?,
      statusUpdate: json['status_update'] as String?,
      milestones: milestones,
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
    );
  }

  static String? _formatQuarter(DateTime? d) {
    if (d == null) return null;
    final q = ((d.month - 1) ~/ 3) + 1;
    return 'Q$q ${d.year}';
  }
}
