/// Typed analytics event catalog for the Growth Engine.
enum AnalyticsEventType {
  pageView,
  propertyView,
  search,
  leadSubmitted,
  download,
  booking,
  chatMessage,
  newsletterSubscribe,
  referralClick,
  abTestExposure,
  custom,
}

class AnalyticsEvent {
  const AnalyticsEvent({
    required this.type,
    required this.name,
    required this.timestamp,
    this.path,
    this.entityId,
    this.properties = const {},
    this.utmSource,
    this.utmCampaign,
  });

  final AnalyticsEventType type;
  final String name;
  final DateTime timestamp;
  final String? path;
  final String? entityId;
  final Map<String, dynamic> properties;
  final String? utmSource;
  final String? utmCampaign;

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'name': name,
        'timestamp': timestamp.toIso8601String(),
        if (path != null) 'path': path,
        if (entityId != null) 'entityId': entityId,
        if (properties.isNotEmpty) 'properties': properties,
        if (utmSource != null) 'utmSource': utmSource,
        if (utmCampaign != null) 'utmCampaign': utmCampaign,
      };
}
