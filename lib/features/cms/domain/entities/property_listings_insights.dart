/// Live engagement + ops insights for the admin Property Listings dashboard.
class PropertyListingsInsights {
  const PropertyListingsInsights({
    this.byPropertyId = const {},
    this.inspections = const [],
    this.performance = const PropertyPerformanceBreakdown(),
  });

  final Map<String, PropertyEngagementStats> byPropertyId;
  final List<ListingsInspectionItem> inspections;
  final PropertyPerformanceBreakdown performance;

  PropertyEngagementStats statsFor(String propertyId) =>
      byPropertyId[propertyId] ?? const PropertyEngagementStats();
}

class PropertyEngagementStats {
  const PropertyEngagementStats({
    this.views = 0,
    this.inquiries = 0,
  });

  final int views;
  final int inquiries;

  PropertyEngagementStats merge(PropertyEngagementStats other) =>
      PropertyEngagementStats(
        views: views + other.views,
        inquiries: inquiries + other.inquiries,
      );
}

class ListingsInspectionItem {
  const ListingsInspectionItem({
    required this.id,
    required this.propertyId,
    required this.title,
    required this.scheduledAt,
    this.location = '',
    this.visitorName,
    this.status = 'scheduled',
  });

  final String id;
  final String propertyId;
  final String title;
  final DateTime scheduledAt;
  final String location;
  final String? visitorName;
  final String status;

  String get timeLabel {
    final h = scheduledAt.hour;
    final m = scheduledAt.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$hour12:$m $period';
  }

  String get subtitle {
    final loc = location.trim();
    if (loc.isEmpty) return timeLabel;
    return '$loc · $timeLabel';
  }
}

class PropertyPerformanceBreakdown {
  const PropertyPerformanceBreakdown({
    this.averageScore = 0,
    this.highCount = 0,
    this.averageCount = 0,
    this.lowCount = 0,
  });

  /// Mean performance score (0–100) shown in the donut center.
  final double averageScore;
  final int highCount;
  final int averageCount;
  final int lowCount;

  int get total => highCount + averageCount + lowCount;

  double get highShare => total == 0 ? 0 : highCount / total;
  double get averageShare => total == 0 ? 0 : averageCount / total;
  double get lowShare => total == 0 ? 0 : lowCount / total;
}
