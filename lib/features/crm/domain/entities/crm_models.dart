// Volume 4 Part 3 — Enterprise Client Relationship Management domain models.

enum CrmCustomerType {
  guest,
  registeredClient,
  buyer,
  investor,
  propertyOwner,
  tenant,
  corporate,
  agentPartner,
  vendor,
  formerClient;

  String get label => switch (this) {
        CrmCustomerType.guest => 'Guest',
        CrmCustomerType.registeredClient => 'Registered Client',
        CrmCustomerType.buyer => 'Buyer',
        CrmCustomerType.investor => 'Investor',
        CrmCustomerType.propertyOwner => 'Property Owner',
        CrmCustomerType.tenant => 'Tenant',
        CrmCustomerType.corporate => 'Corporate',
        CrmCustomerType.agentPartner => 'Agent Partner',
        CrmCustomerType.vendor => 'Vendor',
        CrmCustomerType.formerClient => 'Former Client',
      };

  String get slug => switch (this) {
        CrmCustomerType.registeredClient => 'registered_client',
        CrmCustomerType.propertyOwner => 'property_owner',
        CrmCustomerType.agentPartner => 'agent_partner',
        CrmCustomerType.formerClient => 'former_client',
        _ => name,
      };

  static CrmCustomerType fromSlug(String? raw) {
    return switch ((raw ?? 'guest').toLowerCase()) {
      'registered_client' || 'registeredclient' =>
        CrmCustomerType.registeredClient,
      'buyer' => CrmCustomerType.buyer,
      'investor' => CrmCustomerType.investor,
      'property_owner' || 'propertyowner' => CrmCustomerType.propertyOwner,
      'tenant' => CrmCustomerType.tenant,
      'corporate' => CrmCustomerType.corporate,
      'agent_partner' || 'agentpartner' => CrmCustomerType.agentPartner,
      'vendor' => CrmCustomerType.vendor,
      'former_client' || 'formerclient' => CrmCustomerType.formerClient,
      _ => CrmCustomerType.guest,
    };
  }
}

enum CrmRelationshipStatus {
  lead,
  prospect,
  activeBuyer,
  investor,
  owner,
  dormant,
  vip;

  String get label => switch (this) {
        CrmRelationshipStatus.lead => 'Lead',
        CrmRelationshipStatus.prospect => 'Prospect',
        CrmRelationshipStatus.activeBuyer => 'Active Buyer',
        CrmRelationshipStatus.investor => 'Investor',
        CrmRelationshipStatus.owner => 'Owner',
        CrmRelationshipStatus.dormant => 'Dormant',
        CrmRelationshipStatus.vip => 'VIP',
      };

  String get slug => switch (this) {
        CrmRelationshipStatus.activeBuyer => 'active_buyer',
        _ => name,
      };

  static CrmRelationshipStatus fromSlug(String? raw) {
    return switch ((raw ?? 'lead').toLowerCase()) {
      'prospect' => CrmRelationshipStatus.prospect,
      'active_buyer' || 'activebuyer' => CrmRelationshipStatus.activeBuyer,
      'investor' => CrmRelationshipStatus.investor,
      'owner' => CrmRelationshipStatus.owner,
      'dormant' => CrmRelationshipStatus.dormant,
      'vip' => CrmRelationshipStatus.vip,
      _ => CrmRelationshipStatus.lead,
    };
  }
}

enum CrmLeadStatus {
  open,
  qualified,
  nurture,
  won,
  lost;

  String get label => switch (this) {
        CrmLeadStatus.open => 'Open',
        CrmLeadStatus.qualified => 'Qualified',
        CrmLeadStatus.nurture => 'Nurture',
        CrmLeadStatus.won => 'Won',
        CrmLeadStatus.lost => 'Lost',
      };

  String get slug => name;

  static CrmLeadStatus fromSlug(String? raw) {
    return switch ((raw ?? 'open').toLowerCase()) {
      'qualified' => CrmLeadStatus.qualified,
      'nurture' => CrmLeadStatus.nurture,
      'won' => CrmLeadStatus.won,
      'lost' => CrmLeadStatus.lost,
      _ => CrmLeadStatus.open,
    };
  }
}

enum CrmPriority {
  low,
  medium,
  high,
  urgent;

  String get label => switch (this) {
        CrmPriority.low => 'Low',
        CrmPriority.medium => 'Medium',
        CrmPriority.high => 'High',
        CrmPriority.urgent => 'Urgent',
      };

  String get slug => name;

  static CrmPriority fromSlug(String? raw) {
    return switch ((raw ?? 'medium').toLowerCase()) {
      'low' => CrmPriority.low,
      'high' => CrmPriority.high,
      'urgent' => CrmPriority.urgent,
      _ => CrmPriority.medium,
    };
  }
}

enum CrmTaskType {
  call,
  meeting,
  siteVisit,
  email,
  followUp,
  reminder,
  internalNote;

  String get label => switch (this) {
        CrmTaskType.call => 'Call',
        CrmTaskType.meeting => 'Meeting',
        CrmTaskType.siteVisit => 'Site Visit',
        CrmTaskType.email => 'Email',
        CrmTaskType.followUp => 'Follow-up',
        CrmTaskType.reminder => 'Reminder',
        CrmTaskType.internalNote => 'Internal Note',
      };

  String get slug => switch (this) {
        CrmTaskType.siteVisit => 'site_visit',
        CrmTaskType.followUp => 'follow_up',
        CrmTaskType.internalNote => 'internal_note',
        _ => name,
      };

  static CrmTaskType fromSlug(String? raw) {
    return switch ((raw ?? 'follow_up').toLowerCase()) {
      'call' => CrmTaskType.call,
      'meeting' => CrmTaskType.meeting,
      'site_visit' || 'sitevisit' => CrmTaskType.siteVisit,
      'email' => CrmTaskType.email,
      'reminder' => CrmTaskType.reminder,
      'internal_note' || 'internalnote' => CrmTaskType.internalNote,
      _ => CrmTaskType.followUp,
    };
  }
}

enum CrmTaskStatus {
  open,
  inProgress,
  done,
  cancelled;

  String get label => switch (this) {
        CrmTaskStatus.open => 'Open',
        CrmTaskStatus.inProgress => 'In Progress',
        CrmTaskStatus.done => 'Done',
        CrmTaskStatus.cancelled => 'Cancelled',
      };

  String get slug => switch (this) {
        CrmTaskStatus.inProgress => 'in_progress',
        _ => name,
      };

  static CrmTaskStatus fromSlug(String? raw) {
    return switch ((raw ?? 'open').toLowerCase()) {
      'in_progress' || 'inprogress' => CrmTaskStatus.inProgress,
      'done' => CrmTaskStatus.done,
      'cancelled' => CrmTaskStatus.cancelled,
      _ => CrmTaskStatus.open,
    };
  }
}

enum CrmAppointmentStatus {
  scheduled,
  confirmed,
  completed,
  cancelled,
  noShow;

  String get label => switch (this) {
        CrmAppointmentStatus.scheduled => 'Scheduled',
        CrmAppointmentStatus.confirmed => 'Confirmed',
        CrmAppointmentStatus.completed => 'Completed',
        CrmAppointmentStatus.cancelled => 'Cancelled',
        CrmAppointmentStatus.noShow => 'No Show',
      };

  String get slug => switch (this) {
        CrmAppointmentStatus.noShow => 'no_show',
        _ => name,
      };

  static CrmAppointmentStatus fromSlug(String? raw) {
    return switch ((raw ?? 'scheduled').toLowerCase()) {
      'confirmed' => CrmAppointmentStatus.confirmed,
      'completed' => CrmAppointmentStatus.completed,
      'cancelled' => CrmAppointmentStatus.cancelled,
      'no_show' || 'noshow' => CrmAppointmentStatus.noShow,
      _ => CrmAppointmentStatus.scheduled,
    };
  }
}

enum CrmHealthLabel {
  critical,
  atRisk,
  healthy,
  excellent,
  vip;

  String get label => switch (this) {
        CrmHealthLabel.critical => 'Critical',
        CrmHealthLabel.atRisk => 'At Risk',
        CrmHealthLabel.healthy => 'Healthy',
        CrmHealthLabel.excellent => 'Excellent',
        CrmHealthLabel.vip => 'VIP',
      };

  String get slug => switch (this) {
        CrmHealthLabel.atRisk => 'at_risk',
        _ => name,
      };

  static CrmHealthLabel fromSlug(String? raw) {
    return switch ((raw ?? 'healthy').toLowerCase()) {
      'critical' => CrmHealthLabel.critical,
      'at_risk' || 'atrisk' => CrmHealthLabel.atRisk,
      'excellent' => CrmHealthLabel.excellent,
      'vip' => CrmHealthLabel.vip,
      _ => CrmHealthLabel.healthy,
    };
  }

  static CrmHealthLabel fromScore(double score) {
    if (score >= 90) return CrmHealthLabel.vip;
    if (score >= 80) return CrmHealthLabel.excellent;
    if (score >= 60) return CrmHealthLabel.healthy;
    if (score >= 40) return CrmHealthLabel.atRisk;
    return CrmHealthLabel.critical;
  }
}

class CrmPipelineStage {
  const CrmPipelineStage({
    required this.id,
    required this.slug,
    required this.name,
    this.sortOrder = 0,
    this.probabilityPct = 0,
    this.isActive = true,
  });

  final String id;
  final String slug;
  final String name;
  final int sortOrder;
  final double probabilityPct;
  final bool isActive;

  factory CrmPipelineStage.fromJson(Map<String, dynamic> json) {
    return CrmPipelineStage(
      id: json['id']?.toString() ?? '',
      slug: json['slug'] as String? ?? '',
      name: json['name'] as String? ?? '',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      probabilityPct: (json['probability_pct'] as num?)?.toDouble() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class CrmClientPreference {
  const CrmClientPreference({
    this.preferredPropertyTypes = const [],
    this.bedrooms,
    this.amenities = const [],
    this.paymentPlanPref,
    this.investmentGoals,
  });

  final List<String> preferredPropertyTypes;
  final double? bedrooms;
  final List<String> amenities;
  final String? paymentPlanPref;
  final String? investmentGoals;

  factory CrmClientPreference.fromJson(Map<String, dynamic> json) {
    List<String> listOf(dynamic raw) => raw is List
        ? raw.map((e) => e.toString()).toList()
        : const <String>[];
    return CrmClientPreference(
      preferredPropertyTypes: listOf(json['preferred_property_types']),
      bedrooms: (json['bedrooms'] as num?)?.toDouble(),
      amenities: listOf(json['amenities']),
      paymentPlanPref: json['payment_plan_pref'] as String?,
      investmentGoals: json['investment_goals'] as String?,
    );
  }
}

class CrmClient {
  const CrmClient({
    required this.id,
    required this.clientCode,
    required this.fullName,
    this.email,
    this.phone,
    this.whatsapp,
    this.customerType = CrmCustomerType.guest,
    this.relationshipStatus = CrmRelationshipStatus.lead,
    this.assignedStaffId,
    this.profileId,
    this.nationality,
    this.preferredLanguage = 'en',
    this.occupation,
    this.company,
    this.industry,
    this.budgetMin,
    this.budgetMax,
    this.preferredLocations = const [],
    this.healthScore = 0,
    this.healthLabel = CrmHealthLabel.healthy,
    this.leadScore = 0,
    this.aiSummary,
    this.marketingConsent = false,
    this.preferences = const CrmClientPreference(),
    this.tags = const [],
  });

  final String id;
  final String clientCode;
  final String fullName;
  final String? email;
  final String? phone;
  final String? whatsapp;
  final CrmCustomerType customerType;
  final CrmRelationshipStatus relationshipStatus;
  final String? assignedStaffId;
  final String? profileId;
  final String? nationality;
  final String preferredLanguage;
  final String? occupation;
  final String? company;
  final String? industry;
  final double? budgetMin;
  final double? budgetMax;
  final List<String> preferredLocations;
  final double healthScore;
  final CrmHealthLabel healthLabel;
  final double leadScore;
  final String? aiSummary;
  final bool marketingConsent;
  final CrmClientPreference preferences;
  final List<String> tags;

  String formatBudget(double? value) {
    if (value == null) return '—';
    final n = value;
    if (n >= 1e9) return '₦${(n / 1e9).toStringAsFixed(1)}B';
    if (n >= 1e6) return '₦${(n / 1e6).toStringAsFixed(1)}M';
    if (n >= 1e3) return '₦${(n / 1e3).toStringAsFixed(0)}K';
    return '₦${n.toStringAsFixed(0)}';
  }

  String get budgetRange {
    if (budgetMin == null && budgetMax == null) return '—';
    return '${formatBudget(budgetMin)} – ${formatBudget(budgetMax)}';
  }

  factory CrmClient.fromJson(Map<String, dynamic> json) {
    final locs = json['preferred_locations'];
    final tagsRaw = json['tags'];
    return CrmClient(
      id: json['id']?.toString() ?? '',
      clientCode: json['client_code'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      whatsapp: json['whatsapp'] as String?,
      customerType: CrmCustomerType.fromSlug(json['customer_type'] as String?),
      relationshipStatus:
          CrmRelationshipStatus.fromSlug(json['relationship_status'] as String?),
      assignedStaffId: json['assigned_staff_id']?.toString(),
      profileId: json['profile_id']?.toString(),
      nationality: json['nationality'] as String?,
      preferredLanguage: json['preferred_language'] as String? ?? 'en',
      occupation: json['occupation'] as String?,
      company: json['company'] as String?,
      industry: json['industry'] as String?,
      budgetMin: (json['budget_min'] as num?)?.toDouble(),
      budgetMax: (json['budget_max'] as num?)?.toDouble(),
      preferredLocations: locs is List
          ? locs.map((e) => e.toString()).toList()
          : const <String>[],
      healthScore: (json['health_score'] as num?)?.toDouble() ?? 0,
      healthLabel: CrmHealthLabel.fromSlug(json['health_label'] as String?),
      leadScore: (json['lead_score'] as num?)?.toDouble() ?? 0,
      aiSummary: json['ai_summary'] as String?,
      marketingConsent: json['marketing_consent'] as bool? ?? false,
      preferences: json['preferences'] is Map
          ? CrmClientPreference.fromJson(
              Map<String, dynamic>.from(json['preferences'] as Map),
            )
          : const CrmClientPreference(),
      tags: tagsRaw is List
          ? tagsRaw.map((e) => e.toString()).toList()
          : const <String>[],
    );
  }
}

class CrmLead {
  const CrmLead({
    required this.id,
    required this.clientId,
    required this.title,
    this.clientName,
    this.sourceId,
    this.sourceName,
    this.stageId,
    this.stageSlug,
    this.stageName,
    this.status = CrmLeadStatus.open,
    this.assignedTo,
    this.priority = CrmPriority.medium,
    this.conversionProbability = 0,
    this.estimatedValue,
    this.notes,
    this.capturedAt,
  });

  final String id;
  final String clientId;
  final String title;
  final String? clientName;
  final String? sourceId;
  final String? sourceName;
  final String? stageId;
  final String? stageSlug;
  final String? stageName;
  final CrmLeadStatus status;
  final String? assignedTo;
  final CrmPriority priority;
  final double conversionProbability;
  final double? estimatedValue;
  final String? notes;
  final DateTime? capturedAt;

  String get valueDisplay {
    final n = estimatedValue;
    if (n == null) return '—';
    if (n >= 1e9) return '₦${(n / 1e9).toStringAsFixed(1)}B';
    if (n >= 1e6) return '₦${(n / 1e6).toStringAsFixed(1)}M';
    if (n >= 1e3) return '₦${(n / 1e3).toStringAsFixed(0)}K';
    return '₦${n.toStringAsFixed(0)}';
  }

  factory CrmLead.fromJson(Map<String, dynamic> json) {
    final stageRel = json['crm_pipeline_stages'];
    final sourceRel = json['crm_lead_sources'];
    final clientRel = json['crm_clients'];
    String? stageName;
    String? stageSlug;
    if (stageRel is Map) {
      stageName = stageRel['name'] as String?;
      stageSlug = stageRel['slug'] as String?;
    }
    return CrmLead(
      id: json['id']?.toString() ?? '',
      clientId: json['client_id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      clientName: json['client_name'] as String? ??
          (clientRel is Map ? clientRel['full_name'] as String? : null),
      sourceId: json['source_id']?.toString(),
      sourceName: json['source_name'] as String? ??
          (sourceRel is Map ? sourceRel['name'] as String? : null),
      stageId: json['stage_id']?.toString(),
      stageSlug: json['stage_slug'] as String? ?? stageSlug,
      stageName: json['stage_name'] as String? ?? stageName,
      status: CrmLeadStatus.fromSlug(json['status'] as String?),
      assignedTo: json['assigned_to']?.toString(),
      priority: CrmPriority.fromSlug(json['priority'] as String?),
      conversionProbability:
          (json['conversion_probability'] as num?)?.toDouble() ?? 0,
      estimatedValue: (json['estimated_value'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
      capturedAt: DateTime.tryParse(json['captured_at'] as String? ?? ''),
    );
  }
}

class CrmTask {
  const CrmTask({
    required this.id,
    required this.clientId,
    required this.title,
    this.clientName,
    this.leadId,
    this.taskType = CrmTaskType.followUp,
    this.priority = CrmPriority.medium,
    this.status = CrmTaskStatus.open,
    this.dueAt,
    this.assignedTo,
  });

  final String id;
  final String clientId;
  final String title;
  final String? clientName;
  final String? leadId;
  final CrmTaskType taskType;
  final CrmPriority priority;
  final CrmTaskStatus status;
  final DateTime? dueAt;
  final String? assignedTo;

  bool get isDueSoon {
    final due = dueAt;
    if (due == null) return false;
    final now = DateTime.now();
    return due.isAfter(now) && due.difference(now).inHours <= 48;
  }

  factory CrmTask.fromJson(Map<String, dynamic> json) {
    final clientRel = json['crm_clients'];
    return CrmTask(
      id: json['id']?.toString() ?? '',
      clientId: json['client_id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      clientName: json['client_name'] as String? ??
          (clientRel is Map ? clientRel['full_name'] as String? : null),
      leadId: json['lead_id']?.toString(),
      taskType: CrmTaskType.fromSlug(json['task_type'] as String?),
      priority: CrmPriority.fromSlug(json['priority'] as String?),
      status: CrmTaskStatus.fromSlug(json['status'] as String?),
      dueAt: DateTime.tryParse(json['due_at'] as String? ?? ''),
      assignedTo: json['assigned_to']?.toString(),
    );
  }
}

class CrmAppointment {
  const CrmAppointment({
    required this.id,
    required this.clientId,
    required this.title,
    required this.scheduledAt,
    this.clientName,
    this.appointmentType = 'meeting',
    this.location,
    this.meetingUrl,
    this.assignedStaffId,
    this.status = CrmAppointmentStatus.scheduled,
    this.propertyId,
  });

  final String id;
  final String clientId;
  final String title;
  final DateTime scheduledAt;
  final String? clientName;
  final String appointmentType;
  final String? location;
  final String? meetingUrl;
  final String? assignedStaffId;
  final CrmAppointmentStatus status;
  final String? propertyId;

  factory CrmAppointment.fromJson(Map<String, dynamic> json) {
    final clientRel = json['crm_clients'];
    return CrmAppointment(
      id: json['id']?.toString() ?? '',
      clientId: json['client_id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      scheduledAt: DateTime.tryParse(json['scheduled_at'] as String? ?? '') ??
          DateTime.now(),
      clientName: json['client_name'] as String? ??
          (clientRel is Map ? clientRel['full_name'] as String? : null),
      appointmentType: json['appointment_type'] as String? ?? 'meeting',
      location: json['location'] as String?,
      meetingUrl: json['meeting_url'] as String?,
      assignedStaffId: json['assigned_staff_id']?.toString(),
      status: CrmAppointmentStatus.fromSlug(json['status'] as String?),
      propertyId: json['property_id']?.toString(),
    );
  }
}

class CrmTimelineEvent {
  const CrmTimelineEvent({
    required this.id,
    required this.clientId,
    required this.eventType,
    required this.title,
    this.description,
    this.clientName,
    this.occurredAt,
  });

  final String id;
  final String clientId;
  final String eventType;
  final String title;
  final String? description;
  final String? clientName;
  final DateTime? occurredAt;

  factory CrmTimelineEvent.fromJson(Map<String, dynamic> json) {
    final clientRel = json['crm_clients'];
    return CrmTimelineEvent(
      id: json['id']?.toString() ?? '',
      clientId: json['client_id']?.toString() ?? '',
      eventType: json['event_type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      clientName: json['client_name'] as String? ??
          (clientRel is Map ? clientRel['full_name'] as String? : null),
      occurredAt: DateTime.tryParse(json['occurred_at'] as String? ?? ''),
    );
  }
}

class CrmAiInsight {
  const CrmAiInsight({
    required this.id,
    required this.title,
    required this.body,
    this.category = 'assistant',
    this.isAiGenerated = true,
    this.clientId,
  });

  final String id;
  final String title;
  final String body;
  final String category;
  final bool isAiGenerated;
  final String? clientId;
}

class CrmKpi {
  const CrmKpi({
    required this.label,
    required this.value,
    this.unit = 'count',
  });

  final String label;
  final double value;
  final String unit;

  String get displayValue {
    if (unit == 'ngn') {
      final n = value;
      if (n >= 1e9) return '₦${(n / 1e9).toStringAsFixed(1)}B';
      if (n >= 1e6) return '₦${(n / 1e6).toStringAsFixed(1)}M';
      if (n >= 1e3) return '₦${(n / 1e3).toStringAsFixed(0)}K';
      return '₦${n.toStringAsFixed(0)}';
    }
    if (unit == 'percent') {
      return value == value.roundToDouble()
          ? '${value.toStringAsFixed(0)}%'
          : '${value.toStringAsFixed(1)}%';
    }
    if (unit == 'score') {
      return value == value.roundToDouble()
          ? value.toStringAsFixed(0)
          : value.toStringAsFixed(1);
    }
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }
}

class CrmRelationshipNode {
  const CrmRelationshipNode({
    required this.id,
    required this.label,
    required this.kind,
    this.connectedTo = const [],
  });

  final String id;
  final String label;
  final String kind;
  final List<String> connectedTo;
}

/// Full CRM Command Center snapshot.
class CrmCommandCenterSnapshot {
  const CrmCommandCenterSnapshot({
    required this.kpis,
    required this.clients,
    required this.leads,
    required this.tasks,
    required this.appointments,
    required this.timeline,
    required this.stages,
    required this.aiInsights,
    required this.leadIntelligence,
    required this.relationshipGraph,
    this.fromRemote = false,
    this.loadedAt,
  });

  final List<CrmKpi> kpis;
  final List<CrmClient> clients;
  final List<CrmLead> leads;
  final List<CrmTask> tasks;
  final List<CrmAppointment> appointments;
  final List<CrmTimelineEvent> timeline;
  final List<CrmPipelineStage> stages;
  final List<CrmAiInsight> aiInsights;
  final List<String> leadIntelligence;
  final List<CrmRelationshipNode> relationshipGraph;
  final bool fromRemote;
  final DateTime? loadedAt;

  Map<String, int> stageCounts() {
    final counts = <String, int>{};
    for (final stage in stages) {
      counts[stage.slug] = 0;
    }
    for (final lead in leads) {
      final key = lead.stageSlug ?? 'new';
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }
}

/// Default / offline CRM dataset when DB is empty or unavailable.
abstract final class CrmDemo {
  static CrmCommandCenterSnapshot snapshot() {
    final now = DateTime.now();
    final stages = _stages();
    final clients = _clients();
    final leads = _leads(now);
    final tasks = _tasks(now);
    final appointments = _appointments(now);
    final timeline = _timeline(now);

    return CrmCommandCenterSnapshot(
      kpis: aggregateKpis(
        clients: clients,
        leads: leads,
        tasks: tasks,
      ),
      clients: clients,
      leads: leads,
      tasks: tasks,
      appointments: appointments,
      timeline: timeline,
      stages: stages,
      aiInsights: const [
        CrmAiInsight(
          id: 'crm-ai-1',
          title: 'VIP acceleration — Adaeze Nwosu',
          body:
              'Negotiation-stage VIP with 82% conversion probability. Recommend same-day offer letter and priority site escort.',
          category: 'pipeline',
          clientId: 'crm-1',
        ),
        CrmAiInsight(
          id: 'crm-ai-2',
          title: 'Payment-plan nudge — Chuka Okonkwo',
          body:
              'Active buyer stalled on installment clarity. Auto-send 6/12/18-month schedule templates to unlock site visit.',
          category: 'follow_up',
          clientId: 'crm-2',
        ),
        CrmAiInsight(
          id: 'crm-ai-3',
          title: 'Investor tranche fit — Horizon Capital',
          body:
              'Penthouse and multi-unit yield stories outperform single duplex pitches for this persona. Lead with IRR pack.',
          category: 'matching',
          clientId: 'crm-3',
        ),
        CrmAiInsight(
          id: 'crm-ai-4',
          title: 'Pipeline health',
          body:
              'Hot leads concentrating in Negotiation. Keep Lost stage under 15% this month by reactivating dormant WhatsApp inquiries.',
          category: 'analytics',
        ),
      ],
      leadIntelligence: const [
        'Lead Intelligence™: 1 VIP hot lead requires owner-level follow-up within 6 hours.',
        'WhatsApp-sourced leads convert 1.6× faster than website form leads this week.',
        'Budget bands ₦60–95M dominate apartment interest — prioritize Azure Court inventory.',
        'Referral code REF-ADA-CHU-01 is qualified; queue reward approval for finance.',
      ],
      relationshipGraph: const [
        CrmRelationshipNode(
          id: 'crm-1',
          label: 'Adaeze Nwosu (VIP)',
          kind: 'client',
          connectedTo: ['staff-sales', 'crm-2', 'prop-vc'],
        ),
        CrmRelationshipNode(
          id: 'crm-2',
          label: 'Chuka Okonkwo',
          kind: 'client',
          connectedTo: ['crm-1', 'staff-sales', 'prop-azure'],
        ),
        CrmRelationshipNode(
          id: 'crm-3',
          label: 'Horizon Capital',
          kind: 'investor',
          connectedTo: ['staff-ir', 'prop-harbour'],
        ),
        CrmRelationshipNode(
          id: 'staff-sales',
          label: 'Sales Pod A',
          kind: 'staff',
          connectedTo: ['crm-1', 'crm-2'],
        ),
        CrmRelationshipNode(
          id: 'staff-ir',
          label: 'Investor Relations',
          kind: 'staff',
          connectedTo: ['crm-3'],
        ),
        CrmRelationshipNode(
          id: 'prop-vc',
          label: 'Victoria Crest',
          kind: 'property',
          connectedTo: ['crm-1'],
        ),
        CrmRelationshipNode(
          id: 'prop-azure',
          label: 'Azure Court',
          kind: 'property',
          connectedTo: ['crm-2'],
        ),
        CrmRelationshipNode(
          id: 'prop-harbour',
          label: 'Harbour View',
          kind: 'property',
          connectedTo: ['crm-3'],
        ),
      ],
      fromRemote: false,
      loadedAt: now,
    );
  }

  static List<CrmKpi> aggregateKpis({
    required List<CrmClient> clients,
    required List<CrmLead> leads,
    required List<CrmTask> tasks,
  }) {
    final newLeads = leads
        .where((l) =>
            l.status == CrmLeadStatus.open ||
            l.status == CrmLeadStatus.qualified)
        .length
        .toDouble();
    var pipelineValue = 0.0;
    var probabilitySum = 0.0;
    for (final lead in leads) {
      if (lead.status == CrmLeadStatus.won || lead.status == CrmLeadStatus.lost) {
        continue;
      }
      pipelineValue += lead.estimatedValue ?? 0;
      probabilitySum += lead.conversionProbability;
    }
    final conversionRate =
        leads.isEmpty ? 0.0 : probabilitySum / leads.length;
    final tasksDue = tasks
        .where((t) =>
            t.status == CrmTaskStatus.open ||
            t.status == CrmTaskStatus.inProgress)
        .length
        .toDouble();
    final avgHealth = clients.isEmpty
        ? 0.0
        : clients.map((c) => c.healthScore).reduce((a, b) => a + b) /
            clients.length;
    final hotLeads = leads
        .where((l) =>
            l.priority == CrmPriority.urgent ||
            l.priority == CrmPriority.high ||
            l.conversionProbability >= 70)
        .length
        .toDouble();

    return [
      CrmKpi(label: 'New Leads', value: newLeads),
      CrmKpi(label: 'Pipeline Value', value: pipelineValue, unit: 'ngn'),
      CrmKpi(label: 'Conversion Rate', value: conversionRate, unit: 'percent'),
      CrmKpi(label: 'Tasks Due', value: tasksDue),
      CrmKpi(label: 'Avg Health', value: avgHealth, unit: 'score'),
      CrmKpi(label: 'Hot Leads', value: hotLeads),
    ];
  }

  static List<CrmPipelineStage> _stages() => const [
        CrmPipelineStage(
          id: 'st-new',
          slug: 'new',
          name: 'New Lead',
          sortOrder: 10,
          probabilityPct: 10,
        ),
        CrmPipelineStage(
          id: 'st-contacted',
          slug: 'contacted',
          name: 'Contacted',
          sortOrder: 20,
          probabilityPct: 25,
        ),
        CrmPipelineStage(
          id: 'st-qualified',
          slug: 'qualified',
          name: 'Qualified',
          sortOrder: 30,
          probabilityPct: 40,
        ),
        CrmPipelineStage(
          id: 'st-site',
          slug: 'site_visit',
          name: 'Site Visit',
          sortOrder: 40,
          probabilityPct: 55,
        ),
        CrmPipelineStage(
          id: 'st-nego',
          slug: 'negotiation',
          name: 'Negotiation',
          sortOrder: 50,
          probabilityPct: 70,
        ),
        CrmPipelineStage(
          id: 'st-won',
          slug: 'won',
          name: 'Won',
          sortOrder: 60,
          probabilityPct: 100,
        ),
        CrmPipelineStage(
          id: 'st-lost',
          slug: 'lost',
          name: 'Lost',
          sortOrder: 70,
          probabilityPct: 0,
        ),
      ];

  static List<CrmClient> _clients() => const [
        CrmClient(
          id: 'crm-1',
          clientCode: 'CRM-VIP-001',
          fullName: 'Adaeze Nwosu',
          email: 'adaeze.nwosu@example.com',
          phone: '+2348010000001',
          whatsapp: '+2348010000001',
          customerType: CrmCustomerType.buyer,
          relationshipStatus: CrmRelationshipStatus.vip,
          nationality: 'Nigerian',
          occupation: 'Entrepreneur',
          company: 'Nwosu Holdings',
          industry: 'Real Estate',
          budgetMin: 80000000,
          budgetMax: 150000000,
          preferredLocations: ['Lekki', 'Victoria Island'],
          healthScore: 92,
          healthLabel: CrmHealthLabel.vip,
          leadScore: 88,
          aiSummary:
              'VIP hot lead with strong Lekki duplex preference. High engagement and referral potential — prioritize site visit this week.',
          marketingConsent: true,
          preferences: CrmClientPreference(
            preferredPropertyTypes: ['duplex', 'maisonette'],
            bedrooms: 4,
            amenities: ['Pool', 'Security', 'Backup Power'],
            paymentPlanPref: 'outright',
            investmentGoals: 'Primary residence + prestige',
          ),
          tags: ['hot', 'vip', 'lekki'],
        ),
        CrmClient(
          id: 'crm-2',
          clientCode: 'CRM-BUY-002',
          fullName: 'Chuka Okonkwo',
          email: 'chuka.okonkwo@example.com',
          phone: '+2348010000002',
          customerType: CrmCustomerType.buyer,
          relationshipStatus: CrmRelationshipStatus.activeBuyer,
          nationality: 'Nigerian',
          occupation: 'Banker',
          company: 'First Atlantic Bank',
          industry: 'Finance',
          budgetMin: 60000000,
          budgetMax: 95000000,
          preferredLocations: ['Lekki', 'Ajah'],
          healthScore: 78,
          healthLabel: CrmHealthLabel.healthy,
          leadScore: 71,
          aiSummary:
              'Active buyer mid-pipeline. Prefers 3-bed apartments with payment plan flexibility.',
          marketingConsent: true,
          preferences: CrmClientPreference(
            preferredPropertyTypes: ['apartment'],
            bedrooms: 3,
            amenities: ['Gym', 'Parking', 'CCTV'],
            paymentPlanPref: '12_month',
            investmentGoals: 'Family home close to work',
          ),
          tags: ['buyer'],
        ),
        CrmClient(
          id: 'crm-3',
          clientCode: 'CRM-INV-003',
          fullName: 'Horizon Capital Partners',
          email: 'deals@horizoncapital.example',
          phone: '+2348010000003',
          customerType: CrmCustomerType.investor,
          relationshipStatus: CrmRelationshipStatus.investor,
          nationality: 'Nigerian',
          occupation: 'Investment Director',
          company: 'Horizon Capital',
          industry: 'Private Equity',
          budgetMin: 150000000,
          budgetMax: 500000000,
          preferredLocations: ['Port Harcourt', 'Lekki', 'Abuja'],
          healthScore: 85,
          healthLabel: CrmHealthLabel.excellent,
          leadScore: 82,
          aiSummary:
              'Institutional investor evaluating penthouse and multi-unit tranches. Focus on ROI and title clarity.',
          preferences: CrmClientPreference(
            preferredPropertyTypes: ['penthouse', 'apartment'],
            bedrooms: 5,
            amenities: ['Concierge', 'Waterfront', 'Smart Home'],
            paymentPlanPref: 'tranche',
            investmentGoals: 'Portfolio yield 12%+ IRR',
          ),
          tags: ['investor'],
        ),
      ];

  static List<CrmLead> _leads(DateTime now) => [
        CrmLead(
          id: 'lead-1',
          clientId: 'crm-1',
          clientName: 'Adaeze Nwosu',
          title: 'Victoria Crest Duplex — VIP inquiry',
          sourceName: 'WhatsApp',
          stageId: 'st-nego',
          stageSlug: 'negotiation',
          stageName: 'Negotiation',
          status: CrmLeadStatus.qualified,
          priority: CrmPriority.urgent,
          conversionProbability: 82,
          estimatedValue: 145000000,
          notes: 'Hot VIP lead from WhatsApp after open house.',
          capturedAt: now.subtract(const Duration(days: 2)),
        ),
        CrmLead(
          id: 'lead-2',
          clientId: 'crm-2',
          clientName: 'Chuka Okonkwo',
          title: 'Azure Court 3-Bed payment plan',
          sourceName: 'Website',
          stageId: 'st-site',
          stageSlug: 'site_visit',
          stageName: 'Site Visit',
          status: CrmLeadStatus.open,
          priority: CrmPriority.high,
          conversionProbability: 58,
          estimatedValue: 68000000,
          capturedAt: now.subtract(const Duration(days: 5)),
        ),
        CrmLead(
          id: 'lead-3',
          clientId: 'crm-3',
          clientName: 'Horizon Capital Partners',
          title: 'Harbour View investor tranche',
          sourceName: 'Referral',
          stageId: 'st-qualified',
          stageSlug: 'qualified',
          stageName: 'Qualified',
          status: CrmLeadStatus.qualified,
          priority: CrmPriority.high,
          conversionProbability: 65,
          estimatedValue: 220000000,
          capturedAt: now.subtract(const Duration(days: 8)),
        ),
      ];

  static List<CrmTask> _tasks(DateTime now) => [
        CrmTask(
          id: 'task-1',
          clientId: 'crm-1',
          clientName: 'Adaeze Nwosu',
          leadId: 'lead-1',
          title: 'Call Adaeze — confirm duplex offer letter',
          taskType: CrmTaskType.call,
          priority: CrmPriority.urgent,
          status: CrmTaskStatus.open,
          dueAt: now.add(const Duration(hours: 4)),
        ),
        CrmTask(
          id: 'task-2',
          clientId: 'crm-2',
          clientName: 'Chuka Okonkwo',
          leadId: 'lead-2',
          title: 'Send installment schedule PDF',
          taskType: CrmTaskType.email,
          priority: CrmPriority.high,
          status: CrmTaskStatus.open,
          dueAt: now.add(const Duration(days: 1)),
        ),
        CrmTask(
          id: 'task-3',
          clientId: 'crm-3',
          clientName: 'Horizon Capital Partners',
          leadId: 'lead-3',
          title: 'Prepare investor ROI pack — Harbour View',
          taskType: CrmTaskType.followUp,
          priority: CrmPriority.medium,
          status: CrmTaskStatus.inProgress,
          dueAt: now.add(const Duration(days: 2)),
        ),
      ];

  static List<CrmAppointment> _appointments(DateTime now) => [
        CrmAppointment(
          id: 'appt-1',
          clientId: 'crm-1',
          clientName: 'Adaeze Nwosu',
          appointmentType: 'site_visit',
          title: 'VIP site visit — Victoria Crest',
          scheduledAt: now.add(const Duration(days: 1)),
          location: 'Victoria Crest Sales Gallery, Lekki',
          status: CrmAppointmentStatus.confirmed,
        ),
        CrmAppointment(
          id: 'appt-2',
          clientId: 'crm-2',
          clientName: 'Chuka Okonkwo',
          appointmentType: 'meeting',
          title: 'Payment plan review — Chuka',
          scheduledAt: now.add(const Duration(days: 2)),
          location: 'HD Homes HQ',
          status: CrmAppointmentStatus.scheduled,
        ),
        CrmAppointment(
          id: 'appt-3',
          clientId: 'crm-3',
          clientName: 'Horizon Capital Partners',
          appointmentType: 'investor_briefing',
          title: 'Horizon Capital investor briefing',
          scheduledAt: now.add(const Duration(days: 3)),
          location: 'Virtual',
          status: CrmAppointmentStatus.scheduled,
        ),
      ];

  static List<CrmTimelineEvent> _timeline(DateTime now) => [
        CrmTimelineEvent(
          id: 'tl-1',
          clientId: 'crm-1',
          clientName: 'Adaeze Nwosu',
          eventType: 'lead_created',
          title: 'VIP lead captured',
          description: 'WhatsApp inbound after open house.',
          occurredAt: now.subtract(const Duration(days: 2)),
        ),
        CrmTimelineEvent(
          id: 'tl-2',
          clientId: 'crm-1',
          clientName: 'Adaeze Nwosu',
          eventType: 'stage_change',
          title: 'Moved to Negotiation',
          description: 'Post site-tour conversion boost.',
          occurredAt: now.subtract(const Duration(days: 1)),
        ),
        CrmTimelineEvent(
          id: 'tl-3',
          clientId: 'crm-2',
          clientName: 'Chuka Okonkwo',
          eventType: 'task_created',
          title: 'Installment schedule requested',
          description: 'Client asked for 12-month plan.',
          occurredAt: now.subtract(const Duration(days: 5)),
        ),
        CrmTimelineEvent(
          id: 'tl-4',
          clientId: 'crm-2',
          clientName: 'Chuka Okonkwo',
          eventType: 'appointment_set',
          title: 'Payment plan meeting booked',
          description: 'HQ meeting in 2 days.',
          occurredAt: now.subtract(const Duration(hours: 6)),
        ),
        CrmTimelineEvent(
          id: 'tl-5',
          clientId: 'crm-3',
          clientName: 'Horizon Capital Partners',
          eventType: 'note',
          title: 'Investor diligence started',
          description: 'Title pack + yield model requested.',
          occurredAt: now.subtract(const Duration(days: 8)),
        ),
      ];
}
