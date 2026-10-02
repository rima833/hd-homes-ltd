import 'package:flutter/material.dart';

enum ConsultationMeetingMethod { phone, video, office }

class ConsultationDepartment {
  const ConsultationDepartment({
    required this.id,
    required this.slug,
    required this.name,
    required this.description,
    required this.iconName,
    required this.responseTimeLabel,
    required this.advisorCount,
    required this.durationMinutes,
  });

  final String id;
  final String slug;
  final String name;
  final String description;
  final String iconName;
  final String responseTimeLabel;
  final int advisorCount;
  final int durationMinutes;

  factory ConsultationDepartment.fromJson(Map<String, dynamic> json) {
    return ConsultationDepartment(
      id: '${json['id']}',
      slug: '${json['slug'] ?? ''}',
      name: '${json['name'] ?? ''}',
      description: '${json['description'] ?? ''}',
      iconName: '${json['icon_name'] ?? 'headset'}',
      responseTimeLabel: '${json['response_time_label'] ?? '< 15 min'}',
      advisorCount: (json['advisor_count'] as num?)?.toInt() ?? 1,
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 45,
    );
  }
}

class ConsultationAdvisor {
  const ConsultationAdvisor({
    required this.id,
    required this.fullName,
    required this.title,
    this.departmentId,
    this.photoUrl,
    this.phone,
    this.whatsapp,
    this.email,
    this.experienceYears = 5,
    this.languages = const ['English'],
    this.rating = 4.9,
    this.reviewCount = 0,
  });

  final String id;
  final String fullName;
  final String title;
  final String? departmentId;
  final String? photoUrl;
  final String? phone;
  final String? whatsapp;
  final String? email;
  final int experienceYears;
  final List<String> languages;
  final double rating;
  final int reviewCount;

  factory ConsultationAdvisor.fromJson(Map<String, dynamic> json) {
    final langs = <String>[];
    final raw = json['languages'];
    if (raw is List) {
      for (final e in raw) {
        final s = '$e'.trim();
        if (s.isNotEmpty) langs.add(s);
      }
    }
    return ConsultationAdvisor(
      id: '${json['id']}',
      fullName: '${json['full_name'] ?? ''}',
      title: '${json['title'] ?? 'Property Consultant'}',
      departmentId: json['department_id']?.toString(),
      photoUrl: json['photo_url'] as String?,
      phone: json['phone'] as String?,
      whatsapp: json['whatsapp'] as String?,
      email: json['email'] as String?,
      experienceYears: (json['experience_years'] as num?)?.toInt() ?? 5,
      languages: langs.isEmpty ? const ['English'] : langs,
      rating: (json['rating'] as num?)?.toDouble() ?? 4.9,
      reviewCount: (json['review_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class ConsultationSlot {
  const ConsultationSlot({
    required this.date,
    required this.time,
    required this.scheduledAt,
    required this.available,
    required this.period,
  });

  final DateTime date;
  final String time;
  final DateTime scheduledAt;
  final bool available;
  final String period;

  factory ConsultationSlot.fromJson(Map<String, dynamic> json) {
    final scheduled =
        DateTime.tryParse('${json['scheduled_at']}')?.toLocal() ??
        DateTime.now();
    final dateRaw = json['date'];
    final date = dateRaw == null
        ? DateTime(scheduled.year, scheduled.month, scheduled.day)
        : (DateTime.tryParse('$dateRaw') ??
              DateTime(scheduled.year, scheduled.month, scheduled.day));
    return ConsultationSlot(
      date: DateTime(date.year, date.month, date.day),
      time: '${json['time'] ?? ''}',
      scheduledAt: scheduled,
      available: json['available'] == true,
      period: '${json['period'] ?? 'morning'}',
    );
  }

  String get label {
    final h = int.tryParse(time.split(':').first) ?? scheduledAt.hour;
    final m = time.contains(':')
        ? int.tryParse(time.split(':').last) ?? scheduledAt.minute
        : scheduledAt.minute;
    final tod = TimeOfDay(hour: h, minute: m);
    final hour = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final suffix = tod.period == DayPeriod.am ? 'AM' : 'PM';
    final mm = tod.minute.toString().padLeft(2, '0');
    return '$hour:$mm $suffix';
  }
}

class ConsultationBookingDraft {
  const ConsultationBookingDraft({
    this.fullName = '',
    this.phone = '',
    this.email = '',
    this.company = '',
    this.departmentSlug = '',
    this.meetingMethod = ConsultationMeetingMethod.video,
    this.selectedDate,
    this.selectedSlot,
    this.advisorId,
    this.officeLocationId,
    this.purpose,
    this.budget,
    this.propertyReference,
    this.preferredEstate,
    this.timeline,
    this.investmentInterest = false,
    this.notes = '',
    this.documentUrls = const [],
    this.step = 0,
    this.submitting = false,
    this.submittedReference,
    this.error,
  });

  final String fullName;
  final String phone;
  final String email;
  final String company;
  final String departmentSlug;
  final ConsultationMeetingMethod meetingMethod;
  final DateTime? selectedDate;
  final ConsultationSlot? selectedSlot;
  final String? advisorId;
  final String? officeLocationId;
  final String? purpose;
  final String? budget;
  final String? propertyReference;
  final String? preferredEstate;
  final String? timeline;
  final bool investmentInterest;
  final String notes;
  final List<String> documentUrls;
  final int step;
  final bool submitting;
  final String? submittedReference;
  final String? error;

  ConsultationBookingDraft copyWith({
    String? fullName,
    String? phone,
    String? email,
    String? company,
    String? departmentSlug,
    ConsultationMeetingMethod? meetingMethod,
    DateTime? selectedDate,
    bool clearSelectedDate = false,
    ConsultationSlot? selectedSlot,
    bool clearSelectedSlot = false,
    String? advisorId,
    bool clearAdvisorId = false,
    String? officeLocationId,
    bool clearOfficeLocationId = false,
    String? purpose,
    String? budget,
    String? propertyReference,
    String? preferredEstate,
    String? timeline,
    bool? investmentInterest,
    String? notes,
    List<String>? documentUrls,
    int? step,
    bool? submitting,
    String? submittedReference,
    bool clearReference = false,
    String? error,
    bool clearError = false,
  }) {
    return ConsultationBookingDraft(
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      company: company ?? this.company,
      departmentSlug: departmentSlug ?? this.departmentSlug,
      meetingMethod: meetingMethod ?? this.meetingMethod,
      selectedDate: clearSelectedDate
          ? null
          : (selectedDate ?? this.selectedDate),
      selectedSlot: clearSelectedSlot
          ? null
          : (selectedSlot ?? this.selectedSlot),
      advisorId: clearAdvisorId ? null : (advisorId ?? this.advisorId),
      officeLocationId: clearOfficeLocationId
          ? null
          : (officeLocationId ?? this.officeLocationId),
      purpose: purpose ?? this.purpose,
      budget: budget ?? this.budget,
      propertyReference: propertyReference ?? this.propertyReference,
      preferredEstate: preferredEstate ?? this.preferredEstate,
      timeline: timeline ?? this.timeline,
      investmentInterest: investmentInterest ?? this.investmentInterest,
      notes: notes ?? this.notes,
      documentUrls: documentUrls ?? this.documentUrls,
      step: step ?? this.step,
      submitting: submitting ?? this.submitting,
      submittedReference: clearReference
          ? null
          : (submittedReference ?? this.submittedReference),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ConsultationBookingResult {
  const ConsultationBookingResult({
    required this.reference,
    this.bookingId,
    this.leadId,
    this.advisorName,
  });

  final String reference;
  final String? bookingId;
  final String? leadId;
  final String? advisorName;
}
