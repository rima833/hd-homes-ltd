class AdminConsultationRow {
  const AdminConsultationRow({
    required this.id,
    required this.reference,
    required this.status,
    required this.scheduledAt,
    required this.meetingMethod,
    required this.durationMinutes,
    this.fullName,
    this.phone,
    this.email,
    this.company,
    this.departmentName,
    this.departmentSlug,
    this.advisorName,
    this.advisorId,
    this.officeName,
    this.notes,
    this.adminNotes,
    this.meetingUrl,
    this.createdAt,
  });

  final String id;
  final String reference;
  final String status;
  final DateTime scheduledAt;
  final String meetingMethod;
  final int durationMinutes;
  final String? fullName;
  final String? phone;
  final String? email;
  final String? company;
  final String? departmentName;
  final String? departmentSlug;
  final String? advisorName;
  final String? advisorId;
  final String? officeName;
  final String? notes;
  final String? adminNotes;
  final String? meetingUrl;
  final DateTime? createdAt;

  factory AdminConsultationRow.fromJson(Map<String, dynamic> json) {
    String? deptName;
    String? deptSlug;
    final dept = json['consultation_departments'];
    if (dept is Map) {
      deptName = dept['name'] as String?;
      deptSlug = dept['slug'] as String?;
    }

    String? advisorName;
    final advisor = json['consultation_advisors'];
    if (advisor is Map) {
      advisorName = advisor['full_name'] as String?;
    }

    String? officeName;
    final office = json['office_locations'];
    if (office is Map) {
      officeName = office['name'] as String?;
    }

    return AdminConsultationRow(
      id: '${json['id']}',
      reference: '${json['reference']}',
      status: '${json['status'] ?? 'scheduled'}',
      scheduledAt: DateTime.parse('${json['scheduled_at']}'),
      meetingMethod: '${json['meeting_method'] ?? 'video'}',
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 45,
      fullName: json['full_name'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      company: json['company'] as String?,
      departmentName: deptName,
      departmentSlug: deptSlug,
      advisorName: advisorName,
      advisorId: json['advisor_id']?.toString(),
      officeName: officeName,
      notes: json['notes'] as String?,
      adminNotes: json['admin_notes'] as String?,
      meetingUrl: json['meeting_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse('${json['created_at']}')
          : null,
    );
  }
}

class AdminConsultationStats {
  const AdminConsultationStats({
    this.total = 0,
    this.today = 0,
    this.upcoming = 0,
    this.pending = 0,
    this.confirmed = 0,
    this.completed = 0,
    this.cancelled = 0,
    this.noShow = 0,
  });

  final int total;
  final int today;
  final int upcoming;
  final int pending;
  final int confirmed;
  final int completed;
  final int cancelled;
  final int noShow;
}

class ConsultationBookingEvent {
  const ConsultationBookingEvent({
    required this.id,
    required this.eventType,
    required this.createdAt,
    this.metadata,
  });

  final String id;
  final String eventType;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  factory ConsultationBookingEvent.fromJson(Map<String, dynamic> json) {
    return ConsultationBookingEvent(
      id: '${json['id']}',
      eventType: '${json['event_type']}',
      createdAt: DateTime.parse('${json['created_at']}'),
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
    );
  }
}

class AdminConsultationAdvisor {
  const AdminConsultationAdvisor({
    required this.id,
    required this.fullName,
    required this.isActive,
    this.title,
    this.departmentId,
    this.departmentName,
    this.email,
    this.phone,
    this.whatsapp,
    this.sortOrder,
  });

  final String id;
  final String fullName;
  final bool isActive;
  final String? title;
  final String? departmentId;
  final String? departmentName;
  final String? email;
  final String? phone;
  final String? whatsapp;
  final int? sortOrder;

  factory AdminConsultationAdvisor.fromJson(Map<String, dynamic> json) {
    String? deptName;
    final dept = json['consultation_departments'];
    if (dept is Map) {
      deptName = dept['name'] as String?;
    }
    return AdminConsultationAdvisor(
      id: '${json['id']}',
      fullName: '${json['full_name']}',
      isActive: json['is_active'] as bool? ?? true,
      title: json['title'] as String?,
      departmentId: json['department_id']?.toString(),
      departmentName: deptName,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      whatsapp: json['whatsapp'] as String?,
      sortOrder: (json['sort_order'] as num?)?.toInt(),
    );
  }
}

class AdminConsultationDepartment {
  const AdminConsultationDepartment({
    required this.id,
    required this.slug,
    required this.name,
    required this.isActive,
    this.description,
    this.responseTimeLabel,
    this.advisorCount,
    this.durationMinutes,
    this.sortOrder,
  });

  final String id;
  final String slug;
  final String name;
  final bool isActive;
  final String? description;
  final String? responseTimeLabel;
  final int? advisorCount;
  final int? durationMinutes;
  final int? sortOrder;

  factory AdminConsultationDepartment.fromJson(Map<String, dynamic> json) {
    return AdminConsultationDepartment(
      id: '${json['id']}',
      slug: '${json['slug']}',
      name: '${json['name']}',
      isActive: json['is_active'] as bool? ?? true,
      description: json['description'] as String?,
      responseTimeLabel: json['response_time_label'] as String?,
      advisorCount: (json['advisor_count'] as num?)?.toInt(),
      durationMinutes: (json['duration_minutes'] as num?)?.toInt(),
      sortOrder: (json['sort_order'] as num?)?.toInt(),
    );
  }
}
