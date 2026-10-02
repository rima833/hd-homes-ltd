/// Typed models for the production support configuration and ticket context.
library;

DateTime? _date(dynamic value) =>
    value is String ? DateTime.tryParse(value) : null;

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

class SupportCategory {
  const SupportCategory({
    required this.id,
    required this.slug,
    required this.name,
    this.description,
    this.sortOrder = 100,
    this.isActive = true,
  });

  final String id;
  final String slug;
  final String name;
  final String? description;
  final int sortOrder;
  final bool isActive;

  factory SupportCategory.fromJson(Map<String, dynamic> json) {
    return SupportCategory(
      id: json['id'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 100,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class SupportPropertyOption {
  const SupportPropertyOption({
    required this.id,
    required this.title,
    this.developmentName,
  });

  final String id;
  final String title;
  final String? developmentName;

  String get label => (developmentName ?? '').trim().isEmpty
      ? title
      : '$title · $developmentName';

  factory SupportPropertyOption.fromJson(Map<String, dynamic> json) {
    final estate = json['estate'];
    return SupportPropertyOption(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Property',
      developmentName: estate is Map ? estate['name'] as String? : null,
    );
  }
}

class LiveChatPropertyOption {
  const LiveChatPropertyOption({
    required this.id,
    required this.title,
    required this.subtitle,
    this.slug,
    this.imageUrl,
  });

  final String id;
  final String title;
  final String subtitle;
  final String? slug;
  final String? imageUrl;

  factory LiveChatPropertyOption.fromJson(Map<String, dynamic> json) {
    final beds = json['bedrooms'];
    final bedCount = beds is num ? beds.round() : int.tryParse('$beds');
    final city = (json['city'] as String?)?.trim() ?? '';
    final cityLabel = city.isEmpty
        ? ''
        : '${city[0].toUpperCase()}${city.substring(1)}';
    final parts = <String>[
      if (bedCount != null && bedCount > 0) '$bedCount-Bedroom',
      if (cityLabel.isNotEmpty) cityLabel,
    ];
    return LiveChatPropertyOption(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Property',
      subtitle: parts.join(' · '),
      slug: json['slug'] as String?,
      imageUrl: _coverImage(json['property_images']),
    );
  }

  static String? _coverImage(dynamic raw) {
    if (raw is! List) return null;
    final rows = raw
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .where((row) => row['is_deleted'] != true)
        .toList();
    rows.sort((a, b) {
      final cover =
          (a['is_cover'] == true ? 0 : 1) - (b['is_cover'] == true ? 0 : 1);
      if (cover != 0) return cover;
      final order = ((a['sort_order'] as num?) ?? 0).compareTo(
        (b['sort_order'] as num?) ?? 0,
      );
      return order;
    });
    if (rows.isEmpty) return null;
    final url = rows.first['url']?.toString().trim() ?? '';
    return url.isEmpty ? null : url;
  }
}

class SupportSettings {
  const SupportSettings({
    required this.id,
    this.timezone = 'Africa/Lagos',
    required this.welcomeMessage,
    required this.offlineMessage,
    this.businessHoursEnabled = true,
    this.offlineTicketEnabled = true,
    this.autoAssignmentEnabled = false,
    this.metadata = const {},
    this.updatedAt,
  });

  final String id;
  final String timezone;
  final String welcomeMessage;
  final String offlineMessage;
  final bool businessHoursEnabled;
  final bool offlineTicketEnabled;
  final bool autoAssignmentEnabled;
  final Map<String, dynamic> metadata;
  final DateTime? updatedAt;

  factory SupportSettings.fromJson(Map<String, dynamic> json) {
    return SupportSettings(
      id: json['id'] as String? ?? '',
      timezone: json['timezone'] as String? ?? 'Africa/Lagos',
      welcomeMessage: json['welcome_message'] as String? ?? '',
      offlineMessage: json['offline_message'] as String? ?? '',
      businessHoursEnabled: json['business_hours_enabled'] as bool? ?? true,
      offlineTicketEnabled: json['offline_ticket_enabled'] as bool? ?? true,
      autoAssignmentEnabled: json['auto_assignment_enabled'] as bool? ?? false,
      metadata: _map(json['metadata']),
      updatedAt: _date(json['updated_at']),
    );
  }

  Map<String, dynamic> toUpdateJson() => {
    'timezone': timezone,
    'welcome_message': welcomeMessage.trim(),
    'offline_message': offlineMessage.trim(),
    'business_hours_enabled': businessHoursEnabled,
    'offline_ticket_enabled': offlineTicketEnabled,
    'auto_assignment_enabled': autoAssignmentEnabled,
    'metadata': metadata,
  };

  SupportSettings copyWith({
    String? timezone,
    String? welcomeMessage,
    String? offlineMessage,
    bool? businessHoursEnabled,
    bool? offlineTicketEnabled,
    bool? autoAssignmentEnabled,
    Map<String, dynamic>? metadata,
  }) {
    return SupportSettings(
      id: id,
      timezone: timezone ?? this.timezone,
      welcomeMessage: welcomeMessage ?? this.welcomeMessage,
      offlineMessage: offlineMessage ?? this.offlineMessage,
      businessHoursEnabled: businessHoursEnabled ?? this.businessHoursEnabled,
      offlineTicketEnabled: offlineTicketEnabled ?? this.offlineTicketEnabled,
      autoAssignmentEnabled:
          autoAssignmentEnabled ?? this.autoAssignmentEnabled,
      metadata: metadata ?? this.metadata,
      updatedAt: updatedAt,
    );
  }
}

class SupportOperatingHour {
  const SupportOperatingHour({
    required this.id,
    required this.dayOfWeek,
    required this.isOpen,
    this.opensAt,
    this.closesAt,
  });

  final String id;
  final int dayOfWeek;
  final bool isOpen;
  final String? opensAt;
  final String? closesAt;

  factory SupportOperatingHour.fromJson(Map<String, dynamic> json) {
    return SupportOperatingHour(
      id: json['id'] as String? ?? '',
      dayOfWeek: (json['day_of_week'] as num?)?.toInt() ?? 0,
      isOpen: json['is_open'] as bool? ?? false,
      opensAt: json['opens_at'] as String?,
      closesAt: json['closes_at'] as String?,
    );
  }

  Map<String, dynamic> toUpsertJson() => {
    'day_of_week': dayOfWeek,
    'is_open': isOpen,
    'opens_at': isOpen ? opensAt : null,
    'closes_at': isOpen ? closesAt : null,
  };
}

class SupportHoliday {
  const SupportHoliday({
    required this.id,
    required this.date,
    required this.name,
    this.isClosed = true,
    this.opensAt,
    this.closesAt,
    this.metadata = const {},
  });

  final String id;
  final DateTime date;
  final String name;
  final bool isClosed;
  final String? opensAt;
  final String? closesAt;
  final Map<String, dynamic> metadata;

  factory SupportHoliday.fromJson(Map<String, dynamic> json) {
    return SupportHoliday(
      id: json['id'] as String? ?? '',
      date: _date(json['holiday_date']) ?? DateTime(1970),
      name: json['name'] as String? ?? '',
      isClosed: json['is_closed'] as bool? ?? true,
      opensAt: json['opens_at'] as String?,
      closesAt: json['closes_at'] as String?,
      metadata: _map(json['metadata']),
    );
  }
}

class SupportQuickReply {
  const SupportQuickReply({
    required this.id,
    required this.title,
    required this.shortcut,
    required this.body,
    this.categoryId,
    this.teamId,
    this.isActive = true,
    this.sortOrder = 100,
    this.metadata = const {},
  });

  final String id;
  final String title;
  final String shortcut;
  final String body;
  final String? categoryId;
  final String? teamId;
  final bool isActive;
  final int sortOrder;
  final Map<String, dynamic> metadata;

  factory SupportQuickReply.fromJson(Map<String, dynamic> json) {
    return SupportQuickReply(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      shortcut: json['shortcut'] as String? ?? '',
      body: json['body'] as String? ?? '',
      categoryId: json['category_id'] as String?,
      teamId: json['team_id'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 100,
      metadata: _map(json['metadata']),
    );
  }
}

class SupportAssignmentRule {
  const SupportAssignmentRule({
    required this.id,
    required this.name,
    this.rank = 100,
    this.isEnabled = false,
    this.categoryId,
    this.customerType,
    this.channel,
    this.priority,
    this.teamId,
    this.queueId,
    this.conditions = const {},
  });

  final String id;
  final String name;
  final int rank;
  final bool isEnabled;
  final String? categoryId;
  final String? customerType;
  final String? channel;
  final String? priority;
  final String? teamId;
  final String? queueId;
  final Map<String, dynamic> conditions;

  factory SupportAssignmentRule.fromJson(Map<String, dynamic> json) {
    return SupportAssignmentRule(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      rank: (json['rank'] as num?)?.toInt() ?? 100,
      isEnabled: json['is_enabled'] as bool? ?? false,
      categoryId: json['category_id'] as String?,
      customerType: json['customer_type'] as String?,
      channel: json['channel'] as String?,
      priority: json['priority'] as String?,
      teamId: json['team_id'] as String?,
      queueId: json['queue_id'] as String?,
      conditions: _map(json['conditions']),
    );
  }
}

class SupportTicketEvent {
  const SupportTicketEvent({
    required this.id,
    required this.ticketId,
    required this.action,
    this.actorId,
    this.actorLabel,
    this.fromStatus,
    this.toStatus,
    this.fromPriority,
    this.toPriority,
    this.isInternal = false,
    this.metadata = const {},
    this.createdAt,
  });

  final String id;
  final String ticketId;
  final String action;
  final String? actorId;
  final String? actorLabel;
  final String? fromStatus;
  final String? toStatus;
  final String? fromPriority;
  final String? toPriority;
  final bool isInternal;
  final Map<String, dynamic> metadata;
  final DateTime? createdAt;

  factory SupportTicketEvent.fromJson(Map<String, dynamic> json) {
    return SupportTicketEvent(
      id: json['id'] as String? ?? '',
      ticketId: json['ticket_id'] as String? ?? '',
      action: json['action'] as String? ?? '',
      actorId: json['actor_id'] as String?,
      actorLabel: json['actor_label'] as String?,
      fromStatus: json['from_status'] as String?,
      toStatus: json['to_status'] as String?,
      fromPriority: json['from_priority'] as String?,
      toPriority: json['to_priority'] as String?,
      isInternal: json['is_internal'] as bool? ?? false,
      metadata: _map(json['metadata']),
      createdAt: _date(json['created_at']),
    );
  }
}

class SupportTicketLink {
  const SupportTicketLink({
    required this.id,
    required this.ticketId,
    required this.entityType,
    required this.entityId,
    this.label,
    this.resourceUrl,
    this.metadata = const {},
  });

  final String id;
  final String ticketId;
  final String entityType;
  final String entityId;
  final String? label;
  final String? resourceUrl;
  final Map<String, dynamic> metadata;

  factory SupportTicketLink.fromJson(Map<String, dynamic> json) {
    return SupportTicketLink(
      id: json['id'] as String? ?? '',
      ticketId: json['ticket_id'] as String? ?? '',
      entityType: json['entity_type'] as String? ?? '',
      entityId: json['entity_id'] as String? ?? '',
      label: json['label'] as String?,
      resourceUrl: json['resource_url'] as String?,
      metadata: _map(json['metadata']),
    );
  }
}

class SupportConfigurationSnapshot {
  const SupportConfigurationSnapshot({
    required this.settings,
    this.hours = const [],
    this.holidays = const [],
    this.quickReplies = const [],
    this.assignmentRules = const [],
  });

  final SupportSettings settings;
  final List<SupportOperatingHour> hours;
  final List<SupportHoliday> holidays;
  final List<SupportQuickReply> quickReplies;
  final List<SupportAssignmentRule> assignmentRules;
}
