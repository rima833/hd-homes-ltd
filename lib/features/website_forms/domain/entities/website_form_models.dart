class WebsiteFormOption {
  const WebsiteFormOption({
    required this.id,
    required this.name,
    this.slug = '',
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory WebsiteFormOption.fromJson(Map<String, dynamic> json) =>
      WebsiteFormOption(
        id: '${json['id']}',
        name: json['name'] as String? ?? '',
        slug: json['slug'] as String? ?? '',
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
        isActive: json['is_active'] as bool? ?? true,
      );

  final String id;
  final String name;
  final String slug;
  final int sortOrder;
  final bool isActive;
}

class WebsiteSupportSettings {
  const WebsiteSupportSettings({
    required this.id,
    this.isEnabled = true,
    this.confirmationTitle = 'Ticket submitted',
    this.confirmationMessage =
        'Thank you. Our support team has received your ticket and will get back to you shortly.',
    this.defaultPriority = 'normal',
    this.disabledMessage =
        'Support submissions are temporarily unavailable. Please try again later or email us directly.',
    this.contactPhone,
    this.contactEmail,
  });

  factory WebsiteSupportSettings.fromJson(Map<String, dynamic> json) =>
      WebsiteSupportSettings(
        id: '${json['id']}',
        isEnabled: json['is_enabled'] as bool? ?? true,
        confirmationTitle:
            json['confirmation_title'] as String? ?? 'Ticket submitted',
        confirmationMessage: json['confirmation_message'] as String? ?? '',
        defaultPriority: json['default_priority'] as String? ?? 'normal',
        disabledMessage: json['disabled_message'] as String? ?? '',
        contactPhone: json['contact_phone'] as String?,
        contactEmail: json['contact_email'] as String?,
      );

  final String id;
  final bool isEnabled;
  final String confirmationTitle;
  final String confirmationMessage;
  final String defaultPriority;
  final String disabledMessage;
  final String? contactPhone;
  final String? contactEmail;

  Map<String, dynamic> toJson() => {
        'is_enabled': isEnabled,
        'confirmation_title': confirmationTitle,
        'confirmation_message': confirmationMessage,
        'default_priority': defaultPriority,
        'disabled_message': disabledMessage,
        'contact_phone': contactPhone,
        'contact_email': contactEmail,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
}

class CareerApplicationSettings {
  const CareerApplicationSettings({
    this.applicationsEnabled = true,
    this.confirmationTitle = 'Application received',
    this.confirmationMessage =
        'Thank you for applying. Our recruitment team will review your application.',
    this.allowedCvExtensions = const ['pdf', 'doc', 'docx'],
    this.maxCvBytes = 5242880,
    this.allowGeneralApplication = true,
    this.disabledMessage =
        'Career applications are temporarily closed. Please check back soon.',
  });

  factory CareerApplicationSettings.fromJson(Map<String, dynamic> json) {
    final ext = json['allowed_cv_extensions'];
    return CareerApplicationSettings(
      applicationsEnabled: json['applications_enabled'] as bool? ?? true,
      confirmationTitle:
          json['application_confirmation_title'] as String? ??
          'Application received',
      confirmationMessage:
          json['application_confirmation_message'] as String? ?? '',
      allowedCvExtensions: ext is List
          ? ext.map((e) => '$e'.toLowerCase()).toList()
          : const ['pdf', 'doc', 'docx'],
      maxCvBytes: (json['max_cv_bytes'] as num?)?.toInt() ?? 5242880,
      allowGeneralApplication:
          json['allow_general_application'] as bool? ?? true,
      disabledMessage: json['applications_disabled_message'] as String? ?? '',
    );
  }

  final bool applicationsEnabled;
  final String confirmationTitle;
  final String confirmationMessage;
  final List<String> allowedCvExtensions;
  final int maxCvBytes;
  final bool allowGeneralApplication;
  final String disabledMessage;
}

class PartnershipSettings {
  const PartnershipSettings({
    required this.id,
    this.isEnabled = true,
    this.confirmationTitle = 'Partnership request received',
    this.confirmationMessage =
        'Thank you. Our partnerships team will review your proposal and get in touch.',
    this.disabledMessage =
        'Partnership requests are temporarily unavailable. Please email us directly.',
    this.allowedDocExtensions = const ['pdf', 'doc', 'docx'],
    this.maxDocBytes = 10485760,
  });

  factory PartnershipSettings.fromJson(Map<String, dynamic> json) {
    final ext = json['allowed_doc_extensions'];
    return PartnershipSettings(
      id: '${json['id']}',
      isEnabled: json['is_enabled'] as bool? ?? true,
      confirmationTitle:
          json['confirmation_title'] as String? ??
          'Partnership request received',
      confirmationMessage: json['confirmation_message'] as String? ?? '',
      disabledMessage: json['disabled_message'] as String? ?? '',
      allowedDocExtensions: ext is List
          ? ext.map((e) => '$e'.toLowerCase()).toList()
          : const ['pdf', 'doc', 'docx'],
      maxDocBytes: (json['max_doc_bytes'] as num?)?.toInt() ?? 10485760,
    );
  }

  final String id;
  final bool isEnabled;
  final String confirmationTitle;
  final String confirmationMessage;
  final String disabledMessage;
  final List<String> allowedDocExtensions;
  final int maxDocBytes;

  Map<String, dynamic> toJson() => {
        'is_enabled': isEnabled,
        'confirmation_title': confirmationTitle,
        'confirmation_message': confirmationMessage,
        'disabled_message': disabledMessage,
        'allowed_doc_extensions': allowedDocExtensions,
        'max_doc_bytes': maxDocBytes,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
}

class WebsiteFormSubmitResult {
  const WebsiteFormSubmitResult({
    required this.reference,
    this.id,
    this.title = 'Submitted',
    this.message = 'Thank you. We have received your submission.',
  });

  final String reference;
  final String? id;
  final String title;
  final String message;
}

class WebsitePickedFile {
  const WebsitePickedFile({
    required this.bytes,
    required this.fileName,
    required this.extension,
    this.mimeType,
  });

  final List<int> bytes;
  final String fileName;
  final String extension;
  final String? mimeType;

  int get size => bytes.length;
}

class WebsiteSupportTicketRow {
  const WebsiteSupportTicketRow({
    required this.id,
    required this.reference,
    required this.name,
    required this.email,
    required this.subject,
    this.details = '',
    this.typeSlug = '',
    this.status = 'new',
    this.priority = 'normal',
    this.assignedTo,
    this.adminNotes,
    this.createdAt,
    this.updatedAt,
  });

  factory WebsiteSupportTicketRow.fromJson(Map<String, dynamic> json) {
    final meta = json['metadata'];
    String? notes;
    if (meta is Map) {
      notes = meta['admin_notes']?.toString();
    }
    return WebsiteSupportTicketRow(
      id: '${json['id']}',
      reference: json['ticket_number'] as String? ?? '',
      name: json['customer_name'] as String? ?? '',
      email: json['customer_email'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      details: json['description'] as String? ?? '',
      typeSlug: json['subcategory'] as String? ?? '',
      status: json['status'] as String? ?? 'new',
      priority: json['priority'] as String? ?? 'normal',
      assignedTo: json['assigned_to'] as String?,
      adminNotes: notes,
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
      updatedAt: DateTime.tryParse('${json['updated_at'] ?? ''}'),
    );
  }

  final String id;
  final String reference;
  final String name;
  final String email;
  final String subject;
  final String details;
  final String typeSlug;
  final String status;
  final String priority;
  final String? assignedTo;
  final String? adminNotes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

class CareerApplicationRow {
  const CareerApplicationRow({
    required this.id,
    required this.reference,
    required this.fullName,
    required this.email,
    this.phone,
    this.jobId,
    this.positionTitle = '',
    this.preferredLocation,
    this.linkedinUrl,
    this.coverLetter,
    this.cvPath,
    this.cvFileName,
    this.status = 'new',
    this.assignedTo,
    this.adminNotes,
    this.createdAt,
    this.updatedAt,
  });

  factory CareerApplicationRow.fromJson(Map<String, dynamic> json) =>
      CareerApplicationRow(
        id: '${json['id']}',
        reference: json['reference_number'] as String? ?? '',
        fullName: json['full_name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        phone: json['phone'] as String?,
        jobId: json['job_id'] as String?,
        positionTitle: json['position_title'] as String? ?? '',
        preferredLocation: json['preferred_location'] as String?,
        linkedinUrl: json['linkedin_url'] as String?,
        coverLetter: json['cover_letter'] as String?,
        cvPath: json['cv_path'] as String?,
        cvFileName: json['cv_file_name'] as String?,
        status: json['status'] as String? ?? 'new',
        assignedTo: json['assigned_to'] as String?,
        adminNotes: json['admin_notes'] as String?,
        createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
        updatedAt: DateTime.tryParse('${json['updated_at'] ?? ''}'),
      );

  final String id;
  final String reference;
  final String fullName;
  final String email;
  final String? phone;
  final String? jobId;
  final String positionTitle;
  final String? preferredLocation;
  final String? linkedinUrl;
  final String? coverLetter;
  final String? cvPath;
  final String? cvFileName;
  final String status;
  final String? assignedTo;
  final String? adminNotes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

class PartnershipRequestRow {
  const PartnershipRequestRow({
    required this.id,
    required this.reference,
    required this.companyName,
    required this.contactPerson,
    required this.email,
    required this.phone,
    this.typeName,
    this.proposalSummary,
    this.documents = const [],
    this.status = 'new',
    this.priority = 'normal',
    this.assignedTo,
    this.adminNotes,
    this.createdAt,
    this.updatedAt,
  });

  factory PartnershipRequestRow.fromJson(Map<String, dynamic> json) {
    final docs = json['documents'];
    return PartnershipRequestRow(
      id: '${json['id']}',
      reference: json['reference_number'] as String? ?? '',
      companyName: json['company_name'] as String? ?? '',
      contactPerson: json['contact_person'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      typeName: json['type_name'] as String?,
      proposalSummary: json['proposal_summary'] as String?,
      documents: docs is List
          ? docs
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
          : const [],
      status: json['status'] as String? ?? 'new',
      priority: json['priority'] as String? ?? 'normal',
      assignedTo: json['assigned_to'] as String?,
      adminNotes: json['admin_notes'] as String?,
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
      updatedAt: DateTime.tryParse('${json['updated_at'] ?? ''}'),
    );
  }

  final String id;
  final String reference;
  final String companyName;
  final String contactPerson;
  final String email;
  final String phone;
  final String? typeName;
  final String? proposalSummary;
  final List<Map<String, dynamic>> documents;
  final String status;
  final String priority;
  final String? assignedTo;
  final String? adminNotes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

class WebsiteInboxNote {
  const WebsiteInboxNote({
    required this.id,
    required this.body,
    this.authorLabel,
    this.createdAt,
  });

  factory WebsiteInboxNote.fromJson(Map<String, dynamic> json) =>
      WebsiteInboxNote(
        id: '${json['id']}',
        body: json['body'] as String? ?? '',
        authorLabel: json['author_label'] as String?,
        createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
      );

  final String id;
  final String body;
  final String? authorLabel;
  final DateTime? createdAt;
}

class WebsiteSupportStats {
  const WebsiteSupportStats({
    this.total = 0,
    this.neu = 0,
    this.open = 0,
    this.inProgress = 0,
    this.resolved = 0,
    this.urgent = 0,
  });

  final int total;
  final int neu;
  final int open;
  final int inProgress;
  final int resolved;
  final int urgent;
}

class CareerApplicationStats {
  const CareerApplicationStats({
    this.openPositions = 0,
    this.total = 0,
    this.neu = 0,
    this.interviews = 0,
    this.shortlisted = 0,
    this.hired = 0,
  });

  final int openPositions;
  final int total;
  final int neu;
  final int interviews;
  final int shortlisted;
  final int hired;
}

class PartnershipRequestStats {
  const PartnershipRequestStats({
    this.total = 0,
    this.neu = 0,
    this.underReview = 0,
    this.negotiation = 0,
    this.approved = 0,
    this.closed = 0,
  });

  final int total;
  final int neu;
  final int underReview;
  final int negotiation;
  final int approved;
  final int closed;
}
