class AdminInspectionRow {
  const AdminInspectionRow({
    required this.id,
    required this.propertyId,
    required this.status,
    required this.scheduledAt,
    required this.inspectionType,
    this.reference,
    this.visitorName,
    this.visitorEmail,
    this.visitorPhone,
    this.propertyTitle,
    this.estateId,
    this.advisorId,
    this.preferredLanguage,
    this.meetingUrl,
    this.reportPayload,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String propertyId;
  final String status;
  final DateTime scheduledAt;
  final String inspectionType;
  final String? reference;
  final String? visitorName;
  final String? visitorEmail;
  final String? visitorPhone;
  final String? propertyTitle;
  final String? estateId;
  final String? advisorId;
  final String? preferredLanguage;
  final String? meetingUrl;
  final Map<String, dynamic>? reportPayload;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory AdminInspectionRow.fromJson(Map<String, dynamic> json) {
    final props = json['properties'];
    String? title;
    if (props is Map) {
      title = props['title'] as String?;
    }
    Map<String, dynamic>? payload;
    final rawPayload = json['report_payload'];
    if (rawPayload is Map) {
      payload = Map<String, dynamic>.from(rawPayload);
    }
    return AdminInspectionRow(
      id: '${json['id']}',
      propertyId: '${json['property_id']}',
      status: '${json['status'] ?? 'scheduled'}',
      scheduledAt: DateTime.parse('${json['scheduled_at']}'),
      inspectionType: '${json['inspection_type'] ?? 'site_visit'}',
      reference: json['reference'] as String?,
      visitorName: json['visitor_name'] as String?,
      visitorEmail: json['visitor_email'] as String?,
      visitorPhone: json['visitor_phone'] as String?,
      propertyTitle: title,
      estateId: json['estate_id']?.toString(),
      advisorId: json['advisor_id']?.toString(),
      preferredLanguage: json['preferred_language'] as String?,
      meetingUrl: json['meeting_url'] as String?,
      reportPayload: payload,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse('${json['created_at']}')
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse('${json['updated_at']}')
          : null,
    );
  }
}

class AdminInspectionStats {
  const AdminInspectionStats({
    this.total = 0,
    this.today = 0,
    this.upcoming = 0,
    this.scheduled = 0,
    this.confirmed = 0,
    this.completed = 0,
    this.cancelled = 0,
    this.noShow = 0,
  });

  final int total;
  final int today;
  final int upcoming;
  final int scheduled;
  final int confirmed;
  final int completed;
  final int cancelled;
  final int noShow;
}

class InspectionSettingsRow {
  const InspectionSettingsRow({
    required this.id,
    this.slotDurationMinutes = 60,
    this.bufferMinutes = 15,
    this.minNoticeHours = 24,
    this.maxBookingDays = 60,
    this.maxDailyInspections = 20,
    this.maxAgentDailyInspections = 6,
    this.allowAgentSelection = true,
    this.timezone = 'Africa/Lagos',
  });

  final String id;
  final int slotDurationMinutes;
  final int bufferMinutes;
  final int minNoticeHours;
  final int maxBookingDays;
  final int maxDailyInspections;
  final int maxAgentDailyInspections;
  final bool allowAgentSelection;
  final String timezone;

  factory InspectionSettingsRow.fromJson(Map<String, dynamic> json) {
    return InspectionSettingsRow(
      id: '${json['id']}',
      slotDurationMinutes: json['slot_duration_minutes'] as int? ?? 60,
      bufferMinutes: json['buffer_minutes'] as int? ?? 15,
      minNoticeHours: json['min_notice_hours'] as int? ?? 24,
      maxBookingDays: json['max_booking_days'] as int? ?? 60,
      maxDailyInspections: json['max_daily_inspections'] as int? ?? 20,
      maxAgentDailyInspections:
          json['max_agent_daily_inspections'] as int? ?? 6,
      allowAgentSelection: json['allow_agent_selection'] as bool? ?? true,
      timezone: json['timezone'] as String? ?? 'Africa/Lagos',
    );
  }

  Map<String, dynamic> toJson() => {
        'slot_duration_minutes': slotDurationMinutes,
        'buffer_minutes': bufferMinutes,
        'min_notice_hours': minNoticeHours,
        'max_booking_days': maxBookingDays,
        'max_daily_inspections': maxDailyInspections,
        'max_agent_daily_inspections': maxAgentDailyInspections,
        'allow_agent_selection': allowAgentSelection,
        'timezone': timezone,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
}

class InspectionWorkingHourRow {
  const InspectionWorkingHourRow({
    required this.id,
    required this.weekday,
    required this.startTime,
    required this.endTime,
    this.isActive = true,
  });

  final String id;
  final int weekday;
  final String startTime;
  final String endTime;
  final bool isActive;

  static const weekdayLabels = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  factory InspectionWorkingHourRow.fromJson(Map<String, dynamic> json) {
    return InspectionWorkingHourRow(
      id: '${json['id']}',
      weekday: json['weekday'] as int? ?? 0,
      startTime: '${json['start_time']}'.substring(0, 5),
      endTime: '${json['end_time']}'.substring(0, 5),
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'weekday': weekday,
        'start_time': startTime,
        'end_time': endTime,
        'is_active': isActive,
      };

  InspectionWorkingHourRow copyWith({
    String? id,
    int? weekday,
    String? startTime,
    String? endTime,
    bool? isActive,
  }) {
    return InspectionWorkingHourRow(
      id: id ?? this.id,
      weekday: weekday ?? this.weekday,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isActive: isActive ?? this.isActive,
    );
  }
}

class InspectionHolidayRow {
  const InspectionHolidayRow({
    required this.id,
    required this.holidayDate,
    required this.name,
  });

  final String id;
  final DateTime holidayDate;
  final String name;

  factory InspectionHolidayRow.fromJson(Map<String, dynamic> json) {
    return InspectionHolidayRow(
      id: '${json['id']}',
      holidayDate: DateTime.parse('${json['holiday_date']}'),
      name: json['name'] as String? ?? 'Holiday',
    );
  }
}

class InspectionBlockedSlotRow {
  const InspectionBlockedSlotRow({
    required this.id,
    required this.blockedAt,
    required this.reason,
    this.propertyId,
    this.estateId,
  });

  final String id;
  final DateTime blockedAt;
  final String reason;
  final String? propertyId;
  final String? estateId;

  factory InspectionBlockedSlotRow.fromJson(Map<String, dynamic> json) {
    return InspectionBlockedSlotRow(
      id: '${json['id']}',
      blockedAt: DateTime.parse('${json['blocked_at']}'),
      reason: json['reason'] as String? ?? 'Blocked',
      propertyId: json['property_id']?.toString(),
      estateId: json['estate_id']?.toString(),
    );
  }
}

class InspectionAgentRow {
  const InspectionAgentRow({
    required this.id,
    required this.advisorId,
    required this.advisorName,
    this.advisorTitle,
    this.maxDailyInspections = 6,
    this.isActive = true,
    this.estateIds = const [],
  });

  final String id;
  final String advisorId;
  final String advisorName;
  final String? advisorTitle;
  final int maxDailyInspections;
  final bool isActive;
  final List<String> estateIds;

  factory InspectionAgentRow.fromJson(Map<String, dynamic> json) {
    final advisor = json['consultation_advisors'];
    String name = '';
    String? title;
    if (advisor is Map) {
      name = advisor['full_name'] as String? ?? '';
      title = advisor['title'] as String?;
    }
    final estates = json['estate_ids'];
    return InspectionAgentRow(
      id: '${json['id']}',
      advisorId: '${json['advisor_id']}',
      advisorName: name,
      advisorTitle: title,
      maxDailyInspections: json['max_daily_inspections'] as int? ?? 6,
      isActive: json['is_active'] as bool? ?? true,
      estateIds: estates is List
          ? estates.map((e) => '$e').toList()
          : const [],
    );
  }
}

class PropertyInspectionConfigRow {
  const PropertyInspectionConfigRow({
    required this.propertyId,
    this.inspectionEnabled = true,
    this.physicalEnabled = true,
    this.virtualEnabled = true,
    this.durationMinutes,
    this.minNoticeHours,
    this.maxDailyInspections,
    this.availableWeekdays = const [0, 1, 2, 3, 4, 5],
    this.specialInstructions,
  });

  final String propertyId;
  final bool inspectionEnabled;
  final bool physicalEnabled;
  final bool virtualEnabled;
  final int? durationMinutes;
  final int? minNoticeHours;
  final int? maxDailyInspections;
  final List<int> availableWeekdays;
  final String? specialInstructions;

  factory PropertyInspectionConfigRow.fromJson(Map<String, dynamic> json) {
    final weekdays = json['available_weekdays'];
    return PropertyInspectionConfigRow(
      propertyId: '${json['property_id']}',
      inspectionEnabled: json['inspection_enabled'] as bool? ?? true,
      physicalEnabled: json['physical_enabled'] as bool? ?? true,
      virtualEnabled: json['virtual_enabled'] as bool? ?? true,
      durationMinutes: json['duration_minutes'] as int?,
      minNoticeHours: json['min_notice_hours'] as int?,
      maxDailyInspections: json['max_daily_inspections'] as int?,
      availableWeekdays: weekdays is List
          ? weekdays.map((e) => e as int).toList()
          : const [0, 1, 2, 3, 4, 5],
      specialInstructions: json['special_instructions'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'property_id': propertyId,
        'inspection_enabled': inspectionEnabled,
        'physical_enabled': physicalEnabled,
        'virtual_enabled': virtualEnabled,
        'duration_minutes': durationMinutes,
        'min_notice_hours': minNoticeHours,
        'max_daily_inspections': maxDailyInspections,
        'available_weekdays': availableWeekdays,
        'special_instructions': specialInstructions,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
}

class InspectionStatusHistoryEntry {
  const InspectionStatusHistoryEntry({
    required this.id,
    required this.toStatus,
    this.fromStatus,
    this.reason,
    this.changedAt,
  });

  final String id;
  final String toStatus;
  final String? fromStatus;
  final String? reason;
  final DateTime? changedAt;

  factory InspectionStatusHistoryEntry.fromJson(Map<String, dynamic> json) {
    return InspectionStatusHistoryEntry(
      id: '${json['id']}',
      toStatus: '${json['to_status']}',
      fromStatus: json['from_status'] as String?,
      reason: json['reason'] as String?,
      changedAt: json['changed_at'] != null
          ? DateTime.tryParse('${json['changed_at']}')
          : null,
    );
  }
}

class InspectionPropertyOption {
  const InspectionPropertyOption({
    required this.id,
    required this.title,
    this.estateId,
  });

  final String id;
  final String title;
  final String? estateId;

  factory InspectionPropertyOption.fromJson(Map<String, dynamic> json) {
    return InspectionPropertyOption(
      id: '${json['id']}',
      title: json['title'] as String? ?? 'Untitled property',
      estateId: json['estate_id']?.toString(),
    );
  }
}

class InspectionAdvisorOption {
  const InspectionAdvisorOption({
    required this.id,
    required this.fullName,
    this.title,
    this.isActive = true,
  });

  final String id;
  final String fullName;
  final String? title;
  final bool isActive;

  factory InspectionAdvisorOption.fromJson(Map<String, dynamic> json) {
    return InspectionAdvisorOption(
      id: '${json['id']}',
      fullName: json['full_name'] as String? ?? 'Advisor',
      title: json['title'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class InspectionEstateOption {
  const InspectionEstateOption({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;

  factory InspectionEstateOption.fromJson(Map<String, dynamic> json) {
    return InspectionEstateOption(
      id: '${json['id']}',
      name: json['name'] as String? ??
          json['title'] as String? ??
          'Estate',
    );
  }
}

class AdminInspectionDraft {
  const AdminInspectionDraft({
    this.id,
    required this.propertyId,
    required this.scheduledAt,
    this.status = 'scheduled',
    this.inspectionType = 'site_visit',
    this.visitorName,
    this.visitorEmail,
    this.visitorPhone,
    this.advisorId,
    this.preferredLanguage,
    this.meetingUrl,
    this.reason,
    this.clearAdvisor = false,
  });

  final String? id;
  final String propertyId;
  final DateTime scheduledAt;
  final String status;
  final String inspectionType;
  final String? visitorName;
  final String? visitorEmail;
  final String? visitorPhone;
  final String? advisorId;
  final String? preferredLanguage;
  final String? meetingUrl;
  final String? reason;
  final bool clearAdvisor;
}
