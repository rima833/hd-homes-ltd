class CustomerConsultationBooking {
  const CustomerConsultationBooking({
    required this.id,
    required this.reference,
    required this.status,
    required this.scheduledAt,
    required this.durationMinutes,
    required this.meetingMethod,
    this.departmentName,
    this.advisorName,
    this.advisorPhone,
    this.advisorWhatsapp,
    this.advisorEmail,
    this.meetingUrl,
    this.notes,
  });

  final String id;
  final String reference;
  final String status;
  final DateTime scheduledAt;
  final int durationMinutes;
  final String meetingMethod;
  final String? departmentName;
  final String? advisorName;
  final String? advisorPhone;
  final String? advisorWhatsapp;
  final String? advisorEmail;
  final String? meetingUrl;
  final String? notes;

  bool get isUpcoming {
    final active = !{
      'cancelled',
      'rejected',
      'completed',
      'no_show',
    }.contains(status);
    return active && scheduledAt.isAfter(DateTime.now());
  }

  bool get canCancel =>
      isUpcoming && !{'cancelled', 'rejected', 'completed'}.contains(status);

  factory CustomerConsultationBooking.fromJson(Map<String, dynamic> json) {
    final dept = json['consultation_departments'];
    final advisor = json['consultation_advisors'];
    return CustomerConsultationBooking(
      id: '${json['id']}',
      reference: '${json['reference'] ?? ''}',
      status: '${json['status'] ?? 'scheduled'}',
      scheduledAt: DateTime.parse('${json['scheduled_at']}').toLocal(),
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 45,
      meetingMethod: '${json['meeting_method'] ?? 'video'}',
      departmentName: dept is Map ? dept['name']?.toString() : null,
      advisorName: advisor is Map ? advisor['full_name']?.toString() : null,
      advisorPhone: advisor is Map ? advisor['phone']?.toString() : null,
      advisorWhatsapp: advisor is Map ? advisor['whatsapp']?.toString() : null,
      advisorEmail: advisor is Map ? advisor['email']?.toString() : null,
      meetingUrl: json['meeting_url']?.toString(),
      notes: json['notes']?.toString(),
    );
  }
}
