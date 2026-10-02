class InspectionAdvisor {
  const InspectionAdvisor({
    required this.id,

    required this.name,

    required this.title,

    this.avatarUrl,

    this.whatsapp,

    this.phone,

    this.rating,

    this.languages = const ['English'],
  });

  final String id;

  final String name;

  final String title;

  final String? avatarUrl;

  final String? whatsapp;

  final String? phone;

  final double? rating;

  final List<String> languages;

  factory InspectionAdvisor.fromJson(Map<String, dynamic> json) {
    final langs = <String>[];

    final raw = json['languages'];

    if (raw is List) {
      for (final e in raw) {
        final s = '$e'.trim();

        if (s.isNotEmpty) langs.add(s);
      }
    }

    return InspectionAdvisor(
      id: '${json['id']}',

      name: '${json['full_name'] ?? json['name'] ?? ''}',

      title: '${json['title'] ?? 'Property Advisor'}',

      avatarUrl: json['photo_url'] as String?,

      whatsapp: json['whatsapp'] as String?,

      phone: json['phone'] as String?,

      rating: (json['rating'] as num?)?.toDouble(),

      languages: langs.isEmpty ? const ['English'] : langs,
    );
  }
}

enum InspectionMeetingType { physical, virtual }

/// How the visitor reaches a physical inspection.
enum InspectionMeetupMode { meetAtProperty, meetAtOffice, pickup }

enum InspectionPurpose { residence, investment, both }

class InspectionSlot {
  const InspectionSlot({
    required this.date,

    required this.time,

    required this.scheduledAt,

    required this.available,

    this.durationMinutes = 60,
  });

  final DateTime date;

  final String time;

  final DateTime scheduledAt;

  final bool available;

  final int durationMinutes;

  TimeOfDayLike get timeOfDay {
    final parts = time.split(':');

    return TimeOfDayLike(
      int.tryParse(parts.first) ?? 10,

      int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
  }

  String get label => timeOfDay.label;

  factory InspectionSlot.fromJson(Map<String, dynamic> json) {
    final rawDate = json['date'];
    DateTime parsed;
    if (rawDate is DateTime) {
      parsed = rawDate;
    } else {
      parsed = DateTime.parse('$rawDate');
    }
    // Normalize to a calendar date so timezone offsets never shift the day.
    final date = DateTime(parsed.year, parsed.month, parsed.day);

    final scheduledRaw = json['scheduled_at'];
    final scheduledAt = scheduledRaw is DateTime
        ? scheduledRaw.toLocal()
        : DateTime.parse('$scheduledRaw').toLocal();

    return InspectionSlot(
      date: date,
      time: '${json['time'] ?? ''}',
      scheduledAt: scheduledAt,
      available: json['available'] == true || json['available'] == 'true',
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 60,
    );
  }
}

class InspectionBookingDraft {
  const InspectionBookingDraft({
    this.fullName = '',

    this.phone = '',

    this.email = '',

    this.propertyId,

    this.estateId,

    this.preferredDate,

    this.preferredTime,

    this.scheduledAt,

    this.advisorId,

    this.meetingType = InspectionMeetingType.physical,

    this.meetupMode = InspectionMeetupMode.meetAtProperty,

    this.pickupAddress = '',

    this.meetupOfficeId,

    this.meetupOfficeLabel,

    this.preferredLanguage = 'English',

    this.notes = '',

    this.documentUrls = const [],

    this.budget,

    this.timeline,

    this.financing,

    this.location,

    this.propertyType,

    this.purpose = InspectionPurpose.residence,

    this.investmentInterest = false,

    this.step = 0,

    this.maxStepReached = 0,

    this.submitting = false,

    this.submittedReference,

    this.submittedInspectionId,

    this.submittedScheduledAt,

    this.submittedAdvisorName,

    this.submittedMeetingType,

    this.error,
  });

  final String fullName;

  final String phone;

  final String email;

  final String? propertyId;

  final String? estateId;

  final DateTime? preferredDate;

  final TimeOfDayLike? preferredTime;

  final DateTime? scheduledAt;

  final String? advisorId;

  final InspectionMeetingType meetingType;

  final InspectionMeetupMode meetupMode;

  /// Free-text address when [meetupMode] is [InspectionMeetupMode.pickup].
  final String pickupAddress;

  final String? meetupOfficeId;

  final String? meetupOfficeLabel;

  final String preferredLanguage;

  final String notes;

  final List<String> documentUrls;

  final String? budget;

  final String? timeline;

  final String? financing;

  final String? location;

  final String? propertyType;

  final InspectionPurpose purpose;

  final bool investmentInterest;

  final int step;

  final int maxStepReached;

  final bool submitting;

  final String? submittedReference;

  final String? submittedInspectionId;

  final DateTime? submittedScheduledAt;

  final String? submittedAdvisorName;

  final InspectionMeetingType? submittedMeetingType;

  final String? error;

  /// First incomplete step — drives the dedicated-page stepper in real time.
  int get liveStep {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (fullName.trim().length < 2 ||
        digits.length < 10 ||
        !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email.trim())) {
      return 0;
    }
    if (propertyId == null || propertyId!.isEmpty) return 1;
    if (preferredDate == null ||
        (preferredTime == null && scheduledAt == null)) {
      return 2;
    }
    return 3;
  }

  InspectionBookingDraft copyWith({
    String? fullName,

    String? phone,

    String? email,

    String? propertyId,

    bool clearPropertyId = false,

    String? estateId,

    bool clearEstateId = false,

    DateTime? preferredDate,

    bool clearPreferredDate = false,

    TimeOfDayLike? preferredTime,

    bool clearPreferredTime = false,

    DateTime? scheduledAt,

    bool clearScheduledAt = false,

    String? advisorId,

    bool clearAdvisorId = false,

    InspectionMeetingType? meetingType,

    InspectionMeetupMode? meetupMode,

    String? pickupAddress,

    String? meetupOfficeId,

    bool clearMeetupOfficeId = false,

    String? meetupOfficeLabel,

    bool clearMeetupOfficeLabel = false,

    String? preferredLanguage,

    String? notes,

    List<String>? documentUrls,

    String? budget,

    String? timeline,

    String? financing,

    String? location,

    String? propertyType,

    InspectionPurpose? purpose,

    bool? investmentInterest,

    int? step,

    int? maxStepReached,

    bool? submitting,

    String? submittedReference,

    bool clearReference = false,

    String? submittedInspectionId,

    bool clearInspectionId = false,

    DateTime? submittedScheduledAt,

    String? submittedAdvisorName,

    InspectionMeetingType? submittedMeetingType,

    String? error,

    bool clearError = false,
  }) {
    return InspectionBookingDraft(
      fullName: fullName ?? this.fullName,

      phone: phone ?? this.phone,

      email: email ?? this.email,

      propertyId: clearPropertyId ? null : (propertyId ?? this.propertyId),

      estateId: clearEstateId ? null : (estateId ?? this.estateId),

      preferredDate: clearPreferredDate
          ? null
          : (preferredDate ?? this.preferredDate),

      preferredTime: clearPreferredTime
          ? null
          : (preferredTime ?? this.preferredTime),

      scheduledAt: clearScheduledAt ? null : (scheduledAt ?? this.scheduledAt),

      advisorId: clearAdvisorId ? null : (advisorId ?? this.advisorId),

      meetingType: meetingType ?? this.meetingType,

      meetupMode: meetupMode ?? this.meetupMode,

      pickupAddress: pickupAddress ?? this.pickupAddress,

      meetupOfficeId: clearMeetupOfficeId
          ? null
          : (meetupOfficeId ?? this.meetupOfficeId),

      meetupOfficeLabel: clearMeetupOfficeLabel
          ? null
          : (meetupOfficeLabel ?? this.meetupOfficeLabel),

      preferredLanguage: preferredLanguage ?? this.preferredLanguage,

      notes: notes ?? this.notes,

      documentUrls: documentUrls ?? this.documentUrls,

      budget: budget ?? this.budget,

      timeline: timeline ?? this.timeline,

      financing: financing ?? this.financing,

      location: location ?? this.location,

      propertyType: propertyType ?? this.propertyType,

      purpose: purpose ?? this.purpose,

      investmentInterest: investmentInterest ?? this.investmentInterest,

      step: step ?? this.step,

      maxStepReached: maxStepReached ?? this.maxStepReached,

      submitting: submitting ?? this.submitting,

      submittedReference: clearReference
          ? null
          : (submittedReference ?? this.submittedReference),

      submittedInspectionId: clearInspectionId
          ? null
          : (submittedInspectionId ?? this.submittedInspectionId),

      submittedScheduledAt: submittedScheduledAt ?? this.submittedScheduledAt,

      submittedAdvisorName: submittedAdvisorName ?? this.submittedAdvisorName,

      submittedMeetingType: submittedMeetingType ?? this.submittedMeetingType,

      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Lightweight time-of-day without Flutter dependency in domain layer.

class TimeOfDayLike {
  const TimeOfDayLike(this.hour, this.minute);

  final int hour;

  final int minute;

  String get label {
    final h = hour % 12 == 0 ? 12 : hour % 12;

    final m = minute.toString().padLeft(2, '0');

    final suffix = hour >= 12 ? 'PM' : 'AM';

    return '$h:$m $suffix';
  }
}

class InspectionBookingResult {
  const InspectionBookingResult({
    required this.reference,

    this.inspectionId,

    this.leadId,

    this.scheduledAt,

    this.advisorName,

    this.meetingType,
  });

  final String reference;

  final String? inspectionId;

  final String? leadId;

  final DateTime? scheduledAt;

  final String? advisorName;

  final InspectionMeetingType? meetingType;
}
