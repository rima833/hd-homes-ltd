/// Client Ops Command Center domain models (admin desk).
library;

class ClientOpsKpi {
  const ClientOpsKpi({
    required this.label,
    required this.value,
    this.unit = 'count',
  });

  final String label;
  final double value;
  final String unit;

  String get displayValue {
    if (unit == 'ngn') {
      final n = value.round();
      final s = n.toString();
      final buf = StringBuffer();
      for (var i = 0; i < s.length; i++) {
        final fromEnd = s.length - i;
        buf.write(s[i]);
        if (fromEnd > 1 && fromEnd % 3 == 1) buf.write(',');
      }
      return '₦$buf';
    }
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }
}

class ClientDeskKpis {
  const ClientDeskKpis({
    required this.totalClients,
    required this.activeBuyers,
    required this.leads,
    required this.unassigned,
    required this.portalLinked,
    required this.openLeads,
    required this.pendingApplications,
    required this.pendingPayments,
    required this.overdueTasks,
    this.generatedAt,
  });

  final int totalClients;
  final int activeBuyers;
  final int leads;
  final int unassigned;
  final int portalLinked;
  final int openLeads;
  final int pendingApplications;
  final int pendingPayments;
  final int overdueTasks;
  final DateTime? generatedAt;

  factory ClientDeskKpis.fromJson(Map<String, dynamic> json) {
    return ClientDeskKpis(
      totalClients: (json['total_clients'] as num?)?.toInt() ?? 0,
      activeBuyers: (json['active_buyers'] as num?)?.toInt() ?? 0,
      leads: (json['leads'] as num?)?.toInt() ?? 0,
      unassigned: (json['unassigned'] as num?)?.toInt() ?? 0,
      portalLinked: (json['portal_linked'] as num?)?.toInt() ?? 0,
      openLeads: (json['open_leads'] as num?)?.toInt() ?? 0,
      pendingApplications:
          (json['pending_applications'] as num?)?.toInt() ?? 0,
      pendingPayments: (json['pending_payments'] as num?)?.toInt() ?? 0,
      overdueTasks: (json['overdue_tasks'] as num?)?.toInt() ?? 0,
      generatedAt: DateTime.tryParse(json['generated_at'] as String? ?? ''),
    );
  }

  List<ClientOpsKpi> toKpiCards() => [
        ClientOpsKpi(label: 'Total Clients', value: totalClients.toDouble()),
        ClientOpsKpi(label: 'Active Buyers', value: activeBuyers.toDouble()),
        ClientOpsKpi(label: 'Leads', value: leads.toDouble()),
        ClientOpsKpi(label: 'Unassigned', value: unassigned.toDouble()),
        ClientOpsKpi(label: 'Portal Linked', value: portalLinked.toDouble()),
        ClientOpsKpi(label: 'Open Pipeline', value: openLeads.toDouble()),
        ClientOpsKpi(
          label: 'Applications',
          value: pendingApplications.toDouble(),
        ),
        ClientOpsKpi(
          label: 'Pending Payments',
          value: pendingPayments.toDouble(),
        ),
        ClientOpsKpi(label: 'Overdue Tasks', value: overdueTasks.toDouble()),
      ];
}

class ClientOpsRow {
  const ClientOpsRow({
    required this.id,
    required this.fullName,
    this.clientCode,
    this.email,
    this.phone,
    this.whatsapp,
    this.customerType,
    this.relationshipStatus,
    this.assignedStaffId,
    this.assignedStaffName,
    this.profileId,
    this.portalClientId,
    this.portalStatus,
    this.hasPortal = false,
    this.company,
    this.budgetMin,
    this.budgetMax,
    this.preferredLocations = const [],
    this.healthScore,
    this.healthLabel,
    this.leadScore,
    this.openLeads = 0,
    this.openTasks = 0,
    this.pendingApplications = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String fullName;
  final String? clientCode;
  final String? email;
  final String? phone;
  final String? whatsapp;
  final String? customerType;
  final String? relationshipStatus;
  final String? assignedStaffId;
  final String? assignedStaffName;
  final String? profileId;
  final String? portalClientId;
  final String? portalStatus;
  final bool hasPortal;
  final String? company;
  final double? budgetMin;
  final double? budgetMax;
  final List<String> preferredLocations;
  final double? healthScore;
  final String? healthLabel;
  final double? leadScore;
  final int openLeads;
  final int openTasks;
  final int pendingApplications;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get statusLabel {
    final raw = relationshipStatus ?? '';
    if (raw.isEmpty) return '—';
    return raw
        .split('_')
        .map((p) => p.isEmpty ? p : '${p[0].toUpperCase()}${p.substring(1)}')
        .join(' ');
  }

  factory ClientOpsRow.fromJson(Map<String, dynamic> json) {
    final locs = json['preferred_locations'];
    return ClientOpsRow(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name'] as String? ?? 'Client',
      clientCode: json['client_code'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      whatsapp: json['whatsapp'] as String?,
      customerType: json['customer_type'] as String?,
      relationshipStatus: json['relationship_status'] as String?,
      assignedStaffId: json['assigned_staff_id']?.toString(),
      assignedStaffName: json['assigned_staff_name'] as String?,
      profileId: json['profile_id']?.toString(),
      portalClientId: json['portal_client_id']?.toString(),
      portalStatus: json['portal_status'] as String?,
      hasPortal: json['has_portal'] as bool? ?? false,
      company: json['company'] as String?,
      budgetMin: (json['budget_min'] as num?)?.toDouble(),
      budgetMax: (json['budget_max'] as num?)?.toDouble(),
      preferredLocations: locs is List
          ? locs.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
          : const [],
      healthScore: (json['health_score'] as num?)?.toDouble(),
      healthLabel: json['health_label'] as String?,
      leadScore: (json['lead_score'] as num?)?.toDouble(),
      openLeads: (json['open_leads'] as num?)?.toInt() ?? 0,
      openTasks: (json['open_tasks'] as num?)?.toInt() ?? 0,
      pendingApplications:
          (json['pending_applications'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
    );
  }
}

class ClientOpsPage {
  const ClientOpsPage({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
    required this.hasMore,
  });

  final List<ClientOpsRow> items;
  final int total;
  final int limit;
  final int offset;
  final bool hasMore;

  factory ClientOpsPage.fromJson(Map<String, dynamic> json) {
    final rows = json['items'];
    return ClientOpsPage(
      items: rows is List
          ? rows
              .whereType<Map>()
              .map((r) => ClientOpsRow.fromJson(Map<String, dynamic>.from(r)))
              .toList()
          : const [],
      total: (json['total'] as num?)?.toInt() ?? 0,
      limit: (json['limit'] as num?)?.toInt() ?? 50,
      offset: (json['offset'] as num?)?.toInt() ?? 0,
      hasMore: json['has_more'] as bool? ?? false,
    );
  }
}

class ClientOpsQueueItem {
  const ClientOpsQueueItem({
    required this.id,
    required this.title,
    required this.status,
    this.clientId,
    this.subtitle,
    this.amount,
    this.currency,
    this.priority,
    this.dueAt,
    this.createdAt,
  });

  final String id;
  final String title;
  final String status;
  final String? clientId;
  final String? subtitle;
  final double? amount;
  final String? currency;
  final String? priority;
  final DateTime? dueAt;
  final DateTime? createdAt;

  factory ClientOpsQueueItem.fromJson(Map<String, dynamic> json) {
    return ClientOpsQueueItem(
      id: json['id']?.toString() ?? '',
      clientId: json['client_id']?.toString(),
      title: json['title'] as String? ?? '',
      status: json['status'] as String? ?? '',
      subtitle: json['subtitle'] as String?,
      amount: (json['amount'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
      priority: json['priority'] as String?,
      dueAt: DateTime.tryParse(json['due_at'] as String? ?? ''),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }
}

class ClientOpsWorkQueues {
  const ClientOpsWorkQueues({
    this.unassigned = const [],
    this.followUps = const [],
    this.tasks = const [],
    this.applications = const [],
    this.payments = const [],
    this.stale = const [],
  });

  final List<ClientOpsQueueItem> unassigned;
  final List<ClientOpsQueueItem> followUps;
  final List<ClientOpsQueueItem> tasks;
  final List<ClientOpsQueueItem> applications;
  final List<ClientOpsQueueItem> payments;
  final List<ClientOpsQueueItem> stale;

  factory ClientOpsWorkQueues.fromJson(Map<String, dynamic> json) {
    List<ClientOpsQueueItem> parse(String key) {
      final rows = json[key];
      if (rows is! List) return const [];
      return rows
          .whereType<Map>()
          .map(
            (r) => ClientOpsQueueItem.fromJson(Map<String, dynamic>.from(r)),
          )
          .toList();
    }

    return ClientOpsWorkQueues(
      unassigned: parse('unassigned'),
      followUps: parse('follow_ups'),
      tasks: parse('tasks'),
      applications: parse('applications'),
      payments: parse('payments'),
      stale: parse('stale'),
    );
  }
}

class ClientOpsStaffOption {
  const ClientOpsStaffOption({
    required this.id,
    required this.name,
    this.email,
  });

  final String id;
  final String name;
  final String? email;

  factory ClientOpsStaffOption.fromJson(Map<String, dynamic> json) {
    return ClientOpsStaffOption(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String?,
    );
  }
}

class ClientOpsLeadRow {
  const ClientOpsLeadRow({
    required this.id,
    required this.title,
    required this.status,
    this.priority,
    this.estimatedValue,
    this.nextFollowUpAt,
    this.preferredLocation,
  });

  final String id;
  final String title;
  final String status;
  final String? priority;
  final double? estimatedValue;
  final DateTime? nextFollowUpAt;
  final String? preferredLocation;

  factory ClientOpsLeadRow.fromJson(Map<String, dynamic> json) {
    return ClientOpsLeadRow(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? 'Lead',
      status: json['status'] as String? ?? '',
      priority: json['priority'] as String?,
      estimatedValue: (json['estimated_value'] as num?)?.toDouble(),
      nextFollowUpAt:
          DateTime.tryParse(json['next_follow_up_at'] as String? ?? ''),
      preferredLocation: json['preferred_location'] as String?,
    );
  }
}

class ClientOpsTaskRow {
  const ClientOpsTaskRow({
    required this.id,
    required this.title,
    required this.status,
    this.priority,
    this.taskType,
    this.dueAt,
  });

  final String id;
  final String title;
  final String status;
  final String? priority;
  final String? taskType;
  final DateTime? dueAt;

  factory ClientOpsTaskRow.fromJson(Map<String, dynamic> json) {
    return ClientOpsTaskRow(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? 'Task',
      status: json['status'] as String? ?? '',
      priority: json['priority'] as String?,
      taskType: json['task_type'] as String?,
      dueAt: DateTime.tryParse(json['due_at'] as String? ?? ''),
    );
  }
}

class ClientOpsApplicationRow {
  const ClientOpsApplicationRow({
    required this.id,
    required this.status,
    this.paymentPlan,
    this.amountOffered,
    this.createdAt,
  });

  final String id;
  final String status;
  final String? paymentPlan;
  final double? amountOffered;
  final DateTime? createdAt;

  factory ClientOpsApplicationRow.fromJson(Map<String, dynamic> json) {
    return ClientOpsApplicationRow(
      id: json['id']?.toString() ?? '',
      status: json['status'] as String? ?? '',
      paymentPlan: json['payment_plan'] as String?,
      amountOffered: (json['amount_offered'] as num?)?.toDouble(),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }
}

class ClientOpsPaymentRow {
  const ClientOpsPaymentRow({
    required this.id,
    required this.status,
    this.amount,
    this.currency,
    this.reference,
    this.createdAt,
  });

  final String id;
  final String status;
  final double? amount;
  final String? currency;
  final String? reference;
  final DateTime? createdAt;

  factory ClientOpsPaymentRow.fromJson(Map<String, dynamic> json) {
    return ClientOpsPaymentRow(
      id: json['id']?.toString() ?? '',
      status: json['status'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
      reference: (json['payment_reference'] as String?) ??
          (json['bank_reference'] as String?) ??
          (json['provider_reference'] as String?),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }
}

class ClientOpsDetail {
  const ClientOpsDetail({
    required this.client,
    this.leads = const [],
    this.tasks = const [],
    this.applications = const [],
    this.payments = const [],
    this.aiSummary,
    this.nationality,
    this.occupation,
    this.industry,
    this.preferredLanguage,
    this.marketingConsent,
  });

  final ClientOpsRow client;
  final List<ClientOpsLeadRow> leads;
  final List<ClientOpsTaskRow> tasks;
  final List<ClientOpsApplicationRow> applications;
  final List<ClientOpsPaymentRow> payments;
  final String? aiSummary;
  final String? nationality;
  final String? occupation;
  final String? industry;
  final String? preferredLanguage;
  final bool? marketingConsent;

  factory ClientOpsDetail.fromJson(Map<String, dynamic> json) {
    List<T> parseList<T>(String key, T Function(Map<String, dynamic>) convert) {
      final rows = json[key];
      if (rows is! List) return const [];
      return rows
          .whereType<Map>()
          .map((r) => convert(Map<String, dynamic>.from(r)))
          .toList();
    }

    return ClientOpsDetail(
      client: ClientOpsRow.fromJson(json),
      leads: parseList('leads', ClientOpsLeadRow.fromJson),
      tasks: parseList('tasks', ClientOpsTaskRow.fromJson),
      applications: parseList('applications', ClientOpsApplicationRow.fromJson),
      payments: parseList('payments', ClientOpsPaymentRow.fromJson),
      aiSummary: json['ai_summary'] as String?,
      nationality: json['nationality'] as String?,
      occupation: json['occupation'] as String?,
      industry: json['industry'] as String?,
      preferredLanguage: json['preferred_language'] as String?,
      marketingConsent: json['marketing_consent'] as bool?,
    );
  }
}
