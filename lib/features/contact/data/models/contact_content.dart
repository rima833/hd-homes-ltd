// Contact & Lead Generation CMS models (Supabase wired in Volume 1.5).

enum ContactChannelId {
  phone,
  whatsapp,
  email,
  visitOffice,
  bookAppointment,
  bookInspection,
  investorRelations,
  partnerships,
  liveChat,
  virtualMeeting,
}

/// Deep-link / scroll targets for the Contact Hub page.
enum ContactScrollTarget {
  options,
  offices,
  inspection,
  consultation,
  callback,
  liveChat,
  whatsapp,
  support,
  careers,
  partnerships,
  newsletter,
}

enum OfficeType { headOffice, regional, salesCenter, construction }

enum DepartmentId {
  sales,
  investorRelations,
  construction,
  legal,
  finance,
  propertyManagement,
  customerSupport,
  marketing,
  careers,
  general,
}

enum LeadPriority { low, normal, high, vip }

enum CrmPipelineStage {
  newLead,
  contacted,
  qualified,
  inspectionScheduled,
  negotiation,
  reservation,
  documentation,
  payment,
  completedSale,
  afterSales,
}

class ContactOption {
  const ContactOption({
    required this.id,
    required this.title,
    required this.description,
    required this.iconName,
    required this.department,
    required this.availability,
    required this.responseTime,
    required this.ctaLabel,
  });

  final ContactChannelId id;
  final String title;
  final String description;
  final String iconName;
  final String department;
  final String availability;
  final String responseTime;
  final String ctaLabel;
}

class OfficeLocation {
  const OfficeLocation({
    required this.id,
    required this.name,
    required this.type,
    required this.address,
    required this.city,
    required this.phone,
    required this.email,
    required this.hours,
    required this.lat,
    required this.lng,
    required this.parkingInfo,
    required this.landmarks,
  });

  final String id;
  final String name;
  final OfficeType type;
  final String address;
  final String city;
  final String phone;
  final String email;
  final String hours;
  final double lat;
  final double lng;
  final String parkingInfo;
  final List<String> landmarks;
}

class DepartmentInfo {
  const DepartmentInfo({
    required this.id,
    required this.name,
    required this.manager,
    required this.availability,
    required this.sla,
    required this.phone,
    required this.email,
    required this.whatsapp,
  });

  final DepartmentId id;
  final String name;
  final String manager;
  final String availability;
  final String sla;
  final String phone;
  final String email;
  final String whatsapp;
}

class ContactFaqItem {
  const ContactFaqItem({
    required this.question,
    required this.answer,
    required this.category,
  });

  final String question;
  final String answer;
  final String category;
}

class EmergencyContact {
  const EmergencyContact({
    required this.title,
    required this.number,
    required this.description,
    required this.available24x7,
  });

  final String title;
  final String number;
  final String description;
  final bool available24x7;
}

class CalendarSlot {
  const CalendarSlot({
    required this.date,
    required this.time,
    required this.consultant,
    required this.available,
  });

  final String date;
  final String time;
  final String consultant;
  final bool available;
}

class ContactHubCms {
  const ContactHubCms({
    required this.heroHeadline,
    required this.heroSubheadline,
    this.backgroundImageUrl,
    this.backgroundVideoUrl,
    required this.phone,
    required this.whatsapp,
    required this.email,
    this.supportHours = 'Mon–Fri 8:00 AM – 5:00 PM',
    this.officeLabel = 'Abuja, Nigeria',
    required this.contactOptions,
    required this.offices,
    required this.departments,
    required this.inspectionProperties,
    required this.inspectionEstates,
    required this.consultationTypes,
    required this.calendarSlots,
    required this.faqs,
    required this.emergencyContacts,
    required this.whatsappDepartments,
    required this.crmPipelineStages,
    required this.popularFaqCategories,
  });

  final String heroHeadline;
  final String heroSubheadline;
  final String? backgroundImageUrl;
  final String? backgroundVideoUrl;
  final String phone;
  final String whatsapp;
  final String email;
  /// Public support hours from Platform Control Center (contact.support_hours).
  final String supportHours;
  /// Short office label for footers (city / address from admin).
  final String officeLabel;
  final List<ContactOption> contactOptions;
  final List<OfficeLocation> offices;
  final List<DepartmentInfo> departments;
  final List<String> inspectionProperties;
  final List<String> inspectionEstates;
  final List<String> consultationTypes;
  final List<CalendarSlot> calendarSlots;
  final List<ContactFaqItem> faqs;
  final List<EmergencyContact> emergencyContacts;
  final List<String> whatsappDepartments;
  final List<String> crmPipelineStages;
  final List<String> popularFaqCategories;

  ContactHubCms copyWith({
    String? heroHeadline,
    String? heroSubheadline,
    String? backgroundImageUrl,
    String? backgroundVideoUrl,
    String? phone,
    String? whatsapp,
    String? email,
    String? supportHours,
    String? officeLabel,
    List<ContactOption>? contactOptions,
    List<OfficeLocation>? offices,
    List<DepartmentInfo>? departments,
    List<String>? inspectionProperties,
    List<String>? inspectionEstates,
    List<String>? consultationTypes,
    List<CalendarSlot>? calendarSlots,
    List<ContactFaqItem>? faqs,
    List<EmergencyContact>? emergencyContacts,
    List<String>? whatsappDepartments,
    List<String>? crmPipelineStages,
    List<String>? popularFaqCategories,
  }) {
    return ContactHubCms(
      heroHeadline: heroHeadline ?? this.heroHeadline,
      heroSubheadline: heroSubheadline ?? this.heroSubheadline,
      backgroundImageUrl: backgroundImageUrl ?? this.backgroundImageUrl,
      backgroundVideoUrl: backgroundVideoUrl ?? this.backgroundVideoUrl,
      phone: phone ?? this.phone,
      whatsapp: whatsapp ?? this.whatsapp,
      email: email ?? this.email,
      supportHours: supportHours ?? this.supportHours,
      officeLabel: officeLabel ?? this.officeLabel,
      contactOptions: contactOptions ?? this.contactOptions,
      offices: offices ?? this.offices,
      departments: departments ?? this.departments,
      inspectionProperties: inspectionProperties ?? this.inspectionProperties,
      inspectionEstates: inspectionEstates ?? this.inspectionEstates,
      consultationTypes: consultationTypes ?? this.consultationTypes,
      calendarSlots: calendarSlots ?? this.calendarSlots,
      faqs: faqs ?? this.faqs,
      emergencyContacts: emergencyContacts ?? this.emergencyContacts,
      whatsappDepartments: whatsappDepartments ?? this.whatsappDepartments,
      crmPipelineStages: crmPipelineStages ?? this.crmPipelineStages,
      popularFaqCategories: popularFaqCategories ?? this.popularFaqCategories,
    );
  }
}

class LeadQualificationInput {
  const LeadQualificationInput({
    this.budget,
    this.location,
    this.propertyType,
    this.timeline,
    this.investmentInterest = false,
    this.financingMethod,
    this.department,
    this.priority = LeadPriority.normal,
  });

  final String? budget;
  final String? location;
  final String? propertyType;
  final String? timeline;
  final bool investmentInterest;
  final String? financingMethod;
  final DepartmentId? department;
  final LeadPriority priority;
}

class LeadRoutingResult {
  const LeadRoutingResult({
    required this.score,
    required this.department,
    required this.assignedTo,
    required this.priority,
    required this.pipelineStage,
    required this.summary,
  });

  final int score;
  final String department;
  final String assignedTo;
  final LeadPriority priority;
  final CrmPipelineStage pipelineStage;
  final String summary;
}

class SubmittedLead {
  const SubmittedLead({
    required this.id,
    required this.type,
    required this.routing,
    required this.submittedAt,
    required this.visitorPassCode,
  });

  final String id;
  final String type;
  final LeadRoutingResult routing;
  final DateTime submittedAt;
  final String? visitorPassCode;
}
