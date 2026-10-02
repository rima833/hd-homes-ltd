class CallbackSettings {
  const CallbackSettings({
    required this.id,
    this.isEnabled = true,
    this.title = 'Request a Callback',
    this.subtitle =
        'Share your details and our team will call you at a time that works best for you.',
    this.ctaText = 'Request Callback',
    this.successTitle = 'Callback request received',
    this.successMessage =
        'Thank you. Our team has received your request and will contact you shortly.',
    this.trustSecurity = 'Your information is 100% secure',
    this.trustResponse = 'Quick response within 24 hours',
    this.trustExpert = 'Speak with a real expert',
    this.defaultResponseHours = 24,
    this.afterHoursMessage =
        'Callback requests are currently being accepted. Our team will contact you during business hours.',
    this.showAvailableNow = true,
    this.timezone = 'Africa/Lagos',
    this.preferredTimeOptions = const [
      'Morning (9am–12pm)',
      'Afternoon (12pm–3pm)',
      'Evening (3pm–6pm)',
      'Anytime',
    ],
  });

  final String id;
  final bool isEnabled;
  final String title;
  final String subtitle;
  final String ctaText;
  final String successTitle;
  final String successMessage;
  final String trustSecurity;
  final String trustResponse;
  final String trustExpert;
  final int defaultResponseHours;
  final String afterHoursMessage;
  final bool showAvailableNow;
  final String timezone;
  final List<String> preferredTimeOptions;

  factory CallbackSettings.fromJson(Map<String, dynamic> json) {
    final opts = json['preferred_time_options'];
    return CallbackSettings(
      id: '${json['id']}',
      isEnabled: json['is_enabled'] as bool? ?? true,
      title: json['title'] as String? ?? 'Request a Callback',
      subtitle: json['subtitle'] as String? ?? '',
      ctaText: json['cta_text'] as String? ?? 'Request Callback',
      successTitle: json['success_title'] as String? ?? 'Callback request received',
      successMessage: json['success_message'] as String? ?? '',
      trustSecurity: json['trust_security'] as String? ?? '',
      trustResponse: json['trust_response'] as String? ?? '',
      trustExpert: json['trust_expert'] as String? ?? '',
      defaultResponseHours: json['default_response_hours'] as int? ?? 24,
      afterHoursMessage: json['after_hours_message'] as String? ?? '',
      showAvailableNow: json['show_available_now'] as bool? ?? true,
      timezone: json['timezone'] as String? ?? 'Africa/Lagos',
      preferredTimeOptions: opts is List
          ? opts.map((e) => '$e').toList()
          : const [
              'Morning (9am–12pm)',
              'Afternoon (12pm–3pm)',
              'Evening (3pm–6pm)',
              'Anytime',
            ],
    );
  }

  Map<String, dynamic> toJson() => {
        'is_enabled': isEnabled,
        'title': title,
        'subtitle': subtitle,
        'cta_text': ctaText,
        'success_title': successTitle,
        'success_message': successMessage,
        'trust_security': trustSecurity,
        'trust_response': trustResponse,
        'trust_expert': trustExpert,
        'default_response_hours': defaultResponseHours,
        'after_hours_message': afterHoursMessage,
        'show_available_now': showAvailableNow,
        'timezone': timezone,
        'preferred_time_options': preferredTimeOptions,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

  CallbackSettings copyWith({
    bool? isEnabled,
    String? title,
    String? subtitle,
    String? ctaText,
    String? successTitle,
    String? successMessage,
    String? trustSecurity,
    String? trustResponse,
    String? trustExpert,
    int? defaultResponseHours,
    String? afterHoursMessage,
    bool? showAvailableNow,
    String? timezone,
    List<String>? preferredTimeOptions,
  }) {
    return CallbackSettings(
      id: id,
      isEnabled: isEnabled ?? this.isEnabled,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      ctaText: ctaText ?? this.ctaText,
      successTitle: successTitle ?? this.successTitle,
      successMessage: successMessage ?? this.successMessage,
      trustSecurity: trustSecurity ?? this.trustSecurity,
      trustResponse: trustResponse ?? this.trustResponse,
      trustExpert: trustExpert ?? this.trustExpert,
      defaultResponseHours: defaultResponseHours ?? this.defaultResponseHours,
      afterHoursMessage: afterHoursMessage ?? this.afterHoursMessage,
      showAvailableNow: showAvailableNow ?? this.showAvailableNow,
      timezone: timezone ?? this.timezone,
      preferredTimeOptions:
          preferredTimeOptions ?? this.preferredTimeOptions,
    );
  }
}

class CallbackDepartment {
  const CallbackDepartment({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.icon = 'briefcase',
    this.responseHours = 24,
    this.sortOrder = 0,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String slug;
  final String? description;
  final String icon;
  final int responseHours;
  final int sortOrder;
  final bool isActive;

  factory CallbackDepartment.fromJson(Map<String, dynamic> json) {
    return CallbackDepartment(
      id: '${json['id']}',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      description: json['description'] as String?,
      icon: json['icon'] as String? ?? 'briefcase',
      responseHours: json['response_hours'] as int? ?? 24,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class CallbackPriority {
  const CallbackPriority({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.responseHours = 24,
    this.sortOrder = 0,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String slug;
  final String? description;
  final int responseHours;
  final int sortOrder;
  final bool isActive;

  factory CallbackPriority.fromJson(Map<String, dynamic> json) {
    return CallbackPriority(
      id: '${json['id']}',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      description: json['description'] as String?,
      responseHours: json['response_hours'] as int? ?? 24,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class CallbackWorkingHour {
  const CallbackWorkingHour({
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

  factory CallbackWorkingHour.fromJson(Map<String, dynamic> json) {
    return CallbackWorkingHour(
      id: '${json['id']}',
      weekday: json['weekday'] as int? ?? 0,
      startTime: '${json['start_time']}'.substring(0, 5),
      endTime: '${json['end_time']}'.substring(0, 5),
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class CallbackSubmitResult {
  const CallbackSubmitResult({
    required this.reference,
    this.department,
    this.priority,
    this.responseHours = 24,
  });

  final String reference;
  final String? department;
  final String? priority;
  final int responseHours;
}

class AdminCallbackRow {
  const AdminCallbackRow({
    required this.id,
    required this.referenceNumber,
    required this.fullName,
    required this.phone,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.email,
    this.preferredTime,
    this.departmentId,
    this.departmentName,
    this.priorityId,
    this.priorityName,
    this.assignedTo,
    this.assignedToName,
    this.adminNotes,
    this.scheduledAt,
    this.contactedAt,
    this.completedAt,
  });

  final String id;
  final String referenceNumber;
  final String fullName;
  final String phone;
  final String reason;
  final String status;
  final DateTime createdAt;
  final String? email;
  final String? preferredTime;
  final String? departmentId;
  final String? departmentName;
  final String? priorityId;
  final String? priorityName;
  final String? assignedTo;
  final String? assignedToName;
  final String? adminNotes;
  final DateTime? scheduledAt;
  final DateTime? contactedAt;
  final DateTime? completedAt;

  factory AdminCallbackRow.fromJson(Map<String, dynamic> json) {
    final dept = json['callback_departments'];
    final pri = json['callback_priorities'];
    return AdminCallbackRow(
      id: '${json['id']}',
      referenceNumber: json['reference_number'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      status: json['status'] as String? ?? 'new',
      createdAt: DateTime.parse('${json['created_at']}'),
      email: json['email'] as String?,
      preferredTime: json['preferred_time'] as String?,
      departmentId: json['department_id']?.toString(),
      departmentName: dept is Map ? dept['name'] as String? : null,
      priorityId: json['priority_id']?.toString(),
      priorityName: pri is Map ? pri['name'] as String? : null,
      assignedTo: json['assigned_to']?.toString(),
      adminNotes: json['admin_notes'] as String?,
      scheduledAt: json['scheduled_at'] != null
          ? DateTime.tryParse('${json['scheduled_at']}')
          : null,
      contactedAt: json['contacted_at'] != null
          ? DateTime.tryParse('${json['contacted_at']}')
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse('${json['completed_at']}')
          : null,
    );
  }

  AdminCallbackRow copyWith({
    String? assignedToName,
    String? status,
    String? assignedTo,
    String? adminNotes,
    DateTime? scheduledAt,
  }) {
    return AdminCallbackRow(
      id: id,
      referenceNumber: referenceNumber,
      fullName: fullName,
      phone: phone,
      reason: reason,
      status: status ?? this.status,
      createdAt: createdAt,
      email: email,
      preferredTime: preferredTime,
      departmentId: departmentId,
      departmentName: departmentName,
      priorityId: priorityId,
      priorityName: priorityName,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedToName: assignedToName ?? this.assignedToName,
      adminNotes: adminNotes ?? this.adminNotes,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      contactedAt: contactedAt,
      completedAt: completedAt,
    );
  }
}

class CallbackStaffMember {
  const CallbackStaffMember({
    required this.id,
    required this.displayName,
    this.email,
  });

  final String id;
  final String displayName;
  final String? email;
}

class AdminCallbackStats {
  const AdminCallbackStats({
    this.total = 0,
    this.neu = 0,
    this.assigned = 0,
    this.contacted = 0,
    this.scheduled = 0,
    this.completed = 0,
    this.cancelled = 0,
  });

  final int total;
  final int neu;
  final int assigned;
  final int contacted;
  final int scheduled;
  final int completed;
  final int cancelled;
}

class CallbackStatusHistoryEntry {
  const CallbackStatusHistoryEntry({
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

  factory CallbackStatusHistoryEntry.fromJson(Map<String, dynamic> json) {
    return CallbackStatusHistoryEntry(
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
